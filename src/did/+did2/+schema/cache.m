classdef cache < handle
    % did2.schema.cache  V_delta schema cache.
    %
    %   Loads V_delta schema files lazily, resolves superclass chains,
    %   builds blank documents in the V_delta class-scoped wire shape,
    %   and validates documents against their class definitions. See
    %   docs/v2/PLAN.md §5.
    %
    %   Document shape (V_delta "JSON Format: Document Instances"):
    %     document_class
    %       .class_name       string         concrete class
    %       .class_version    string         semver of the concrete class
    %       .superclasses     array          [{class_name, class_version}]
    %     depends_on          array          [{name, value}]
    %     <class_name>        object         one property block per class
    %                                        in the chain. Contains the
    %                                        field values that class
    %                                        declared (empty {} if it
    %                                        declares no fields).
    %
    %   MATLAB representation: every key in the V_delta wire shape is a
    %   valid MATLAB struct field name (no leading underscores anywhere
    %   after the V_delta SPEC's "drop underscore prefixes" update), so
    %   the in-memory representation is the JSON shape verbatim.
    %   `jsondecode` returns a struct with the same field names, and
    %   `jsonencode` writes them back without any rename pass.
    %
    %   did2.schema.cache Properties:
    %       schemaPath      - filesystem path to a V_delta schema dir.
    %       loadedClasses   - containers.Map of classname -> raw schema.
    %       curieRegistry   - parsed CURIE_lookups_meta.json contents.
    %
    %   did2.schema.cache Static Methods:
    %       shared          - return the process-wide singleton cache.
    %       setSchemaPath   - rebuild the singleton at a new schema path.
    %       resetSingleton  - drop the cached singleton (test helper).
    %
    %   did2.schema.cache Methods:
    %       getClass            - resolved class definition for a name.
    %       superclasses        - ancestor chain (parent first, root last).
    %       classChain          - root-first list including the class itself.
    %       ownFields           - the `fields` list a class declares directly.
    %       fieldsFor           - merged inherited fields tagged with the
    %                             declaring class (struct array).
    %       loadAllSchemas      - parse every *.json in the schema dir.
    %       queryablePaths      - scalar and array-iteration paths
    %                             declared by the loaded schemas.
    %       buildBlankDocument  - blank V_delta document in the wire shape.
    %       validateDocument    - validate a did2.document instance.
    %
    %   See also: did2.document, docs/v2/PLAN.md.

    properties (SetAccess = private)
        schemaPath (1,:) char = ''
        loadedClasses
        curieRegistry struct = struct()
    end

    methods (Access = private)
        function obj = cache(schemaPath)
            % Private constructor — use did2.schema.cache.shared().
            arguments
                schemaPath (1,:) char = did2.schema.cache.defaultSchemaPath()
            end
            obj.schemaPath = schemaPath;
            obj.loadedClasses = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.loadRegistry();
        end
    end

    methods
        function s = getClass(obj, className)
            % getClass - return the parsed schema struct for className.
            arguments
                obj
                className (1,:) char
            end
            if obj.loadedClasses.isKey(className)
                s = obj.loadedClasses(className);
                return;
            end
            schemaFile = fullfile(obj.schemaPath, [className '.json']);
            if ~isfile(schemaFile)
                error('did2:schema:missingClass', ...
                    'No schema file for class "%s" at %s.', className, schemaFile);
            end
            s = jsondecode(fileread(schemaFile));
            obj.loadedClasses(className) = s;
        end

        function names = superclasses(obj, className)
            % superclasses - transitive ancestor list across multiple
            %   inheritance. BFS over every parent class_name in each
            %   ancestor's `document_class.superclasses` array, deduped
            %   by class name. Order: direct parents first (in their
            %   schema-declared order), then grandparents, etc.
            %
            %   For single-inheritance schemas the order matches the
            %   leaf-first convention used before the multi-parent fix
            %   (e.g., 'demoB' -> {'demoA', 'base'}); multi-parent
            %   classes flatten their ancestor DAG in BFS order. The
            %   classChain() wrapper still applies fliplr to put
            %   deepest-discovered ancestors at the front and the
            %   class itself at the back.
            arguments
                obj
                className (1,:) char
            end
            names = {};
            visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            visited(className) = true;
            queue = {className};
            while ~isempty(queue)
                current = queue{1};
                queue(1) = [];
                s = obj.getClass(current);
                if ~isstruct(s) || ~isfield(s, 'document_class') ...
                        || ~isstruct(s.document_class) ...
                        || ~isfield(s.document_class, 'superclasses') ...
                        || isempty(s.document_class.superclasses)
                    continue;
                end
                sc = s.document_class.superclasses;
                for k = 1:numel(sc)
                    parent = obj.elementAt(sc, k);
                    if ~isstruct(parent) || ~isfield(parent, 'class_name')
                        continue;
                    end
                    parentName = char(parent.class_name);
                    if isempty(parentName) || visited.isKey(parentName)
                        continue;
                    end
                    visited(parentName) = true;
                    names{end+1} = parentName; %#ok<AGROW>
                    queue{end+1} = parentName; %#ok<AGROW>
                end
            end
        end

        function chain = classChain(obj, className)
            % classChain - root-first list of class names including the
            %   class itself. For 'demoB' -> {'base', 'demoA', 'demoB'}.
            arguments
                obj
                className (1,:) char
            end
            chain = [fliplr(obj.superclasses(className)), {className}];
        end

        function fields = ownFields(obj, className)
            % ownFields - cell array of field defs the class declares
            %   directly (not inherited).
            arguments
                obj
                className (1,:) char
            end
            s = obj.getClass(className);
            if ~isstruct(s) || ~isfield(s, 'fields') || isempty(s.fields)
                fields = {};
                return;
            end
            fields = obj.toCellArray(s.fields);
        end

        function tagged = fieldsFor(obj, className)
            % fieldsFor - merged inherited fields tagged with the
            %   declaring class. Returns a struct array with fields
            %   `declaringClass` (char) and `fieldDef` (the schema's
            %   `fields` entry).
            arguments
                obj
                className (1,:) char
            end
            tagged = struct('declaringClass', {}, 'fieldDef', {});
            chain = obj.classChain(className);
            for k = 1:numel(chain)
                own = obj.ownFields(chain{k});
                for f = 1:numel(own)
                    tagged(end+1) = struct( ...
                        'declaringClass', chain{k}, ...
                        'fieldDef', own{f}); %#ok<AGROW>
                end
            end
        end

        function loadAllSchemas(obj)
            % loadAllSchemas - parse every *.json schema in the schema
            %   directory and populate the loaded-classes map. Skips
            %   meta files (CURIE_lookups_meta.json, ndi_reserved_keys.json).
            %   Used by the SQLite backend at open-time so queryablePaths
            %   returns a deterministic set independent of which classes
            %   have been touched so far in this session.
            if ~isfolder(obj.schemaPath)
                return;
            end
            entries = dir(fullfile(obj.schemaPath, '*.json'));
            for k = 1:numel(entries)
                [~, name, ~] = fileparts(entries(k).name);
                if endsWith(name, '_meta') ...
                        || strcmp(name, 'ndi_reserved_keys')
                    continue;
                end
                if ~obj.loadedClasses.isKey(name)
                    obj.getClass(name);  % side effect: caches the parse.
                end
            end
        end

        function paths = queryablePaths(obj)
            % queryablePaths - the set of class-qualified queryable
            %   dot-paths declared by the schemas currently loaded in
            %   the cache. Used by the SQL backend to drive the
            %   generated columns (§3.2) and (eventually) the
            %   queryable_array_elem sidecar (§3.3).
            %
            %   Returns a struct with two fields:
            %     .scalar  - struct array; one entry per scalar queryable
            %                path. Each entry has:
            %                  .path           class-qualified dot-path
            %                                  (e.g., 'base.session_id').
            %                  .declaringClass declaring class name.
            %                  .fieldName      the field's own name.
            %                  .type           the schema's type string
            %                                  ('char', 'did_uid', ...).
            %                  .column         generated-column name
            %                                  ('q_' + path with '.' -> '_').
            %                  .affinity       SQLite type affinity for
            %                                  the column ('TEXT', 'REAL',
            %                                  or 'INTEGER').
            %     .array   - struct array; one entry per queryable scalar
            %                sub-field of an array-of-structure field.
            %                Each entry has:
            %                  .path           full '[*]'-bearing dot-path
            %                                  (e.g., 'demoArray.axes[*].unit').
            %                  .declaringClass declaring class name.
            %                  .parentField    the array-of-structure field
            %                                  name (e.g., 'axes').
            %                  .parentPath     class-qualified parent path
            %                                  (e.g., 'demoArray.axes').
            %                  .subField       the queryable sub-field name
            %                                  inside each element
            %                                  (e.g., 'unit').
            %                  .type           the sub-field's schema type
            %                                  string.
            %                  .affinity       SQLite type affinity for the
            %                                  sub-field ('TEXT', 'REAL',
            %                                  or 'INTEGER').
            %
            %   Run loadAllSchemas() first if you need a deterministic
            %   set independent of which classes have been touched.
            scalar = struct('path', {}, 'declaringClass', {}, ...
                'fieldName', {}, 'type', {}, ...
                'column', {}, 'affinity', {});
            arrayPaths = struct('path', {}, 'declaringClass', {}, ...
                'parentField', {}, 'parentPath', {}, ...
                'subField', {}, 'type', {}, 'affinity', {});
            seenScalar = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            seenArray  = containers.Map('KeyType', 'char', 'ValueType', 'logical');

            keys = obj.loadedClasses.keys();
            for k = 1:numel(keys)
                className = keys{k};
                schema = obj.loadedClasses(className);
                if ~isstruct(schema) || ~isfield(schema, 'fields') ...
                        || isempty(schema.fields)
                    continue;
                end
                own = obj.toCellArray(schema.fields);
                for f = 1:numel(own)
                    fieldDef = own{f};
                    fieldName = char(fieldDef.name);
                    fieldType = char(fieldDef.type);
                    path = sprintf('%s.%s', className, fieldName);
                    if obj.fieldIsScalar(fieldDef)
                        if ~obj.fieldIsQueryable(fieldDef) || seenScalar.isKey(path)
                            continue;
                        end
                        seenScalar(path) = true;
                        scalar(end+1) = struct( ...
                            'path', path, ...
                            'declaringClass', className, ...
                            'fieldName', fieldName, ...
                            'type', fieldType, ...
                            'column', did2.schema.cache.columnNameFor(path), ...
                            'affinity', did2.schema.cache.affinityFor(fieldType)); %#ok<AGROW>
                    elseif strcmp(fieldType, 'structure') ...
                            && obj.fieldIsQueryable(fieldDef) ...
                            && isfield(fieldDef, 'fields') ...
                            && ~isempty(fieldDef.fields)
                        % Array-of-structure: emit one entry per queryable
                        % scalar sub-field inside the element template.
                        subEntries = obj.toCellArray(fieldDef.fields);
                        for s = 1:numel(subEntries)
                            subDef = subEntries{s};
                            if ~obj.fieldIsQueryable(subDef) ...
                                    || ~obj.fieldIsScalar(subDef)
                                continue;
                            end
                            subName = char(subDef.name);
                            subType = char(subDef.type);
                            fullPath = sprintf('%s[*].%s', path, subName);
                            if seenArray.isKey(fullPath)
                                continue;
                            end
                            seenArray(fullPath) = true;
                            arrayPaths(end+1) = struct( ...
                                'path', fullPath, ...
                                'declaringClass', className, ...
                                'parentField', fieldName, ...
                                'parentPath', path, ...
                                'subField', subName, ...
                                'type', subType, ...
                                'affinity', did2.schema.cache.affinityFor(subType)); %#ok<AGROW>
                        end
                    end
                end
            end

            paths = struct('scalar', {scalar}, 'array', {arrayPaths});
        end

        function doc = buildBlankDocument(obj, className)
            % buildBlankDocument - blank V_delta document in the
            %   class-scoped wire shape. Mints a fresh did_uid for
            %   base.id and the current UTC timestamp for base.datestamp.
            arguments
                obj
                className (1,:) char
            end
            doc = struct();
            schema = obj.getClass(className);
            schemaDC = schema.document_class;

            ancestors = obj.superclasses(className);
            sc = struct('class_name', {}, 'class_version', {});
            for k = 1:numel(ancestors)
                ancDC = obj.getClass(ancestors{k}).document_class;
                sc(end+1) = struct( ...
                    'class_name', char(ancDC.class_name), ...
                    'class_version', char(ancDC.class_version)); %#ok<AGROW>
            end
            doc.document_class = struct( ...
                'class_name', char(schemaDC.class_name), ...
                'class_version', char(schemaDC.class_version), ...
                'superclasses', sc);

            doc.depends_on = struct('name', {}, 'value', {});

            chain = obj.classChain(className);
            for k = 1:numel(chain)
                blockClass = chain{k};
                doc.(blockClass) = obj.buildBlockForClass(blockClass);
            end
        end

        function validateDocument(obj, docOrStruct)
            % validateDocument - raise did2:validation:* on a
            %   non-conforming document. Accepts a did2.document or a
            %   plain struct.
            arguments
                obj
                docOrStruct
            end
            if isa(docOrStruct, 'did2.document')
                s = docOrStruct.toStruct();
            elseif isstruct(docOrStruct)
                s = docOrStruct;
            else
                error('did2:validation:badInput', ...
                    'validateDocument expects a did2.document or a struct, got %s.', ...
                    class(docOrStruct));
            end
            if ~isfield(s, 'document_class') || ~isstruct(s.document_class)
                error('did2:validation:missingClassName', ...
                    'Document has no document_class header; cannot validate.');
            end
            dc = s.document_class;
            if ~isfield(dc, 'class_name') || isempty(dc.class_name)
                error('did2:validation:missingClassName', ...
                    'Document has no document_class.class_name; cannot validate.');
            end
            className = char(dc.class_name);
            classSchema = obj.getClass(className);
            if isfield(classSchema, 'document_class') ...
                    && isstruct(classSchema.document_class) ...
                    && isfield(classSchema.document_class, 'abstract') ...
                    && classSchema.document_class.abstract == true
                error('did2:validation:abstractInstantiation', ...
                    ['Class "%s" is declared abstract; documents must ' ...
                     'instantiate a concrete subclass.'], className);
            end
            chain = obj.classChain(className);
            for k = 1:numel(chain)
                blockClass = chain{k};
                if ~isfield(s, blockClass)
                    error('did2:validation:missingClassBlock', ...
                        'Document is missing the "%s" property block.', blockClass);
                end
                block = s.(blockClass);
                if ~isstruct(block)
                    error('did2:validation:badClassBlock', ...
                        'Property block "%s" must be a struct, got %s.', ...
                        blockClass, class(block));
                end
                own = obj.ownFields(blockClass);
                for f = 1:numel(own)
                    fieldDef = own{f};
                    obj.validateField(block, fieldDef, blockClass, char(fieldDef.name));
                end
            end
        end
    end

    methods (Static)
        function obj = shared(varargin)
            % shared - return the process-wide cache singleton.
            persistent instance
            if nargin == 1 && ischar(varargin{1}) && strcmp(varargin{1}, '-reset')
                instance = [];
                obj = [];
                return;
            end
            if isempty(instance) || ~isvalid(instance)
                if nargin >= 1 && ~isempty(varargin{1})
                    schemaPath = varargin{1};
                else
                    schemaPath = did2.schema.cache.defaultSchemaPath();
                end
                instance = did2.schema.cache(schemaPath);
            end
            obj = instance;
        end

        function setSchemaPath(schemaPath)
            % setSchemaPath - rebuild the singleton at a new schema path.
            arguments
                schemaPath (1,:) char
            end
            did2.schema.cache.shared('-reset');
            did2.schema.cache.shared(schemaPath);
        end

        function resetSingleton()
            % resetSingleton - drop the cached singleton.
            did2.schema.cache.shared('-reset');
        end
    end

    methods (Static, Access = private)
        function p = defaultSchemaPath()
            envOverride = getenv('DID_SCHEMA_PATH');
            if ~isempty(envOverride)
                p = envOverride;
                return;
            end
            toolboxDir = did.toolboxdir();
            % did.toolboxdir() resolves to <DID-matlab>/src/did, so
            % three '..'s land at the *sibling* of DID-matlab where a
            % did-schema checkout typically lives. (The previous two
            % '..'s expected did-schema *inside* DID-matlab.)
            p = fullfile(toolboxDir, '..', '..', '..', 'did-schema', 'schemas', 'V_delta', 'stable');
        end

        function ts = currentUTCTimestamp()
            dt = datetime('now', 'TimeZone', 'UTC');
            dt.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
            ts = char(string(dt));
        end

        function len = stringLength(value)
            if isstring(value)
                len = strlength(value);
                if numel(len) > 1
                    len = max(len);
                end
            elseif ischar(value)
                len = numel(value);
            else
                len = 0;
            end
        end

        function name = columnNameFor(path)
            % columnNameFor - canonical SQLite generated-column name for a
            %   class-qualified dot-path. 'base.session_id' ->
            %   'q_base_session_id'; 'demoA.value' -> 'q_demoa_value'.
            %   Always lowercase so the convention round-trips cleanly
            %   through `pragma_table_info` (which reports column names
            %   in the case SQLite parses them) regardless of how the
            %   class names happen to be spelled in the V_delta schema
            %   files.
            name = ['q_' lower(strrep(path, '.', '_'))];
        end

        function aff = affinityFor(fieldType)
            % affinityFor - SQLite type affinity for a V_delta scalar type.
            switch fieldType
                case {'char', 'did_uid', 'timestamp', 'string'}
                    aff = 'TEXT';
                case {'boolean', 'integer'}
                    aff = 'INTEGER';
                case {'double', 'matrix'}
                    aff = 'REAL';
                otherwise
                    aff = '';  % no declared affinity for unknown types
            end
        end
    end

    methods (Access = private)
        function loadRegistry(obj)
            registryFile = fullfile(obj.schemaPath, 'CURIE_lookups_meta.json');
            if isfile(registryFile)
                obj.curieRegistry = jsondecode(fileread(registryFile));
            end
        end

        function out = toCellArray(~, raw)
            if iscell(raw)
                out = raw(:)';
            elseif isstruct(raw)
                out = arrayfun(@(i) raw(i), 1:numel(raw), 'UniformOutput', false);
            else
                out = {raw};
            end
        end

        function tf = fieldIsQueryable(~, fieldDef)
            tf = isstruct(fieldDef) && isfield(fieldDef, 'queryable') ...
                && logical(fieldDef.queryable);
        end

        function tf = fieldIsScalar(~, fieldDef)
            % Treat queryable mustBeScalar fields as scalar paths. Fields
            % without an explicit mustBeScalar default to scalar; only
            % mustBeScalar==false marks a field as an array.
            tf = true;
            if isstruct(fieldDef) && isfield(fieldDef, 'mustBeScalar')
                tf = logical(fieldDef.mustBeScalar);
            end
        end

        function elem = elementAt(obj, raw, idx)
            cells = obj.toCellArray(raw);
            elem = cells{idx};
        end

        function block = buildBlockForClass(obj, className)
            % buildBlockForClass - one property block populated with
            %   `blank_value` for every field the class declares
            %   directly. Base block also receives a fresh did_uid for
            %   `id` and the current UTC timestamp for `datestamp`.
            block = struct();
            own = obj.ownFields(className);
            for f = 1:numel(own)
                fieldDef = own{f};
                fieldName = char(fieldDef.name);
                blank = fieldDef.blank_value;
                fieldType = char(fieldDef.type);
                if strcmp(fieldType, 'structure') ...
                        && (isempty(blank) || (isstruct(blank) && isempty(fieldnames(blank))))
                    block.(fieldName) = obj.buildBlankStructure(fieldDef);
                else
                    block.(fieldName) = blank;
                end
            end
            if strcmp(className, 'base')
                if isfield(block, 'id')
                    block.id = did.ido.unique_id();
                end
                if isfield(block, 'datestamp')
                    block.datestamp = did2.schema.cache.currentUTCTimestamp();
                end
            end
        end

        function s = buildBlankStructure(obj, fieldDef)
            s = struct();
            if ~isfield(fieldDef, 'fields') || isempty(fieldDef.fields)
                return;
            end
            entries = obj.toCellArray(fieldDef.fields);
            for k = 1:numel(entries)
                subDef = entries{k};
                subName = char(subDef.name);
                subBlank = subDef.blank_value;
                subType = char(subDef.type);
                if strcmp(subType, 'structure') ...
                        && (isempty(subBlank) || (isstruct(subBlank) && isempty(fieldnames(subBlank))))
                    s.(subName) = obj.buildBlankStructure(subDef);
                else
                    s.(subName) = subBlank;
                end
            end
        end

        function validateField(obj, block, fieldDef, blockClass, fieldName)
            % validateField - apply type, mustBe* flags, and
            %   constraints for one field against the property block.
            %   Skips absent fields unless the schema marks them
            %   mustBeNonEmpty.
            mustBeNonEmpty = logical(fieldDef.mustBeNonEmpty);
            if ~isfield(block, fieldName)
                if mustBeNonEmpty
                    error('did2:validation:missingField', ...
                        'Required field "%s.%s" is missing.', ...
                        blockClass, fieldName);
                end
                return;
            end
            value = block.(fieldName);
            fieldType = char(fieldDef.type);
            qualifiedName = sprintf('%s.%s', blockClass, fieldName);
            obj.validateTypeShape(value, fieldType, qualifiedName);

            mustBeScalar   = logical(fieldDef.mustBeScalar);
            mustNotHaveNaN = logical(fieldDef.mustNotHaveNaN);
            if mustBeNonEmpty && obj.isEmptyValue(value)
                error('did2:validation:emptyField', ...
                    'Field "%s" is required to be non-empty.', qualifiedName);
            end
            if mustBeScalar && ~obj.isScalarValue(value, fieldType)
                error('did2:validation:notScalar', ...
                    'Field "%s" is required to be scalar.', qualifiedName);
            end
            if mustNotHaveNaN && isnumeric(value) && any(isnan(value(:)))
                error('did2:validation:nanValue', ...
                    'Field "%s" contains NaN.', qualifiedName);
            end
            constraints = fieldDef.constraints;
            if isstruct(constraints) && ~isempty(fieldnames(constraints))
                obj.validateConstraints(value, constraints, fieldType, qualifiedName);
            end
        end

        function tf = isEmptyValue(~, value)
            if isstring(value)
                tf = all(strlength(value) == 0);
            elseif ischar(value)
                tf = isempty(value);
            elseif isstruct(value)
                tf = isempty(value) || isempty(fieldnames(value));
            else
                tf = isempty(value);
            end
        end

        function tf = isScalarValue(~, value, fieldType)
            switch fieldType
                case {'char', 'string', 'did_uid', 'timestamp'}
                    tf = (ischar(value) && (isempty(value) || size(value,1) <= 1)) ...
                        || (isstring(value) && isscalar(value));
                otherwise
                    tf = isscalar(value);
            end
        end

        function validateTypeShape(~, value, fieldType, qualifiedName)
            switch fieldType
                case {'char', 'did_uid', 'timestamp'}
                    if ~(ischar(value) || (isstring(value) && isscalar(value)))
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be char/string (type %s).', qualifiedName, fieldType);
                    end
                case 'string'
                    if ~(ischar(value) || isstring(value))
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be string.', qualifiedName);
                    end
                case 'boolean'
                    if ~(islogical(value) || (isnumeric(value) && all(value(:) == 0 | value(:) == 1)))
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be boolean.', qualifiedName);
                    end
                case 'integer'
                    if ~isnumeric(value) || any(mod(value(:), 1) ~= 0)
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be integer.', qualifiedName);
                    end
                case {'double', 'matrix'}
                    if ~isnumeric(value)
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be numeric.', qualifiedName);
                    end
                case 'structure'
                    if ~isstruct(value)
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be a struct.', qualifiedName);
                    end
                case {'duration','volume','mass','length','voltage','current','frequency','concentration','ontology_term'}
                    if ~isstruct(value)
                        error('did2:validation:typeMismatch', ...
                            'Field "%s" must be a struct (named composite type %s).', ...
                            qualifiedName, fieldType);
                    end
                otherwise
                    % Unknown type - tolerated; the meta-schema's enum gates
                    % new types, so an unknown means tooling drift.
            end
        end

        function validateConstraints(~, value, constraints, ~, qualifiedName)
            cnames = fieldnames(constraints);
            for k = 1:numel(cnames)
                cname = cnames{k};
                cval = constraints.(cname);
                switch cname
                    case 'maxLength'
                        len = did2.schema.cache.stringLength(value);
                        if len > cval
                            error('did2:validation:maxLength', ...
                                'Field "%s" exceeds maxLength %d (got %d).', qualifiedName, cval, len);
                        end
                    case 'minLength'
                        len = did2.schema.cache.stringLength(value);
                        if len < cval
                            error('did2:validation:minLength', ...
                                'Field "%s" below minLength %d (got %d).', qualifiedName, cval, len);
                        end
                    case 'minimum'
                        if isnumeric(value) && any(value(:) < cval)
                            error('did2:validation:minimum', ...
                                'Field "%s" below minimum %g.', qualifiedName, cval);
                        end
                    case 'maximum'
                        if isnumeric(value) && any(value(:) > cval)
                            error('did2:validation:maximum', ...
                                'Field "%s" above maximum %g.', qualifiedName, cval);
                        end
                    case 'enum'
                        choices = string(cval);
                        v = string(value);
                        if ~any(strcmp(v, choices))
                            error('did2:validation:enum', ...
                                'Field "%s" value "%s" not in enum.', qualifiedName, v);
                        end
                    otherwise
                        % Unrecognised constraint keys are tolerated;
                        % `pattern` and similar can be added later.
                end
            end
        end
    end
end
