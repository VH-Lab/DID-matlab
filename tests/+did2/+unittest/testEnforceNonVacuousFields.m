function tests = testEnforceNonVacuousFields
%TESTENFORCENONVACUOUSFIELDS Open item #38: make an ALL-BLANK COMPOSITE count
%   as empty for the required-field check.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment these tests
%   were written in, so every assertion below is UNVERIFIED. Read them as a
%   specification of intended behaviour, not as a passing suite. Run
%       results = runtests('did2.unittest.testEnforceNonVacuousFields');
%   before trusting any of it.
%
%   WHAT WAS BROKEN
%   ---------------
%   did2.schema.cache/isEmptyValue calls a struct empty only when it has NO
%   FIELDNAMES. An ontology_term of {node:'', name:''} has two fieldnames, so
%   it satisfies `mustBeNonEmpty` while recording nothing at all. That is not
%   a hypothetical shape: it is the literal `blank_value` of
%   subject_statement.variable, the key the whole V_eta model pivots on. A
%   migrator that read a source field no real document has emitted exactly
%   this and passed every gate.
%
%   THE FIX IS A SIBLING PREDICATE, NOT A WIDER isEmptyValue.
%   isVacuousValue is a separate recursive test and raises a separate id,
%   did2:validation:vacuousField, for two reasons:
%     - isEmptyValue answers "is there a value here", and an all-blank
%       composite structurally IS one. What it is not is INFORMATIVE.
%     - a distinct id keeps the corpus quarantine histogram legible. Arming
%       this switch has to be readable as its own row, not as an unexplained
%       jump in the pre-existing emptyField count.
%
%   GATED, AND ARMED BY DEFAULT (2026-08-10, team's call):
%   did2.schema.cache.strictMode('NonVacuousFields').
%
%   HISTORICAL-SIGNOFF-CLAIM. This header said "GATED, DEFAULT OFF ... It is
%   still off ... Arming it is a one-line change once someone decides that gap
%   is closed" for as long as that was true and then kept saying it after the
%   team armed the switch -- while this file's OWN FIRST TEST,
%   testNonVacuousFieldsIsARMEDByDefault, asserted the opposite forty lines
%   below. A document's header disagreeing with its own body is the exact
%   staleness the schema repo gates elsewhere, and it ran in the usual
%   direction: the header claimed LESS enforcement than shipped, so it never
%   produced a wrong build, only a wrong belief about where we stand.
%
%   The evidence for arming: the last measured census (DID-matlab corpus run
%   31415147934, 02854c7) reported ZERO vacuous required fields across six
%   corpora, 562,448 documents. Zero measured cost.
%
%   THE STANDING CAVEAT, which is an argument FOR arming rather than against:
%   "zero on the six corpora we happen to test" is not "zero", the corpora are
%   a sample of datasets, and the census's field scan and the validator's do
%   not have identical denominators (the census only inspects blocks that
%   already host the field; the validator also reaches required fields whose
%   block is missing entirely). A dataset still waiting to migrate could trip
%   it -- and the intended outcome then is a LOUD quarantine, not a document
%   that validates while saying nothing. DID_ENFORCE_NONVACUOUS_FIELDS=0 is
%   the operator's escape hatch, and it is tested below.
%
%   Run with:
%       results = runtests('did2.unittest.testEnforceNonVacuousFields');

tests = functiontests(localfunctions);
end

% ===================== fixtures ============================================

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
testCase.TestData.fixtureDir = fixtureDir;
% A throwaway schema dir: the hermetic V_delta fixtures carry no required
% composite field, and adding one to them would change the queryable-path
% list that testSchemaCache asserts exactly.
testCase.TestData.schemaDir = vacuousFixtureDir(fixtureDir);
did2.schema.cache.setSchemaPath(testCase.TestData.schemaDir);
testCase.TestData.cache = did2.schema.cache.shared();
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
did2.schema.cache.strictMode('-reset');
end

function setup(testCase)
testCase.TestData.prior = did2.schema.cache.strictMode('NonVacuousFields');
end

function teardown(testCase)
did2.schema.cache.strictMode('NonVacuousFields', testCase.TestData.prior);
end

% ===================== the hole, and its closure ===========================

function testNonVacuousFieldsIsARMEDByDefault(testCase)
% INVERTED 2026-08-10, on the team's call, exactly as its predecessor
% instructed.
%
% This was `testAllBlankCompositeIsAcceptedWhenSwitchIsOff`, which ASSERTED
% THE BUG ON PURPOSE so that enforcement could not become live unnoticed on a
% 500,000-document corpus run, and whose header said: "When the team arms the
% switch by default this test INVERTS -- it does not get patched."
%
% The team armed it. So the thing worth pinning is no longer "the bug is still
% there" but "the DEFAULT is on" -- because the failure mode has flipped.
% Before, the risk was enforcement arriving silently; now it is enforcement
% being silently DISARMED by a stray environment variable or a `-reset` that
% forgets the default. This test is what makes that loud.
%
% The evidence for arming: corpus run 31415147934 reports "0 vacuous required
% field(s)" across all six corpora, 562,448 documents. Zero measured cost.
% The standing caveat is that the corpora are a SAMPLE and the census's field
% scan does not share a denominator with the validator's, so "0 measured" is
% weaker than "0 possible" -- which is the argument FOR arming, not against:
% the intended outcome for a dataset that trips it is a loud quarantine, not
% a document that validates while saying nothing.
did2.schema.cache.strictMode('-reset');
verifyTrue(testCase, did2.schema.cache.strictMode('NonVacuousFields'), ...
    'NonVacuousFields must be ARMED after a reset -- the default is on');
doc = blankOf(testCase, 'demoTerm');
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:vacuousField', ...
    'an all-blank required composite must quarantine with no switch set');
