function tests = testCorpusCountsDump
%TESTCORPUSCOUNTSDUMP Scratch (branch claude/corpus-counts-1110 only). A
%   function-based test only so that runCorpusDiscovery gets a testCase with
%   TestData; the corpus is $COUNTS_CORPUS, the dump goes to $COUNTS_DUMP.
tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testDump(testCase)
corpus_counts_dump(testCase, getenv('COUNTS_CORPUS'), getenv('COUNTS_DUMP'));
end
