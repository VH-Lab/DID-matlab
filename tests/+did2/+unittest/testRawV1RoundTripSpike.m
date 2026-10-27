function tests = testRawV1RoundTripSpike
%TESTRAWV1ROUNDTRIPSPIKE The spike-sorting / calculation family read as raw
%   v1, and its round trip: neuron_extracellular, jrclust_clusters,
%   hartley_calc, speedtuning_calc (migrator speed_tuning_calc).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [early migration pieces
%   fixed] (1) (one migrator per class: the old +migrators wrappers for
%   hartley_calc, speed_tuning_calc, simple_calc and jrclust_clusters, and
%   their helper calcCommon, are deleted) and [migration reliability practices]
%   (a) (a round trip per class, did2.convert.roundtrip.check).
%
%   THE v1 DOCUMENTS ARE THE WRITERS'.
%     hartley_calc.mock.1.json     NDIcalc-vis-matlab 00e3e0f,
%     speedtuning_calc.mock.1.json +ndi/+calc/+vis/mock/<calc>: each
%                                  calculator's stored self-test output, copied
%                                  verbatim to tests/+did2/fixtures/ndi_writer_outputs
%     jrclust_clusters             built here as NDI-matlab (locked `main`
%     neuron_extracellular         3cb19a8) +ndi/+fun/+probe/+import/+jrclust/
%                                  probe.m writes them (no stored output
%                                  exists), and passed through
%                                  jsonencode/jsondecode, the shape a corpus
%                                  delivers; the kilosort no-template shape
%                                  (+kilosort/probe.m: meanWf = [], wst = [],
%                                  counts max(size,1) = 1) too
%   The templates they are written over are copied verbatim to
%   tests/+did2/fixtures/ndi_templates (NDI-matlab 3cb19a8: jrclust_clusters,
%   ngrid, neuron_extracellular, app, calculator, base; NDIcalc-vis-matlab
%   00e3e0f: hartley_calc, hartley_reverse_correlation, reverse_correlation,
%   speedtuning_calc, speed_tuning). The writer wins over the template: the
%   Hartley writer stores frameTimes, hartley_numbers and spiketimes inline
%   where its current template lists .bin files.
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY.
%     hartley_calc   converts (with its presentation in the batch); alone it is
%                    carried (carry-040: the stimulus properties could not be
%                    compared). Nothing lost.
%     speedtuning_calc  carried (carry-056): its three fit blocks `fit`,
%                    `fit_no_speed`, `fit_fullspeed` would become three
%                    model_fit entries all named 'Priebe fit'. The same document
%                    with one fit block (the "converted shape") converts and
%                    loses nothing. On the renamed path it passed through
%                    unconverted: universalRenames never mapped the writer's
%                    spelling to the migrator.
%     jrclust_clusters  converts. KNOWN FINDING: base.name (the writer sets it
%                    to the parameter file's name, 'jrclust.prm') is not
%                    written (#73 item 54); the Soph vintage whose name is in
%                    ndi_document.name is carried (carry-049, [one-reading
%                    quick answers] Q5).
%     neuron_extracellular  converts. KNOWN FINDINGS: base.id (the migrator
%                    mints the unit's id and keeps the source id on no
%                    document), and waveform_sample_times (the regular time
%                    axis is stored as origin + spacing, which rebuilds the
%                    writer's (a:b)'/rate to within 1.1e-19, not exactly).
%   Every lost path is listed here exactly; nothing is invented or unplaced.
tests = functiontests(localfunctions);
end

function setup(testCase)
did2.convert.stimulusPresentationSpecs('reset');
testCase.addTeardown(@() did2.convert.stimulusPresentationSpecs('reset'));
end

% ===================== the writers' documents round trip =================

function testWriterOutputsRoundTrip(testCase)
% {label, batch (first: the document), carried?, known lost paths}
cases = { ...
    'hartley writer output', {hartley(), presentationOf(hartley())}, false, {}; ...
    'hartley corpus vintage', {hartleyVintage(), presentationOf(hartleyVintage())}, false, {}; ...
    'hartley without its presentation', {hartley()}, true, {}; ...
    'speed writer output', {speed()}, true, {}; ...
    'speed, converted shape', {speedOneFit()}, false, {}; ...
    'jrclust writer output', {jrclust()}, false, {'base.name'}; ...
    'jrclust Soph vintage (ndi_document.name)', {jrclustNdiDocument()}, true, {}; ...
    'neuron writer output', {neuron()}, false, ...
        {'base.id', 'neuron_extracellular.waveform_sample_times'}; ...
    'neuron corpus vintage (no sorting output)', {neuronCorpusVintage()}, false, ...
        {'base.id', 'neuron_extracellular.waveform_sample_times'}; ...
    'neuron with no waveform (kilosort)', {neuronNoWaveform()}, false, {'base.id'}; ...
    'neuron with times but no waveform (jrclust)', {neuronTimesOnly()}, true, {}};
for k = 1:size(cases, 1)
    [label, batch, carried, known] = cases{k, :};
    out = runRaw(batch);
    verifyEmpty(testCase, out.quarantine, [label ': quarantined']);
    mine = own(out.migrated);
    r = did2.convert.roundtrip.check(batch{1}, mine);
    verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
    verifyEqual(testCase, r.carried, carried, [label ': carried?']);
    verifyEqual(testCase, sort(lostPaths(r)), sort(known), ...
        sprintf('%s: lost %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end
end

function testEveryWriterFieldOfAConvertedHartleyIsAccountedFor(testCase)
% the denominator is the writer's document: each leaf matched, restated,
% equivalent, not set or exempt, and the ones the fold turns on by name
v1 = hartley();
r = did2.convert.roundtrip.check(v1, own(runRaw({v1, presentationOf(v1)}).migrated));
accounted = [r.matched, r.restated, r.equivalent, r.not_set, r.exempt];
verifyEqual(testCase, numel(accounted), r.fields_inspected);
for p = {'ngrid.coordinates', 'ngrid.data_dim', 'ngrid.data_type', 'ngrid.data_size', ...
        'hartley_reverse_correlation.frameTimes', 'hartley_reverse_correlation.spiketimes', ...
        'hartley_reverse_correlation.hartley_numbers.KXV', ...
        'hartley_reverse_correlation.reconstruction_properties.T_coords', ...
        'hartley_reverse_correlation.stimulus_properties.rect', ...
        'hartley_calc.input_parameters.T', 'hartley_calc.depends_on(1).value', ...
        'reverse_correlation.method', 'files.file_info.locations.location', ...
        'app.version', 'depends_on(2).value', 'document_class.class_name'}
    verifyTrue(testCase, any(strcmp(p{1}, [r.matched, r.restated, r.equivalent])), ...
        sprintf('%s is not accounted for', p{1}));
end
end

function testCarriesCiteTheirRows(testCase)
verifyCarriedFor(testCase, {hartley()}, '[carry-040]');
verifyCarriedFor(testCase, {speed()}, '[carry-056] speed_tuning.fit, speed_tuning.fit_no_speed');
verifyCarriedFor(testCase, {jrclustNdiDocument()}, '[carry-049] universalRenames would discard: ndi_document');
verifyCarriedFor(testCase, {neuronTimesOnly()}, ...
    'neuron_extracellular.waveform_sample_times (no mean_waveform');
end

% ===================== the switch ======================================

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for cls = {'neuron_extracellular', 'jrclust_clusters', 'hartley_calc', 'speedtuning_calc'}
    verifyTrue(testCase, any(strcmp(names, cls{1})), cls{1});
end
verifyEqual(testCase, did2.convert.rawV1Classes('speedtuning_calc'), 'speed_tuning_calc');
verifyFalse(testCase, any(strcmp(names, 'speed_tuning_calc')), ...
    'the migrator''s spelling is not the v1 name');
verifyFalse(testCase, any(strcmp(names, 'simple_calc')), ...
    'simple_calc stays on the renamed path (rawV1Classes, NOT LISTED)');
end

function testTheSwitchChangesNoConvertedDocument(testCase)
% "keep behaviour identical": every document the raw path CONVERTS is the one
% the universalRenames path converted; a carry is carried on both paths, the
% raw one the untouched v1 source
batches = {{hartley(), presentationOf(hartley())}, {hartleyVintage(), presentationOf(hartleyVintage())}, ...
    {hartley()}, {jrclust()}, {jrclustNdiDocument()}, {neuron()}, {neuronCorpusVintage()}, ...
    {neuronNoWaveform()}};
for k = 1:numel(batches)
    b = batches{k};
    raw = runRaw(b);
    old = did2.convert.v1_to_v2(b, 'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
    label = sprintf('batch %d (%s)', k, b{1}.document_class.class_name);
    verifyEqual(testCase, raw.summary.legacy_ndi_document.bodies_read_raw_v1, 1, label);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), ...
        [label ': carried on one path only']);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    if isCarried(raw, b{1})
        verifyTrue(testCase, isCarried(old, []), [label ': carried on the raw path only']);
        continue;
    end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        verifyTrue(testCase, isequaln(raw.migrated{j}.toStruct(), old.migrated{j}.toStruct()), ...
            sprintf('%s, document %d differs between the raw and the renamed path', label, j));
    end
end
end

function testTheSpeedWriterSpellingNeverReachedItsMigratorBeforeTheSwitch(testCase)
% the renamed path keeps `speedtuning_calc` (universalRenames maps only the
% contrast spellings) and finds no migrator by that name: the document passed
% through unconverted. The raw path reaches speed_tuning_calc through
% rawV1Classes' table; the converted shape converts the same way on the
% migrator's own spelling.
v1 = speedOneFit();
old = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
verifyEqual(testCase, numel(old.migrated), 1);
verifyEqual(testCase, char(old.migrated{1}.get('document_class.class_name')), 'speedtuning_calc');
raw = runRaw({v1});
names = cellfun(@(d) char(d.get('document_class.class_name')), raw.migrated, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'speed_tuning_calculation')), strjoin(names, ', '));
snake = respelled(v1, 'speed_tuning_calc');
b = runRaw({snake});
verifyEqual(testCase, b.summary.legacy_ndi_document.bodies_read_raw_v1, 0);
verifyEqual(testCase, numel(b.migrated), numel(raw.migrated));
for j = 1:min(numel(b.migrated), numel(raw.migrated))
    verifyTrue(testCase, isequaln(b.migrated{j}.toStruct(), raw.migrated{j}.toStruct()), ...
        sprintf('document %d differs between the two spellings', j));
end
end

function testTheOldSpikeWrappersAreGone(testCase)
% [early migration pieces fixed] (1): one migrator per class. The +migrators
% wrappers were never reached (each class has a +migrators_j migrator, and no
% v1 class names them as a superclass); calcCommon served only them.
for cls = {'hartley_calc', 'speed_tuning_calc', 'simple_calc', 'jrclust_clusters'}
    verifyEmpty(testCase, which(['did2.convert.migrators.' cls{1}]), ...
        sprintf('+migrators/%s.m is back', cls{1}));
    verifyNotEmpty(testCase, which(['did2.convert.migrators_j.' cls{1}]), ...
        sprintf('+migrators_j/%s.m is missing', cls{1}));
end
verifyEmpty(testCase, which('did2.convert.calcCommon'), 'calcCommon is back');
% the one superclass migrator hartley_calc met stays, for ontology_image
verifyNotEmpty(testCase, which('did2.convert.migrators_j.super.ngrid'));
end

function testTheConvertedDocumentsValidate(testCase)
% the converted documents pass the V2 schema (the corpus run validates too)
batches = {{hartley(), presentationOf(hartley())}, {speedOneFit()}, {jrclust()}, {neuron()}, ...
    {neuronNoWaveform()}};
for k = 1:numel(batches)
    out = did2.convert.v1_to_v2(batches{k}, 'Validate', true, 'TargetVersion', 'V_eta');
    label = batches{k}{1}.document_class.class_name;
    verifyEmpty(testCase, out.quarantine, sprintf('%s: %s', label, quarantineText(out)));
    verifyGreaterThan(testCase, numel(out.migrated), 2, label);
end
end

% ===================== every field accounted for =========================

function testAFieldTheFoldDoesNotReadCarriesTheDocument(testCase)
v1 = neuron();
v1.neuron_extracellular.isolation_distance = 12.5;
verifyCarriedFor(testCase, {v1}, 'neuron_extracellular.isolation_distance');
v1 = neuron();
v1.app.license = 'MIT';
verifyCarriedFor(testCase, {v1}, 'app.license');
v1 = neuron();
v1.neuron_extracellular.cluster_index = 7.5;
verifyCarriedFor(testCase, {v1}, 'cluster_index (not one whole number)');
v1 = neuron();
v1.neuron_extracellular.quality_label = ' single';
verifyCarriedFor(testCase, {v1}, 'quality_label (surrounding spaces)');
v1 = jrclust();
v1.jrclust_clusters.num_clusters = 12;
verifyCarriedFor(testCase, {v1}, 'jrclust_clusters.num_clusters');
v1 = jrclust();
v1.depends_on(end + 1) = struct('name', 'sorting_parameters_id', 'value', 'sp_1');
verifyCarriedFor(testCase, {v1}, 'depends_on sorting_parameters_id');
v1 = hartley();
v1.hartley_reverse_correlation.window = [0 1];
verifyCarriedFor(testCase, {v1, presentationOf(v1)}, '[carry-056] hartley_reverse_correlation.window');
v1 = hartley();
v1.ngrid.data_size = 4;
verifyCarriedFor(testCase, {v1, presentationOf(v1)}, '[carry-056] ngrid.data_size');
v1 = hartley();
v1.hartley_calc.log = 'a log';
verifyCarriedFor(testCase, {v1, presentationOf(v1)}, '[carry-056] hartley_calc.log');
v1 = speedOneFit();
v1.speed_tuning.fit.Priebe_fit_note = 'x';
verifyCarriedFor(testCase, {v1}, '[carry-056]');
end

% ===================== a check that cannot fail proves nothing ===========

function testABrokenEmissionIsReportedLost(testCase)
% jrclust: the checksum in the body's description changed
v1 = jrclust();
docs = structs(runRaw({v1}).migrated);
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'opaque_body')
        docs{k}.data_body.description = 'JRCLUST results (res_mat_MD5_checksum: 0)';
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, sort(lostPaths(r)), sort({'base.name', 'jrclust_clusters.res_mat_MD5_checksum'}));

