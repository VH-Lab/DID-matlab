function tests = testStatementKind
%TESTSTATEMENTKIND did2.convert.statementKind reads both vintages.
%   The matchers in epochMint, resolveEpochProbemap and resolveResponseParameters
%   recognise a statement through it: the did-schema #88 direction + value-kind
%   mixin, and (old-vintage input only) a pre-port document's joined class name.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase);
% The term registry check (tenet T19, strictMode 'TermRegistry') is OFF for
% this file, whatever DID_ENFORCE_TERM_REGISTRY says: testTheDirectionAndItsMixin
% builds a statement from the made-up variable 'voltage' to test how
% statementKind reads the class, not the registry. test-code.yml arms the
% registry, where it was refused ("voltage" is not in the term registry), as
% testBuild and testBuildMatrix were before 7a49a9f. The registry check is
% tested ARMED in testBuildTermRegistry and its siblings.
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testTheDirectionAndItsMixin(testCase)
c = did2.schema.cache.shared();
doc = did2.build.statement('observation', 'e1', 'voltage', [], 'ValueKind', 'voltage', ...
    'DataBody', true, 'TimeReferenceIds', {'t1'}, 'SessionId', 's1', 'Validate', false);
[d, k] = did2.convert.statementKind(doc);
verifyEqual(testCase, d, 'observation');
verifyEqual(testCase, k, 'voltage');
verifyTrue(testCase, c.hasClass('observation'));
end

function testAnOldVintageJoinedNameIsReadAsDirectionAndKind(testCase)
% a pre-port document (input only; nothing writes this form)
old = struct('document_class', struct('class_name', 'voltage_observation', ... % OLD-VINTAGE-INPUT
    'superclasses', struct('class_name', {'observation', 'voltage'})));
[d, k] = did2.convert.statementKind(old);
verifyEqual(testCase, d, 'observation');
verifyEqual(testCase, k, 'voltage');
old.document_class.class_name = 'harmonic_component_calculation'; % OLD-VINTAGE-INPUT
[d, k] = did2.convert.statementKind(old);
verifyEqual(testCase, {d, k}, {'calculation', 'harmonic_component'});
end

function testANamedCalculatorIsItsOwnClass(testCase)
doc = struct('document_class', struct('class_name', 'tuning_curve_calculation', ...
    'superclasses', struct('class_name', {'calculation'})));
[d, k] = did2.convert.statementKind(doc);
verifyEqual(testCase, d, 'tuning_curve_calculation');
verifyEqual(testCase, k, '');
end

function testANonStatementAnswersItsClass(testCase)
[d, k] = did2.convert.statementKind(struct('document_class', ...
    struct('class_name', 'relative_time_reference')));
verifyEqual(testCase, {d, k}, {'relative_time_reference', ''});
[d, k] = did2.convert.statementKind(struct());
verifyEqual(testCase, {d, k}, {'', ''});
end
