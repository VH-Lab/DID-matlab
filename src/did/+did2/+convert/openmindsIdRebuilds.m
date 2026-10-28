function tf = openmindsIdRebuilds(node, openmindsId, ix)
%OPENMINDSIDREBUILDS True when a v1 openMINDS controlled term's `openminds_id`
%   can be rebuilt from its term through the term registry's `equivalent` list.
%
%   TF = did2.convert.openmindsIdRebuilds(NODE, OPENMINDSID) looks the term
%   NODE up in the shared schema's term registry (did2.schema.termIndex) and
%   is true when that row's `equivalent` list holds OPENMINDSID as written,
%   or as `openminds:<OPENMINDSID>`, or (an IRI) as `openminds:<its last path
%   segment>`. TF = ...(NODE, OPENMINDSID, IX) reads the index IX instead (a
%   test, or a caller holding one).
%
%   Decided by Jess Haley, 2026-10-27 [openMINDS subject leftovers] (did-schema
%   V_eta_go_forward_class_audit.md): "a controlled term's `openminds_id` is
%   rebuilt from the term through the registry's `equivalent` list ([term
%   equivalents recorded]), and a document whose id does not rebuild is
%   carried". Until did-schema adds the `equivalent` column every list is
%   empty, so no id rebuilds and did2.convert.migrators_j.openminds_subject
%   carries every document that states one.

arguments
    node {mustBeText}
    openmindsId {mustBeText}
    ix = []
end

tf = false;
node = strtrim(char(node));
openmindsId = strtrim(char(openmindsId));
if isempty(node) || isempty(openmindsId)
    return;
end
if isempty(ix)
    try
        ix = did2.schema.termIndex();
    catch
        return;
    end
end
if ~isstruct(ix) || ~isfield(ix, 'present') || ~ix.present
    return;
end
key = did2.schema.curieKey(node);
if ~isKey(ix.byNode, key)
    return;
end
e = ix.byNode(key);
if ~isfield(e, 'equivalent') || isempty(e.equivalent)
    return;
end
forms = {openmindsId, ['openminds:' openmindsId]};
parts = regexp(openmindsId, '[^/#]+$', 'match', 'once');
if ~isempty(parts) && ~strcmp(parts, openmindsId)
    forms{end+1} = ['openminds:' parts];
end
tf = any(ismember(forms, e.equivalent));
end
