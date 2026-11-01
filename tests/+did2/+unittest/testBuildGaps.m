function tests = testBuildGaps
%TESTBUILDGAPS A required field may be left out only when the run's migration report lists it.
%
%   Decided by Jess Haley, 2026-11-01 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): [migration record] drops
%   `base.needs_info`, so a document no longer says what its source left out;
%   [gap accepted when the report lists it]: "a migrated document may lack a
%   required field only when its run's migration report lists that document
%   and field with a reason; any other missing required field fails
%   validation". did2.build.document 'Gaps' lists them in the run's report
%   (did2.convert.migrationReport); the validator reads them there by the
%   document's id. First use: a probe's coordinate system, whose reference
%   point v1 never states.
%
%   Run with:  results = runtests('did2.unittest.testBuildGaps');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build gap tests');
% made-up ids, registered-or-not terms: the builder's mechanics are tested
% here, not the term registry (testBuildTermRegistry tests that)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
cache = did2.schema.cache.shared();
if ~cache.hasClass('coordinate_system') || ~cache.hasClass('base')
    assumeFail(testCase, sprintf('the loaded schema (%s) has no coordinate_system class', ...
        char(cache.schemaPath)));
end
testCase.TestData.sid = did.ido.unique_id();
end

function setup(testCase) %#ok<INUSD>
did2.convert.migrationReport('begin');
end

function teardown(testCase) %#ok<INUSD>
did2.convert.migrationReport('end');
end

% ===================== the builder =========================================

function testARequiredFieldListedAsAGapMayBeLeftOut(testCase)
g = struct('field', 'coordinate_system.reference_point', ...
    'reason', 'v1 probe_geometry does not state where zero is');
doc = buildCS(testCase, rmfield(csFields(), 'reference_point'), g);
verifyFalse(testCase, isfield(doc.coordinate_system, 'reference_point'));
% the document says nothing about it; the run's report lists it
verifyFalse(testCase, isfield(doc.base, 'needs_info'));
listed = did2.convert.migrationReport('gaps', doc.base.id);
verifyEqual(testCase, {listed.field}, {'coordinate_system.reference_point'});
verifyEqual(testCase, listed(1).reason, g.reason);
% and the validator accepts it (did2.build validated it already; once more
% on its own so a failure names the validator)
did2.schema.cache.shared().validateDocument(doc);
end

function testARequiredFieldNotListedIsStillRequired(testCase)
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), []), ...
    'did2:build:missingField');
other = struct('field', 'coordinate_system.axes(1).positive_direction', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), other), ...
    'did2:build:missingField', 'a gap for another field excuses nothing here');
end

function testANestedFieldIsNamedByItsElementPath(testCase)
f = csFields();
f.axes = rmfield(f.axes, 'positive_direction');
g = struct('field', 'coordinate_system.axes(1).positive_direction', ...
    'reason', 'v1 does not state which way depth runs');
doc = buildCS(testCase, f, g);
verifyFalse(testCase, isfield(doc.coordinate_system.axes, 'positive_direction'));
wrong = struct('field', 'coordinate_system.axes(2).positive_direction', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, f, wrong), 'did2:build:missingField');
end

function testAGapForAGivenFieldIsRefused(testCase)
g = struct('field', 'coordinate_system.reference_point', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, csFields(), g), 'did2:build:badGap');
noReason = struct('field', 'coordinate_system.reference_point', 'reason', '');
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), noReason), ...
    'did2:build:badGap');
end

function testAConditionWhoseCanonicalIsListedHoldsItsSourceValue(testCase)
% conditions_one_value ([canonical absent only as needs info], Jess Haley,
% 2026-10-30): a quantity condition that keeps its source_value, its canonical
% absent and listed as a gap, holds ONE value (first use: an image stack's
% acquisition time on a clock that is not UTC, [acquisition time on its
% clock]). Unlisted, it still holds none and is refused.
cond = did2.build.composite('statement', 'conditions', struct( ...
    'variable', did2.build.term('AFO:AFR_0001158', 'acquisition time'), ...
    'quantity', struct('source_value', '739038.5')));
g = struct('field', 'statement.conditions(1).quantity.value', ...
    'reason', 'a datenum on a clock that is not UTC');
