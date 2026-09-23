function bodies = file_reference(preBody)
%FILE_REFERENCE Brainstorm-J migrator: did_v1 fileReference -> V_eta
%   file_reference, an id-preserving 1:1 passthrough. ⊂ base in V_eta;
%   NOT folded to `generic_file` -- the two classes coexist BY DESIGN per
%   the file_reference .md doc: `generic_file` HOLDS bytes, while
%   `file_reference` RECORDS the identity of an external file that lives
%   somewhere else (original_path, format_ontology, date_created,
%   date_updated, file_size, checksum, checksum_algorithm). This migrator
%   is DELIBERATELY NOT routed through +did2.+convert.foldGenericFiles;
%   universalRenames has already snake_cased the block field names that
%   were camelCase in NDI (originalPath -> original_path, formatOntology
%   -> format_ontology, dateCreated -> date_created, dateUpdated ->
%   date_updated, fileSize -> file_size, checksumAlgorithm ->
%   checksum_algorithm), which is exactly the V_eta schema's spelling.
%   The optional `document_id` edge (pointing at the document this file
%   is a reference to) carries through as-is. base.id is preserved.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   `fileReference` PERSISTS as a distinct class -- explicitly not folded
%   to `generic_file`. Scope: DID-schema OPEN_WORK #122 / #123. Row #124
%   (corpus proof) is DEFERRED; #126 (T8 binding follow-ons:
%   `format_ontology`, `checksum_algorithm`) is out of scope here.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
