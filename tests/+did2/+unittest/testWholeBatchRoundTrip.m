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
isMode = strcmp({r.accepted_losses.name}, 'mode of a probe that never recorded');
hits = r.accepted_losses(strcmp({r.accepted_losses.source_id}, 'wb_m_idle') & isMode);
verifyEqual(testCase, numel(hits), 1);
verifyEqual(testCase, hits(1).path, 'element.type');
verifyEmpty(testCase, r.accepted_losses(strcmp({r.accepted_losses.source_id}, 'wb_m_rec')), ...
    'the recorded probe''s type was taken as an accepted loss');
% the idle probe has no recording and no wiring either, so its class is the
% other accepted loss, [unlinked device is not an element] (Jess Haley, 2026-11-11)
unlinked = r.accepted_losses(strcmp({r.accepted_losses.source_id}, 'wb_m_idle') & ~isMode);
verifyEqual(testCase, numel(unlinked), 1, describe(r));
if isscalar(unlinked)
    verifyEqual(testCase, unlinked.path, 'element.ndi_element_class');
end
for k = 1:numel(r.failures)
    if any(strcmp(r.failures(k).source_id, {'wb_m_idle', 'wb_m_rec'}))
        verifyFalse(testCase, any(strcmp(r.failures(k).lost, 'element.type')), describe(r));
        verifyEmpty(testCase, r.failures(k).unplaced, describe(r));
    end
end
end

function testADeviceWithNoLinksIsNotAnElement(testCase)
% [unlinked device is not an element] (Decided by Jess Haley, 2026-11-11,
% did-schema docs/plans/did_v2_go_forward_class_audit.md): a migrated v1 probe
% whose device has no recording observation (`instrument_id`) and no wiring
% (`connected to`, RO:0002170) is not an element ([element recognised by its
% links]), as NDI-matlab's ndi.vintage.linkedElements reads it. It keeps its
% device entity; its v1 ndi_element_class is not rebuilt, and the round trip
% lists that as the decided difference, named and counted, not a failure and
% not an equivalent element. A probe the probe map names (recorded, wired)
% rebuilds its class and is not listed. (PRED's `rayostim`, a stimulator with
% no epochs, is the case found: its corpus zip has no epoch files, NDI-matlab
% #785.)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = '41268b6f5c6a3d4e_00000000000000c4';
bodies = {sessionV1('wb_u_sess', sid), subjectV1('wb_u_spec', sid, 'L'), ...
    elementV1('wb_u_rec', sid, 'p', 1, 'n-trode', 'wb_u_spec'), ...
    elementV1('wb_u_idle', sid, 'rayostim', 1, 'stimulator', 'wb_u_spec'), ...
    daqsystemV1('wb_u_daq', sid, 'intan1', 'wb_u_nav'), ...
    manifestV1('wb_u_efi', sid, 't0001', 'wb_u_nav', ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'p\t1\tn-trode\tintan1:ai1-2\tL\n']))};
bodies{4}.element.ndi_element_class = 'ndi.probe.timeseries.stimulator';
% the probes' edges as ndi.element/newdocument writes them
for k = 3:4
    bodies{k}.depends_on = struct('name', {'underlying_element_id', 'subject_id'}, ...
        'value', {'', 'wb_u_spec'});
end
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
result = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
% premise: the idle stimulator is still a device entity under its v1 id
finalBodies = cellfun(@(d) d.toStruct(), result.migrated, 'UniformOutput', false);
ix = find(cellfun(@(b) strcmp(char(b.base.id), 'wb_u_idle'), finalBodies), 1);
assertNotEmpty(testCase, ix, 'premise: the stimulator''s entity is in the batch');
verifyEqual(testCase, did2.unittest.helpers.classKey(finalBodies{ix}), 'device', ...
    'the unlinked stimulator keeps its device entity');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyTrue(testCase, isfield(r.accepted_losses_by_name, 'deviceWithNoLinksIsNotAnElement'), describe(r));
if isfield(r.accepted_losses_by_name, 'deviceWithNoLinksIsNotAnElement')
    verifyEqual(testCase, r.accepted_losses_by_name.deviceWithNoLinksIsNotAnElement, 1, describe(r));
end
isUnlinked = strcmp({r.accepted_losses.name}, 'device with no links is not an element');
hits = r.accepted_losses(isUnlinked);
verifyEqual(testCase, numel(hits), 1, describe(r));
if isscalar(hits)
    verifyEqual(testCase, hits.source_id, 'wb_u_idle');
    verifyEqual(testCase, hits.class_name, 'element');
    verifyEqual(testCase, hits.path, 'element.ndi_element_class');
    verifyTrue(testCase, contains(hits.decision, '[unlinked device is not an element]'));
