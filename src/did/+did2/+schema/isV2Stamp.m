function tf = isV2Stamp(v)
%ISV2STAMP True when V names the current V2 document generation.
%
%   TF = did2.schema.isV2Stamp(V). V is a stamp (char or string), or a
%   document (struct, did2.document or did.document), whose stamp is read
%   with did2.schema.stampOf. TF is true for a name in did2.schema.v2Stamps.
%
%   The accepted names are did2.schema.v2Stamps, the ONE list (Decided by
%   Jess Haley, 2026-10-25 [document stamps] and [V_eta stamp not
%   accepted]): 'did_v2', and 'V_eta' only while writers still stamp it.
%   An unknown name is false, and so is every v1 stamp (did2.schema.isV1Stamp).
%
%   See also did2.schema.isV1Stamp, did2.schema.stampOf,
%            did2.convert.schemaVersionRank.

if ~(ischar(v) || (isstring(v) && isscalar(v)))
    v = did2.schema.stampOf(v);
end
v = char(v);
if isempty(v)
    tf = false;
    return;
end
tf = any(strcmp(reshape(v, 1, []), did2.schema.v2Stamps()));
end
