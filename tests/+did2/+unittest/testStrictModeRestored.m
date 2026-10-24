function tests = testStrictModeRestored
%TESTSTRICTMODERESTORED A conversion pass leaves the strict modes as it found them.
%
%   did2.convert's entry points switch strict modes off while they run (a
%   migrator transcribes the v1 source's own terms) and restore them with an
%   onCleanup. foldGenericFiles switched TermRegistry off TWICE into the same
%   variables (DID-matlab 526d685): reassigning restoreTermRegistry destroyed
%   the first onCleanup, which re-armed the check mid-pass, and the second
%   restored it to OFF on return, so TermRegistry stayed off after the pass.
%   It leaked into NDI-matlab's TestGenericDatasetEndToEnd/
%   testAnUnregisteredTermIsRefused (NDI run 40112365853).
%
%   Each test runs the pass with the switch ON and with it OFF and checks it
%   is unchanged afterwards. The empty batch is enough: the switch-off and
%   restore happen before a single document is read.
%
%   Example:
%       results = runtests('did2.unittest.testStrictModeRestored');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping strict-mode restore tests');
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testFoldGenericFilesRestoresTermRegistry(testCase)
verifyRestored(testCase, 'TermRegistry', @() did2.convert.foldGenericFiles( ...
    emptyResult(), 'Validate', false, 'TargetVersion', 'V_eta'));
end

function testV1ToV2RestoresTermRegistry(testCase)
verifyRestored(testCase, 'TermRegistry', @() did2.convert.v1_to_v2({}, ...
    'Validate', false, 'Audits', false));
end

function testFoldGenericFilesRestoresRetiredClasses(testCase)
verifyRestored(testCase, 'RetiredClasses', @() did2.convert.foldGenericFiles( ...
    emptyResult(), 'Validate', false, 'TargetVersion', 'V_eta'));
end

function testV1ToV2RestoresRetiredClasses(testCase)
verifyRestored(testCase, 'RetiredClasses', @() did2.convert.v1_to_v2({}, ...
    'Validate', false, 'Audits', false));
end

% ===================== helpers ==============================================

function verifyRestored(testCase, switchName, pass)
arguments
    testCase
    switchName (1,:) char
    pass (1,1) function_handle
end
prev = did2.schema.cache.strictMode(switchName);
testCase.addTeardown(@() did2.schema.cache.strictMode(switchName, prev));
for state = [true false]
    did2.schema.cache.strictMode(switchName, state);
    pass();
    verifyEqual(testCase, did2.schema.cache.strictMode(switchName), state, ...
        sprintf('strictMode(''%s'') was %d before the pass and changed after it', ...
        switchName, state));
end
end

function r = emptyResult()
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));
end
