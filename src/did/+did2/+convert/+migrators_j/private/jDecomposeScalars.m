function extra = jDecomposeScalars(preBody, sourceId, anchorId, specs)
%JDECOMPOSESCALARS Emit computed <dim>_observations for a list of interpretable
%   scalars (D-C analysis-tier decomposition, grain A). Each row of `specs` is a
%   6-cell record:
%
%     {block, field, dim, variable, method, unit}
%
%   block    the (already-resolved) source struct holding the scalar.
%   field    the scalar field name within `block`.
%   dim      the data-type leaf: 'angle' | 'frequency' | 'score'.
%   variable the spine label (subject_statement.variable name).
%   method   the algorithm ontology term name (marks the value COMPUTED).
%   unit     source_unit for angle/frequency (ignored for score).
%
%   Absent or NaN scalars are skipped -- nothing is invented. Every observation is
%   of the same subject and carries derived_from_1 -> sourceId (the curve
%   observation it was computed from). Shared helper for the Brainstorm-J
%   (+migrators_j) analysis-tier decomposition migrators.
extra = {};
for i = 1:size(specs, 1)
    v = pickNum(specs{i, 1}, specs{i, 2});
    if isempty(v); continue; end
    switch specs{i, 3}
        case 'angle'
            leaf = 'angle_observation'; mixin = 'angle';
            vb = jMeasureArray(v, specs{i, 6});
        case 'frequency'
            leaf = 'frequency_observation'; mixin = 'frequency';
            vb = jMeasureArray(v, specs{i, 6});
        otherwise
            leaf = 'score_observation'; mixin = 'score';
            vb = struct('value', double(v), 'scale', jOntologyTerm('', ''), ...
                'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
    end
    extra{end + 1} = jComputedScalar(preBody, anchorId, sourceId, leaf, mixin, ...
        specs{i, 4}, specs{i, 5}, vb); %#ok<AGROW>
end
end

function v = pickNum(blk, name)
v = [];
if isstruct(blk) && isfield(blk, name)
    x = blk.(name);
    if isnumeric(x) && isscalar(x) && ~isnan(x); v = double(x); end
end
end
