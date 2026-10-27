function bodies = distance_metadata(preBody)
%DISTANCE_METADATA Brainstorm-J migrator: reshape a did_v1 distance_metadata into
%   the validated V_eta distance_metadata. 1 -> 1.
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
%   spelling (and on that one, which v1_to_v2's 'RawV1Classes', {} path still
%   hands it until universalRenames is deleted). Every v1 field and where it
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
%   What the renamed path would have discarded is carried, carry-049, as
%   before; a field or edge no part of this migrator reads (e.g. an
%   integerIDs_C with no ontologyNode_C) now carries the document whole as v1
%   (private/jRawAccount, jRawCarry; no register row yet). The JH writer's
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
if jRawCarry('distance_metadata', src, collision, unplaced)
    bodies = {src};
    return;
end

if ~isfield(preBody, 'distance_metadata') || ~isstruct(preBody.distance_metadata)
    error('did2:convert:missingBlock', ...
        'distance_metadata body is missing the distance_metadata property block.');
end

% the endpoint labels: the v1 suffixes, and on the renamed path (v1_to_v2
% 'RawV1Classes', {}, until universalRenames is deleted) the suffixes of the
% spelling that pass gives them (ontology_node_a, integer_i_ds_a, ...)
labels = upper(suffixes);
renamed = renamedSuffixes(blk);
labels = [labels, upper(renamed(~ismember(upper(renamed), labels)))];
[labels, order] = sort(labels);
raw = [suffixes, repmat({''}, 1, numel(labels) - numel(suffixes))];
raw = raw(order);
endpoints = struct('label', {}, 'measurement', {}, ...
    'integer_ids', {}, 'string_ids', {}, 'numeric_values', {});
for k = 1:numel(labels)
    endpoints(end+1) = buildEndpoint(blk, labels{k}, raw{k}); %#ok<AGROW>
end

unitsNode = '';
if isfield(blk, 'units')
    unitsNode = char(blk.units);
end

v2Body = preBody;
if isfield(v2Body, 'depends_on') && ~isempty(v2Body.depends_on)
    % the {name, document_id} entries the renamed path gave the document
    deps = did2.convert.v1read.readDependsOn(src);
    v2Body.depends_on = struct('name', {deps.name}, 'document_id', {deps.document_id});
end
v2Body.distance_metadata = struct('endpoints', endpoints, 'units', ontologyTerm(unitsNode));
bodies = {v2Body};
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

function suffixes = renamedSuffixes(block)
% Every x with an `ontology_node_x` field (universalRenames' spelling).
suffixes = {};
fns = fieldnames(block);
for k = 1:numel(fns)
    tokens = regexp(fns{k}, '^ontology_node_(.+)$', 'tokens', 'once');
    if ~isempty(tokens) && ~any(strcmpi(suffixes, tokens{1}))
        suffixes{end+1} = tokens{1}; %#ok<AGROW>
    end
end
end

function [v, found] = endpointField(block, rawName, x, renamedName, label)
% The v1 field <rawName>_<x>, else universalRenames' <renamedName>_<label>.
v = [];
found = false;
names = {};
if ~isempty(x)
    names{end+1} = [rawName '_' x];
end
names{end+1} = [renamedName '_' lower(label)];
for k = 1:numel(names)
    if isfield(block, names{k})
        v = block.(names{k});
        found = true;
        return;
    end
end
end

function ep = buildEndpoint(block, label, x)
% One V2 endpoint record from v1's per-suffix fields (X, as the document
% spells it, or '' when only the renamed spelling holds the endpoint). A field
% the document does not have is an empty value of the right type.
nodeVal = '';
[v, found] = endpointField(block, 'ontologyNode', x, 'ontology_node', label);
if found
    nodeVal = char(v);
end
intIds = [];
[v, found] = endpointField(block, 'integerIDs', x, 'integer_i_ds', label);
if found
    intIds = double(v);
    intIds = intIds(:)';
end
stringIds = string.empty(1, 0);
[raw, found] = endpointField(block, 'ontologyStringValues', x, 'ontology_string_values', label);
if found
    if ischar(raw)
        parts = strsplit(raw, ',');
        parts = cellfun(@strtrim, parts, 'UniformOutput', false);
        parts = parts(~cellfun('isempty', parts));
        stringIds = string(parts);
    elseif isstring(raw)
        stringIds = raw(:)';
    end
end
nums = [];
[v, found] = endpointField(block, 'ontologyNumericValues', x, 'ontology_numeric_values', label);
if found
    if isnumeric(v)
        nums = double(v(:)');
    end
end
ep = struct( ...
    'label',          label, ...
    'measurement',    ontologyTerm(nodeVal), ...
    'integer_ids',    intIds, ...
    'string_ids',     stringIds, ...
    'numeric_values', nums);
end

function term = ontologyTerm(curie)
% An ontology_term composite. Empty input yields a node-only, name-empty
% struct. ndi.ontology.lookup failures leave name ''.
term = struct('node', char(curie), 'name', '');
if isempty(curie)
    return;
end
try
    [~, resolved] = ndi.ontology.lookup(char(curie));
    if isstring(resolved) && isscalar(resolved)
        term.name = char(resolved);
    elseif ischar(resolved)
        term.name = resolved;
    end
catch
    % ndi.ontology not on path or curie unknown; leave name ''.
end
end
