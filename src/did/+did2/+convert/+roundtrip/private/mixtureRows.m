function rows = mixtureRows(raw)
%MIXTUREROWS The rows of a v1 `mixture_table` text, read as
%   did2.convert.migrators_j reads them (its private jMixtureTable): a CSV as
%   NDI's ndi.database.fun.writetablechar writes it, an optional HEADER row
%   (ontologyName,name,value,ontologyUnit,unitName) naming the columns, cells
%   possibly double-quoted; a table with no header is read by position in the
%   same order. A line with neither a node nor a name is skipped.
%
%   ROWS is a struct array {node, name, value, unode, uname}: text, and VALUE
%   a double ([] when the cell is empty).
rows = struct('node', {}, 'name', {}, 'value', {}, 'unode', {}, 'uname', {});
if isstring(raw); raw = char(raw); end
if ~ischar(raw) || isempty(strtrim(raw))
    return;
end
lines = regexp(raw, '\r?\n', 'split');
col = struct('node', 1, 'name', 2, 'value', 3, 'unode', 4, 'uname', 5);
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line); continue; end
    cells = regexp(line, '("([^"]|"")*"|[^,]*)(,|$)', 'tokens');
    cells = cellfun(@(c) unquote(c{1}), cells, 'UniformOutput', false);
    if strcmpi(cells{1}, 'ontologyName')
        col = headerColumns(cells, col);
        continue;
    end
    node = cellAt(cells, col.node);
    name = cellAt(cells, col.name);
    if isempty(node) && isempty(name); continue; end
    value = [];
    v = cellAt(cells, col.value);
    if ~isempty(v)
        value = str2double(v);
    end
    rows(end+1) = struct('node', node, 'name', name, 'value', value, ...
        'unode', cellAt(cells, col.unode), 'uname', cellAt(cells, col.uname)); %#ok<AGROW>
end
end

function col = headerColumns(cells, col)
names = {'ontologyName', 'node'; 'name', 'name'; 'value', 'value'; ...
    'ontologyUnit', 'unode'; 'unitName', 'uname'};
for k = 1:size(names, 1)
    hit = find(strcmpi(cells, names{k, 1}), 1);
    if ~isempty(hit)
        col.(names{k, 2}) = hit;
    end
end
end

function c = cellAt(cells, k)
c = '';
if k <= numel(cells)
    c = strtrim(cells{k});
end
end

function t = unquote(t)
t = strtrim(t);
if numel(t) >= 2 && t(1) == '"' && t(end) == '"'
    t = strrep(t(2:end-1), '""', '"');
end
end
