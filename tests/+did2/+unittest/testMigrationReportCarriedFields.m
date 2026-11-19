function tests = testMigrationReportCarriedFields
%TESTMIGRATIONREPORTCARRIEDFIELDS The migration report's carried fields: add, list, count, load.
%
%   Decided by Jess Haley, 2026-11-19 (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md):
%     [one-field carry in the migration report]  the needing-information
%                          subject is held in a new "carried fields" list of
%                          the run's migration report: {document_id, class,
%                          field, value, carry, reason}, citing a
%                          field-scoped carry-register row (kind
%                          needs_mapping); written by NDI's second pass.
%     [stimulator subject carried as needing information],
%     [recording probe subject carried the same way]  its first use: an
%                          element's v1 `depends_on subject_id`, carry-172
%                          (did2.convert.carryElementSubject).
%
%   What is tested: did2.convert.migrationReport 'carriedField' (add),
%   'carriedFields' (list), 'collect' (the list and its counts, with the
%   denominator; kept for a document that converts, which is where a
%   whole-document carry entry is dropped), 'load' (from the stored report's
%   JSON), and the wrapper pair did2.convert.carryElementSubject /
%   did2.convert.carriedElementSubject.
%
%   Run with:  results = runtests('did2.unittest.testMigrationReportCarriedFields');

tests = functiontests(localfunctions);
end

function setup(testCase) %#ok<INUSD>
did2.convert.migrationReport('begin');
end

function teardown(testCase) %#ok<INUSD>
did2.convert.migrationReport('end');
end

% ===================== add and list ========================================

function testACarriedFieldIsListedForItsDocument(testCase)
did2.convert.migrationReport('carriedField', 'el_1', 'element', ...
    'depends_on subject_id', 'subj_1', '[carry-172]', 'no statement names it');
f = did2.convert.migrationReport('carriedFields', 'el_1');
assertEqual(testCase, numel(f), 1);
verifyEqual(testCase, f(1).field, 'depends_on subject_id');
verifyEqual(testCase, f(1).value, 'subj_1');
verifyEqual(testCase, f(1).carry, 'carry-172', 'the row, as its id');
verifyEqual(testCase, f(1).reason, 'no statement names it');
verifyEmpty(testCase, did2.convert.migrationReport('carriedFields', 'el_2'));
% never a gap, a defect or an input not found
verifyEmpty(testCase, did2.convert.migrationReport('gaps', 'el_1'));
verifyEmpty(testCase, did2.convert.migrationReport('defects', 'el_1'));
verifyEmpty(testCase, did2.convert.migrationReport('inputsNotFound', 'el_1'));
end

function testTheValueIsKeptAsAValueNotText(testCase)
v = struct('id', 'subj_9', 'epochs', [1 2 3]);
did2.convert.migrationReport('carriedField', 'el_v', 'element', 'x.y', v, ...
    'carry-172', 'kept as given');
did2.convert.migrationReport('carriedField', 'el_n', 'element', 'x.y', 42, ...
    'carry-172', 'a number');
f = did2.convert.migrationReport('carriedFields', 'el_v');
verifyEqual(testCase, f(1).value, v);
f = did2.convert.migrationReport('carriedFields', 'el_n');
verifyEqual(testCase, f(1).value, 42);
end

function testOneEntryPerDocumentAndFieldTheLatest(testCase)
did2.convert.migrationReport('carriedField', 'el_1', 'element', 'a', 'v1', 'carry-172', 'r1');
did2.convert.migrationReport('carriedField', 'el_1', 'element', 'b', 'v2', 'carry-172', 'r2');
did2.convert.migrationReport('carriedField', 'el_1', 'element', 'a', 'v3', 'carry-172', 'r3');
f = did2.convert.migrationReport('carriedFields', 'el_1');
verifyEqual(testCase, {f.field}, {'a', 'b'});
verifyEqual(testCase, {f.value}, {'v3', 'v2'});
verifyEqual(testCase, {f.reason}, {'r3', 'r2'});
end

function testACarriedFieldNeedsItsParts(testCase)
ok = {'el_1', 'element', 'f', 'v', 'carry-172', 'why'};
verifyError(testCase, @() did2.convert.migrationReport('carriedField', ok{1:5}), ...
    'did2:convert:badCarriedField', 'six arguments are needed');