end
verifyEmpty(testCase, r.accepted_losses(strcmp({r.accepted_losses.source_id}, 'wb_u_rec')), ...
    'the recorded, wired probe was taken as an accepted loss');
for k = 1:numel(r.failures)
    if any(strcmp(r.failures(k).source_id, {'wb_u_idle', 'wb_u_rec'}))
        verifyFalse(testCase, any(strcmp(r.failures(k).lost, 'element.ndi_element_class')), describe(r));
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

function testARetiredIngestedArchiveIsComparedOnTheBodiesItBecame(testCase)
% resolveEpochProbemap RETIRES a v1 daqreader_mfdaq_epochdata_ingested once its
% files and its clock have new owners ([segment length is the time chunk],
% Jess Haley, 2026-10-29), so none of its own documents remains. The round
% trip finds the opaque_body documents that carry its files (their file_info
% holds its location uids) and rebuilds the archive from them and the batch:
% it is compared, not counted CHANGED BY A BATCH PASS (Test code run
% 43077600408: B 1,242, Dab 2,846). Its id is released, not lost, and the
% rebuilt document's missing base.id is not a second loss. The two segment
% lengths, which [segment length is the time chunk] puts on a sampled_body's
% time `chunk` in NDI-matlab's second pass, after this batch, are DEFERRED to
% that pass, not lost ([archive segment lengths measured after the second
% pass], Jess Haley, 2026-11-12): counted by field, and the archive is clean
% at the DID stage.
[bodies, result, rep] = archiveBatch(testCase, 'wb_arc', 'b6');
assertEqual(testCase, rep.archive_docs_retired, 1, 'premise: the archive retired');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
cls = 'daqreader_mfdaq_epochdata_ingested';
verifyFalse(testCase, isfield(r.changed_by_class, cls), describe(r));
verifyTrue(testCase, isfield(r.compared_after_batch_pass_by_class, cls), describe(r));
verifyTrue(testCase, isfield(r.ids_released_by_class, cls), describe(r));
verifyFalse(testCase, isfield(r.ids_lost_by_class, cls), describe(r));
verifyEmpty(testCase, archiveFailure(r, 'wb_arc_arc'), ...
    ['only the deferred segment lengths differ: ' describe(r)]);
verifyFalse(testCase, isfield(r.failures_by_class, cls), describe(r));
verifyArchiveSegmentsDeferred(testCase, r, 1, 1);
end

function testAnArchiveFileListInAnotherOrderRoundTrips(testCase)
% [archive file list compared as a set] (Jess Haley, 2026-11-12): the v1
% archive's files.file_list in another order than the template's is the same
% list (B and Dab: every retired archive differed only so)
[bodies, result, rep] = archiveBatch(testCase, 'wb_arco', 'b8', @reverseFileList);
assertEqual(testCase, rep.archive_docs_retired, 1, 'premise: the archive retired');
k = archiveIndex(bodies);
tmpl = archiveTemplateFileList();
assertFalse(testCase, isequal(bodies{k}.files.file_list, tmpl), ...
    'premise: the v1 list is not in the template order');
assertEqual(testCase, sort(bodies{k}.files.file_list), sort(tmpl), ...
    'premise: the v1 list holds the template names');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEmpty(testCase, archiveFailure(r, 'wb_arco_arc'), describe(r));
verifyArchiveSegmentsDeferred(testCase, r, 1, 1);
end

function testAnArchiveFileListWithOtherMembersIsLost(testCase)
% the set comparison is not a pass for anything: a name missing, a name the
% template does not hold, or a duplicate in place of another name, each is
% files.file_list LOST (a check that cannot fail proves nothing)
[bodies0, result] = archiveBatch(testCase, 'wb_arcm', 'b9');
k = archiveIndex(bodies0);
fl = bodies0{k}.files.file_list;
cases = { ...
    'a name missing', fl(1:end-1); ...
    'a name the template does not hold', [fl(1:end-1); {'xx_group1_seg.nbf_#'}]; ...
    'a duplicate in place of another name', [fl(1:end-1); fl(1)]; ...
    'a duplicate added', [fl; fl(2)]};
for c = 1:size(cases, 1)
    bodies = bodies0;
    bodies{k}.files.file_list = cases{c, 2};
    r = did2.convert.roundtrip.wholeBatch(bodies, result);
    f = archiveFailure(r, 'wb_arcm_arc');
    assertNotEmpty(testCase, f, [cases{c, 1} ': ' describe(r)]);
    verifyEqual(testCase, f.lost, {'files.file_list'}, [cases{c, 1} ': ' describe(r)]);
    % the deferral is still reported, on a source that is not clean
    verifyArchiveSegmentsDeferred(testCase, r, 1, 0);
end
end

