function info = nTrodeElectrodeCounts(action, arg)
%NTRODEELECTRODECOUNTS The channel counts and site counts of every n-trode in
%   the batch, for its "number of electrodes".
%
%   Decided by Jess Haley, 2026-10-29 [n-trode count from the channel list]
%   (did-schema V_eta_go_forward_class_audit.md): "the 'number of electrodes'
%   of an n-trode ([n-trode is a multielectrode array], [number of electrodes
%   minted]) is the count of channels its epochprobemap `devicestring` names
%   (NDI `+ndi/+epoch/epochprobemap_daqsystem.m`, 'the device and channels
%   that comprise the data'), cross-checked against the sites of its
%   `probe_geometry` / `site2channelmap` where one exists; when they disagree
%   the device is carried as v1 under a `needs_mapping` register row"
%   (carry-156).
%
%   A per-document migrator cannot follow an edge, so did2.convert.v1_to_v2
%   indexes the batch before the first migrator runs (as
%   did2.convert.elementSubjects); migrators_j.element reads it.
%
%   did2.convert.nTrodeElectrodeCounts('reset')        forget all
%   did2.convert.nTrodeElectrodeCounts('load', BODIES) index the cell BODIES
%       (structs or JSON text): every v1 `element` of type 'n-trode' (its
%       session, name, reference); every epochprobemap row of type 'n-trode'
%       held by an `epochfiles_ingested` (its session, name, reference and the
%       channels its devicestring names); every `probe_geometry` and
%       `site2channelmap` by its probe_id (the number of sites it holds:
%       numel of site_locations_leftright / frontback / depth, or of map).
%       Adds to what is held; v1_to_v2 resets first.
%   INFO = did2.convert.nTrodeElectrodeCounts('get', ELEMENTID) for the v1
%       element ELEMENTID:
%         INFO.channel_counts  the distinct channel counts its probemap rows
%                              name (one per distinct count; [] when the
%                              batch holds no row of it)
%         INFO.rows            how many probemap rows matched it
%         INFO.unparsed        how many of those rows named channels that did
%                              not parse (their count is not in
%                              channel_counts)
%         INFO.site_counts     the distinct site counts of its probe_geometry
%                              and site2channelmap documents ([] when none)
%
%   A probemap row names its probe as NDI matches it: name, reference and type
%   (ndi.epoch.epochprobemap_daqsystem); the reference is compared as text
%   (an integer reference as int2str writes it). Rows are matched within the
%   element's session.
%
%   THE CHANNEL COUNT. A devicestring is 'device:<type><numbers>[;...]'
%   (ndi.daq.daqsystemstring), e.g. 'intan1:ai1-4' or 'intan1:ai27-28,45';
%   numbers are single integers or inclusive 'a-b' ranges. The count is the
%   number of channels it names, over all its groups.
%
%   See also did2.convert.migrators_j.element, did2.convert.elementSubjects.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'get'})}
    arg = []
end

persistent elements probemapRows sites
if isempty(elements) || ~isa(elements, 'containers.Map')
    elements = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
if isempty(probemapRows) || ~isa(probemapRows, 'containers.Map')
    probemapRows = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
if isempty(sites) || ~isa(sites, 'containers.Map')
    sites = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
info = struct('channel_counts', [], 'rows', 0, 'unparsed', 0, 'site_counts', []);
switch action
    case 'reset'
        elements = containers.Map('KeyType', 'char', 'ValueType', 'char');
        probemapRows = containers.Map('KeyType', 'char', 'ValueType', 'any');
        sites = containers.Map('KeyType', 'char', 'ValueType', 'any');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        for k = 1:numel(bodies)
            b = bodies{k};
            if ischar(b) || (isstring(b) && isscalar(b))
                if ~contains(b, '"element"') && ~contains(b, 'epochprobemap') ...
                        && ~contains(b, 'probe_geometry') && ~contains(b, 'site2channelmap')
                    continue;
                end
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            switch classOf(b)
                case 'element'
                    el = blockOf(b, 'element');
                    if ~strcmp(strtrim(textOf(fieldOf(el, 'type'))), 'n-trode'); continue; end
                    id = baseText(b, 'id');
                    if isempty(id); continue; end
                    elements(id) = rowKey(baseText(b, 'session_id'), ...
                        textOf(fieldOf(el, 'name')), refText(fieldOf(el, 'reference')));
                case 'epochfiles_ingested'
                    pm = textOf(fieldOf(blockOf(b, 'epochfiles_ingested'), 'epochprobemap'));
                    if isempty(pm); continue; end
                    session = baseText(b, 'session_id');
                    rows = parseProbemapRows(pm);
                    for r = 1:numel(rows)
                        if ~strcmp(rows(r).type, 'n-trode'); continue; end
                        key = rowKey(session, rows(r).name, rows(r).reference);
                        n = channelCount(rows(r).devicestring);
                        if isKey(probemapRows, key)
                            probemapRows(key) = [probemapRows(key), n];
                        else
                            probemapRows(key) = n;
                        end
                    end
                case 'probe_geometry'
                    g = blockOf(b, 'probe_geometry');
                    n = [];
                    for f = {'site_locations_leftright', 'site_locations_frontback', ...
                            'site_locations_depth'}
                        v = fieldOf(g, f{1});
                        if isnumeric(v) && ~isempty(v); n(end+1) = numel(v); end %#ok<AGROW>
                    end
                    sites = addSites(sites, probeOf(b), unique(n));
                case 'site2channelmap'
                    m = fieldOf(blockOf(b, 'site2channelmap'), 'map');
                    if isnumeric(m) && ~isempty(m)
                        sites = addSites(sites, probeOf(b), numel(m));
                    end
            end
        end
    case 'get'
        id = char(arg);
        if isempty(id) || ~isKey(elements, id); return; end
        key = elements(id);
        if isKey(probemapRows, key)
            n = probemapRows(key);
            info.rows = numel(n);
            info.unparsed = sum(isnan(n));
            info.channel_counts = unique(n(~isnan(n)));
        end
        if isKey(sites, id)
            info.site_counts = unique(sites(id));
        end
