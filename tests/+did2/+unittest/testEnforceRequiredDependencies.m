function tests = testEnforceRequiredDependencies
%TESTENFORCEREQUIREDDEPENDENCIES Open item #37: make `mustBeNonEmpty` on a
%   `depends_on` entry actually reject.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment these tests
%   were written in, so every assertion below is UNVERIFIED. Read them as a
%   specification of intended behaviour, not as a passing suite. The first
%   person with MATLAB should run
%       results = runtests('did2.unittest.testEnforceRequiredDependencies');
%   and treat any red as a defect in the code or in these tests, not as a
%   surprise.
%
%   WHAT WAS BROKEN
%   ---------------
%   Six V_eta classes shipped a REQUIRED depends_on edge that was empty on
%   100% of their documents, and every one of those documents validated
%   clean. Two separate things had to be true for that:
%
%     did2.schema.cache/validateDocument never looked at `depends_on` AT
%     ALL -- the only mentions of the key in that file were a comment,
%     buildBlankDocument's empty seed, and the allowed-top-level-keys list.
%
%     did2.validate.references skips empty edges. That skip is CORRECT and
%     is NOT changed: references is the ORPHAN checker, an edge with no id
%     cannot dangle, and references is handed no schema so it cannot know
%     which edges were declared required. It was read for a long time as
%     the cause; it is the half that was right.
%
%   So the check now lives in the schema cache, where the schema is in
%   scope, and it is GATED:
%       did2.schema.cache.strictMode('RequiredDependencies')
%   DEFAULT OFF, because the last measured corpus census (DID-matlab run
%   31415147934, 02854c7) found 7,233 empty required edges across six
%   corpora and the corpus gate is 0 quarantine. Arming a gate ahead of the
%   repairs it grades just turns it red.
%
%   A NOTE ON testEmptyRequiredEdgeIsAcceptedWhenSwitchIsOff
%   --------------------------------------------------------
%   That test asserts the BUG. It is here deliberately and it must be read
%   as a hazard notice, not as an endorsement: it pins the default so that
%   nobody discovers by accident, on a 500,000-document corpus run, that
%   enforcement became live. When the census reaches zero and the team arms
%   the switch by default, that test INVERTS -- it does not get patched.
%
%   Run with:
%       results = runtests('did2.unittest.testEnforceRequiredDependencies');

tests = functiontests(localfunctions);
end

% ===================== fixtures ============================================

function setupOnce(testCase)
% The hermetic V_delta fixtures already contain exactly the class this needs:
% demoC declares item1 (mustBeNonEmpty true), item2 (true) and item3 (false).
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
did2.schema.cache.setSchemaPath(fixtureDir);
testCase.TestData.fixtureDir = fixtureDir;
testCase.TestData.cache = did2.schema.cache.shared();
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
did2.schema.cache.strictMode('-reset');
end

function setup(testCase)
% Record the switch so a failing assertion cannot leak enforcement into the
% next test -- a leaked global is exactly the kind of state that makes a
% suite pass or fail depending on ordering.
testCase.TestData.priorDeps = ...
    did2.schema.cache.strictMode('RequiredDependencies');
end

function teardown(testCase)
did2.schema.cache.strictMode('RequiredDependencies', ...
    testCase.TestData.priorDeps);
end

% ===================== the switch itself ===================================

function testSwitchIsOffUnlessTheEnvironmentArmsIt(testCase)
% The default is a deliberate decision, so it gets a test. Skipped rather
% than failed when the environment has armed the switch on purpose --
% asserting "off" against a job that asked for "on" would be the test
% lying about its own denominator.
if ~isempty(strtrim(getenv('DID_ENFORCE_REQUIRED_DEPENDENCIES')))
    assumeFail(testCase, ...
        ['DID_ENFORCE_REQUIRED_DEPENDENCIES is set in this environment; ' ...
         'the default-off assertion does not apply.']);
end
s = did2.schema.cache.strictMode('-reset');
verifyFalse(testCase, s.RequiredDependencies, ...
    '#37 enforcement must default to OFF');
