function row = fitModelRow(node, family, e)
%FITMODELROW The did2.convert.tuningFitModels row of an entry: the row of FAMILY
%   with the entry's model NODE whose constraints are exactly the entry's
%   (each {symbol, value}, in any order), or [] when there is none.
row = [];
if isempty(node)
    return;
end
rows = did2.convert.tuningFitModels(family);
if isempty(rows)
    return;
end
rows = rows(strcmpi({rows.node}, strtrim(node)));
held = heldConstraints(e);
if isempty(held) && ~isempty(asCell(getIn(e, 'constraints')))
    return;   % a constraint that is not {symbol, number}
end
for k = 1:numel(rows)
    want = rows(k).constraints;
    if size(want, 1) ~= size(held, 1)
        continue;
    end
    if isequal(constraintKeys(want), constraintKeys(held))
        row = rows(k);
        return;
    end
end
end

function held = heldConstraints(e)
% an entry's constraints as {symbol, value} rows; {} when any is not one
% (the names before [tuning fit coefficients named by symbol] are read as
% their symbols: 'Naka-Rushton parameter 3' is n, '... 4' is s)
held = cell(0, 2);
c = asCell(getIn(e, 'constraints'));
for k = 1:numel(c)
    [~, name] = termParts(getIn(c{k}, 'variable'));
    v = numberOf(getIn(c{k}, 'value'));
    name = strtrim(name);
    legacy = regexp(name, '^Naka-Rushton parameter ([34])$', 'tokens', 'once');
    if ~isempty(legacy)
        if strcmp(legacy{1}, '3'); name = 'n'; else; name = 's'; end
    end
    if isempty(name) || isempty(v) || ~isscalar(v)
        held = cell(0, 2);
        return;
    end
    held(end+1, :) = {name, v}; %#ok<AGROW>
end
end

function keys = constraintKeys(c)
% {symbol, value} rows as sorted 'symbol=value' text, so two sets compare in
% any order
keys = cell(1, size(c, 1));
for k = 1:size(c, 1)
    keys{k} = sprintf('%s=%.17g', c{k, 1}, double(c{k, 2}));
end
keys = sort(keys);
end