function testAnArchiveFieldOtherThanTheSegmentLengthsIsStillLost(testCase)
% only the two segment lengths are deferred: another parameter the batch does
% not hold is lost, and the deferral is still reported beside it
[bodies, result] = archiveBatch(testCase, 'wb_arcp', 'ba');
k = archiveIndex(bodies);
cls = 'daqreader_mfdaq_epochdata_ingested';
bodies{k}.(cls).parameters.sample_other_segment = 5;
r = did2.convert.roundtrip.wholeBatch(bodies, result);
f = archiveFailure(r, 'wb_arcp_arc');
assertNotEmpty(testCase, f, describe(r));
verifyEqual(testCase, f.lost, {[cls '.parameters.sample_other_segment']}, describe(r));
verifyEqual(testCase, sort(f.deferred), sort({ ...
    [cls '.parameters.sample_analog_segment'], ...
    [cls '.parameters.sample_digital_segment']}), describe(r));
verifyArchiveSegmentsDeferred(testCase, r, 1, 0);
end

function verifyArchiveSegmentsDeferred(testCase, r, nSources, nOk)
% the report's DEFERRED TO THE SECOND PASS block: its denominator, the
% archive's two segment-length fields, each counted on NSOURCES sources, NOK
% of them clean at the DID stage
cls = 'daqreader_mfdaq_epochdata_ingested';
d = r.deferred_to_second_pass;
verifyEqual(testCase, d.sources_compared, r.sources_compared, 'the denominator');
verifyEqual(testCase, d.sources, nSources, describe(r));
verifyEqual(testCase, d.sources_ok, nOk, describe(r));
verifyEqual(testCase, d.values, 2 * nSources, describe(r));
verifyEqual(testCase, sort({d.fields.path}), sort({ ...
    [cls '.parameters.sample_analog_segment'], ...
    [cls '.parameters.sample_digital_segment']}), describe(r));
verifyEqual(testCase, unique({d.fields.class_name}), {cls});
verifyEqual(testCase, [d.fields.sources], [nSources nSources]);
verifyTrue(testCase, all(contains({d.fields.decision}, ...
    'archive segment lengths measured after the second pass')));
end

function v1 = reverseFileList(v1)
v1.files.file_list = flipud(v1.files.file_list(:));
end

function k = archiveIndex(bodies)
k = find(cellfun(@(b) strcmp(b.document_class.class_name, ...
    'daqreader_mfdaq_epochdata_ingested'), bodies));
end

function c = archiveTemplateFileList()
thisDir = fileparts(mfilename('fullpath'));
tmpl = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', ...
    'daqreader_mfdaq_epochdata_ingested.json')));
c = tmpl.files.file_list;
end

function testARetiredArchiveWhoseValueTheBatchDoesNotHoldIsLost(testCase)
% the same archive, its v1 epoch and its second segment's place changed after
% the migration: the rebuilt document states what the batch holds, so both
% differences are reported lost (a check that cannot fail proves nothing)
[bodies, result] = archiveBatch(testCase, 'wb_arcx', 'b7');
k = find(cellfun(@(b) strcmp(b.document_class.class_name, ...
    'daqreader_mfdaq_epochdata_ingested'), bodies));
bodies{k}.epochid.epochid = 't9999';
bodies{k}.files.file_info(3).locations.location = 'ndic://ds/elsewhere';
r = did2.convert.roundtrip.wholeBatch(bodies, result);
f = archiveFailure(r, 'wb_arcx_arc');
assertNotEmpty(testCase, f, describe(r));
verifyTrue(testCase, any(strcmp(f.lost, 'epochid.epochid')), describe(r));
verifyTrue(testCase, any(strcmp(f.lost, 'files.file_info(3).locations.location')), describe(r));
end