% neuron: one waveform sample changed
v1 = neuron();
docs = structs(runRaw({v1}).migrated);
for k = 1:numel(docs)
    if isfield(docs{k}, 'voltage')
        v = docs{k}.voltage.value;
        if iscell(v)
            v{3}.source_value = v{3}.source_value + 1;
        else
            v(3).source_value = v(3).source_value + 1;
        end
        docs{k}.voltage.value = v;
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyTrue(testCase, any(strcmp(lostPaths(r), 'neuron_extracellular.mean_waveform')));

% hartley: the spike-time body dropped
v1 = hartley();
docs = structs(own(runRaw({v1, presentationOf(v1)}).migrated));
keep = true(1, numel(docs));
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'sampled_body') ...
            && ~isfield(docs{k}.data_body, 'conditions')
        keep(k) = false;
    end
end
r = did2.convert.roundtrip.check(v1, docs(keep));
verifyEqual(testCase, lostPaths(r), {'hartley_reverse_correlation.spiketimes'});
end

function testADifferentSourceIsReportedLost(testCase)
v1 = hartley();
out = runRaw({v1, presentationOf(v1)});
v1.ngrid.coordinates(1) = 99;
v1.hartley_reverse_correlation.stimulus_properties.fps = 60;
r = did2.convert.roundtrip.check(v1, own(out.migrated));
verifyFalse(testCase, r.ok);
verifyEqual(testCase, sort(lostPaths(r)), ...
    {'hartley_reverse_correlation.stimulus_properties.fps', 'ngrid.coordinates'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = neuron();
out = runRaw({v1});
extra = runRaw({jrclust()}).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(2)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== helpers =========================================

function out = runRaw(batch)
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
end

function docs = own(migrated)
% the documents emitted for the first source: every one but a passed-through
% stimulus_presentation (the batch's other member)
keep = cellfun(@(d) ~strcmp(char(d.get('document_class.class_name')), 'stimulus_presentation'), migrated);
docs = migrated(keep);
end

function tf = isCarried(out, v1)
docs = own(out.migrated);
tf = isscalar(docs) && strcmp(char(docs{1}.get('document_class.schema_version')), 'did_v1');
if tf && ~isempty(v1)
    s = docs{1}.toStruct();
    s.document_class = rmfield(s.document_class, 'schema_version');
    tf = isequaln(s, v1);
end
end

function verifyCarriedFor(testCase, batch, part)
out = runRaw(batch);
v1 = batch{1};
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, isCarried(out, v1), [label ': not carried as the untouched v1 source']);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'carried_as_v1'), [label ': no carried_as_v1 note']);
d = strjoin(cellstr(notes.carried_as_v1.distinct_details), ' || ');
verifyTrue(testCase, contains(d, part), sprintf('%s: the note does not name it: %s', label, d));
end