% #38 INVERTED 2026-08-10: NonVacuousFields is now ARMED by default, on the
% team's call, and this assertion moved with it rather than being deleted.
% The two switches deliberately default DIFFERENTLY, and the difference is the
% measurement: the same corpus run reports 0 vacuous required fields and 7,233
% empty required edges. Arming the first costs nothing measured; arming the
% second would gate the corpus on repairs that are predicted, not proven.
% Asserting them together as "both OFF" would hide that distinction the moment
% either moves, which is exactly what just happened.
verifyTrue(testCase, s.NonVacuousFields, ...
    '#38 enforcement must default to ON');
end

function testStrictModeReturnsThePreviousValueSoItCanBeRestored(testCase)
did2.schema.cache.strictMode('RequiredDependencies', false);
prev = did2.schema.cache.strictMode('RequiredDependencies', true);
verifyFalse(testCase, prev, 'setter must return the PREVIOUS value');
verifyTrue(testCase, did2.schema.cache.strictMode('RequiredDependencies'));
end

function testUnknownSwitchNameRaisesRatherThanSilentlyDoingNothing(testCase)
% A typo'd switch name that quietly no-ops is a switch that is off while
% the operator believes it is on.
verifyError(testCase, ...
    @() did2.schema.cache.strictMode('RequiredDependancies', true), ...
    'did2:schema:unknownStrictMode');
end

% ===================== the hole, and its closure ===========================

function testEmptyRequiredEdgeIsAcceptedWhenSwitchIsOff(testCase)
% ASSERTS THE BUG ON PURPOSE. See the file header: this pins the default so
% that enforcement cannot go live unnoticed. INVERT this when the team arms
% the switch; do not patch it.
did2.schema.cache.strictMode('RequiredDependencies', false);
doc = demoCWith(testCase, {'item1', 'item2'}, {'', ''});
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, ...
    'with the switch off an empty required edge still validates clean');
end

function testEmptyRequiredEdgeIsRejectedWhenSwitchIsOn(testCase)
did2.schema.cache.strictMode('RequiredDependencies', true);
doc = demoCWith(testCase, {'item1', 'item2'}, {'', ''});
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:emptyRequiredDependency');
end

function testAbsentRequiredEdgeIsRejectedToo(testCase)
% Absent and blank are the same answer: neither names a referent. The
% invented-empty-edge pattern produced both spellings depending on which
% migrator emitted the document, so a check that caught only one would have
% missed half the corpus.
did2.schema.cache.strictMode('RequiredDependencies', true);
doc = demoCWith(testCase, {}, {});
verifyError(testCase, ...
    @() doc.validate('SchemaCache', testCase.TestData.cache), ...
    'did2:validation:emptyRequiredDependency');
end

function testPopulatedRequiredEdgesValidate(testCase)
did2.schema.cache.strictMode('RequiredDependencies', true);
doc = demoCWith(testCase, {'item1', 'item2'}, ...
    {'aaaaaaaaaaaaaaaa_0000111122223333', ...
     'bbbbbbbbbbbbbbbb_0000111122223333'});
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'both required edges populated -- must pass');
end

function testOptionalEdgeMayStayEmpty(testCase)
% demoC.item3 is mustBeNonEmpty:false. Enforcement must not widen into
% "every declared edge is required" -- that would quarantine documents the
% schema explicitly permits.
did2.schema.cache.strictMode('RequiredDependencies', true);
doc = demoCWith(testCase, {'item1', 'item2', 'item3'}, ...
    {'aaaaaaaaaaaaaaaa_0000111122223333', ...
     'bbbbbbbbbbbbbbbb_0000111122223333', ''});
doc.validate('SchemaCache', testCase.TestData.cache);
verifyTrue(testCase, true, 'an optional edge may be empty');
end

function testErrorNamesEveryUnpopulatedEdge(testCase)
% A quarantine reason that says only "a required edge is empty" costs the
% reader a bisect. Name them.
did2.schema.cache.strictMode('RequiredDependencies', true);
doc = demoCWith(testCase, {'item1'}, {''});
try
    doc.validate('SchemaCache', testCase.TestData.cache);
    verifyFail(testCase, 'expected did2:validation:emptyRequiredDependency');
