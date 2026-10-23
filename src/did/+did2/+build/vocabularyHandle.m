function h = vocabularyHandle(kind, term)
%VOCABULARYHANDLE The code handle ('epoch', 'session', 'member_of') a term names, by node.
%
%   H = did2.build.vocabularyHandle(KIND, TERM): TERM is a {node, name} struct
%   (or a bare name), KIND 'relation' or 'entity_type'. H is the FIRST handle
%   of did2.build.vocabulary's table whose node is TERM's node, so a document
%   storing {EMPTY:0000383, "recording epoch"} answers 'epoch' and one storing
%   {NCIT:C67447, "Session"} answers 'session'. A term with no node (a
%   document written before did-schema #88 gave the vocabulary nodes) is
%   resolved through its name (did2.build.vocabulary accepts a handle or a
%   label). A term whose node is in no handle row (culture; a relation the
%   table does not list) answers its stored name unchanged.
%
%   Code that switches on an entity's kind or a relation's name calls this
%   instead of reading the stored name: the stored name is the ontology label
%   (Jess Haley 2026-10-22 [vocabulary nodes] L1, L2) and can change in the
%   schema without a change in code; the node does not.
%
%   See also did2.build.vocabulary, did2.build.isVocabulary.

arguments
    kind (1,:) char {mustBeMember(kind, {'relation', 'entity_type'})}
    term
end

node = '';
name = '';
if iscell(term) && ~isempty(term); term = term{1}; end
if isstruct(term) && isscalar(term)
    if isfield(term, 'node') && ~isempty(term.node); node = strtrim(char(term.node)); end
    if isfield(term, 'name') && ~isempty(term.name); name = char(term.name); end
elseif ischar(term) || isstring(term)
    name = char(term);
end
h = name;
if isempty(node) && ~isempty(name)
    node = did2.build.vocabulary(kind, name);
end
if isempty(node); return; end
[~, handles] = did2.build.vocabulary(kind);
hit = find(strcmpi(handles(:, 2), node), 1);
if ~isempty(hit)
    h = handles{hit, 1};
end
end
