function s = sourceText(e)
%SOURCETEXT The text a source wrote for a list item's number, from either shape.
%
%   S = sourceText(E) is what fieldText(getIn(E, 'quantity'), 'source_value')
%   read before the new numeric shape ([one shape for measured numbers], Jess
%   Haley, 2026-11-17): the old quantity.source_value, or the new flat
%   source_numeric (itemSource), as text; '' when E states none. A number
%   written there is given in the shortest text that reads back to it.
s = '';
[v, found] = itemSource(e);
if ~found || isempty(v)
    return;
end
if ischar(v) || (isstring(v) && isscalar(v))
    s = char(v);
elseif isnumeric(v) && isscalar(v)
    s = sprintf('%.17g', v);
    for digits = 15:17
        t = sprintf(sprintf('%%.%dg', digits), v);
        if str2double(t) == v
            s = t;
            break;
        end
    end
end
end
