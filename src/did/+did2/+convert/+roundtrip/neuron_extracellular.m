function [v1, spec] = neuron_extracellular(bodies)
%NEURON_EXTRACELLULAR Rebuild a v1 `neuron_extracellular` from what
%   did2.convert.migrators_j.neuron_extracellular emitted when it CONVERTED it:
%   the sorted unit (an `entity` of type cell), its derived_from relation to
%   the recording element, the session anchor, the calculations about the unit
%   (cluster index and quality label: `label`; mean waveform: `voltage`;
%   quality number: `score`) and the software entities (with their version
%   assertions).
%
%   [V1, SPEC] = did2.convert.roundtrip.neuron_extracellular(BODIES). V1 is the
%   document in the shape NDI-matlab's writers give it
%   (neuron_extracellular.json + app.json + base.json at the locked `main`
%   3cb19a8; +ndi/+fun/+probe/+import/+jrclust/probe.m, +kilosort/probe.m,
%   +kiasort/probe.m, +ndi/+app/spikesorter.m):
%
%     base.id, session_id, datestamp   the calculations' run (calcParts; the
%                                      unit's id is minted, the source id is
%                                      not kept: no inbound edge names a
%                                      neuron_extracellular)
%     app                              the calculations' software entities
%     depends_on element_id            the relation's parent_id
%     depends_on spike_clusters_id     the calculations' input_id ('' when none)
%     cluster_index                    the 'spike sorter cluster index' label
%     quality_label                    the 'spike sort quality' label
%     quality_number                   the 'spike sort quality' score
%     mean_waveform                    the 'mean spike waveform' voltage values,
%                                      column-major over (time, channel)
%     waveform_sample_times            the time covariate: its values, or
%                                      origin + spacing * (0:n-1)
%     number_of_samples_per_channel,   restated by the waveform's two extents
%     number_of_channels               ([restated values checked]); with no
%                                      waveform the writers' 1 or 0
%                                      (SPEC.equivalents)
%
%   base.id: the migrator does not keep the source id on any emitted document
%   (testMigratorsJNeuronExtracellular testTheSourceIdIsNotReusedByAnyEmittedBody),
%   so it is REPORTED LOST by the round trip (a known finding,
%   testRawV1RoundTripSpike; open).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.neuron_extracellular.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
n = numel(bodies);
used = false(1, n);
unitIdx = [];
for k = 1:n
    if isEntityOfType(bodies{k}, 'cell') && isempty(unitIdx)
        unitIdx = k;
    end
end
if isempty(unitIdx)
    spec.unplaced{end+1} = 'no unit entity (type cell) was emitted';
    return;
end
unit = bodies{unitIdx};
used(unitIdx) = true;
unitId = char(getIn(unit, 'base', 'id'));

% the calculations about the unit, by variable and value kind
calcs = struct('kind', {}, 'variable', {}, 'body', {});
for k = 1:n
    b = bodies{k};
    if ~strcmp(classNameOf(b), 'calculation') || ~isequal(edgeIds(b, 'entity_id'), {unitId})
        continue;
    end
    [~, var] = termParts(getIn(b, 'statement', 'variable'));
    kind = '';
    for kk = {'label', 'score', 'voltage'}
        if isfield(b, kk{1}); kind = kk{1}; end
    end
    calcs(end+1) = struct('kind', kind, 'variable', var, 'body', b); %#ok<AGROW>
    used(k) = true;
end
if isempty(calcs)
    spec.unplaced{end+1} = 'no calculation about the unit was emitted';
    return;
end
relParent = '';
for k = 1:n
    b = bodies{k};
    if used(k) || ~strcmp(classNameOf(b), 'directed_relation'); continue; end
    if isequal(edgeIds(b, 'child_id'), {unitId})
        p = edgeIds(b, 'parent_id');
        if isscalar(p); relParent = p{1}; end
        used(k) = true;
    end
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
local = fieldText(getIn(unit, 'entity'), 'local_identifier');
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
% the unit's name restates its cluster index
want = 'unit';
if isfield(ne, 'cluster_index'); want = sprintf('unit_%d', ne.cluster_index); end
if ~strcmp(local, want)
    spec.unplaced{end+1} = sprintf('the unit is named "%s", not "%s"', local, want);
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
