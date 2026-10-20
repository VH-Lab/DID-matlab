function id = sessionDocumentId(documentId, sessionId)
%SESSIONDOCUMENTID The base.id a migrated session document has, on either schema.
%
%   ID = did2.unittest.helpers.sessionDocumentId(DOCUMENTID, SESSIONID) is
%   SESSIONID when the loaded schema stores the session id as the `session_id`
%   EDGE, and DOCUMENTID (the v1 session document's own base.id, preserved)
%   when it stores it as the base.session_id field.
%
%   did-schema V_eta_relation_inheritance_plan.md (2026-10-20): on the edge
%   shape the session entity's base.id IS its session id --
%   did2.convert.migrators_j.session re-ids it -- so every pass that resolves
%   "the session document" for a session id finds the session id itself. The
%   fixtures here give the session document a DIFFERENT v1 id, which is the v1
%   reality and what the field shape still preserves.
%
%   STATUS: NOT VERIFIED BY EXECUTION in the authoring environment (no MATLAB).

arguments
    documentId (1,:) char
    sessionId (1,:) char
end

if did2.schema.cache.shared().sessionIdIsEdge()
    id = sessionId;
else
    id = documentId;
end
end