function testAnArchiveAfterTheSecondPassIsRebuiltByName(testCase)
% NDI-matlab's second pass converts the channel group to a sampled_body whose
% members are body_data_<k> ([migrated body members renamed]), removes the
% evenly spaced time, channel_list.bin ([channel list rows get v2 homes]) and
% the events file ([unpacked events file is removed]) and writes each event
% channel as an observation (Jess Haley, 2026-11-17). The archive is still
% found (its sampled_body holds its location uids) and rebuilt: every v1 file
% NAME comes back in the writer's place, and only the v1 LOCATIONS of the
% removed files are not rebuilt (no v2 document names their uid; the file
% stays in NDI's store, unreferenced). Those of channel_list.bin (entry 1)
% and the events file (entry 6) are an accepted loss ([removed file
% locations are an accepted loss], Jess Haley, 2026-11-18), and so are those
% of the removed evenly spaced time segments (entries 4 and 5, [removed time
% segment locations are an accepted loss], Jess Haley, 2026-11-19): listed
% and counted, and nothing is lost
[bodies, result] = archiveBatch(testCase, 'wb_arc2', 'bb');
result2 = secondPassOf(result, false);
r = did2.convert.roundtrip.wholeBatch(bodies, result2);
cls = 'daqreader_mfdaq_epochdata_ingested';
verifyTrue(testCase, isfield(r.compared_after_batch_pass_by_class, cls), describe(r));
% clean at the DID stage: nothing lost, invented or unplaced, only the two
% segment lengths deferred to the second pass
verifyEmpty(testCase, archiveFailure(r, 'wb_arc2_arc'), describe(r));
name = 'removed archive file location';
acc = r.accepted_losses(strcmp({r.accepted_losses.name}, name));
assertNotEmpty(testCase, acc, describe(r));
verifyEqual(testCase, r.accepted_losses_by_name.(matlab.lang.makeValidName(name)), numel(acc));
verifyTrue(testCase, all(contains({acc.decision}, 'removed file locations are an accepted loss')));
verifyTrue(testCase, all(strcmp({acc.source_id}, 'wb_arc2_arc')));
verifyTrue(testCase, all(startsWith({acc.path}, {'files.file_info(1).locations', ...
    'files.file_info(4).locations', 'files.file_info(5).locations', ...
    'files.file_info(6).locations'})), strjoin({acc.path}, ', '));
verifyTrue(testCase, all(contains({acc.decision}, ...
    'removed time segment locations are an accepted loss')));
for k = [1 4 5 6]
    verifyTrue(testCase, any(strcmp({acc.path}, sprintf('files.file_info(%d).locations.uid', k))), ...
        sprintf('entry %d accepted: %s', k, strjoin({acc.path}, ', ')));
    verifyTrue(testCase, any(strcmp({acc.path}, sprintf('files.file_info(%d).locations.location', k))), ...
        sprintf('entry %d accepted: %s', k, strjoin({acc.path}, ', ')));
end
verifyEqual(testCase, r.accepted_losses_total, numel(r.accepted_losses));
verifyArchiveSegmentsDeferred(testCase, r, 1, 1);
end

function testRemovedFileLocationsAreAcceptedOnlyWhenRemoved(testCase)
% [removed file locations are an accepted loss] covers a file the second pass
% removed, never one still carried: the same archive with channel_list.bin
% kept (its body still there, so its location is rebuilt from the body) has
% no accepted location loss for it, and a v1 location of that kept file that
% the body does not hold is still lost (a check that cannot fail proves
% nothing)
[bodies, result] = archiveBatch(testCase, 'wb_arc5', 'be');
result2 = secondPassOf(result, false, {'channel_list.bin'});
assertNotEmpty(testCase, find(cellfun(@(d) strcmp(slotOf(asStruct(d)), 'channel_list.bin'), ...
    result2.migrated), 1), 'the channel_list.bin body is kept');
k = find(cellfun(@(b) strcmp(b.document_class.class_name, ...
    'daqreader_mfdaq_epochdata_ingested'), bodies));
bodies{k}.files.file_info(1).locations.location = 'ndic://ds/elsewhere';
r = did2.convert.roundtrip.wholeBatch(bodies, result2);
f = archiveFailure(r, 'wb_arc5_arc');
assertNotEmpty(testCase, f, describe(r));
verifyTrue(testCase, any(strcmp(f.lost, 'files.file_info(1).locations.location')), describe(r));
acc = r.accepted_losses(strcmp({r.accepted_losses.name}, 'removed archive file location'));
verifyFalse(testCase, any(startsWith({acc.path}, 'files.file_info(1).')), strjoin({acc.path}, ', '));
verifyTrue(testCase, any(strcmp({acc.path}, 'files.file_info(6).locations.uid')), ...
    strjoin({acc.path}, ', '));
end

function testKeptTimeSegmentLocationsAreNotAccepted(testCase)
% [removed time segment locations are an accepted loss] (Jess Haley,
% 2026-11-19) covers a time segment the second pass removed, never one still
% carried: with the time body kept (as for an unevenly spaced time channel
% the pass does not drop), a v1 location of a segment that the body does not
% hold is still lost and not accepted, while the removed channel_list.bin
% and events file are (a check that cannot fail proves nothing)
[bodies, result] = archiveBatch(testCase, 'wb_arc6', 'bf');
result2 = secondPassOf(result, false, {'ti_group1_seg.nbf_#'});
assertNotEmpty(testCase, find(cellfun(@(d) strcmp(slotOf(asStruct(d)), 'ti_group1_seg.nbf_#'), ...
    result2.migrated), 1), 'the time body is kept');
k = find(cellfun(@(b) strcmp(b.document_class.class_name, ...
    'daqreader_mfdaq_epochdata_ingested'), bodies));
bodies{k}.files.file_info(4).locations.location = 'ndic://ds/elsewhere';
r = did2.convert.roundtrip.wholeBatch(bodies, result2);
f = archiveFailure(r, 'wb_arc6_arc');
assertNotEmpty(testCase, f, describe(r));
verifyTrue(testCase, any(strcmp(f.lost, 'files.file_info(4).locations.location')), describe(r));
acc = r.accepted_losses(strcmp({r.accepted_losses.name}, 'removed archive file location'));
verifyFalse(testCase, any(startsWith({acc.path}, {'files.file_info(4).', 'files.file_info(5).'})), ...
    strjoin({acc.path}, ', '));
for e = [1 6]
    verifyTrue(testCase, any(strcmp({acc.path}, sprintf('files.file_info(%d).locations.uid', e))), ...
        strjoin({acc.path}, ', '));
end
end

function testAnArchiveWhoseGroupHasItsOwnOwnerIsRebuiltTheSame(testCase)
% [non-specimen channel groups get their own owner]: a group owned by another
% observation of the same epoch and system reads back the same epoch, clock
% and reader. Both read back clean (the removed files' locations are accepted
% losses, [removed file locations are an accepted loss] and [removed time
% segment locations are an accepted loss]), so the epoch (epochid), the
% clock and the reader (depends_on) are matched in both
[bodies, result] = archiveBatch(testCase, 'wb_arc3', 'bc');
r0 = did2.convert.roundtrip.wholeBatch(bodies, secondPassOf(result, false));
r1 = did2.convert.roundtrip.wholeBatch(bodies, secondPassOf(result, true));
cls = 'daqreader_mfdaq_epochdata_ingested';
for r = {r0, r1}
    verifyTrue(testCase, isfield(r{1}.compared_after_batch_pass_by_class, cls), describe(r{1}));
    verifyEmpty(testCase, archiveFailure(r{1}, 'wb_arc3_arc'), describe(r{1}));
end
verifyEqual(testCase, sort({r1.accepted_losses.path}), sort({r0.accepted_losses.path}), ...
    'the same values accepted with either owner');
end

function testASecondPassBodyWhoseNamesCannotBeRebuiltIsUnplaced(testCase)
% the group's channel type removed: its names cannot be rebuilt, which is
% reported (a check that cannot fail proves nothing)
[bodies, result] = archiveBatch(testCase, 'wb_arc4', 'bd');
result2 = secondPassOf(result, false);
for k = 1:numel(result2.migrated)
    b = result2.migrated{k};
    if strcmp(b.document_class.class_name, 'sampled_body')
        for blk = {'data_body', 'opaque_body'}
            if isfield(b, blk{1}) && isfield(b.(blk{1}), 'filename')
                b.(blk{1}) = rmfield(b.(blk{1}), 'filename');
            end
        end
        b.data_body = rmfield(b.data_body, 'conditions');
        result2.migrated{k} = b;
    end
end
r = did2.convert.roundtrip.wholeBatch(bodies, result2);
f = archiveFailure(r, 'wb_arc4_arc');
assertNotEmpty(testCase, f, describe(r));
verifyNotEmpty(testCase, f.unplaced, describe(r));
verifyTrue(testCase, any(contains(f.lost, 'files.file_info(2).name')), describe(r));
end

function result = secondPassOf(result, ownOwner, kept)
% the archive's pass-1 bodies as NDI-matlab's second pass leaves them under
% the 2026-11-17 decisions (see testIngestedArchiveFiles for the shape): the
% analog group a sampled_body (members body_data_<k>, 2 segments of 1e6
% samples), the evenly spaced time, channel_list.bin and the events file
% removed, the marker channel an observation of the epoch. OWNOWNER: the
% group is owned by a new observation of the same epoch and system. KEPT
% (optional): slots whose body the pass keeps (as it keeps a channel list it
% cannot rebuild exactly)
if nargin < 3; kept = {}; end
final = cellfun(@(d) asStruct(d), result.migrated, 'UniformOutput', false);
T = @(node, name) struct('node', node, 'name', name);
keep = true(1, numel(final));
added = {};
for k = 1:numel(final)
    b = final{k};
    if ~strcmp(b.document_class.class_name, 'opaque_body'); continue; end
    slot = slotOf(b);
    switch slot
        case {'channel_list.bin', 'ti_group1_seg.nbf_#', 'evmktx_group1_seg.nbf_#'}
            keep(k) = any(strcmp(slot, kept));
        case 'ai_group1_seg.nbf_#'
            owners = {b.depends_on(strcmp({b.depends_on.name}, 'owner_id')).document_id};
            rec = final{find(cellfun(@(x) strcmp(x.base.id, owners{1}), final), 1)};
            tref = {rec.depends_on(strcmp({rec.depends_on.name}, 'time_reference_id')).document_id};
            b.document_class.class_name = 'sampled_body';
            cov = @(v, f, x) setfield(struct('variable', v, 'along', 1), f, x); %#ok<SFLD>
            b.data = struct('dimensions', {{struct('term', T('om:Time', 'time'), 'n', 1500000, ...
                'chunk', 1e6), struct('term', T('NCIT:C44170', 'Channel'), 'n', 2)}}, ...
                'covariates', {{struct('variable', T('om:Time', 'time'), 'along', 0, ...
                'origin', struct('value', 0), 'spacing', struct('value', 1/30000)), ...
                cov(T('EMPTY:0000370', 'analog input channel'), 'count', [1 2]), ...
                cov(T('AFO:AFQ_0000202', 'signal offset configuration'), 'quantity', struct('value', [0 0])), ...
                cov(T('NCIT:C70774', 'Unit Conversion Factor'), 'quantity', struct('value', [1 1])), ...
                cov(T('EMPTY:0000374', 'time channel'), 'quantity', struct('value', [1 1]))}});
            b.data_body.conditions = struct('variable', T('NCIT:C44170', 'Channel'), ...
                'term', T('EMPTY:0000370', 'analog input channel'));
            if ownOwner
                acq = {rec.depends_on(strcmp({rec.depends_on.name}, 'acquisition_system_id')).document_id};
                o = struct('document_class', struct('class_name', 'observation'), ...
                    'base', struct('id', 'own_owner'), ...
                    'depends_on', struct('name', [repmat({'time_reference_id'}, 1, numel(tref)), ...
                        repmat({'acquisition_system_id'}, 1, numel(acq))], 'document_id', [tref, acq]));
                added{end+1} = o; %#ok<AGROW>
                i = find(strcmp({b.depends_on.name}, 'owner_id'));
                b.depends_on(i(1)).document_id = 'own_owner';
                b.depends_on(i(2:end)) = [];
            end
            final{k} = b;
            mk = struct('document_class', struct('class_name', 'observation'), ...
                'base', struct('id', 'mk_obs'), ...
                'observation', struct('conditions', struct('variable', ...
                    T('EMPTY:0000377', 'marker channel'), 'count', 1)), ...
                'depends_on', struct('name', 'time_reference_id', 'document_id', tref(1)));
            added{end+1} = mk; %#ok<AGROW>
    end
end
result.migrated = [final(keep), added];
end

function s = slotOf(b)
s = '';
for blk = {'data_body', 'opaque_body'}
    if isfield(b, blk{1}) && isstruct(b.(blk{1})) && isfield(b.(blk{1}), 'filename') ...
            && ~isempty(b.(blk{1}).filename)
        s = char(b.(blk{1}).filename);
        return;
    end
end
end

function b = asStruct(d)
b = d;
if isa(d, 'did2.document'); b = d.toStruct(); end
end

function f = archiveFailure(r, id)
f = [];
for k = 1:numel(r.failures)
    if strcmp(r.failures(k).source_id, id)
        f = r.failures(k);
    end
end
end

function [bodies, result, rep] = archiveBatch(testCase, stem, tail, editArchive)
% an ingested epoch as B and Dab hold it: the epochfiles_ingested manifest,
% and the v1 archive mfdaq.m ingest_epochfiles wrote for the same epoch and
% reader (NDI-matlab 73f46d1): the template's file_list, channel_list.bin and
% the segments attached in the writer's order, one clock. EDITARCHIVE
% (optional) changes the v1 archive before the migration.
arguments
    testCase
    stem
    tail
    editArchive = []
end
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = ['41268b6f5c6a3d4e_00000000000000' tail];
bodies = {sessionV1([stem '_sess'], sid), subjectV1([stem '_spec'], sid, 'L'), ...
    elementV1([stem '_probe'], sid, 'p', 1, 'n-trode', [stem '_spec']), ...
    daqsystemV1([stem '_daq'], sid, 'intan1', [stem '_nav']), ...
    manifestV1([stem '_efi'], sid, 't0001', [stem '_nav'], ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'p\t1\tn-trode\tintan1:ai1-2\tL\n'])), ...
    archiveV1([stem '_arc'], sid, 't0001', ['rdr_' stem '_daq'])};
