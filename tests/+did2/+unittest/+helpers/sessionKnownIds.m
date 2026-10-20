function ids = sessionKnownIds(docs)
%SESSIONKNOWNIDS The session ids a test batch names, as ids known outside it.
%
%   IDS = did2.unittest.helpers.sessionKnownIds(DOCS) is the distinct session
%   ids the documents in DOCS (a cell of did2.document or body structs) carry,
%   when the loaded schema stores the session id as the `session_id` EDGE
%   (did-schema V_eta_relation_inheritance_plan.md, 2026-10-20), and {} when it
%   stores it as the base.session_id field.
%
%   For did2.validate.references(..., 'KnownIds', ...). On the edge shape every
%   document points at its session entity, and a migrator test's few-document
%   batch holds no session document -- the session lives outside the batch,
%   exactly as the subject a test names in 'KnownIds' does. A full corpus
%   carries its session documents, so the corpus gate needs no such list.
%
%   STATUS: NOT VERIFIED BY EXECUTION in the authoring environment (no MATLAB).

arguments
    docs cell
end

ids = {};
if ~did2.schema.cache.shared().sessionIdIsEdge()
    return;
end
for k = 1:numel(docs)
    sid = did2.schema.cache.sessionIdOf(docs{k});
    if ~isempty(sid) && ~any(strcmp(ids, sid))
        ids{end+1} = sid; %#ok<AGROW>
    end
end
end
