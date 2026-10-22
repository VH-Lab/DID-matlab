function tf = isVocabulary(term, kind, handle)
%ISVOCABULARY True when TERM is the relation or entity type HANDLE, by node.
%
%   TF = did2.build.isVocabulary(TERM, KIND, HANDLE): TERM is a {node, name}
%   struct (or a bare name), KIND 'relation' or 'entity_type', HANDLE a
%   handle as did2.build.vocabulary takes it ('member_of', 'epoch').
%   When HANDLE has a node, TERM matches exactly when its node is that node
%   (prefix case ignored) -- or, for a TERM with no node (a document written
%   before did-schema #88 gave the vocabulary nodes), when its name is the
%   handle up to case, spaces, underscores and hyphens. When HANDLE has no
%   node (culture), the name decides. Code compares relations and entity types
%   this way, never by the stored name alone (Jess Haley 2026-10-22
%   [vocabulary nodes] L1, L2).
%
%   See also did2.build.vocabulary.

arguments
    term
    kind (1,:) char
    handle (1,:) char
end

node = '';
name = '';
if isstruct(term) && isscalar(term)
    if isfield(term, 'node'); node = strtrim(char(term.node)); end
    if isfield(term, 'name'); name = char(term.name); end
elseif ischar(term) || isstring(term)
    name = char(term);
end
want = did2.build.vocabulary(kind, handle);
if ~isempty(want) && ~isempty(node)
    tf = strcmpi(node, want);
    return;
end
norm = @(s) lower(regexprep(char(s), '[\s_\-]', ''));
tf = ~isempty(name) && strcmp(norm(name), norm(handle));
if ~tf && ~isempty(want) && ~isempty(name)
    % a label with no node, e.g. "member of" for member_of
    tf = strcmpi(did2.build.vocabulary(kind, name), want);
end
end
