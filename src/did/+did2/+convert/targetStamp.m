function stamp = targetStamp(targetVersion)
%TARGETSTAMP The document stamp a migration to TARGETVERSION writes.
%
%   STAMP = did2.convert.targetStamp(TARGETVERSION). TARGETVERSION is the
%   `TargetVersion` option of did2.convert.v1_to_v2 and the batch passes:
%   the name of the did-schema schema SET the migrators target ('V_eta',
%   did-schema schemas/V_eta/index.json `set_version`). It is not a
%   document stamp. A document migrated to that set is stamped
%   did2.schema.v2Stamp() ('did_v2'; did-schema `schema_version_value`).
%
%   Decided by Jess Haley, 2026-10-25 [document stamps] (did-schema
%   V_eta_go_forward_class_audit.md): a V2 document's
%   document_class.schema_version is 'did_v2'. Before that decision the set
%   name and the stamp were the same string, so v1_to_v2 wrote
%   TargetVersion itself as the stamp; this function is where they part.
%
%   Mapping the SET name here does not make 'V_eta' an accepted document
%   stamp: which stamps a reader accepts is did2.schema.v2Stamps, and
%   nothing else.
%
%   Any other TARGETVERSION is returned unchanged (it is already a stamp on
%   the did2.convert.schemaVersionRank line, e.g. 'did_v2').
%
%   See also did2.schema.v2Stamp, did2.convert.isAlreadyTarget,
%            did2.convert.v1_to_v2.

arguments
    targetVersion {mustBeText}
end

stamp = char(targetVersion);
if strcmp(stamp, 'V_eta')   % the schema set (TargetVersion), not a stamp
    stamp = did2.schema.v2Stamp();
end
end
