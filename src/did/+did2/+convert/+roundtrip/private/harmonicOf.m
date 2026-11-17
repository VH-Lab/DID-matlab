function h = harmonicOf(value)
%HARMONICOF A tuning or contrast-sensitivity value's integer `harmonic`
%   ([harmonic is a field beside the response type], Decided by Jess Haley,
%   2026-11-17, did-schema docs/plans/did_v2_go_forward_class_audit.md), or
%   [] when it states none (a value written before the field, or a response
%   type with no harmonic).
h = [];
if isstruct(value) && isscalar(value) && isfield(value, 'harmonic')
    v = value.harmonic;
    if iscell(v) && isscalar(v); v = v{1}; end
    if isnumeric(v) && isscalar(v) && isfinite(v)
        h = double(v);
    end
end
end
