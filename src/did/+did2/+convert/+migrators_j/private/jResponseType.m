function [t, harmonic] = jResponseType(rt, withHarmonic)
%JRESPONSETYPE A tuning or contrast-sensitivity v1 `response_type` as the
%   value's `response_type` term, and its integer `harmonic`.
%
%   [T, HARMONIC] = jResponseType(RT, WITHHARMONIC)
%
%   [response type harmonics are integers] (Decided by Jess Haley,
%   2026-11-12, did-schema docs/plans/did_v2_go_forward_class_audit.md): a
%   `response_type` of `mean` (F0) is NCIT:C53319 Arithmetic Mean and `peak`
%   is STATO:0000151 "maximum observed value", both registered. The v1
%   spellings are the writers' exactly (NDI tuning_response.m writes `mean`
%   for harmonic 0; NDIcalc-vis-matlab copies it). The round trip gives each
%   node its v1 spelling back (+roundtrip/private/responseTypeBack.m).
%
%   [harmonic is a field beside the response type] (Decided by Jess Haley,
%   2026-11-17, same document): `F1` is NCIT:C94900 "Fourier Analysis" with
%   HARMONIC 1, `F2` Fourier Analysis with HARMONIC 2, written in the value's
%   integer `harmonic` beside the response type; `mean` and `peak` have no
%   harmonic (HARMONIC []). Siblings first: the caller passes WITHHARMONIC
%   true only when the loaded schema declares the value's `harmonic`
%   (jSchemaHasPath); with false, F1 and F2 stay the labels they were, as
%   before (a schema older than did-schema ce262d0, #336, which declares
%   `harmonic` on both values and registers NCIT:C94900). Any other text is
%   the label it was.
arguments
    rt
    withHarmonic (1,1) logical = false
end
harmonic = [];
switch rt
    case 'mean'
        t = did2.convert.registeredTerm('NCIT:C53319', 'Arithmetic Mean');
    case 'peak'
        t = did2.convert.registeredTerm('STATO:0000151', 'maximum observed value');
    case {'F1', 'F2'}
        if withHarmonic
            t = did2.convert.registeredTerm('NCIT:C94900', 'Fourier Analysis');
            harmonic = str2double(rt(2));
        else
            t = jLabel(rt);
        end
    otherwise
        t = jLabel(rt);
end
end
