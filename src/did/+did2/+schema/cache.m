classdef cache < handle
    % did2.schema.cache  V_gamma schema cache (DID v2 scaffold).
    %
    %   Loads all V_gamma schema files once and pre-computes the
    %   structural information that the document, query, and database
    %   layers depend on (PLAN.md §5):
    %
    %     - per-classname full inherited _fields list
    %     - the queryable subset, split into scalar paths and
    %       array-iteration paths
    %     - named composite type expansions (duration -> .seconds /
    %       .approximate / .source_unit / .source_value, ontology_term
    %       -> .node / .name, etc.)
    %     - the CURIE registry from CURIE_lookups_meta.json
    %
    %   Most methods on this scaffold throw 'did2:notImplemented' for
    %   the parts that have not been wired up yet. The shape of the API
    %   is what is being committed here, not the behaviour.
    %
    %   did2.schema.cache Properties:
    %       schemaPath      - filesystem path to a V_gamma schema dir.
    %       loadedClasses   - containers.Map of classname -> raw schema.
    %       curieRegistry   - parsed CURIE_lookups_meta.json contents.
    %
    %   did2.schema.cache Static Methods:
    %       shared          - return the process-wide singleton cache.
    %       setSchemaPath   - override the schema path for the singleton.
    %
    %   did2.schema.cache Methods:
    %       getClass            - resolved class definition for a name.
    %       superclasses        - flat list of ancestors for a class.
    %       fieldsFor           - merged field list across inheritance.
    %       queryablePaths      - scalar and array-iteration paths.
    %       buildBlankDocument  - struct of _blank_value defaults.
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
            % superclasses - ordered list of ancestor classnames (root last).
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
                parent = parents(1);
                parentName = obj.extractField(parent, '_classname');
                names{end+1} = parentName; %#ok<AGROW>
                current = parentName;
            end
        end

        function fields = fieldsFor(~, ~)
            % fieldsFor - return the merged _fields list for className,
            %   walking superclasses root-first so that subclasses can
            %   override (which V_gamma does not currently allow, but
            %   the traversal is stable across future relaxations).
            error('did2:notImplemented', ...
                'did2.schema.cache.fieldsFor is not yet implemented.');
        end

        function paths = queryablePaths(~, ~)
            % queryablePaths - return a struct with fields:
            %   .scalar : cellstr of dot-path strings whose schema field
            %             has _queryable: true and is not an
            %             array-of-structure.
            %   .array  : cellstr of dot-path strings ending in [*] for
            %             array-of-structure queryable sub-fields.
            %   Used by the SQL backend (PLAN §3.2/§3.3) to generate
            %   stored columns and the queryable_array_elem sidecar.
            error('did2:notImplemented', ...
                'did2.schema.cache.queryablePaths is not yet implemented.');
        end

        function s = buildBlankDocument(~, ~)
            % buildBlankDocument - return a struct populated with the
            %   _blank_value of every field declared by className and
            %   its superclasses, plus _class metadata.
            error('did2:notImplemented', ...
                'did2.schema.cache.buildBlankDocument is not yet implemented.');
        end

        function validateDocument(~, ~)
            % validateDocument - raise if the supplied did2.document
            %   does not conform to its V_gamma class definition.
            error('did2:notImplemented', ...
                'did2.schema.cache.validateDocument is not yet implemented.');
        end
    end

    methods (Static)
        function obj = shared(varargin)
            % shared - return the process-wide cache singleton.
            %
            %   shared() returns the existing singleton, creating it on
            %   first call using the default schema path.
            %   shared(schemaPath) sets the schema path on first call; if
            %   the singleton already exists, the argument is ignored
            %   (use setSchemaPath to rebuild).
            %   shared('-reset') drops the singleton.
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
            % setSchemaPath - rebuild the singleton against a new schema path.
            arguments
                schemaPath (1,:) char
            end
            did2.schema.cache.shared('-reset');
            did2.schema.cache.shared(schemaPath);
        end

        function resetSingleton()
            % resetSingleton - drop the cached singleton so the next
            %   .shared() call constructs a fresh instance. Intended for
            %   tests.
            did2.schema.cache.shared('-reset');
        end
    end

    methods (Static, Access = private)
        function p = defaultSchemaPath()
            % defaultSchemaPath - filesystem location of V_gamma schemas.
            %
            %   The default looks for a sibling did-schema checkout next
            %   to the did-matlab repository. Override via the
            %   DID_SCHEMA_PATH environment variable or by calling
            %   setSchemaPath().
            envOverride = getenv('DID_SCHEMA_PATH');
            if ~isempty(envOverride)
                p = envOverride;
                return;
            end
            toolboxDir = did.toolboxdir();
            p = fullfile(toolboxDir, '..', '..', 'did-schema', 'schemas', 'V_gamma');
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
            % extractField - tolerate jsondecode's underscore-prefix
            %   renaming, which on some MATLAB releases mangles leading
            %   underscores into 'x_' or strips them.
            candidates = {name, ['x' name], strrep(name, '_', '')};
            for k = 1:numel(candidates)
                if isfield(s, candidates{k})
                    value = s.(candidates{k});
                    return;
                end
            end
            value = [];
        end
    end
end
