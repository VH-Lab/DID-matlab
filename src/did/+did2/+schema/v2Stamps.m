function names = v2Stamps()
%V2STAMPS The document_class.schema_version values read as a V2 document.
%
%   NAMES = did2.schema.v2Stamps() returns the one list of stamps every
%   reader accepts as the current V2 generation (did2.schema.isV2Stamp, and
%   through it did2.convert.schemaVersionRank).
%
%   Decided by Jess Haley, 2026-10-25 [document stamps] (did-schema
%   V_eta_go_forward_class_audit.md): a V2 document is stamped 'did_v2'.
%   Decided by Jess Haley, 2026-10-25 [V_eta stamp not accepted]: "Stop
%   accepting veta" -- no alias, as with V_delta.
%
%   'V_eta' IS TRANSITIONAL. It is here only while the writers still stamp
%   it (did-schema's schema_version_value is 'V_eta' until its next step).
%   When the writers stamp 'did_v2', delete 'V_eta' from this line; nothing
%   else lists it.
%
%   See also did2.schema.isV2Stamp, did2.schema.isV1Stamp,
%            did2.convert.schemaVersionRank.

names = {'did_v2', 'V_eta'};   % 'V_eta': transitional, see above
end
