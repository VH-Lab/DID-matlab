function x = tuningSummary(leaf, name)
%TUNINGSUMMARY A tuning calculation's summary NAME ('circular_statistics',
%   'interpolated_values'), wherever the document holds it.
%
%   X = did2.unittest.helpers.tuningSummary(LEAF, NAME). LEAF is a converted
%   tuning calculation (a struct). [tuning summaries in the value] (Decided by
%   Jess Haley, 2026-11-10, did-schema did_v2_go_forward_class_audit.md):
%   the two summaries move from the calculator class's own block into
%   `tuning_curve.value`; DID-matlab writes them where the loaded schema
%   declares them, so a test reads them from the value when it holds NAME,
%   else from the calculator's own block. [] when neither does.
x = [];
if isfield(leaf, 'tuning_curve') && isfield(leaf.tuning_curve, 'value') ...
        && isstruct(leaf.tuning_curve.value) && isfield(leaf.tuning_curve.value, name)
    x = leaf.tuning_curve.value.(name);
    return;
end
fns = fieldnames(leaf);
for k = 1:numel(fns)
    b = leaf.(fns{k});
    if isstruct(b) && isscalar(b) && isfield(b, name)
        x = b.(name);
        return;
    end
end
end
