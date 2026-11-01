function tests = testRawV1RoundTripSpikeParameters
%TESTRAWV1ROUNDTRIPSPIKEPARAMETERS The spike-sorting parameters family read as
%   raw v1, and its round trip: spike_extraction_parameters,
%   spike_extraction_parameters_modification, sorting_parameters,
%   kilosort_clusters, kiasort_clusters, SpikeInterfaceSortingOutputs
%   (migrator spike_interface_sorting_outputs).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed].
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim) in
%   the shapes their WRITERS give them, through jsonencode/jsondecode:
%     spike_extraction_parameters   ndi.app.spikeextractor struct2doc: the
%                                   settings struct, + newdocument() (the app
%                                   block: name, version, url, os, os_version,
%                                   interpreter, interpreter_version), base.name
%                                   the extraction name
%     ..._modification              the same, + 'epochid.epochid' (the writer
%                                   wins: the template declares no epochid
%                                   block), extraction_parameters_id, element_id
%     sorting_parameters            ndi.app.spikesorter struct2doc
%     kilosort_clusters             +ndi/+fun/+probe/+import/+kilosort/probe.m:
%                                   app_struct, the directory, the md5sum,
%                                   element_id
%     kiasort_clusters              +kiasort/probe.m, the same
%   SpikeInterfaceSortingOutputs has no writer at that `main` and no corpus
%   document: its fixture is the template with values in its three fields, and
%   it is not invented further.
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY. The three settings documents carry
%   (carry-002/003/004: the run's os and interpreter, which no method keeps);
%   the same documents with those four app fields empty (the "converted
%   shape", DID-side) convert and lose nothing. The cluster documents convert
%   and lose nothing. SpikeInterfaceSortingOutputs passes through. No
%   writer-shaped document loses a field: there are no known findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the switch ======================================

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for c = {'spike_extraction_parameters', 'spike_extraction_parameters_modification', ...
        'sorting_parameters', 'kilosort_clusters', 'kiasort_clusters', 'SpikeInterfaceSortingOutputs'}
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
end
verifyEqual(testCase, did2.convert.rawV1Classes('SpikeInterfaceSortingOutputs'), ...
    'spike_interface_sorting_outputs');
% INVERTED 2026-10-27 ([unbuilt spike classes carry as needs home], Jess
% Haley): they are read raw so that their carry is the untouched v1 source
for c = {'spikewaves', 'spike_clusters', 'binnedspikeratevm'}
    verifyTrue(testCase, any(strcmp(names, c{1})), ...
        [c{1} ' is read raw and carried (rawV1Classes)']);
end
f = writerFixtures();
r = runRaw(f(:, 2)');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, size(f, 1));
end

% ===================== every writer shape round trips =====================

function testWriterShapesRoundTrip(testCase)
f = writerFixtures();
for k = 1:size(f, 1)
    [label, v1, outcome] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    switch outcome
        case 'converted'
            verifyEmpty(testCase, out.passthrough, [label ': converted']);
            verifyFalse(testCase, r.carried, label);
        case 'passthrough'
            verifyEqual(testCase, numel(out.passthrough), 1, [label ': a passthrough']);
            verifyFalse(testCase, r.carried, label);
        case 'carried'
            verifyTrue(testCase, r.carried, [label ': carried']);
    end
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testEveryTemplateFieldIsAccountedFor(testCase)
f = writerFixtures();
cases = { ...
    'spike_extraction_parameters, converted shape', [strcat('spike_extraction_parameters.', ...
        extractionFields()), {'base.name', 'app.name', 'app.version', 'app.url'}]; ...
    'spike_extraction_parameters_modification, converted shape', [strcat( ...
        'spike_extraction_parameters_modification.', extractionFields()), ...
        {'epochid.epochid', 'depends_on(1).value', 'depends_on(2).value', 'base.name'}]; ...
    'sorting_parameters, converted shape', strcat('sorting_parameters.', ...
        {'graphical_mode', 'num_pca_features', 'interpolation', 'min_clusters', ...
        'max_clusters', 'num_start'}); ...
    'kilosort_clusters', {'kilosort_clusters.kilosort_directory', ...
        'kilosort_clusters.curated_output_MD5_checksum', 'app.name', 'app.version', ...
        'app.url', 'app.os', 'app.interpreter', 'app.interpreter_version', 'depends_on(1).value'}; ...
    'kiasort_clusters', {'kiasort_clusters.kiasort_directory', ...
        'kiasort_clusters.curated_output_MD5_checksum', 'app.os'}};
for k = 1:size(cases, 1)
    v1 = f{strcmp(f(:, 1), cases{k, 1}), 2};
    r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
    accounted = [r.matched, r.restated, r.equivalent];
    for p = cases{k, 2}
        verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
            sprintf('%s: %s is not accounted for', cases{k, 1}, p{1}));
    end
end
end

% ===================== the switch changes no outcome ======================

function testTheSortingOutputsPassThroughUnderTheirV1Name(testCase)
v1 = sortingOutputs();
raw = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, numel(raw.passthrough), 1);
verifyEqual(testCase, char(raw.migrated{1}.get('document_class.class_name')), ...
    'SpikeInterfaceSortingOutputs');
out = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine, 'a passthrough with no V_eta class is counted, not quarantined');
end

