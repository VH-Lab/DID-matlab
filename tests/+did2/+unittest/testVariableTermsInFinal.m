function tests = testVariableTermsInFinal
%TESTVARIABLETERMSINFINAL did2.unittest.helpers.variableTermsInFinal reads
%   every statement.variable and method.parameters[].variable in a run's final
%   documents, states its denominators (documents walked, variables read)
%   first, and counts empty nodes and nodes the term registry lacks apart.
tests = functiontests(localfunctions);
end

function testVariablesAreCountedAtBothPathsAndSortedIntoKinds(testCase)
ix = did2.schema.termIndex(registry());
a = struct('statement', struct('variable', struct('node', 'NCIT:C28007', 'name', 'Median')));
b = struct('statement', struct('variable', struct('node', '', 'name', 'element type')));
% a standalone method document, parameters as a struct array
c = struct('method', struct('parameters', struct('variable', { ...
    struct('node', 'EMPTY:9999999', 'name', 'not registered'), ...
    struct('name', 'isspike')})));
% an interaction's inline method, parameters as a cell (ragged round trip)
d = struct('interaction', struct('method', struct('parameters', {{ ...
    struct('variable', struct('node', 'EMPTY:9999999', 'name', 'not registered'))}})));
% a `variable` somewhere else is not read
e = struct('data', struct('covariates', struct('variable', struct('node', 'X:1', 'name', 'x'))));
rep = did2.unittest.helpers.variableTermsInFinal({a, b, c, d, e}, ix);
verifyTrue(testCase, rep.registry_present);
verifyEqual(testCase, rep.docs_walked, 5, 'the denominator');
verifyEqual(testCase, rep.docs_unread, 0);
verifyEqual(testCase, rep.variables_read, 5);
verifyEqual(testCase, rep.empty_node, 2);
verifyEqual(testCase, rep.unregistered, 2);
kinds = {rep.offenders.kind};
verifyEqual(testCase, numel(rep.offenders), 3);
u = rep.offenders(strcmp(kinds, 'unregistered'));
verifyEqual(testCase, u.node, 'EMPTY:9999999');
verifyEqual(testCase, u.count, 2);
end

function testNothingReadIsZeroDocumentsNotZeroOffenders(testCase)
ix = did2.schema.termIndex(registry());
rep = did2.unittest.helpers.variableTermsInFinal({}, ix);
verifyEqual(testCase, rep.docs_walked, 0);
verifyEqual(testCase, rep.variables_read, 0);
rep = did2.unittest.helpers.variableTermsInFinal({struct('base', struct('id', 'x'))}, ix);
verifyEqual(testCase, rep.docs_walked, 1);
verifyEqual(testCase, rep.variables_read, 0);
end

function testNoRegistryLeavesUnregisteredUnmeasured(testCase)
ix = did2.schema.termIndex(struct('title', 'not a term registry'));
a = struct('statement', struct('variable', struct('node', 'NCIT:C28007', 'name', 'Median')));
rep = did2.unittest.helpers.variableTermsInFinal({a}, ix);
verifyFalse(testCase, rep.registry_present);
verifyEqual(testCase, rep.variables_read, 1);
verifyEqual(testCase, rep.unregistered, 0);
end

function r = registry()
r = jsondecode(['{"terms": [' ...
    '{"node": "NCIT:C28007", "name": "Median", "status": "decided"},' ...
    '{"node": "", "name": "body midpoint", "status": "staged"}]}']);
end
