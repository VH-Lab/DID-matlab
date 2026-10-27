function tests = testRawV1RoundTripPyraview
%TESTRAWV1ROUNDTRIPPYRAVIEW pyraview read as raw v1, and its round trip.
%
%   The decisions it serves (Jess Haley, 2026-10-26, did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary], [fields outside
%   the template are malformed] (2026-10-27, carry-100).
%
%   THE TEMPLATES are NDI-matlab's at the locked `main` (3cb19a8), copied
%   verbatim to tests/+did2/fixtures/ndi_templates: data/pyraview.json (as
%   pyraview.json), its superclasses epochclocktimes.json and data/filter.json
%   (as filter.json), and their epochid.json and base.json.
%
%   THE v1 DOCUMENTS ARE THE WRITER'S. +ndi/+gui/+app/+pyraview/
%   makePyraviewDoc.m (PROBE, EPOCHID, FILTERBAND) at the same commit:
%   ndi.document('pyraview', 'pyraview', <block>, 'epochid', ..., 'filter',
%   <filterData.m's struct>, 'epochclocktimes', {'dev_local_time', [t0; t1]})
%   + session.newdocument(), element_id the probe, then add_file for the seven
%   decimation levels (steps [100 10 10 10 10 10 10]); the template's own
%   file_list names level1..level10.bin. The values are corpus PRED's one
%   pyraview (20 kHz, 16 channels, 0 to 28.12495 s, 'high').
%
%   WHAT HAPPENS TO THEM. The writer always names an epoch, so pass 1 DEFERS
%   every one (did2:convert:needsEpochContext), on both paths; it is not
%   accounted for in pass 1 beyond the raw read, which carries a document with
%   a field outside its templates BEFORE deferring it. did2.convert.epochMint
%   (resolveDeferredPyraviews) stamps the `epoch_id` edge on the quarantined
%   source -- the raw v1 document (testTheEpochStepReRunsTheRawSource) -- and
%   runs v1_to_v2 again. The round trip is of THAT output, with the epoch
%   entity epochMint mints. The 'all' band carries there instead
%   (carry-007: the writer's label 'all' differs from its type 'none').
%
%   KNOWN FINDINGS: none. files.file_info was one until [pyraview level keeps
%   its file info] (Jess Haley, 2026-10-27): each level body now carries the
%   v1 file_info entry of its own file name (uid, location, location_type,
%   ingest, delete_original), and the round trip rebuilds file_info from the
%   bodies (testEachLevelKeepsItsFileInfo). Nothing is lost, invented or
%   unplaced.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the switch ======================================

function testTheSwitchListsPyraview(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'pyraview')));
% the v1 spelling is the migrator's: no row in the spelling table
verifyEqual(testCase, did2.convert.rawV1Classes('pyraview'), 'pyraview');
end

function testPassOneDefersTheWritersDocument(testCase)
for b = bands()
    v1 = writerShape(b{1});
    out = runRaw(v1);
    verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1, b{1});
    verifyEmpty(testCase, out.migrated, b{1});
    assertEqual(testCase, numel(out.quarantine), 1, b{1});
    verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:needsEpochContext', b{1});
end
end

function testTheEpochStepReRunsTheRawSource(testCase)
% resolveDeferredPyraviews re-runs jsondecode(quarantine.original_body) with
% epoch_id stamped: that is the v1 document as pass 1 received it, in v1's own
% spelling, so the re-run reads raw v1
v1 = writerShape('high');
out = runRaw(v1);
assertEqual(testCase, numel(out.quarantine), 1);
src = jsondecode(out.quarantine(1).original_body);
verifyTrue(testCase, isfield(src.pyraview, 'nativeRate'), 'the deferred source is not v1''s spelling');
verifyFalse(testCase, isfield(src.pyraview, 'native_rate'));
verifyTrue(testCase, isfield(src.epochclocktimes, 't0_t1'), 'the deferred source was reshaped');
verifyTrue(testCase, isfield(src.filter, 'type'));
verifyFalse(testCase, isfield(src.filter, 'filter_type'));
end

function testWriterShapesRoundTrip(testCase)
for b = {'high', 'low'}
    v1 = writerShape(b{1});
    out = runRaw(stamped(v1));
    verifyEmpty(testCase, out.quarantine, b{1});
    verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1, b{1});
    r = did2.convert.roundtrip.check(v1, [out.migrated, {epochEntity(v1)}]);
    verifyFalse(testCase, r.carried, b{1});
    % nothing is an expected loss: file_info used to be (fileInfoPaths), and
    % must now come back whole
    did2.unittest.helpers.verifyRoundTrip(testCase, r, b{1}, {});
    for p = fileInfoPaths(v1)
        verifyTrue(testCase, any(strcmp(r.matched, p{1})), ...
            sprintf('%s: %s did not come back', b{1}, p{1}));
    end