function testTheConvertedDocumentsValidate(testCase)
f = writerFixtures();
for k = 1:size(f, 1)
    out = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine, sprintf('%s: %s', f{k, 1}, quarantineText(out)));
end
end

% ===================== what the migrator does not read is carried =========

function testAFieldTheMigratorDoesNotReadCarriesTheDocument(testCase)
v1 = convertedShape(writerExtraction());
v1.app.license = 'MIT';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: app.license');
v1 = convertedShape(writerExtraction());
v1.epochid = struct('epochid', 't00001');
verifyCarried(testCase, v1, 'epochid');
v1 = did2.unittest.helpers.setDependency(convertedShape(writerSorting()), 'probe_id', 'p_1');
verifyCarried(testCase, v1, 'depends_on(probe_id)');
v1 = writerCluster('kilosort');
v1.kilosort_clusters.n_units = 12;
verifyCarried(testCase, v1, 'kilosort_clusters.n_units');
v1 = writerCluster('kiasort');
v1.kiasort_clusters.curated_output_MD5_checksum = upper(v1.kiasort_clusters.curated_output_MD5_checksum);
verifyCarried(testCase, v1, 'not lower-case hex');
v1 = sortingOutputs();
v1.SpikeInterfaceSortingOutputs.n_units = 4;
verifyCarried(testCase, v1, 'SpikeInterfaceSortingOutputs.n_units');
end

function testTheWriterSettingsCarryTheirRunEnvironment(testCase)
for c = {{writerExtraction(), '[carry-003]'}, {writerModification(), '[carry-004]'}, ...
        {writerSorting(), '[carry-002]'}}
    [carried, notes] = did2.unittest.helpers.carryNote({c{1}{1}});
    verifyTrue(testCase, carried, c{1}{2});
    verifyTrue(testCase, contains(notes, [c{1}{2} ' unplaced: app.os']), notes);
end
end

% ===================== a check that cannot fail proves nothing ===========

function testABrokenEmissionIsReportedLost(testCase)
v1 = convertedShape(writerExtraction());
docs = structs(runRaw(v1).migrated);
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'method')
        docs{k}.method.name = 'another';
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'base.name'});

v1 = writerCluster('kilosort');
docs = structs(runRaw(v1).migrated);
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'opaque_body')
        docs{k}.data_body.content_hash = '0';
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyEqual(testCase, {r.lost.path}, {'kilosort_clusters.curated_output_MD5_checksum'});
end

