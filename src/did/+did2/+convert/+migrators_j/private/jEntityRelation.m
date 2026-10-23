function rel = jEntityRelation(preBody, childId, parentId, relationName, ~, relationNode)
%JENTITYRELATION A directed_relation CHILDID <RELATIONNAME> PARENTID, built
%   from the v1 body PREBODY through did2.build.directedRelation.
%
%   REL = jEntityRelation(PREBODY, CHILDID, PARENTID, RELATIONNAME, ~, RELATIONNODE)
%   The fifth argument (the pre-#73 `base.name`) is ignored: V_eta documents
%   never write `base.name` (#73 item 54). RELATIONNODE is the term's CURIE;
%   '' lets the builder complete it from the field's bound value set when the
%   name matches one exactly.

if nargin < 6
    relationNode = '';
end
if isempty(relationNode)
    relation = char(relationName);
else
    relation = did2.build.term(char(relationNode), char(relationName));
end
opts = jOpts(preBody);
rel = did2.build.directedRelation(char(childId), char(parentId), relation, opts{:});
end
