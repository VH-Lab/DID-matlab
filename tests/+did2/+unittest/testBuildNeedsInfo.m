function tests = testBuildNeedsInfo
%TESTBUILDNEEDSINFO A required field may be left out only when needs_info names it.
%
%   [missing facts are needs info] (Jess Haley, 2026-10-29, did-schema
%   V_eta_go_forward_class_audit.md): a document records a fact its source
%   never stated as a `needs_info` entry {field, reason} on its base block; a
%   required field may be absent only when an entry names it, and an entry
%   must not name a field the document gives. First use: a probe's
%   coordinate system, whose reference point v1 never states.
%
%   did-schema declares `base.needs_info` after this lands (siblings first),
%   so each test runs on a copy of the schema in which the test declares it,
%   unless the loaded base already does.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   CI is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testBuildNeedsInfo');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build needs_info tests');
% made-up ids, registered-or-not terms: the builder's mechanics are tested
% here, not the term registry (testBuildTermRegistry tests that)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
cache = did2.schema.cache.shared();
src = cache.schemaPath;
testCase.TestData.schemaPath = src;
if ~cache.hasClass('coordinate_system') || ~cache.hasClass('base')
    assumeFail(testCase, sprintf('the loaded schema (%s) has no coordinate_system class', src));
end
baseNames = cellfun(@(d) char(d.name), cache.ownFields('base'), 'UniformOutput', false);
testCase.TestData.declaredUpstream = any(strcmp(baseNames, 'needs_info'));
tmp = tempname;
mkdir(tmp);
testCase.TestData.tmp = tmp;
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
if ~testCase.TestData.declaredUpstream
    declareNeedsInfo(testCase, fullfile(tmp, 'base.json'));
end
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
testCase.TestData.sid = did.ido.unique_id();
end

% ===================== the builder =========================================

function testARequiredFieldNamedInNeedsInfoMayBeLeftOut(testCase)
ni = struct('field', 'coordinate_system.reference_point', ...
    'reason', 'v1 probe_geometry does not state where zero is');
doc = buildCS(testCase, rmfield(csFields(), 'reference_point'), ni);
verifyFalse(testCase, isfield(doc.coordinate_system, 'reference_point'));
verifyEqual(testCase, doc.base.needs_info(1).field, 'coordinate_system.reference_point');
verifyEqual(testCase, doc.base.needs_info(1).reason, ni.reason);
% and the validator accepts it (did2.build validated it already; once more
% on its own so a failure names the validator)
did2.schema.cache.shared().validateDocument(doc);
end

function testARequiredFieldNotNamedIsStillRequired(testCase)
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), []), ...
    'did2:build:missingField');
other = struct('field', 'coordinate_system.axes(1).positive_direction', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), other), ...
    'did2:build:missingField', 'an entry for another field excuses nothing here');
end

function testANestedFieldIsNamedByItsElementPath(testCase)
f = csFields();
f.axes = rmfield(f.axes, 'positive_direction');
ni = struct('field', 'coordinate_system.axes(1).positive_direction', ...
    'reason', 'v1 does not state which way depth runs');
doc = buildCS(testCase, f, ni);
verifyFalse(testCase, isfield(doc.coordinate_system.axes, 'positive_direction'));
wrong = struct('field', 'coordinate_system.axes(2).positive_direction', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, f, wrong), 'did2:build:missingField');
end

function testAnEntryForAGivenFieldIsRefused(testCase)
ni = struct('field', 'coordinate_system.reference_point', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, csFields(), ni), 'did2:build:badNeedsInfo');
noReason = struct('field', 'coordinate_system.reference_point', 'reason', '');
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), noReason), ...
    'did2:build:badNeedsInfo');
end

function testAConditionWhoseCanonicalIsNamedHoldsItsSourceValue(testCase)
% conditions_one_value ([missing facts are needs info]; [canonical absent only
% as needs info], Jess Haley, 2026-10-30): a quantity condition that keeps its
% source_value, its canonical absent and named in needs_info, holds ONE value
% (first use: an image stack's acquisition time on a clock that is not UTC,
% [acquisition time on its clock]). Unnamed, it still holds none and is refused.
cond = did2.build.composite('statement', 'conditions', struct( ...
    'variable', did2.build.term('AFO:AFR_0001158', 'acquisition time'), ...
    'quantity', struct('source_value', '739038.5')));
