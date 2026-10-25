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
%   The first entry is did2.schema.v2Stamp, the stamp every V2 writer puts.
%
%   'V_eta' IS TRANSITIONAL. The writers now stamp 'did_v2'; 'V_eta' stays
%   here only so documents written before that (the existing V2 imports)
%   still read until the next step removes it ([V_eta stamp not accepted]).
%   Delete 'V_eta' from this line then; nothing else lists it as a stamp.
%
%   See also did2.schema.v2Stamp, did2.schema.isV2Stamp,
%            did2.schema.isV1Stamp, did2.convert.schemaVersionRank.

names = {did2.schema.v2Stamp(), 'V_eta'};   % 'V_eta': transitional, see above
end