catch err
    verifyEqual(testCase, err.identifier, ...
        'did2:validation:emptyRequiredDependency');
    verifySubstring(testCase, err.message, 'item1');
    verifySubstring(testCase, err.message, 'item2');
    verifySubstring(testCase, err.message, 'demoC');
end
end

% ===================== key-spelling tolerance ==============================

function testAllThreeEdgeKeySpellingsCountAsPopulated(testCase)
% `value`, `document_id` and `id` all occur in real bodies at different
% stages of the pipeline. Reading only one would report an edge as empty
% because the checker was looking at the wrong key -- the
% grep-that-could-not-have-matched failure, in struct form.
did2.schema.cache.strictMode('RequiredDependencies', true);
cache = testCase.TestData.cache;
for key = {'value', 'document_id', 'id'}
    body = demoCBody(testCase);
    body.depends_on = struct('name', 'item1', key{1}, 'x1');
    body.depends_on(2) = struct('name', 'item2', key{1}, 'x2');
    missing = cache.unpopulatedRequiredDependencies(body, 'demoC');
    verifyEmpty(testCase, missing, ...
        sprintf('edge key "%s" must count as populated', key{1}));
end
end

% ===================== what the rule does NOT cover ========================

function testNumberedFamiliesAreNotTreatedAsRequiredEdges(testCase)
% `mustBeNonEmpty` cannot describe a family: a MISSING instance of
% `slice_#` is not a BLANK one, and the checkable property is the instance
% COUNT (min_count/max_count), which #63 measures REPORT-ONLY in
% did2.validate.silentLoss. Folding families in here would convert an
% unmeasured count into a gate -- which is precisely the mistake this whole
% change is trying not to repeat.
dirPath = familyFixtureDir(testCase.TestData.fixtureDir);
restore = onCleanup(@() localRestore(testCase.TestData.fixtureDir, dirPath)); %#ok<NASGU>
did2.schema.cache.setSchemaPath(dirPath);
cache = did2.schema.cache.shared();
names = cache.requiredDependencies('demoFamily');
verifyEqual(testCase, names, {'anchor_id'}, ...
    'only the non-family required edge is returned');
end

function testRequiredEdgesAreInheritedThroughTheChain(testCase)
% A leaf inherits its ancestors' required edges. subject_statement declares
% subject_id once and 77 concrete V_eta classes carry it, so a check that
% read only the leaf's own declarations would see almost none of them.
dirPath = familyFixtureDir(testCase.TestData.fixtureDir);
restore = onCleanup(@() localRestore(testCase.TestData.fixtureDir, dirPath)); %#ok<NASGU>
did2.schema.cache.setSchemaPath(dirPath);
cache = did2.schema.cache.shared();
names = cache.requiredDependencies('demoFamilyLeaf');
verifyTrue(testCase, any(strcmp(names, 'anchor_id')), ...
    'the inherited required edge must be found on the leaf');
verifyTrue(testCase, any(strcmp(names, 'leaf_id')), ...
    'the leaf''s own required edge must be found too');
end

% ===================== ordering, so reasons stay stable ====================

function testAPreExistingFailureStillReportsItsOwnReason(testCase)
% The #37 check runs LAST. A document that already fails an older check must
% keep failing for the SAME reason with the switch on -- otherwise arming it
% silently rewrites the quarantine-reason histogram for documents whose
% problem is something else entirely, and the corpus report stops being
% comparable across runs.
did2.schema.cache.strictMode('RequiredDependencies', true);
body = demoCBody(testCase);
body.demoC.not_a_declared_field = 'x';
body.depends_on = struct('name', {}, 'document_id', {});
verifyError(testCase, ...
    @() testCase.TestData.cache.validateDocument(body), ...
    'did2:validation:undeclaredField', ...
    'the older, more specific reason must win');
end

% ===================== the lock: census and gate must agree ================

function testCensusAndGateAgreeOnTheSameDocument(testCase)
% THE POINT OF THIS TEST. did2.validate.silentLoss is the REPORT-ONLY census
% that decides when the switch may be armed; validateDocument is the gate.
% If the two ever disagree about WHICH edges are required, the census stops
% predicting what enforcement would cost, and the number the team arms the
% switch on becomes fiction. Same document, both instruments, one assertion.
cache = testCase.TestData.cache;
doc = demoCWith(testCase, {'item1', 'item2', 'item3'}, {'', '', ''});

