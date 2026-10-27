function tests = testRawV1RoundTripSession
%TESTRAWV1ROUNDTRIPSESSION The session / dataset / presentation family read as
%   raw v1, and its round trip: session, session_in_a_dataset, dataset_remote,
%   metadata_editor and stimulus_presentation.
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
%   session.json, session_in_a_dataset.json, dataset_remote.json,
%   metadata_editor.json, stimulus_presentation.json, epochid.json, app.json,
%   base.json) in the shapes their writers give them, and pass through
%   jsonencode/jsondecode as a corpus delivers them:
%     session          +session/dir.m: ndi.document('session',
%                      'session.reference', ref) + newdocument(): base.id the
%                      document's own, base.session_id the session's, name ''
%     membership       +ndi/dataset.m: session_id, session_reference,
%                      is_linked (0 ingested / 1 linked), session_creator
%                      'ndi.session.dir', session_creator_input1..6 from
%                      creator_args() {reference, path, id} (input2 '' for an
%                      ingested session); base.session_id the dataset's id
%     dataset_remote   +cloud/+internal/createRemoteDatasetDoc.m: dataset_id
%                      and organization_id (both cloud ids), no depends_on
%     metadata_editor  +metadata_ds_core/saveEditor2Doc.m: the editor's form
%                      in metadata_structure (convertDatasetInfoToDocument)
%     presentation     +app/+stimulus/decoder.m: presentation_order, stimuli
%                      parameters, epochid, presentation_time.bin, the
%                      stimulus_element_id edge and newdocument()'s `app`
%   The session, membership, remote and presentation shapes are those of all
%   53 / 48 / 4 / 1,428 corpus documents (census of the corpus zips,
%   2026-10-27); the one corpus metadata_editor (Soph) states three form
%   fields.
%
%   Pass 1 converts the session, the membership (or carries it), the remote
%   record and the form, and carries the presentation for NDI's second pass
%   (carry-045). control_stimulus_ids is NOT switched (rawV1Classes says why).
%
%   WHAT V2 DOES NOT KEEP is listed per fixture as KNOWN FINDINGS (questions
%   for the team; today's behaviour is kept): each document's own v1 id where
%   the migration re-ids or mints (session, membership, remote record, form),
%   and a V_zeta-vintage session's three dropped inventions.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the switch ======================================

function testTheFiveClassesAreSwitched(testCase)
names = did2.convert.rawV1Classes();
for c = {'session', 'session_in_a_dataset', 'dataset_remote', 'metadata_editor', ...
        'stimulus_presentation'}
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
end
verifyFalse(testCase, any(strcmp(names, 'control_stimulus_ids')), ...
    'control_stimulus_ids stays on the renamed path (rawV1Classes says why)');
r = runRaw({writerSession('sd_1', 'sess_1', 'exp1'), ...
    writerMembership('sid_1', 'ds_1', 'sess_1', 'exp1', 0, ''), ...
    writerRemote('dr_1', 'ds_1'), writerEditor('me_1', 'ds_1', sophForm()), ...
    writerPresentation('sp_1')});
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, 5);
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

% ===================== session ==========================================

function testWriterSessionsConvertAndRoundTrip(testCase)
cases = {'session', writerSession('sd_A', 'sess_A', '2021-04-01'); ...
    'dataset session', writerSession('sd_D', 'ds_D', 'my_dataset')};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted']);
    verifyEqual(testCase, char(out.migrated{1}.get('entity.local_identifier')), ...
        v1.session.reference, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, findingsFor('session'));
    accounted = [r.matched, r.not_set];
    for p = {'base.session_id', 'base.datestamp', 'base.name', ...
            'document_class.class_name', 'session.reference'}
        verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
            sprintf('%s: %s is not accounted for', label, p{1}));
    end
end
end

