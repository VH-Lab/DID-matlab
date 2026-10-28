function [v1, spec] = neuron_extracellular(bodies)
%NEURON_EXTRACELLULAR Rebuild a v1 `neuron_extracellular` from what
%   did2.convert.migrators_j.neuron_extracellular emitted when it CONVERTED it:
%   the calculations about the sorted unit (cluster index and quality label:
%   `label`; mean waveform: `voltage`; quality number: `score`), all about the
%   unit's entity (the element it came from, [neuron uses the sorted unit's
%   cell], Jess Haley, 2026-10-27), the session anchor and the software
%   entities (with their version assertions).
%
%   [V1, SPEC] = did2.convert.roundtrip.neuron_extracellular(BODIES). V1 is the
%   document in the shape NDI-matlab's writers give it
%   (neuron_extracellular.json + app.json + base.json at the locked `main`
%   3cb19a8; +ndi/+fun/+probe/+import/+jrclust/probe.m, +kilosort/probe.m,
%   +kiasort/probe.m, +ndi/+app/spikesorter.m):
%
%     base.id, session_id, datestamp   the FIRST calculation (calcParts): it
%                                      holds the v1 id ([every v1 id
%                                      survives], Jess Haley, 2026-10-27; the
%                                      migrator emits the waveform first)
%     app                              the calculations' software entities
%     depends_on element_id            the calculations' entity_id
%     depends_on spike_clusters_id     the calculations' input_id ('' when none)
%     cluster_index                    the 'spike sorter cluster index' label
%     quality_label                    the 'spike sort quality' label
%     quality_number                   the 'spike sort quality' score
%     mean_waveform                    the 'mean spike waveform' voltage values,
%                                      column-major over (time, channel)
%     waveform_sample_times            the time covariate: its values, or
%                                      origin + spacing * (0:n-1), equal to the
%                                      v1 times within one rounding step
%                                      (SPEC.same; [sample times equal within
%                                      one rounding step], Jess Haley,
%                                      2026-10-27)
%     number_of_samples_per_channel,   restated by the waveform's two extents
%     number_of_channels               ([restated values checked]); with no
%                                      waveform the writers' 1 or 0
%                                      (SPEC.equivalents)
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.neuron_extracellular.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
n = numel(bodies);
used = false(1, n);
% the calculations, by variable and value kind; all about ONE entity, the unit
calcs = struct('kind', {}, 'variable', {}, 'body', {});
unitIds = {};
for k = 1:n
    b = bodies{k};
    if ~strcmp(classNameOf(b), 'calculation')
        continue;
    end
    [~, var] = termParts(getIn(b, 'statement', 'variable'));
    kind = '';
    for kk = {'label', 'score', 'voltage'}
        if isfield(b, kk{1}); kind = kk{1}; end
    end
    calcs(end+1) = struct('kind', kind, 'variable', var, 'body', b); %#ok<AGROW>
    unitIds = [unitIds, edgeIds(b, 'entity_id')]; %#ok<AGROW>
    used(k) = true;
end
if isempty(calcs)
    spec.unplaced{end+1} = 'no calculation about the unit was emitted';
    return;
end
unitIds = unique(unitIds);
relParent = '';
if isscalar(unitIds)
    relParent = unitIds{1};
else
    spec.unplaced{end+1} = sprintf('the calculations are about %d entities, not one', ...
        numel(unitIds));
end
% identity, app: from the first calculation and the run entities it names
rest = bodies(~used);
[v1, leaf, inputs, s] = calcParts([{calcs(1).body}, rest], 'calculation', ...
    'neuron_extracellular', '');
leafUnplaced = s.unplaced;
v1 = rmfield(v1, 'neuron_extracellular');

% what calcParts placed (the anchor, the software): every body it did not call
% unplaced is used
% (calcParts was handed every body not placed here, and names each it could
% not place)
spec.unplaced = [spec.unplaced, leafUnplaced];
% every calculation names the same run: the others must agree with the first
for c = 2:numel(calcs)
    for e = {'software_id', 'operating_system_id', 'interpreter_id', 'time_reference_id', 'input_id'}
        if ~isequal(edgeIds(calcs(c).body, e{1}), edgeIds(leaf, e{1}))
            spec.unplaced{end+1} = sprintf('calculation %d names another %s', c, e{1});
        end
    end
