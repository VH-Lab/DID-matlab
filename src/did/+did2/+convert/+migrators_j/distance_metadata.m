function bodies = distance_metadata(preBody)
%DISTANCE_METADATA Brainstorm-J migrator: carry a v1 distance_metadata whole as
%   v1. 1 -> 1.
%
%   ================ [reshaped retire classes carried] =====================
%   Decided by Jess Haley, 2026-10-29 (did-schema
%   V_eta_go_forward_class_audit.md, "B"): v1 `distance_metadata` and
%   `oneepoch` are carried whole as v1 for now, not reshaped into their retire
%   classes; the reshape waits for their V2 homes (`distance_metadata`: a
%   decision still to make, docs/V2_PLAN.md G50). So EVERY distance_metadata
%   is carried whole as v1 (the untouched v1 source, with a `carried_as_v1`
%   note): one holding a field outside its NDI template under carry-100, as
%   before, and every other one under register row carry-147, awaiting_home.
%   The reshape into the V_eta `distance_metadata` (a class whose disposition
%   is `retire`) described below is no longer done; the description is the
%   record of what was replaced. did2.convert.roundtrip.distance_metadata, its
%   inverse, is reached by no migrator output any more; a carried document's
%   round trip is the carry itself (did2.convert.roundtrip.check).
%   =======================================================================
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The v1
%   doc is FLAT and records the two ENDPOINTS of a distance measurement, not the
%   distance itself: `ontologyNode_A` / `_B` name what each endpoint is (the JH
%   writer: EMPTY:0000096 "subject document identifier" and EMPTY:0000134
%   "bacterial patch document identifier"), `ontologyStringValues_A` / `_B` the
%   ids of those documents (comma-separated), `integerIDs_A` / `_B` their
%   indices, `ontologyNumericValues_A/_B` are `[]` by design, `units` a CURIE,
%   and `depends_on element_id` points at the `distance` TIMESERIES element
%   (where the actual distances over time live).
%
%   The V_eta distance_metadata collapses the flat per-endpoint A/B fields into
%   a nested `endpoints` array-of-records + a `units` ontology_term:
%
%       endpoints(i).label           'A', 'B' (the suffix, upper case)
%       endpoints(i).measurement     ontology_term {node: ontologyNode_X,
%                                    name: ndi.ontology.lookup's, else ''}
%       endpoints(i).integer_ids     integerIDs_X, as a row
%       endpoints(i).string_ids      ontologyStringValues_X split on ','
%       endpoints(i).numeric_values  ontologyNumericValues_X, as a row
%       units                        ontology_term {node: units}
%
%   Endpoints are found by the `ontologyNode_<X>` fields the document holds, in
%   label order, so a third endpoint would be kept too.
%
%   It deliberately does NOT:
%     - emit a `length_observation`: there is no scalar distance in the metadata
%       doc (the value is the linked element's timeseries) -- Part B, a genuine
%       second pass riding on the element-data -> observation decomposition
%       (deferred, overlaps #9); do not fabricate a values-less observation; and
%     - mint an endpoint relation: both endpoint ids are PRE-migration ids that
%       dangle in a single-doc pass (Part A was tried and reverted, corpus
%       946faf95: 4156 JH orphans, a gating failure). The endpoints can only be
%       resolved by the second pass, which sees the migrated-id graph.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1] and [early migration pieces fixed] (1),
%   did-schema V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator
%   the document exactly as v1 wrote it (NDI distance_metadata.json + base.json
%   at the locked NDI-matlab `main`, 3cb19a8, as +setup/+conv/+haley/doImport.m
%   writes it), and the reshape the old base migrator
%   (+migrators/distance_metadata.m, deleted) did on the universalRenames
%   spelling (ontology_node_a, integer_i_ds_a, ...) is done here on the v1
%   spelling (and on that one, which the rename pass, since deleted, wrote). Every v1 field and where it
%   goes;
%   did2.convert.roundtrip.distance_metadata rebuilds the v1 document and
%   testRawV1RoundTripPosition compares the two:
%
%     base.id, session_id, name, datestamp  -> the same document's base (and
%                                              its session edge)
%     depends_on element_id                 -> the same edge
%     distance_metadata.<field>_<X>         -> endpoints(i), as above
%     distance_metadata.units               -> units.node
%
%   What the renamed path would have discarded is carried, carry-100, as
%   before; a field or edge no part of this migrator reads (e.g. an
%   integerIDs_C with no ontologyNode_C) now carries the document whole as v1
%   (private/jRawAccount, jRawCarry; carry-100, [fields outside the template
%   are malformed]). The JH writer's
%   documents hang off an element of type `distance`, which is carried
%   (carry-063), so v1_to_v2 carries them too (carry-064, [dependents of a
%   carried document carry]).
%
%   See schemas/V_eta_distance_metadata_plan.md (did-schema).
arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
blk = struct();
if isfield(src, 'distance_metadata') && isstruct(src.distance_metadata) ...
        && isscalar(src.distance_metadata)
    blk = src.distance_metadata;
end
suffixes = endpointSuffixes(blk);
read = {'units'};
for k = 1:numel(suffixes)
    x = suffixes{k};
    read = [read, {['ontologyNode_' x], ['integerIDs_' x], ...
        ['ontologyNumericValues_' x], ['ontologyStringValues_' x]}]; %#ok<AGROW>
end
[preBody, collision, unplaced] = jRawAccount(src, ...
    struct('distance_metadata', {read}), {'^element_id$'});
if jRawCarry('distance_metadata', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

if ~isfield(preBody, 'distance_metadata') || ~isstruct(preBody.distance_metadata)
    error('did2:convert:missingBlock', ...
        'distance_metadata body is missing the distance_metadata property block.');
end

% [reshaped retire classes carried] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): no longer reshaped into the retire class
% `distance_metadata`; carried whole as v1 until its V2 home is decided.
b = did2.convert.v1read.readBase(src);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: carry-147
did2.convert.reportNote('carried_as_v1', 'distance_metadata', id, ...
    ['[carry-147] awaiting_home: distance_metadata, until its V2 home is ' ...
    'decided ([reshaped retire classes carried])']);
bodies = {src};
end

function suffixes = endpointSuffixes(block)
% Every X with an `ontologyNode_X` field, as the document spells it. The JH
% writer uses 'A' and 'B'; any further suffix is an endpoint too.
suffixes = {};
fns = fieldnames(block);
for k = 1:numel(fns)
    tokens = regexp(fns{k}, '^ontologyNode_(.+)$', 'tokens', 'once');
    if ~isempty(tokens) && ~any(strcmp(suffixes, tokens{1}))
        suffixes{end+1} = tokens{1}; %#ok<AGROW>
    end
end
end
