function tests = testCorpusJH
%TESTCORPUSJH Discovery-mode end-to-end run against the JH corpus.
%
%   Pulls JH.zip from the public S3 prefix (~89 MB compressed,
%   ~78,688 v1 documents), runs every contained body through
%   did2.convert.v1_to_v2 with Validate=true, and writes a per-run
%   summary JSON to corpus-reports/JH-summary.json. The workflow's
%   upload-artifact step picks up the file as a CI artifact.
%
%   Discovery mode: the test does not assert zero quarantine.
%
%   This corpus is the largest of the four PR-time discovery
%   fixtures (B, Dab, JH at ~150 MB combined). Soph (~446 MB) is
%   guarded separately by DID_RUN_SOPH_TEST.
%
%   Run with:
%       results = runtests('did2.unittest.testCorpusJH');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testJHCorpusDiscoveryReport(testCase)
did2.unittest.helpers.runCorpusDiscovery(testCase, 'JH', ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/JH.zip', ...
    'JH');
end
