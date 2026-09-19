function tests = testCorpusSoph
%TESTCORPUSSOPH Discovery-mode end-to-end run against the Soph corpus.
%
%   The largest single-corpus discovery fixture (~446 MB compressed,
%   ~101,427 v1 documents). Too big to download on every PR, so the
%   test is **opt-in** via the DID_RUN_SOPH_TEST environment
%   variable:
%
%       export DID_RUN_SOPH_TEST=1   # also accepts 'true', case-insensitive
%
%   When the variable is unset, empty, '0', or 'false', the test
%   skips cleanly via assumeFail (no error). When set to '1' or
%   'true', it downloads Soph.zip, runs the full corpus through
%   did2.convert.v1_to_v2 with Validate=true, and writes
%   corpus-reports/Soph-summary.json.
%
%   Discovery mode: the test does not assert zero quarantine.
%
%   Run with:
%       results = runtests('did2.unittest.testCorpusSoph');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testSophCorpusDiscoveryReport(testCase)
if ~sophTestEnabled()
    assumeFail(testCase, ...
        ['DID_RUN_SOPH_TEST not set to a truthy value; ', ...
         'skipping the ~446 MB Soph corpus discovery test. ', ...
         'Set DID_RUN_SOPH_TEST=1 (or true) to enable.']);
end
did2.unittest.helpers.runCorpusDiscovery(testCase, 'Soph', ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/Soph.zip', ...
    'Soph');
end

function tf = sophTestEnabled()
raw = lower(strtrim(getenv('DID_RUN_SOPH_TEST')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end
