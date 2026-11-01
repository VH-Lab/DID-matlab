function s = jGetCharAny(block, names)
%JGETCHARANY First non-empty char field among several candidate names ('' if none).
%   A v1 field may be spelled the way NDI's writer wrote it (camelCase, e.g.
%   `virus_OntologyName`) or the way the deleted rename pass
%   (did2.convert.universalRenames) wrote it (`virus_ontology_name`). Reading
%   a candidate list makes a migrator correct on either spelling.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
s = '';
for i = 1:numel(names)
    s = jGetChar(block, names{i});
    if ~isempty(s)
        return;
    end
end
end
