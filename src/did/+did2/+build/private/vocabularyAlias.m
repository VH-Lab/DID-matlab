function handle = vocabularyAlias(kind, name)
%VOCABULARYALIAS The handle NAME is another name for in vocabulary KIND, or ''.
%
%   HANDLE = vocabularyAlias(KIND, NAME). NAME is compared ignoring case,
%   spaces, underscores and hyphens. An alias is a name a document may store
%   for a handle whose node the loaded schema may not bind yet, so that a
%   node-less document under either name matches the handle
%   (did2.build.isVocabulary) and resolves to the handle's node, or to none
%   when the schema binds none (did2.build.vocabulary), whichever name the
%   schema's row spells:
%
%     entity_type  'cell culture' -> 'culture'  Decided by Jess Haley,
%                  2026-11-10 [culture renamed cell culture] (with [culture
%                  and alignment nodes]): the type is renamed "cell culture",
%                  node OBI:0001876, once the siblings compare it by node
%
%   See also did2.build.vocabulary, did2.build.isVocabulary.

handle = '';
switch kind
    case 'entity_type'
        aliases = {'cell_culture', 'culture'};
    otherwise
        aliases = cell(0, 2);
end
norm = @(s) lower(regexprep(char(s), '[\s_\-]', ''));
key = norm(name);
for k = 1:size(aliases, 1)
    if strcmp(norm(aliases{k, 1}), key)
        handle = aliases{k, 2};
        return;
    end
end
end
