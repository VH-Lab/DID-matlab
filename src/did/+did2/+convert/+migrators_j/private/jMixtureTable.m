function chemicals = jMixtureTable(raw)
%JMIXTURETABLE The rows of a v1 `mixture_table`, as the chemicals jDoseBodies
%   and jTreatmentBodies take.
%
%   CHEMICALS = jMixtureTable(RAW). NDI writes the table with
%   ndi.database.fun.writetablechar: a CSV with a HEADER row
%   (ontologyName,name,value,ontologyUnit,unitName), and double-quoted cells
%   that may hold commas. Every writer on NDI-matlab origin/main does
%   (+birren/TreatmentCreator.m, +birren/createSayaTreatments.m,
%   +hunsberger/TreatmentCreator.m, +babu/TreatmentCreator.m). The header's
%   column names are used when present; a table with no header is read by
%   position in the same order (node, name, value, unit node, unit name).
%   (The reader this replaces split on every comma and kept the header as a
%   chemical, the same defect resolveDeferredBaths' parseMixture records.)
%
%   Each row becomes
%       substance     {node, name}
%       source_value  [] or the row's number
%       source_unit   [] or the row's unit as a term (did2.convert.registeredTerm)
%   Always returns >= 1 record (a blank one when nothing parses) so the
%   formulation still names one ingredient; the blank is the curator's signal.

chemicals = struct('substance', {}, 'source_value', {}, 'source_unit', {});
if isstring(raw); raw = char(raw); end
if ischar(raw) && ~isempty(strtrim(raw))
    lines = regexp(raw, '\r?\n', 'split');
    col = struct('node', 1, 'name', 2, 'value', 3, 'unode', 4, 'uname', 5);
    for i = 1:numel(lines)
        line = strtrim(lines{i});
        if isempty(line); continue; end
        cells = regexp(line, '("([^"]|"")*"|[^,]*)(,|$)', 'tokens');
        cells = cellfun(@(c) unquote(c{1}), cells, 'UniformOutput', false);
        if strcmpi(cells{1}, 'ontologyName')       % the header row
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
        unit = [];
        unode = cellAt(cells, col.unode);
        uname = cellAt(cells, col.uname);
        if ~isempty(unode) || ~isempty(uname)
            unit = did2.convert.registeredTerm(unode, uname);
        end
        chemicals(end+1) = struct('substance', jOntologyTerm(node, name), ...
            'source_value', value, 'source_unit', unit); %#ok<AGROW>
    end
end
if isempty(chemicals)
    chemicals(end+1) = struct('substance', jOntologyTerm('', ''), ...
        'source_value', [], 'source_unit', []);
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
