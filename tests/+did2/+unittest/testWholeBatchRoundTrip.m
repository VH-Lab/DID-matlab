function tests = testWholeBatchRoundTrip
%TESTWHOLEBATCHROUNDTRIP did2.convert.roundtrip.wholeBatch: a migrated batch's
%   FINAL documents back to v1, source by source, and the whole-batch id check.
%
%   Decided by Jess Haley, 2026-10-27 (did-schema
%   V_eta_go_forward_class_audit.md): [whole-batch round trip] ("one test takes
%   a migrated corpus's FINAL V2 batch (after every batch pass ...) back to v1
%   and compares it with the original") and [every v1 id survives] ("a
%   whole-batch id check"). The corpus driver
%   (did2.unittest.helpers.runCorpusDiscovery) runs it on every corpus after
%   every batch pass and writes the report; these tests drive it on a small
%   batch, and break the batch ON PURPOSE to show each count can move (a check
%   that cannot fail proves nothing).
tests = functiontests(localfunctions);
end

function testACleanBatchRoundTripsWholeWithItsDenominators(testCase)
[bodies, result] = cleanBatch();
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.sources_inspected, 3);
verifyEqual(testCase, r.final_documents, numel(result.migrated));
verifyEqual(testCase, r.sources_quarantined, 0);
verifyEqual(testCase, r.ids_kept, 3, 'every v1 id survives');
verifyEqual(testCase, r.ids_lost, 0);
verifyEqual(testCase, r.sources_compared, 3);
verifyEqual(testCase, r.sources_ok, 3, describe(r));
verifyEqual(testCase, r.sources_changed_by_batch_pass, 0);
verifyEqual(testCase, r.sources_no_inverse, 0);
verifyTrue(testCase, r.ok, describe(r));
end

function testTheResultRecordsWhatEachSourceBecame(testCase)
[~, result] = cleanBatch();
rows = result.source_outputs;
verifyEqual(testCase, numel(rows), 3);
verifyEqual(testCase, {rows.id}, {'wb_subj_1', 'wb_subj_2', 'wb_subj_3'});
verifyEqual(testCase, [rows.carried], [false false true]);
for k = 1:3
    verifyTrue(testCase, any(strcmp(rows(k).output_ids, rows(k).id)), rows(k).id);
end
end

function testADocumentABatchPassChangedIsReported(testCase)
% a batch pass that edits a document in place (here: a different local id)
% is caught by the per-class inverse on the final batch
[bodies, result] = cleanBatch();
for k = 1:numel(result.migrated)
    s = result.migrated{k}.toStruct();
    if strcmp(char(s.base.id), 'wb_subj_1')
        s.entity.local_identifier = 'someone else';
        result.migrated{k} = did2.document(s);
    end
end
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.failures_total, 1);
verifyEqual(testCase, r.failures(1).source_id, 'wb_subj_1');
verifyTrue(testCase, any(strcmp(r.failures(1).lost, 'subject.local_identifier')), describe(r));
verifyFalse(testCase, r.ok);
end

function testADocumentABatchPassRemovedLosesTheIdAndIsCounted(testCase)
% a batch pass that replaced a source's document: its id no longer survives,
% and the source is counted as changed by a pass (no inverse yet), not compared
[bodies, result] = cleanBatch();
keep = true(1, numel(result.migrated));
for k = 1:numel(result.migrated)
    keep(k) = ~strcmp(char(result.migrated{k}.get('base.id')), 'wb_subj_2');
end
result.migrated = result.migrated(keep);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.ids_lost, 1);
verifyEqual(testCase, r.ids_lost_ids, {'wb_subj_2'});
verifyEqual(testCase, r.sources_changed_by_batch_pass, 1);
verifyEqual(testCase, r.sources_compared, 2);
verifyFalse(testCase, r.ok);
end

function testADocumentNoSourceBecameIsCountedUnattributed(testCase)
[bodies, result] = cleanBatch();
extra = result.migrated{1}.toStruct();
extra.base.id = 'wb_minted_by_a_pass';
result.migrated{end+1} = did2.document(extra);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.unattributed_documents, 1);
end

function testAResultWithoutSourceOutputsIsRefused(testCase)
[bodies, result] = cleanBatch();
result = rmfield(result, 'source_outputs');
verifyError(testCase, @() did2.convert.roundtrip.wholeBatch(bodies, result), ...
    'did2:convert:roundtrip:noSourceOutputs');
end

% ===================== fixtures =========================================

function [bodies, result] = cleanBatch()
% three subjects as ndi.subject.newdocument writes them: two convert, one with
% no local identifier is carried whole as v1 (carry-033)
bodies = {subject('wb_subj_1', 'mouse_1'), subject('wb_subj_2', 'mouse_2'), ...
    subject('wb_subj_3', '')};
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v1 = subject(id, localId)
v1 = did2.unittest.helpers.ndiDocument('subject', 'Id', id, ...
    'SessionId', '41268b6f5c6a3d4e_00000000000000a1', 'Datestamp', '2024-06-01T12:00:00.000Z');
v1.subject.local_identifier = localId;
v1.subject.description = '';
v1 = jsondecode(jsonencode(v1));
end

function s = describe(r)
parts = {};
for k = 1:numel(r.failures)
    f = r.failures(k);
    parts{end+1} = sprintf('%s (%s): lost %s; invented %s; unplaced %s', f.source_id, ...
        f.class_name, strjoin(f.lost, ', '), strjoin(f.invented, ', '), ...
        strjoin(f.unplaced, '; ')); %#ok<AGROW>
end
s = strjoin(parts, ' || ');
if isempty(s); s = '(no failures)'; end
end
