function tests = testEthicsJurisdiction
%TESTETHICSJURISDICTION v1 EthicsAssessment -> the ethics jurisdiction term
%   (Jess Haley 2026-10-22 [ethics assessment to jurisdiction], S3b):
%   did2.convert.ethicsJurisdiction and entityDoc, which no longer writes the
%   obsolete EMPTY:0000355.
%
%   Run with:  results = runtests('did2.unittest.testEthicsJurisdiction');
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping ethics jurisdiction tests');
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testTheFourOpenmindsValues(testCase)
[t, n] = did2.convert.ethicsJurisdiction('EU compliant');
verifyEqual(testCase, t.node, 'wikidata:Q458');
verifyEmpty(testCase, n);
[t, n] = did2.convert.ethicsJurisdiction('EU compliant +');
verifyEqual(testCase, t.node, 'wikidata:Q458');
verifySubstring(testCase, n, 'additional ethics assessment');
[t, n] = did2.convert.ethicsJurisdiction(struct('node', '', 'name', 'US compliant'));
verifyEqual(testCase, t.node, 'wikidata:Q30');
verifyEmpty(testCase, n);
[t, n] = did2.convert.ethicsJurisdiction('not required');
verifyEmpty(testCase, t);
verifyEqual(testCase, n, 'not required');
[t, n] = did2.convert.ethicsJurisdiction('approved by the local board');
verifyEmpty(testCase, t);
verifyEqual(testCase, n, 'approved by the local board');
% openMINDS v4 instance IRIs
t = did2.convert.ethicsJurisdiction(struct('node', '', 'name', ...
    'https://openminds.om-i.org/instances/ethicsAssessment/EUCompliant+'));
verifyEqual(testCase, t.node, 'wikidata:Q458');
t = did2.convert.ethicsJurisdiction('https://openminds.om-i.org/instances/ethicsAssessment/USCompliant');
verifyEqual(testCase, t.node, 'wikidata:Q30');
end

function testEntityDocWritesTheJurisdictionNotTheObsoleteTerm(testCase)
pre = struct('base', struct('id', 'src_1', 'session_id', 'sess_1', ...
    'datestamp', '2024-01-01T00:00:00.000Z'));
docs = did2.convert.entities.entityDoc(pre, 'dataset', did.ido.unique_id(), ...
    struct('full_name', 'a dataset', 'ethics_assessment', ...
    struct('node', '', 'name', 'EU compliant +')), {}, false);
stmts = docs(cellfun(@(d) isfield(d, 'statement'), docs));
verifyEqual(testCase, numel(stmts), 1);
s = stmts{1};
verifyEqual(testCase, s.statement.variable.node, 'EMPTY:0000359');
verifyEqual(testCase, s.term.value.node, 'wikidata:Q458');
verifySubstring(testCase, s.statement.notes, 'additional ethics assessment');
txt = jsonencode(docs);
verifyFalse(testCase, contains(txt, 'EMPTY:0000355'), 'the obsolete term is not written');
end

function testNotRequiredMakesNoStatementAndIsCounted(testCase)
did2.convert.reportNote('reset');
testCase.addTeardown(@() did2.convert.reportNote('reset'));
pre = struct('base', struct('id', 'src_2', 'session_id', 'sess_1', ...
    'datestamp', '2024-01-01T00:00:00.000Z'));
docs = did2.convert.entities.entityDoc(pre, 'dataset', did.ido.unique_id(), ...
    struct('full_name', 'a dataset', 'ethics_assessment', ...
    struct('node', '', 'name', 'not required')), {}, false);
verifyEqual(testCase, numel(docs), 1, 'the entity alone');
notes = did2.convert.reportNote('collect');
verifyEqual(testCase, notes.ethics_assessment_no_statement.count, 1);
end
