function [v1, spec] = pyraview(bodies)
%PYRAVIEW Rebuild a v1 `pyraview` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.pyraview(BODIES). V1 is the document in
%   NDI's v1 shape (data/pyraview.json over epochclocktimes.json, epochid.json,
%   data/filter.json and base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+gui/+app/+pyraview/makePyraviewDoc.m writes it, its `filter` block
%   from filterData.m). BODIES is what did2.convert.migrators_j.pyraview emitted
%   when it CONVERTED the document -- the `observation` (value kind voltage, id
%   preserved), one `sampled_body` per level file, the time anchor, and the
%   filter's `method` when there is one -- plus, for a pyraview folded by
%   did2.convert.epochMint, the epoch entity its anchor names:
%
%     base.id, session_id, datestamp     the observation (rebuildBase)
%     depends_on element_id              the observation's entity_id
%     epochid.epochid                    the epoch entity's local_identifier
%     epochclocktimes.clocktype          the anchor's clock
%     epochclocktimes.t0_t1              [start; start + duration] of the anchor
%     pyraview.label                     the observation's variable
%     pyraview.dataType                  value.source_data_type, else
%                                        value.data_type
%     pyraview.channels                  the level bodies' channel dimension
%     pyraview.decimationSamplingRates   1 / each level body's time spacing,
%     pyraview.decimationStartTimes      and its time origin, for the levels
%                                        the lists named (below)
%     pyraview.nativeRate,               the rate and origin of the trailing
%       nativeStartTime                  level bodies the migrator sized from
%                                        them (a file_list name past the end of
%                                        the rate list: the writer's template
%                                        lists level1..level10.bin and adds
%                                        seven); the rate is the filter's
%                                        sample frequency, which the writer sets
%                                        from the same variable
%                                        (makePyraviewDoc.m: sr)
%     pyraview.decimationLevels          nativeRate ./ the rates, as the ratios
%                                        of successive levels (the writer sets
%                                        rates = sr ./ cumprod(levels))
%     files.file_list                    each level body's file name, in order
%     files.file_info                    each level body's file_info, when it
%                                        has one, in level order (the migrator
%                                        puts each v1 entry on the level body
%                                        of its name: [pyraview level keeps its
%                                        file info], Jess Haley, 2026-10-27)
%     filter.type, label, algorithm      the method's band and design terms;
%                                        label restates type (a label that
%                                        differs carries the document, carry-007)
%     filter.parameters                  the method's parameters: sampleFrequency,
%                                        order, filterFrequency (the passband
%                                        edge: low for a high-pass, high for a
%                                        low-pass, [low; high] for a band-pass),
%                                        passBandRipple, stopbandAttentuation;
%                                        a NaN the writer states for a parameter
%                                        the design has none of is not written
%                                        (SPEC.equivalents, [writer default is
%                                        not set])
%
%   The level lists are told from the trailing native-rate bodies only when the
%   native rate is known (the filter's sample frequency); without it every body
%   is read as a listed level and nativeRate, nativeStartTime and
%   decimationLevels are not rebuilt. Anything emitted that is not one of the
%   documents above is unplaced.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.pyraview.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
n = numel(bodies);
used = false(1, n);
obs = [];
for k = 1:n
    if strcmp(classNameOf(bodies{k}), 'observation')
        obs = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(obs)
    spec.unplaced{end+1} = 'no observation was emitted';
    return;
end
base = rebuildBase(obs);
obsId = base.id;

% ---- the level bodies, in the order they were emitted ---------------------
levels = {};
for k = 1:n
    if ~used(k) && strcmp(classNameOf(bodies{k}), 'sampled_body') ...
            && isequal(edgeIds(bodies{k}, 'owner_id'), {obsId})
        levels{end+1} = bodies{k}; %#ok<AGROW>
        used(k) = true;
    end
end
if isempty(levels)
    spec.unplaced{end+1} = 'no level body was emitted';
    return;
end
nL = numel(levels);
rates = NaN(nL, 1);
starts = NaN(nL, 1);
names = cell(nL, 1);
fileInfo = {};
channels = [];
methodIds = {};
for j = 1:nL
    b = levels{j};
    [rates(j), starts(j), nCh, bad] = levelAxes(b);
    spec.unplaced = [spec.unplaced, bad];
    if j == 1
        channels = nCh;
    elseif ~isequal(nCh, channels)
        spec.unplaced{end+1} = sprintf('level body %d has another channel count', j);
    end
    fl = asCell(getIn(b, 'files', 'file_list'));
    if isscalar(fl)
        names{j} = char(fl{1});
    else
        spec.unplaced{end+1} = sprintf('level body %d holds %d file names, not one', j, numel(fl));
        names{j} = '';
    end
    fi = getIn(b, 'files', 'file_info');
    if ~isEmptyValue(fi)
        fileInfo = [fileInfo, asCell(fi)]; %#ok<AGROW>
    end
    methodIds = [methodIds, edgeIds(b, 'method_id')]; %#ok<AGROW>
end

% ---- the filter's method ----------------------------------------------------
filt = [];
nativeRate = [];
methodIds = unique(methodIds);
if numel(methodIds) > 1
    spec.unplaced{end+1} = 'the level bodies name different methods';
elseif isscalar(methodIds)
    hit = 0;
    for k = 1:n
        if ~used(k) && strcmp(classNameOf(bodies{k}), 'method') ...
                && strcmp(char(getIn(bodies{k}, 'base', 'id')), methodIds{1})
            hit = k;
            break;
        end
    end
    if hit == 0
        spec.unplaced{end+1} = 'the method the level bodies name was not emitted';
    else
        used(hit) = true;
        [filt, nativeRate, bad, nanPaths] = filterBlock(bodies{hit});
        spec.unplaced = [spec.unplaced, bad];
        for p = nanPaths
            spec.equivalents(end+1) = struct('path', ['filter.parameters.' p{1}], ...
                'values', {{NaN}}, 'why', ['NaN: filterData.m''s "no such ' ...
                'parameter" for this design, not written ([writer default is not set])']);
        end
    end
end

% ---- the listed levels and the native-rate tail ------------------------------
nListed = nL;
nativeStart = [];
if ~isempty(nativeRate)
    while nListed > 0 && rates(nListed) == nativeRate
        nListed = nListed - 1;
    end
    if nListed < nL
        tail = starts(nListed + 1:nL);
        if all(tail == tail(1))
            nativeStart = tail(1);
        else
            spec.unplaced{end+1} = 'the native-rate level bodies start at different times';
        end
    end
end

% ---- the anchor (and the epoch it names) -------------------------------------
anchor = [];
tr = edgeIds(obs, 'time_reference_id');
if numel(tr) ~= 1
    spec.unplaced{end+1} = sprintf('the observation names %d time references, not one', numel(tr));
else
    for k = 1:n
        if ~used(k) && strcmp(char(getIn(bodies{k}, 'base', 'id')), tr{1})
            anchor = bodies{k};
            used(k) = true;
            break;
        end
    end
    if isempty(anchor)
        spec.unplaced{end+1} = 'the time reference was not emitted';
    end
end
epochString = '';
ect = [];
if ~isempty(anchor)
    if ~strcmp(classNameOf(anchor), 'relative_time_reference')
        spec.unplaced{end+1} = sprintf('the time reference is a %s', classNameOf(anchor));
    else
        ref = edgeIds(anchor, 'referent_id');
        if isequal(ref, {base.session_id})
            % "during the session": a pyraview with no epoch string; its
            % extent is not kept
            [rnode, rname] = termParts(getIn(anchor, 'relative_time_reference', 'value', 'relation'));
            if ~(endsWith(rnode, 'intervalDuring') || strcmp(rname, 'intervalDuring'))
                spec.unplaced{end+1} = 'the session anchor is not intervalDuring the session';
            end
        elseif isscalar(ref)
            hit = 0;
            for k = 1:n
                if ~used(k) && isEntityOfType(bodies{k}, 'epoch') ...
                        && strcmp(char(getIn(bodies{k}, 'base', 'id')), ref{1})
                    hit = k;
                    break;
                end
            end
            if hit == 0
                spec.unplaced{end+1} = 'the epoch the anchor names is not among the documents';
            else
                used(hit) = true;
                epochString = fieldText(getIn(bodies{hit}, 'entity'), 'local_identifier');
            end
            [~, clk] = termParts(getIn(anchor, 'relative_time_reference', 'value', 'clock'));
            t0 = numberOf(getIn(anchor, 'relative_time_reference', 'value', 'start', 'seconds'));
            dur = numberOf(getIn(anchor, 'relative_time_reference', 'value', 'duration', 'seconds'));
            if isempty(t0) || isempty(dur)
                spec.unplaced{end+1} = 'the epoch anchor states no start and duration';
            else
                ect = struct('clocktype', clk, 't0_t1', [t0; t0 + dur]);
            end
        else
            spec.unplaced{end+1} = 'the anchor names no referent';
        end
    end
end

for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a pyraview', ...
        k, classNameOf(bodies{k}));
