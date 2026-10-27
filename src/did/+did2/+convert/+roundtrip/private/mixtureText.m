function txt = mixtureText(rows)
%MIXTURETEXT A `mixture_table` text from ROWS (mixtureRows' shape), in the
%   layout ndi.database.fun.writetablechar gives it: the header row, then one
%   line per row; a cell holding a comma or a quote is double-quoted.
lines = {'ontologyName,name,value,ontologyUnit,unitName'};
for k = 1:numel(rows)
    r = rows(k);
    v = '';
    if ~isempty(r.value)
        v = num2str(r.value, 15);
    end
    lines{end+1} = strjoin({q(r.node), q(r.name), v, q(r.unode), q(r.uname)}, ','); %#ok<AGROW>
end
txt = [strjoin(lines, newline) newline];
end

function s = q(s)
s = char(s);
if contains(s, ',') || contains(s, '"')
    s = ['"' strrep(s, '"', '""') '"'];
end
end
