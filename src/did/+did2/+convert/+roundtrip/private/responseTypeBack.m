function rt = responseTypeBack(term)
%RESPONSETYPEBACK The v1 `response_type` text of a value's `response_type`
%   term: the inverse of did2.convert.migrators_j jResponseType
%   ([response type harmonics are integers], Decided by Jess Haley,
%   2026-11-12): NCIT:C53319 Arithmetic Mean is `mean`, STATO:0000151
%   maximum observed value is `peak` (by node); any other term gives its
%   label, as before.
[node, rt] = termParts(term);
if sameCurie(node, 'NCIT:C53319')
    rt = 'mean';
elseif sameCurie(node, 'STATO:0000151')
    rt = 'peak';
end
end
