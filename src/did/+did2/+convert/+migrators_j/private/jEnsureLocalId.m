function li = jEnsureLocalId(candidate, body)
%JENSURELOCALID Non-empty local_identifier for a V_eta subject.
%   V_eta makes subject.local_identifier REQUIRED (a subject must be nameable).
%   Return CANDIDATE when it is a non-empty char handle; otherwise fall back to
%   the document id (BODY.base.id), which is always present and unique. A subject
%   with no source name is thus still nameable by its id rather than quarantining.
%
%   Used by every subject-minting migrator_j (element, subject_group,
%   ontology_table_row patch) and the carry-forward migrator (subject).
li = '';
if nargin >= 1 && ~isempty(candidate)
    li = char(candidate);
end
if isempty(li) && nargin >= 2 && isstruct(body) ...
        && isfield(body, 'base') && isstruct(body.base) && isfield(body.base, 'id')
    li = char(body.base.id);
end
end