blank = [1 3 5 6];
names = {'document id', '', 'field', '', 'carry row', 'reason'};
testCase.log(sprintf('DENOMINATOR: %d required part(s)', numel(blank)));
for k = blank
    a = ok;
    a{k} = '';
    verifyError(testCase, @() did2.convert.migrationReport('carriedField', a{:}), ...
        'did2:convert:badCarriedField', ['an empty ' names{k}]);
end
a = ok;
a{5} = 'no row here';
verifyError(testCase, @() did2.convert.migrationReport('carriedField', a{:}), ...
    'did2:convert:badCarriedField', 'a carry that cites no register row');
end

function testWithNoRunHeldAddingBeginsOne(testCase)
did2.convert.migrationReport('end');
verifyFalse(testCase, did2.convert.migrationReport('active'));
verifyEmpty(testCase, did2.convert.migrationReport('carriedFields', 'el_1'));
did2.convert.migrationReport('carriedField', 'el_1', 'element', 'f', 'v', 'carry-172', 'why');
verifyTrue(testCase, did2.convert.migrationReport('active'));
verifyEqual(testCase, numel(did2.convert.migrationReport('carriedFields', 'el_1')), 1);
end

% ===================== collect and count ===================================

function testCollectKeepsTheEntriesOfConvertedDocuments(testCase)
% unlike a `carried_as_v1` entry, a carried field is of a document that
% converts, so 'collect' keeps it for a v2 document
did2.convert.migrationReport('carriedField', 'el_a', 'element', ...
    'depends_on subject_id', 'subj_a', 'carry-172', 'no statement names it');
did2.convert.migrationReport('carriedField', 'el_b', 'element', ...
    'depends_on subject_id', 'subj_b', 'carry-172', 'no recording observation');
did2.convert.migrationReport('carriedField', 'el_gone', 'element', ...
    'depends_on subject_id', 'subj_g', 'carry-172', 'not written');
% the same document also once recorded as a whole-document carry: that
% entry is dropped for a document that converts, the carried field is not
did2.convert.migrationReport('carried', 'el_a', 'element', 'carry-064', 'earlier');
docs = {v2('el_a', 'entity'), v2('el_b', 'entity'), v2('other', 'assertion')};
r = did2.convert.migrationReport('collect', docs);
verifyTrue(testCase, isfield(r, 'carried_fields'));
verifyEqual(testCase, {r.carried_fields.document_id}, {'el_a', 'el_b'}, ...
    'in the order of DOCS; a document not written is not listed');
verifyEqual(testCase, {r.carried_fields.class}, {'element', 'element'});
verifyEqual(testCase, {r.carried_fields.field}, ...
    {'depends_on subject_id', 'depends_on subject_id'});
verifyEqual(testCase, {r.carried_fields.value}, {'subj_a', 'subj_b'});
verifyEqual(testCase, {r.carried_fields.carry}, {'carry-172', 'carry-172'});
verifyEmpty(testCase, r.carried_as_v1, 'a converted document is not a whole-document carry');
% the counts, with their denominators
verifyEqual(testCase, r.counts.documents, 3);
verifyEqual(testCase, r.counts.documents_converted, 3);
verifyEqual(testCase, r.counts.carried_fields, 2);
verifyEqual(testCase, r.counts.documents_with_carried_fields, 2);
verifyEqual(testCase, {r.counts.carried_fields_by_register_row.row}, {'carry-172'});
verifyEqual(testCase, [r.counts.carried_fields_by_register_row.count], 2);
end

function testADocumentCarriedWholeAsV1HoldsTheFieldItself(testCase)
did2.convert.migrationReport('carriedField', 'el_v1', 'element', ...
    'depends_on subject_id', 'subj_1', 'carry-172', 'why');
r = did2.convert.migrationReport('collect', {v1('el_v1', 'element'), v2('el_2', 'entity')});
verifyEmpty(testCase, r.carried_fields);
verifyEqual(testCase, r.counts.carried_fields, 0);
verifyEqual(testCase, r.counts.documents, 2);
verifyEqual(testCase, r.counts.documents_converted, 1);
verifyEqual(testCase, numel(r.carried_as_v1), 1, 'the v1 document is the carry');
end

function testTheReportHasNoCarriedFieldsWhenNoneIsListed(testCase)
r = did2.convert.migrationReport('collect', {v2('el_1', 'entity')});
verifyTrue(testCase, isfield(r, 'carried_fields'));
verifyEmpty(testCase, r.carried_fields);
verifyEqual(testCase, r.counts.carried_fields, 0);
verifyEqual(testCase, r.counts.documents_with_carried_fields, 0);
verifyEmpty(testCase, r.counts.carried_fields_by_register_row);
end