function testAVZetaSessionLosesOnlyItsInventions(testCase)
% the three V_zeta fields (TEAM-SIGN-OFF [session]: DELETED) are still read and
% dropped, as before the switch; the round trip names them
v1 = writerSession('sd_Z', 'sess_Z', 'exp9');
v1.session.type = 'experiment';
v1.session.date = '2024-06-01';
v1.session.purpose = 'characterisation';
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.passthrough, 'converted, as before');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r, 'V_zeta session', [findingsFor('session'), ...
    {'session.date', 'session.purpose', 'session.type'}]);
end

function testAnUnreadSessionFieldOrEdgeIsCarried(testCase)
% before the switch a field outside the template, or an edge, was dropped
% without a word; now the document is carried whole (no register row yet)
v1 = writerSession('sd_X', 'sess_X', 'exp2');
v1.session.notes = 'a stray field';
w = writerSession('sd_Y', 'sess_Y', 'exp3');
w.depends_on = struct('name', 'subject_id', 'value', 'subj_1');
cases = {'session.notes', jsondecode(jsonencode(v1)); ...
    'depends_on(subject_id)', jsondecode(jsonencode(w))};
for k = 1:size(cases, 1)
    [what, body] = cases{k, :};
    out = runRaw(body);
    verifyCarriedUntouched(testCase, out, body, what);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, contains(d, what), d);
    old = runRenamed(body);
    verifyEmpty(testCase, old.passthrough, [what ': the renamed path dropped it']);
end
end

function testALegacyBlockBesideBaseIsCarriedOnBothPaths(testCase)
v1 = writerSession('sd_L', 'sess_L', 'exp4');
v1.ndi_document = struct('id', 'sd_L', 'type', 'session');
v1 = jsondecode(jsonencode(v1));
raw = runRaw(v1);
old = runRenamed(v1);
verifyCarriedUntouched(testCase, raw, v1, 'legacy beside base');
verifyEqual(testCase, numel(old.passthrough), 1, 'renamed: carried');
d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-049] '), d);
end

% ===================== session_in_a_dataset ==============================

function testAnIngestedMembershipConvertsAndRoundTrips(testCase)
% the session is in the batch, so its reference is compared and dropped
% ([ingested session membership]); its entity is handed to the round trip
s = writerSession('sd_A', 'sess_A', '2021-04-01');
m = writerMembership('sid_A', 'ds_1', 'sess_A', '2021-04-01', 0, '');
out = runRaw({s, m});
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'both converted');
docs = membershipDocs(out, 'sess_A');
verifyEqual(testCase, numel(docs), 3, 'dataset entity, relation, session entity');
r = did2.convert.roundtrip.check(m, docs);
verifyFalse(testCase, r.carried);
verifyRoundTrip(testCase, r, 'ingested membership', findingsFor('membership'));
verifyTrue(testCase, any(strcmp('session_in_a_dataset.session_creator_input1', r.restated)), ...
    'the reference copy in input1 is restated');
verifyTrue(testCase, any(strcmp('session_in_a_dataset.session_creator_input3', r.restated)), ...
    'the id copy in input3 is restated');
end

function testMembershipsTheMigratorCannotPlaceAreCarried(testCase)
s = writerSession('sd_A', 'sess_A', '2021-04-01');
cases = { ...
    'linked (its reference has no home)', {s, writerMembership('sid_L', 'ds_1', 'sess_A', ...
        '2021-04-01', 1, '/data/2021-04-01')}, 'session_reference of a linked session'; ...
    'reference differs', {s, writerMembership('sid_D', 'ds_1', 'sess_A', 'other', 0, '')}, ...
        '[carry-060]'; ...
    'session not in the batch', {writerMembership('sid_N', 'ds_1', 'sess_A', '2021-04-01', 0, '')}, ...
        '[carry-069]'; ...
    'is_linked empty', {s, writerMembership('sid_E', 'ds_1', 'sess_A', '2021-04-01', [], '')}, ...
        '[carry-066]'};