end

function testNonVacuousFieldsCanStillBeTurnedOffDeliberately(testCase)
% The escape hatch is real and is tested. An operator who needs a corpus to
% migrate past a vacuity failure turns it off; nothing about arming the
% default removes that.
did2.schema.cache.strictMode('NonVacuousFields', false);
doc = blankOf(testCase, 'demoTerm');
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, ...
    'with the switch explicitly off, an all-blank composite still passes');
end

function testAllBlankCompositeIsRejectedWhenSwitchIsOn(testCase)
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoTerm');
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:vacuousField');
end

function testOneNonBlankLeafIsEnoughToPass(testCase)
% Partial is not vacuous. A term with a name and no CURIE still says
% something, and quarantining it would be a different and much larger
% decision than the one this switch implements.
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoTerm');
doc = doc.set('demoTerm.term', struct('node', '', 'name', 'temperature'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'one populated leaf makes the composite non-vacuous');
end

function testFullyPopulatedCompositePasses(testCase)
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoTerm');
doc = doc.set('demoTerm.term', ...
    struct('node', 'UBERON:0000955', 'name', 'brain'));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true);
end

% ===================== the edges of "blank" ================================

function testARecordedZeroIsAValueNotABlank(testCase)
% THE MOST DANGEROUS FALSE POSITIVE AVAILABLE HERE. A measured 0 -- 0 volts,
% 0 spikes, false -- is data. If a numeric zero counted as blank, this switch
% would quarantine real measurements while claiming to protect them, and it
% would do it silently because the affected documents look empty.
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoNumeric');
doc = doc.set('demoNumeric.cell', struct('label', '', 'count', 0));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'a recorded 0 must NOT count as blank');
end

function testWhitespaceOnlyCharCountsAsBlank(testCase)
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoTerm');
doc = doc.set('demoTerm.term', struct('node', '   ', 'name', sprintf('\t')));
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:vacuousField');
end

function testNestingIsWalkedAllTheWayDown(testCase)
% A composite of composites is vacuous only if every LEAF is blank. A
% shallow check would call {inner:{leaf:''}} non-empty because `inner` is a
% present struct -- which is the original bug wearing one more layer.
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoNested');
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:vacuousField');