function p = lostPaths(r)
p = {};
if ~isempty(r.lost)
    p = {r.lost.path};
end
end

function s = describeLost(r)
s = strjoin(lostPaths(r), '; ');
end

function c = structs(docs)
c = cellfun(@(d) d.toStruct(), docs, 'UniformOutput', false);
end

function s = quarantineText(out)
s = strjoin(arrayfun(@(q) sprintf('%s|%s|%s', q.class_name, q.identifier, q.message), ...
    out.quarantine, 'UniformOutput', false), '; ');
end

function d = writerOutput(file)
thisDir = fileparts(mfilename('fullpath'));
d = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_writer_outputs', file)));
end

function v1 = hartley()
% ndi.calc.vis.hartley's own stored output, verbatim
v1 = writerOutput('hartley_calc.mock.1.json');
end

function v1 = hartleyVintage()
% the shape corpus 20211116 holds: class version 1, the app named
% 'ndi.calc.vis.hartley_calc' (an earlier writer)
v1 = hartley();
v1.document_class.class_version = 1;
v1.app.name = 'ndi.calc.vis.hartley_calc';
end

function p = presentationOf(v1)
% the stimulus_presentation the calculation names, with the generator settings
% its stimulus_properties copy (the measured key pairs, hartley_calc.m), and
% settings the copy does not carry beside them
sp = v1.hartley_reverse_correlation.stimulus_properties;
p = struct();
p.document_class = struct('class_name', 'stimulus_presentation', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json'}));
p.depends_on = struct('name', 'stimulus_element_id', 'value', 'stim_1');
p.base = struct('id', v1.depends_on(2).value, 'session_id', v1.base.session_id, ...
    'name', '', 'datestamp', v1.base.datestamp);
p.stimulus_presentation = struct('presentation_order', 1, 'stimuli', struct('parameters', struct( ...
    'rect', sp.rect, 'windowShape', 0, 'distance', 30, 'M', sp.M, 'K_absmax', sp.K_max, ...
    'L_absmax', sp.L_max, 'sfmax', sp.sf_max, 'contrast', 1, 'chromhigh', sp.color_high, ...
    'chromlow', sp.color_low, 'background', 0.5, 'fps', sp.fps)));
end

function v1 = speed()
% ndi.calc.vis.speed_tuning's own stored output, verbatim
v1 = writerOutput('speedtuning_calc.mock.1.json');
end

function v1 = speedOneFit()
% the writer's document with one fit block (the "converted shape")
v1 = speed();
v1.speed_tuning = rmfield(v1.speed_tuning, {'fit_no_speed', 'fit_fullspeed'});
end

function s = respelled(v1, name)
s = v1;
old = s.document_class.class_name;
s.document_class.class_name = name;
s.document_class.property_list_name = name;
s.(name) = s.(old);
s = rmfield(s, old);
end

function app = jrclustApp()
% jrclust/probe.m appStruct
app = struct('name', 'JRCLUST to ndi.fun.probe.import.jrclust', 'version', '4.1.0', ...
    'url', 'https://github.com/VH-Lab/JRCLUST', 'os', 'GLNXA64', 'os_version', '', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.2');
end

function dc = stampOf(path, cls)
dc = struct('definition', ['$NDIDOCUMENTPATH/' path cls '.json'], ...
    'validation', ['$NDISCHEMAPATH/' path cls '_schema.json'], ...
    'class_name', cls, 'property_list_name', cls, 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json', '$NDIDOCUMENTPATH/app.json'}));
end

function d = jrclust()
% jrclust/probe.m: ndi.document('jrclust_clusters', 'app', appStruct,
% 'base.session_id', S.id(), 'base.name', options.prmName,
% 'jrclust_clusters.res_mat_MD5_checksum', md5Value), then element_id
d = struct();
d.document_class = stampOf('apps/jrclust/', 'jrclust_clusters');
d.depends_on = struct('name', 'element_id', 'value', 'probe_1');
d.base = struct('id', 'jc_1', 'session_id', 'sess_1', 'name', 'jrclust.prm', ...
    'datestamp', '2026-08-27T00:22:18.600Z');
d.app = jrclustApp();
d.jrclust_clusters = struct('res_mat_MD5_checksum', '0cc175b9c0f1b6a831c399e269772661');
d = jsondecode(jsonencode(d));
end

function d = jrclustNdiDocument()
% the Soph vintage: an ndi_document block naming the parameter file beside
% `base`, whose name is empty, and an empty app block
d = jrclust();
d.base.name = '';
d.ndi_document = struct('name', 'jrclust.prm');
f = fieldnames(d.app);
for k = 1:numel(f); d.app.(f{k}) = ''; end
end

function d = neuron()
% jrclust/probe.m: the neuron_extracellular of one unit (addMultiple sets
% element_id; spike_clusters_id is the jrclust_clusters document)
d = struct();
d.document_class = stampOf('neuron/', 'neuron_extracellular');
d.depends_on = struct('name', {'element_id', 'spike_clusters_id'}, 'value', {'neuron_el_1', 'jc_1'});
d.base = struct('id', 'ne_1', 'session_id', 'sess_1', 'name', '', ...
    'datestamp', '2026-08-27T00:22:18.600Z');
d.app = jrclustApp();
meanWf = reshape(sin(1:(21 * 4)) * 100, 21, 4);
ne = struct();
ne.number_of_samples_per_channel = max(size(meanWf, 1), 1);
ne.number_of_channels = max(size(meanWf, 2), 1);
ne.mean_waveform = meanWf;
ne.waveform_sample_times = (-5:15)' / 20000;   % (evtWindowSamp(1):evtWindowSamp(2))'/sampleRate
ne.cluster_index = 7;
ne.quality_number = 1;
ne.quality_label = 'single';
d.neuron_extracellular = ne;
d = jsondecode(jsonencode(d));
end

function d = neuronCorpusVintage()
% the 20211116 / Soph vintage: spike_clusters_id declared and empty, a
% multi-unit, quality 4
d = neuron();
d.depends_on(2).value = '';
d.neuron_extracellular.quality_number = 4;
d.neuron_extracellular.quality_label = 'multi';
end

function d = neuronNoWaveform()
% +kilosort/probe.m when waveform_source is not 'templates': meanWf = [],
% wst = [], counts max(size([],k),1) = 1
d = neuron();
d.neuron_extracellular.mean_waveform = [];
d.neuron_extracellular.waveform_sample_times = [];
d.neuron_extracellular.number_of_samples_per_channel = 1;
d.neuron_extracellular.number_of_channels = 1;
end

function d = neuronTimesOnly()
% jrclust/probe.m when the results hold no mean waveform: meanWf = [] but the
% times are the parameter file's window
d = neuronNoWaveform();
d.neuron_extracellular.waveform_sample_times = (-5:15)' / 20000;
end
