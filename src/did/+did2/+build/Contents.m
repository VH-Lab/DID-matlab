% +BUILD  Build V_eta documents that are right by construction.
%
%   Every function here reads the shapes it builds from the schema the
%   did2.schema.cache has loaded (DID_SCHEMA_PATH) -- field lists, nested
%   layouts, block placement, edge names, enums and rules -- so nothing about a
%   class's shape is written into the builder, and a schema change is picked up
%   without editing it. Anything the schema does not declare is an error, and
%   optional fields that are not given are left OUT (never filled with blanks).
%
%   The target is V_eta: the JSON under did-schema schemas/V_eta, edited
%   directly since did-schema deleted tools/build_v_eta.py (2026-10-21).
%
%   Documents
%     document               any class: fields routed to blocks, edges and files
%                            checked, schema rules checked, then validateDocument
%     statement              an observation / assertion / manipulation /
%                            calculation (the direction class, with its value
%                            kind as 'ValueKind') about an entity, by its
%                            `entity_id` edge
%     sampledBody            the byte array holding a statement's value
%     opaqueBody             bytes in a named container format
%     relativeTimeReference  a time offset from another document, on a clock
%     absoluteTimeReference  a wall-clock (UTC) instant or interval
%     directedRelation       child <relation> parent
%     method                 a named, shared method: {term, parameters} with an
%                            id of its own (`method_parameters` before #88)
%     undirectedRelation     a symmetric relation between two ends (relata):
%                            entities, statements or standalone values
%
%   Parts of documents
%     valueCell              a data_type's `value` cells (volts, seconds, count, ...)
%     dimension              one axis of a value's array (`dimensions` entry;
%                            `keys` until did-schema data_body AMENDMENT 6)
%     covariate              what is known along one or more dimensions
%                            (`covariates` entry): origin+spacing, quantity,
%                            count, term, text, logical, matrix or document
%     condition              one whole-statement qualifier (`conditions` entry)
%     parameter              one algorithm setting (a `method.parameters` entry);
%                            the same entry as a condition: one `term`,
%                            `quantity`, `count`, `text` or `matrix` (a
%                            numeric array as one value, did-schema #88)
%     fitEntry               one model fit (`model_fit` entry)
%     term, label            an ontology term; a term known only by name
%     list                   join separately built entries into one array
%     composite              the general form: any nested structure a class declares
%     datumType              a MATLAB / source type name -> `datum_type`
%     compression            a body's `compression`, in the form the schema
%                            declares: a codec name (char), or the {term,
%                            parameters} block ([compression block and empty
%                            levels], Jess Haley, 2026-10-26)
%     compressionCodec       read `compression` in either shape: the codec's
%                            spelling and its settings
%     compressionBlockDeclared  does the schema declare the block?
%     relatumIds             read an undirected_relation's ends under either
%                            name: `relatum_id`, or `entity_id` before
%                            [undirected ends are relata] (2026-11-01)

%   Checks across documents
%     checkDoseIngredients   a dose's ingredient_id edges are among its
%                            formulation's (rule ingredient_in_formulation)
%     checkMethodSharedAndOwn  an inline method beside method_id shares no
%                            parameter variable with the shared method (rule
%                            method_shared_and_own)
%
%   Checks beyond per-field types (the list lives in private/checkRules.m):
%     the schema's own `rules` (data_type_when_bytes, clock_with_start,
%     end_consistent, value_inline_or_body, ingredients_or_product,
%     ingredients_match_edges, method_shared_and_own,
%     assertion_no_time_dimension, datum_order_multidimensional,
%     fit_metric_unit; the `dimensions` / `covariates` rules are checked by
%     the builder's own dimension and covariate checks whether or not the
%     schema names them; ingredient_in_formulation is known but needs the
%     formulation, see checkDoseIngredients) -- an UNKNOWN rule is an error,
%     not a skip; `require_inherited`; conditions carry one value; variables are
%     unique across covariates and conditions; parameters carry one form and
%     are unique; beside a `method_id` edge an inline `method` has no term
%     (never both, on a schema without method_shared_and_own); a covariate runs along existing dimensions and its shape matches
%     their extents; a multi-dimension array names datum_order.
%   And every ontology term in a vocabulary slot (a variable, method, unit,
%   condition, parameter, dimension or covariate) and every value term (term.value, a
%   chemical's substance) must be in the schema's term registry (tenet T19;
%   strictMode 'TermRegistry', armed): did2:build:unregisteredTerm. A model
%   fit's coefficient names are the fit's own and are not checked.
%   unregisteredTerms collects them instead, so one run can list them all.
%
%   A class the schema's class_disposition_meta.json lists as retired takes no
%   new document (Jess Haley, 2026-10-24, [V2 builder refuses retired];
%   strictMode 'RetiredClasses', armed; off while did2.convert migrates):
%   did2:build:retiredClass, naming the replacement and the decision. A schema
%   without that file refuses nothing.
%
%   Not checked here: the binding constraint (T8) -- that is
%   did2.schema.cache's strictMode('BindingConformance'), off by default -- and
%   batch checks that need other documents (an edge's referent existing, family
%   uniqueness by clock, `standalone_value`).
%
%   Example
%     sid = session.id();
%     ref = did2.build.relativeTimeReference(epochId, 'Clock', 'dev_local_time', ...
%         'Start', 0, 'Duration', 60, 'SessionId', sid);
%     obs = did2.build.statement('observation', subjectId, 'voltage', [], ...
%         'ValueKind', 'voltage', 'DataBody', true, 'DatumType', did2.build.datumType('int16'), ...
%         'TimeReferenceIds', {ref.base.id}, 'SessionId', sid);
%     body = did2.build.sampledBody(obs.base.id, did2.build.list( ...
%             did2.build.dimension('time', 1800000), did2.build.dimension('channel', 32)), ...
%         'Covariates', did2.build.list( ...
%             did2.build.covariate('time', 0, 'Unit', 'second', 'Origin', 0, 'Spacing', 1/30000), ...
%             did2.build.covariate('channel', 1, 'Count', 1:32)), ...
%         'DatumOrder', 'F', 'ByteOrder', 'little', 'SessionId', sid);
