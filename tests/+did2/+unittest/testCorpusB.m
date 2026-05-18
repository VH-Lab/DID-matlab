function tests = testCorpusB
%TESTCORPUSB Discovery-mode end-to-end run against the B corpus.
%
%   Pulls B.zip from the public S3 prefix (~17 MB compressed,
%   ~12,917 v1 documents across ~18 classes), runs every contained
%   body through did2.convert.v1_to_v2 with Validate=true, and
%   writes a per-run summary JSON to corpus-reports/B-summary.json.
%   The workflow's upload-artifact step picks up the file as a CI
%   artifact.
%
%   Discovery mode: the test does not assert zero quarantine. Its
%   job is to surface coverage signal without blocking unrelated
%   PRs on migrator work.
%
%   Run with:
%       results = runtests('did2.unittest.testCorpusB');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testBCorpusDiscoveryReport(testCase)
did2.unittest.helpers.runCorpusDiscovery(testCase, 'B', ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/B.zip', ...
    'B');
end