doc = buildObs(testCase, cond, g);
verifyFalse(testCase, isfield(doc.statement.conditions(1).quantity, 'value'));
listed = did2.convert.migrationReport('gaps', doc.base.id);
verifyEqual(testCase, listed(1).field, g.field);
verifyError(testCase, @() buildObs(testCase, cond, []), 'did2:build:ruleViolated', ...
    'a condition with no value and no gap listed holds none');
other = struct('field', 'statement.conditions(2).quantity.value', 'reason', 'r');
verifyError(testCase, @() buildObs(testCase, cond, other), 'did2:build:ruleViolated', ...
    'a gap for another condition excuses nothing here');
end

function testReportedGapNamesValueReadsThePath(testCase)
% did2.schema.reportedGapNamesValue: the value, or a field within it, by path
cases = {'formulation.value.ingredients(1).concentration', true; ...
    'formulation.value', true; 'value', true; 'statement.value(2).x', true; ...
    'formulation.values', false; 'statement.value_id', false; ...
    'formulation.data_type', false};
for k = 1:size(cases, 1)
    did2.convert.migrationReport('begin');
    id = sprintf('doc%d', k);
    did2.convert.migrationReport('gap', id, 'formulation', cases{k, 1}, 'not stated');
    s = struct('base', struct('id', id));
    verifyEqual(testCase, did2.schema.reportedGapNamesValue(s), cases{k, 2}, cases{k, 1});
    verifyFalse(testCase, did2.schema.reportedGapNamesValue( ...
        struct('base', struct('id', 'another'))), 'a gap of another document');
end
did2.convert.migrationReport('end');
s = struct('base', struct('id', 'doc1'));
verifyFalse(testCase, did2.schema.reportedGapNamesValue(s), 'no run held');
end

function testABlankValueListedAsAGapIsAccepted(testCase)
% value_inline_or_body, [formulation amount needs info] (Decided by Jess Haley,
% 2026-10-31; docs/V2_PLAN.md G67 (a)): the value rule accepts a blank value
% whose gap is recorded -- a formulation in which no ingredient states an
% amount. The builder and the validator both accept it; unlisted, or listed
% for another field, it is refused as before.
cache = did2.schema.cache.shared();
if ~cache.hasClass('formulation') || ~cache.hasClass('chemical')
    assumeFail(testCase, 'the loaded schema has no formulation class');
end
sid = testCase.TestData.sid;
chem = did2.build.document('chemical', struct('value', struct('substance', ...
    did2.build.term('CHEBI:7035', 'muscimol'))), 'SessionId', sid);
value = struct('ingredients', {{struct()}});
edges = struct('ingredient_id', {{chem.base.id}});
g = struct('field', 'formulation.value.ingredients(1).concentration', ...
    'reason', 'the source lists this ingredient but states no amount');
doc = did2.build.document('formulation', struct('value', value), ...
    'SessionId', sid, 'Edges', edges, 'Gaps', g);
verifyFalse(testCase, isfield(doc.base, 'needs_info'));
cache.validateDocument(jsondecode(jsonencode(doc)));
verifyError(testCase, @() did2.build.document('formulation', struct('value', value), ...
    'SessionId', sid, 'Edges', edges), 'did2:build:ruleViolated', ...
    'a blank value no gap lists is nowhere');
other = struct('field', 'formulation.data_type', 'reason', 'not stated');
verifyError(testCase, @() did2.build.document('formulation', struct('value', value), ...
    'SessionId', sid, 'Edges', edges, 'Gaps', other), 'did2:build:ruleViolated', ...
    'a gap for a field outside the value excuses nothing');
end

% ===================== the validator =======================================

