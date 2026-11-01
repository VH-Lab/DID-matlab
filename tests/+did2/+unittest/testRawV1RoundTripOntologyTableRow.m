function tests = testRawV1RoundTripOntologyTableRow
%TESTRAWV1ROUNDTRIPONTOLOGYTABLEROW ontologyTableRow read as raw v1, and its
%   round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a); 2026-10-30 [table rows carried as v1]
%   (carry-026: every row is carried whole as v1).
%
%   THE v1 DOCUMENTS are built from NDI's template at the locked NDI-matlab
%   `main` (441530d; tests/+did2/fixtures/ndi_templates, copied verbatim):
%   data/ontologyTableRow.json + base.json, in the shape
%   +ndi/+setup/+NDIMaker/tableDocMaker.m writes (the column names, variable
%   names and ontology nodes as comma-separated text, one row of data as a
%   struct, and the template's one edge, `document_id`).
%
%   v1 names the class `ontologyTableRow`; did2.convert.rawV1Classes joins it
%   to +migrators_j/ontology_table_row.m. The row is carried as the untouched
%   v1 source and round trips as itself. No known findings.
tests = functiontests(localfunctions);
end

function testTheClassIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'ontologyTableRow')));
verifyEqual(testCase, did2.convert.rawV1Classes('ontologyTableRow'), 'ontology_table_row');
verifyFalse(testCase, any(strcmp(did2.convert.rawV1Classes(), 'ontology_table_row')), ...
    'the switch is keyed on the v1 spelling');
out = runRaw(writerRow('otr_1'));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
end

function testAWriterRowIsCarriedUntouchedAndRoundTrips(testCase)
v1 = writerRow('otr_1');
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, '[carry-026] needs_mapping: '), notes);
s = out.migrated{1}.toStruct();
verifyEqual(testCase, s.document_class.class_name, 'ontologyTableRow', 'the v1 class name');
verifyTrue(testCase, isfield(s.ontologyTableRow, 'variableNames'), 'the v1 field spelling');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'ontologyTableRow', {});
end

function testAnyRowIsCarried(testCase)
% a subject edge or a field outside the template changes nothing: every row
% is carried with the same note
v1 = did2.unittest.helpers.setDependency(writerRow('otr_s'), 'subject_id', 'subj_1');
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-026] '), notes);
v1 = writerRow('otr_x');
v1.ontologyTableRow.units = 'g';
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-026] '), notes);
end

function testARowWithNoBlockStillQuarantines(testCase)
v1 = writerRow('otr_n');
v1 = rmfield(v1, 'ontologyTableRow');
out = runRaw(v1);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:missingBlock');
end

function testTheInverseOfAnUncarriedRowIsThePassthrough(testCase)
v1 = writerRow('otr_1');
[back, spec] = did2.convert.roundtrip.ontologyTableRow({v1});
verifyEmpty(testCase, spec.unplaced);
verifyEqual(testCase, back.ontologyTableRow, v1.ontologyTableRow);
[~, spec] = did2.convert.roundtrip.ontologyTableRow({v1, v1});
verifyNotEmpty(testCase, spec.unplaced);
end

% ===================== fixtures, from the TEMPLATE and WRITER ===========

function v1 = writerRow(id)
% tableDocMaker.m: ndi.document('ontologyTableRow', 'ontologyTableRow.names',
% ..., 'ontologyTableRow.variableNames', ..., 'ontologyTableRow.ontologyNodes',
% ..., 'ontologyTableRow.data', row) + the `document_id` dependency
v1 = did2.unittest.helpers.ndiDocument('ontologyTableRow', 'Id', id);
v1.ontologyTableRow.names = 'Subject identifier,Weight';
v1.ontologyTableRow.variableNames = 'SubjectIdentifier,Weight';
v1.ontologyTableRow.ontologyNodes = 'NCIT:C69256,PATO:0000128';
v1.ontologyTableRow.data = struct('SubjectIdentifier', 'mouse_1', 'Weight', 25.1);
v1 = did2.unittest.helpers.setDependency(v1, 'document_id', '41268b6f5c6a3d4e_0f000000000000d1');
v1 = jsondecode(jsonencode(v1));
end

% ===================== helpers =========================================

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end
