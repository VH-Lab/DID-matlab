classdef document < handle
    % did2.document  V2 document object.
    %
    %   Holds a single V2 document in the class-scoped wire shape
    %   (see the V2 SPEC's "JSON Format: Document Instances"), validates
    %   it against the V2 schema set, and serialises it back to JSON.
    %
    %   In-memory representation. The V2 document shape carries a
    %   top-level `document_class` header (with sub-keys `class_name`,
    %   `class_version`, `superclasses`), plus a top-level `depends_on`
    %   array, plus one property block per class in the chain keyed by
    %   class name. After V2's "drop underscore prefixes" pass,
    %   every key in the wire shape is a valid MATLAB struct field name,
    %   so the in-memory representation is the JSON shape verbatim.
    %   `jsonencode`/`jsondecode` round-trip without any name-rewrite
    %   pass.
    %
    %   did2.document Properties:
    %       documentProperties - struct mirroring the V2 JSON shape.
    %
    %   did2.document Methods:
    %       document     - construct from JSON text, a struct, or
    %                      (className, valueStruct).
    %       get          - dot-path getter into documentProperties.
    %       set          - dot-path setter into documentProperties.
    %       iterate      - element iterator over an array-of-structure path.
    %       toJSON       - serialise to V2 JSON text.
    %       toStruct     - return the underlying struct.
    %       className    - shorthand for document_class.class_name.
    %       classVersion - shorthand for document_class.class_version.
    %       validate     - validate this document against its schema.
    %
    %   did2.document Static Methods:
    %       fromJSON     - construct from a JSON string.
    %       fromStruct   - construct from a struct.
    %       blank        - construct a blank instance of the named class.
    %
    %   See also: did2.schema.cache.

    properties
        documentProperties (1,1) struct = struct()
    end

    properties (Access = private)
        schemaCacheHandle = []
        % the cache this document was last validated with; toJSON asks it
        % which fields are `matrix` (see toJSON)
        validatedCacheHandle = []
    end

    methods
        function obj = document(varargin)
            % document - construct a did2.document.
            %
            %   D = did2.document() creates an empty document.
            %   D = did2.document(jsonText) parses a JSON string.
            %   D = did2.document(s) wraps an existing struct.
            %   D = did2.document(className, valueStruct) builds a blank
            %       instance of className and overlays valueStruct.

            if nargin == 0
                return;
            end

            firstArg = varargin{1};
            if nargin == 1 && (ischar(firstArg) || (isstring(firstArg) && isscalar(firstArg)))
                obj.documentProperties = did2.document.parseJSONText(firstArg);
            elseif nargin == 1 && isstruct(firstArg)
                obj.documentProperties = firstArg;
            elseif nargin >= 1 && (ischar(firstArg) || (isstring(firstArg) && isscalar(firstArg))) ...
                    && nargin == 2 && isstruct(varargin{2})
                obj.documentProperties = did2.document.buildBlank(char(firstArg));
                obj.documentProperties = did2.document.mergeStruct( ...
                    obj.documentProperties, varargin{2});
            else
                error('did2:document:badInput', ...
                    'did2.document accepts (), (jsonText), (struct), or (className, valueStruct).');
            end
        end

        function value = get(obj, fieldPath)
            % get - read documentProperties at a dot-path.
            %
            %   v = doc.get('base.id') returns the id from the base
            %   property block. `[*]` array iteration is handled by
            %   `iterate(arrayPath)`, not by this method.
            %   'base.session_id' is read from the `session_id` edge when
            %   the document has no such field (see did2.schema.cache.sessionIdOf).
            arguments
                obj
                fieldPath (1,:) char
            end
            if strcmp(fieldPath, 'base.session_id')
                % THE ONE ALIAS, the same one did2.query answers: on a V_eta
                % schema where `base.session_id` became the required
                % `session_id` edge (did-schema
                % V_eta_relation_inheritance_plan.md, 2026-10-20), a document
                % without the field reads its session id from the edge. Only
                % READ: set() still writes the literal path.
                p = obj.documentProperties;
                if ~(isfield(p, 'base') && isstruct(p.base) && isfield(p.base, 'session_id'))
                    value = did2.schema.cache.sessionIdOf(p);
                    if ~isempty(value)
                        return;
                    end
                end
            end
            value = did2.document.dotPathGet(obj.documentProperties, fieldPath);
        end

        function obj = set(obj, fieldPath, value)
            % set - write a value at a dot-path inside documentProperties.
            arguments
                obj
                fieldPath (1,:) char
                value
            end
            obj.documentProperties = did2.document.dotPathSet( ...
                obj.documentProperties, fieldPath, value);
        end

        function elements = iterate(obj, arrayPath)
            % iterate - return the element list at an array-of-structure path.
            arguments
                obj
                arrayPath (1,:) char
            end
            elements = did2.document.dotPathGet(obj.documentProperties, arrayPath);
            if isempty(elements)
                elements = struct([]);
            elseif ~isstruct(elements)
                error('did2:document:notArrayOfStructure', ...
                    'Path "%s" is not an array-of-structure field.', arrayPath);
            end
        end

        function jsonText = toJSON(obj, opts)
            % toJSON - serialise documentProperties to V2 JSON text.
            %
            %   TXT = D.toJSON() / D.toJSON('PrettyPrint', true,
            %   'SchemaCache', C)
            %
            %   `jsonencode`, except for a field the schema types `matrix`
            %   (data_body AMENDMENT 4, did-schema #88: a numeric N-D array,
            %   "row-major as JSON nested arrays"). `jsonencode` writes a 1xN
            %   row and an Nx1 column alike as a flat [a,b,c], and `jsondecode`
            %   reads every flat array back as a COLUMN, so a row vector would
            %   come back transposed. A non-empty `matrix` value is therefore
            %   written with EVERY dimension present: a 1xN row is [[a,b,c]],
            %   an Nx1 column [[a],[b],[c]], an n x 3 palette [[r,g,b],...], a
            %   scalar [[x]] -- and plain `jsondecode` reads each back at the
            %   shape it was written. Numbers are written in the shortest
            %   decimal (15 to 17 significant digits) that reads back to the
            %   same double; a non-finite one is NaN, Infinity or -Infinity, as
            %   the rest of the text writes it (below).
            %
            %   NON-FINITE NUMBERS ARE WRITTEN AS V1 WRITES THEM (Jess Haley,
            %   2026-10-21, did-schema V_eta_go_forward_class_audit.md: "An
            %   unrecorded amount is written as NaN in its quantity [...], and
            %   V2 stores NaN the way V1 does"). V1 encodes with
            %   did.datastructures.jsonencodenan, i.e. jsonencode(...,
            %   'ConvertInfAndNaN', false): the literals NaN, Infinity and
            %   -Infinity, which jsondecode reads back. Plain jsonencode writes
            %   null, and jsondecode reads a scalar null back as [] -- a NaN
            %   amount would come out of the database ABSENT. SQLite's JSON
            %   functions read the literals as JSON5 (NaN as null, Infinity as
            %   a real); testSqliteDbNonFinite pins all of it.
            %
            %   Which fields are matrices is asked of the schema
            %   (did2.schema.cache/matrixFieldPaths): the cache given here,
            %   else the one this document was last validated with (so a
            %   did2.database.sqlitedb write, which validates and then calls
            %   toJSON, uses the database's own), else the shared one. When no
            %   schema can say -- an unknown class, no schema path -- the text
            %   is plain `jsonencode`, as it always was; so is every document
            %   whose class declares no `matrix` field.
            arguments
                obj
                opts.PrettyPrint (1,1) logical = false
                opts.SchemaCache = []
            end
            paths = obj.matrixPaths(opts.SchemaCache);
            if isempty(paths)
                jsonText = jsonencode(obj.documentProperties, ...
                    'ConvertInfAndNaN', false, 'PrettyPrint', opts.PrettyPrint);
                return;
            end
            jsonText = did2.document.encodeWithMatrices( ...
                obj.documentProperties, paths, opts.PrettyPrint);
        end

        function s = toStruct(obj)
            s = obj.documentProperties;
        end

        function name = className(obj)
            % className - the document's `document_class.class_name`.
            if isfield(obj.documentProperties, 'document_class') ...
                    && isstruct(obj.documentProperties.document_class) ...
                    && isfield(obj.documentProperties.document_class, 'class_name')
                name = char(obj.documentProperties.document_class.class_name);
            else
                error('did2:document:missingField', ...
                    'Document has no document_class.class_name.');
            end
        end

        function v = classVersion(obj)
            % classVersion - the document's `document_class.class_version`.
            if isfield(obj.documentProperties, 'document_class') ...
                    && isstruct(obj.documentProperties.document_class) ...
                    && isfield(obj.documentProperties.document_class, 'class_version')
                v = char(obj.documentProperties.document_class.class_version);
            else
                error('did2:document:missingField', ...
                    'Document has no document_class.class_version.');
            end
        end

        function validate(obj, opts)
            % validate - check this document against its V2 schema.
            arguments
                obj
                opts.SchemaCache = []
            end
            cache = obj.resolveSchemaCache(opts.SchemaCache);
            cache.validateDocument(obj);
            % remembered for toJSON only (which fields are matrices): a
            % database validates with its own cache and then serialises
            obj.validatedCacheHandle = cache;
        end
    end

    methods (Static)
        function obj = fromJSON(jsonText, opts)
            % fromJSON - parse JSON document text.
            %
            %   D = did2.document.fromJSON(TXT)
            %   D = did2.document.fromJSON(TXT, 'SchemaCache', C)
            %
            %   PASS THE CACHE WHEN THE TEXT CAME OUT OF A DATABASE. JSON
            %   cannot carry every MATLAB shape -- an empty array of
            %   structs decodes as a 0x0 double, and a ragged array of
            %   objects decodes as a cell -- so a document that validated
            %   on the way in can fail on the way out. `rehydrate` restores
            %   the declared shapes, and it needs a schema to do it.
            %
            %   WITHOUT a cache this is raw `jsondecode` shapes, on
            %   purpose: this is the low-level parser, the scaffold tests
            %   use it with no schema path set, and silently reaching for
            %   the singleton would make those depend on global state.
            %   `did2.database.sqlitedb` -- which is where the round trip
            %   actually happens, and which already resolves a cache for
            %   `add` -- passes one at every read site.
            arguments
                jsonText (1,:) char
                opts.SchemaCache = []
            end
            obj = did2.document(jsonText);
            if ~isempty(opts.SchemaCache)
                obj.documentProperties = ...
                    opts.SchemaCache.rehydrate(obj.documentProperties);
            end
        end

        function obj = fromStruct(s)
            arguments
                s (1,1) struct
            end
            obj = did2.document(s);
        end

        function obj = blank(className, opts)
            % blank - construct a blank V2 document of the named class.
            arguments
                className (1,:) char
                opts.SchemaCache = []
            end
            obj = did2.document();
            obj.documentProperties = did2.document.buildBlank(className, opts.SchemaCache);
        end

        function value = dotPathGet(s, fieldPath)
            arguments
                s
                fieldPath (1,:) char
            end
            if contains(fieldPath, '[*]')
                error('did2:document:arrayPathHere', ...
                    ['"%s" contains [*]; use iterate() for ' ...
                     'array-of-structure traversal.'], fieldPath);
            end
            parts = strsplit(fieldPath, '.');
            value = s;
            for k = 1:numel(parts)
                segment = parts{k};
                if ~isstruct(value) || ~isfield(value, segment)
                    error('did2:document:missingField', ...
                        'Field "%s" not present while resolving "%s".', ...
                        segment, fieldPath);
                end
                value = value.(segment);
            end
        end

        function s = dotPathSet(s, fieldPath, value)
            arguments
                s (1,1) struct
                fieldPath (1,:) char
                value
            end
            parts = strsplit(fieldPath, '.');
            s = did2.document.assignNested(s, parts, value);
        end
    end

    methods (Static, Access = private)
        function txt = encodeWithMatrices(props, paths, pretty)
            % encodeWithMatrices - jsonencode PROPS with every non-empty value
            %   at PATHS written by nestedArrayText. Each such value is first
            %   replaced by a placeholder string, the struct is encoded, and
            %   each quoted placeholder is replaced by the array's text. A
            %   placeholder that is not found exactly once (the document's
            %   own text contains it) is lengthened and the encoding redone.
            base = 'DID2MATRIX';
            while true
                texts = {};
                p = props;
                for i = 1:numel(paths)
                    [p, texts] = did2.document.tokeniseMatrices(p, paths{i}, texts, base);
                end
                txt = jsonencode(p, 'ConvertInfAndNaN', false, 'PrettyPrint', pretty);
                if isempty(texts)
                    return;
                end
                isUnique = true;
                for k = 1:numel(texts)
                    if numel(strfind(txt, ['"' base sprintf('%dX', k) '"'])) ~= 1
                        isUnique = false;
                        break;
                    end
                end
                if isUnique
                    break;
                end
                base = [base 'Z']; %#ok<AGROW>
            end
            for k = 1:numel(texts)
                txt = strrep(txt, ['"' base sprintf('%dX', k) '"'], texts{k});
            end
        end

        function [v, texts] = tokeniseMatrices(v, path, texts, base)
            % tokeniseMatrices - replace each non-empty numeric value at PATH
            %   (field names; struct arrays and cells walked element-wise) by
            %   a placeholder, and append its array text to TEXTS.
            if isempty(path)
                if (isnumeric(v) || islogical(v)) && ~isempty(v) && isreal(v) && ~issparse(v)
                    texts{end+1} = did2.document.nestedArrayText(v);
                    v = sprintf('%s%dX', base, numel(texts));
                end
                return;
            end
            name = path{1};
            if isstruct(v)
                if ~isfield(v, name)
                    return;
                end
                for k = 1:numel(v)
                    [sub, texts] = did2.document.tokeniseMatrices( ...
                        v(k).(name), path(2:end), texts, base);
                    v(k).(name) = sub;
                end
            elseif iscell(v)
                for k = 1:numel(v)
                    [v{k}, texts] = did2.document.tokeniseMatrices(v{k}, path, texts, base);
                end
            end
        end

        function t = nestedArrayText(x)
            % nestedArrayText - X as row-major JSON nested arrays, one level
            %   per dimension (size(X) as MATLAB reports it, so at least 2):
            %   the first index outermost, which is how jsondecode reads it.
            t = did2.document.nestDims(x, size(x));
        end

        function t = nestDims(x, sz)
            if numel(sz) == 1
                t = ['[' strjoin(did2.document.numberTexts(x), ',') ']'];
                return;
            end
            flat = reshape(x, sz(1), []);
            parts = cell(1, sz(1));
            for i = 1:sz(1)
                parts{i} = did2.document.nestDims(flat(i, :), sz(2:end));
            end
            t = ['[' strjoin(parts, ',') ']'];
        end

        function c = numberTexts(x)
            % numberTexts - each element of X as JSON number text: the
            %   shortest of 15/16/17 significant digits that reads back to the
            %   same double; NaN / Infinity / -Infinity when not finite, as
            %   jsonencode(..., 'ConvertInfAndNaN', false) spells them (toJSON);
            %   true/false for a logical.
            x = reshape(x, 1, []);
            if islogical(x)
                c = cell(1, numel(x));
                c(x) = {'true'};
                c(~x) = {'false'};
                return;
            end
            x = double(x);
            c = cellstr(compose('%.15g', x));
            for digits = [16 17]
                bad = str2double(c) ~= x & isfinite(x);
                if ~any(bad)
                    break;
                end
                c(bad) = cellstr(compose(sprintf('%%.%dg', digits), x(bad)));
            end
            c(isnan(x)) = {'NaN'};
            c(x == Inf) = {'Infinity'};
            c(x == -Inf) = {'-Infinity'};
        end

        function out = parseJSONText(jsonText)
            text = char(jsonText);
            out = jsondecode(text);
            if ~isstruct(out)
                error('did2:document:jsonNotObject', ...
                    'Top-level JSON value must be an object, got %s.', class(out));
            end
        end

        function s = assignNested(s, parts, value)
            head = parts{1};
            if isscalar(parts)
                s.(head) = value;
                return;
            end
            if isfield(s, head) && isstruct(s.(head))
                inner = s.(head);
            else
                inner = struct();
            end
            s.(head) = did2.document.assignNested(inner, parts(2:end), value);
        end

        function s = mergeStruct(base, overlay)
            s = base;
            if ~isstruct(overlay)
                return;
            end
            f = fieldnames(overlay);
            for k = 1:numel(f)
                name = f{k};
                if isfield(s, name) && isstruct(s.(name)) && isstruct(overlay.(name))
                    s.(name) = did2.document.mergeStruct(s.(name), overlay.(name));
                else
                    s.(name) = overlay.(name);
                end
            end
        end

        function s = buildBlank(className, cacheOverride)
            if nargin < 2
                cacheOverride = [];
            end
            if isempty(cacheOverride)
                cache = did2.schema.cache.shared();
            else
                cache = cacheOverride;
            end
            s = cache.buildBlankDocument(className);
        end
    end

    methods (Access = private)
        function paths = matrixPaths(obj, override)
            % matrixPaths - the document's `matrix` field paths, or {} when no
            %   schema can say (see toJSON).
            paths = {};
            try
                if ~isempty(override)
                    cache = override;
                elseif ~isempty(obj.validatedCacheHandle)
                    cache = obj.validatedCacheHandle;
                else
                    cache = obj.resolveSchemaCache([]);
                end
                if ismethod(cache, 'matrixFieldPaths')
                    paths = cache.matrixFieldPaths(obj.documentProperties);
                end
            catch
                % No schema to ask (no schema path, an unreadable class):
                % plain jsonencode, the writer's behaviour before matrices.
                paths = {};
            end
        end

        function cache = resolveSchemaCache(obj, override)
            if ~isempty(override)
                cache = override;
                return;
            end
            if isempty(obj.schemaCacheHandle)
                obj.schemaCacheHandle = did2.schema.cache.shared();
            end
            cache = obj.schemaCacheHandle;
        end
    end
end
