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

function testASourceALaterPassResolvedIsIdCheckedAndCompared(testCase)
% pass 1 defers some sources (a stimulus_bath whose element it cannot read)
% and a later pass puts a document under the v1 id (resolveDeferredBaths);
% the report id-checks and compares it, and counts it apart. A source no
% final document holds stays quarantined.
[bodies, result] = cleanBatch();
k = find(strcmp({result.source_outputs.id}, 'wb_subj_1'));
% as pass 1 leaves a deferred source: not done, and neither its id nor its
% class recorded (v1_to_v2 records them only when the body migrates)
result.source_outputs(k).done = false;
result.source_outputs(k).id = '';
result.source_outputs(k).class_name = '';
result.source_outputs(k).output_ids = {};
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.sources_quarantined, 1);
verifyEqual(testCase, r.sources_resolved_by_batch_pass, 1);
verifyEqual(testCase, r.sources_still_quarantined, 0);
verifyTrue(testCase, isfield(r.resolved_by_batch_pass_by_class, 'subject'), ...
    'its class is read from the v1 body');
verifyEqual(testCase, r.ids_kept, 3);
verifyEqual(testCase, r.sources_compared, 3);
verifyEqual(testCase, r.sources_ok, 3, describe(r));
% its document gone: still quarantined, neither id-checked nor compared
keep = true(1, numel(result.migrated));
for j = 1:numel(result.migrated)
    keep(j) = ~strcmp(char(result.migrated{j}.get('base.id')), 'wb_subj_1');
end
result.migrated = result.migrated(keep);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.sources_still_quarantined, 1);
verifyEqual(testCase, r.sources_resolved_by_batch_pass, 0);
verifyEqual(testCase, r.ids_kept, 2);
verifyEqual(testCase, r.sources_compared, 2);
end

function testAnIdADecisionReleasesIsCountedApartFromLost(testCase)
% [a rebuilt document may lose its id] (Jess Haley, 2026-10-27): a source of a
% listed class (here daqreader_mfdaq_epochdata_ingested, [segment length is
% the time chunk], 2026-10-29) whose documents are gone and whose id nothing
% references is RELEASED, not lost; the same source with a referrer is lost
[bodies, result] = cleanBatch();
k = find(strcmp({result.source_outputs.id}, 'wb_subj_2'));
result.source_outputs(k).class_name = 'daqreader_mfdaq_epochdata_ingested';
keep = true(1, numel(result.migrated));
for j = 1:numel(result.migrated)
    keep(j) = ~strcmp(char(result.migrated{j}.get('base.id')), 'wb_subj_2');
end
result.migrated = result.migrated(keep);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.ids_released, 1);
verifyTrue(testCase, isfield(r.ids_released_by_class, 'daqreader_mfdaq_epochdata_ingested'));
verifyEqual(testCase, r.ids_lost, 0);
verifyEqual(testCase, r.sources_changed_by_batch_pass, 1, 'its round trip is still not measured');
verifyFalse(testCase, r.ok);
% a final document that references it: the id is lost, not released
s1 = result.migrated{1}.toStruct();
s1.depends_on = struct('name', 'archive_id', 'value', 'wb_subj_2');
result.migrated{1} = did2.document(s1);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.ids_released, 0);
verifyEqual(testCase, r.ids_lost, 1);
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

function testAPassthroughStillUnchangedIsStoredAsItsV1Source(testCase)
% an ontologyTableRow is carried by pass 1 unchanged, as every row is
% ([table rows carried as v1], Jess Haley, 2026-10-30); still unchanged at the
% end, the pipeline stores its v1 source
% (ndi.migrate.internal.carryUnchangedAsV1), which is what is compared
[bodies, result] = cleanBatch();
bodies{end+1} = tableRow('wb_row_1');
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
verifyTrue(testCase, any(strcmp({result.passthrough.id}, 'wb_row_1')), ...
    'pass 1 records the row as passed through');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.sources_compared, 4);
