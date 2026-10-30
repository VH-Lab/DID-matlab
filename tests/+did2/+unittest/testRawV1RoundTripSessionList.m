function tests = testRawV1RoundTripSessionList
%TESTRAWV1ROUNDTRIPSESSIONLIST dataset_session_info read as raw v1, and its
%   round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27 [fit
%   classes kept; session list rebuilt] (carry-118), [a rebuilt document may
%   lose its id], [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (441530d; tests/+did2/fixtures/ndi_templates, copied verbatim):
%   dataset_session_info.json + base.json, its list holding one entry per
%   member session, each entry the member's `session_in_a_dataset` block (the
%   aggregate form of session_in_a_dataset, written by NDI's older +dataset/
%   dir.m); the memberships and sessions in the writers' shapes, as
%   testRawV1RoundTripSession builds them (+session/dir.m, +ndi/dataset.m).
%   No corpus of the four zips holds a dataset_session_info.
%
%   A list the converted memberships rebuild exactly writes no V2 document;
%   any other list is carried whole as v1 and round trips as itself. The
%   switch changes no outcome. No known findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testTheClassIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'dataset_session_info')));
verifyEqual(testCase, did2.convert.rawV1Classes('dataset_session_info'), 'dataset_session_info');
out = runRaw({writerList('dsi_1', 'ds_1', {})});
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

function testAListTheMembershipsRebuildWritesNothing(testCase)
batch = rebuildingBatch();
out = runRaw(batch);
verifyEmpty(testCase, out.quarantine);
ids = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(ids, 'dsi_1')), 'the list writes no V2 document');
verifyFalse(testCase, any(strcmp({out.passthrough.id}, 'dsi_1')), 'not carried');
% the inverse of nothing rebuilds nothing, and says so
[~, spec] = did2.convert.roundtrip.dataset_session_info({});
verifyNotEmpty(testCase, spec.unplaced);
end

function testAListThatDoesNotRebuildIsCarriedAndRoundTrips(testCase)
s = rebuildingBatch();
lists = {{s{end}}, ...                                   % alone
    [s(1:4), {reordered(s{end})}], ...                   % another order
    [s(1:4), {relinked(s{end})}]};                       % another value
for k = 1:numel(lists)
    batch = lists{k};
    v1 = batch{end};
    out = runRaw(batch);
    label = sprintf('list %d', k);
    verifyEmpty(testCase, out.quarantine, label);
    doc = docWithId(out, 'dsi_1');
    assertNotEmpty(testCase, doc, [label ': carried']);
    verifyEqual(testCase, char(doc.document_class.schema_version), 'did_v1', label);
    notes = strjoin(cellstr(out.summary.migration_notes.carried_as_v1.distinct_details), ' || ');
    verifyTrue(testCase, contains(notes, '[carry-118] awaiting_home: '), notes);
    r = did2.convert.roundtrip.check(v1, {doc});
    verifyTrue(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testAFieldOutsideTheTemplateCarriesTheList(testCase)
s = rebuildingBatch();
v1 = s{end};
v1.dataset_session_info.dataset_name = 'exp';
verifyCarried(testCase, [{v1}, s(1:4)], 'dataset_session_info.dataset_name');
v1 = s{end};
v1.notes = struct('text', 'kept');
verifyCarried(testCase, [{v1}, s(1:4)], 'notes');
v1 = did2.unittest.helpers.setDependency(s{end}, 'dataset_id', 'ds_1');
verifyCarried(testCase, [{v1}, s(1:4)], 'depends_on(dataset_id)');
end

function testTheSwitchChangesNoOutcome(testCase)
s = rebuildingBatch();
for batch = {s, {s{end}}, [s(1:4), {reordered(s{end})}]}
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(batch{1});
    verifyEmpty(testCase, problems, strjoin(problems, '; '));
end
end

function testADifferentSourceIsReportedLost(testCase)
v1 = writerList('dsi_1', 'ds_1', {});
out = runRaw({v1});
doc = docWithId(out, 'dsi_1');
v1.base.name = 'changed';
r = did2.convert.roundtrip.check(v1, {doc});
verifyEqual(testCase, {r.lost.path}, {'base.name'});
end

% ===================== fixtures, from the TEMPLATES and WRITERS ============

function batch = rebuildingBatch()
% two sessions, their two ingested memberships of dataset ds_1, and the list
% that holds exactly the two membership blocks, in batch order
sA = writerSession('sd_A', 'sess_A', '2021-04-01');
sB = writerSession('sd_B', 'sess_B', '2021-04-02');
mA = writerMembership('sid_A', 'ds_1', 'sess_A', '2021-04-01');
mB = writerMembership('sid_B', 'ds_1', 'sess_B', '2021-04-02');
batch = {sA, mA, sB, mB, writerList('dsi_1', 'ds_1', ...
    {mA.session_in_a_dataset, mB.session_in_a_dataset})};
end

function v1 = writerList(docId, datasetId, entries)
% dataset_session_info.json: its one block holds the list
v1 = did2.unittest.helpers.ndiDocument('dataset_session_info', 'Id', docId, ...
    'SessionId', datasetId, 'Datestamp', '2026-05-15T18:57:10.582Z');
if isempty(entries)
    v1.dataset_session_info.dataset_session_info = '';
else
    v1.dataset_session_info.dataset_session_info = [entries{:}];
end
v1 = jsondecode(jsonencode(v1));
end

function v1 = reordered(v1)
v1.dataset_session_info.dataset_session_info = ...
    v1.dataset_session_info.dataset_session_info([2 1]);
end

function v1 = relinked(v1)
v1.dataset_session_info.dataset_session_info(2).is_linked = 1;
end

function v1 = writerSession(docId, sessionId, reference)
% +session/dir.m: ndi.document('session','session.reference',ref) +
% newdocument() (as testRawV1RoundTripSession)
v1 = did2.unittest.helpers.ndiDocument('session', 'Id', docId, ...
    'SessionId', sessionId, 'Datestamp', '2026-05-15T18:57:10.582Z');
v1.depends_on = [];
v1.session = struct('reference', reference);
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerMembership(docId, datasetId, sessionId, reference)
% +ndi/dataset.m add_ingested_session + addSessionInfoToDataset (as
% testRawV1RoundTripSession): the session_info struct, creator_args() of an
% ndi.session.dir ({reference, path, id}); input2 '' for an ingested session
v1 = did2.unittest.helpers.ndiDocument('session_in_a_dataset', 'Id', docId, ...
    'SessionId', datasetId, 'Datestamp', '2026-05-15T18:57:10.582Z');
v1.depends_on = [];
v1.session_in_a_dataset = struct('session_id', sessionId, ...
    'session_reference', reference, 'is_linked', 0, ...
    'session_creator', 'ndi.session.dir', 'session_creator_input1', reference, ...
    'session_creator_input2', '', 'session_creator_input3', sessionId, ...
    'session_creator_input4', '', 'session_creator_input5', '', ...
    'session_creator_input6', '');
v1 = jsondecode(jsonencode(v1));
end

% ===================== helpers =========================================

function out = runRaw(batch)
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
end

function s = docWithId(out, id)
s = [];
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(char(b.base.id), id)
        s = b;
        return;
    end
end
end

function verifyCarried(testCase, batch, part)
[carried, notes, out] = did2.unittest.helpers.carryNote(batch);
label = sprintf('dataset_session_info (%s)', part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, ['[carry-100] malformed: outside the NDI template, unplaced: ' part]) ...
    || contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