rep = did2.validate.silentLoss({doc}, 'SchemaCache', cache);
verifyEqual(testCase, rep.total_docs, 1, ...
    'denominator first: the census must have read the document');
verifyEqual(testCase, rep.empty_dependency_count, 2, ...
    'the census must count item1 and item2, and NOT the optional item3');

did2.schema.cache.strictMode('RequiredDependencies', true);
try
    doc.validate('SchemaCache', cache);
    verifyFail(testCase, ...
        'the gate must reject what the census counted');
catch err
    verifyEqual(testCase, err.identifier, ...
        'did2:validation:emptyRequiredDependency');
    verifySubstring(testCase, err.message, 'item1');
    verifySubstring(testCase, err.message, 'item2');
    verifyTrue(testCase, ~contains(err.message, 'item3'), ...
        'the optional edge must not appear in the gate''s reason either');
end
end

% ===================== the lock, second shape: a CELL depends_on ===========

function testCensusAndGateAgreeWhenDependsOnIsACell(testCase)
% THE DIVERGENCE THE FIRST LOCK TEST COULD NOT SEE, and the reason this one
% exists as its own case rather than as an extra assertion in that one.
%
% testCensusAndGateAgreeOnTheSameDocument builds `depends_on` with
% `deps(end+1) = struct(...)` -- a STRUCT ARRAY, every time. Both instruments
% were written against that shape, and both passed. But jsondecode returns a
% CELL whenever the entries of a JSON array do not all carry the same keys,
% which is exactly what a mid-migration body carrying a mix of `document_id`
% and the raw v1 `id` spelling decodes to -- the same mixture the key
% tolerance elsewhere in both files exists to handle. Three other readers of a
% body's depends_on already handled the cell shape
% (silentLoss/familyMemberIds, did2.convert.epochMint,
% migrators_j.epochfiles_ingested); silentLoss/edgeIsPopulated did not. It
% read `if ~isstruct(deps); return; end` and answered "not populated" for
% EVERY edge without inspecting one.
%
% So the census over-reported empty edges the gate would happily pass. That is
% the SAFE direction -- it makes the repair look bigger, never done -- which is
% precisely why it survived: nothing about it looked like progress. It still
% corrupts the denominator the arming decision for #37 rests on, which is the
% one number both instruments exist to produce.
%
% This test is written from the SHAPE, not from either implementation, and it
% drives BOTH instruments over the same body. Before the fix it fails on the
% census assertion while the gate assertion passes -- which is the defect
% stated as an inequality.
cache = testCase.TestData.cache;

% (a) POPULATED, cell-shaped, MIXED KEYS. Nothing is missing here; both
%     instruments must say so.
body = demoCBody(testCase);
body.depends_on = { ...
    struct('name', 'item1', 'document_id', 'aaaaaaaaaaaaaaaa_0000111122223333'), ...
    struct('name', 'item2', 'id',          'bbbbbbbbbbbbbbbb_0000111122223333')};

rep = did2.validate.silentLoss({did2.document(body)}, 'SchemaCache', cache);
verifyEqual(testCase, rep.total_docs, 1, ...
    'denominator first: the census must have read the document');
verifyEqual(testCase, rep.empty_dependency_count, 0, ...
    ['a CELL-shaped depends_on with both required edges populated must ' ...
     'count ZERO empty edges -- reporting 2 here is the census reading ' ...
     'the shape, not the data']);

verifyEmpty(testCase, cache.unpopulatedRequiredDependencies(body, 'demoC'), ...
    'the gate must agree the cell-shaped body is fully populated');

did2.schema.cache.strictMode('RequiredDependencies', true);
did2.document(body).validate('SchemaCache', cache);
verifyTrue(testCase, true, ...
    'and must accept it with enforcement armed');

% (b) The converse, same shape: genuinely blank. Both instruments must still
%     agree -- a fix that made the census blind to cell-shaped bodies
%     altogether would pass (a) and fail here.
blankBody = demoCBody(testCase);
blankBody.depends_on = { ...
    struct('name', 'item1', 'document_id', ''), ...
    struct('name', 'item2', 'id',          '')};

