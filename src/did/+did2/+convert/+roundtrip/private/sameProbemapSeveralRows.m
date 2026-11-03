function tf = sameProbemapSeveralRows(v1pm, rebuiltPm)
%SAMEPROBEMAPSEVERALROWS True when a rebuilt probe map is the v1 one with each
%   probe listed in several rows written as one row per acquisition system.
%
%   TF = sameProbemapSeveralRows(V1PM, REBUILTPM). Decided by Jess Haley,
%   2026-11-03, did-schema did_v2_go_forward_class_audit.md [probe in several
%   rows is one wiring]: a probe listed in several rows of one epoch's probe
%   map (a stimulator once per marker channel, `vhvis_spike2:mk1`, `...:mk2`)
%   is wired by one relation per acquisition system holding all its rows'
%   channels in row order, and "the round trip writes the merged row
%   (`...:mk1-7`), the probe and channels NDI reads". NDI reads a probe's
%   channels by matching its rows (ndi.probe.epochprobemapmatch: name,
%   reference, type) and joining their channels in row order
%   (ndi.probe.getchanneldevinfo), so the merged row and the several rows give
%   NDI the same probe and the same ordered channel list.
%
%   HOW IT COMPARES. Both maps are split into their header and rows (tab
%   columns name, reference, type, devicestring, subjectstring). The rows V1PM
%   would have merged are found exactly as did2.convert.resolveEpochProbemap
%   finds them: a probe (name, reference) in two or more rows that name a
%   device, whose rows all have the same name, reference, type and
%   subjectstring, grouped by the device (system) name, each group in row
%   order. From V1PM the EXPECTED rows are built: each group of two or more
%   rows is one row at its first row's place, its channels the group's
%   channels joined in row order; every other row is its own text. TF is true
%   only when
%     - the headers are the same text,
%     - at least one group of two or more rows was merged (for any other map
%       the rebuilt text must equal the v1 text, which check.m tests first),
%     - the rebuilt map has exactly the expected rows, in order: a row that
%       was not merged is the same text; a merged row has the same name,
%       reference, type, subjectstring and device name, and the SAME ORDERED
%       channel list, each channel its v1 prefix and number ('mk1-3;e1' and
%       'mk1;mk2;mk3;e1' are both mk1, mk2, mk3, e1).
%   A probe whose rows disagree is never merged by the migration (its v1
%   document is carried), so such a V1PM is never equivalent here.
%
%   See also did2.convert.roundtrip.epochfiles_ingested,
%            did2.convert.resolveEpochProbemap.

tf = false;
if ~(ischar(v1pm) || (isstring(v1pm) && isscalar(v1pm))) ...
        || ~(ischar(rebuiltPm) || (isstring(rebuiltPm) && isscalar(rebuiltPm)))
    return;
end
[h1, rows1] = splitMap(char(v1pm));
[h2, rows2] = splitMap(char(rebuiltPm));
if ~strcmp(h1, h2)
    return;
end
n = numel(rows1);
cols = cellfun(@columns, rows1, 'UniformOutput', false);
hasDev = cellfun(@(c) ~isempty(c{4}), cols);
probe = cellfun(@(c) [c{1} char(0) c{2}], cols, 'UniformOutput', false);
dev = cellfun(@(c) deviceOf(c{4}), cols, 'UniformOutput', false);
expected = struct('text', {}, 'cols', {}, 'channels', {});
consumed = false(1, n);
merged = false;
for r = 1:n
    if consumed(r)
        continue;
    end
    consumed(r) = true;
    same = [];
    if hasDev(r)
        same = find(hasDev & strcmp(probe, probe{r}));
    end
    if numel(same) < 2
        expected(end+1) = struct('text', rows1{r}, 'cols', {{}}, 'channels', {{}}); %#ok<AGROW>
        continue;
    end
    for f = [1 2 3 5]
        vals = cellfun(@(c) c{f}, cols(same), 'UniformOutput', false);
        if ~all(strcmp(vals, vals{1}))
            return;   % rows that disagree are never merged
        end
    end
    group = same(strcmp(dev(same), dev{r}));
    consumed(group) = true;
    if isscalar(group)
        expected(end+1) = struct('text', rows1{r}, 'cols', {{}}, 'channels', {{}}); %#ok<AGROW>
        continue;
    end
    merged = true;
    chans = {};
    for g = group
        [c, ok] = channelList(cols{g}{4});
        if ~ok
            return;
        end
        chans = [chans, c]; %#ok<AGROW>
    end
    expected(end+1) = struct('text', '', 'cols', {cols{r}}, 'channels', {chans}); %#ok<AGROW>
end
if ~merged || numel(expected) ~= numel(rows2)
    return;
end
for i = 1:numel(expected)
    e = expected(i);
    if isempty(e.cols)
        if ~strcmp(e.text, rows2{i})
            return;
        end
        continue;
    end
    c = columns(rows2{i});
    for f = [1 2 3 5]
        if ~strcmp(c{f}, e.cols{f})
            return;
        end
    end
    if ~strcmp(deviceOf(c{4}), deviceOf(e.cols{4}))
        return;
    end
    [chans, ok] = channelList(c{4});
    if ~ok || ~isequal(chans, e.channels)
        return;
    end
end
tf = true;
end

function [header, rows] = splitMap(s)
lines = strsplit(s, newline, 'CollapseDelimiters', false);
lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
header = '';
rows = {};
if isempty(lines)
    return;
end
header = lines{1};
rows = lines(2:end);
end

function c = columns(line)
c = strsplit(line, sprintf('\t'), 'CollapseDelimiters', false);
c = cellfun(@strtrim, c, 'UniformOutput', false);
c(end+1:5) = {''};
end

function d = deviceOf(devicestring)
s = strtrim(char(devicestring));
k = find(s == ':', 1);
if isempty(k)
    d = s;
else
    d = strtrim(s(1:k-1));
end
end

function [chans, ok] = channelList(devicestring)
% 'dev:mk1-3;e1' -> {'mk1', 'mk2', 'mk3', 'e1'}, in order; ok false when a
% group cannot be read
chans = {};
ok = true;
s = strtrim(char(devicestring));
k = find(s == ':', 1);
if isempty(k)
    return;
end
spec = strtrim(s(k+1:end));
if isempty(spec)
    return;
end
groups = strsplit(spec, ';');
for g = 1:numel(groups)
    grp = strtrim(groups{g});
    if isempty(grp)
        continue;
    end
    tok = regexp(grp, '^([A-Za-z]+)(.*)$', 'tokens', 'once');
    if isempty(tok)
        ok = false;
        return;
    end
    parts = strsplit(strtrim(tok{2}), ',');
    for p = 1:numel(parts)
        part = strtrim(parts{p});
        ab = regexp(part, '^(\d+)\s*-\s*(\d+)$', 'tokens', 'once');
        if ~isempty(ab)
            nums = str2double(ab{1}):str2double(ab{2});
        elseif ~isempty(regexp(part, '^\d+$', 'once'))
            nums = str2double(part);
        else
            ok = false;
            return;
        end
        for x = nums
            chans{end+1} = sprintf('%s%d', tok{1}, x); %#ok<AGROW>
        end
    end
end
end