if ~isempty(editArchive)
    bodies{end} = editArchive(bodies{end});
end
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
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

function testAProbeWithASortedUnitReadsItsSubjectFromItsRecordingOnly(testCase)
% the probe's `observes` relation is retired by its recording observation; the
% spike train of a unit sorted from it ([spike trains as epoch bodies]) is a
% second observation with the probe as instrument and the UNIT as entity. The
% unit (`derived_from` the probe) is not the probe's specimen, so subject_id
% and direct are rebuilt from the recording alone (Soph corpus run
% 44473899940: 61 probes reported "1 + their units" specimens and lost both)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = '41268b6f5c6a3d4e_00000000000000b4';
probe = elementV1('wb_probe_u', sid, 'p', 1, 'n-trode', 'wb_spec_u');
probe.depends_on = struct('name', {'underlying_element_id', 'subject_id'}, ...
    'value', {'', 'wb_spec_u'});
unit = elementV1('wb_unit_u', sid, 'p_1', 1, 'spikes', 'wb_spec_u');
unit.depends_on = struct('name', {'underlying_element_id', 'subject_id'}, ...
    'value', {'wb_probe_u', 'wb_spec_u'});
unit.element.ndi_element_class = 'ndi.neuron';
unit.element.direct = 0;
bodies = {sessionV1('wb_sess_doc_u', sid), subjectV1('wb_spec_u', sid, 'L'), ...
    probe, unit, elementEpochV1('wb_ee_u', sid, 'wb_unit_u', 't0001'), ...
    daqsystemV1('wb_daq_u', sid, 'intan1', 'wb_nav_u'), ...
    manifestV1('wb_efi_u', sid, 't0001', 'wb_nav_u', ...
        sprintf(['name\treference\ttype\tdevicestring\tsubjectstring\n' ...
        'p\t1\tn-trode\tintan1:ai27-28,45;di0-2\tL\n']))};
