function t = jResponseType(rt)
%JRESPONSETYPE A tuning or contrast-sensitivity v1 `response_type` as the
%   value's `response_type` term.
%
%   [response type harmonics are integers] (Decided by Jess Haley,
%   2026-11-12, did-schema docs/plans/did_v2_go_forward_class_audit.md): a
%   `response_type` of `mean` (F0) is NCIT:C53319 Arithmetic Mean and `peak`
%   is STATO:0000151 "maximum observed value", both registered. The v1
%   spellings are the writers' exactly (NDI tuning_response.m writes `mean`
%   for harmonic 0; NDIcalc-vis-matlab copies it), so only those two convert;
%   any other text is the label it was, as before. The round trip gives each
%   node its v1 spelling back (+roundtrip/private/responseTypeBack.m).
%
%   F1 and F2 are decided to be the integer harmonic (1, 2), not terms, but
%   no decision says where a tuning curve or contrast sensitivity value
%   writes that integer (the integer field is `harmonic_component.value.harmonic`,
%   which neither value declares), so they stay labels until it is.
switch rt
    case 'mean'
        t = did2.convert.registeredTerm('NCIT:C53319', 'Arithmetic Mean');
    case 'peak'
        t = did2.convert.registeredTerm('STATO:0000151', 'maximum observed value');
    otherwise
        t = jLabel(rt);
end
end
