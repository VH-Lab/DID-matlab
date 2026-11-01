function tests = testRawV1RoundTripIngested
%TESTRAWV1ROUNDTRIPINGESTED The ingested-epoch / sync family read as raw v1,
%   and its round trip: daqreader_mfdaq_epochdata_ingested,
%   epochfiles_ingested, syncrule_mapping and
%   daqmetadatareader_epochdata_ingested.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [migration reliability
%   practices] (a) (a round trip per class, did2.convert.roundtrip.check), and
%   [rename clashes are malformed] (what the deleted universalRenames would
%   have discarded is carried, carry-100). The test of the round trip is [lossless means round
%   trip].
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   daqreader_mfdaq_epochdata_ingested.json, daqreader_epochdata_ingested.json,
%   epochid.json, epochfiles_ingested.json, syncrule_mapping.json,
%   daqmetadatareader_epochdata_ingested.json, base.json) in the shapes their
%   writers give them, and pass through jsonencode/jsondecode as a corpus
%   delivers them:
%     mfdaq cache   +daq/+reader/mfdaq.m ingest_epochfiles: parameters 1e6 /
%                   1e7 (the writer, not the template's 1e6 / 1e6); epochtable
%                   {epochclock, t0_t1 2xN}; epochid; daqreader_id; the
%                   recording archives in files
%     manifest      +file/navigator.m: epoch_id, files ('epochid://...' first),
%                   epochprobemap (serialised), filenavigator_id; no files block
%     mapping       +time/syncgraph.m: cost, mapping, the two epochnodes of
%                   seven fields; syncgraph_id, syncrule_id; files with none
%     stimulus file +daq/metadatareader.m ingest_epochfiles: epochid,
%                   daqmetadatareader_id, data.bin; an empty block
%   These are the shapes of all 4,438 / 4,437 / 2,832 / 1,417 documents of the
%   corpora (Dab and Soph; census of the corpus zips, 2026-10-27).
%
%   Pass 1 converts the mfdaq cache (renamed to daqreader_epochdata_ingested),
%   passes the manifest through, and carries the mapping (carry-036) and the
%   stimulus file (carry-046). The mapping's fold is did2.convert.epochMint's;
%   its round trip is tested here on epochMint's output.
%
%   WHAT V2 DOES NOT KEEP would be listed per fixture as KNOWN FINDINGS; every
%   writer-shaped fixture here round trips with none.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the switch ======================================

function testAllFourClassesAreSwitched(testCase)
names = did2.convert.rawV1Classes();
for c = {'daqreader_mfdaq_epochdata_ingested', 'epochfiles_ingested', ...
        'syncrule_mapping', 'daqmetadatareader_epochdata_ingested'}
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
end
r = runRaw({writerMfdaq('mf_1', 1), writerManifest('efi_1', 't00001', 'nav_1', probemap('a')), ...
    writerMapping('map_1', identityNodes()), writerStimulusFile('sf_1')});
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, 4);
end

% ===================== the mfdaq cache: converted ========================

function testWriterMfdaqCachesConvertAndRoundTrip(testCase)
cases = {'one clock', writerMfdaq('mf_1', 1); 'two clocks', writerMfdaq('mf_2', 2)};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, not passed through']);
    doc = out.migrated{1};
    verifyEqual(testCase, char(doc.get('document_class.class_name')), ...
        'daqreader_epochdata_ingested', label);
    verifyEqual(testCase, char(doc.get('document_class.schema_version')), 'did_v2', label);
    verifyEqual(testCase, doc.get('daqreader_epochdata_ingested.parameters.sample_digital_segment'), ...
        1e7, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, findingsFor(label));
    accounted = [r.matched, r.not_set];
    for p = {'base.id', 'base.session_id', 'base.datestamp', 'base.name', ...
            'document_class.class_name', 'depends_on(1).name', 'depends_on(1).value', ...
            'epochid.epochid', 'daqreader_epochdata_ingested.epochtable.epochclock', ...
            'daqreader_epochdata_ingested.epochtable.t0_t1', ...
            'daqreader_mfdaq_epochdata_ingested.parameters.sample_analog_segment', ...
            'daqreader_mfdaq_epochdata_ingested.parameters.sample_digital_segment', ...
            'files.file_list', 'files.file_info(1).name'}
        verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
            sprintf('%s: %s is not accounted for', label, p{1}));
    end
