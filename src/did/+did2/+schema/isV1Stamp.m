function tf = isV1Stamp(v, opts)
%ISV1STAMP True when V names a v1 (did_v1) document.
%
%   TF = did2.schema.isV1Stamp(V). V is a stamp (char or string), or a
%   document (struct, did2.document or did.document), whose stamp is read
%   with did2.schema.stampOf. TF is true for 'did_v1' and for the EMPTY
%   stamp: a v1 document written before the stamps were named carries none.
%
%   Decided by Jess Haley, 2026-10-25 [document stamps] (did-schema
%   V_eta_go_forward_class_audit.md): a v1 document's
%   document_class.schema_version is 'did_v1'. Both rank 0 in
%   did2.convert.schemaVersionRank. The brainstorm names (V_alpha ..
%   V_zeta) and unknown names are neither v1 nor V2: false here and in
%   did2.schema.isV2Stamp.
%
%   TF = did2.schema.isV1Stamp(V, 'Explicit', true) is true for 'did_v1'
%   only: the stamp must be PRESENT. That is the question a V2 database asks
%   before it skips V_eta validation and reads a body as stored (Decided by
%   Jess Haley, 2026-10-24 [passthrough stays v1: how]): a v1 document is
%   stored there by declaring itself one, and an unstamped body is
%   validated and read exactly as before.
%
%   See also did2.schema.isV2Stamp, did2.schema.stampOf,
%            did2.convert.schemaVersionRank.

arguments
    v
    opts.Explicit (1,1) logical = false
end

if ~(ischar(v) || (isstring(v) && isscalar(v)))
    v = did2.schema.stampOf(v);
end
v = char(v);
if isempty(v)
    tf = ~opts.Explicit;
    return;
end
[rank, known] = did2.convert.schemaVersionRank(reshape(v, 1, []));
tf = known && rank == 0;
end
