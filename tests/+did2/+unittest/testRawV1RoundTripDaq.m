function tests = testRawV1RoundTripDaq
%TESTRAWV1ROUNDTRIPDAQ The acquisition-system family read as raw v1, and its
%   round trip: daqsystem, filenavigator, daqreader, daqreader_ndr,
%   daqmetadatareader, syncrule, syncgraph and probe_location.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [migration reliability
%   practices] (a) (a round trip per class, did2.convert.roundtrip.check), and
%   [renames carry is temporary] (what universalRenames would discard is still
%   carried, carry-049). The test of the round trip is [lossless means round
%   trip].
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   daqsystem.json, filenavigator.json, daqreader.json, daqreader_ndr.json,
%   daqmetadatareader.json, syncrule.json, syncgraph.json, probe_location.json,
%   base.json) in the shapes their WRITERS give them (the writer wins over the
%   template), and pass through jsonencode/jsondecode as a corpus delivers
%   them:
%     daqsystem          +daq/system.m newdocument: base.name the system's
%                        name; filenavigator_id, daqreader_id, the template's
%                        own empty daqmetadatareader_id, then
%                        add_dependency_value_n's daqmetadatareader_id_1..N
%     filenavigator      +file/navigator.m newdocument: the class, the two
%                        cell2str pattern lists, the probe-map class
%     daqreader          +daq/reader.m newdocument: the class; the session is
%                        ndi.session.empty_id() (the corpora hold a real one)
%     daqreader_ndr      +daq/+reader/+mfdaq/ndr.m newdocument: the daqreader
%                        class, the NDR reader string, the NDR class (equal)
%     daqmetadatareader  +daq/metadatareader.m newdocument: the class and the
%                        tab-separated file parameter
%     syncrule           +time/syncrule.m newdocument, for filematch.m,
%                        filefind.m and commonTriggersOverlappingEpochs.m
%     syncgraph          +time/syncgraph.m newdocument: the class, and
%                        add_dependency_value_n's syncrule_id_1..N
%     probe_location     +setup/+conv/+dabrowska/doImport.m and
%                        +fun/+doc/+probe/probeLocations4probes.m: the term,
%                        probe_id, the session's newdocument (base.name '')
%   These are the shapes of all 139 / 139 / 138 / 1 / 46 / 92 / 46 / 528
%   documents of the four corpus zips (20211116, Dab, JH, Soph; survey of the
%   zips, 2026-10-27), with their values.
%
%   WHAT V2 DOES NOT KEEP is listed per fixture as KNOWN FINDINGS (knownFindings
%   below): every writer-shaped fixture but one round trips with none (the
%   Dabrowska probe location's label, below); the other findings are shapes no
%   NDI writer at the locked `main` makes, kept here so that the round trip is
%   seen to report them.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the switch ======================================

function testAllEightClassesAreSwitched(testCase)
names = did2.convert.rawV1Classes();
for c = familyClasses()
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
    verifyEqual(testCase, did2.convert.rawV1Classes(c{1}), c{1}, ...
        [c{1} ': the migrator is the v1 name']);
end
f = writerFixtures();
r = runRaw(f(:, 2)');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, size(f, 1));
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

% ===================== every writer shape round trips =====================

function testWriterShapesRoundTrip(testCase)
f = writerFixtures();
for k = 1:size(f, 1)
    [label, v1, outcome] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    switch outcome
        case 'converted'
            verifyEmpty(testCase, out.passthrough, [label ': converted, not passed through']);
            verifyGreaterThan(testCase, numel(out.migrated), 1, [label ': the document and its parts']);
        case 'passthrough'
            verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
            verifyEqual(testCase, numel(out.migrated), 1, label);
            verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
                'did_v2', [label ': a passthrough is not a carry']);
    end
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, findingsFor(label));
end
end

