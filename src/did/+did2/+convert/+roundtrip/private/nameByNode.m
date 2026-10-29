function spec = nameByNode(spec, namePath, node)
%NAMEBYNODE Compare a v1 term's NAME by its node: SPEC with a spec.same row
%   for NAMEPATH when the rebuilt term has a node.
%
%   SPEC = nameByNode(SPEC, NAMEPATH, NODE). NAMEPATH is the v1 path of a
%   term's name (e.g. 'probe_location.name'); NODE is the node the inverse
%   rebuilt for that term (the v1 node field beside the name, compared on its
%   own path, by sameCurie). When NODE is not empty, the name is compared by
%   that node: any v1 name text is the same term as the rebuilt name text,
%   because the node, compared on its own path, says which term it is. When
%   NODE is empty (a name-only term) nothing is added and the name is
%   compared as text.
%
%   WHY. Decided by Jess Haley, 2026-10-29 [term names compare by node]
%   (did-schema V_eta_go_forward_class_audit.md): "a v1 term name that
%   differs from the registry label of the same node (e.g. v1 'bed nucleus
%   of stria terminalis (BNST)', UBERON:0001880) is notation: no change, and
%   the round trip compares terms by node." The migrator writes a registered
%   node with the registry's label (did2.convert.registeredTerm; T19).
%
%   See also did2.convert.roundtrip.check, sameCurie.
if ~(ischar(node) || isstring(node)) || isempty(strtrim(char(node)))
    return;
end
spec.same(end+1) = struct('path', namePath, 'fn', @isText, ...
    'why', ['a term name compared by its node, ' char(node) ' ([term names ' ...
    'compare by node], Jess Haley, 2026-10-29): a v1 name that differs from ' ...
    'the registry label of the same node is notation']);
end

function tf = isText(a, b)
tf = (ischar(a) || isstring(a)) && (ischar(b) || isstring(b));
end
