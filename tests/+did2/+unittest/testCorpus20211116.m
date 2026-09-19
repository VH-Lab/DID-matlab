function tests = testCorpus20211116
%TESTCORPUS20211116 Discovery-mode end-to-end run against the 20211116 corpus.
%
%   Pulls the 20211116.zip fixture from the public S3 prefix
%   (~11MB compressed, ~36MB unzipped, ~1220 v1 documents across
%   ~21 classes) and runs every contained body through
%   did2.convert.v1_to_v2 with Validate=true, targeting **V_epsilon**
%   (via the shared did2.unittest.helpers.runCorpusDiscovery driver,
%   same as the B / Dab / JH corpora), and writes a per-run summary
%   JSON to corpus-reports/20211116-summary.json that the workflow's
%   upload-artifact step picks up.
%
%   Discovery mode: the test does not assert zero quarantine. Its job
%   is to surface coverage signal (which classes / required fields are
%   not yet migratable) without blocking unrelated PRs on migrator
%   work. The single hard assertion (inside the helper) is that the
%   corpus contained at least one JSON file, to catch a broken fixture
%   URL.
%
%   The corpus URL:
%       https://ndi-programming-development.s3.us-east-1.amazonaws.com/20211116.zip
%   The zip contains a top-level 20211116/ directory of v1 NDI
%   document JSONs (plus __MACOSX/ sidecars that are skipped).
%
%   Schema-path resolution + teardown are handled by the shared
%   helpers (DID_SCHEMA_PATH first, then the did2.schema.cache
%   sibling-checkout default; assumeFail skip if neither resolves).
%
%   Run with:
%       results = runtests('did2.unittest.testCorpus20211116');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function test20211116CorpusDiscoveryReport(testCase)
did2.unittest.helpers.runCorpusDiscovery(testCase, '20211116', ...
    'https://ndi-programming-development.s3.us-east-1.amazonaws.com/20211116.zip', ...
    '20211116');
end