verifyEqual(testCase, r.sources_ok, 4, describe(r));
verifyGreaterThanOrEqual(testCase, r.sources_stored_as_v1, 1);
% UPDATED 2026-10-30: the row reads raw v1 ([migrators read raw v1], Jess
% Haley, 2026-10-26; did2.convert.rawV1Classes), so pass 1 names its class as
% v1 writes it, `ontologyTableRow`, not universalRenames' `ontology_table_row`
verifyTrue(testCase, isfield(r.stored_as_v1_by_class, 'ontologyTableRow'), ...
    'the row is counted as stored as its v1 source');
verifyEqual(testCase, r.sources_no_inverse, 0);
end

function testAPassthroughALaterStepChangedIsNotStoredAsV1(testCase)
% the same row, changed after pass 1: it is no longer stored as its v1 source,
% so it is compared as it is, and the run is not ok.
% UPDATED for [table rows carried as v1] (Jess Haley, 2026-10-30): this
% expected `sources_no_inverse == 1`. Pass 1 used to pass the row through
% silently, stamped did_v2, so did2.convert.roundtrip.check looked for an
% ontology_table_row inverse, found none, and counted NO INVERSE. Every row
% is now CARRIED (noted carry-026), and v1_to_v2 stamps a carried body
% 'did_v1' at once, so check compares that body directly with its v1 source
% (its CARRIED branch). The later change is therefore seen as a FAILED round
% trip of this one source, not hidden: the three subjects still round trip,
% and nothing is counted without an inverse.
[bodies, result] = cleanBatch();
bodies{end+1} = tableRow('wb_row_1');
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
for k = 1:numel(result.migrated)
    s = result.migrated{k}.toStruct();
    if strcmp(char(s.base.id), 'wb_row_1')
        s.base.name = 'changed by a later step';
        result.migrated{k} = did2.document(s);
    end
end
r = did2.convert.roundtrip.wholeBatch(bodies, result);
% the class as v1 writes it: the row reads raw v1 since 2026-10-30
verifyFalse(testCase, isfield(r.stored_as_v1_by_class, 'ontologyTableRow'));
verifyEqual(testCase, r.sources_no_inverse, 0);
verifyEqual(testCase, r.sources_compared, 4);
verifyEqual(testCase, r.sources_ok, 3, 'the changed row does not round trip');
verifyEqual(testCase, r.failures_total, 1);
verifyTrue(testCase, isfield(r.failures_by_class, 'ontologyTableRow'), ...
    'the failure is the changed row');
verifyFalse(testCase, r.ok);
end

function testAFailureSampleNamesTheLostValues(testCase)
[bodies, result] = cleanBatch();
for k = 1:numel(result.migrated)
    s = result.migrated{k}.toStruct();
    if strcmp(char(s.base.id), 'wb_subj_1')
        s.entity.local_identifier = 'someone else';
        result.migrated{k} = did2.document(s);
    end
end
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyNotEmpty(testCase, r.failures(1).lost_values);
verifyTrue(testCase, any(contains(r.failures(1).lost_values, 'someone else')), ...
    strjoin(r.failures(1).lost_values, ' | '));
end

function testAnIngestedManifestRoundTripsThroughItsDecomposition(testCase)
% resolveEpochProbemap renames the manifest to an ingestion_manifest and
% decomposes its probe map into statements no source became; the inverse reads
% them from the whole batch
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = '41268b6f5c6a3d4e_00000000000000b2';
bodies = {sessionV1('wb_sess_doc', sid), subjectV1('wb_spec', sid, 'L'), ...
    elementV1('wb_probe', sid, 'p', 1, 'n-trode', 'wb_spec'), ...
    daqsystemV1('wb_daq', sid, 'intan1', 'wb_nav'), ...
    manifestV1('wb_efi', sid, 't0001', 'wb_nav', ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'p\t1\tn-trode\tintan1:ai27-28,45;di0-2\tL\n']))};
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
verifyEqual(testCase, rep.manifests_renamed, 1, 'the manifest is renamed');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyFalse(testCase, isfield(r.changed_by_class, 'epochfiles_ingested'), describe(r));
verifyFalse(testCase, isfield(r.no_inverse_by_class, 'epochfiles_ingested'), describe(r));
verifyFalse(testCase, isfield(r.failures_by_class, 'epochfiles_ingested'), describe(r));
end

