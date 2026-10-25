function stamp = v2Stamp()
%V2STAMP The document_class.schema_version a V2 writer puts on a document.
%
%   STAMP = did2.schema.v2Stamp() returns 'did_v2'.
%
%   Decided by Jess Haley, 2026-10-25 [document stamps] (did-schema
%   V_eta_go_forward_class_audit.md): a v1 document's
%   document_class.schema_version is 'did_v1' and a V2 document's is
%   'did_v2'. did-schema records the same value as `schema_version_value` in
%   schemas/V_eta/index.json.
%
%   Every V2 writer takes its stamp from here (did2.build.document,
%   did2.schema.cache/buildBlankDocument, did2.convert.v1_to_v2 through
%   did2.convert.targetStamp, the batch passes and the split migrators), so
%   the value is written in one place. It is the first entry of
%   did2.schema.v2Stamps, the list the readers accept.
%
%   See also did2.schema.v2Stamps, did2.schema.isV2Stamp,
%            did2.convert.targetStamp.

stamp = 'did_v2';
end
