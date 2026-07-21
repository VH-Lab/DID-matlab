function bodies = distance_metadata(preBody)
%DISTANCE_METADATA Brainstorm-J migrator: did_v1 distance_metadata -> a
%   length_observation (the measured distance) about the element-subject + anchor.
%   1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. A
%   distance between two labelled endpoints becomes a `length_observation` of the
%   element-subject: subject_statement.variable = the measurement term
%   (`endpoints.measurement`, else 'distance'); the leaf value = numeric_values as
%   a length-N inline value (one measurement per pair); source_unit from the
%   `units` ontology term. DEFERRED: the endpoint identities (label / *_ids) --
%   which two points -- await the Path-S subject graph (the NDI second pass).
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'distance_metadata') && isstruct(preBody.distance_metadata)
    blk = preBody.distance_metadata;
end
endpoints = struct();
if isfield(blk, 'endpoints') && isstruct(blk.endpoints); endpoints = blk.endpoints; end
% `numeric_values` is NESTED inside the endpoints structure, so universalRenames
% (which snake_cases only immediate block fields) leaves its raw v1 casing
% untouched. Read snake-first with a camelCase fallback so a camelCase source is
% not silently read empty (which would drop to the passthrough branch and
% quarantine on the required non-empty `endpoints` -- the JH files DO carry
% distance values, so an empty read there is a bug, not real missing data).
vals = [];
for nm = {'numeric_values', 'numericValues'}
    if isfield(endpoints, nm{1}) && isnumeric(endpoints.(nm{1})) ...
            && ~isempty(endpoints.(nm{1}))
        vals = double(endpoints.(nm{1})(:)');
        break;
    end
end
unit = '';
if isfield(blk, 'units') && isstruct(blk.units); unit = jGetChar(blk.units, 'name'); end

variable = jOntologyTerm('', 'distance');
if isfield(endpoints, 'measurement') && isstruct(endpoints.measurement)
    m = endpoints.measurement;
    nm = jGetChar(m, 'name');
    if isempty(nm); nm = 'distance'; end
    variable = jOntologyTerm(jGetChar(m, 'node'), nm);
end

anchor = jSessionAnchor(preBody, 'during');
if isempty(vals)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

obs = jStartInteraction(preBody, 'length_observation', 'subject_observation', ...
    {'length'}, variable, {'element_id', 'subject_id'});
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.length = struct('value', jMeasureArray(vals, unit));

bodies = {obs, anchor};
end