end
end

function testTheMfdaqLiftRoundTrips(testCase)
% with an `epoch_id` edge (never on a v1 document; the parent's lift) the
% epochtable also becomes references, which restate it
v1 = writerMfdaq('mf_3', 2);
v1.depends_on = [v1.depends_on; struct('name', 'epoch_id', 'value', 'epochdoc_1')];
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyGreaterThan(testCase, numel(out.migrated), 1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r, 'mfdaq cache with its lift', {});
end

function testAnUnreadMfdaqFieldIsCarried(testCase)
% before the switch the migrator dropped a field of the mfdaq block other than
% `parameters` without a word; now it carries the document whole (no register
% row yet)
v1 = writerMfdaq('mf_4', 1);
v1.daqreader_mfdaq_epochdata_ingested.segment_format = 'nbf';
raw = runRaw(v1);
verifyEqual(testCase, numel(raw.passthrough), 1);
emitted = raw.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1');
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, contains(d, 'daqreader_mfdaq_epochdata_ingested.segment_format'), d);
verifyTrue(testCase, did2.convert.roundtrip.check(v1, raw.migrated).ok);
% the migrator runs on both paths now, so the renamed path carries it too
end

function testAMfdaqDependencyVersionIsCarriedOnBothPaths(testCase)
v1 = writerMfdaq('mf_5', 1);
v1.depends_on.version = 2;
v1 = jsondecode(jsonencode(v1));
raw = runRaw(v1);
verifyEqual(testCase, numel(raw.passthrough), 1, 'raw: carried');
d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-100] '), d);
emitted = raw.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
end

% ===================== the manifest: passed through ======================

function testWriterManifestsPassThroughAndRoundTrip(testCase)
cases = {'three files', writerManifest('efi_1', 't00001', 'nav_1', probemap('a')); ...
    'one file', writerManifest('efi_2', 'epoch_4126945aeeb60250_40b32508ea91cbb2', 'nav_2', probemap('b'), 1)};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
    verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), 'did_v2', label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, findingsFor(label));
end
end

function testAManifestEpochIdTwinIsCarriedOnBothPaths(testCase)
v1 = writerManifest('efi_3', 't00001', 'nav_1', probemap('a'));
v1.epochfiles_ingested.epochId = 't00002';
raw = runRaw(v1);
verifyEqual(testCase, numel(raw.passthrough), 1);
verifyEqual(testCase, char(raw.migrated{1}.get('document_class.schema_version')), 'did_v1');
end

% ===================== the mapping: carried, then folded =================

function testWriterMappingsAreCarriedAndRoundTrip(testCase)
cases = {'identity (Dab)', writerMapping('map_d', identityNodes()); ...
    'drift (Soph)', writerMapping('map_s', driftNodes(), [1.00000241750492, -4.33176506573082])};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    for path = {'raw'}
        out = runRaw(v1);
        verifyEmpty(testCase, out.quarantine, label);
        verifyEqual(testCase, numel(out.passthrough), 1, [label ', ' path{1} ': carried']);
        verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
            'did_v1', [label ', ' path{1}]);
    end
    out = runRaw(v1);
    emitted = out.migrated{1}.toStruct();
    emitted.document_class = rmfield(emitted.document_class, 'schema_version');
    verifyTrue(testCase, isequaln(emitted, v1), [label ': the carry is not the v1 source']);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-036] '), d);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
end
end