end

sc = '';
if ~isempty(inputs); sc = inputs{1}; end
v1.depends_on = struct('name', {'element_id', 'spike_clusters_id'}, 'value', {relParent, sc});

ne = struct();
for c = 1:numel(calcs)
    b = calcs(c).body;
    switch [calcs(c).kind '|' calcs(c).variable]
        case 'label|spike sorter cluster index'
            ne.cluster_index = str2double(char(getIn(b, 'label', 'value', 'name')));
        case 'label|spike sort quality'
            ne.quality_label = char(getIn(b, 'label', 'value', 'name'));
        case 'score|spike sort quality'
            ne.quality_number = numberOf(getIn(b, 'score', 'value', 'score'));
        case 'voltage|mean spike waveform'
            [w, t, bad] = waveform(b);
            spec.unplaced = [spec.unplaced, bad];
            ne.number_of_samples_per_channel = size(w, 1);
            ne.number_of_channels = size(w, 2);
            ne.mean_waveform = w;
            ne.waveform_sample_times = t;
        otherwise
            spec.unplaced{end+1} = sprintf('calculation "%s" (%s) has no v1 field', ...
                calcs(c).variable, calcs(c).kind);
    end
end
if ~isfield(ne, 'mean_waveform')
    % no waveform: the counts were the writers' value for an empty one
    % ([writer default is not set]: 1 from the import writers, 0 from
    % spikesorter.m, absent or [] from the template)
    why = 'no waveform: a writer''s count for an empty one ([writer default is not set], carry-041)';
    for f = {'number_of_samples_per_channel', 'number_of_channels'}
        spec.equivalents(end+1) = struct('path', ['neuron_extracellular.' f{1}], ...
            'values', {{1, 0}}, 'why', why);
    end
end
v1.neuron_extracellular = ne;
spec.same(end+1) = struct('path', 'neuron_extracellular.waveform_sample_times', ...
    'fn', @(a, b) withinOneRoundingStep(a, b), 'why', ['start + step equals ' ...
    'the v1 times within eight rounding steps ([sample times within eight ' ...
    'rounding steps], Jess Haley, 2026-10-27)']);
end

function tf = withinOneRoundingStep(a, b)
% the rule of did2.convert.migrators_j.neuron_extracellular regularTimebase:
% every time within one ulp of the largest-magnitude v1 time
tf = false;
if ~isnumeric(a) || ~isnumeric(b) || numel(a) ~= numel(b) || isempty(a)
    return;
end
a = double(a(:));
b = double(b(:));
tf = all(abs(a - b) <= 8 * eps(max(abs(a))));   % [sample times within eight rounding steps]
end

function [w, t, bad] = waveform(b)
% the (time x channel) matrix and the sample times from the voltage calculation
bad = {};
w = [];
t = [];
dims = asCell(getIn(b, 'data', 'dimensions'));
if numel(dims) ~= 2
    bad{end+1} = sprintf('the waveform has %d dimensions, not (time, channel)', numel(dims));
    return;
end
nT = numberOf(getIn(dims{1}, 'n'));
nC = numberOf(getIn(dims{2}, 'n'));
vals = asCell(getIn(b, 'voltage', 'value'));
x = zeros(numel(vals), 1);
for k = 1:numel(vals)
    v = numberOf(getIn(vals{k}, 'source_value'));
    if isempty(v); v = NaN; end
    x(k) = v;
end
if numel(x) ~= nT * nC
    bad{end+1} = sprintf('%d waveform values for %d x %d', numel(x), nT, nC);
    return;
end
w = reshape(x, nT, nC);
covs = asCell(getIn(b, 'data', 'covariates'));
for k = 1:numel(covs)
    c = covs{k};
    if numberOf(getIn(c, 'along')) ~= 0; continue; end
    [q, hasQ] = getIn(c, 'quantity', 'value');
    if hasQ && ~isempty(q)
        t = column(q);
    else
        o = numberOf(getIn(c, 'origin', 'source_value'));
        s = numberOf(getIn(c, 'spacing', 'source_value'));
        if ~isempty(o) && ~isempty(s)
            t = o + s * (0:(nT - 1))';
        end
    end
end
if isempty(t)
    bad{end+1} = 'the waveform has no sample times';
end
end