end
end

% ===================== helpers ===========================================

function sites = addSites(sites, probeId, n)
if isempty(probeId) || isempty(n); return; end
if isKey(sites, probeId)
    sites(probeId) = [sites(probeId), reshape(n, 1, [])];
else
    sites(probeId) = reshape(n, 1, []);
end
end

function n = channelCount(devicestring)
%CHANNELCOUNT How many channels DEVICESTRING names; NaN when it names none or
%   a group does not parse (a count is never guessed).
n = NaN;
s = strtrim(char(devicestring));
colon = find(s == ':', 1);
if isempty(colon); return; end
spec = strtrim(s(colon+1:end));
if isempty(spec); return; end
total = 0;
groups = strsplit(spec, ';');
for g = 1:numel(groups)
    grp = strtrim(groups{g});
    if isempty(grp); continue; end
    tok = regexp(grp, '^([A-Za-z]+)(.*)$', 'tokens', 'once');
    if isempty(tok); return; end
    parts = strsplit(strtrim(tok{2}), ',');
    for p = 1:numel(parts)
        part = strtrim(parts{p});
        if isempty(part); return; end
        rng = regexp(part, '^(\d+)-(\d+)$', 'tokens', 'once');
        if ~isempty(rng)
            a = str2double(rng{1});
            z = str2double(rng{2});
            if ~(z >= a); return; end
            total = total + (z - a + 1);
        elseif ~isempty(regexp(part, '^\d+$', 'once'))
            total = total + 1;
        else
            return;
        end
    end
end
if total > 0
    n = total;
end
end

function rows = parseProbemapRows(s)
%PARSEPROBEMAPROWS name / reference / type / devicestring of each row of a
%   serialized epochprobemap (NDI epochprobemap_daqsystem.serialize: a
%   tab-separated header `name reference type devicestring subjectstring`,
%   then one line per probe). As resolveEpochProbemap reads it: with an
%   unrecognised header every non-empty line is a row.
rows = struct('name', {}, 'reference', {}, 'type', {}, 'devicestring', {});
tab = sprintf('\t');
lines = strsplit(char(s), sprintf('\n'), 'CollapseDelimiters', false);
lines = lines(~cellfun(@(l) isempty(strtrim(l)), lines));
if isempty(lines); return; end
expected = {'name', 'reference', 'type', 'devicestring', 'subjectstring'};
h = strsplit(lines{1}, tab, 'CollapseDelimiters', false);
if numel(h) == numel(expected) && all(cellfun(@(a, b) strcmpi(strtrim(a), b), h, expected))
    lines = lines(2:end);
end
for i = 1:numel(lines)
    c = strsplit(lines{i}, tab, 'CollapseDelimiters', false);
    c(end+1:4) = {''};
    rows(end+1) = struct('name', strtrim(c{1}), 'reference', strtrim(c{2}), ...
        'type', strtrim(c{3}), 'devicestring', strtrim(c{4})); %#ok<AGROW>
end
end

function k = rowKey(session, name, reference)
k = sprintf('%s\t%s\t%s', strtrim(char(session)), strtrim(char(name)), strtrim(char(reference)));
end

function s = refText(r)
%REFTEXT A reference as text: an integer as int2str writes it (NDI's display
%   form and the probemap's), other numbers to 17 digits, text trimmed.
s = '';
if ischar(r) || (isstring(r) && isscalar(r))
    s = strtrim(char(r));
elseif (isnumeric(r) || islogical(r)) && isscalar(r)
    if r == round(r)
        s = int2str(r);
    else
        s = num2str(r, 17);
    end
end
end

function c = classOf(b)
c = '';
if isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
        && isstruct(b.document_class) && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
end

function blk = blockOf(b, name)
blk = struct();
if isfield(b, name) && isstruct(b.(name)) && isscalar(b.(name))
    blk = b.(name);
end
end

function v = fieldOf(s, name)
v = [];
if isstruct(s) && isfield(s, name); v = s.(name); end
end

function t = textOf(v)
t = '';
if ischar(v) || (isstring(v) && isscalar(v)); t = char(v); end
end

function t = baseText(b, name)
t = textOf(fieldOf(blockOf(b, 'base'), name));
end

function p = probeOf(b)
p = '';
try
    deps = did2.convert.v1read.readDependsOn(b, 'Name', '^probe_id$');
catch
    return;
end
if ~isempty(deps) && ~isempty(deps(1).document_id)
    p = char(deps(1).document_id);
end
end