for k = 1:size(cases, 1)
    [label, batch, cite] = cases{k, :};
    m = batch{end};
    out = runRaw(batch);
    verifyEmpty(testCase, out.quarantine, label);
    emitted = docWithId(out, m.base.id);
    assertNotEmpty(testCase, emitted, [label ': the membership was not carried under its id']);
    verifyEqual(testCase, char(emitted.get('document_class.schema_version')), 'did_v1', label);
    r = did2.convert.roundtrip.check(m, {emitted});
    verifyTrue(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
    notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' | ');
    verifyTrue(testCase, contains(notes, cite), sprintf('%s: %s', label, notes));
end
end

function testAnUnreadMembershipFieldIsCarried(testCase)
s = writerSession('sd_A', 'sess_A', '2021-04-01');
m = writerMembership('sid_X', 'ds_1', 'sess_A', '2021-04-01', 0, '');
m.session_in_a_dataset.session_path = '/somewhere';
m = jsondecode(jsonencode(m));
out = runRaw({s, m});
emitted = docWithId(out, 'sid_X');
assertNotEmpty(testCase, emitted);
verifyEqual(testCase, char(emitted.get('document_class.schema_version')), 'did_v1');
notes = strjoin(out.summary.migration_notes.carried_as_v1.distinct_details, ' | ');
verifyTrue(testCase, contains(notes, 'session_in_a_dataset.session_path'), notes);
end

% ===================== dataset_remote ===================================

function testWriterRemoteRecordsConvertAndRoundTrip(testCase)
v1 = writerRemote('dr_1', 'ds_1');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted');
verifyEqual(testCase, numel(out.migrated), 3, 'dataset, organization, hosted_by');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
verifyRoundTrip(testCase, r, 'remote record', findingsFor('remote'));
accounted = [r.matched, r.not_set];
for p = {'base.session_id', 'base.datestamp', 'dataset_remote.dataset_id', ...
        'dataset_remote.organization_id'}
    verifyTrue(testCase, any(strcmp(p{1}, accounted)), sprintf('%s is not accounted for', p{1}));
end
end

% ===================== metadata_editor ==================================

function testWriterFormsConvertAndRoundTrip(testCase)
cases = {'Soph form', writerEditor('me_S', 'ds_S', sophForm()); ...
    'full form', writerEditor('me_F', 'ds_F', fullForm())};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, findingsFor('form'));
end
end

function testAnUnreadFormFieldIsCarried(testCase)
% the editor writes `Comments` and each author's `authorRole`; the migrator
% reads neither, so before the switch they were dropped without a word
f = fullForm();
f.Comments = 'collected in 2021';
g = fullForm();
g.Author.authorRole = 'first author';
cases = {'metadata_structure.Comments', f; 'Author(1).authorRole', g};
for k = 1:size(cases, 1)
    [what, form] = cases{k, :};
    v1 = writerEditor('me_U', 'ds_U', form);
    out = runRaw(v1);
    verifyCarriedUntouched(testCase, out, v1, what);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, contains(d, strrep(what, 'metadata_structure.', '')), d);
end
end

% ===================== stimulus_presentation =============================

function testWriterPresentationsAreCarriedUntouched(testCase)
cases = {'parameters', writerPresentation('sp_1'); ...
    'no stimulus parameters', writerPresentation('sp_2', false)};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    for path = {'raw', 'renamed'}
        if strcmp(path{1}, 'raw'); out = runRaw(v1); else; out = runRenamed(v1); end
        verifyEmpty(testCase, out.quarantine, [label ', ' path{1}]);
        verifyEqual(testCase, numel(out.passthrough), 1, [label ', ' path{1} ': carried']);
        verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
            'did_v1', [label ', ' path{1}]);
        d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
        verifyTrue(testCase, startsWith(d, '[carry-045] '), d);
    end
    out = runRaw(v1);
    verifyCarriedUntouched(testCase, out, v1, label);
end
end

