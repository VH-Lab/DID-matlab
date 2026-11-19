function tests = testBuildNumericShapeWriters
%TESTBUILDNUMERICSHAPEWRITERS Step 2 of [one shape for measured numbers]: the writers write the new shape.
%
%   Decided by Jess Haley, 2026-11-17, did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [one shape for measured numbers]
%   and [numeric shape details]. Its section 9, step 2: DID-matlab's writers
%   write the new numeric shape (did2.build.numericShape defaults to 'new';
%   step 1, testBuildNumericShape, made every builder and the validator read
%   both). Pinned here, beside testBuildNumericShape:
%
%     - did2.build.numericItem turns an item a caller assembled by hand in
%       the old shape (quantity, matrix, origin/spacing blocks) into the new
%       one, with every number in its one place, and leaves it alone in the
%       old shape;
%     - did2.build.sourceNumericField names a value cell's source field;
%     - [numeric shape details] (1): a condition's or parameter's source
%       number stays a number, its text stays text;
%     - [numeric shape details] (2): a relative time reference's start, end
%       and duration, and an absolute one's duration, write source_numeric;
%       an absolute start's and end's text keeps source_value;
%     - [numeric shape details] (3): a single number in a list item is written
%       plain in did2's JSON; an array keeps its dimensions; both read back.
%
%   UNVERIFIED: written without MATLAB; test-builder.yml runs it.
%
%   Run with:  results = runtests('did2.unittest.testBuildNumericShapeWriters');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping numeric shape writer tests');
% made-up terms ('depth', 'volt', ...) test the builder's mechanics, as in
% testBuild; the term registry check has its own tests
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
cache = did2.schema.cache.shared();
if ~cache.hasClass('data') || ~cache.hasClass('voltage') || ~cache.hasClass('relative_time_reference')
    assumeFail(testCase, sprintf(['the loaded schema (%s) has no data, voltage or ' ...
        'relative_time_reference class.'], cache.schemaPath));
end
testCase.TestData.sid = did.ido.unique_id();
prevShape = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prevShape));
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== numericItem ==========================================

function testNumericItemFlattensAQuantity(testCase)
old = struct('variable', struct('node', '', 'name', 'depth'), 'along', 0, ...
    'unit', struct('node', '', 'name', 'meter'), ...
    'quantity', struct('value', [1 2 3], 'source_value', [1000 2000 3000]));
c = did2.build.numericItem(old, 'new');
verifyFalse(testCase, isfield(c, 'quantity'));
verifyEqual(testCase, c.numeric, [1 2 3]);
verifyEqual(testCase, c.source_numeric, [1000 2000 3000]);
verifyEqual(testCase, c.unit, old.unit, 'unit is kept as it is');
verifyEqual(testCase, c.along, 0);
verifySameReading(testCase, old, c);
end

function testNumericItemFlattensOriginAndSpacing(testCase)
old = struct('variable', struct('node', '', 'name', 'time'), 'along', 0, ...
    'source_unit', struct('node', 'om:second-Time', 'name', 'second'), ...
    'origin', struct('value', 0, 'source_value', 0), ...
    'spacing', struct('value', 3.33e-5, 'source_value', 3.33e-5));
c = did2.build.numericItem(old, 'new');
verifyEqual(testCase, c.origin, 0);
verifyEqual(testCase, c.spacing, 3.33e-5);
verifyEqual(testCase, c.source_origin, 0);
verifyEqual(testCase, c.source_spacing, 3.33e-5);
verifySameReading(testCase, old, c);
end

function testNumericItemMatrixAndSourceOnly(testCase)
m = did2.build.numericItem(struct('variable', 'colour palette', 'matrix', [1 2; 3 4]), 'new');
verifyFalse(testCase, isfield(m, 'matrix'));
verifyEqual(testCase, m.numeric, [1 2; 3 4]);
% a number kept only as the source wrote it (its canonical a gap)
s = did2.build.numericItem(struct('variable', 'acquisition time', ...
    'quantity', struct('source_value', 739000.5)), 'new');
verifyFalse(testCase, isfield(s, 'numeric'));
verifyEqual(testCase, s.source_numeric, 739000.5);
end