ni = struct('field', 'statement.conditions(1).quantity.value', ...
    'reason', 'a datenum on a clock that is not UTC');
doc = buildObs(testCase, cond, ni);
verifyFalse(testCase, isfield(doc.statement.conditions(1).quantity, 'value'));
verifyEqual(testCase, doc.base.needs_info(1).field, ni.field);
verifyError(testCase, @() buildObs(testCase, cond, []), 'did2:build:ruleViolated', ...
    'a condition with no value and nothing named in needs_info holds none');
other = struct('field', 'statement.conditions(2).quantity.value', 'reason', 'r');
verifyError(testCase, @() buildObs(testCase, cond, other), 'did2:build:ruleViolated', ...
    'an entry for another condition excuses nothing here');
end

function doc = buildObs(testCase, conditions, needsInfo)
args = {'SessionId', testCase.TestData.sid, 'TimeReferenceIds', {did.ido.unique_id()}, ...
    'Conditions', conditions, 'ValueKind', 'voltage'};
if ~isempty(needsInfo)
    args = [args, {'NeedsInfo', needsInfo}];
end
doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), args{:});
end

% ===================== the validator =======================================

function testTheValidatorReadsNeedsInfo(testCase)
cache = did2.schema.cache.shared();
ni = struct('field', 'coordinate_system.reference_point', 'reason', 'unstated');
doc = buildCS(testCase, rmfield(csFields(), 'reference_point'), ni);
% the same document without its entry: the required field is missing
bare = doc;
bare.base = rmfield(bare.base, 'needs_info');
verifyError(testCase, @() cache.validateDocument(bare), 'did2:validation:missingField');
% an entry naming a field the document gives says something false
full = buildCS(testCase, csFields(), []);
full.base.needs_info = ni;
verifyError(testCase, @() cache.validateDocument(full), 'did2:validation:badNeedsInfo');
end

function testNeedsInfoNeedsASchemaThatDeclaresIt(testCase)
if testCase.TestData.declaredUpstream
    return;   % the loaded schema declares it: nothing to refuse
end
did2.schema.cache.setSchemaPath(testCase.TestData.schemaPath);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(testCase.TestData.tmp));
ni = struct('field', 'coordinate_system.reference_point', 'reason', 'r');
verifyError(testCase, @() buildCS(testCase, rmfield(csFields(), 'reference_point'), ni), ...
    'did2:build:needsInfoNotDeclared');
end

% ===================== helpers =============================================

function f = csFields()
f = struct();
f.reference_point = did2.build.term('EMPTY:0000310', 'image upper-left corner');
f.axes = struct('axis', did2.build.term('STATO:0000006', 'x-axis'), ...
    'positive_direction', did2.build.term('EMPTY:0000311', 'image right'));
end

function doc = buildCS(testCase, fields, needsInfo)
args = {'SessionId', testCase.TestData.sid, ...
    'Edges', struct('referent_id', did.ido.unique_id())};
if ~isempty(needsInfo)
    args = [args, {'NeedsInfo', needsInfo}];
end
doc = did2.build.document('coordinate_system', fields, args{:});
end

function declareNeedsInfo(testCase, baseFile)
% Insert a `needs_info` declaration into base's own field list, as text (as
% testBuild's testADeclaredCoordinateSystemEdgeIsReadFromTheSchema does).
jsonText = fileread(baseFile);
at = strfind(jsonText, '"fields": [');
assertNotEmpty(testCase, at, 'base.json declares no fields list');
at = at(1) + numel('"fields": [') - 1;
txt = @(n) sprintf(['{"name": "%s", "type": "char", "blank_value": "", ' ...
    '"default_value": "", "mustBeNonEmpty": true, "mustBeScalar": true, ' ...
    '"mustNotHaveNaN": false, "queryable": true, "ontology": null, ' ...
    '"documentation": "declared for this test", "constraints": {}}'], n);
decl = ['{"name": "needs_info", "type": "structure", "blank_value": [], ' ...
    '"default_value": [], "mustBeNonEmpty": false, "mustBeScalar": false, ' ...
    '"mustNotHaveNaN": false, "queryable": true, "ontology": null, ' ...
    '"documentation": "declared for this test", "constraints": {}, ' ...
    '"fields": [' txt('field') ', ' txt('reason') ']}, '];
jsonText = [jsonText(1:at) decl jsonText(at+1:end)];
fid = fopen(baseFile, 'w');
fwrite(fid, jsonText);
fclose(fid);
end