function testEveryTemplateFieldIsAccountedFor(testCase)
% by name, on the converted writer shapes: each field NDI's template declares
cases = {'daqsystem, one metadata reader', {'base.id', 'base.session_id', 'base.name', ...
        'base.datestamp', 'document_class.class_name', 'daqsystem.ndi_daqsystem_class', ...
        'depends_on(1).name', 'depends_on(1).value', 'depends_on(2).value', ...
        'depends_on(3).name', 'depends_on(4).name', 'depends_on(4).value'}; ...
    'filenavigator, epochdir', {'filenavigator.ndi_filenavigator_class', ...
        'filenavigator.fileparameters', 'filenavigator.epochprobemap_class', ...
        'filenavigator.epochprobemap_fileparameters', 'base.name'}; ...
    'daqreader, empty session', {'daqreader.ndi_daqreader_class', 'base.session_id'}; ...
    'daqreader_ndr', {'daqreader.ndi_daqreader_class', 'daqreader_ndr.ndr_reader_string', ...
        'daqreader_ndr.ndi_daqreader_ndr_class'}; ...
    'daqmetadatareader', {'daqmetadatareader.ndi_daqmetadatareader_class', ...
        'daqmetadatareader.tab_separated_file_parameter'}; ...
    'syncrule, filematch', {'syncrule.ndi_syncrule_class', ...
        'syncrule.parameters.number_fullpath_matches'}; ...
    'syncgraph, two rules', {'syncgraph.ndi_syncgraph_class', 'depends_on(1).name', ...
        'depends_on(1).value', 'depends_on(2).name', 'depends_on(2).value'}; ...
    'probe_location, Dabrowska', {'probe_location.ontology_name', 'probe_location.name', ...
        'depends_on(1).name', 'depends_on(1).value', 'base.session_id'}};
f = writerFixtures();
for k = 1:size(cases, 1)
    v1 = f{strcmp(f(:, 1), cases{k, 1}), 2};
    r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
    % a listed known finding is accounted for: the round trip reports it
    accounted = [r.matched, r.not_set, r.restated, r.equivalent, findingsFor(cases{k, 1})];
    for p = cases{k, 2}
        verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
            sprintf('%s: %s is not accounted for', cases{k, 1}, p{1}));
    end
end
end

function testTheFilefindFoldRoundTrips(testCase)
% pass 1 passes a filefind rule through; did2.convert.resolveClockAlignment
% resolves its two system NAMES to the migrated acquisition systems and re-runs
% the migrator: a configuration linking the two systems (from, to) and its
% software. The rule is rebuilt from those and the two systems.
for path = {'raw', 'renamed'}
    [batch, rule] = filefindBatch();
    if strcmp(path{1}, 'raw'); out = runRaw(batch); else; out = runRenamed(batch); end
    out = did2.convert.resolveClockAlignment(out, 'Validate', false, 'TargetVersion', 'V_eta');
    verifyEqual(testCase, out.clock_alignment_fold.syncrule_configurations_folded, 1, path{1});
    docs = foldDocs(out, rule.base.id);
    verifyNotEmpty(testCase, docs, path{1});
    r = did2.convert.roundtrip.check(rule, docs);
    verifyFalse(testCase, r.carried, path{1});
    verifyRoundTrip(testCase, r, ['the filefind fold, ' path{1}], {});
    for p = {'syncrule.parameters.daqsystem1', 'syncrule.parameters.daqsystem2', ...
            'syncrule.parameters.syncfilename', 'syncrule.parameters.number_fullpath_matches'}
        verifyTrue(testCase, any(strcmp(p{1}, r.matched)), sprintf('%s: %s not matched', path{1}, p{1}));
    end
end
end

function testTheChannelRuleFoldRoundTrips(testCase)
% a commonTriggersOverlappingEpochs rule: its systems are the from / to edges
% (daqsystem1_name, daqsystem2_name), its trigger channels and errorOnFailure
% method parameters; the v1 rule rebuilds exactly
for path = {'raw', 'renamed'}
    rule = channelRule();
    batch = {writerDaqsystem('vhtaste_sync', {}), writerDaqsystem('vhtaste_bpod', {'mdr_1'}), rule};
    if strcmp(path{1}, 'raw'); out = runRaw(batch); else; out = runRenamed(batch); end
    out = did2.convert.resolveClockAlignment(out, 'Validate', false, 'TargetVersion', 'V_eta');
    verifyEqual(testCase, out.clock_alignment_fold.syncrule_configurations_folded, 1, path{1});
    docs = foldDocs(out, rule.base.id);
    verifyNotEmpty(testCase, docs, path{1});
    r = did2.convert.roundtrip.check(rule, docs);
    verifyFalse(testCase, r.carried, path{1});
    verifyRoundTrip(testCase, r, ['the channel rule fold, ' path{1}], {});
    for p = {'syncrule.parameters.daqsystem1_name', 'syncrule.parameters.daqsystem2_name', ...
            'syncrule.parameters.daqsystem_ch1', 'syncrule.parameters.daqsystem_ch2', ...
            'syncrule.parameters.epochclocktype', 'syncrule.parameters.minEmbeddedFileOverlap', ...
            'syncrule.parameters.errorOnFailure'}
        verifyTrue(testCase, any(strcmp(p{1}, r.matched)), sprintf('%s: %s not matched', path{1}, p{1}));
    end
