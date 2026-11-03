function stamp = targetStamp(targetVersion)
%TARGETSTAMP The document stamp a migration to TARGETVERSION writes.
%
%   STAMP = did2.convert.targetStamp(TARGETVERSION). TARGETVERSION is the
%   `TargetVersion` option of did2.convert.v1_to_v2 and the batch passes:
%   the name of the did-schema schema SET the migrators target ('did_v2'). It is not a
%   document stamp. A document migrated to that set is stamped
%   did2.schema.v2Stamp() ('did_v2'; did-schema `schema_version_value`).
%
%   Decided by Jess Haley, 2026-10-25 [document stamps] (did-schema
%   V_eta_go_forward_class_audit.md): a v2 document's
%   document_class.schema_version is 'did_v2'. Before that decision the set
%   name and the stamp were the same string, so v1_to_v2 wrote
%   TargetVersion itself as the stamp; this function is where they part.
%
%   The set's earlier name 'V_eta' was mapped to 'did_v2' here until
%   Decided by Jess Haley, 2026-11-02 [V_eta not kept as an alias]: it is no
%   longer an accepted TargetVersion, so it is not mapped. Which stamps a
%   reader accepts is did2.schema.v2Stamps, and nothing else.
%
%   TARGETVERSION is returned unchanged (the set 'did_v2' writes the stamp
%   'did_v2', on the did2.convert.schemaVersionRank line).
%
%   See also did2.schema.v2Stamp, did2.convert.isAlreadyTarget,
%            did2.convert.v1_to_v2.

arguments
    targetVersion {mustBeText}
end

stamp = char(targetVersion);
end