function testASessionDocumentIdIsAnAcceptedLoss(testCase)
% [v1 session document id not kept] (Jess Haley, 2026-11-03): the own base.id
% of a v1 `session` document is not kept (the session entity keeps the
% session id). After the check that nothing points at it, the round trip
% lists it as an accepted loss, named and counted, not a failure.
[bodies, result] = sessionBatch(testCase, 'wb_sdoc', 'c1', '');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.accepted_id_check.documents_scanned, numel(bodies), 'denominator');
verifyEqual(testCase, r.accepted_id_check.ids_checked, 1);
verifyEqual(testCase, double(r.accepted_id_check.ids_referenced), 0);
verifyEqual(testCase, r.ids_lost, 0, describe(r));
verifyEqual(testCase, r.ids_accepted_lost, 1);
verifyEqual(testCase, r.ids_accepted_lost_by_class.session, 1);
verifyEqual(testCase, r.accepted_losses_total, 1, 'listed once');
verifyEqual(testCase, r.accepted_losses_by_name.v1SessionDocumentId, 1);
verifyEqual(testCase, r.accepted_losses(1).source_id, 'wb_sdoc_sess');
verifyFalse(testCase, isfield(r.failures_by_class, 'session'), describe(r));
end

function testASessionDocumentIdAnotherDocumentNamesIsLost(testCase)
% the check first: a v1 document that names the session document's id (here
% in a text field) is reported with the field, and the id is NOT accepted
[bodies, result] = sessionBatch(testCase, 'wb_sref', 'c2', 'wb_sref_sess');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, double(r.accepted_id_check.ids_referenced), 1);
hit = r.accepted_id_check.referenced(1);
verifyEqual(testCase, hit.id, 'wb_sref_sess');
verifyEqual(testCase, hit.by_id, 'wb_sref_spec');
verifyEqual(testCase, hit.field, 'subject.description');
verifyEqual(testCase, r.ids_accepted_lost, 0);
verifyEqual(testCase, r.ids_lost, 1);
end

function testTheModeOfAProbeThatNeverRecordedIsAnAcceptedLoss(testCase)
% [clamp mode of unrecorded probe dropped] (Jess Haley, 2026-11-03): the
% patch-I probe no probe-map row names loses its `element type`; the round
% trip lists element.type as an accepted loss, named and counted, not a failure
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = '41268b6f5c6a3d4e_00000000000000c3';
bodies = {sessionV1('wb_m_sess', sid), subjectV1('wb_m_spec', sid, 'L'), ...
    elementV1('wb_m_rec', sid, 'pv', 1, 'patch-Vm', 'wb_m_spec'), ...
    elementV1('wb_m_idle', sid, 'pi', 1, 'patch-I', 'wb_m_spec'), ...
    daqsystemV1('wb_m_daq', sid, 'intan1', 'wb_m_nav'), ...
    manifestV1('wb_m_efi', sid, 't0001', 'wb_m_nav', ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'pv\t1\tpatch-Vm\tintan1:ai1\tL\n']))};
% the probes' edges as ndi.element/newdocument writes them
for k = 3:4
    bodies{k}.depends_on = struct('name', {'underlying_element_id', 'subject_id'}, ...
        'value', {'', 'wb_m_spec'});
end
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
assertEqual(testCase, rep.mode_statements_dropped_unrecorded, 1, 'premise');
% [recording mode terms] (Jess Haley, 2026-11-01): the RECORDED patch-Vm
% probe's statement is dropped too; its type rebuilds from its kind plus its
% recording observation's mode (current clamp), so it is no accepted loss
assertEqual(testCase, rep.mode_statements_dropped_recorded, 1, 'premise');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.accepted_losses_by_name.modeOfAProbeThatNeverRecorded, 1, describe(r));
hits = r.accepted_losses(strcmp({r.accepted_losses.source_id}, 'wb_m_idle'));
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits(1).path, 'element.type');
verifyEmpty(testCase, r.accepted_losses(strcmp({r.accepted_losses.source_id}, 'wb_m_rec')), ...
    'the recorded probe''s type was taken as an accepted loss');
