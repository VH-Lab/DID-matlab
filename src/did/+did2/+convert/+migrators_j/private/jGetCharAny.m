function s = jGetCharAny(block, names)
%JGETCHARANY First non-empty char field among several candidate names ('' if none).
%   did2.convert.universalRenames snake_cases property-block field names when
%   RenameClassNames is true (the migration default): a legacy camelCase field
%   like `virus_OntologyName` arrives as `virus_ontology_name`, while a read path
%   with RenameClassNames=false leaves it camelCase. Reading a candidate list
%   (snake form first, legacy camelCase as a fallback) makes a migrator correct
%   on both paths.
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
