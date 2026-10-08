function def = fieldDef(cache, className, fieldPath)
%FIELDDEF The schema declaration of one (possibly nested) field of a class.
%
%   DEF = fieldDef(CACHE, CLASSNAME, FIELDPATH) looks FIELDPATH up in the
%   fields CLASSNAME declares or inherits. FIELDPATH is dot-separated, e.g.
%   'keys', 'value', 'value.start'. The first segment may instead name a class
%   in the chain ('interaction.method_parameters') when the same field
%   name is declared by two classes of the chain.
%
%   Errors did2:build:unknownField when nothing matches and
%   did2:build:ambiguousField when the first segment matches more than once.

parts = strsplit(fieldPath, '.');
tagged = cache.fieldsFor(className);
chain = cache.classChain(className);

owner = '';
if numel(parts) > 1 && any(strcmp(parts{1}, chain))
    owner = parts{1};
    parts = parts(2:end);
end

matches = {};
for k = 1:numel(tagged)
    if ~isempty(owner) && ~strcmp(tagged(k).declaringClass, owner)
        continue;
    end
    if strcmp(char(tagged(k).fieldDef.name), parts{1})
        matches{end+1} = tagged(k).fieldDef; %#ok<AGROW>
    end
end
if isempty(matches)
    error('did2:build:unknownField', ...
        'Class "%s" declares no field "%s".', className, fieldPath);
elseif numel(matches) > 1
    error('did2:build:ambiguousField', ...
        ['Class "%s" declares "%s" more than once in its chain; qualify ' ...
         'it with the declaring class, e.g. "<class>.%s".'], ...
        className, parts{1}, fieldPath);
end

def = matches{1};
for k = 2:numel(parts)
    subDefs = asDefs(subFields(def));
    found = false;
    for j = 1:numel(subDefs)
        if strcmp(char(subDefs{j}.name), parts{k})
            def = subDefs{j};
            found = true;
            break;
        end
    end
    if ~found
        error('did2:build:unknownField', ...
            'Class "%s" declares no field "%s" (no "%s" under "%s").', ...
            className, fieldPath, parts{k}, strjoin(parts(1:k-1), '.'));
    end
end
end

function raw = subFields(def)
raw = [];
if isfield(def, 'fields')
    raw = def.fields;
end
end