function testTheValidatorReadsTheRunsReport(testCase)
cache = did2.schema.cache.shared();
g = struct('field', 'coordinate_system.reference_point', 'reason', 'unstated');
doc = buildCS(testCase, rmfield(csFields(), 'reference_point'), g);
cache.validateDocument(doc);
% without the run's report, the required field is missing ("Re-validating
% migrated documents without the report fails on those fields")
r = did2.convert.migrationReport('collect', {doc});
did2.convert.migrationReport('end');
verifyError(testCase, @() cache.validateDocument(doc), 'did2:validation:missingField');
% loaded again (from the attached file's JSON), it is accepted
did2.convert.migrationReport('load', jsondecode(jsonencode(r)));
cache.validateDocument(doc);
% a gap naming a field the document gives says something false
full = buildCS(testCase, csFields(), []);
did2.convert.migrationReport('gap', full.base.id, 'coordinate_system', g.field, g.reason);
verifyError(testCase, @() cache.validateDocument(full), 'did2:validation:badGap');
end

% ===================== the report ==========================================

function testTheReportListsGapsOfTheDocumentsWritten(testCase)
g = struct('field', 'coordinate_system.reference_point', 'reason', 'unstated');
kept = buildCS(testCase, rmfield(csFields(), 'reference_point'), g);
dropped = buildCS(testCase, rmfield(csFields(), 'reference_point'), g);
r = did2.convert.migrationReport('collect', {kept});
verifyEqual(testCase, {r.gaps.document_id}, {kept.base.id}, ...
    'a gap of a document the run does not write is not reported');
verifyEqual(testCase, r.gaps(1).class, 'coordinate_system');
verifyEqual(testCase, r.gaps(1).field, g.field);
verifyEqual(testCase, r.gaps(1).reason, g.reason);
verifyEqual(testCase, r.counts.documents, 1);
verifyEqual(testCase, r.counts.gaps, 1);
verifyEqual(testCase, r.counts.documents_with_gaps, 1);
verifyEqual(testCase, r.counts.carried_as_v1, 0);
verifyNotEqual(testCase, dropped.base.id, kept.base.id);
end

function testTheReportCountsCarriesByRegisterRow(testCase)
% practice (d) of [migration reliability practices] (Jess Haley, 2026-10-26):
% carries counted by carry register row, with the denominator
v1 = @(id) struct('document_class', struct('class_name', 'stimulus_response', ...
    'schema_version', 'did_v1'), 'base', struct('id', id));
did2.convert.reportNote('reset');
did2.convert.reportNote('carried_as_v1', 'stimulus_response', 'a', '[carry-022] needs_mapping: x');
did2.convert.reportNote('carried_as_v1', 'stimulus_response', 'b', ...
    '[carry-022] one; [carry-100] two');
r = did2.convert.migrationReport('collect', {v1('a'), v1('b'), v1('c')});
verifyEqual(testCase, {r.carried_as_v1.document_id}, {'a', 'b', 'c'});
verifyEqual(testCase, r.carried_as_v1(2).carry, 'carry-022, carry-100');
verifyEqual(testCase, r.carried_as_v1(3).carry, '', ...
    'a v1 document with no recorded carry is still listed');
verifyEqual(testCase, r.counts.carried_as_v1, 3);
verifyEqual(testCase, {r.counts.carried_by_register_row.row}, {'carry-022', 'carry-100'});
verifyEqual(testCase, [r.counts.carried_by_register_row.count], [2 1]);
verifyEqual(testCase, r.counts.carried_citing_a_row, 2);
verifyEqual(testCase, r.counts.carried_citing_no_row, 1);
did2.convert.reportNote('reset');
end

% ===================== helpers =============================================

function doc = buildObs(testCase, conditions, gaps)
args = {'SessionId', testCase.TestData.sid, 'TimeReferenceIds', {did.ido.unique_id()}, ...
    'Conditions', conditions, 'ValueKind', 'voltage'};
if ~isempty(gaps)
    args = [args, {'Gaps', gaps}];
end
doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), args{:});
end

function f = csFields()
f = struct();
f.reference_point = did2.build.term('EMPTY:0000310', 'image upper-left corner');
f.axes = struct('axis', did2.build.term('STATO:0000006', 'x-axis'), ...
    'positive_direction', did2.build.term('EMPTY:0000311', 'image right'));
end

function doc = buildCS(testCase, fields, gaps)
args = {'SessionId', testCase.TestData.sid, ...
    'Edges', struct('referent_id', did.ido.unique_id())};
if ~isempty(gaps)
    args = [args, {'Gaps', gaps}];
end
doc = did2.build.document('coordinate_system', fields, args{:});
end