function testNumericItemLeavesTheRestAlone(testCase)
old = struct('variable', 'depth', 'quantity', struct('value', 1));
verifyEqual(testCase, did2.build.numericItem(old, 'old'), old, 'the old shape: unchanged');
t = struct('variable', 'channel', 'along', 1, 'term', struct('node', '', 'name', 'A1'));
verifyEqual(testCase, did2.build.numericItem(t, 'new'), t, 'no number: unchanged');
n = struct('variable', 'depth', 'numeric', 1, 'source_numeric', 1000);
verifyEqual(testCase, did2.build.numericItem(n, 'new'), n, 'already new: unchanged');
both = did2.build.numericItem({old, t}, 'new');
verifyEqual(testCase, both{1}.numeric, 1);
verifyEqual(testCase, both{2}, t);
verifyError(testCase, @() did2.build.numericItem(old, 'newest'), 'did2:build:badOption');
end

function testNumericItemFollowsTheSetting(testCase)
prev = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prev));
old = struct('variable', 'depth', 'quantity', struct('value', 1));
did2.build.numericShape('old');
verifyEqual(testCase, did2.build.numericItem(old), old);
did2.build.numericShape('new');
verifyEqual(testCase, did2.build.numericItem(old).numeric, 1);
end

function testSourceNumericField(testCase)
verifyEqual(testCase, did2.build.sourceNumericField('new'), 'source_numeric');
verifyEqual(testCase, did2.build.sourceNumericField('old'), 'source_value');
prev = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prev));
if isempty(getenv('DID_NUMERIC_SHAPE'))
    verifyEqual(testCase, did2.build.sourceNumericField(), 'source_numeric', 'the default');
end
verifyError(testCase, @() did2.build.sourceNumericField('x'), 'did2:build:badOption');
end

% ===================== [numeric shape details] (1) =========================

function testASourceNumberStaysANumber(testCase)
c = did2.build.condition('temperature', 'Value', 37, 'SourceValue', 37, 'Shape', 'new');
verifyEqual(testCase, c.source_numeric, 37);
verifyClass(testCase, c.source_numeric, 'double');
p = did2.build.parameter('threshold', 'Value', 0.03, 'SourceValue', '0.030', 'Shape', 'new');
verifyEqual(testCase, p.source_numeric, '0.030', 'text the source wrote stays text');
o = did2.build.condition('temperature', 'Value', 37, 'SourceValue', 37, 'Shape', 'old');
verifyEqual(testCase, o.quantity.source_value, '37', 'the old shape keeps a number as text');
end

% ===================== [numeric shape details] (2) =========================

function testRelativeTimeReferenceWritesSourceNumeric(testCase)
sid = testCase.TestData.sid;
ms = did2.build.term('om:millisecond-Time', 'millisecond');
ref = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'dev_local_time', ...
    'Start', 12.5, 'StartSourceValue', 12500, 'StartSourceUnit', ms, ...
    'End', 14.5, 'EndSourceValue', 14500, 'EndSourceUnit', ms, ...
    'SessionId', sid, 'Validate', false);
v = ref.relative_time_reference.value;
verifyEqual(testCase, v.start.source_numeric, 12500);
verifyEqual(testCase, v.end.source_numeric, 14500);
verifyFalse(testCase, isfield(v.start, 'source_value') || isfield(v.end, 'source_value'));
did2.schema.cache.shared().validateDocument(ref);
old = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'dev_local_time', ...
    'Start', 12.5, 'StartSourceValue', 12500, 'StartSourceUnit', ms, 'SessionId', sid, ...
    'Validate', false);
verifyEqual(testCase, old.relative_time_reference.value.start.source_numeric, 12500);
prev = did2.build.numericShape('old');
testCase.addTeardown(@() did2.build.numericShape(prev));
o = did2.build.relativeTimeReference(did.ido.unique_id(), 'Clock', 'dev_local_time', ...
    'Start', 12.5, 'StartSourceValue', 12500, 'StartSourceUnit', ms, 'SessionId', sid);
