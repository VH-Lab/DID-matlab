function rt = responseTypeBack(term, harmonic)
%RESPONSETYPEBACK The v1 `response_type` text of a value's `response_type`
%   term and `harmonic`: the inverse of did2.convert.migrators_j
%   jResponseType ([response type harmonics are integers], Decided by Jess
%   Haley, 2026-11-12; [harmonic is a field beside the response type],
%   2026-11-17): NCIT:C53319 Arithmetic Mean is `mean`, STATO:0000151
%   maximum observed value is `peak`, NCIT:C94900 Fourier Analysis with
%   HARMONIC 1 is `F1` and with HARMONIC 2 `F2` (by node); any other term
%   gives its label, as before, so a document migrated before the harmonic
%   was written (the label `F1` or `F2`, no node) reads back the same.
if nargin < 2
    harmonic = [];
end
[node, rt] = termParts(term);
if sameCurie(node, 'NCIT:C53319')
    rt = 'mean';
elseif sameCurie(node, 'STATO:0000151')
    rt = 'peak';
elseif sameCurie(node, 'NCIT:C94900') && isnumeric(harmonic) && isscalar(harmonic) ...
        && any(harmonic == [1 2])
    rt = sprintf('F%d', harmonic);
end
end
