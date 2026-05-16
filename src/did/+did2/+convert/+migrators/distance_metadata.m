function v2Body = distance_metadata(preBody)
%DISTANCE_METADATA Migrate a did_v1 distance_metadata body to V_delta.
%
%   v1 carries a paired A/B endpoint structure:
%
%       distance_metadata.ontologyNode_A          (after universalRenames:
%                                                  ontology_node_a) - CURIE
%       distance_metadata.integerIDs_A            (scalar or matrix)
%       distance_metadata.ontologyStringValues_A  (comma-separated did_uids)
%       distance_metadata.ontologyNumericValues_A (matrix; often empty)
%       (same set for endpoint B)
%       distance_metadata.units                   (CURIE)
%
%   V_delta collapses both endpoints into a single
%   `endpoints` array-of-records (mirrors the position_metadata
%   dimensions pattern) with explicit per-endpoint `label`s
%   preserved from v1:
%
%       distance_metadata.endpoints(i).label           - 'A', 'B'
%       distance_metadata.endpoints(i).measurement     (ontology_term)
%       distance_metadata.endpoints(i).integer_ids     - matrix
%       distance_metadata.endpoints(i).string_ids      - string array
%       distance_metadata.endpoints(i).numeric_values  - matrix
%       distance_metadata.units                        (ontology_term)
%
%   Ontology terms have their `name` resolved via ndi.ontology.lookup
%   at conversion time; lookup failures (library unavailable, CURIE
%   unknown) leave `name` empty.
%
%   The migrator only walks endpoints actually present in the v1
%   doc. Most v1 docs in the JH corpus have endpoints 'A' and 'B';
%   any v1 doc that ships further endpoints (e.g., 'C') would be
%   migrated as a 3-element array, preserving the v1 information.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'distance_metadata') ...
        || ~isstruct(v2Body.distance_metadata)
    error('did2:convert:missingBlock', ...
        'distance_metadata body is missing the distance_metadata property block.');
end

block = v2Body.distance_metadata;

labels = discoverEndpointLabels(block);
endpoints = struct('label', {}, 'measurement', {}, ...
    'integer_ids', {}, 'string_ids', {}, 'numeric_values', {});
for k = 1:numel(labels)
    L = labels{k};
    endpoints(end+1) = buildEndpoint(block, L); %#ok<AGROW>
end

unitsNode = '';
if isfield(block, 'units')
    unitsNode = char(block.units);
end

newBlock = struct();
newBlock.endpoints = endpoints;
newBlock.units = ontologyTerm(unitsNode);
v2Body.distance_metadata = newBlock;
end

function labels = discoverEndpointLabels(block)
% Find every label X that appears as a suffix on `ontology_node_X`
% in the v1 block. v1 in the JH corpus uses 'A' and 'B'; this is
% future-proof for any single uppercase letter.
labels = {};
fns = fieldnames(block);
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(fns)
    fn = fns{k};
    tokens = regexp(fn, '^ontology_node_(.+)$', 'tokens', 'once');
    if isempty(tokens); continue; end
    L = upper(tokens{1});
    if ~seen.isKey(L)
        seen(L) = true;
        labels{end+1} = L; %#ok<AGROW>
    end
end
labels = sort(labels);
end

function ep = buildEndpoint(block, label)
% Build one V_delta endpoint record from v1's per-label fields.
% All fields are tolerant of absence: missing v1 fields default to
% empty values of the right type.
nodeKey       = sprintf('ontology_node_%s',           lower(label));
intIdsKey     = sprintf('integer_i_ds_%s',            lower(label));
stringIdsKey  = sprintf('ontology_string_values_%s',  lower(label));
numericKey    = sprintf('ontology_numeric_values_%s', lower(label));

if isfield(block, nodeKey)
    nodeVal = char(block.(nodeKey));
else
    nodeVal = '';
end
if isfield(block, intIdsKey)
    intIds = double(block.(intIdsKey));
    intIds = intIds(:)';
else
    intIds = [];
end
if isfield(block, stringIdsKey)
    raw = block.(stringIdsKey);
    if ischar(raw)
        parts = strsplit(raw, ',');
        parts = cellfun(@strtrim, parts, 'UniformOutput', false);
        parts = parts(~cellfun('isempty', parts));
        stringIds = string(parts);
    elseif isstring(raw)
        stringIds = raw(:)';
    else
        stringIds = string.empty(1, 0);
    end
else
    stringIds = string.empty(1, 0);
end
if isfield(block, numericKey)
    nums = block.(numericKey);
    if isnumeric(nums)
        nums = double(nums(:)');
    else
        nums = [];
    end
else
    nums = [];
end

ep = struct( ...
    'label',          label, ...
    'measurement',    ontologyTerm(nodeVal), ...
    'integer_ids',    intIds, ...
    'string_ids',     stringIds, ...
    'numeric_values', nums);
end

function term = ontologyTerm(curie)
% Build an ontology_term composite. Empty input yields a node-only,
% name-empty struct. ndi.ontology.lookup failures leave name ''.
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