function testTheMappingFoldRoundTrips(testCase)
% epochMint folds the carried mapping into a clock_alignment between the two
% per-system references ([device clocks on one epoch] (3)); the mapping is
% rebuilt from the alignment and the documents its ends are tied to
for c = {'two epochs', 'one epoch, two systems'}
    [batch, mapping] = foldBatch(c{1});
    [out, rep] = did2.convert.epochMint(runRaw(batch), 'Validate', false, 'TargetVersion', 'did_v2');
    verifyEqual(testCase, rep.syncrule_folds_emitted, 1, c{1});
    docs = foldDocs(out);
    verifyNotEmpty(testCase, docs, c{1});
    r = did2.convert.roundtrip.check(mapping, docs);
    verifyFalse(testCase, r.carried, c{1});
    verifyRoundTrip(testCase, r, ['the fold, ' c{1}], {});
    for p = {'syncrule_mapping.cost', 'syncrule_mapping.mapping', ...
            'syncrule_mapping.epochnode_a.epoch_id', 'syncrule_mapping.epochnode_a.epoch_session_id', ...
            'syncrule_mapping.epochnode_a.epochprobemap', 'syncrule_mapping.epochnode_a.epoch_clock', ...
            'syncrule_mapping.epochnode_a.t0_t1', 'syncrule_mapping.epochnode_a.objectname', ...
            'syncrule_mapping.epochnode_a.objectclass', 'syncrule_mapping.epochnode_b.objectname', ...
            'depends_on(1).value', 'depends_on(2).value'}
        verifyTrue(testCase, any(strcmp(p{1}, r.matched)), sprintf('%s: %s not matched', c{1}, p{1}));
    end
end
end

function s = endsBlanked(doc)
s = doc.toStruct();
for k = 1:numel(s.depends_on)
    if any(strcmp(char(s.depends_on(k).name), {'input_id', 'output_id'}))
        s.depends_on(k).document_id = '';
    end
end
end

function testAFieldTheFoldDoesNotPlaceKeepsTheMappingCarried(testCase)
% unread by the fold: the mapping is not folded, it stays carried
breaks = {'base.name', @(m) setIn(m, {'base', 'name'}, 'a named mapping'); ...
    'an extra node field', @(m) setIn(m, {'syncrule_mapping', 'epochnode_a', 'note'}, 'x'); ...
    'another session', @(m) setIn(m, {'syncrule_mapping', 'epochnode_b', 'epoch_session_id'}, 'sess_other'); ...
    'a file', @(m) setIn(m, {'files', 'file_list'}, {'mapping.bin'})};
for k = 1:size(breaks, 1)
    [batch, mapping] = foldBatch('two epochs');
    batch{end} = jsondecode(jsonencode(breaks{k, 2}(mapping)));
    [out, rep] = did2.convert.epochMint(runRaw(batch), 'Validate', false, 'TargetVersion', 'did_v2');
    verifyEqual(testCase, rep.syncrule_folds_emitted, 0, breaks{k, 1});
    verifyEqual(testCase, rep.syncrule_refused_migrator_declined, 1, breaks{k, 1});
    verifyEmpty(testCase, ofClass(out, 'clock_alignment'), breaks{k, 1});
    verifyNumElements(testCase, ofClass(out, 'syncrule_mapping'), 1, breaks{k, 1});
end
end

% ===================== the stimulus file: carried ======================

function testWriterStimulusFilesAreCarriedAndRoundTrip(testCase)
v1 = writerStimulusFile('sf_2');
for path = {'raw'}
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, path{1});
    verifyEqual(testCase, numel(out.passthrough), 1, [path{1} ': carried']);
    verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), 'did_v1', path{1});
end
out = runRaw(v1);
emitted = out.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-046] '), d);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
verifyRoundTrip(testCase, r, 'stimulus file', {});
end

% ===================== the switch changes no outcome ======================

% ===================== the round trip can fail ===========================

function testAChangedValueIsReportedLost(testCase)
v1 = writerMfdaq('mf_6', 1);
out = runRaw(v1);
v1b = v1;
v1b.daqreader_epochdata_ingested.epochtable.t0_t1(2) = 1;
r = did2.convert.roundtrip.check(v1b, out.migrated);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'daqreader_epochdata_ingested.epochtable.t0_t1'});
end

