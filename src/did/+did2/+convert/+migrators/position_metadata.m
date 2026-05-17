function v2Body = position_metadata(preBody)
%POSITION_METADATA Migrate a did_v1 position_metadata body to V_delta.
%
%   v1 carries three ontology-driven descriptor fields:
%
%       position_metadata.ontologyNode (after universalRenames:
%                                       ontology_node)   - what kind of
%                                                          position
%       position_metadata.units                          - unit (CURIE)
%       position_metadata.dimensions                     - comma-separated
%                                                          per-axis CURIEs
%
%   V_delta re-shapes these into ontology_term composites and an
%   array-of-records `dimensions` field with explicit per-axis
%   identifiers:
%
%       position_metadata.measurement       (ontology_term)
%       position_metadata.units             (ontology_term)
%       position_metadata.dimensions(i).axis  - 'axis_1', 'axis_2', ...
%       position_metadata.dimensions(i).node  - per-axis CURIE
%       position_metadata.dimensions(i).name  - resolved label
%
%   Human-readable names on the ontology terms are looked up via
%   ndi.ontology.lookup. If the lookup throws (ndi-ontology-matlab
%   not installed, CURIE unknown), the name stays empty -- the
%   V_delta ontology_term composite type only requires the value
%   to be a struct; the inner-field-name shape is open.
%
%   See did-schema's
%   schemas/V_delta/conversions/from_did_v1/position_metadata.md
%   for the full conversion spec.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'position_metadata') ...
        || ~isstruct(v2Body.position_metadata)
    error('did2:convert:missingBlock', ...
        'position_metadata body is missing the position_metadata property block.');
end

block = v2Body.position_metadata;

if isfield(block, 'ontology_node')
    measurementNode = char(block.ontology_node);
else
    measurementNode = '';
end
if isfield(block, 'units')
    unitsNode = char(block.units);
else
    unitsNode = '';
end
if isfield(block, 'dimensions')
    dimsRaw = block.dimensions;
else
    dimsRaw = '';
end

newBlock = struct();
newBlock.measurement = ontologyTerm(measurementNode);
newBlock.units = ontologyTerm(unitsNode);
newBlock.dimensions = buildDimensionRecords(dimsRaw);
v2Body.position_metadata = newBlock;
end

function term = ontologyTerm(curie)
% Build an ontology_term composite (node + name). Looks up the
% human-readable name via ndi.ontology.lookup; leaves the name
% empty if the lookup is unavailable or fails.
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
    % ndi.ontology not on the path or curie unknown; leave name ''
end
end

function records = buildDimensionRecords(raw)
% Parse v1's comma-separated `dimensions` CURIE list into an array
% of per-axis structs with explicit positional axis labels. Empty
% input -> 0-element struct array (schema marks the field optional,
% so empty is allowed).
records = struct('axis', {}, 'node', {}, 'name', {});
if isempty(raw)
    return;
end
if isstring(raw) && isscalar(raw)
    raw = char(raw);
end
if ~ischar(raw)
    return;
end
parts = strsplit(raw, ',');
for k = 1:numel(parts)
    curie = strtrim(parts{k});
    if isempty(curie)
        continue;
    end
    term = ontologyTerm(curie);
    records(end+1) = struct( ...
        'axis', sprintf('axis_%d', k), ...
        'node', term.node, ...
        'name', term.name); %#ok<AGROW>
end
end
