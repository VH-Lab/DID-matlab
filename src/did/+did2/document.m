classdef document < handle
    % did2.document  V_gamma document object (DID v2 scaffold).
    %
    %   A did2.document holds a single DID document in its V_gamma JSON
    %   shape, validates it against the V_gamma schema set, and serialises
    %   it back to JSON. Unlike did.document, the internal representation
    %   is the flat V_gamma shape directly — no translation to/from the
    %   V_alpha base.* / document_class.* / <property_list_name> nesting.
    %
    %   This is the v2 development scaffold (PLAN.md §9, item 1). The
    %   outer API is intended to stabilise here; internal methods are
    %   filled in iteratively. Stubs throw 'did2:notImplemented' so that
    %   missing pieces surface loudly rather than silently no-op.
    %
    %   did2.document Properties:
    %       documentProperties - struct mirroring the V_gamma JSON shape.
    %
    %   did2.document Methods:
    %       document     - construct from JSON text, a struct, or
    %                      (className, valueStruct).
    %       get          - dot-path getter into documentProperties.
    %       set          - dot-path setter into documentProperties.
    %       iterate      - element iterator over an array-of-structure path
    %                      (used by the in-memory query evaluator for [*]).
    %       toJSON       - serialise to a JSON string.
    %       toStruct     - return the underlying struct.
    %       className    - shorthand for get('_class.name').
    %       classVersion - shorthand for get('_class.version').
    %       validate     - validate this document against its schema.
    %
    %   did2.document Static Methods:
    %       fromJSON     - construct from a JSON string.
    %       fromStruct   - construct from a struct.
    %       blank        - construct a blank instance of the named class.
    %
    %   See also: did2.schema.cache, did.document, docs/v2/PLAN.md.

    properties
        % documentProperties - struct mirroring the V_gamma JSON shape.
        %   Top-level keys are flat snake_case (e.g., id, session_id,
        %   name, datestamp) plus class-defined fields. System metadata
        %   carries a leading underscore (_class, _depends_on, _files).
        documentProperties (1,1) struct = struct()
    end

    properties (Access = private)
        % schemaCacheHandle - lazily resolved did2.schema.cache instance.
        schemaCacheHandle = []
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
            %   v = doc.get('sample_rate.hertz') returns the hertz field
            %   inside the sample_rate named composite. The [*] array
            %   iteration suffix is not handled here — use iterate() for
            %   that, since [*] returns a struct array rather than a scalar.
            arguments
                obj
                fieldPath (1,:) char
            end
            value = did2.document.dotPathGet(obj.documentProperties, fieldPath);
        end

        function obj = set(obj, fieldPath, value)
            % set - write a value at a dot-path inside documentProperties.
            %
            %   doc.set('app.app_name', 'ndi_app_spikeextractor') sets the
            %   nested field, creating intermediate structs as needed.
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
            %
            %   els = doc.iterate('axes') returns the struct array stored
            %   at the 'axes' path. Used by the in-memory query evaluator
            %   to implement the V_gamma '[*]' existential semantics
            %   described in did_query_model.md.
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
            % toJSON - serialise documentProperties to JSON text.
            arguments
                obj
                opts.PrettyPrint (1,1) logical = false
            end
            jsonText = jsonencode(obj.documentProperties, ...
                'PrettyPrint', opts.PrettyPrint);
        end

        function s = toStruct(obj)
            % toStruct - return the underlying documentProperties struct.
            s = obj.documentProperties;
        end

        function name = className(obj)
            % className - shorthand for get('_class.name').
            name = obj.get('_class.name');
        end

        function v = classVersion(obj)
            % classVersion - shorthand for get('_class.version').
            v = obj.get('_class.version');
        end

        function validate(obj, opts)
            % validate - check this document against its V_gamma schema.
            %
            %   doc.validate() resolves the schema cache from the default
            %   path, looks up the document's class definition, and
            %   verifies required fields, type constraints, and the named
            %   composite layouts (ontology_term, duration, length, ...).
            %
            %   doc.validate(SchemaCache=cache) uses the supplied cache
            %   instead of the shared singleton.
            arguments
                obj
                opts.SchemaCache = []
            end
            cache = obj.resolveSchemaCache(opts.SchemaCache);
            cache.validateDocument(obj);
        end
    end

    methods (Static)
        function obj = fromJSON(jsonText)
            % fromJSON - construct a did2.document from a JSON string.
            arguments
                jsonText (1,:) char
            end
            obj = did2.document(jsonText);
        end

        function obj = fromStruct(s)
            % fromStruct - construct a did2.document from a struct.
            arguments
                s (1,1) struct
            end
            obj = did2.document(s);
        end

        function obj = blank(className, opts)
            % blank - construct a blank V_gamma document of the named class.
            %
            %   d = did2.document.blank('app') builds an instance of the
            %   'app' class with every field set to its '_blank_value' as
            %   declared by the V_gamma schema. _class metadata is filled
            %   from the schema; id and datestamp are populated with a
            %   freshly generated did_uid and the current UTC timestamp.
            arguments
                className (1,:) char
                opts.SchemaCache = []
            end
            obj = did2.document();
            obj.documentProperties = did2.document.buildBlank(className, opts.SchemaCache);
        end

        function value = dotPathGet(s, fieldPath)
            % dotPathGet - read a nested value out of struct s by dot-path.
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
            % dotPathSet - write value into struct s at the given dot-path.
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
            if numel(parts) == 1
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
            % mergeStruct - shallow overlay of overlay onto base.
            %   Scalar struct fields in overlay overwrite base; nested
            %   structs recurse. Non-struct values overwrite.
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
            % buildBlank - assemble a blank V_gamma document by walking
            %   the schema cache for className and its superclasses,
            %   populating each field with its _blank_value, then filling
            %   _class metadata, id (freshly minted), session_id (blank),
            %   and datestamp (current UTC).
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
