% +BUILD  Build V_eta documents that are right by construction.
%
%   Every function here reads the shapes it builds from the schema the
%   did2.schema.cache has loaded (DID_SCHEMA_PATH) -- field lists, nested
%   layouts, block placement, edge names, enums and rules -- so nothing about a
%   class's shape is written into the builder, and a schema change is picked up
%   without editing it. Anything the schema does not declare is an error, and
%   optional fields that are not given are left OUT (never filled with blanks).
%
%   The target is V_eta as built by did-schema tools/build_v_eta.py after #73.
%
%   Documents
%     document               any class: fields routed to blocks, edges and files
%                            checked, schema rules checked, then validateDocument
%     statement              an observation / assertion / manipulation /
%                            calculation about a subject
%     sampledBody            the byte array holding a statement's value
%     opaqueBody             bytes in a named container format
%     relativeTimeReference  a time offset from another document, on a clock
%     absoluteTimeReference  a wall-clock (UTC) instant or interval
%     directedRelation       child <relation> parent
%     undirectedRelation     a symmetric relation among entities
%
%   Parts of documents
%     valueCell              a data_type's `value` cells (volts, seconds, count, ...)
%     key                    one dimension of a value (`keys` entry)
%     condition              one whole-statement qualifier (`conditions` entry)
%     parameter              one algorithm setting (`method_parameters` entry)
%     fitEntry               one model fit (`model_fit` entry)
%     term, label            an ontology term; a term known only by name
%     list                   join separately built entries into one array
%     composite              the general form: any nested structure a class declares
%     datumType              a MATLAB / source type name -> `datum_type`
%
%   Checks beyond per-field types (the list lives in private/checkRules.m):
%     the schema's own `rules` (key_regular_origin_spacing,
%     key_positions_one_form, key_chunk_sampled_only, datum_type_when_bytes,
%     clock_with_start, ingredients_or_product) -- an UNKNOWN rule is an error,
%     not a skip; `require_inherited`; conditions carry one value; variables are
%     unique across keys and conditions; parameters carry one form and are
%     unique; inline parameters and method_parameters_id are never both given;
%     key n matches its positions; a multi-key sampled_body names datum_order.
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
%     obs = did2.build.statement('voltage_observation', subjectId, 'voltage', [], ...
%         'DataBody', true, 'DatumType', did2.build.datumType('int16'), ...
%         'TimeReferenceIds', {ref.base.id}, 'SessionId', sid);
%     body = did2.build.sampledBody(obs.base.id, did2.build.list( ...
%             did2.build.key('time', 1800000, 'Unit', 'second', 'Origin', 0, 'Spacing', 1/30000), ...
%             did2.build.key('channel', 32, 'Values', 1:32)), ...
%         'DatumOrder', 'F', 'ByteOrder', 'little', 'SessionId', sid);