end
% the writer's all-pass is carried where epochMint re-runs it, as the source
% that re-run was handed (the v1 document with its epoch_id edge)
s = stamped(writerShape('all'));
out = runRaw(s);
verifyEmpty(testCase, out.quarantine);
r = did2.convert.roundtrip.check(s, out.migrated);
verifyTrue(testCase, r.carried, 'all: carried?');
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'all', {});
end

function testEachLevelKeepsItsFileInfo(testCase)
% [pyraview level keeps its file info] (Jess Haley, 2026-10-27): the level body
% of file levelK.bin carries the v1 files.file_info entry named levelK.bin,
% unchanged; a level the writer attached nothing to carries none
v1 = writerShape('high');
out = runRaw(stamped(v1));
assertEmpty(testCase, out.quarantine);
fi = v1.files.file_info;
nWithInfo = 0;
nLevels = 0;
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if ~strcmp(b.document_class.class_name, 'sampled_body'); continue; end
    nLevels = nLevels + 1;
    name = b.files.file_list;
    if iscell(name); name = name{1}; end
    hit = find(strcmp({fi.name}, name));
    if isempty(hit)
        verifyFalse(testCase, isfield(b.files, 'file_info'), ...
            sprintf('%s: file_info on a level nothing was attached to', name));
        continue;
    end
    nWithInfo = nWithInfo + 1;
    assertTrue(testCase, isfield(b.files, 'file_info'), sprintf('%s: no file_info', name));
    verifyEqual(testCase, b.files.file_info.name, fi(hit).name);
    verifyEqual(testCase, b.files.file_info.locations.uid, fi(hit).locations.uid, name);
    verifyEqual(testCase, b.files.file_info.locations.location, ...
        fi(hit).locations.location, name);
end
verifyEqual(testCase, nLevels, numel(v1.files.file_list), 'one level body per file_list name');
verifyEqual(testCase, nWithInfo, numel(fi), 'every file_info entry is on its level');
end

function testTheSwitchChangesNoOutcome(testCase)
for b = bands()
    v1 = writerShape(b{1});
    % pass 1 (both defer) and epochMint's re-run (both fold, or both carry)
    for batch = {{v1}, {stamped(v1)}}
        [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(batch{1});
        verifyEmpty(testCase, problems, sprintf('%s: %s', b{1}, strjoin(problems, '; ')));
    end
end
end

function testTheCarriesNameTheirReason(testCase)
v1 = writerShape('high');
v1.pyraview.gain = 2;
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: pyraview.gain');
v1 = did2.unittest.helpers.setDependency(writerShape('high'), 'probe_id', 'p_1');
verifyCarried(testCase, v1, 'depends_on(probe_id)');
v1 = writerShape('high');
v1.extra_block = struct('x', 1);
verifyCarried(testCase, v1, 'extra_block');
% the writer's all-pass, where epochMint re-runs it
verifyCarried(testCase, stamped(writerShape('all')), '[carry-007] filter.label "all"');
end

function testAnUnknownFilterParameterIsMalformed(testCase)
% Decided by Jess Haley, 2026-10-27 [unknown filter parameter is malformed]:
% `filter.parameters` is open in the template, and a key there that
% private/jFrequencyFilter does not read carries the document whole as v1,
% carry-100, through jRawCarry -- for a designed filter and for the all-pass
% alike, and before the epoch deferral (pass 1 stores the untouched source)
for b = bands()
    v1 = writerShape(b{1});
    v1.filter.parameters.transitionWidth = 50;
    verifyCarried(testCase, v1, ...
        '[carry-100] malformed: outside the NDI template, unplaced: filter.parameters.transitionWidth');
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, [b{1} ': deferred instead of carried']);
    assertEqual(testCase, numel(out.migrated), 1, b{1});
    verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
        'did_v1', b{1});
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried, b{1});
    did2.unittest.helpers.verifyRoundTrip(testCase, r, b{1}, {});
end
% an EMPTY unknown key is a key all the same ("holds a key")
v1 = writerShape('high');
v1.filter.parameters.transitionWidth = [];
verifyCarried(testCase, v1, 'filter.parameters.transitionWidth');
end

function testACarryIsDecidedBeforeTheDeferral(testCase)
% a document carried for a field outside its templates is the untouched v1
% source, stored in pass 1; it never waits in the quarantine to be re-run with
% an epoch_id edge it did not have
v1 = writerShape('high');
v1.pyraview.gain = 2;
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), 'did_v1');
end