function testADifferentSourceIsReportedLost(testCase)
v1 = convertedShape(writerModification());
out = runRaw(v1);
v1.spike_extraction_parameters_modification.spike_end_time = 0.002;
v1.epochid.epochid = 't00002';
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, sort({r.lost.path}), ...
    {'epochid.epochid', 'spike_extraction_parameters_modification.spike_end_time'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = writerCluster('kiasort');
out = runRaw(v1);
extra = runRaw(convertedShape(writerSorting())).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== fixtures, from the WRITERS =========================

function f = writerFixtures()
f = { ...
    'spike_extraction_parameters, spikeextractor', writerExtraction(), 'carried'; ...
    'spike_extraction_parameters, converted shape', convertedShape(writerExtraction()), 'converted'; ...
    'spike_extraction_parameters_modification, spikeextractor', writerModification(), 'carried'; ...
    'spike_extraction_parameters_modification, converted shape', ...
        convertedShape(writerModification()), 'converted'; ...
    'sorting_parameters, spikesorter', writerSorting(), 'carried'; ...
    'sorting_parameters, converted shape', convertedShape(writerSorting()), 'converted'; ...
    'kilosort_clusters', writerCluster('kilosort'), 'converted'; ...
    'kiasort_clusters', writerCluster('kiasort'), 'converted'; ...
    'SpikeInterfaceSortingOutputs, template', sortingOutputs(), 'passthrough'};
end

function n = extractionFields()
n = {'center_range_time', 'overlap', 'read_time', 'refractory_time', 'spike_start_time', ...
    'spike_end_time', 'do_filter', 'filter_type', 'filter_low', 'filter_high', ...
    'filter_order', 'filter_ripple', 'threshold_method', 'threshold_parameter', 'threshold_sign'};
end

function app = newdocumentApp(name)
% ndi.app/newdocument: name, the git version and url, computer, the OS
% version, 'MATLAB' and its version
app = struct('name', name, 'version', '9f3c2a1b7d4e5f60718293a4b5c6d7e8f9012345', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'GLNXA64', ...
    'os_version', '6.5.0', 'interpreter', 'MATLAB', 'interpreter_version', '24.2.0.2712019 (R2024b)');
end

function d = writerExtraction()
% struct2doc('extraction_parameters', settings, name): the template's
% settings (spikeextractor's defaults) + newdocument() + base.name
d = did2.unittest.helpers.ndiDocument('spike_extraction_parameters', ...
    'Id', '41268b6f5c6a3d4e_5e0000000000000a', 'Name', 'default');
d.app = newdocumentApp('ndi_app_spikeextractor');
if isfield(d, 'depends_on'); d = rmfield(d, 'depends_on'); end
d = jsondecode(jsonencode(d));
end

function d = writerModification()
% struct2doc('extraction_parameters_modification', settings, element, epoch,
% name): 'epochid.epochid', the two edges
d = did2.unittest.helpers.ndiDocument('spike_extraction_parameters_modification', ...
    'Id', '41268b6f5c6a3d4e_5e0000000000000b', 'Name', 'default');
d.app = newdocumentApp('ndi_app_spikeextractor');
d.spike_extraction_parameters_modification.threshold_parameter = -5;
d.epochid = struct('epochid', 't00003');
d = did2.unittest.helpers.setDependency(d, 'extraction_parameters_id', '41268b6f5c6a3d4e_5e0000000000000a');
d = did2.unittest.helpers.setDependency(d, 'element_id', '41268b6f5c6a3d4e_5e00000000000001');
d = jsondecode(jsonencode(d));
end

function d = writerSorting()
d = did2.unittest.helpers.ndiDocument('sorting_parameters', ...
    'Id', '41268b6f5c6a3d4e_5e0000000000000c', 'Name', 'klustakwik_default');
d.app = newdocumentApp('ndi_app_spikesorter');
if isfield(d, 'depends_on'); d = rmfield(d, 'depends_on'); end
d = jsondecode(jsonencode(d));
end

function d = convertedShape(d)
% the writer's document with no run environment (DID-side: what converts)
for f = {'os', 'os_version', 'interpreter', 'interpreter_version'}
    d.app.(f{1}) = '';
end
end

function d = writerCluster(sorter)
% ndi.document('<sorter>_clusters', 'app', app_struct, 'base.session_id',
% S.id(), '<sorter>_clusters.<sorter>_directory', [dir '/' elestr],
% '..curated_output_MD5_checksum', md5sum), then element_id
cls = [sorter '_clusters'];
d = did2.unittest.helpers.ndiDocument(cls, 'Id', ['41268b6f5c6a3d4e_5e00000000000' sprintf('%03d', numel(sorter))]);
if strcmp(sorter, 'kilosort')
    d.app = struct('name', 'Kilosort2.5 to phy to ndi.fun.probe.import.kilosort', ...
        'version', '2.5', 'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'GLNXA64', ...
        'os_version', '', 'interpreter', 'MATLAB', 'interpreter_version', '24.2.0.2712019 (R2024b)');
else
    d.app = struct('name', 'KIASORT to ndi.fun.probe.import.kiasort', 'version', '1.0', ...
        'url', 'https://github.com/VH-Lab/KIASORT', 'os', 'GLNXA64', 'os_version', '', ...
        'interpreter', 'MATLAB', 'interpreter_version', '24.2.0.2712019 (R2024b)');
end
d.(cls).([sorter '_directory']) = [sorter '/probe_a_1'];
d.(cls).curated_output_MD5_checksum = '0cc175b9c0f1b6a831c399e269772661';
d = did2.unittest.helpers.setDependency(d, 'element_id', '41268b6f5c6a3d4e_5e00000000000001');
d = jsondecode(jsonencode(d));
end

function d = sortingOutputs()
% the template with values in its three fields (no writer at the locked main)
d = did2.unittest.helpers.ndiDocument('SpikeInterfaceSortingOutputs', ...
    'Id', '41268b6f5c6a3d4e_5e0000000000000d');
d.SpikeInterfaceSortingOutputs = struct('sorter_name', 'kilosort4', 'sample_rate', 30000, 'unit', 'ms');
d = jsondecode(jsonencode(d));
end

% ===================== helpers =========================================

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end

function c = structs(docs)
c = cellfun(@(d) d.toStruct(), docs, 'UniformOutput', false);
end

function s = quarantineText(out)
s = strjoin(arrayfun(@(q) sprintf('%s|%s|%s', q.class_name, q.identifier, q.reason), ...
    out.quarantine, 'UniformOutput', false), '; ');
end