end

% ---- the v1 document ----------------------------------------------------------
v1.document_class = struct('class_name', 'pyraview');
ids = edgeIds(obs, 'entity_id');
if isempty(ids); ids = {''}; end
v1.depends_on = struct('name', 'element_id', 'value', ids{1});
v1.base = struct('id', base.id, 'session_id', base.session_id, 'datestamp', base.datestamp);
if ~isempty(epochString)
    v1.epochid = struct('epochid', epochString);
end
if ~isempty(ect)
    v1.epochclocktimes = ect;
end
files = struct('file_list', {names});
if ~isempty(fileInfo)
    files.file_info = vertcat(fileInfo{:});
end
v1.files = files;

pv = struct();
[~, label] = termParts(getIn(obs, 'statement', 'variable'));
pv.label = label;
if strcmp(label, 'signal')
    spec.equivalents(end+1) = struct('path', 'pyraview.label', 'values', {{''}}, ...
        'why', 'an empty label: the migrator names the signal ''signal''');
end
dt = fieldText(getIn(obs, 'value'), 'source_data_type');
if isempty(dt)
    dt = fieldText(getIn(obs, 'value'), 'data_type');
end
pv.dataType = dt;
if ~isempty(channels)
    pv.channels = channels;
end
if nListed > 0
    pv.decimationSamplingRates = rates(1:nListed);
    pv.decimationStartTimes = starts(1:nListed);