doc = doc.set('demoNested.outer', struct('inner', struct('leaf', 'x')));
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'a populated deep leaf makes the whole thing real');
end

function testAStructArrayIsVacuousOnlyIfEveryElementIs(testCase)
did2.schema.cache.strictMode('NonVacuousFields', true);
cache = testCase.TestData.cache;

allBlank = blankOf(testCase, 'demoSeries');
allBlank = allBlank.set('demoSeries.series', ...
    struct('tag', {'', ''}));
verifyError(testCase, @() allBlank.validate('SchemaCache', cache), ...
    'did2:validation:vacuousField');

oneReal = blankOf(testCase, 'demoSeries');
oneReal = oneReal.set('demoSeries.series', ...
    struct('tag', {'', 'sweep-2'}));
oneReal.validate('SchemaCache', cache);
verifyTrue(testCase, true, 'one populated element makes the array non-vacuous');
end

% ===================== the two ids stay distinct ===========================

function testAGenuinelyEmptyStructStillRaisesEmptyFieldNotVacuousField(testCase)
% The pre-existing check keeps its own id. Merging the two would make it
% impossible to read, from a corpus report, how much of a quarantine spike
% this switch caused and how much was already there.
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoTerm');
doc = doc.set('demoTerm.term', struct());
try
    doc.validate('SchemaCache', testCase.TestData.cache);
    verifyFail(testCase, 'expected a validation error');
catch err
    verifyEqual(testCase, err.identifier, 'did2:validation:emptyField', ...
        'a struct with no fieldnames is EMPTY, not vacuous');
end
end

function testOptionalCompositeMayBeVacuous(testCase)
% mustBeNonEmpty:false means the schema does not care. Enforcement must not
% widen into "no composite may be blank anywhere".
did2.schema.cache.strictMode('NonVacuousFields', true);
doc = blankOf(testCase, 'demoOptionalTerm');
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'an optional composite may be all-blank');
end

% ===================== the lock: census and gate must agree ================

function testCensusAndGateAgreeOnTheSameDocument(testCase)
% did2.validate.silentLoss/isVacuous and
% did2.schema.cache/isVacuousValue implement the SAME rule in two files.
% They have to, because the census is what the decision to arm this switch
% will be made on -- if the two drift, the number quoted in that decision
% stops describing the gate. Same document, both instruments.
cache = testCase.TestData.cache;
doc = blankOf(testCase, 'demoTerm');

rep = did2.validate.silentLoss({doc}, 'SchemaCache', cache);
verifyEqual(testCase, rep.total_docs, 1, ...
    'denominator first: the census must have read the document');
verifyEqual(testCase, rep.vacuous_field_count, 1, ...
    'the census must count the all-blank required composite');

did2.schema.cache.strictMode('NonVacuousFields', true);
verifyError(testCase, @() doc.validate('SchemaCache', cache), ...
    'did2:validation:vacuousField', ...
    'the gate must reject what the census counted');
end

function testCensusAndGateAgreeThatARecordedZeroIsFine(testCase)
% The inverse lock, and the one that matters most: both instruments must
% agree that a measured 0 is data. If only one of them thought so, either
% the census would over-report and delay the repair, or the gate would
% quarantine real measurements.
cache = testCase.TestData.cache;
doc = blankOf(testCase, 'demoNumeric');
doc = doc.set('demoNumeric.cell', struct('label', '', 'count', 0));

rep = did2.validate.silentLoss({doc}, 'SchemaCache', cache);
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.vacuous_field_count, 0, ...
    'the census must not count a recorded zero as vacuous');

did2.schema.cache.strictMode('NonVacuousFields', true);
doc.validate('SchemaCache', cache);
verifyTrue(testCase, true, 'and neither must the gate');
end

% ===================== helpers =============================================

function doc = blankOf(testCase, className)
% base.session_id is mustBeNonEmpty and buildBlankDocument leaves it at its
% blank_value, so an unmodified blank document fails on emptyField BEFORE
% any of the checks under test can run. Populating it here is not cosmetic:
% without it every assertion below would be verifying the wrong error id.
doc = did2.document.blank(className, 'SchemaCache', testCase.TestData.cache);
doc = doc.set('base.session_id', 'sess_0000111122223333');
end

