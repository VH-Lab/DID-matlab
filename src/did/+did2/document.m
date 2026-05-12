classdef document < handle
    % did2.document  V_gamma document object.
    %
    %   Holds a single V_gamma document in the class-scoped wire shape
    %   (see V_gamma_SPEC.md "JSON Format: Document Instances"), validates
    %   it against the V_gamma schema set, and serialises it back to JSON.
    %
    %   In-memory representation. The V_gamma document shape carries a
    %   top-level `document_class` header (with sub-keys `class_name`,
    %   `class_version`, `superclasses`), plus a top-level `_depends_on`
    %   array, plus one property block per class in the chain keyed by
    %   class name. `document_class` and its sub-keys, and the class
    %   block keys, are all valid MATLAB identifiers and stay verbatim.
    %   Only `_depends_on` (top-level) and `_name` (inside its entries)
    %   keep MATLAB's `x_` rename — stored as `x_depends_on` and
    %   `x_name`, matching what `jsondecode` produces. `toJSON`
    %   rewrites `"x_<name>":` back to `"_<name>":` on the encoded
    %   output so the wire form matches the spec; `fromJSON` relies on
    %   `jsondecode`'s default rename to read it back in.
    %
    %   did2.document Properties:
    %       documentProperties - struct mirroring the V_gamma JSON shape.
    %
    %   did2.document Methods:
    %       document     - construct from JSON text, a struct, or
    %                      (className, valueStruct).
    %       get          - dot-path getter into documentProperties.
    %       set          - dot-path setter into documentProperties.
    %       iterate      - element iterator over an array-of-structure path.
    %       toJSON       - serialise to V_gamma JSON text.
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
    %   See also: did2.schema.cache, docs/v2/PLAN.md.

    properties
        documentProperties (1,1) struct = struct()
    end

    properties (Access = private)
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
            %   v = doc.get('base.id') returns the id from the base
            %   property block. `[*]` array iteration is handled by
            %   `iterate(arrayPath)`, not by this method.
            arguments
                obj
                fieldPath (1,:) char
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
            % toJSON - serialise documentProperties to V_gamma JSON text.
            %   Internal `x_<name>` keys are rewritten to `_<name>` on
            %   the encoded output to match the spec. Currently the
            %   only two such keys at the document-instance level are
            %   `x_depends_on` (top-level) and `x_name` (inside each
            %   `_depends_on` entry); everything else is already plain.
            arguments
                obj
                opts.PrettyPrint (1,1) logical = false
            end
            raw = jsonencode(obj.documentProperties, ...
                'PrettyPrint', opts.PrettyPrint);
            jsonText = did2.document.rewriteXUnderscoreKeys(raw);
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
            % validate - check this document against its V_gamma schema.
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
            arguments
                jsonText (1,:) char
            end
            obj = did2.document(jsonText);
        end

        function obj = fromStruct(s)
            arguments
                s (1,1) struct
            end
            obj = did2.document(s);
        end

        function obj = blank(className, opts)
            % blank - construct a blank V_gamma document of the named class.
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

        function out = rewriteXUnderscoreKeys(jsonText)
            % rewriteXUnderscoreKeys - convert `"x_<name>":` keys to
            %   `"_<name>":` on the encoded JSON text. The regex matches
            %   only JSON keys (colon-terminated, with optional
            %   whitespace) so values that happen to start with `x_`
            %   are unaffected.
            out = regexprep(jsonText, '"x_([a-zA-Z][a-zA-Z0-9_]*)"(\s*):', '"_$1"$2:');
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