end
if ~isempty(nativeRate)
    pv.nativeRate = nativeRate;
    if nListed > 0
        pv.decimationLevels = levelsOf(nativeRate, rates(1:nListed));
    end
end
if ~isempty(nativeStart)
    pv.nativeStartTime = nativeStart;
end
v1.pyraview = pv;
if ~isempty(filt)
    v1.filter = filt;
end
end

% ===================== helpers =========================================

function [rate, start, nCh, bad] = levelAxes(b)
% the level's rate (1 / its time spacing), its time origin and its channel
% count ([] with no channel dimension)
bad = {};
rate = NaN;
start = NaN;
nCh = [];
dims = asCell(getIn(b, 'data', 'dimensions'));
covs = asCell(getIn(b, 'data', 'covariates'));
if isempty(dims) || numel(dims) > 2
    bad{end+1} = sprintf('a level body has %d dimensions, not (time[, channel])', numel(dims));
    return;
end
[~, t1] = termParts(getIn(dims{1}, 'term'));
if ~strcmpi(t1, 'time')
    bad{end+1} = sprintf('a level body''s first dimension is "%s", not time', t1);
end
if numel(dims) == 2
    [~, t2] = termParts(getIn(dims{2}, 'term'));
    if ~strcmpi(t2, 'channel')
        bad{end+1} = sprintf('a level body''s second dimension is "%s", not channel', t2);
    end
    nCh = numberOf(getIn(dims{2}, 'n'));
end
for k = 1:numel(covs)
    c = covs{k};
    al = getIn(c, 'along');
    if iscell(al); al = cell2mat(al); end
    if ~(isnumeric(al) && isscalar(al) && double(al) == 0)
        bad{end+1} = 'a level body has a covariate along a dimension other than time'; %#ok<AGROW>
        continue;
    end
    o = num(getIn(c, 'origin'));
    s = num(getIn(c, 'spacing'));
    if ~isempty(o); start = o; end
    if ~isempty(s) && s > 0; rate = 1 / s; end
end
if isnan(rate) || isnan(start)
    bad{end+1} = 'a level body has no time origin and spacing';
end
end