function testTheInventedPresentationEdgeStillQuarantines(testCase)
v1 = writerPresentation('sp_3');
v1.depends_on = [v1.depends_on; struct('name', 'element_id', 'value', '')];
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:stimulusPresentationInventedEdge');
end

% ===================== the switch changes no outcome ======================

function testTheSwitchChangesNoConvertedDocument(testCase)
% a converted document is the one the renamed path converted; a carry is
% carried on both
s = writerSession('sd_A', 'sess_A', '2021-04-01');
fixtures = {{writerSession('sd_B', 'sess_B', 'exp1')}, ...
    {s, writerMembership('sid_A', 'ds_1', 'sess_A', '2021-04-01', 0, '')}, ...
    {s, writerMembership('sid_L', 'ds_1', 'sess_A', '2021-04-01', 1, '/data/x')}, ...
    {writerRemote('dr_1', 'ds_1')}, {writerEditor('me_S', 'ds_S', sophForm())}, ...
    {writerEditor('me_F', 'ds_F', fullForm())}, {writerPresentation('sp_1')}};
for k = 1:numel(fixtures)
    batch = fixtures{k};
    raw = runRaw(batch);
    old = runRenamed(batch);
    label = sprintf('fixture %d (%s)', k, batch{end}.document_class.class_name);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), label);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        a = raw.migrated{j}.toStruct();
        b = old.migrated{j}.toStruct();
        if strcmp(char(a.document_class.schema_version), 'did_v1')
            verifyEqual(testCase, char(b.document_class.schema_version), 'did_v1', label);
            continue;
        end
        verifyTrue(testCase, isequaln(a, b), sprintf('%s, document %d: raw %s; renamed %s', ...
            label, j, jsonencode(a), jsonencode(b)));
    end
end
end

function testWriterShapesValidate(testCase)
% everything converted above is a valid V2 document (the tests above run with
% Validate false)
s = writerSession('sd_A', 'sess_A', '2021-04-01');
batch = {s, writerMembership('sid_A', 'ds_1', 'sess_A', '2021-04-01', 0, ''), ...
    writerRemote('dr_1', 'ds_1'), writerEditor('me_S', 'ds_S', sophForm()), ...
    writerEditor('me_F', 'ds_F', fullForm()), writerPresentation('sp_1')};
out = did2.convert.v1_to_v2(batch, 'Validate', true, 'TargetVersion', 'V_eta');
reasons = '';
for k = 1:numel(out.quarantine)
    reasons = [reasons sprintf('%s: %s; ', out.quarantine(k).class_name, ...
        out.quarantine(k).reason)]; %#ok<AGROW>
end
verifyEmpty(testCase, out.quarantine, reasons);
end

% ===================== the round trip can fail ===========================

function testAChangedValueIsReportedLost(testCase)
v1 = writerRemote('dr_2', 'ds_2');
out = runRaw(v1);
v1b = v1;
v1b.dataset_remote.dataset_id = 'another';
r = did2.convert.roundtrip.check(v1b, out.migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp('dataset_remote.dataset_id', {r.lost.path})));
s = writerSession('sd_C', 'sess_C', 'exp5');
outS = runRaw(s);
s.session.reference = 'exp6';
r = did2.convert.roundtrip.check(s, outS.migrated);
verifyTrue(testCase, any(strcmp('session.reference', {r.lost.path})));
end

