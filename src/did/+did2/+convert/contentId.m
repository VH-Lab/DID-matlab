function id = contentId(role, body)
%CONTENTID An id derived from a source document's own content, for a source
%   that states no v1 id.
%
%   ID = did2.convert.contentId(ROLE, BODY). Decided by Jess Haley, 2026-11-12
%   [ids from content when v1 states none] (did-schema
%   did_v2_go_forward_class_audit.md): where a source document states no v1
%   id, the id the migration gives it (or a document made for it) is derived
%   from the document's own canonical content, so the same input gives the
%   same id and two different documents never share one. DID-matlab #453
%   (7924c247) did this for every source with a v1 id (did2.convert.mintId).
%
%   The key is did2.convert.mintKey(BODY): its id if it states one (base.id,
%   or a legacy identity block's), else 'json:' and its canonical JSON (the
%   whole document, so its class and every field are in it). ROLE (a char:
%   the class and what the id is for, e.g. 'pyraview observation') is
%   hashed with it, so two roles for one document get two ids. The id is
%   did2.convert.mintId's derivation of ('content|' KEY, ROLE, 1) in a context
%   of its own: a pure function of (ROLE, BODY), the same however often and
%   wherever it is called in a run (unlike a ROLE-only mintId, whose ordinal
%   counts). Two documents with the same content are the same document and
%   get the same id.
%
%   Only a body jsonencode cannot encode has no key; the id is then random
%   (did.ido.unique_id), as mintId's is with no key.
%
%   See also did2.convert.mintKey, did2.convert.mintId.

arguments
    role {mustBeTextScalar}
    body
end
key = did2.convert.mintKey(body);
depth = did2.convert.mintId('-depth');
restore = onCleanup(@() did2.convert.mintId('-popto', depth));
if isempty(key)
    did2.convert.mintId('-push', '');
else
    did2.convert.mintId('-push', ['content|' key]);
end
id = did2.convert.mintId(char(role));
clear restore
end