repBlank = did2.validate.silentLoss({did2.document(blankBody)}, ...
    'SchemaCache', cache);
verifyEqual(testCase, repBlank.total_docs, 1, ...
    'denominator first');
verifyEqual(testCase, repBlank.empty_dependency_count, 2, ...
    'a cell-shaped body with both required edges blank must count TWO');

verifyError(testCase, ...
    @() did2.document(blankBody).validate('SchemaCache', cache), ...
    'did2:validation:emptyRequiredDependency', ...
    'the gate must reject what the census counted, cell shape included');
end

% ===================== helpers =============================================

function body = demoCBody(testCase)
% base.session_id is mustBeNonEmpty and buildBlankDocument leaves it at its
% blank_value, so an unmodified blank document fails on emptyField BEFORE
% any of the checks under test can run. Populating it here is not cosmetic:
% without it every assertion below would be verifying the wrong error id.
doc = did2.document.blank('demoC', 'SchemaCache', testCase.TestData.cache);
doc = doc.set('base.session_id', 'sess_0000111122223333');
body = doc.toStruct();
end

function doc = demoCWith(testCase, names, values)
body = demoCBody(testCase);
deps = struct('name', {}, 'document_id', {});
for k = 1:numel(names)
    deps(end+1) = struct('name', names{k}, 'document_id', values{k}); %#ok<AGROW>
end
body.depends_on = deps;
doc = did2.document(body);
end

function localRestore(fixtureDir, throwawayDir)
% Point the singleton back at the shared fixtures BEFORE removing the
% throwaway dir -- a cache still holding the temp path would be a cache
% pointing at nothing for every test that runs after this one.
did2.schema.cache.setSchemaPath(fixtureDir);
if nargin > 1 && isfolder(throwawayDir)
    rmdir(throwawayDir, 's');
end
end

function dirPath = familyFixtureDir(fixtureDir)
% A throwaway schema dir with TWO classes:
%   demoFamily     - one plain required edge (anchor_id) and one NUMBERED
%                    family (slice_#) that is ALSO marked mustBeNonEmpty,
%                    which is exactly the mis-declaration #63 found in the
%                    real schema. The family must be ignored here.
%   demoFamilyLeaf - extends demoFamily, adds its own required edge, so the
%                    chain walk is exercised.
dirPath = tempname;
mkdir(dirPath);
copyfile(fullfile(fixtureDir, 'base.json'), fullfile(dirPath, 'base.json'));
curie = fullfile(fixtureDir, 'CURIE_lookups_meta.json');
if isfile(curie)
    copyfile(curie, fullfile(dirPath, 'CURIE_lookups_meta.json'));
end
writeJSON(fullfile(dirPath, 'demoFamily.json'), ...
    ['{"document_class":{"class_name":"demoFamily","class_version":"1.0.0",' ...
     '"superclasses":[{"class_name":"base","class_version":"1.0.0"}]},' ...
     '"depends_on":[' ...
     '{"name":"anchor_id","mustBeNonEmpty":true,"documentation":"required",' ...
     '"must_refer_to_document_class":""},' ...
     '{"name":"slice_#","mustBeNonEmpty":true,"min_count":1,' ...
     '"documentation":"a NUMBERED family, mis-marked required",' ...
     '"must_refer_to_document_class":""}],' ...
     '"file":[],"fields":[]}']);
writeJSON(fullfile(dirPath, 'demoFamilyLeaf.json'), ...
    ['{"document_class":{"class_name":"demoFamilyLeaf","class_version":"1.0.0",' ...
     '"superclasses":[{"class_name":"demoFamily","class_version":"1.0.0"}]},' ...
     '"depends_on":[' ...
     '{"name":"leaf_id","mustBeNonEmpty":true,"documentation":"required",' ...
     '"must_refer_to_document_class":""}],' ...
     '"file":[],"fields":[]}']);
end

function writeJSON(path, text)
fid = fopen(path, 'w');
if fid < 0
    error('did2:test:cannotWriteFixture', 'Could not write "%s".', path);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, text);
end
