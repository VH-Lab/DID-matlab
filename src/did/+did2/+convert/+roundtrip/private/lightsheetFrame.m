function f = lightsheetFrame(dimensions, covariates)
%LIGHTSHEETFRAME A lightsheet array's v1 axis fields, read back from the
%   `dimensions` and `covariates` +migrators_j/private/jLightsheetAxes wrote.
%
%   F = lightsheetFrame(DIMENSIONS, COVARIATES). F has, in the order of the
%   dimensions (one per character of v1's axes_order):
%     axes_order   one letter per dimension (t, c, z, y, x), from its term
%     shape        each dimension's `n`
%     chunks       each dimension's `chunk` ([] when none states one)
%     scale        each axis's spacing in the SOURCE's unit (source_value when
%                  the migrator converted it, else value); 1 for an axis with
%                  no spacing covariate (the channel axis, a bare axis): the
%                  NGFF default jLightsheetAxes did not write
%     translation  the same for the origin; 0 where none (the NGFF default)
%     units        cellstr, each axis's unit as v1 spelled it (the OM node
%                  mapped back to the UDUNITS-2 name OME-NGFF writes, e.g.
%                  om:micrometre -> 'micrometer'); '' where none
%     channel_names  the channel covariate's term names joined with ','
%     bad          cellstr: what could not be read
%
%   The same reading as NDI-matlab ndi.vintage.lightsheetKeys (origin/V2),
%   which reads a migrated pyramid or level back for the viewer.
%
%   See also did2.convert.roundtrip.lightsheetZarrPyramid,
%            did2.convert.roundtrip.lightsheetZarrLevel.

dims = asCell(dimensions);
covs = asCell(covariates);
n = numel(dims);
f = struct('axes_order', blanks(n), 'shape', zeros(n, 1), 'chunks', [], ...
    'scale', ones(n, 1), 'translation', zeros(n, 1), ...
    'units', {repmat({''}, 1, n)}, 'channel_names', '', 'bad', {{}});
chunks = NaN(n, 1);
for k = 1:n
    d = dims{k};
    f.axes_order(k) = axisLetter(getIn(d, 'term'));
    sz = numberOf(getIn(d, 'n'));
    if isempty(sz)
        f.bad{end+1} = sprintf('dimension %d states no size', k);
    else
        f.shape(k) = sz;
    end
    c = numberOf(getIn(d, 'chunk'));
    if ~isempty(c); chunks(k) = c; end
    cov = along(covs, k - 1);
    if isempty(cov); continue; end
    if f.axes_order(k) == 'c'
        t = asCell(getIn(cov, 'term'));
        names = cell(1, numel(t));
        for j = 1:numel(t)
            [~, names{j}] = termParts(t{j});
        end
        f.channel_names = strjoin(names, ',');
        continue;
    end
    [o, so] = pairOf(getIn(cov, 'origin'));
    [s, ss] = pairOf(getIn(cov, 'spacing'));
    if ~isempty(ss); s = ss; end
    if ~isempty(so); o = so; end
    if ~isempty(s); f.scale(k) = s; end
    if ~isempty(o); f.translation(k) = o; end
    unit = unitSpelling(getIn(cov, 'source_unit'));
    if isempty(unit)
        unit = unitSpelling(getIn(cov, 'unit'));
    end
    f.units{k} = unit;
end
if any(~isnan(chunks))
    f.chunks = chunks;
end
end

% ===================== helpers =============================================

function c = along(covs, index)
c = [];
for i = 1:numel(covs)
    a = getIn(covs{i}, 'along');
    if iscell(a); a = cell2mat(a); end
    if isnumeric(a) && isscalar(a) && double(a) == index
        c = covs{i};
        return;
    end
end
end

function [v, source] = pairOf(p)
v = [];
source = [];
p = firstOf(p);
if isstruct(p) && isscalar(p)
    if isfield(p, 'value'); v = numberOf(p.value); end
    if isfield(p, 'source_value'); source = numberOf(p.source_value); end
elseif isnumeric(p)
    v = numberOf(p);
end
end

function a = axisLetter(t)
[node, name] = termParts(t);
switch lower(node)
    case 'ncit:c44477'; a = 'x'; return;
    case 'ncit:c44478'; a = 'y'; return;
    case 'ncit:c44479'; a = 'z'; return;
    case 'om:time';     a = 't'; return;
end
switch lower(strtrim(name))
    case {'x', 'x-coordinate'}; a = 'x';
    case {'y', 'y-coordinate'}; a = 'y';
    case {'z', 'z-coordinate'}; a = 'z';
    case {'t', 'time'};         a = 't';
    case {'c', 'channel'};      a = 'c';
    otherwise;                  a = '?';
end
end

function u = unitSpelling(t)
% the OM node back to the UDUNITS-2 name OME-NGFF writes (jLightsheetAxes
% unitTerm, inverted); a name-only unit as it was spelled
nodes = {'om:angstrom', 'om:nanometre', 'om:micrometre', 'om:millimetre', ...
    'om:centimetre', 'om:metre', 'om:nanosecond-Time', 'om:microsecond-Time', ...
    'om:millisecond-Time', 'om:second-Time', 'om:minute-Time', 'om:hour'};
names = {'angstrom', 'nanometer', 'micrometer', 'millimeter', 'centimeter', ...
    'meter', 'nanosecond', 'microsecond', 'millisecond', 'second', 'minute', 'hour'};
[node, name] = termParts(t);
hit = find(strcmpi(nodes, node), 1);
if ~isempty(hit)
    u = names{hit};
else
    u = name;
end
end