for k = 1:numel(r.failures)
    if any(strcmp(r.failures(k).source_id, {'wb_m_idle', 'wb_m_rec'}))
        verifyFalse(testCase, any(strcmp(r.failures(k).lost, 'element.type')), describe(r));
        verifyEmpty(testCase, r.failures(k).unplaced, describe(r));
    end
end
end

function [bodies, result] = sessionBatch(testCase, stem, tail, description)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = ['41268b6f5c6a3d4e_00000000000000' tail];
bodies = {sessionV1([stem '_sess'], sid), subjectV1([stem '_spec'], sid, 'L')};
bodies{2}.subject.description = description;
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
end

function testAProbeInSeveralRowsRoundTripsAsItsMergedRow(testCase)
% [probe in several rows is one wiring] (Jess Haley, 2026-11-03): a stimulator
% listed once per channel (B and Dab) is one statement and one wiring holding
% every row's channels in row order; the round trip writes the merged row
% ('vis:mk1-3;e1;md1'), the probe and channels NDI reads, and the comparison
% accepts it as the same probe with the same ordered channel list
[bodies, result] = severalRowsBatch(testCase, 'wb_sev', 'b4');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyFalse(testCase, isfield(r.changed_by_class, 'epochfiles_ingested'), describe(r));
verifyFalse(testCase, isfield(r.failures_by_class, 'epochfiles_ingested'), describe(r));
end

function testAMergedRowWithAnotherChannelOrderIsLost(testCase)
% the equivalence is the ordered channel list: a v1 map whose rows list the
% same channels in another order is not what the merged row states
[bodies, result] = severalRowsBatch(testCase, 'wb_sevx', 'b5');
k = find(cellfun(@(b) strcmp(b.document_class.class_name, 'epochfiles_ingested'), bodies));
pm = bodies{k}.epochfiles_ingested.epochprobemap;
bodies{k}.epochfiles_ingested.epochprobemap = strrep(strrep(strrep(pm, ...
    'vis:mk1', 'vis:TMP'), 'vis:mk2', 'vis:mk1'), 'vis:TMP', 'vis:mk2');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyTrue(testCase, isfield(r.failures_by_class, 'epochfiles_ingested'), describe(r));
end

function [bodies, result] = severalRowsBatch(testCase, stem, tail)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = ['41268b6f5c6a3d4e_00000000000000' tail];
bodies = {sessionV1([stem '_sess'], sid), subjectV1([stem '_spec'], sid, 'L'), ...
    elementV1([stem '_stim'], sid, 'vis', 1, 'stimulator', [stem '_spec']), ...
    daqsystemV1([stem '_daq'], sid, 'vis', [stem '_nav']), ...
    manifestV1([stem '_efi'], sid, 't0001', [stem '_nav'], ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'vis\t1\tstimulator\tvis:mk1\tL\n' ...
        'vis\t1\tstimulator\tvis:mk2\tL\n' ...
        'vis\t1\tstimulator\tvis:mk3\tL\n' ...
        'vis\t1\tstimulator\tvis:e1\tL\n' ...
        'vis\t1\tstimulator\tvis:md1\tL\n']))};
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
assert(rep.manifests_renamed == 1 && rep.wiring_several_rows_merged == 1, ...
    'premise: the five rows merged and the manifest was renamed');
end

function testAProbeWhoseObservesRelationWasRetiredIsComparedAfterThePass(testCase)
% resolveEpochProbemap retires the probe's `observes` relation once a recording
% observation carries the same (instrument, specimen) pair; the element's
% inverse reads the specimen there, so the probe is compared (not counted
% CHANGED BY A BATCH PASS) and its subject_id is not lost
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = '41268b6f5c6a3d4e_00000000000000b3';
bodies = {sessionV1('wb_sess_doc_o', sid), subjectV1('wb_spec_o', sid, 'L'), ...
    elementV1('wb_probe_o', sid, 'p', 1, 'n-trode', 'wb_spec_o'), ...
    daqsystemV1('wb_daq_o', sid, 'intan1', 'wb_nav_o'), ...
    manifestV1('wb_efi_o', sid, 't0001', 'wb_nav_o', ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'p\t1\tn-trode\tintan1:ai27-28,45;di0-2\tL\n']))};
