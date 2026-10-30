function [v1, spec] = probe_geometry(bodies)
%PROBE_GEOMETRY Rebuild a v1 `probe_geometry` from what the migration made of
%   it.
%
%   [V1, SPEC] = did2.convert.roundtrip.probe_geometry(BODIES). V1 is the
%   document in NDI's v1 shape (probe/probe_geometry.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+fun/+probe/+geometry/fromStruct.m
%   writes it). BODIES holds one length `observation` per populated axis, the
%   probe's `coordinate_system` they name, the optional probe-model
%   `assertion` and the session anchor the observations name:
%
%     base.id, session_id, datestamp    the first observation's
%     base.name                         '' (the writer sets none)
%     depends_on probe_id               the statements' entity_id (one probe)
%     site_locations_leftright,         the observation whose variable is
%       _frontback, _depth              NCIT X-Coordinate / Y-Coordinate /
%                                       Z-Coordinate (by node, else by name;
%                                       [site positions are coordinates]): its
%                                       source values, in order, as a column
%                                       (fromStruct writes columns)
%     unit                              the values' source unit, spelled as
%                                       NDI writes it ('um' for om:micrometre);
%                                       another spelling of the same unit is
%                                       the same unit ([spelling is notation])
%     probe_model                       the assertion's term name
%     ndim                              2 ([writer default is not set]: the
%                                       migrator converts no other value)
%     has_planar_contour                0 or 1 (each writer's fixed default;
%                                       the migrator converts no other value)
%     shank_id, contact_shape*,         not rebuilt: the migrator converts only
%       manufacturer, contour_x/_y      a document that sets none (carry-001)
%
%   The coordinate system ([site frame is a coordinate system], Jess Haley,
%   2026-10-27) restates no v1 field: v1's frame is fixed by its template. It
%   is placed when it is about the same probe and every site observation
%   names it by `coordinate_system_id`; a second one, one about another
%   referent, or an observation naming none or another is unplaced.
%
%   A passthrough (no site locations) is no conversion and has no inverse.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.probe_geometry.

arguments
    bodies cell
end

AXES = { ...
    'site_locations_leftright', 'NCIT:C44477', 'X-Coordinate'; ...
    'site_locations_frontback', 'NCIT:C44478', 'Y-Coordinate'; ...
    'site_locations_depth',     'NCIT:C44479', 'Z-Coordinate'};
spec = emptySpec();
v1 = struct();
used = false(1, numel(bodies));
blk = struct();
first = [];
probes = {};
units = {};
frames = {};   % the coordinate_system_id each site observation names
for k = 1:numel(bodies)
    b = bodies{k};
    if ~strcmp(classNameOf(b), 'observation')
        continue;
    end
    [vnode, vname] = termParts(getIn(b, 'statement', 'variable'));
    row = axisRow(AXES, vnode, vname);
    if isempty(row) || isfield(blk, AXES{row, 1})
        continue;
    end
    used(k) = true;
    if isempty(first); first = b; end
    probes = [probes, edgeIds(b, 'entity_id')]; %#ok<AGROW>
    f = edgeIds(b, 'coordinate_system_id');
    if isempty(f); f = {''}; end
    frames = [frames, f(1)]; %#ok<AGROW>
    values = asCell(getIn(b, 'length', 'value'));
    col = zeros(numel(values), 1);
    for j = 1:numel(values)
        x = numberOf(getIn(values{j}, 'source_value'));
        if isempty(x)
            spec.unplaced{end+1} = sprintf('%s value %d states no source value', vname, j);
            x = NaN;
        end
        col(j) = x;
        [unode, ~] = termParts(getIn(values{j}, 'source_unit'));
        units{end+1} = unode; %#ok<AGROW>
    end
    blk.(AXES{row, 1}) = col;
end
if isempty(first)
    spec.unplaced{end+1} = 'no site-location observation was emitted';
    return;
end
base = rebuildBase(first);
sid = base.session_id;
[used, bad] = sessionAnchorOf(bodies, used, first, sid);
spec.unplaced = [spec.unplaced, bad];

% the probe's coordinate system: one, about the probe, named by every site
frameIds = {};
frameReferents = {};
for k = find(~used)
    b = bodies{k};
    if strcmp(classNameOf(b), 'coordinate_system')
        used(k) = true;
        frameIds{end+1} = char(getIn(b, 'base', 'id')); %#ok<AGROW>
        frameReferents = [frameReferents, edgeIds(b, 'referent_id')]; %#ok<AGROW>
    end