function dirPath = vacuousFixtureDir(fixtureDir)
% Five throwaway classes, one per shape the vacuity rule has to get right.
% Every field is queryable:false so that no queryable path is added -- the
% shared fixture dir is not touched and testSchemaCache's exact path list is
% unaffected.
%
% NOTE the blank_value of demoTerm.term: {"node":"","name":""}. That is not
% invented for the test. It is verbatim the blank_value of
% subject_statement.variable in V_eta, which is the field this whole item is
% about.
dirPath = tempname;
mkdir(dirPath);
copyfile(fullfile(fixtureDir, 'base.json'), fullfile(dirPath, 'base.json'));
curie = fullfile(fixtureDir, 'CURIE_lookups_meta.json');
if isfile(curie)
    copyfile(curie, fullfile(dirPath, 'CURIE_lookups_meta.json'));
end

writeJSON(fullfile(dirPath, 'demoTerm.json'), classJSON('demoTerm', ...
    [field('term', 'ontology_term', true, true, '{"node":"","name":""}', ...
        [sub('node', 'char', '""') ',' sub('name', 'char', '""')])]));

writeJSON(fullfile(dirPath, 'demoOptionalTerm.json'), ...
    classJSON('demoOptionalTerm', ...
    [field('term', 'ontology_term', false, true, '{"node":"","name":""}', ...
        [sub('node', 'char', '""') ',' sub('name', 'char', '""')])]));

writeJSON(fullfile(dirPath, 'demoNumeric.json'), classJSON('demoNumeric', ...
    [field('cell', 'structure', true, true, '{"label":"","count":0}', ...
        [sub('label', 'char', '""') ',' sub('count', 'double', '0')])]));

writeJSON(fullfile(dirPath, 'demoNested.json'), classJSON('demoNested', ...
    [field('outer', 'structure', true, true, '{"inner":{"leaf":""}}', ...
        ['{"name":"inner","type":"structure","mustBeScalar":true,' ...
         '"mustBeNonEmpty":false,"mustNotHaveNaN":false,"queryable":false,' ...
         '"documentation":"nested","blank_value":{"leaf":""},' ...
         '"default_value":{"leaf":""},"constraints":{},"fields":[' ...
         sub('leaf', 'char', '""') ']}'])]));

writeJSON(fullfile(dirPath, 'demoSeries.json'), classJSON('demoSeries', ...
    [field('series', 'structure', true, false, '[{"tag":""}]', ...
        sub('tag', 'char', '""'))]));
end

function s = classJSON(className, fieldsJSON)
s = ['{"document_class":{"class_name":"' className '","class_version":"1.0.0",' ...
     '"superclasses":[{"class_name":"base","class_version":"1.0.0"}]},' ...
     '"depends_on":[],"file":[],"fields":[' fieldsJSON ']}'];
end

function s = field(name, type, required, scalar, blank, subsJSON)
s = sprintf(['{"name":"%s","type":"%s","mustBeScalar":%s,' ...
    '"mustBeNonEmpty":%s,"mustNotHaveNaN":false,"queryable":false,' ...
    '"documentation":"a composite used by the #38 tests",' ...
    '"blank_value":%s,"default_value":%s,"constraints":{},"fields":[%s]}'], ...
    name, type, boolStr(scalar), boolStr(required), blank, blank, subsJSON);
end

function s = sub(name, type, blank)
s = sprintf(['{"name":"%s","type":"%s","mustBeScalar":true,' ...
    '"mustBeNonEmpty":false,"mustNotHaveNaN":false,"queryable":false,' ...
    '"documentation":"sub-field","blank_value":%s,"default_value":%s,' ...
    '"constraints":{}}'], name, type, blank, blank);
end

function s = boolStr(tf)
if tf
    s = 'true';
else
    s = 'false';
end
end

function writeJSON(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('did2:test:cannotWriteFixture', 'Could not write "%s".', path);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text);
end
