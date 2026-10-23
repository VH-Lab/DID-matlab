function t = term(node, name)
%TERM An ontology term {node, name}.
%
%   T = did2.build.term(NODE, NAME) returns struct('node', NODE, 'name', NAME).
%   NODE is a CURIE ('NCIT:C25613'), its prefix written as the CURIE
%   registry's `spelling` (DID-schema V_eta_prefix_spelling_plan.md, signed
%   2026-10-19); NAME is its human-readable label. NODE is stored as given:
%   did2.schema.curieSpelling rewrites one written another way.
%
%   A term may be given by NAME alone while its node is staged (T8: matched by
%   name): did2.build.term('', 'spatial frequency'). A term with neither is an
%   error -- an all-blank term is a vacuous value, which the validator refuses
%   on any required field (#38).
%
%   NODE and NAME may be string arrays / cellstrs of equal length, giving a
%   1xN struct array (e.g. a key's `term`).
%
%   See also did2.build.label.

arguments
    node {mustBeText}
    name {mustBeText} = ''
end

node = cellstr(node);
name = cellstr(name);
if isscalar(name) && ~isscalar(node) && isempty(name{1})
    name = repmat({''}, size(node));
end
if numel(node) ~= numel(name)
    error('did2:build:sizeMismatch', ...
        'term: %d node(s) but %d name(s).', numel(node), numel(name));
end
for k = 1:numel(node)
    if isempty(strtrim(node{k})) && isempty(strtrim(name{k}))
        error('did2:build:emptyTerm', ...
            'term %d has neither a node nor a name.', k);
    end
end
t = struct('node', reshape(node, 1, []), 'name', reshape(name, 1, []));
end