bodies = cellfun(@(b) jsondecode(jsonencode(b)), bodies, 'UniformOutput', false);
% [sorted units are cells or groups]: a unit its sorting run labels single
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2', ...
    'UnitQualityLabels', {'wb_unit_u', 'single'});
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'did_v2');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'did_v2');
assertGreaterThanOrEqual(testCase, rep.observes_retired, 1, ...
    'premise: the pass retired the probe''s observes relation');
assertEqual(testCase, rep.spike_trains_emitted, 1, ...
    'premise: the unit has a spike train whose instrument is the probe');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyTrue(testCase, isfield(r.compared_after_batch_pass_by_class, 'element'), describe(r));
for k = 1:numel(r.failures)
    if strcmp(r.failures(k).source_id, 'wb_probe_u')
        verifyFalse(testCase, any(startsWith(r.failures(k).lost, 'depends_on')), describe(r));
        verifyFalse(testCase, any(strcmp(r.failures(k).lost, 'element.direct')), describe(r));
        verifyFalse(testCase, any(contains(r.failures(k).unplaced, 'specimens')), describe(r));
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

function testADeferredPyraviewIsComparedOnEveryDocumentItsReRunMade(testCase)
% pass 1 defers a pyraview that names an epoch (did2:convert:needsEpochContext);
% did2.convert.epochMint (resolveDeferredPyraviews) re-runs it through
% v1_to_v2 once the epoch exists, and records what the re-run made of it
% (result.batch_pass_outputs). The whole-batch round trip compares the source
% on all of those documents and the epoch its anchor names. Before the record
% it was handed only the observation that holds the v1 id, and PRED's one
% pyraview read "no level body was emitted" (DID-matlab Test code run
% 43169466173, PR #450) while its level bodies were in the batch.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
pv = pyraviewV1('high');
sid = pv.base.session_id;
bodies = {jsondecode(jsonencode(sessionV1('wb_pv_sess', sid))), pv};
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
assertEqual(testCase, numel(result.quarantine), 1, 'pass 1 defers the pyraview');
verifyEqual(testCase, result.quarantine(1).identifier, 'did2:convert:needsEpochContext');
[result, rep] = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'did_v2');
assertEqual(testCase, rep.pyraview_deferred_resolved, 1, 'epochMint folds it');
assertTrue(testCase, isfield(result, 'batch_pass_outputs'));
k = find(strcmp({result.batch_pass_outputs.id}, pv.base.id));
assertNumElements(testCase, k, 1, 'the pass records what the pyraview became');
rec = result.batch_pass_outputs(k);
verifyGreaterThan(testCase, numel(rec.output_ids), 1, 'more than the observation');
verifyTrue(testCase, any(strcmp(rec.output_ids, pv.base.id)), 'the observation keeps the v1 id');
verifyNumElements(testCase, rec.context_ids, 1, 'the epoch its anchor names');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyTrue(testCase, isfield(r.resolved_by_batch_pass_by_class, 'pyraview'), describe(r));
verifyFalse(testCase, isfield(r.changed_by_class, 'pyraview'), describe(r));
verifyFalse(testCase, isfield(r.failures_by_class, 'pyraview'), describe(r));
verifyEqual(testCase, r.sources_still_quarantined, 0);
% without the record: the reading of run 43169466173 (the check can fail)
r = did2.convert.roundtrip.wholeBatch(bodies, rmfield(result, 'batch_pass_outputs'));
assertTrue(testCase, isfield(r.failures_by_class, 'pyraview'), describe(r));
f = r.failures(strcmp({r.failures.class_name}, 'pyraview'));
verifyTrue(testCase, any(strcmp(f(1).unplaced, 'no level body was emitted')), describe(r));
% one of its level bodies removed by a later step: changed, not compared
lv = '';
for j = 1:numel(result.migrated)
    s = result.migrated{j}.toStruct();
    if strcmp(char(s.document_class.class_name), 'sampled_body') ...
            && any(strcmp(rec.output_ids, char(s.base.id)))
        lv = char(s.base.id);
        break;
    end