% the probe's edges as ndi.element/newdocument writes them: underlying_element_id
% (empty for a probe) then subject_id
bodies{3}.depends_on = struct('name', {'underlying_element_id', 'subject_id'}, ...
    'value', {'', 'wb_spec_o'});
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
assertGreaterThanOrEqual(testCase, rep.observes_retired, 1, ...
    'premise: the pass retired the probe''s observes relation');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyFalse(testCase, isfield(r.changed_by_class, 'element'), describe(r));
verifyTrue(testCase, isfield(r.compared_after_batch_pass_by_class, 'element'), describe(r));
for k = 1:numel(r.failures)
    if strcmp(r.failures(k).source_id, 'wb_probe_o')
        verifyFalse(testCase, any(startsWith(r.failures(k).lost, 'depends_on')), describe(r));
        verifyFalse(testCase, any(strcmp(r.failures(k).lost, 'element.direct')), describe(r));
    end
end
end

function testAnOpenmindsSubjectRoundTripsWithTheSpeciesTextAccepted(testCase)
% INVERTED 2026-10-29 from testAnOpenmindsSubjectRoundTrips, which asserted the
% species' definition and synonym were LOST. Decided by Jess Haley, 2026-10-29
% [species text is the openMINDS equivalent] (did-schema
% V_eta_go_forward_class_audit.md): they are not stored in v2 (the registry
% records the openMINDS species instance as the term's equivalent), and "the
% round trip reports the v1 text as an accepted difference".
% JH's shapes (ndi.database.fun.openMINDSobj2ndi_document): a sex states no
% definition and round trips clean; a species states openMINDS's definition and
% synonym, and the round trip reports exactly those as accepted (equivalent)
sex = openmindsV1('wb_om_sex', 'openminds_subject', 'subject_id', 'BiologicalSex', ...
    'hermaphrodite', 'PATO:0001340', '', '');
species = openmindsV1('wb_om_sp', 'openminds_subject', 'subject_id', 'Species', ...
    'Caenorhabditis elegans', 'NCBITaxon:6239', ...
    'Caenorhabditis elegans is a species of nematode.', 'C. elegans');
out = did2.convert.v1_to_v2({sex}, 'Validate', false, 'TargetVersion', 'did_v2');
r = did2.convert.roundtrip.check(sex, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_subject (sex)', {});
out = did2.convert.v1_to_v2({species}, 'Validate', false, 'TargetVersion', 'did_v2');
r = did2.convert.roundtrip.check(species, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_subject (species)', {});
verifyTrue(testCase, all(ismember({'openminds.fields.definition', ...
    'openminds.fields.synonym'}, r.equivalent)), ...
    'the species text is reported as an accepted difference');
verifyTrue(testCase, r.ok);
end

function testAnOpenmindsSubjectIdIsReadBackThroughTheEquivalentList(testCase)
% [term equivalents recorded] (Jess Haley, 2026-10-27), the round trip read:
% the inverse compares a v1 `openminds_id` through did2.convert.
% openmindsIdRebuilds, the migrator's own test, so it accepts exactly the ids
% the migrator converts; the rebuilt field stays '' so a writer document that
% states no id (JH's) is not reported as inventing one
sex = openmindsV1('wb_om_sex2', 'openminds_subject', 'subject_id', 'BiologicalSex', ...
    'hermaphrodite', 'PATO:0001340', '', '');
out = did2.convert.v1_to_v2({sex}, 'Validate', false, 'TargetVersion', 'did_v2');
bodies = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
[v1, spec] = did2.convert.roundtrip.openminds_subject(bodies);
verifyEqual(testCase, v1.openminds.openminds_id, '');
k = find(strcmp({spec.same.path}, 'openminds.openminds_id'));
assertNumElements(testCase, k, 1, 'the inverse reads the id back');
iri = 'https://openminds.om-i.org/instances/biologicalSex/hermaphrodite';
fn = spec.same(k).fn;
verifyEqual(testCase, fn(iri, ''), ...
    did2.convert.openmindsIdRebuilds('PATO:0001340', iri), ...
    'the round trip accepts an id exactly when the migrator would convert it');
r = did2.convert.roundtrip.check(sex, out.migrated);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_subject (no id)', {});
end

function testAnOpenmindsElementWithAnIdAndADescriptionConverts(testCase)
% INVERTED 2026-11-10 from testAnOpenmindsElementWithAnIdAndADescriptionIsCarried
% ([openMINDS element leftovers carried], carry-128). Decided by Jess Haley,
% 2026-11-10 [openMINDS element description in notes] (did-schema
% did_v2_go_forward_class_audit.md): the description is the term assertion's
% notes and the openminds_id is not stored (an openMINDS export rebuilds it).
% Dab's shape: a cell type with an openMINDS id and a description, and each
% half alone
ct = openmindsV1('wb_om_ct', 'openminds_element', 'element_id', 'CellType', ...
    'type III BNST neuron', 'EMPTY:0000073', '', '');
ct.openminds.openminds_id = 'CellType/dc2f5dd6-5cea-477c-a035-ca2dd3e6649d';
ct.openminds.fields.description = 'A type of neuron.';
for half = {'both', 'id', 'description'}
    one = ct;
    if strcmp(half{1}, 'id')
        one.openminds.fields.description = '';
    elseif strcmp(half{1}, 'description')
        one.openminds.openminds_id = '';
    end
    out = did2.convert.v1_to_v2({one}, 'Validate', false, 'TargetVersion', 'did_v2');
    verifyFalse(testCase, any(strcmp({out.passthrough.id}, 'wb_om_ct')), ...
        ['converted with ' half{1}]);
    r = did2.convert.roundtrip.wholeBatch({one}, out);
    verifyEqual(testCase, r.sources_compared, 1);
    verifyEqual(testCase, r.sources_ok, 1, describe(r));
end
end

function testAnOpenmindsElementWithNeitherConverts(testCase)
% the other side of [openMINDS element leftovers carried]: a cell type stating
% neither an openminds_id nor a description still converts to the term
% assertion, and round trips clean
ct = openmindsV1('wb_om_ct2', 'openminds_element', 'element_id', 'CellType', ...
    'type III BNST neuron', 'EMPTY:0000073', '', '');
out = did2.convert.v1_to_v2({ct}, 'Validate', false, 'TargetVersion', 'did_v2');
r = did2.convert.roundtrip.check(ct, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_element (converted)', {});
end

function testTheBatchIndexesAreReadFromTheWholeBatch(testCase)
% a batch pass calls v1_to_v2 on its own sub-batch, which re-indexes the batch
% (did2.convert.elementSubjects and the others) to THAT sub-batch; the report
% runs after every pass, so it indexes the whole batch again before an inverse
% reads it (a unit's subject_id rebuilt from its probe's: [unit direct and
% subject rebuild from the probe], Jess Haley, 2026-10-27)
sid = '41268b6f5c6a3d4e_00000000000000c3';
bodies = {subjectV1('wb_spec_ix', sid, 'L'), ...
    elementV1('wb_probe_ix', sid, 'p', 1, 'n-trode', 'wb_spec_ix')};
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
did2.convert.v1_to_v2({subject('wb_other_ix', 'x')}, 'Validate', false, ...
    'TargetVersion', 'did_v2');   % what a batch pass does
[~, found] = did2.convert.elementSubjects('get', 'wb_probe_ix');
verifyFalse(testCase, found, 'premise: the sub-batch call re-indexed the batch');
did2.convert.roundtrip.wholeBatch(bodies, result);
[subjectId, found] = did2.convert.elementSubjects('get', 'wb_probe_ix');
verifyTrue(testCase, found, 'the report indexes the whole batch again');
verifyEqual(testCase, subjectId, 'wb_spec_ix');
end

% ===================== fixtures =========================================

function [bodies, result] = cleanBatch()
% three subjects as ndi.subject.newdocument writes them: two convert, one with
% no local identifier is carried whole as v1 (carry-033)
bodies = {subject('wb_subj_1', 'mouse_1'), subject('wb_subj_2', 'mouse_2'), ...
    subject('wb_subj_3', '')};
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
end

function v1 = subject(id, localId)
v1 = did2.unittest.helpers.ndiDocument('subject', 'Id', id, ...
    'SessionId', '41268b6f5c6a3d4e_00000000000000a1', 'Datestamp', '2024-06-01T12:00:00.000Z');
v1.subject.local_identifier = localId;
v1.subject.description = '';
v1 = jsondecode(jsonencode(v1));
end

function v1 = tableRow(id)
% an ontologyTableRow as NDI's writers make it: the template's one edge,
% `document_id`, and no subject edge
v1 = struct();
v1.base = struct('id', id, 'session_id', '41268b6f5c6a3d4e_00000000000000a1', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.depends_on = struct('name', 'document_id', 'value', 'wb_subj_1');
v1.document_class = struct('definition', '$NDIDOCUMENTPATH/ontologyTableRow.json', ...
    'validation', '$NDISCHEMAPATH/ontologyTableRow_schema.json', ...
    'class_name', 'ontologyTableRow', 'property_list_name', 'ontologyTableRow', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.ontologyTableRow = struct('names', 'Weight', 'variableNames', 'weight', ...
    'ontologyNodes', 'PATO:0000128', 'data', struct('weight', 3));
v1 = jsondecode(jsonencode(v1));
end

function v1 = openmindsV1(id, cls, edge, type, name, node, definition, synonym)
v1 = struct();
v1.base = struct('id', id, 'session_id', '41268b6f5c6a3d4e_00000000000000a1', ...
    'name', '', 'datestamp', '2025-09-04T16:21:34.420Z');
v1.depends_on = struct('name', {edge, 'openminds'}, 'value', {'wb_about', ''});
v1.document_class = struct('definition', ['$NDIDOCUMENTPATH/metadata/' cls '.json'], ...
    'validation', ['$NDISCHEMAPATH/metadata/' cls '.json'], 'class_name', cls, ...
    'property_list_name', cls, 'class_version', 1, 'superclasses', ...
    struct('definition', {'$NDIDOCUMENTPATH/base.json', '$NDIDOCUMENTPATH/metadata/openminds.json'}));
v1.openminds = struct('openminds_type', ['https://openminds.om-i.org/types/' type], ...
    'matlab_type', ['openminds.controlledterms.' type], 'openminds_id', '', ...
    'fields', struct('definition', definition, 'description', '', ...
    'interlexIdentifier', '', 'knowledgeSpaceLink', '', 'name', name, ...
    'preferredOntologyIdentifier', node, 'synonym', synonym));
v1.(cls) = struct();
v1 = jsondecode(jsonencode(v1));
end

function v1 = sessionV1(id, sid)
v1 = struct();
v1.document_class = struct('definition', '$NDIDOCUMENTPATH/session.json', ...
    'validation', '$NDISCHEMAPATH/session.json', 'class_name', 'session', ...
    'property_list_name', 'session', 'class_version', 1, ...
    'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', 'wb_ref');
end

function v1 = subjectV1(id, sid, localId)
v1 = did2.unittest.helpers.ndiDocument('subject', 'Id', id, 'SessionId', sid, ...
    'Datestamp', '2024-06-01T12:00:00.000Z');
v1.subject.local_identifier = localId;
v1.subject.description = '';
end

function v1 = elementV1(id, sid, name, reference, type, subjectId)
v1 = struct();
v1.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {subjectId});
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.element = struct('ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
    'name', name, 'reference', reference, 'type', type, 'direct', 1);
end

function v1 = daqsystemV1(id, sid, name, navId)
v1 = struct();
v1.document_class = struct('class_name', 'daqsystem', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.base = struct('id', id, 'session_id', sid, 'name', name, ...
    'datestamp', '2024-05-01T00:00:00.000Z');
v1.daqsystem = struct('ndi_daqsystem_class', 'ndi.daq.system.mfdaq');
v1.depends_on = struct('name', {'filenavigator_id', 'daqreader_id'}, ...
    'value', {navId, ['rdr_' id]});
end

function v1 = manifestV1(id, sid, epochId, navId, pm)
v1 = struct();
v1.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation', '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name', 'epochfiles_ingested', 'property_list_name', 'epochfiles_ingested', ...
    'class_version', 1, 'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', navId);
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochfiles_ingested = struct('epoch_id', epochId, ...
    'files', {{['epochid://' epochId]; ['/data/' epochId '/a.rhd']}}, 'epochprobemap', pm);
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