end
end

% ===================== the switch changes no outcome ======================

function testTheSwitchChangesNoOutcome(testCase)
% a converted document is the one the renamed path converted; a passthrough is
% the same document but for v1's `value` edge key; a carry is carried on both
f = writerFixtures();
for k = 1:size(f, 1)
    [label, v1] = f{k, 1:2};
    raw = runRaw(v1);
    old = runRenamed(v1);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), label);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        a = raw.migrated{j}.toStruct();
        b = old.migrated{j}.toStruct();
        if ~isempty(raw.passthrough)
            verifyEqual(testCase, edgeMap(a), edgeMap(b), label);
            a = rmfieldIf(a, 'depends_on');
            b = rmfieldIf(b, 'depends_on');
        end
        verifyTrue(testCase, isequaln(a, b), sprintf('%s, document %d: raw %s; renamed %s', ...
            label, j, jsonencode(a), jsonencode(b)));
    end
end
end

% ===================== what the migrator does not read is carried =========

function testAnUnreadFieldIsCarried(testCase)
% before the switch a field or edge the migrator does not read was dropped
% without a word on the renamed path; now the document is carried whole, as
% the untouched v1 source, with an `unplaced:` note naming it (no register row
% yet: a question for the team)
breaks = { ...
    'daqsystem, one metadata reader', 'daqsystem.ndi_daqsystem_version', ...
        @(v) setIn(v, {'daqsystem', 'ndi_daqsystem_version'}, '2'); ...
    'daqsystem, one metadata reader', 'depends_on(device_id)', ...
        @(v) addEdge(v, 'device_id', 'dev_1'); ...
    'filenavigator, epochdir', 'filenavigator.directory', ...
        @(v) setIn(v, {'filenavigator', 'directory'}, '/data'); ...
    'daqreader, empty session', 'daqreader_ndr', ...
        @(v) setIn(v, {'daqreader_ndr', 'ndr_reader_string'}, 'intan'); ...
    'daqreader_ndr', 'base.type', ...
        @(v) setIn(v, {'base', 'type'}, 'daqreader'); ...
    'daqmetadatareader', 'daqmetadatareader.metadata_names', ...
        @(v) setIn(v, {'daqmetadatareader', 'metadata_names'}, 'stims'); ...
    'syncrule, filematch', 'files', ...
        @(v) setIn(v, {'files'}, struct('file_list', {{'rule.bin'}})); ...
    'syncgraph, two rules', 'depends_on(session_reference_id)', ...
        @(v) addEdge(v, 'session_reference_id', 'sref_1'); ...
    'probe_location, Dabrowska', 'probe_location.hemisphere', ...
        @(v) setIn(v, {'probe_location', 'hemisphere'}, 'left')};
f = writerFixtures();
for k = 1:size(breaks, 1)
    [label, path, fn] = breaks{k, :};
    v1 = jsondecode(jsonencode(fn(f{strcmp(f(:, 1), label), 2})));
    raw = runRaw(v1);
    verifyEmpty(testCase, raw.quarantine, [label ' + ' path]);
    verifyEqual(testCase, numel(raw.passthrough), 1, [label ' + ' path ': carried']);
    emitted = raw.migrated{1}.toStruct();
    verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1', [label ' + ' path]);
    emitted.document_class = rmfield(emitted.document_class, 'schema_version');
    verifyTrue(testCase, isequaln(emitted, v1), [label ' + ' path ': the carry is not the v1 source']);
    d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-100] malformed: outside the NDI template, unplaced: ') && contains(d, path), d);
    verifyTrue(testCase, did2.convert.roundtrip.check(v1, raw.migrated).ok, [label ' + ' path]);