end
assertNotEmpty(testCase, lv, 'a level body is among what it became');
keep = true(1, numel(result.migrated));
for j = 1:numel(result.migrated)
    keep(j) = ~strcmp(char(result.migrated{j}.get('base.id')), lv);
end
result.migrated = result.migrated(keep);
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyTrue(testCase, isfield(r.changed_by_class, 'pyraview'), describe(r));
verifyFalse(testCase, isfield(r.failures_by_class, 'pyraview'), describe(r));
end

function d = pyraviewV1(band)
% makePyraviewDoc(probe, 'EST_VISUAL_PREDROGA', BAND) on corpus PRED's probe,
% as testRawV1RoundTripPyraview builds it (NDI-matlab main
% +ndi/+gui/+app/+pyraview/makePyraviewDoc.m, its filter from filterData.m)
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
d.filter = struct('label', band, 'type', band, 'algorithm', 'chebyshev_1', ...
    'parameters', struct('sampleFrequency', sr, 'order', 4, ...
    'filterFrequency', 300, 'passBandRipple', 0.8, 'stopbandAttentuation', NaN));
d.epochclocktimes = struct('clocktype', 'dev_local_time', 't0_t1', [t0; t1]);
d = did2.unittest.helpers.setDependency(d, 'element_id', '41269628e2a03088_c085f412b5d8c08d');
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

