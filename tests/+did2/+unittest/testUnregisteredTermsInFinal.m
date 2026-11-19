function tests = testUnregisteredTermsInFinal
%TESTUNREGISTEREDTERMSINFINAL did2.unittest.helpers.unregisteredTermsInFinal
%   counts, for each unregistered-term row did2.build collected, the FINAL
%   documents still holding that term at that field, and states its
%   denominator (the documents walked) first.
tests = functiontests(localfunctions);
end

function testARowIsCountedOnlyWhereAFinalDocumentHoldsIt(testCase)
rows = struct('name', {'element type', 'patch-I', 'hartley S'}, ...
    'node', {'', '', ''}, ...
    'field', {'statement.variable', 'term.value[]', 'data.covariates[].variable'}, ...
    'reason', {'r', 'r', 'r'}, 'count', {400, 200, 3});
a = struct('statement', struct('variable', struct('node', '', 'name', 'element type')), ...
    'term', struct('value', struct('node', '', 'name', 'patch-I')));
b = struct('statement', struct('variable', struct('node', 'NCIT:C178920', 'name', 'Equipment Type')));
c = struct('data', struct('covariates', {{struct('variable', struct('node', '', 'name', 'hartley S')), ...
    struct('variable', struct('node', '', 'name', 'hartley KXV'))}}));
% the same name at another field, or with a node, is not the row
d = struct('method', struct('parameters', struct('variable', struct('node', '', 'name', 'element type'))));
rep = did2.unittest.helpers.unregisteredTermsInFinal({a, b, c, d}, rows);
verifyEqual(testCase, rep.docs_walked, 4, 'the denominator');
verifyEqual(testCase, rep.docs_unread, 0);
verifyEqual(testCase, rep.terms_read, 6);
verifyEqual(testCase, [rep.rows.final_docs], [1 1 1]);
verifyEqual(testCase, [rep.rows.final_count], [1 1 1]);
verifyEqual(testCase, rep.rows_in_final, 3);
end

function testADroppedTermIsZeroInTheFinalDocuments(testCase)
rows = struct('name', 'element type', 'node', '', 'field', 'statement.variable', ...
    'reason', 'r', 'count', 400);
b = struct('statement', struct('variable', struct('node', 'NCIT:C178920', 'name', 'Equipment Type')));
rep = did2.unittest.helpers.unregisteredTermsInFinal({b, b}, rows);
verifyEqual(testCase, rep.docs_walked, 2);
verifyEqual(testCase, rep.rows.final_docs, 0);
verifyEqual(testCase, rep.rows_in_final, 0);
end

function testATermStoredWithNoNodeFieldIsCounted(testCase)
% a term whose node is empty may be stored with no `node` field at all
rows = struct('name', 'isspike', 'node', '', 'field', 'method.parameters[].variable', ...
    'reason', 'r', 'count', 273);
m = struct('method', struct('parameters', struct('variable', struct('name', 'isspike'))));
rep = did2.unittest.helpers.unregisteredTermsInFinal({m}, rows);
verifyEqual(testCase, rep.rows.final_docs, 1);
verifyEqual(testCase, rep.rows_in_final, 1);
end

function testNoRowsStillWalksAndCounts(testCase)
rows = struct('name', {}, 'node', {}, 'field', {}, 'reason', {}, 'count', {});
b = struct('statement', struct('variable', struct('node', 'NCIT:C178920', 'name', 'Equipment Type')));
rep = did2.unittest.helpers.unregisteredTermsInFinal({b}, rows);
verifyEqual(testCase, rep.docs_walked, 1);
verifyEqual(testCase, rep.terms_read, 1);
verifyEqual(testCase, rep.rows_in_final, 0);
verifyEmpty(testCase, rep.rows);
end