function v = num(x)
% a composite's `value` (else its source_value) as a number
v = numberOf(getIn(x, 'value'));
if isempty(v)
    sv = getIn(x, 'source_value');
    if ischar(sv) || (isstring(sv) && isscalar(sv))
        v = str2double(sv);
        if isnan(v); v = []; end
    else
        v = numberOf(sv);
    end
end
end

function lv = levelsOf(nativeRate, rates)
% the decimation factors: nativeRate ./ rates is their cumulative product
cp = nativeRate ./ rates(:);
lv = [cp(1); cp(2:end) ./ cp(1:end-1)];
r = round(lv);
near = abs(lv - r) <= 1e-9 * max(1, abs(r));
lv(near) = r(near);
end

function [f, sampleFrequency, bad, nanPaths] = filterBlock(m)
% the v1 `filter` block from the method private/jFrequencyFilter made
bad = {};
nanPaths = {};
sampleFrequency = [];
designs = { ...
    'EMPTY:0000387', 'chebyshev_1'; 'EMPTY:0000388', 'chebyshev_2'; ...
    'wikidata:Q1018162', 'butterworth'; 'wikidata:Q1051541', 'elliptic'; ...
    'wikidata:Q830123', 'bessel'; 'wikidata:Q117785', 'fir'};
bands = { ...
    'wikidata:Q262754', 'high'; 'wikidata:Q918242', 'low'; ...
    'wikidata:Q2718101', 'bandpass'};
dnode = termParts(getIn(m, 'method', 'term'));
hit = strcmp(designs(:, 1), dnode);
algorithm = '';
if any(hit)
    algorithm = designs{find(hit, 1), 2};
else
    bad{end+1} = sprintf('the method''s design "%s" has no v1 algorithm', dnode);
end
type = '';
params = struct();
edges = struct();
entries = asCell(getIn(m, 'method', 'parameters'));
for k = 1:numel(entries)
    e = entries{k};
    [~, vname] = termParts(getIn(e, 'variable'));
    switch vname
        case 'filter band'
            bnode = termParts(getIn(e, 'term'));
            h = strcmp(bands(:, 1), bnode);
            if any(h)
                type = bands{find(h, 1), 2};
            else
                bad{end+1} = sprintf('the filter band "%s" has no v1 type', bnode); %#ok<AGROW>
            end
        case 'passband low edge'
            edges.low = numberOf(getIn(e, 'quantity', 'value'));
        case 'passband high edge'
            edges.high = numberOf(getIn(e, 'quantity', 'value'));
        case 'filter order'
            params.order = numberOf(getIn(e, 'count'));
        case 'passband ripple'
            params.passBandRipple = quantityOf(e);
        case 'stopband attenuation'
            params.stopbandAttentuation = quantityOf(e);
        case 'sample frequency'
            sampleFrequency = numberOf(getIn(e, 'quantity', 'value'));
            params.sampleFrequency = sampleFrequency;
        otherwise
            bad{end+1} = sprintf('the method parameter "%s" has no v1 place', vname); %#ok<AGROW>
    end
end
switch type
    case 'high'
        if isfield(edges, 'low'); params.filterFrequency = edges.low; end
    case 'low'
        if isfield(edges, 'high'); params.filterFrequency = edges.high; end
    case 'bandpass'
        if isfield(edges, 'low') && isfield(edges, 'high')
            params.filterFrequency = [edges.low; edges.high];
        end
end
for p = {'order', 'filterFrequency', 'passBandRipple', 'stopbandAttentuation'}
    if ~isfield(params, p{1})
        nanPaths{end+1} = p{1}; %#ok<AGROW>
    end
end
% the label restates the type, unless the method is named: a label that
% differs is the method's name ([filter label is the method name], Jess Haley,
% 2026-10-27)
label = type;
name = getIn(m, 'method', 'name');
if (ischar(name) || isstring(name)) && strlength(name) > 0
    label = char(name);
end
f = struct('label', label, 'type', type, 'algorithm', algorithm, 'parameters', params);
end

function v = quantityOf(e)
% a parameter's quantity value; a NaN the source stated stays NaN
v = getIn(e, 'quantity', 'value');
if iscell(v); v = v{1}; end
if ~(isnumeric(v) && isscalar(v))
    v = NaN;
end
v = double(v);
end
