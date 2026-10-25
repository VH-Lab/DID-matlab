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
%   'V_eta' IS NOT A STAMP ANY MORE ([V_eta stamp not accepted]). A document
%   stamped 'V_eta' is not read as V2: did2.convert.schemaVersionRank does
%   not know it, so v1_to_v2 quarantines it as
%   did2:convert:unknownSchemaVersion. There is no alias. 'V_eta' remains
%   the name of the schema SET (TargetVersion; did2.convert.targetStamp).
%
%   See also did2.schema.v2Stamp, did2.schema.isV2Stamp,
%            did2.schema.isV1Stamp, did2.convert.schemaVersionRank.

names = {did2.schema.v2Stamp()};
end