% ===================== load ================================================

function testCarriedFieldsSurviveTheStoredReport(testCase)
did2.convert.migrationReport('carriedField', 'el_a', 'element', ...
    'depends_on subject_id', 'subj_a', 'carry-172', 'no statement names it');
did2.convert.migrationReport('carriedField', 'el_b', 'element', ...
    'depends_on subject_id', 'subj_b', 'carry-172', 'no recording observation');
docs = {v2('el_a', 'entity'), v2('el_b', 'entity')};
r = did2.convert.migrationReport('collect', docs);
did2.convert.migrationReport('end');
verifyEmpty(testCase, did2.convert.migrationReport('carriedFields', 'el_a'));
% the attached file is JSON (did2.convert.migrationRecord writes
% jsonencode of the report)
did2.convert.migrationReport('load', jsondecode(jsonencode(r)));
f = did2.convert.migrationReport('carriedFields', 'el_b');
assertEqual(testCase, numel(f), 1);
verifyEqual(testCase, f(1).value, 'subj_b');
verifyEqual(testCase, f(1).carry, 'carry-172');
verifyEqual(testCase, f(1).reason, 'no recording observation');
r2 = did2.convert.migrationReport('collect', docs);
verifyEqual(testCase, r2.counts.carried_fields, 2);
verifyEqual(testCase, {r2.carried_fields.value}, {'subj_a', 'subj_b'});
% one entry alone decodes as a scalar struct, and loads the same way
r1 = did2.convert.migrationReport('collect', docs(1));
did2.convert.migrationReport('load', jsondecode(jsonencode(r1)));
[s, found] = did2.convert.carriedElementSubject('el_a');
verifyTrue(testCase, found);
verifyEqual(testCase, s, 'subj_a');
end

function testAnOlderReportWithNoCarriedFieldsLoads(testCase)
r = did2.convert.migrationReport('collect', {v2('el_a', 'entity')});
r = rmfield(r, 'carried_fields');
did2.convert.migrationReport('load', jsondecode(jsonencode(r)));
verifyEmpty(testCase, did2.convert.migrationReport('carriedFields', 'el_a'));
end

% ===================== the element-subject wrapper =========================

function testTheElementSubjectWrapperCitesCarry172(testCase)
did2.convert.carryElementSubject('el_stim', 'subj_7', ...
    'no stimulus presentation, bath manipulation or Stimulator manipulation names it');
f = did2.convert.migrationReport('carriedFields', 'el_stim');
assertEqual(testCase, numel(f), 1);
verifyEqual(testCase, f(1).field, 'depends_on subject_id');
verifyEqual(testCase, f(1).field, did2.convert.carriedElementSubject('field'));
verifyEqual(testCase, f(1).value, 'subj_7');
verifyEqual(testCase, f(1).carry, 'carry-172');
[s, found] = did2.convert.carriedElementSubject('el_stim');
verifyTrue(testCase, found);
verifyEqual(testCase, s, 'subj_7');
[s, found] = did2.convert.carriedElementSubject('el_none');
verifyFalse(testCase, found);
verifyEqual(testCase, s, '');
r = did2.convert.migrationReport('collect', {v2('el_stim', 'entity')});
verifyEqual(testCase, r.carried_fields(1).class, 'element', 'the v1 class of the field');
verifyEqual(testCase, r.counts.carried_fields, 1);
end

function testTheWrapperNeedsAllItsParts(testCase)
verifyError(testCase, @() did2.convert.carryElementSubject('', 'subj', 'why'), ...
    ?MException);
verifyError(testCase, @() did2.convert.carryElementSubject('el', '', 'why'), ...
    ?MException);
verifyError(testCase, @() did2.convert.carryElementSubject('el', 'subj', ''), ...
    ?MException);
end

function testAnotherFieldIsNotTheSubject(testCase)
did2.convert.migrationReport('carriedField', 'el_x', 'element', 'element.reference', ...
    'subj_x', 'carry-172', 'another field');
[~, found] = did2.convert.carriedElementSubject('el_x');
verifyFalse(testCase, found);
end

% ===================== helpers =============================================

function d = v2(id, cls)
d = struct('document_class', struct('class_name', cls, ...
    'schema_version', did2.schema.v2Stamp()), 'base', struct('id', id));
end

function d = v1(id, cls)
d = struct('document_class', struct('class_name', cls, ...
    'schema_version', 'did_v1'), 'base', struct('id', id));
end