function testAMissingOrExtraDocumentIsUnplaced(testCase)
v1 = writerRemote('dr_3', 'ds_3');
docs = runRaw(v1).migrated;
r = did2.convert.roundtrip.check(v1, docs(1:2));
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
s = writerSession('sd_E', 'sess_E', 'exp7');
r = did2.convert.roundtrip.check(s, [runRaw(s).migrated, docs(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
p = writerPresentation('sp_5');
r = did2.convert.roundtrip.check(p, runRaw(s).migrated);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== known findings ===================================

function f = knownFindings()
% {fixture, path, why}. On the session_id EDGE shape (did-schema main) the
% session entity takes the session id as its base.id; the field shape keeps
% the document's own id.
f = { ...
    'membership', 'base.id', ['the relation''s id is minted; the v1 record''s own id ' ...
        'is kept nowhere (a question for the team)']; ...
    'remote', 'base.id', 'the v1 record''s own id is kept nowhere (a question)'; ...
    'form', 'base.id', 'the v1 form''s own id is kept nowhere (a question)'};
if did2.schema.cache.shared().sessionIdIsEdge()
    f(end+1, :) = {'session', 'base.id', ['the session entity takes the session id ' ...
        '(V_eta_relation_inheritance_plan item 4); the document''s own id is kept ' ...
        'nowhere (a question)']};
end
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

% ===================== helpers =========================================

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

function verifyCarriedUntouched(testCase, out, v1, label)
verifyEmpty(testCase, out.quarantine, label);
assertEqual(testCase, numel(out.migrated), 1, [label ': one document']);
verifyEqual(testCase, numel(out.passthrough), 1, [label ': carried']);
emitted = out.migrated{1}.toStruct();
verifyEqual(testCase, char(emitted.document_class.schema_version), 'did_v1', label);
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), [label ': the carry is not the v1 source']);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried, label);
verifyRoundTrip(testCase, r, label, {});
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

function doc = docWithId(out, id)
doc = [];
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), id)
        doc = out.migrated{k};
        return;
    end
end
end

function docs = membershipDocs(out, sessionId)
% the dataset entity, the membership relation and the member session's entity
docs = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    s = d.toStruct();
    if strcmp(d.className(), 'directed_relation') || ...
            (strcmp(d.className(), 'entity') && ...
            (strcmp(char(s.base.id), sessionId) || ...
            strcmp(did2.build.vocabularyHandle('entity_type', s.entity.type), 'dataset')))
        docs{end+1} = d; %#ok<AGROW>
    end
end
end

% ===================== fixtures, from the WRITERS =========================

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end

function b = writerBase(id, sessionId)
tpl = loadTemplate('base');
b = tpl.base;
b.id = id;
b.session_id = sessionId;
b.datestamp = '2026-05-15T18:57:10.582Z';
end