end
if numel(frameIds) > 1
    spec.unplaced{end+1} = sprintf('%d coordinate systems were emitted (a probe has one)', ...
        numel(frameIds));
elseif isscalar(frameIds)
    if ~all(strcmp(frames, frameIds{1}))
        spec.unplaced{end+1} = 'a site observation does not name the probe''s coordinate system';
    end
    probes = [probes, frameReferents];
else
    spec.unplaced{end+1} = 'no coordinate system was emitted for the site positions';
end

model = '';
for k = find(~used)
    b = bodies{k};
    [~, vname] = termParts(getIn(b, 'statement', 'variable'));
    if strcmp(classNameOf(b), 'assertion') && strcmpi(vname, 'probe model') && isempty(model)
        [~, model] = termParts(getIn(b, 'term', 'value'));
        probes = [probes, edgeIds(b, 'entity_id')]; %#ok<AGROW>
        used(k) = true;
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a probe geometry', ...
        k, classNameOf(bodies{k}));
end
if numel(unique(probes)) > 1
    spec.unplaced{end+1} = 'the statements and the coordinate system name more than one probe';
end
if isempty(probes); probes = {''}; end

unit = '';
units = unique(units);
if numel(units) > 1
    spec.unplaced{end+1} = sprintf('the values state %d source units (the document has one)', numel(units));
elseif isscalar(units)
    unit = ndiUnit(units{1});
    if isempty(unit) && ~isempty(units{1})
        spec.unplaced{end+1} = sprintf('source unit %s is not a length unit NDI writes', units{1});
    end
end

v1.document_class = struct('class_name', 'probe_geometry');
v1.depends_on = struct('name', 'probe_id', 'value', probes{1});
v1.base = struct('id', base.id, 'session_id', sid, 'name', '', ...
    'datestamp', base.datestamp);
for r = 1:size(AXES, 1)
    if ~isfield(blk, AXES{r, 1})
        blk.(AXES{r, 1}) = zeros(0, 1);
    end
end
blk.probe_model = model;
blk.ndim = 2;
blk.unit = unit;
v1.probe_geometry = blk;
spec.equivalents(end+1) = struct('path', 'probe_geometry.has_planar_contour', ...
    'values', {{0, 1, false, true}}, 'why', ['each writer''s fixed default (template 1, ' ...
    'fromStruct 0): [writer default is not set], Jess Haley, 2026-10-26']);
spec.same(end+1) = struct('path', 'probe_geometry.unit', 'fn', @sameLengthUnit, ...
    'why', ['equivalent spellings of one unit are the same unit ([spelling is notation], ' ...
    'Jess Haley, 2026-10-26); the migrator writes the unit''s term']);
end

% ===================== helpers =========================================

function row = axisRow(AXES, node, name)
%AXISROW The AXES row of a site observation's variable: by node, else by name.
row = [];
if ~isempty(node)
    row = find(strcmpi(AXES(:, 2), node), 1);
end
if isempty(row) && ~isempty(name)
    row = find(strcmpi(AXES(:, 3), name), 1);
end
end

function u = ndiUnit(node)
%NDIUNIT The spelling NDI's writers use for a length unit term ('' if none).
u = '';
T = {'om:micrometre', 'um'; 'om:millimetre', 'mm'; 'om:centimetre', 'cm'; ...
    'om:metre', 'm'; 'om:nanometre', 'nm'};
hit = find(strcmpi(T(:, 1), node), 1);
if ~isempty(hit)
    u = T{hit, 2};
end
end

function tf = sameLengthUnit(a, b)
%SAMELENGTHUNIT Two spellings of one length unit (the synonyms the migrator's
%   unit table, private/jSourceUnit, maps to one term).
S = { ...
    {'m', 'meter', 'metre'}; {'cm'}; {'mm', 'millimeter'}; ...
    {'um', [char(181) 'm'], 'micron', 'microns', 'micrometer'}; {'nm'}};
a = strtrim(char(a));
b = strtrim(char(b));
tf = strcmp(a, b);
for k = 1:numel(S)
    if any(strcmp(S{k}, a)) && any(strcmp(S{k}, b))
        tf = true;
        return;
    end
end
end
