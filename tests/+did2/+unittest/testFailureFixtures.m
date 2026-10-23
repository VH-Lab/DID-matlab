function tests = testFailureFixtures
%TESTFAILUREFIXTURES Corpus failures, reproduced on the quick gate.
%
%   Runs every folder under tests/+did2/fixtures/corpus_failures/ (written by
%   tools/extract_failure_fixtures.py from a red corpus report) through
%   did2.unittest.helpers.runCorpusDiscovery -- the same migration, batch
%   post-passes and report the corpus tests use -- and asserts the corpus
%   gates on it: 0 quarantine, 0 fragments, 0 empty required edges, 0 orphans
%   (the last inside the driver).
%
%   The name deliberately does NOT contain "testCorpus": the quick workflow
%   drops those, and this file exists to run there.
%
%   NO FOLDERS IS A SKIP, NOT A PASS. With nothing extracted there is nothing
%   to reproduce, and a green tick over zero fixtures is the all-zero report
%   this project has shipped before. The skip message carries the count.

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testEveryExtractedFixtureMigratesCleanly(testCase)
here = fileparts(mfilename('fullpath'));
root = fullfile(here, '..', 'fixtures', 'corpus_failures');
entries = dir(root);
entries = entries([entries.isdir] & ~startsWith({entries.name}, '.'));
fprintf('failure fixtures: %d folder(s) under %s\n', numel(entries), root);
if isempty(entries)
    assumeFail(testCase, sprintf( ...
        '0 extracted failure-fixture folders under %s -- nothing to reproduce', root));
end
for k = 1:numel(entries)
    name = entries(k).name;
    folder = fullfile(root, name);
    [~, result] = did2.unittest.helpers.runCorpusDiscovery(testCase, ...
        ['fixture-' name], 'none', name, 'CorpusDir', folder);
    verifyEqual(testCase, result.summary.quarantine_count, 0, ...
        sprintf('fixture %s: %d document(s) quarantined', name, ...
            result.summary.quarantine_count));
    verifyEqual(testCase, result.summary.fragment_count, 0, ...
        sprintf('fixture %s: %d fragment(s)', name, result.summary.fragment_count));
    if isfield(result, 'silent_loss') && isfield(result.silent_loss, 'empty_dependency_count')
        verifyEqual(testCase, result.silent_loss.empty_dependency_count, 0, ...
            sprintf('fixture %s: %d empty required edge(s)', name, ...
                result.silent_loss.empty_dependency_count));
    else
        verifyFail(testCase, sprintf( ...
            'fixture %s: silent_loss.empty_dependency_count NOT MEASURED', name));
    end
end
end
