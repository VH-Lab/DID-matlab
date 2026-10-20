function tests = testBuildTermRegistry
%TESTBUILDTERMREGISTRY did2.build refuses a term the term registry does not hold.
%
%   Tenet T19 and DID-schema V_eta_term_registry_plan.md (Jess Haley,
%   2026-10-20: "error until the term is registered"). The index and the
%   match rule are tested on a registry written here; the builder itself on
%   the schema in DID_SCHEMA_PATH, when that schema has a registry.
%
%   Example:
%       results = runtests('did2.unittest.testBuildTermRegistry');

tests = functiontests(localfunctions);
end

% ===================== the index and the match rule =========================

function testANodeIsMatchedByKeyAndTheNameMustBeTheRegisteredOne(testCase)
ix = did2.schema.termIndex(registry());
verifyTrue(testCase, ix.present);
verifyEqual(testCase, ix.count, 3);
verifyTrue(testCase, did2.schema.termRegistered(term('NCIT:C28007', 'Median'), ix));
% the prefix is read by key, spelling or synonym, ignoring case
verifyTrue(testCase, did2.schema.termRegistered(term('ncit:C28007', 'Median'), ix));
% a node given without its name is the registered term
verifyTrue(testCase, did2.schema.termRegistered(term('NCIT:C28007', ''), ix));
[tf, why] = did2.schema.termRegistered(term('NCIT:C28007', 'median'), ix);
verifyFalse(testCase, tf);
verifyTrue(testCase, contains(why, 'registered as "Median"'));
[tf, why] = did2.schema.termRegistered(term('STATO:0000574', 'center value'), ix);
verifyFalse(testCase, tf, 'another ontology''s median is not the registered one');
verifyTrue(testCase, contains(why, 'not in the term registry'));
end

function testAStagedTermIsMatchedByNameAlone(testCase)
ix = did2.schema.termIndex(registry());
verifyTrue(testCase, did2.schema.termRegistered(term('', 'body midpoint'), ix));
[tf, why] = did2.schema.termRegistered(term('', 'Median'), ix);
verifyFalse(testCase, tf, 'a term registered with a node must be given with it');
verifyTrue(testCase, contains(why, 'give the node'));
verifyFalse(testCase, did2.schema.termRegistered(term('', 'midpoint'), ix));
end

function testNoRegistryRegistersNothing(testCase)
ix = did2.schema.termIndex(struct('title', 'not a term registry'));
verifyFalse(testCase, ix.present);
verifyEqual(testCase, ix.count, 0);
end

function testCollectionListsEachDistinctTermOnceWithACount(testCase)
prev = did2.build.unregisteredTerms('-collect', true);
testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prev));
did2.build.unregisteredTerms('-reset');
testCase.addTeardown(@() did2.build.unregisteredTerms('-reset'));
t = term('', 'made up');
did2.build.unregisteredTerms('-add', t, 'statement.conditions(1).variable', 'why');
did2.build.unregisteredTerms('-add', t, 'statement.conditions(2).variable', 'why');
L = did2.build.unregisteredTerms();
verifyNumElements(testCase, L, 1);
verifyEqual(testCase, L.field, 'statement.conditions[].variable');
verifyEqual(testCase, L.count, 2);
end

% ===================== the builder, on the schema in use ====================

function testTheBuilderRefusesAnUnregisteredVariable(testCase)
ix = needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
verifyError(testCase, @() did2.build.condition( ...
    did2.build.term('', 'a variable nobody registered'), 'Value', 1), ...
    'did2:build:unregisteredTerm');
% a registered term passes
e = firstWithNode(ix);
verifyWarningFree(testCase, @() did2.build.condition(did2.build.term(e.node, e.name), 'Value', 1));
end

function testDisarmedAndCollectingItRecordsInsteadOfRefusing(testCase)
needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
prevC = did2.build.unregisteredTerms('-collect', true);
testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prevC));
did2.build.unregisteredTerms('-reset');
testCase.addTeardown(@() did2.build.unregisteredTerms('-reset'));
did2.build.condition(did2.build.term('', 'a variable nobody registered'), 'Value', 1);
L = did2.build.unregisteredTerms();
verifyTrue(testCase, any(strcmp({L.name}, 'a variable nobody registered')));
end

% ===================== helpers ==============================================

function ix = needRegistry(testCase)
arguments
    testCase
end
ix = did2.schema.termIndex();
assumeTrue(testCase, ix.present, ...
    'the schema in DID_SCHEMA_PATH has no term registry (did-schema main)');
end

function e = firstWithNode(ix)
arguments
    ix (1,1) struct
end
v = values(ix.byNode);
e = v{1};
end

function t = term(node, name)
arguments
    node {mustBeText}
    name {mustBeText}
end
t = struct('node', char(node), 'name', char(name));
end

function r = registry()
r = jsondecode(['{"terms": [' ...
    '{"node": "NCIT:C28007", "name": "Median", "status": "decided"},' ...
    '{"node": "UBERON:0000033", "name": "head", "status": "decided"},' ...
    '{"node": "", "name": "body midpoint", "status": "staged"}]}']);
end
