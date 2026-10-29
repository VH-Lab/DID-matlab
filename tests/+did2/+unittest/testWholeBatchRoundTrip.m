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

function testAPassthroughStillUnchangedIsStoredAsItsV1Source(testCase)
% an ontologyTableRow with no subject edge passes pass 1 through unchanged for
% NDI's second pass; still unchanged at the end, the pipeline stores its v1
% source (ndi.migrate.internal.carryUnchangedAsV1), which is what is compared
[bodies, result] = cleanBatch();
bodies{end+1} = tableRow('wb_row_1');
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, any(strcmp({result.passthrough.id}, 'wb_row_1')), ...
    'pass 1 records the row as passed through');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyEqual(testCase, r.sources_compared, 4);
verifyEqual(testCase, r.sources_ok, 4, describe(r));
verifyGreaterThanOrEqual(testCase, r.sources_stored_as_v1, 1);
verifyTrue(testCase, isfield(r.stored_as_v1_by_class, 'ontology_table_row'), ...
    'the row is counted as stored as its v1 source');
verifyEqual(testCase, r.sources_no_inverse, 0);
end

function testAPassthroughALaterStepChangedIsNotStoredAsV1(testCase)
% the same row, changed after pass 1: it is no longer stored as its v1 source,
% so it is compared as it is (and its class has no inverse)
[bodies, result] = cleanBatch();
bodies{end+1} = tableRow('wb_row_1');
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
for k = 1:numel(result.migrated)
    s = result.migrated{k}.toStruct();
    if strcmp(char(s.base.id), 'wb_row_1')
        s.base.name = 'changed by a later step';
        result.migrated{k} = did2.document(s);
    end
end
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyFalse(testCase, isfield(r.stored_as_v1_by_class, 'ontology_table_row'));
verifyEqual(testCase, r.sources_no_inverse, 1);
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
result = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'V_eta');
result = did2.convert.epochMint(result, 'Validate', false, 'TargetVersion', 'V_eta');
result = did2.convert.resolveSessionAnchors(result, 'Validate', true, 'TargetVersion', 'V_eta');
[result, rep] = did2.convert.resolveEpochProbemap(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.manifests_renamed, 1, 'the manifest is renamed');
r = did2.convert.roundtrip.wholeBatch(bodies, result);
verifyFalse(testCase, isfield(r.changed_by_class, 'epochfiles_ingested'), describe(r));
verifyFalse(testCase, isfield(r.no_inverse_by_class, 'epochfiles_ingested'), describe(r));
verifyFalse(testCase, isfield(r.failures_by_class, 'epochfiles_ingested'), describe(r));
end

function testAnOpenmindsSubjectRoundTripsWithTheSpeciesTextAccepted(testCase)
% INVERTED 2026-10-29 from testAnOpenmindsSubjectRoundTrips, which asserted the
% species' definition and synonym were LOST. Decided by Jess Haley, 2026-10-29
% [species text is the openMINDS equivalent] (did-schema
% V_eta_go_forward_class_audit.md): they are not stored in V2 (the registry
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
out = did2.convert.v1_to_v2({sex}, 'Validate', false, 'TargetVersion', 'V_eta');
r = did2.convert.roundtrip.check(sex, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_subject (sex)', {});
out = did2.convert.v1_to_v2({species}, 'Validate', false, 'TargetVersion', 'V_eta');
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
out = did2.convert.v1_to_v2({sex}, 'Validate', false, 'TargetVersion', 'V_eta');
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

function testAnOpenmindsElementWithAnIdAndADescriptionIsCarried(testCase)
% INVERTED 2026-10-29 from testAnOpenmindsElementReportsWhatItDoesNotKeep,
% which asserted the element was CONVERTED and its openminds_id and description
% LOST. Decided by Jess Haley, 2026-10-29 [openMINDS element leftovers carried]
% (did-schema V_eta_go_forward_class_audit.md): "a v1 `openminds_element`
% holding an `openminds_id` or a `fields.description` is carried whole as v1"
% (carry-128), so the round trip compares the carry and nothing is lost.
% Dab's shape: a cell type with an openMINDS id and a description
ct = openmindsV1('wb_om_ct', 'openminds_element', 'element_id', 'CellType', ...
    'type III BNST neuron', 'EMPTY:0000073', '', '');
ct.openminds.openminds_id = 'CellType/dc2f5dd6-5cea-477c-a035-ca2dd3e6649d';
ct.openminds.fields.description = 'A type of neuron.';
% openminds_element is read on the renamed path, so pass 1 hands back the
% renamed body as a passthrough and the pipeline stores the untouched v1 source
% (v1_to_v2.m, "A CARRY IS THE V1 SOURCE"; ndi.migrate.internal.
% carryUnchangedAsV1). Compare what is stored, as the table-row test does.
out = did2.convert.v1_to_v2({ct}, 'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, any(strcmp({out.passthrough.id}, 'wb_om_ct')), ...
    'pass 1 records the element as carried through');
r = did2.convert.roundtrip.wholeBatch({ct}, out);
verifyEqual(testCase, r.sources_compared, 1);
verifyEqual(testCase, r.sources_ok, 1, describe(r));
verifyTrue(testCase, isfield(r.stored_as_v1_by_class, 'openminds_element'), ...
    'the element is stored as its v1 source');
% each half alone carries too
for half = {'id', 'description'}
    one = ct;
    if strcmp(half{1}, 'id')
        one.openminds.fields.description = '';
    else
        one.openminds.openminds_id = '';
    end
    out = did2.convert.v1_to_v2({one}, 'Validate', false, 'TargetVersion', 'V_eta');
    verifyTrue(testCase, any(strcmp({out.passthrough.id}, 'wb_om_ct')), ...
        ['carried for its ' half{1} ' alone']);
end
end

function testAnOpenmindsElementWithNeitherConverts(testCase)
% the other side of [openMINDS element leftovers carried]: a cell type stating
% neither an openminds_id nor a description still converts to the term
% assertion, and round trips clean
ct = openmindsV1('wb_om_ct2', 'openminds_element', 'element_id', 'CellType', ...
    'type III BNST neuron', 'EMPTY:0000073', '', '');
out = did2.convert.v1_to_v2({ct}, 'Validate', false, 'TargetVersion', 'V_eta');
r = did2.convert.roundtrip.check(ct, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_element (converted)', {});
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