end
end

function testAnEmptyUnreadFieldIsNotACarry(testCase)
% an empty value states nothing: the document converts as before
v1 = writerDaqmetadatareader();
v1.daqmetadatareader.metadata_names = '';
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.passthrough);
verifyGreaterThan(testCase, numel(out.migrated), 1);
end

function testWhatTheRenamedPathDiscardedIsCarriedOnBothPaths(testCase)
% carry-049 ([renames carry is temporary]): a depends_on `version`, an
% `ndi_document` beside `base`, a camelCase twin with a different value
breaks = { ...
    'daqsystem, one metadata reader', @(v) setDep(v, 1, 'version', 2); ...
    'syncgraph, two rules', @(v) setIn(v, {'ndi_document'}, struct('id', 'old_1', 'type', 'syncgraph')); ...
    'filenavigator, epochdir', @(v) setIn(v, {'filenavigator', 'epochprobemapClass'}, 'other.class')};
f = writerFixtures();
for k = 1:size(breaks, 1)
    label = breaks{k, 1};
    v1 = jsondecode(jsonencode(breaks{k, 2}(f{strcmp(f(:, 1), label), 2})));
    raw = runRaw(v1);
    old = runRenamed(v1);
    verifyEqual(testCase, numel(raw.passthrough), 1, [label ': raw carries']);
    verifyEqual(testCase, numel(old.passthrough), 1, [label ': renamed carries']);
    verifyEqual(testCase, char(raw.migrated{1}.get('document_class.schema_version')), 'did_v1', label);
    verifyEqual(testCase, char(old.migrated{1}.get('document_class.schema_version')), 'did_v1', label);
    d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-049] '), d);
end
end

function testTheExistingCarriesStayCarried(testCase)
% carry-017 / carry-039 (daqreader_ndr) and the passthroughs keep their notes
v1 = writerDaqreaderNdr();
v1.daqreader_ndr.file_extension = '.rhd';
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEqual(testCase, numel(out.passthrough), 1);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, contains(d, '[carry-039]'), d);
emitted = out.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
end

% ===================== the round trip can fail ===========================

function testAChangedValueIsReportedLost(testCase)
cases = {'daqsystem, one metadata reader', {'daqsystem', 'ndi_daqsystem_class'}, ...
        'ndi.daq.system.other', 'daqsystem.ndi_daqsystem_class'; ...
    'filenavigator, epochdir', {'filenavigator', 'fileparameters'}, ...
        '{ ''other.txt'' }', 'filenavigator.fileparameters'; ...
    'syncgraph, two rules', {'base', 'session_id'}, 'sess_other', 'base.session_id'; ...
    'probe_location, Dabrowska', {'probe_location', 'name'}, 'amygdala', 'probe_location.name'};
f = writerFixtures();
for k = 1:size(cases, 1)
    v1 = f{strcmp(f(:, 1), cases{k, 1}), 2};
    out = runRaw(v1);
    changed = setIn(v1, cases{k, 2}, cases{k, 3});
    r = did2.convert.roundtrip.check(changed, out.migrated);
    verifyFalse(testCase, r.ok, cases{k, 1});
    verifyEqual(testCase, {r.lost.path}, cases(k, 4), cases{k, 1});
end
end

function testADroppedEdgeIsReportedLost(testCase)
% a v1 metadata reader the acquisition_system no longer names
v1 = writerDaqsystem('vhvis_spike2', {'mdr_1', 'mdr_2'});
out = runRaw(v1);
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'acquisition_system')
        keep = ~strcmp({docs{k}.depends_on.document_id}, 'mdr_2');
        docs{k}.depends_on = docs{k}.depends_on(keep);
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(startsWith({r.lost.path}, 'depends_on(5)')), describeLost(r));
end

