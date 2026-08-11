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
    %   ENFORCEMENT SWITCHES (open items #32, #37 and #38)
    %   -------------------------------------------------
    %   Three rules the schema DECLARES were, until this change, read by
    %   nothing. Two are about non-emptiness:
    %
    %     #37  `mustBeNonEmpty` on a `depends_on` entry. validateDocument
    %          never looked at `depends_on` at all -- the only mentions of
    %          the key in this file were a comment, buildBlankDocument's
    %          empty seed, and the allowed-top-level-keys list. The other
    %          half of the story is did2.validate.references, which skips
    %          empty edges; that skip is CORRECT for what references does
    %          (an edge with no id cannot dangle, and references is handed
    %          no schema so it cannot know which edges are required). The
    %          missing check belongs here, where the schema is visible.
    %
    %     #38  An ALL-BLANK COMPOSITE. isEmptyValue calls a struct empty
    %          only when it has NO FIELDNAMES, so an ontology_term of
    %          {node:'', name:''} satisfies mustBeNonEmpty while saying
    %          nothing. isVacuousValue is the recursive all-leaves-blank
    %          test that catches it.
    %
    %   and the third is about vocabulary:
    %
    %     #32  `constraints.binding` (T8). validateConstraints handled
    %          five keywords -- maxLength, minLength, minimum, maximum,
    %          enum -- and dropped every other key into `otherwise`, so a
    %          binding was a comment with JSON syntax. checkBinding reads
    %          the two things a binding can state with no ontology loaded:
    %          an inline `values` set, and `node_form: curie`. Ontology
    %          MEMBERSHIP is still out of scope (NDIC.txt lives in
    %          VH-Lab/ndi-ontology-matlab).
    %
    %   TWO ARE ARMED BY DEFAULT (2026-08-10, team's call) AND THE THIRD IS
    %   NOT. This header read "BOTH DEFAULT TO OFF" for as long as that was
    %   true and for a while after it was not -- the same header-vs-state
    %   staleness the schema repo documents. The authority for the defaults
    %   is `strictMode` below, and it is where the reasoning lives:
    %
    %     #38 NonVacuousFields      ARMED    -- 0 measured cost
    %     #37 RequiredDependencies  ARMED    -- 7,233 measured cost, ON PURPOSE
    %     #32 BindingConformance    DISARMED -- cost NEVER MEASURED
    %
    %   The third default is the odd one out on purpose. #37 and #38 were
    %   armed knowing what they would cost; nobody knows what #32 costs,
    %   because no census has ever counted a binding violation -- nothing
    %   read `binding` until now. A corpus that is green on 627,526
    %   documents is green on a rule that was not being checked, which is
    %   not evidence about the rule. Arm it on a discovery run and read the
    %   rollup before changing that default.
    %
    %   THE TWO ARMED ONES WERE ARMED ON OPPOSITE EVIDENCE, and that
    %   distinction must not be flattened back out. #38 costs nothing
    %   measured. #37 is armed
    %   AGAINST its measurement -- the same corpus run reports 7,233 empty
    %   required edges, so the corpus gates are EXPECTED TO GO RED. The
    %   team's instruction was "arm it, we want to see issues so we can fix
    %   them": a loud red gate beats a hollow document that validates while
    %   naming nobody.
    %
    %   The earlier rule here -- "enforcement is gated on the census
    %   reaching zero" -- is therefore SUPERSEDED for #37 by an explicit
    %   decision to enforce first and repair against the noise. The census
    %   (did2.validate.silentLoss) still measures both conditions and still
    %   raises nothing; its job is now to PREDICT the gate rather than to
    %   permit it, which is why the two implementations of each rule are
    %   locked together by test. See
    %   did-schema/schemas/V_eta_ground_truth_plan.md Phase 1.
    %
    %   Set them per-process with did2.schema.cache.strictMode, or per-CI-
    %   job with the environment variables DID_ENFORCE_REQUIRED_DEPENDENCIES,
    %   DID_ENFORCE_NONVACUOUS_FIELDS and DID_ENFORCE_BINDING_CONFORMANCE.
    %   The first two are armed, so an explicit 0/false/no/off DISARMS them;
    %   the third is disarmed, so an explicit 1/true/yes/on ARMS it. In both
    %   directions an unset or misspelled value leaves the switch as it was.
    %
    %   did2.schema.cache Static Methods:
    %       shared          - return the process-wide singleton cache.
    %       setSchemaPath   - rebuild the singleton at a new schema path.
    %       resetSingleton  - drop the cached singleton (test helper).
    %       strictMode      - read/set the #32, #37 and #38 enforcement
    %                         switches.
    %
    %   did2.schema.cache Methods:
    %       getClass            - resolved class definition for a name.
    %       requiredDependencies - depends_on names declared mustBeNonEmpty
    %                             anywhere in a class chain (#37).
    %       unpopulatedRequiredDependencies - which of those a given body
    %                             leaves absent or blank (#37).
    %   (isVacuousValue, the #38 predicate, is PRIVATE -- it is reached
    %    through validateDocument, and did2.validate.silentLoss carries the
    %    report-only twin of the same rule.)
    %       superclasses        - ancestor chain (parent first, root last).
    %       classChain          - root-first list including the class itself.
    %       ownFields           - the `fields` list a class declares directly.
    %       fieldsFor           - merged inherited fields tagged with the
    %                             declaring class (struct array).
    %       resolvePlacement    - per-block field layout for a concrete class,
    %                             honoring per-field `placement`.
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

        function names = requiredDependencies(obj, className)
            % requiredDependencies - names of `depends_on` entries declared
            %   `mustBeNonEmpty` anywhere in CLASSNAME's chain (#37).
            %
            %   NUMBERED FAMILIES (`derived_from_#`, `time_reference_#`)
            %   ARE EXCLUDED, deliberately. `mustBeNonEmpty` cannot
            %   describe a family: a MISSING instance is not a blank one,
            %   and the checkable property is the instance COUNT, which
            %   the schema states as min_count/max_count and which #63
            %   measures REPORT-ONLY in did2.validate.silentLoss. Folding
            %   families in here would turn an unmeasured count into a
            %   gate.
            %
            %   This is the same rule silentLoss/requiredDependencies
            %   applies, so the census and the gate agree by construction
            %   on WHICH edges are at stake. testEnforceRequiredDependencies
            %   locks the two together on one document.
            arguments
                obj
                className (1,:) char
            end
            names = {};
            chain = obj.classChain(className);
            for k = 1:numel(chain)
                try
                    s = obj.getClass(chain{k});
                catch
                    continue;
                end
                if ~isfield(s, 'depends_on'); continue; end
                deps = s.depends_on;
                % jsondecode returns a CELL when the dependency objects in
                % one class do not all carry the same keys (normal now that
                % only numbered families declare min_count). Iterate
                % element-wise; `[deps{:}]` throws on mismatched fieldnames.
                if isstruct(deps)
                    items = num2cell(deps(:)');
                elseif iscell(deps)
                    items = deps(:)';
                else
                    continue;
                end
                for d = 1:numel(items)
                    dep = items{d};
                    if ~isstruct(dep) || ~isfield(dep, 'name') ...
                            || ~isfield(dep, 'mustBeNonEmpty')
                        continue;
                    end
                    if ~logical(dep.mustBeNonEmpty); continue; end
                    n = char(dep.name);
                    if contains(n, '#'); continue; end
                    if ~any(strcmp(names, n)); names{end+1} = n; end %#ok<AGROW>
                end
            end
        end

        function missing = unpopulatedRequiredDependencies(obj, body, className)
            % unpopulatedRequiredDependencies - the subset of
            %   requiredDependencies(CLASSNAME) that BODY leaves absent or
            %   blank (#37). BODY is a document body struct.
            %
            %   ABSENT AND BLANK ARE THE SAME ANSWER HERE. An edge that was
            %   never written and an edge written as '' both fail to name a
            %   referent, and the invented-empty-edge pattern produced both
            %   spellings depending on which migrator emitted the document.
            arguments
                obj
                body struct
                className (1,:) char
            end
            missing = {};
            required = obj.requiredDependencies(className);
            for k = 1:numel(required)
                if ~did2.schema.cache.edgeIsPopulated(body, required{k})
                    missing{end+1} = required{k}; %#ok<AGROW>
                end
            end
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

        function info = resolvePlacement(obj, className)
            % resolvePlacement - per-block field layout for a concrete
            %   class, honoring the per-field `placement` attribute
            %   (V_gamma_SPEC.md "Field placement"). For each field
            %   declared anywhere in the class chain, decides which
            %   property block hosts the field on instance bodies:
            %
            %     placement = "declaring_class" (default)
            %       -> hosted on the declaring class's block.
            %     placement = "concrete_class"
            %       -> hosted on the concrete (leaf) class's block.
            %         Only valid on fields declared by an abstract
            %         class.
            %
            %   Returns a struct with three fields:
            %
            %     info.blocksContributed
            %       cellstr of block names (each a class name in the
            %       chain) that contribute a property block on instance
            %       bodies. A concrete class always contributes. An
            %       abstract class contributes only if at least one of
            %       its own fields uses placement="declaring_class".
            %
            %     info.fieldsByBlock
            %       containers.Map keyed by block name; each value is a
            %       struct array with fields:
            %         .fieldDef        the raw schema field entry
            %         .declaringClass  the class that declared it
            %         .placement       'declaring_class' | 'concrete_class'
            %
            %     info.chain
            %       cellstr root-first class chain (same as classChain).
            %
            %   Raises did2:schema:* on:
            %     placementOnConcreteClass  field with placement="concrete_class"
            %                               declared by a non-abstract class.
            %     invalidPlacement          placement value other than the two
            %                               allowed strings.
            %     placementCollision        same field name lands twice in the
            %                               same block (either two ancestors
            %                               both place into the concrete-class
            %                               block, or any class redeclares a
            %                               name an ancestor has placed).
            arguments
                obj
                className (1,:) char
            end

            chain = obj.classChain(className);
            leaf  = className;

            entriesByBlock = containers.Map();
            blocksContributedSet = containers.Map();

            for k = 1:numel(chain)
                cls = chain{k};
                clsSchema = obj.getClass(cls);
                isAbstract = obj.classIsAbstract(clsSchema);
                own = obj.ownFields(cls);

                clsContributesOwnBlock = ~isAbstract;
                for f = 1:numel(own)
                    fdef = own{f};
                    fieldName = char(fdef.name);
                    placement = obj.fieldPlacement(fdef);

                    if strcmp(placement, 'concrete_class')
                        if ~isAbstract
                            error('did2:schema:placementOnConcreteClass', ...
                                ['Field "%s" on class "%s" sets ', ...
                                 'placement="concrete_class" but "%s" is ', ...
                                 'not abstract. placement="concrete_class" ', ...
                                 'is only valid on fields declared by ', ...
                                 'abstract classes (V_gamma_SPEC.md ', ...
                                 '"Field placement").'], ...
                                fieldName, cls, cls);
                        end
                        targetBlock = leaf;
                    elseif strcmp(placement, 'declaring_class')
                        targetBlock = cls;
                        clsContributesOwnBlock = true;
                    else
                        error('did2:schema:invalidPlacement', ...
                            ['Field "%s" on class "%s" has invalid ', ...
                             'placement value "%s". Allowed values are ', ...
                             '"declaring_class" and "concrete_class".'], ...
                            fieldName, cls, placement);
                    end

                    entry = struct( ...
                        'fieldDef',       fdef, ...
                        'declaringClass', cls, ...
                        'placement',      placement);

                    if isKey(entriesByBlock, targetBlock)
                        existing = entriesByBlock(targetBlock);
                        for j = 1:numel(existing)
                            if strcmp(existing(j).fieldDef.name, fieldName)
                                error('did2:schema:placementCollision', ...
                                    ['Field name "%s" collides in ', ...
                                     'block "%s" of class chain for ', ...
                                     '"%s": declared by "%s" ', ...
                                     '(placement="%s") and "%s" ', ...
                                     '(placement="%s"). No class in ', ...
                                     'the chain may declare a field ', ...
                                     'whose name matches a ', ...
                                     'placement="concrete_class" ', ...
                                     'declaration on any ancestor ', ...
                                     '(V_gamma_SPEC.md "Field placement").'], ...
                                    fieldName, targetBlock, leaf, ...
                                    existing(j).declaringClass, ...
                                    existing(j).placement, ...
                                    cls, placement);
                            end
                        end
                        existing(end+1) = entry; %#ok<AGROW>
                        entriesByBlock(targetBlock) = existing;
                    else
                        entriesByBlock(targetBlock) = entry;
                    end
                end

                if clsContributesOwnBlock
                    blocksContributedSet(cls) = true;
                end
            end

            % Preserve root-first chain order for blocksContributed.
            blocksContributed = {};
            for k = 1:numel(chain)
                if isKey(blocksContributedSet, chain{k})
                    blocksContributed{end+1} = chain{k}; %#ok<AGROW>
                end
            end

            info = struct();
            info.blocksContributed = blocksContributed;
            info.fieldsByBlock     = entriesByBlock;
            info.chain             = chain;
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
                    path = sprintf('%s.%s', className, char(fieldDef.name));
                    [sc, ar] = obj.collectFieldPaths(fieldDef, className, path);
                    for i = 1:numel(sc)
                        if seenScalar.isKey(sc(i).path)
                            continue;
                        end
                        seenScalar(sc(i).path) = true;
                        scalar(end+1) = sc(i); %#ok<AGROW>
                    end
                    for i = 1:numel(ar)
                        if seenArray.isKey(ar(i).path)
                            continue;
                        end
                        seenArray(ar(i).path) = true;
                        arrayPaths(end+1) = ar(i); %#ok<AGROW>
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
                'superclasses', sc, ...
                'schema_version', 'V_delta');

            doc.depends_on = struct('name', {}, 'document_id', {});

            % Placement-aware block layout: only contributing blocks
            % appear on the body, each populated with the fields routed
            % to it (the class's own declaring-class fields plus any
            % concrete-class-placed fields from abstract ancestors when
            % this is the leaf).
            info = obj.resolvePlacement(className);
            for k = 1:numel(info.blocksContributed)
                blockClass = info.blocksContributed{k};
                doc.(blockClass) = obj.buildBlockFromEntries( ...
                    blockClass, info.fieldsByBlock);
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
            % V_gamma_SPEC §"Validation checklist": the
            % document_class.superclasses snapshot must equal the chain
            % derived from the schema files (same set, same order,
            % class-name-by-class-name). buildBlankDocument and the
            % v1->v2 migrator both honour this by construction; this
            % check catches hand-built docs and serialisers that emit
            % only the immediate parent — a truncated chain breaks
            % isa-style queries downstream (e.g., classLineage on the
            % cloud), so flag it at the boundary.
            if ~isfield(dc, 'superclasses')
                error('did2:validation:missingSuperclasses', ...
                    ['document_class.superclasses is required (empty ' ...
                     '[] for base). Class "%s" expects %d entries.'], ...
                    className, numel(obj.superclasses(className)));
            end
            expectedAncestors = obj.superclasses(className);
            declaredAncestors = obj.superclassClassNames(dc.superclasses);
            if numel(declaredAncestors) ~= numel(expectedAncestors) ...
                    || ~all(cellfun(@strcmp, declaredAncestors, expectedAncestors))
                error('did2:validation:superclassesChainMismatch', ...
                    ['document_class.superclasses for "%s" is {%s} but ' ...
                     'the schema chain is {%s}. V_delta requires the ' ...
                     'snapshot to match the schema-derived chain ' ...
                     'class-name-by-class-name.'], ...
                    className, ...
                    strjoin(declaredAncestors, ', '), ...
                    strjoin(expectedAncestors, ', '));
            end
            % Placement-aware: a class in the chain whose declared
            % fields are all `placement: "concrete_class"` does not
            % contribute a body block. Inherited fields routed onto the
            % concrete leaf's block are validated there against their
            % declaring class's field definition.
            info = obj.resolvePlacement(className);
            for k = 1:numel(info.blocksContributed)
                blockClass = info.blocksContributed{k};
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
                if isKey(info.fieldsByBlock, blockClass)
                    entries = info.fieldsByBlock(blockClass);
                else
                    entries = struct('fieldDef', {}, 'declaringClass', {}, 'placement', {});
                end
                declaredNames = cell(1, numel(entries));
                for f = 1:numel(entries)
                    fieldDef = entries(f).fieldDef;
                    fieldName = char(fieldDef.name);
                    declaredNames{f} = fieldName;
                    obj.validateField(block, fieldDef, blockClass, fieldName);
                end
                % Strict-fields check: every property-block field must be
                % declared by the (placement-resolved) schema layout for
                % this block. Anything else is mis-keyed data (e.g., a
                % v1 field name the migrator forgot to map) or a v1-only
                % field that needs an explicit drop. Loud failure beats
                % silent passthrough.
                blockFns = fieldnames(block);
                for fk = 1:numel(blockFns)
                    fn = blockFns{fk};
                    if ~any(strcmp(fn, declaredNames))
                        error('did2:validation:undeclaredField', ...
                            ['Property block "%s" carries undeclared ' ...
                             'field "%s". V_delta requires every block ' ...
                             'field to be declared by the schema; v1 ' ...
                             'fields without a V_delta counterpart must ' ...
                             'be migrated or explicitly dropped.'], ...
                            blockClass, fn);
                    end
                end
            end
            % Strict top-level check: every top-level key must be either
            % a structural key, a contributing chain block, or the
            % optional file/files wrapper. A chain class that does not
            % contribute a body block (all of its declared fields placed
            % at concrete_class) appearing as a top-level key on the
            % body is treated as an undeclared block — the abstract
            % class has no fields of its own to host on the instance.
            allowedTop = [info.blocksContributed, {'document_class', 'depends_on', 'file', 'files'}];
            topFns = fieldnames(s);
            for tk = 1:numel(topFns)
                tn = topFns{tk};
                if ~any(strcmp(tn, allowedTop))
                    error('did2:validation:undeclaredBlock', ...
                        ['Document carries undeclared top-level block ' ...
                         '"%s". Either snake_case the key to match a ' ...
                         'V_delta chain class or remove it in a per-class ' ...
                         'migrator.'], tn);
                end
            end
            % ---- #37: required depends_on edges --------------------------
            % LAST, on purpose. Every check above predates this one, and a
            % document that already fails one of them must keep failing for
            % the SAME reason -- otherwise flipping this switch silently
            % rewrites the quarantine-reason histogram for documents whose
            % problem is something else entirely.
            %
            % ARMED BY DEFAULT since 2026-08-10 (team's call). This comment
            % previously said switching it on "before those are repaired turns
            % the 0-quarantine gate red" -- that is still TRUE and is now the
            % INTENDED outcome, not a reason to wait. The last measured census
            % (corpus run 31415147934, 02854c7) found 7,233 empty required
            % edges across six corpora; expect them as quarantines, read them
            % PER CLASS out of v1_to_v2/printSummary, and repair against that.
            if did2.schema.cache.strictMode('RequiredDependencies')
                missingDeps = obj.unpopulatedRequiredDependencies(s, className);
                if ~isempty(missingDeps)
                    error('did2:validation:emptyRequiredDependency', ...
                        ['Class "%s" declares depends_on %s as ' ...
                         'mustBeNonEmpty, and the document leaves ' ...
                         'them absent or empty. A required edge that ' ...
                         'names no referent is a document about ' ...
                         'nobody.'], ...
                        className, ...
                        ['{' strjoin(missingDeps, ', ') '}']);
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

        function out = strictMode(varargin)
            % strictMode - read or set the #32/#37/#38 enforcement switches.
            %
            %   S = strictMode()               all switches, as a struct
            %   TF = strictMode(NAME)          one switch
            %   PREV = strictMode(NAME, TF)    set one, return its PREVIOUS
            %                                  value (so a test can restore)
            %   S = strictMode('-reset')       re-read the environment
            %
            %   SWITCHES
            %     RequiredDependencies  #37. mustBeNonEmpty on a depends_on
            %                           entry rejects, raising
            %                           did2:validation:emptyRequiredDependency.
            %     NonVacuousFields      #38. A required field whose every
            %                           leaf is blank rejects, raising
            %                           did2:validation:vacuousField.
            %
            %   BOTH ARE NOW ARMED (2026-08-10, team's call) -- and they were
            %   armed on OPPOSITE evidence, which must not be flattened out.
            %
            %   NonVacuousFields: cost measured, and it is ZERO. Corpus run
            %   31415147934 reports "0 vacuous required field(s)" on all six
            %   corpora across 562,448 documents. Nothing we have ever
            %   migrated trips it, so arming it buys a whole class of silent
            %   defect for no quarantine.
            %
            %   RequiredDependencies: cost measured, and it is NOT zero. The
            %   same run reports 7,233 empty required edges --
            %   stimulus_presentation.element_id 2,670 and
            %   image_observation.subject_id 4,563. IT IS ARMED ANYWAY, on the
            %   team's explicit instruction: "Arm it. We want to see issues so
            %   we can fix them." So EXPECT THE CORPUS GATES TO GO RED. (The
            %   image_stack guard post-dates that run, so the 4,563 row may
            %   already be lower -- unmeasured either way.)
            %
            %   This REVERSES the older rule stated here, that a gate must not
            %   be armed ahead of the repairs it grades. That rule was right
            %   about the consequence, and the team accepted the consequence
            %   deliberately: a visible red is the point, because the
            %   alternative is a hollow document that passes silently.
            %
            %   Because #37 will sit red for a while, the reds have to stay
            %   READABLE: did2.convert.v1_to_v2/printSummary rolls quarantines
            %   up PER CLASS AND REASON, denominator first, so a NEW offender
            %   is distinguishable from the two known rows on the day it
            %   appears.
            %
            %   THE CAVEAT ON ARMING, stated because "0 measured" is weaker
            %   than "0 possible": the corpora are a SAMPLE, and the census's
            %   field scan does not share a denominator with the validator's
            %   (the census inspects only blocks that already host the field;
            %   the validator also reaches required fields whose block is
            %   missing entirely). A dataset still waiting to migrate could
            %   trip it. That is the intended outcome -- a loud quarantine
            %   beats a document that validates while saying nothing -- and
            %   the env var below turns it off if an operator needs it to.
            %
            %   Environment overrides, read once per process (or per
            %   '-reset'), so a CI job can arm a switch without a code
            %   change:
            %     DID_ENFORCE_REQUIRED_DEPENDENCIES
            %     DID_ENFORCE_NONVACUOUS_FIELDS
            %     DID_ENFORCE_BINDING_CONFORMANCE
            %   For the first two -- which are ARMED by default -- '0',
            %   'false', 'no' or 'off' (any case) DISARM, and anything
            %   else, including unset and a typo, leaves them armed.
            %   BindingConformance is the other way round because it is
            %   DISARMED by default: '1', 'true', 'yes' or 'on' arm it,
            %   anything else including unset leaves it off. The two
            %   readers are envFlagIsOff and envFlag respectively, and
            %   each is written so that the SAFE reading survives a typo:
            %   a default-on switch stays on, a default-off switch stays
            %   off.
            %
            %     BindingConformance   #32 (T8). A `constraints.binding`
            %                          that states BOTH strength:required
            %                          and something checkable rejects a
            %                          value that does not conform, with
            %                          did2:validation:bindingValueMissing,
            %                          :bindingNodeMalformed or
            %                          :bindingValueNotInSet.
            %
            %                          DISARMED BY DEFAULT, and unlike the
            %                          two above this is NOT a cost that has
            %                          been measured -- it is a cost that is
            %                          KNOWN to be non-zero in at least one
            %                          direction. `epoch_clock` and the two
            %                          clock/relation fields carry
            %                          strength:required inline value sets,
            %                          and no census has ever counted how
            %                          many migrated documents hold a value
            %                          outside them. Arming it blind would be
            %                          the 2,484-quarantine mistake again.
            %                          Arm it on a DISCOVERY run, read the
            %                          per-class/per-reason quarantine
            %                          rollup, then decide.
            %
            %                          NOTHING HERE HAS BEEN EXECUTED. There
            %                          is no MATLAB in the environment this
            %                          switch was written in, so the
            %                          behaviour described above is the
            %                          intended design and is UNVERIFIED;
            %                          tests/+did2/+unittest/testBindingConformance.m
            %                          is its written-but-unrun specification.
            persistent state
            if isempty(state) || (nargin == 1 && isequal(varargin{1}, '-reset'))
                state = struct( ...
                    ... ARMED BY DEFAULT 2026-08-10, on the team's call:
                    ... "Arm it. We want to see issues so we can fix them."
                    ... Same envFlagIsOff shape as NonVacuousFields, so only an
                    ... explicit 0/false/no/off disarms it and a typo leaves the
                    ... gate ARMED.
                    ...
                    ... THIS ONE IS ARMED AGAINST ITS MEASUREMENT, NOT WITH IT,
                    ... and that is the whole point of the decision. Corpus run
                    ... 31415147934 reports 7,233 empty required edges --
                    ... stimulus_presentation.element_id 2,670 and
                    ... image_observation.subject_id 4,563 -- so unlike #38 this
                    ... switch has a KNOWN, NON-ZERO cost and the corpus gates
                    ... are EXPECTED TO GO RED. The team wants that visibility
                    ... rather than a silent hollow document. (The image_stack
                    ... guard post-dates that run, so the 4,563 row may already
                    ... be lower; nobody has measured it since.)
                    ...
                    ... BECAUSE IT WILL SIT RED FOR A WHILE, the failure has to
                    ... stay READABLE: v1_to_v2/printSummary rolls quarantines up
                    ... PER CLASS AND REASON with the denominator first, so a NEW
                    ... offender is distinguishable from the two known rows. A
                    ... permanently-red gate that says only "7,233" teaches
                    ... people to ignore it.
                    'RequiredDependencies', ...
                        ~did2.schema.cache.envFlagIsOff('DID_ENFORCE_REQUIRED_DEPENDENCIES'), ...
                    ... ARMED BY DEFAULT 2026-08-10, on the team's call. The
                    ... env var can still turn it OFF, which is why the default
                    ... is OR'd rather than replaced: an operator who needs a
                    ... corpus to migrate past a vacuity failure sets
                    ... DID_ENFORCE_NONVACUOUS_FIELDS=0 and gets the old
                    ... behaviour, without editing source.
                    ...
                    ... THE EVIDENCE FOR ARMING IT: zero cost, MEASURED. Corpus
                    ... run 31415147934 reports "0 vacuous required field(s)"
                    ... on all six corpora over 562,448 documents. So nothing
                    ... in anything we have ever migrated trips this, and
                    ... arming it costs no quarantine today while making a
                    ... whole class of silent defect impossible tomorrow.
                    ...
                    ... AND THE CAVEAT, which is why this is a decision and not
                    ... a cleanup: the corpora are a SAMPLE, and the census's
                    ... field scan and the validator's do NOT share a
                    ... denominator -- the census inspects only blocks that
                    ... already host the field, while the validator also
                    ... reaches required fields whose block is missing
                    ... entirely. So "0 measured" is weaker than "0 possible".
                    ... A dataset still waiting to migrate could trip it, and
                    ... the intended outcome then is a LOUD quarantine rather
                    ... than a document that validates while saying nothing.
                    'NonVacuousFields', ...
                        ~did2.schema.cache.envFlagIsOff('DID_ENFORCE_NONVACUOUS_FIELDS'), ...
                    ... #32 (T8). DISARMED BY DEFAULT, and deliberately the
                    ... OPPOSITE of the two switches above -- envFlag, not
                    ... ~envFlagIsOff -- so that unset and a typo both leave it
                    ... OFF.
                    ...
                    ... THE JUSTIFICATION IS EVIDENCE, NOT CAUTION. The two
                    ... switches above were armed on a MEASURED cost (0 vacuous
                    ... fields) or on an explicit team instruction to accept a
                    ... measured one (7,233 empty edges). This one has neither:
                    ... NO census has ever counted a binding violation, because
                    ... nothing has ever read `binding`. The corpus is green on
                    ... 627,526 documents across six corpora -- corpus run
                    ... 31441923369 (`caf710b`), the rollup quoted in
                    ... +did2/+convert/resolveSessionAnchors.m:14-15 -- and that
                    ... green says nothing whatever about this rule: it was not
                    ... being checked. Arming an unmeasured gate on a
                    ... 600k-document corpus is precisely the mistake the
                    ... RequiredDependencies comment above records.
                    ...
                    ... AND THE COST IS KNOWN TO BE NON-ZERO SOMEWHERE. Seven
                    ... V_eta fields declare strength:required WITH an inline
                    ... admissible set (the four did_clocktype carriers, the two
                    ... frequency_filter fields, relative_reference's OWL-Time
                    ... relation). Whether a migrated document ever holds a value
                    ... outside those sets is UNKNOWN, which is exactly the state
                    ... in which a gate must not be armed.
                    ...
                    ... The three fields #32 increment 2 bound -- variable,
                    ... method, purpose -- are `preferred`, and checkBinding
                    ... rejects only on `required`. So even armed, they do not
                    ... reject today: the strength on the field and this switch
                    ... are two independent brakes.
                    'BindingConformance', ...
                        did2.schema.cache.envFlag('DID_ENFORCE_BINDING_CONFORMANCE'));
                if nargin == 1 && isequal(varargin{1}, '-reset')
                    out = state;
                    return;
                end
            end
            if nargin == 0
                out = state;
                return;
            end
            name = char(varargin{1});
            if ~isfield(state, name)
                error('did2:schema:unknownStrictMode', ...
                    ['"%s" is not an enforcement switch. Known switches: ' ...
                     '%s.'], name, strjoin(fieldnames(state)', ', '));
            end
            out = state.(name);
            if nargin >= 2
                state.(name) = logical(varargin{2});
            end
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

        function tf = envFlag(varName)
            % envFlag - true when VARNAME is set to an affirmative value.
            %   Anything unrecognised -- including unset -- is FALSE. A
            %   switch that arms itself on a typo is worse than one that
            %   stays off.
            % strcmpi, not lower()+strcmp: one call, and it does not build a
            % throwaway lowercased copy whose only purpose is the comparison.
            % (GitHub code scanning alert 169; the two are equivalent here
            % because every candidate below is already lower-case ASCII.)
            tf = any(strcmpi(strtrim(getenv(varName)), {'1', 'true', 'yes', 'on'}));
        end

        function tf = envFlagIsOff(varName)
            % envFlagIsOff - true ONLY when VARNAME is set to a negative value.
            %   Unset is FALSE, which is the whole point: this is the reader
            %   for a switch that is ARMED by default, so silence must mean
            %   "leave it armed".
            %
            %   NOT `~envFlag(...)`. That would disarm on unset, and on any
            %   typo -- exactly inverting envFlag's own stated rule ("a switch
            %   that arms itself on a typo is worse than one that stays off").
            %   For a default-on switch the same reasoning runs the other way:
            %   a switch that DISARMS itself on a typo is worse than one that
            %   stays on, because a disarmed gate is silent and a false
            %   quarantine is loud. So an unrecognised value leaves it armed.
            tf = any(strcmpi(strtrim(getenv(varName)), {'0', 'false', 'no', 'off'}));
        end

        function tf = edgeIsPopulated(body, name)
            % edgeIsPopulated - true when BODY carries a depends_on entry
            %   called NAME with a non-empty value.
            %
            %   Tolerant of all THREE key spellings the pipeline uses at
            %   different stages, because they genuinely all occur:
            %   buildBlankDocument seeds `document_id`, the raw v1 wire
            %   shape uses `value`, and some intermediate bodies carry the
            %   bare `id`. Checking only one would have this report an
            %   edge as empty because it was reading the wrong key -- the
            %   grep-that-could-not-match failure, in struct form.
            tf = false;
            if ~isfield(body, 'depends_on'); return; end
            deps = body.depends_on;
            if iscell(deps)
                items = deps(:)';
            elseif isstruct(deps)
                items = num2cell(deps(:)');
            else
                return;
            end
            for k = 1:numel(items)
                d = items{k};
                if ~isstruct(d) || ~isfield(d, 'name'); continue; end
                if ~strcmp(char(d.name), name); continue; end
                for key = {'value', 'document_id', 'id'}
                    if isfield(d, key{1}) && ~isempty(d.(key{1}))
                        tf = true;
                        return;
                    end
                end
            end
        end

        function checkBinding(value, binding, qualifiedName)
            % checkBinding - #32 (T8). Enforce what a `constraints.binding`
            %   ACTUALLY STATES, and nothing more.
            %
            %   T8 wants controlled vocabularies hard-validated: a value
            %   resolved against an admissible set through the binding
            %   registry. That validator does not exist and cannot be
            %   written here -- the admissible set for `variable` lives in
            %   NDIC.txt, which moved to VH-Lab/ndi-ontology-matlab
            %   (2c19bf24c). So MEMBERSHIP IN AN ONTOLOGY IS OUT OF SCOPE.
            %
            %   What a binding can state without any ontology loaded is:
            %     values     an inline admissible set, enumerated on the
            %                field itself -- membership IS checkable, the
            %                set is right there
            %     node_form  a lexical rule on the value's `node` slot;
            %                `curie` = must look like `prefix:local`
            %   and this function checks exactly those two. It does NOT
            %   check that a CURIE's prefix expands (that is
            %   check_binding_governance.py B8, schema-side) and it does
            %   NOT reach the registry.
            %
            %   THREE GATES, ALL OF WHICH MUST OPEN, so that a binding that
            %   says nothing checkable cannot reject anything:
            %     1. strictMode('BindingConformance') -- DISARMED by
            %        default. See strictMode for why: no census has ever
            %        measured a binding violation, so the cost is unknown,
            %        and seven fields carry strength:required inline sets.
            %     2. strength == 'required'. `preferred` and `suggested`
            %        are advisory BY DEFINITION; a validator that rejected
            %        them would make the word meaningless. This is why the
            %        three fields #32 bound (variable/method/purpose,
            %        `preferred`) do not reject even with the switch armed.
            %     3. the binding names something checkable. A binding of
            %        {strength: required} alone, or one whose only content
            %        is `keyed_by` or `term_set`, has nothing behind it --
            %        check_binding_governance.py B9 counts exactly these --
            %        so it returns rather than inventing a rule.
            %
            %   THREE DISTINCT ERROR IDS, for the same reason #38 got its
            %   own: a corpus quarantine histogram has to stay legible, and
            %   "the value is absent" and "the value is present but not
            %   shaped like a term reference" are different repairs.
            %     did2:validation:bindingValueMissing    nothing there
            %     did2:validation:bindingNodeMalformed   node is not a CURIE
            %                                            (an EMPTY node is
            %                                            malformed, not
            %                                            missing, when a name
            %                                            is present -- the
            %                                            document said
            %                                            something, it just
            %                                            did not say anything
            %                                            resolvable)
            %     did2:validation:bindingValueNotInSet   not in `values`
            %
            %   NEVER EXECUTED. There is no MATLAB in the environment this
            %   was written in. See testBindingConformance.m.
            if ~did2.schema.cache.strictMode('BindingConformance')
                return;
            end
            if ~isstruct(binding) || ~isscalar(binding)
                return;
            end
            strength = '';
            if isfield(binding, 'strength') && ~isempty(binding.strength) ...
                    && (ischar(binding.strength) || isstring(binding.strength))
                strength = char(binding.strength);
            end
            if ~strcmp(strength, 'required')
                return;
            end

            hasSet = isfield(binding, 'values') && ~isempty(binding.values);
            hasForm = false;
            if isfield(binding, 'node_form') && ~isempty(binding.node_form) ...
                    && (ischar(binding.node_form) || isstring(binding.node_form))
                % Only `curie` is defined. An unknown node_form is
                % TOLERATED rather than treated as a failure: a schema
                % written by newer tooling must not make old code reject
                % documents it does not understand.
                hasForm = strcmpi(char(binding.node_form), 'curie');
            end
            if ~(hasSet || hasForm)
                return;
            end

            [terms, readable] = did2.schema.cache.bindingTerms(value);
            if ~readable
                % A binding on a shape this function cannot read as a term
                % reference (numeric, arbitrary struct). Tolerated, exactly
                % as validateTypeShape tolerates an unknown type: the
                % mismatch is a schema defect, and reporting it as a
                % binding violation would put it in the wrong histogram row.
                return;
            end
            if isempty(terms)
                error('did2:validation:bindingValueMissing', ...
                    ['Field "%s" carries a required binding and has no ' ...
                     'value at all.'], qualifiedName);
            end

            memberNodes = {};
            memberNames = {};
            if hasSet
                [memberNodes, memberNames] = ...
                    did2.schema.cache.bindingMembers(binding.values);
            end

            for k = 1:numel(terms)
                node = strtrim(terms(k).node);
                name = strtrim(terms(k).name);
                if isempty(node) && isempty(name)
                    error('did2:validation:bindingValueMissing', ...
                        ['Field "%s" carries a required binding and its ' ...
                         'value is blank.'], qualifiedName);
                end
                if hasForm && ~did2.schema.cache.isCurieToken(node)
                    error('did2:validation:bindingNodeMalformed', ...
                        ['Field "%s" is bound with node_form "curie", so ' ...
                         'its `node` must be a CURIE (prefix:local); got ' ...
                         '"%s" (name "%s").'], qualifiedName, node, name);
                end
                if hasSet
                    inSet = false;
                    if ~isempty(node)
                        inSet = any(strcmp(node, memberNodes));
                    end
                    if ~inSet && ~isempty(name)
                        inSet = any(strcmp(name, memberNames));
                    end
                    if ~inSet
                        error('did2:validation:bindingValueNotInSet', ...
                            ['Field "%s" value (node "%s", name "%s") is ' ...
                             'not a member of the %d-member admissible ' ...
                             'set the binding declares.'], ...
                            qualifiedName, node, name, numel(memberNames));
                    end
                end
            end
        end

        function [terms, readable] = bindingTerms(value)
            % bindingTerms - read a field value as zero or more
            %   {node, name} term references.
            %
            %   READABLE is returned separately from an empty TERMS so that
            %   "this value holds no term" and "this function cannot read
            %   this shape" stay distinguishable -- collapsing them would
            %   let an unreadable value be reported as a missing one, which
            %   is the reassuring direction.
            %
            %   Both wire shapes occur in V_eta: an `ontology_term` field is
            %   a struct with node/name, while `epoch_bounded_reference`'s
            %   bound `epoch_clock` is plain char. A char value has no node,
            %   so its whole content is read as the NAME.
            terms = struct('node', {}, 'name', {});
            readable = false;
            if isstruct(value)
                if ~isfield(value, 'node') && ~isfield(value, 'name')
                    return;
                end
                readable = true;
                for k = 1:numel(value)
                    terms(end + 1) = struct( ...
                        'node', did2.schema.cache.charOf(value(k), 'node'), ...
                        'name', did2.schema.cache.charOf(value(k), 'name')); %#ok<AGROW>
                end
            elseif ischar(value) || isstring(value)
                readable = true;
                items = cellstr(string(value));
                for k = 1:numel(items)
                    terms(end + 1) = struct('node', '', 'name', items{k}); %#ok<AGROW>
                end
            elseif iscell(value)
                if ~all(cellfun(@(c) ischar(c) || isstring(c), value(:)))
                    return;
                end
                readable = true;
                for k = 1:numel(value)
                    terms(end + 1) = struct('node', '', ...
                        'name', char(string(value{k}))); %#ok<AGROW>
                end
            elseif isnumeric(value) && isempty(value)
                % jsondecode renders JSON `[]` -- and every blank_value
                % spelled that way -- as an empty double. That IS a value
                % slot with nothing in it, so it is readable and empty.
                readable = true;
            end
        end

        function [nodes, names] = bindingMembers(values)
            % bindingMembers - normalise a binding's `values` list to two
            %   cellstrs. A member is either a {node, name} NodeRef or a
            %   bare string; BOTH occur in V_eta today
            %   (check_binding_governance.py B4 counts the three fields
            %   where the shape disagrees with the field's declared type),
            %   so a reader that assumed one of them would silently pass
            %   every value of the other.
            nodes = {};
            names = {};
            if isstruct(values)
                for k = 1:numel(values)
                    nodes{end + 1} = did2.schema.cache.charOf(values(k), 'node'); %#ok<AGROW>
                    names{end + 1} = did2.schema.cache.charOf(values(k), 'name'); %#ok<AGROW>
                end
            elseif iscell(values)
                for k = 1:numel(values)
                    v = values{k};
                    if isstruct(v) && isscalar(v)
                        nodes{end + 1} = did2.schema.cache.charOf(v, 'node'); %#ok<AGROW>
                        names{end + 1} = did2.schema.cache.charOf(v, 'name'); %#ok<AGROW>
                    elseif ischar(v) || isstring(v)
                        nodes{end + 1} = ''; %#ok<AGROW>
                        names{end + 1} = char(string(v)); %#ok<AGROW>
                    end
                end
            elseif ischar(values) || isstring(values)
                items = cellstr(string(values));
                for k = 1:numel(items)
                    nodes{end + 1} = ''; %#ok<AGROW>
                    names{end + 1} = items{k}; %#ok<AGROW>
                end
            end
        end

        function s = charOf(st, fieldName)
            % charOf - a struct field as trimmed char, '' when absent.
            s = '';
            if isstruct(st) && isscalar(st) && isfield(st, fieldName)
                v = st.(fieldName);
                if ischar(v) || (isstring(v) && isscalar(v))
                    s = strtrim(char(v));
                end
            end
        end

        function tf = isCurieToken(s)
            % isCurieToken - true when S looks like `prefix:local`.
            %
            %   THIS PATTERN IS SHARED WITH DID-schema. It is character for
            %   character the CURIE_PATTERN literal in
            %   tools/check_binding_governance.py, because `node_form:
            %   curie` is DECLARED there and ENFORCED here, and one grammar
            %   implemented twice is how `did_clocktype` came to mean two
            %   different things in two files. DID-schema
            %   tests/test_binding_governance.py
            %   ::test_the_curie_grammar_is_identical_in_cache_m reads this
            %   line out of this file and fails if the two drift.
            %
            %   Deliberately loose on the local part: OBO uses digits
            %   (UBERON:0000955), OWL-Time uses camelCase names
            %   (time:intervalDuring). It says NOTHING about whether the
            %   prefix expands -- that is a separate, schema-side check.
            pattern = '^[A-Za-z][A-Za-z0-9_.\-]*:[A-Za-z0-9_][A-Za-z0-9_.\-]*$';
            tf = false;
            if ischar(s) || (isstring(s) && isscalar(s))
                tf = ~isempty(regexp(char(s), pattern, 'once'));
            end
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

        function [sc, ar] = collectFieldPaths(obj, fieldDef, declaringClass, path)
            % collectFieldPaths - the queryable paths contributed by ONE field,
            %   descending through its DECLARED sub_fields.
            %
            %   A field carrying sub_fields is a composite cell: either a literal
            %   `structure`, or one of the named composite types (voltage,
            %   duration, count, score, ontology_term, ...) whose canonical +
            %   source-provenance layout the schema now declares inline. Both are
            %   treated the same -- what decides the shape is whether sub_fields
            %   exist, NOT the type string.
            %
            %   This is the fix for a real gap: the previous version descended only
            %   into literal `structure` ARRAY fields, so every named value cell
            %   produced no usable path. A dimensioned `value` is mustBeScalar:false
            %   with type 'voltage', which matched neither branch -- 26 of 35 V_eta
            %   data_type composites emitted nothing at all, i.e. no measured value
            %   was indexable.
            %
            %     scalar cell -> dotted scalar paths (voltage_assertion.value.volts)
            %     array cell  -> '[*]' sidecar paths (voltage.value[*].volts)
            %     leaf        -> itself, as before.
            sc = struct('path', {}, 'declaringClass', {}, 'fieldName', {}, ...
                'type', {}, 'column', {}, 'affinity', {});
            ar = struct('path', {}, 'declaringClass', {}, 'parentField', {}, ...
                'parentPath', {}, 'subField', {}, 'type', {}, 'affinity', {});
            if ~obj.fieldIsQueryable(fieldDef)
                return;
            end
            fieldName = char(fieldDef.name);
            fieldType = char(fieldDef.type);
            subs = {};
            if isfield(fieldDef, 'fields') && ~isempty(fieldDef.fields)
                subs = obj.toCellArray(fieldDef.fields);
            end
            if obj.fieldIsScalar(fieldDef)
                if isempty(subs)
                    sc(end+1) = struct( ...
                        'path', path, ...
                        'declaringClass', declaringClass, ...
                        'fieldName', fieldName, ...
                        'type', fieldType, ...
                        'column', did2.schema.cache.columnNameFor(path), ...
                        'affinity', did2.schema.cache.affinityFor(fieldType));
                    return;
                end
                for s = 1:numel(subs)
                    subDef = subs{s};
                    subPath = sprintf('%s.%s', path, char(subDef.name));
                    [s2, a2] = obj.collectFieldPaths(subDef, declaringClass, subPath);
                    sc = [sc, s2]; %#ok<AGROW>
                    ar = [ar, a2]; %#ok<AGROW>
                end
                return;
            end
            % Array-valued cell: one sidecar entry per queryable scalar LEAF
            % sub-field. A sub-field that is itself a composite is skipped -- a
            % sidecar column holds one value per element, not a nested object.
            for s = 1:numel(subs)
                subDef = subs{s};
                if ~obj.fieldIsQueryable(subDef) || ~obj.fieldIsScalar(subDef)
                    continue;
                end
                if isfield(subDef, 'fields') && ~isempty(subDef.fields)
                    continue;
                end
                subName = char(subDef.name);
                subType = char(subDef.type);
                ar(end+1) = struct( ...
                    'path', sprintf('%s[*].%s', path, subName), ...
                    'declaringClass', declaringClass, ...
                    'parentField', fieldName, ...
                    'parentPath', path, ...
                    'subField', subName, ...
                    'type', subType, ...
                    'affinity', did2.schema.cache.affinityFor(subType)); %#ok<AGROW>
            end
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

        function names = superclassClassNames(obj, raw)
            % Extract the class_name from each entry of a
            % document_class.superclasses array. Accepts the empty
            % array `[]` (jsondecode of `[]`), an empty struct array,
            % a single struct, or an N-element struct array. Raises
            % did2:validation:badSuperclassEntry on malformed entries.
            if isempty(raw)
                names = {};
                return;
            end
            cells = obj.toCellArray(raw);
            names = cell(1, numel(cells));
            for k = 1:numel(cells)
                entry = cells{k};
                if ~isstruct(entry) || ~isfield(entry, 'class_name') ...
                        || isempty(entry.class_name)
                    error('did2:validation:badSuperclassEntry', ...
                        ['document_class.superclasses(%d) is missing ' ...
                         'class_name; every snapshot entry must carry ' ...
                         'at least class_name.'], k);
                end
                names{k} = char(entry.class_name);
            end
        end

        function block = buildBlockFromEntries(obj, blockClass, fieldsByBlock)
            % buildBlockFromEntries - populate one property block from
            %   the placement-resolved field entries for `blockClass`
            %   (from resolvePlacement(.).fieldsByBlock). Honors
            %   `blank_value` per field. Base block also receives a
            %   fresh did_uid for `id` and a UTC timestamp for
            %   `datestamp`.
            block = struct();
            if isKey(fieldsByBlock, blockClass)
                entries = fieldsByBlock(blockClass);
                for f = 1:numel(entries)
                    fieldDef = entries(f).fieldDef;
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
            end
            if strcmp(blockClass, 'base')
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
            % ---- #38: present, but saying nothing ------------------------
            % A SEPARATE predicate and a SEPARATE error id rather than a
            % wider isEmptyValue. Two reasons. (1) isEmptyValue answers a
            % general question -- "is there a value here" -- and an
            % all-blank ontology_term genuinely IS a value, structurally;
            % what it is not is INFORMATIVE. (2) A distinct id keeps the
            % corpus quarantine histogram legible: turning this switch on
            % must be readable as its own row, not as a jump in the
            % pre-existing emptyField count.
            %
            % ARMED BY DEFAULT since 2026-08-10 (team's call; evidence and
            % caveat are in strictMode). This comment read "OFF BY DEFAULT:
            % see the class header" while pointing at a class header that
            % also said off -- two stale statements agreeing with each other
            % is not corroboration, it is one error copied.
            if mustBeNonEmpty ...
                    && did2.schema.cache.strictMode('NonVacuousFields') ...
                    && obj.isVacuousValue(value)
                error('did2:validation:vacuousField', ...
                    ['Field "%s" is required to be non-empty and is ' ...
                     'present, but every leaf of it is blank. A ' ...
                     'composite whose every cell is its blank_value ' ...
                     'satisfies the letter of mustBeNonEmpty while ' ...
                     'recording nothing.'], qualifiedName);
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
            % NOTE (#38): a struct is "empty" here only when it has NO
            % FIELDNAMES. That is the hole -- {node:'', name:''} has two
            % fieldnames and so passes. isVacuousValue below is the
            % companion test; this one is deliberately left as it was, so
            % that a genuinely empty value keeps raising emptyField and an
            % all-blank one raises vacuousField.
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

        function tf = isVacuousValue(obj, value)
            % isVacuousValue - PRESENT, but carrying nothing: a struct
            %   every leaf of which is blank, recursively (#38).
            %
            %   Deliberately mirrors did2.validate.silentLoss/isVacuous, so
            %   that the count the census reports is the count enforcement
            %   would quarantine. If these two ever disagree, the census
            %   stops predicting the gate -- which is the failure mode this
            %   whole repair track exists to close.
            %
            %   The rules, and why each is that way:
            %     - a non-struct is NEVER vacuous. '' and [] are plain
            %       empties; isEmptyValue already catches those, and
            %       double-reporting them would drown the new signal.
            %     - a struct with NO FIELDNAMES is NOT vacuous, same
            %       reason: isEmptyValue already calls it empty.
            %     - a real numeric 0 or a logical false IS a value. A
            %       recorded zero is a measurement, not a blank.
            %     - whitespace-only char counts as blank.
            %     - a struct ARRAY is vacuous only if EVERY element is.
            tf = false;
            if ~isstruct(value) || isempty(value); return; end
            fn = fieldnames(value);
            if isempty(fn); return; end
            for k = 1:numel(value)
                for f = 1:numel(fn)
                    v = value(k).(fn{f});
                    if isstruct(v)
                        if ~obj.isVacuousValue(v) ...
                                && ~(isempty(v) || isempty(fieldnames(v)))
                            return;
                        end
                    elseif ~isempty(v)
                        if islogical(v) || isnumeric(v)
                            return;
                        end
                        if ischar(v) && ~isempty(strtrim(v)); return; end
                        if isstring(v) && any(strlength(strtrim(v)) > 0); return; end
                    end
                end
            end
            tf = true;
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
                    % Accept char, string array, or cell-of-chars.
                    % MATLAB's jsondecode produces a cell-of-chars for
                    % JSON arrays of strings (e.g., `["a", "b"]`); the
                    % string-type field is intended to hold either a
                    % single string or an array, so all three forms
                    % are equivalent for the type-shape check. Also
                    % accept an empty numeric array as a degenerate
                    % "no value set" sentinel (matches what jsondecode
                    % returns for JSON `[]`, and what schemas declare
                    % as the default `blank_value`).
                    ok = ischar(value) || isstring(value);
                    if ~ok && iscell(value)
                        ok = all(cellfun(@(c) ischar(c) || (isstring(c) && isscalar(c)), value(:)));
                    end
                    if ~ok && isnumeric(value) && isempty(value)
                        ok = true;
                    end
                    if ~ok
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
                    case 'binding'
                        % #32 (T8). The SIXTH constraint keyword, and the
                        % first one that is gated: see checkBinding, and
                        % strictMode('BindingConformance') which is
                        % DISARMED by default. With the switch off this
                        % call returns before it looks at the value, so
                        % the added cost on a corpus run is one function
                        % call per bound field per document -- 14 bound
                        % fields exist in the whole of V_eta.
                        did2.schema.cache.checkBinding(value, cval, qualifiedName);
                    otherwise
                        % Unrecognised constraint keys are tolerated;
                        % `pattern` and similar can be added later.
                end
            end
        end

        function tf = classIsAbstract(~, classSchema)
            % classIsAbstract - true if the document_class header carries
            %   `abstract: true`.
            tf = false;
            if ~isstruct(classSchema) || ~isfield(classSchema, 'document_class')
                return;
            end
            dc = classSchema.document_class;
            if ~isstruct(dc) || ~isfield(dc, 'abstract')
                return;
            end
            abstractVal = dc.abstract;
            tf = (islogical(abstractVal) && abstractVal) ...
                || (isnumeric(abstractVal) && abstractVal == 1);
        end

        function placement = fieldPlacement(~, fieldDef)
            % fieldPlacement - return the field's `placement` value,
            %   defaulting to 'declaring_class' when the key is absent
            %   or empty.
            placement = 'declaring_class';
            if ~isstruct(fieldDef) || ~isfield(fieldDef, 'placement')
                return;
            end
            raw = fieldDef.placement;
            if isempty(raw)
                return;
            end
            placement = char(raw);
        end
    end
end