function testTheConvertedDocumentsValidate(testCase)
for b = {'high', 'low'}
    out = did2.convert.v1_to_v2({stamped(writerShape(b{1}))}, 'Validate', true, ...
        'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine, b{1});
    verifyGreaterThan(testCase, numel(out.migrated), 2, b{1});
end
end

function testADifferentSourceIsReportedLost(testCase)
v1 = writerShape('high');
out = runRaw(stamped(v1));
v1.pyraview.channels = v1.pyraview.channels + 1;
v1.epochclocktimes.t0_t1(2) = v1.epochclocktimes.t0_t1(2) + 1;
r = did2.convert.roundtrip.check(v1, [out.migrated, {epochEntity(v1)}]);
verifyFalse(testCase, r.ok);
lost = {r.lost.path};
verifyTrue(testCase, any(strcmp(lost, 'pyraview.channels')));
verifyTrue(testCase, any(strcmp(lost, 'epochclocktimes.t0_t1')));
end

% ===================== fixtures =========================================

function b = bands()
b = {'high', 'low', 'all'};
end

function d = writerShape(band)
% makePyraviewDoc(probe, 'EST_VISUAL_PREDROGA', BAND) on PRED's probe
sr = 20000;
t0 = 0;
t1 = 28.12495;
steps = [100 10 10 10 10 10 10];
d = did2.unittest.helpers.ndiDocument('pyraview', ...
    'Id', '41269628e2d51bf1_40a0cb9f87794ccb', ...
    'SessionId', '41269628e23756b9_c0d504560ca6769c', ...
    'Datestamp', '2026-05-14T14:37:57.977Z');
d.epochid = struct('epochid', 'EST_VISUAL_PREDROGA');
d.pyraview = struct('label', band, 'nativeRate', sr, 'nativeStartTime', t0, ...
    'channels', 16, 'dataType', 'double', 'decimationLevels', steps, ...
    'decimationSamplingRates', sr ./ cumprod(steps), ...
    'decimationStartTimes', t0 * ones(numel(steps), 1));
d.filter = filterData(sr, band);
d.epochclocktimes = struct('clocktype', 'dev_local_time', 't0_t1', [t0; t1]);
d = did2.unittest.helpers.setDependency(d, 'element_id', '41269628e2a03088_c085f412b5d8c08d');
% add_file, one per decimation level
info = struct('name', {}, 'locations', {});
for i = 1:numel(steps)
    info(i) = struct('name', sprintf('level%d.bin', i), 'locations', struct( ...
        'delete_original', 1, 'uid', sprintf('41269628e2d51ffe_40dc0fd6725017e%d', i), ...
        'location', sprintf('/tmp/tp88ff8093/pyraview_tpd8415b93_L%d.bin', i), ...
        'parameters', '', 'location_type', 'file', 'ingest', 1));
end
d.files.file_info = info;
d = jsondecode(jsonencode(d, 'ConvertInfAndNaN', false));
end

function f = filterData(sr, band)
% filterData.m's filterStruct for BAND
f = struct('label', band);
if strcmp(band, 'all')
    f.type = 'none';
    f.algorithm = 'none';
    f.parameters = struct('sampleFrequency', sr, 'order', NaN, ...
        'filterFrequency', NaN, 'passBandRipple', NaN, 'stopbandAttentuation', NaN);
    return;
end
f.type = band;
f.algorithm = 'chebyshev_1';
f.parameters = struct('sampleFrequency', sr, 'order', 4, ...
    'filterFrequency', 300, 'passBandRipple', 0.8, 'stopbandAttentuation', NaN);
end

function s = stamped(v1)
% what resolveDeferredPyraviews hands v1_to_v2: the source with epoch_id
s = did2.unittest.helpers.setDependency(v1, 'epoch_id', epochId());
end

function id = epochId()
id = '41269628e23756b9_e00000000000e0c1';
end

function e = epochEntity(v1)
% the epoch epochMint mints for (session, epoch string) (its mintEpoch)
epochType = did2.convert.registeredTerm( ...
    did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch');
e = did2.build.document('entity', ...
    struct('type', epochType, 'local_identifier', v1.epochid.epochid), ...
    'Id', epochId(), 'SessionId', v1.base.session_id, ...
    'CreationTimestamp', v1.base.datestamp, 'Validate', false);
end

function p = fileInfoPaths(v1)
% every non-empty leaf of files.file_info (the known finding)
p = {};
fi = v1.files.file_info;
for k = 1:numel(fi)
    p{end+1} = sprintf('files.file_info(%d).name', k); %#ok<AGROW>
    for f = {'delete_original', 'uid', 'location', 'location_type', 'ingest'}
        p{end+1} = sprintf('files.file_info(%d).locations.%s', k, f{1}); %#ok<AGROW>
    end
end
end

% ===================== helpers =========================================

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('pyraview (%s)', part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
