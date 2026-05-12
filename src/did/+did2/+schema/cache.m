classdef cache < handle
    % did2.schema.cache  V_gamma schema cache.
    %
    %   Loads V_gamma schema files lazily, resolves superclass chains,
    %   builds blank documents in the V_gamma class-scoped wire shape,
    %   and validates documents against their class definitions. See
    %   docs/v2/PLAN.md §5.
    %
    %   Document shape (V_gamma "JSON Format: Document Instances"):
    %     _classname      string         concrete class
    %     _class_version  string         semver of the concrete class
    %     _superclasses   array          [{_classname, _class_version}]
    %     _depends_on     array          [{_name, value}]
    %     <classname>     object         one property block per class in
    %                                    the chain, keyed by _classname.
    %                                    Contains the field values that
    %                                    class declared (empty {} if the
    %                                    class declares no fields).
    %
    %   MATLAB representation: leading-underscore JSON keys can't be
    %   MATLAB struct field names, so we store them with the same `x_`
    %   prefix MATLAB's `jsondecode` produces — `x_classname`,
    %   `x_class_version`, `x_superclasses`, `x_depends_on`. The
    %   class-block keys (`base`, `demoA`, ...) are plain snake_case
    %   identifiers and stay as written. did2.document.toJSON rewrites
    %   `"x_<name>":` back to `"_<name>":` on serialisation; jsondecode
    %   reverses that on parse.
    %
    %   did2.schema.cache Properties:
    %       schemaPath      - filesystem path to a V_gamma schema dir.
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
    %       ownFields           - the _fields list a class declares directly.
    %       fieldsFor           - merged inherited fields tagged with the
    %                             declaring class (struct array).
    %       queryablePaths      - scalar and array-iteration paths (stub).
    %       buildBlankDocument  - blank V_gamma document in the wire shape.
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
            % superclasses - ancestor chain (parent first, root last).
            %   For 'demoA' -> {'base'}. For 'base' -> {}.
            arguments
                obj
                className (1,:) char
            end
            names = {};
            current = className;
            visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            while true
                if visited.isKey(current)
                    error('did2:schema:cycle', ...
                        'Superclass cycle detected starting at "%s".', className);
                end
                visited(current) = true;
                s = obj.getClass(current);
                parents = obj.extractField(s, '_superclasses');
                if isempty(parents)
                    break;
                end
                parent = obj.elementAt(parents, 1);
                parentName = obj.extractField(parent, '_classname');
                names{end+1} = char(parentName); %#ok<AGROW>
                current = char(parentName);
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
            raw = obj.extractField(s, '_fields');
            if isempty(raw)
                fields = {};
            else
                fields = obj.toCellArray(raw);
            end
        end

        function tagged = fieldsFor(obj, className)
            % fieldsFor - merged inherited fields tagged with the
            %   declaring class. Returns a struct array with fields
            %   `declaringClass` (char) and `fieldDef` (the schema's
            %   _fields entry).
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

        function paths = queryablePaths(~, ~) %#ok<STOUT>
            % queryablePaths - planned for steps 3 & 4. Will return
            %   .scalar (cellstr of class-qualified dot-paths like
            %   'daqsystem.sample_rate.hertz') and .array (cellstr of
            %   '[*]'-suffixed paths). Used by the SQL backend to drive
            %   generated columns (§3.2) and the queryable_array_elem
            %   sidecar (§3.3).
            error('did2:notImplemented', ...
                'did2.schema.cache.queryablePaths is not yet implemented (step 3/4).');
        end

        function doc = buildBlankDocument(obj, className)
            % buildBlankDocument - blank V_gamma document in the
            %   class-scoped wire shape. Mints a fresh did_uid for
            %   base.id and the current UTC timestamp for base.datestamp.
            arguments
                obj
                className (1,:) char
            end
            doc = struct();
            schema = obj.getClass(className);
            doc.x_classname     = char(obj.extractField(schema, '_classname'));
            doc.x_class_version = char(obj.extractField(schema, '_class_version'));

            ancestors = obj.superclasses(className);
            sc = struct('x_classname', {}, 'x_class_version', {});
            for k = 1:numel(ancestors)
                ancSchema = obj.getClass(ancestors{k});
                sc(end+1) = struct( ...
                    'x_classname', char(obj.extractField(ancSchema, '_classname')), ...
                    'x_class_version', char(obj.extractField(ancSchema, '_class_version'))); %#ok<AGROW>
            end
            doc.x_superclasses = sc;
            doc.x_depends_on = struct('x_name', {}, 'value', {});

            chain = obj.classChain(className);
            for k = 1:numel(chain)
                blockClass = chain{k};
                block = obj.buildBlockForClass(blockClass);
                doc.(blockClass) = block;
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
            if ~isfield(s, 'x_classname') || isempty(s.x_classname)
                error('did2:validation:missingClassName', ...
                    'Document has no _classname; cannot validate.');
            end
            className = char(s.x_classname);
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
                    fieldName = char(obj.extractField(fieldDef, '_name'));
                    obj.validateField(block, fieldDef, blockClass, fieldName);
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
            p = fullfile(toolboxDir, '..', '..', 'did-schema', 'schemas', 'V_gamma');
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
    end

    methods (Access = private)
        function loadRegistry(obj)
            registryFile = fullfile(obj.schemaPath, 'CURIE_lookups_meta.json');
            if isfile(registryFile)
                obj.curieRegistry = jsondecode(fileread(registryFile));
            end
        end

        function value = extractField(~, s, name)
            % extractField - tolerate jsondecode's leading-underscore
            %   rewrites (`_<x>` becomes `x_<x>`), with backwards-compat
            %   probes for older quirks.
            if ~isstruct(s) && ~isobject(s)
                value = [];
                return;
            end
            candidates = {name, ['x' name], strrep(name, '_', '')};
            for k = 1:numel(candidates)
                if isfield(s, candidates{k})
                    value = s.(candidates{k});
                    return;
                end
            end
            value = [];
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

        function elem = elementAt(obj, raw, idx)
            cells = obj.toCellArray(raw);
            elem = cells{idx};
        end

        function block = buildBlockForClass(obj, className)
            % buildBlockForClass - one property block populated with
            %   _blank_value for every field the class declares
            %   directly. Base block also receives a fresh did_uid for
            %   `id` and the current UTC timestamp for `datestamp`.
            block = struct();
            own = obj.ownFields(className);
            for f = 1:numel(own)
                fieldDef = own{f};
                fieldName = char(obj.extractField(fieldDef, '_name'));
                blank = obj.extractField(fieldDef, '_blank_value');
                fieldType = char(obj.extractField(fieldDef, 'type'));
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
            nested = obj.extractField(fieldDef, '_fields');
            s = struct();
            if isempty(nested)
                return;
            end
            entries = obj.toCellArray(nested);
            for k = 1:numel(entries)
                subDef = entries{k};
                subName = char(obj.extractField(subDef, '_name'));
                subBlank = obj.extractField(subDef, '_blank_value');
                subType = char(obj.extractField(subDef, 'type'));
                if strcmp(subType, 'structure') ...
                        && (isempty(subBlank) || (isstruct(subBlank) && isempty(fieldnames(subBlank))))
                    s.(subName) = obj.buildBlankStructure(subDef);
                else
                    s.(subName) = subBlank;
                end
            end
        end

        function validateField(obj, block, fieldDef, blockClass, fieldName)
            % validateField - apply type, _mustBe* flags, and
            %   _constraints for one field against the property block.
            %   Skips absent fields unless the schema marks them
            %   _mustBeNonEmpty.
            if ~isfield(block, fieldName)
                if obj.extractField(fieldDef, '_mustBeNonEmpty')
                    error('did2:validation:missingField', ...
                        'Required field "%s.%s" is missing.', ...
                        blockClass, fieldName);
                end
                return;
            end
            value = block.(fieldName);
            fieldType = char(obj.extractField(fieldDef, 'type'));
            qualifiedName = sprintf('%s.%s', blockClass, fieldName);
            obj.validateTypeShape(value, fieldType, qualifiedName);

            mustBeNonEmpty = logical(obj.extractField(fieldDef, '_mustBeNonEmpty'));
            mustBeScalar   = logical(obj.extractField(fieldDef, '_mustBeScalar'));
            mustNotHaveNaN = logical(obj.extractField(fieldDef, '_mustNotHaveNaN'));
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
            constraints = obj.extractField(fieldDef, '_constraints');
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
                case {'duration','volume','mass','length','voltage','current','frequency','ontology_term'}
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
