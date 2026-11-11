function [p, bad] = fitRowCoefficients(e, row, where)
%FITROWCOEFFICIENTS The v1 parameter vector of an entry with a model row: its coefficients'
% values, named by the row's symbols in stored order, with the TF difference
% of Gaussians' leading constant 0 put back (row.leadingZero)
bad = {};
p = [];
c = asCell(getIn(e, 'coefficients'));
for k = 1:numel(c)
    [~, name] = termParts(getIn(c{k}, 'variable'));
    if k > numel(row.symbols) || ~strcmp(strtrim(name), row.symbols{k})
        bad{end+1} = sprintf('%s: coefficient %d is "%s", not the symbol %s of %s', ...
            where, k, name, symbolAt(row, k), row.name); %#ok<AGROW>
        p = [];
        return;
    end
    v = getIn(c{k}, 'value');
    if isempty(v)
        v = NaN;   % a NaN coefficient read back from JSON null
    end
    p(end+1, 1) = double(v(1)); %#ok<AGROW>
end
if row.leadingZero
    p = [0; p];
end
end

function s = symbolAt(row, k)
s = '(none)';
if k <= numel(row.symbols)
    s = row.symbols{k};
end
end