function testAMissingOrExtraDocumentIsUnplaced(testCase)
f = writerFixtures();
for label = {'daqsystem, one metadata reader', 'syncgraph, two rules', 'probe_location, Dabrowska'}
    v1 = f{strcmp(f(:, 1), label{1}), 2};
    docs = runRaw(v1).migrated;
    % one document short (the software entity, or the session anchor)
    r = did2.convert.roundtrip.check(v1, docs(1));
    verifyFalse(testCase, r.ok, label{1});
    verifyNotEmpty(testCase, r.unplaced, label{1});
    % a stray document
    stray = runRaw(writerDaqmetadatareader()).migrated;
    r = did2.convert.roundtrip.check(v1, [docs, stray(1)]);
    verifyFalse(testCase, r.ok, label{1});
    verifyNotEmpty(testCase, r.unplaced, label{1});
end
end

% ===================== known findings ===================================

function f = knownFindings()
% {fixture, path, why}. One writer-shaped fixture has one (the Dabrowska probe
% location, first row); the others are shapes no NDI writer at the locked
% `main` makes, and today's behaviour is kept for them (a question for the team
% each):
f = { ...
    'probe_location, Dabrowska', 'probe_location.name', ...
        ['the writer''s "bed nucleus of stria terminalis (BNST)" is written as the ' ...
         'registry''s label of UBERON:0001880, "bed nucleus of stria terminalis" ' ...
         '([probe location terms], Jess Haley, 2026-10-27); whether the writer''s ' ...
         'own spelling is also kept is open question 11e (as treatment)']; ...
    'daqreader with a base.name', 'base.name', ...
        'V2 writes no base.name (#73 item 54); the writer leaves it '''' (as subject 4a)'; ...
    'filenavigator, unbraced pattern', 'filenavigator.fileparameters', ...
        'a pattern not written by cell2str is read as one pattern and written back braced'; ...
    'probe_location, a label not the registry''s', 'probe_location.name', ...
        'a registered node takes the registry''s label (as treatment 11e)'};
end

function testKnownFindingsAreReported(testCase)
cases = {'daqreader with a base.name', setIn(writerDaqreader('ndi.daq.reader.mfdaq.intan', emptySessionId()), ...
        {'base', 'name'}, 'intan reader'); ...
    'filenavigator, unbraced pattern', setIn(writerFilenavigator('ndi.file.navigator', ...
        '#\.mat\>', 'ndi.epoch.epochprobemap_daqsystem', ''), {'base', 'name'}, ''); ...
    'probe_location, a label not the registry''s', writerProbeLocation('pl_9', 'UBERON:0002436', 'V1')};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    v1 = jsondecode(jsonencode(v1));
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, as today']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyRoundTrip(testCase, r, label, findingsFor(label));
end
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

% ===================== helpers =========================================

function c = familyClasses()
c = {'daqsystem', 'filenavigator', 'daqreader', 'daqreader_ndr', ...
    'daqmetadatareader', 'syncrule', 'syncgraph', 'probe_location'};
end

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runRenamed(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', ...
    'RawV1Classes', {});
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

function s = rmfieldIf(s, f)
if isfield(s, f); s = rmfield(s, f); end
end

function s = setIn(s, path, value)
s = setfield(s, path{:}, value); %#ok<SFLD>
end

function v1 = addEdge(v1, name, id)
d = v1.depends_on;
if isempty(d)
    d = struct('name', {}, 'value', {});
end
d = reshape(d, 1, []);
d(end+1) = struct('name', name, 'value', id);
v1.depends_on = d;
end

function v1 = setDep(v1, k, field, value)
% one entry gains FIELD; the others hold it empty (one struct array, as
% jsondecode gives entries that share their keys)
d = reshape(v1.depends_on, 1, []);
[d.(field)] = deal([]);
d(k).(field) = value;
v1.depends_on = d;
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

function docs = foldDocs(out, ruleId)
%FOLDDOCS The configuration the rule folded into, its software and the
%   acquisition systems its from / to edges name.
docs = {};
cfg = docWithId(out, ruleId);
if isempty(cfg) || ~strcmp(char(did2.unittest.helpers.classKey(cfg)), ...
        'clock_alignment_configuration')
    return;
end
docs = {cfg};
for sw = edgesOf(cfg, 'software_id')
    docs{end+1} = docWithId(out, sw{1}); %#ok<AGROW>
end
for role = {'from_acquisition_system_id', 'to_acquisition_system_id'}
    for s = edgesOf(cfg, role{1})
        docs{end+1} = docWithId(out, s{1}); %#ok<AGROW>
    end
end
end

% ===================== fixtures, from the WRITERS =========================

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end

function id = emptySessionId()
% ndi.session.empty_id(): every character of a fresh id '0' but the '_'
id = '0000000000000000_0000000000000000';
end

function v1 = withBase(tplName, id, sessionId, name)
tpl = loadTemplate(tplName);
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
if isfield(tpl, 'depends_on')
    v1.depends_on = tpl.depends_on;
end
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = sessionId;
v1.base.name = name;
v1.base.datestamp = '2025-05-27T15:47:23.738Z';
end

function f = writerFixtures()
% {label, v1, 'converted' | 'passthrough'}
f = { ...
    'daqsystem, one metadata reader', writerDaqsystem('vhvis_spike2', {'mdr_1'}), 'converted'; ...
    'daqsystem, no metadata reader', writerDaqsystem('vhintan', {}), 'converted'; ...
    'filenavigator, epochdir', writerFilenavigator('ndi.file.navigator.epochdir', ...
        '{ ''reference.txt'', ''.*\.rhd\>'', ''vhintan_channelgrouping.txt'', ''vhintan_intan2spike2time.txt'' }', ...
        'ndi.setup.epoch.epochprobemap_daqsystem_vhlab', '{ ''vhintan_channelgrouping.txt'' }'), 'converted'; ...
    'filenavigator, navigator', writerFilenavigator('ndi.file.navigator', ...
        '{ ''#\.mat\>'', ''#\.epochprobemap.txt\>'' }', 'ndi.epoch.epochprobemap_daqsystem', ...
        '{ ''(.*)epochprobemap.txt'' }'), 'converted'; ...
    'filenavigator, no parameters', writerFilenavigator('ndi.file.navigator', '', ...
        'ndi.epoch.epochprobemap_daqsystem', ''), 'converted'; ...
    'daqreader, empty session', writerDaqreader('ndi.daq.reader.mfdaq.intan', emptySessionId()), 'converted'; ...
    'daqreader, corpus session', writerDaqreader('ndi.daq.reader.mfdaq.cedspike2', 'sess_0001'), 'converted'; ...
    'daqreader_ndr', writerDaqreaderNdr(), 'converted'; ...
    'daqmetadatareader', writerDaqmetadatareader(), 'converted'; ...
    'syncrule, filematch', writerSyncrule('rule_fm', 'ndi.time.syncrule.filematch', ...
        struct('number_fullpath_matches', 2)), 'converted'; ...
    'syncrule, filefind', writerSyncrule('rule_ff', 'ndi.time.syncrule.filefind', ...
        filefindParameters()), 'passthrough'; ...
    'syncrule, commonTriggersOverlappingEpochs', channelRule(), 'passthrough'; ...
    'syncgraph, two rules', writerSyncgraph({'rule_ff', 'rule_fm'}), 'converted'; ...
    'probe_location, Dabrowska', writerProbeLocation('pl_1', 'UBERON:0001880', ...
        'bed nucleus of stria terminalis (BNST)'), 'converted'; ...
    'probe_location, probeLocations4probes', writerProbeLocation('pl_2', 'UBERON:0002436', ...
        'primary visual cortex'), 'converted'};
end

function v1 = writerDaqsystem(name, metadataIds)
% +daq/system.m newdocument: base.name the system's name, the real session;
% set_dependency_value fills the template's filenavigator_id and daqreader_id;
% add_dependency_value_n appends daqmetadatareader_id_1..N beside the
% template's own empty daqmetadatareader_id
v1 = withBase('daqsystem', ['daq_' name], 'sess_0001', name);
v1.depends_on(1).value = ['nav_' name];
v1.depends_on(2).value = ['rdr_' name];
for k = 1:numel(metadataIds)
    v1.depends_on(end+1) = struct('name', sprintf('daqmetadatareader_id_%d', k), ...
        'value', metadataIds{k});
end
tpl = loadTemplate('daqsystem');
v1.daqsystem = tpl.daqsystem;
v1.daqsystem.ndi_daqsystem_class = 'ndi.daq.system.mfdaq';
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerFilenavigator(cls, fileParams, mapClass, mapParams)
% +file/navigator.m newdocument: the four fields, cell2str'd lists ('' for
% none); the session is the navigator's; base.name the template's ''
v1 = withBase('filenavigator', 'nav_1', 'sess_0001', '');
v1.filenavigator = struct('ndi_filenavigator_class', cls, 'fileparameters', fileParams, ...
    'epochprobemap_class', mapClass, 'epochprobemap_fileparameters', mapParams);
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerDaqreader(cls, sessionId)
% +daq/reader.m newdocument: the class; base.session_id ndi.session.empty_id()
% (a corpus document holds the session it was added to)
v1 = withBase('daqreader', 'rdr_1', sessionId, '');
v1.daqreader = struct('ndi_daqreader_class', cls);
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerDaqreaderNdr()
% +daq/+reader/+mfdaq/ndr.m newdocument: the daqreader class, the reader
% string, the NDR class (the same class); superclasses base, daqreader
v1 = withBase('daqreader_ndr', 'rdr_ndr', emptySessionId(), '');
v1.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.mfdaq.ndr');
v1.daqreader_ndr = struct('ndr_reader_string', 'dabrowska', ...
    'ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr');
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerDaqmetadatareader()
% +daq/metadatareader.m newdocument
v1 = withBase('daqmetadatareader', 'mdr_1', emptySessionId(), '');
v1.daqmetadatareader = struct('ndi_daqmetadatareader_class', ...
    'ndi.daq.metadatareader.NewStimStims', 'tab_separated_file_parameter', 'stims.mat');
v1 = jsondecode(jsonencode(v1));
end

function v1 = channelRule()
% +time/syncrule.m newdocument for commonTriggersOverlappingEpochs.m:36
v1 = writerSyncrule('rule_ct', ...
    'ndi.time.syncrule.commonTriggersOverlappingEpochs', struct( ...
    'daqsystem1_name', 'vhtaste_sync', 'daqsystem2_name', 'vhtaste_bpod', ...
    'daqsystem_ch1', 'dep1', 'daqsystem_ch2', 'mk1', 'epochclocktype', 'dev_local_time', ...
    'minEmbeddedFileOverlap', 1, 'errorOnFailure', true));
end

function p = filefindParameters()
p = struct('number_fullpath_matches', 1, 'syncfilename', 'vhintan_intan2spike2time.txt', ...
    'daqsystem1', 'vhintan', 'daqsystem2', 'vhvis_spike2');
end

function v1 = writerSyncrule(id, cls, params)
% +time/syncrule.m newdocument: the class and the rule's parameters; the
% corpora hold the session the rule was added to
v1 = withBase('syncrule', id, 'sess_0001', '');
v1.syncrule = struct('ndi_syncrule_class', cls, 'parameters', params);
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerSyncgraph(ruleIds)
% +time/syncgraph.m newdocument: the class, the real session, and
% add_dependency_value_n('syncrule_id', ...) per rule (the template declares
% no edge)
v1 = withBase('syncgraph', 'graph_1', 'sess_0001', '');
v1.depends_on = struct('name', arrayfun(@(k) sprintf('syncrule_id_%d', k), ...
    1:numel(ruleIds), 'UniformOutput', false), 'value', ruleIds);
v1.syncgraph = struct('ndi_syncgraph_class', 'ndi.time.syncgraph');
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerProbeLocation(id, node, name)
% +setup/+conv/+dabrowska/doImport.m: ndi.document('probe_location',
% 'probe_location', struct(ontology_name, name)) + session.newdocument(), then
% set_dependency_value('probe_id', ...)
v1 = withBase('probe_location', id, 'sess_0001', '');
v1.depends_on.value = 'probe_1';
v1.probe_location = struct('ontology_name', node, 'name', name);
v1 = jsondecode(jsonencode(v1));
end

function [batch, rule] = filefindBatch()
%FILEFINDBATCH The two acquisition systems a filefind rule names (each with
%   its navigator and reader), and the rule, in one session.
rule = writerSyncrule('rule_ff', 'ndi.time.syncrule.filefind', filefindParameters());
batch = {writerDaqsystem('vhintan', {}), writerDaqsystem('vhvis_spike2', {'mdr_1'}), rule};
end
