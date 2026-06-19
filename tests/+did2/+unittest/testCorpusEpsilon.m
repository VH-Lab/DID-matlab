function tests = testCorpusEpsilon
%TESTCORPUSEPSILON Discovery-mode end-to-end run through the Brainstorm-E split.
%
%   Runs a real v1 corpus through did2.convert.v1_to_v2 with
%   TargetVersion='V_epsilon', so the treatment -> manipulation and
%   ontology_table_row -> observation split migrators
%   (+did2.+convert.+migrators_e) are exercised and the migrated bodies
%   are validated against the V_epsilon schema set. Writes
%   corpus-reports/<name>-summary.json.
%
%   Opt-in via DID_RUN_EPSILON_CORPUS (the CI step that assembles a
%   combined V_epsilon stable+draft schema dir and points
%   DID_SCHEMA_PATH at it sets this). When the variable is unset the
%   test skips cleanly via assumeFail, so it is a no-op in the default
%   V_delta test run.
%
%   The Dab corpus is used because its treatment rows (incl. the
%   optogenetic-tetanus "Target Location" idiom) directly exercise the
%   treatment split. Discovery mode: nothing is asserted about the
%   migrated/quarantine split; the report is the deliverable.
%
%   Run with:
%       export DID_RUN_EPSILON_CORPUS=1
%       results = runtests('did2.unittest.testCorpusEpsilon');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testEpsilonDabCorpusDiscoveryReport(testCase)
if ~epsilonTestEnabled()
    assumeFail(testCase, ...
        ['DID_RUN_EPSILON_CORPUS not set to a truthy value; skipping the ', ...
         'V_epsilon (Brainstorm E) corpus discovery test. Set ', ...
         'DID_RUN_EPSILON_CORPUS=1 (and DID_SCHEMA_PATH to a V_epsilon ', ...
         'stable+draft schema dir) to enable.']);
end
did2.unittest.helpers.runCorpusDiscovery(testCase, 'Dab-epsilon', ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/Dab.zip', ...
    'Dab', 'TargetVersion', 'V_epsilon');
end

function tf = epsilonTestEnabled()
raw = lower(strtrim(getenv('DID_RUN_EPSILON_CORPUS')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end