verifyEqual(testCase, o.relative_time_reference.value.start.source_value, 12500, ...
    'the old shape keeps source_value');
end

function testAbsoluteDurationWritesSourceNumericAndTheTimestampKeepsItsText(testCase)
sid = testCase.TestData.sid;
ref = did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'SourceValue', '1 Mar 2024 10:00', 'Duration', 7200, 'DurationSourceValue', 2, ...
    'DurationSourceUnit', did2.build.term('om:hour', 'hour'), ...
    'EndSourceValue', '1 Mar 2024 12:00', 'SessionId', sid, 'Validate', false);
v = ref.absolute_time_reference.value;
verifyEqual(testCase, v.start.source_value, '1 Mar 2024 10:00', ...
    'a timestamp''s text keeps source_value ([numeric shape details] (2))');
verifyEqual(testCase, v.end.source_value, '1 Mar 2024 12:00');
verifyEqual(testCase, v.duration.source_numeric, 2, 'a duration is a time value');
verifyFalse(testCase, isfield(v.duration, 'source_value'));
did2.schema.cache.shared().validateDocument(ref);
end

% ===================== [numeric shape details] (3) =========================

function testASingleNumberIsWrittenPlain(testCase)
cache = did2.schema.cache.shared();
doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01, 'Shape', 'new'), ...
    'Conditions', did2.build.condition('temperature setting', 'Value', 37, ...
        'Unit', 'degree Celsius', 'Shape', 'new'), ...
    'MethodParameters', did2.build.list( ...
        did2.build.parameter('threshold', 'Value', 4.5, 'Unit', 'volt', 'Shape', 'new'), ...
        did2.build.parameter('colour palette', 'Matrix', [1 2; 3 4], 'Shape', 'new'), ...
        did2.build.parameter('colour weights', 'Matrix', [0.2 0.3 0.5], 'Shape', 'new')), ...
    'TimeReferenceIds', {did.ido.unique_id()}, 'SessionId', testCase.TestData.sid, ...
    'ValueKind', 'voltage');
txt = did2.document(doc).toJSON('SchemaCache', cache);
verifyNotEmpty(testCase, strfind(txt, '"numeric":37'), 'a single number is plain');
verifyNotEmpty(testCase, strfind(txt, '"numeric":4.5'), 'a single number is plain');
verifyEmpty(testCase, strfind(txt, '[[37]]'));
verifyNotEmpty(testCase, strfind(txt, '[[1,2],[3,4]]'), 'an array keeps its dimensions');
verifyNotEmpty(testCase, strfind(txt, '[[0.2,0.3,0.5]]'), 'a row keeps its dimensions');
back = did2.document.fromJSON(txt, 'SchemaCache', cache);
s = back.toStruct();
verifyEqual(testCase, s.statement.conditions.numeric, 37);
params = s.interaction.method.parameters;
if iscell(params); params = [params{:}]; end
verifyEqual(testCase, params(1).numeric, 4.5);
verifyEqual(testCase, params(2).numeric, [1 2; 3 4]);
verifyEqual(testCase, params(3).numeric, [0.2 0.3 0.5]);
verifyWarningFree(testCase, @() back.validate('SchemaCache', cache));
end

% ===================== helpers ==============================================

function verifySameReading(testCase, old, new)
% the converted item reads; the old one is refused (did-schema
% did_v2_numeric_shape_plan.md section 9 step 4, [no migrated database is
% kept], Jess Haley, 2026-11-19)
verifyError(testCase, @() did2.read.numeric(old), 'did2:read:oldNumericShapeReMigrate', ...
    'the old item is refused');
rn = did2.read.numeric(new);
verifyNotEmpty(testCase, rn.form, 'the converted item states a number');
verifyEqual(testCase, rn.unit, did2.read.numeric(rmOld(old)).unit, 'the unit is the item''s');
verifyEqual(testCase, rn.source_unit, did2.read.numeric(rmOld(old)).source_unit);
end

function s = rmOld(s)
% the old item without its old forms: what it states beside the number
for f = {'quantity', 'matrix', 'origin', 'spacing'}
    if isfield(s, f{1}); s = rmfield(s, f{1}); end
end
end
