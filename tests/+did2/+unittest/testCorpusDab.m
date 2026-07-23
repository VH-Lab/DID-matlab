function tests = testCorpusDab
%TESTCORPUSDAB Discovery-mode end-to-end run against the Dab corpus.
%
%   Pulls Dab.zip from the public S3 prefix (~35 MB compressed,
%   ~27,561 v1 documents), runs every contained body through
%   did2.convert.v1_to_v2 with Validate=true, and writes a per-run
%   summary JSON to corpus-reports/Dab-summary.json. The workflow's
%   upload-artifact step picks up the file as a CI artifact.
%
%   Discovery mode: the test does not assert zero quarantine.
%
%   Run with:
%       results = runtests('did2.unittest.testCorpusDab');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testDabCorpusDiscoveryReport(testCase)
did2.unittest.helpers.runCorpusDiscovery(testCase, 'Dab', ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/Dab.zip', ...
    'Dab');
end