function testAMissingOrExtraDocumentIsUnplaced(testCase)
[batch, mapping] = foldBatch('two epochs');
out = did2.convert.epochMint(runRaw(batch), 'Validate', false, 'TargetVersion', 'did_v2');
docs = foldDocs(out);
% without the epochs the ends' epoch ids cannot be read back
keep = cellfun(@(d) ~strcmp(did2.unittest.helpers.classKey(d), 'epoch'), docs);
r = did2.convert.roundtrip.check(mapping, docs(keep));
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
% a document with no role in the mapping
r = did2.convert.roundtrip.check(mapping, [docs, runRaw(writerStimulusFile('sf_9')).migrated]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
% the mfdaq cache with a stray document
mf = writerMfdaq('mf_7', 1);
r = did2.convert.roundtrip.check(mf, [runRaw(mf).migrated, runRaw(writerManifest('efi_9', 't1', 'n', 'x')).migrated]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

function testTheStimulusFileInverseRefusesAConversion(testCase)
% pass 1 never converts it, so anything handed to its inverse is unplaced
v1 = writerStimulusFile('sf_3');
fake = runRaw(writerManifest('efi_8', 't00001', 'nav_1', probemap('a'))).migrated;
r = did2.convert.roundtrip.check(v1, fake);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== known findings ===================================

function f = knownFindings()
% {fixture, path, why}: none. Every writer-shaped fixture round trips.
f = cell(0, 3);
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end

function verifyRoundTrip(testCase, r, label, expectedLost)
verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
lost = reshape(sort({r.lost.path}), 1, []);
verifyEqual(testCase, lost, reshape(sort(expectedLost), 1, []), ...
    sprintf('%s: lost paths are not the listed findings; lost: %s', label, describeLost(r)));
verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end

function s = describeLost(r)
parts = cell(1, numel(r.lost));
for k = 1:numel(r.lost)
    parts{k} = sprintf('%s (v1 %s, rebuilt %s)', r.lost(k).path, ...
        show(r.lost(k).v1), show(r.lost(k).rebuilt));
end
s = strjoin(parts, '; ');
if isempty(s); s = '(none)'; end
end

function s = show(v)
try
    s = jsonencode(v);
catch
    s = class(v);
end
end

function m = edgeMap(b)
% name -> id, whichever key holds it
m = struct();
if ~isfield(b, 'depends_on'); return; end
d = b.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    e = d{k};
    v = '';
    for key = {'document_id', 'value', 'id'}
        if isfield(e, key{1}) && ~isempty(e.(key{1}))
            v = char(e.(key{1}));
            break;
        end
    end
    m.(matlab.lang.makeValidName(char(e.name))) = v;
end
end

function docs = ofClass(out, className)
docs = {};
for k = 1:numel(out.migrated)
    if strcmp(char(did2.unittest.helpers.classKey(out.migrated{k})), className)
        docs{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
end

function doc = docWithId(out, id)
doc = [];
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), id)
        doc = out.migrated{k};
        return;
    end
end
end

function ids = edgesOf(doc, name)
ids = {};
deps = doc.get('depends_on');
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    e = deps{k};
    if ~strcmp(char(e.name), name); continue; end
    for key = {'document_id', 'value', 'id'}
        if isfield(e, key{1}) && ~isempty(e.(key{1}))
            ids{end+1} = char(e.(key{1})); %#ok<AGROW>
            break;
        end
    end
end
end

function docs = foldDocs(out)
%FOLDDOCS The clock_alignment and the documents its ends are read back from:
%   its two references, the epochs holding them, the acquisition systems they
%   are on, those systems' software, and the manifests.
docs = {};
align = ofClass(out, 'clock_alignment');
if isempty(align); return; end
docs = align(1);
refIds = [edgesOf(align{1}, 'input_id'), edgesOf(align{1}, 'output_id')];
sysIds = {};
for k = 1:numel(refIds)
    ref = docWithId(out, refIds{k});
    if isempty(ref); continue; end
    docs{end+1} = ref; %#ok<AGROW>
    sysIds = [sysIds, edgesOf(ref, 'referent_id')]; %#ok<AGROW>
end
for e = ofClass(out, 'epoch')
    if any(ismember(edgesOf(e{1}, 'time_reference_id'), refIds))
        docs{end+1} = e{1}; %#ok<AGROW>
    end
end
sysIds = unique(sysIds, 'stable');
for k = 1:numel(sysIds)
    sys = docWithId(out, sysIds{k});
    if isempty(sys); continue; end
    docs{end+1} = sys; %#ok<AGROW>
    for sw = edgesOf(sys, 'software_id')
        s = docWithId(out, sw{1});
        if ~isempty(s) && ~any(cellfun(@(d) strcmp(char(d.get('base.id')), sw{1}), docs))
            docs{end+1} = s; %#ok<AGROW>
        end
    end
end
docs = [docs, ofClass(out, 'epochfiles_ingested')];
end

function s = setIn(s, path, value)
s = setfield(s, path{:}, value); %#ok<SFLD>
end

% ===================== fixtures, from the WRITERS =========================

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end

function b = writerBase(id)
tpl = loadTemplate('base');
b = tpl.base;
b.id = id;
b.session_id = 'sess_0001';
b.datestamp = '2025-05-27T15:47:23.738Z';
end

function v1 = writerMfdaq(id, nClocks)
% +daq/+reader/mfdaq.m ingest_epochfiles: ndi.document(...) merges the
% template with its superclasses (base, epochid, daqreader_epochdata_ingested,
% in that order on every corpus document), then sets the three blocks, the
% daqreader_id edge, and attaches the channel list and the segment files
tpl = loadTemplate('daqreader_mfdaq_epochdata_ingested');
v1 = struct();
v1.document_class = tpl.document_class;
v1.document_class.superclasses = struct('definition', { ...
    '$NDIDOCUMENTPATH/base.json', '$NDIDOCUMENTPATH/epochid.json', ...
    '$NDIDOCUMENTPATH/ingestion/daqreader_epochdata_ingested.json'});
v1.depends_on = struct('name', 'daqreader_id', 'value', 'rdr_vhintan');
v1.base = writerBase(id);
v1.epochid = struct('epochid', 't00003');
clocks = {'dev_local_time', 'exp_global_time'};
t0t1 = [0 739000.5; 863.17431 739000.51];
v1.daqreader_epochdata_ingested = struct('epochtable', struct( ...
    'epochclock', {clocks(1:nClocks)}, 't0_t1', t0t1(:, 1:nClocks)));
v1.daqreader_mfdaq_epochdata_ingested = struct('parameters', struct( ...
    'sample_analog_segment', 1e6, 'sample_digital_segment', 1e7));
loc = @(uid) struct('delete_original', 0, 'uid', uid, ...
    'location', ['ndic://66140c237dbc358954ddffb9/' uid], 'parameters', '', ...
    'location_type', 'ndicloud', 'ingest', 0);
v1.files = struct('file_list', {tpl.files.file_list}, 'file_info', struct( ...
    'name', {'channel_list.bin', 'ai_group1_seg.nbf_1'}, ...
    'locations', {loc('4126900e087c50b9_c0d1467da3eb9532'), loc('4126900e087c50b9_c0d1467da3eb9533')}));
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerManifest(id, epochId, navId, pm, nFiles)
% +file/navigator.m: epoch_id, files ('epochid://' first), the serialised
% probe map, the filenavigator_id edge; the template declares no files block
if nargin < 5; nFiles = 3; end
tpl = loadTemplate('epochfiles_ingested');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = struct('name', 'filenavigator_id', 'value', navId);
v1.base = writerBase(id);
files = {['epochid://' epochId], ['/data/' epochId '/experiment002trial006.mat'], ...
    ['/data/' epochId '/experiment002trial006.epochprobemap.txt']};
v1.epochfiles_ingested = struct('epoch_id', epochId, 'files', {files(1:nFiles)}, ...
    'epochprobemap', pm);
v1 = jsondecode(jsonencode(v1));
end

function pm = probemap(which)
switch which
    case 'a'
        pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\nRightcortex\t1\tn-trode\tvhtaste_sync:ai1-32\tferret_385.1618@vhlab.org\n');
    otherwise
        pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\nvhvis_spike2\t1\tstimulator\tvhtaste_bpod:mk1\tferret_385.1618@vhlab.org\n');
end
end

function nodes = identityNodes()
nodes = {node('t00001', 'vhtaste_sync', probemap('a'), [0 479.692213]), ...
    node('t00002', 'vhtaste_bpod', probemap('b'), [0 479.7])};
end

function nodes = driftNodes()
nodes = {node('t00001', 'vhtaste_sync', probemap('a'), [0 4429.871950000001]), ...
    node('t00001', 'vhtaste_bpod', probemap('b'), [0 4429.86])};
end

function n = node(epochId, objectName, pm, t0t1)
% syncgraph.m: the seven epoch_node_fields, the probe map serialised and the
% clock as its char
n = struct('epoch_id', epochId, 'epoch_session_id', 'sess_0001', ...
    'epochprobemap', pm, 'epoch_clock', 'dev_local_time', 't0_t1', t0t1, ...
    'objectname', objectName, 'objectclass', 'ndi.daq.system.mfdaq');
end

function v1 = writerMapping(id, nodes, mapping)
% +time/syncgraph.m ingest: cost, mapping, the two nodes; the two edges; the
% files block ndi.document gives a template that declares one, with no file
if nargin < 3; mapping = [1 0]; end
tpl = loadTemplate('syncrule_mapping');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = struct('name', {'syncgraph_id', 'syncrule_id'}, ...
    'value', {'graph_0001', 'rule_ctoe'});
v1.base = writerBase(id);
v1.files = struct('file_list', {{}}, 'file_info', {{}});
v1.syncrule_mapping = struct('cost', 1, 'mapping', mapping, ...
    'epochnode_a', nodes{1}, 'epochnode_b', nodes{2});
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerStimulusFile(id)
% +daq/metadatareader.m ingest_epochfiles: the epochid block, the
% daqmetadatareader_id edge, data.bin; the template's block is empty
tpl = loadTemplate('daqmetadatareader_epochdata_ingested');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = struct('name', 'daqmetadatareader_id', 'value', 'mdr_1');
v1.base = writerBase(id);
v1.daqmetadatareader_epochdata_ingested = struct();
v1.epochid = struct('epochid', 't00001');
v1.files = struct('file_list', {{'data.bin'}}, 'file_info', struct('name', 'data.bin', ...
    'locations', struct('delete_original', 0, 'uid', '4126936f64faca84_c0d3f57ec1fd3843', ...
    'location', 'ndic://68839b1fbf243809c0800a01/4126936f64faca84_c0d3f57ec1fd3843', ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0)));
v1 = jsondecode(jsonencode(v1));
end

function [batch, mapping] = foldBatch(kind)
%FOLDBATCH A session, the two acquisition systems the mapping's ends name, the
%   manifests of their epochs (each read by its system's navigator, with the
%   endpoint's own probe map), and the writer-shaped mapping. 'two epochs':
%   t00001 / t00002 (identity); 'one epoch, two systems': both ends on t00001
%   (Soph's shape, a drifting clock).
if strcmp(kind, 'two epochs')
    mapping = writerMapping('map_0001', identityNodes());
    e2 = 't00002';
else
    mapping = writerMapping('map_0001', driftNodes(), [1.00000241750492, -4.33176506573082]);
    e2 = 't00001';
end
batch = {sessionBody('sd_A', 'sess_0001', 'exp1'), daqsystemBody('sync'), daqsystemBody('bpod'), ...
    writerManifest('efi_1', 't00001', 'nav_sync', probemap('a')), ...
    writerManifest('efi_2', e2, 'nav_bpod', probemap('b')), mapping};
end

function v1 = daqsystemBody(rig)
% as testEpochMintSyncruleArming: a daqsystem named vhtaste_<RIG> (base.id
% daq_<RIG>, preserved onto its acquisition_system), its navigator nav_<RIG>
v1 = struct();
v1.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', ['daq_' rig], 'session_id', 'sess_0001', ...
    'name', ['vhtaste_' rig], 'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
v1.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'id', {['nav_' rig], ['rdr_' rig]});
end

function v1 = sessionBody(docId, sessionId, reference)
% as testEpochMint: a did_v1 `session` document
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/session.json', ...
    'validation',         '$NDISCHEMAPATH/session.json', ...
    'class_name',         'session', ...
    'property_list_name', 'session', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', reference);
end