function v1 = elementEpochV1(id, sid, elementId, epochId)
% an element_epoch as ndi.element/addepoch writes it, its samples attached as
% epoch_binary_data.vhsb
v1 = struct();
v1.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', [struct('class_name', 'base', 'class_version', '1.0.0'), ...
                     struct('class_name', 'epochid', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', 'element_id', 'value', elementId);
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0 10]);
v1.epochid = struct('epochid', epochId);
v1.files = struct('file_list', {{'epoch_binary_data.vhsb'}}, ...
    'file_info', struct('name', 'epoch_binary_data.vhsb', 'locations', ...
        struct('delete_original', 0, 'uid', 'vhsb_u', ...
            'location', ['/data/' epochId '/unit.vhsb'], 'parameters', '', ...
            'location_type', 'file', 'ingest', 1)));
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

function v1 = archiveV1(id, sid, epochId, readerId)
% a v1 daqreader_mfdaq_epochdata_ingested as NDI-matlab's mfdaq.m
% ingest_epochfiles writes it (73f46d1): its template's file_list
% (tests/+did2/fixtures/ndi_templates), the channel list and each segment
% attached in plan order, the segment lengths it sets
thisDir = fileparts(mfilename('fullpath'));
tmpl = jsondecode(fileread(fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', ...
    'daqreader_mfdaq_epochdata_ingested.json')));
v1 = struct();
v1.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/ingestion/daqreader_mfdaq_epochdata_ingested.json', ...
    'validation', '$NDISCHEMAPATH/ingestion/daqreader_mfdaq_epochdata_ingested_schema.json', ...
    'class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'property_list_name', 'daqreader_mfdaq_epochdata_ingested', 'class_version', 1, ...
    'superclasses', struct('definition', {'$NDIDOCUMENTPATH/base.json', ...
        '$NDIDOCUMENTPATH/epochid.json', ...
        '$NDIDOCUMENTPATH/ingestion/daqreader_epochdata_ingested.json'}));
v1.base = struct('id', id, 'session_id', sid, 'name', '', ...
    'datestamp', '2024-03-20T13:48:13.459Z');
v1.depends_on = struct('name', 'daqreader_id', 'value', readerId);
v1.epochid = struct('epochid', epochId);
v1.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0; 348.66121599999997]));
v1.daqreader_mfdaq_epochdata_ingested = struct('parameters', ...
    struct('sample_analog_segment', 1e6, 'sample_digital_segment', 1e7));
loc = @(u) struct('delete_original', 0, 'uid', [id '_' u], ...
    'location', ['ndic://ds/' id '_' u], 'parameters', '', ...
    'location_type', 'ndicloud', 'ingest', 0);
v1.files = struct('file_list', {tmpl.files.file_list}, ...
    'file_info', struct('name', {'channel_list.bin', 'ai_group1_seg.nbf_1', ...
        'ai_group1_seg.nbf_2', 'ti_group1_seg.nbf_1', 'ti_group1_seg.nbf_2', ...
        'evmktx_group1_seg.nbf_1'}, ...
    'locations', {loc('c'), loc('a1'), loc('a2'), loc('t1'), loc('t2'), loc('e1')}));
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