function v1 = writerSession(docId, sessionId, reference)
% +session/dir.m: ndi.document('session','session.reference',ref) +
% newdocument() (base.id new, base.session_id the session's own id)
tpl = loadTemplate('session');
v1 = struct();
v1.base = writerBase(docId, sessionId);
v1.depends_on = [];
v1.document_class = tpl.document_class;
v1.session = struct('reference', reference);
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerMembership(docId, datasetId, sessionId, reference, isLinked, path)
% +ndi/dataset.m add_linked_session / add_ingested_session +
% addSessionInfoToDataset: the session_info struct, creator_args() of an
% ndi.session.dir ({reference, path, id}); input2 '' for an ingested session
tpl = loadTemplate('session_in_a_dataset');
v1 = struct();
v1.base = writerBase(docId, datasetId);
v1.depends_on = [];
v1.document_class = tpl.document_class;
v1.session_in_a_dataset = struct('session_id', sessionId, ...
    'session_reference', reference, 'is_linked', isLinked, ...
    'session_creator', 'ndi.session.dir', 'session_creator_input1', reference, ...
    'session_creator_input2', path, 'session_creator_input3', sessionId, ...
    'session_creator_input4', '', 'session_creator_input5', '', ...
    'session_creator_input6', '');
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerRemote(docId, datasetId)
% +cloud/+internal/createRemoteDatasetDoc.m: the cloud dataset's id and its
% organization's id (as on all 4 corpus records); no depends_on
tpl = loadTemplate('dataset_remote');
v1 = struct();
v1.base = writerBase(docId, datasetId);
v1.dataset_remote = struct('dataset_id', '67f723d574f5f79c6062389d', ...
    'organization_id', '649b1b1bea20f31db68d4f9f');
v1.document_class = tpl.document_class;
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerEditor(docId, datasetId, form)
% +metadata_ds_core/saveEditor2Doc.m: ndi.document('metadata_editor',
% 'base.id', new, 'base.session_id', D.id(), 'metadata_editor.metadata_structure',
% convertDatasetInfoToDocument(datasetInfo))
tpl = loadTemplate('metadata_editor');
v1 = struct();
v1.base = writerBase(docId, datasetId);
v1.document_class = tpl.document_class;
v1.metadata_editor = struct('metadata_structure', form);
v1 = jsondecode(jsonencode(v1));
end

function f = sophForm()
% the one corpus form (Soph)
f = struct('VersionIdentifier', 'This is the first version of the dataset', ...
    'License', 'CC-BY-4.0', 'DataType', 'derivedData');
end

function f = fullForm()
% the editor's fields as convertDatasetInfoToDocument writes them (char
% values; one author as AuthorData.getDefaultAuthorItem shapes it)
f = struct();
f.DatasetFullName = 'Recordings of visual cortex';
f.DatasetShortName = 'V1 recordings';
f.Description = 'Single units recorded in V1.';
f.ReleaseDate = '2025-06-02';
f.License = 'CC-BY-4.0';
f.VersionIdentifier = '1.0';
f.ExperimentalApproach = 'electrophysiology';
f.DataType = 'derivedData';
f.Author = struct('affiliation', struct('memberOf', struct('fullName', 'Brandeis University')), ...
    'contactInformation', struct('email', 'author at example.org'), ...
    'digitalIdentifier', struct('identifier', 'https://orcid.org/0000-0002-1825-0097'), ...
    'familyName', 'Carberry', 'givenName', 'Josiah', 'authorRole', '');
f.Funding = struct('funder', 'National Eye Institute', 'awardTitle', 'Visual cortex', ...
    'awardNumber', 'EY022122');
end

function v1 = writerPresentation(id, withParameters)
% +app/+stimulus/decoder.m: the presentation block (presentation_time now in
% presentation_time.bin), epochid, the stimulus_element_id edge, and the
% `app` block newdocument() adds
if nargin < 2; withParameters = true; end
tpl = loadTemplate('stimulus_presentation');
app = loadTemplate('app');
v1 = struct();
v1.app = app.app;
v1.app.name = 'ndi_app_stimulus_decoder';
v1.app.version = '9a7b6c5';
v1.app.url = 'https://github.com/VH-Lab/NDI-matlab';
v1.app.os = 'MACI64';
v1.app.os_version = '14.6.1';
v1.app.interpreter = 'MATLAB';
v1.app.interpreter_version = '24.2';
v1.base = writerBase(id, 'sess_1');
v1.depends_on = struct('name', 'stimulus_element_id', 'value', 'stim_el_1');
v1.document_class = tpl.document_class;
v1.epochid = struct('epochid', 't00001');
v1.files = struct('file_list', {{'presentation_time.bin'}}, 'file_info', struct( ...
    'name', 'presentation_time.bin', 'locations', struct('delete_original', 0, ...
    'uid', '4126936f64faca84_c0d3f57ec1fd3843', ...
    'location', 'ndic://68839b1fbf243809c0800a01/4126936f64faca84_c0d3f57ec1fd3843', ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0)));
if withParameters
    stimuli = struct('parameters', {struct('angle', 0, 'sFrequency', 0.05, 'isblank', 0), ...
        struct('angle', 90, 'sFrequency', 0.05, 'isblank', 0), struct('isblank', 1)});
else
    stimuli = struct('parameters', {struct(), struct()});
end
v1.stimulus_presentation = struct('presentation_order', [1; 2; 3; 1; 2; 3], ...
    'stimuli', stimuli);
v1 = jsondecode(jsonencode(v1));
end
