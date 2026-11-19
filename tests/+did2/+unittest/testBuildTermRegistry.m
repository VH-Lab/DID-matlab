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

function testANameIsFoundIgnoringCaseSpacesUnderscoresAndHyphens(testCase)
% [term names match ignoring spacing] (Jess Haley, 2026-10-29): "path name"
% finds Pathname. The stored name must still be the registered one exactly.
ix = did2.schema.termIndex(registry());
verifyEqual(testCase, did2.schema.termNameKey('Body_Mid-point'), 'bodymidpoint');
verifyTrue(testCase, isKey(ix.byName, did2.schema.termNameKey('body-midpoint')));
verifyEqual(testCase, ix.byName(did2.schema.termNameKey('Body Midpoint')).name, 'body midpoint');
[tf, why] = did2.schema.termRegistered(term('', 'body_midpoint'), ix);
verifyFalse(testCase, tf, 'found, but not stored under the registered name');
verifyTrue(testCase, contains(why, 'registered as "body midpoint"'));
[tf, why] = did2.schema.termRegistered(term('', 'Me-dian'), ix);
verifyFalse(testCase, tf);
verifyTrue(testCase, contains(why, 'give the node'), 'found by its spelling, so the reason names the node');
verifyFalse(testCase, did2.schema.termRegistered(term('', 'mid point'), ix));
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

function testTheBuilderRefusesAnUnregisteredValueTerm(testCase)
% A statement's own value term is registered too (Jess Haley, 2026-10-20;
% DID-schema V_eta_term_registry_plan.md, open item 1): term.value and a
% chemical's substance are checked like a variable.
ix = needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
verifyError(testCase, @() did2.build.composite('term', 'value', ...
    did2.build.term('', 'a value nobody registered')), 'did2:build:unregisteredTerm');
verifyError(testCase, @() did2.build.composite('term', 'value', ...
    did2.build.term('EMPTY:9999999', 'a value nobody registered')), ...
    'did2:build:unregisteredTerm');
verifyError(testCase, @() did2.build.composite('chemical', 'value', ...
    struct('substance', did2.build.term('', 'a substance nobody registered'))), ...
    'did2:build:unregisteredTerm');
% a registered term passes in either slot
e = firstWithNode(ix);
verifyWarningFree(testCase, @() did2.build.composite('term', 'value', ...
    did2.build.term(e.node, e.name)));
verifyWarningFree(testCase, @() did2.build.composite('chemical', 'value', ...
    struct('substance', did2.build.term(e.node, e.name))));
end

function testDisarmedAndCollectingItRecordsAnUnregisteredValueTerm(testCase)
ix = needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
prevC = did2.build.unregisteredTerms('-collect', true);
testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prevC));
did2.build.unregisteredTerms('-reset');
testCase.addTeardown(@() did2.build.unregisteredTerms('-reset'));
e = firstWithNode(ix);
did2.build.composite('term', 'value', did2.build.term('', 'a value nobody registered'));
did2.build.composite('chemical', 'value', ...
    struct('substance', did2.build.term('', 'a substance nobody registered')));
did2.build.composite('term', 'value', did2.build.term(e.node, e.name));
did2.build.composite('chemical', 'value', struct('substance', did2.build.term(e.node, e.name)));
L = did2.build.unregisteredTerms();
verifyNumElements(testCase, L, 2, 'only the two unregistered terms are recorded');
v = L(strcmp({L.name}, 'a value nobody registered'));
verifyNumElements(testCase, v, 1);
verifyTrue(testCase, startsWith(v.field, 'term.value'));
c = L(strcmp({L.name}, 'a substance nobody registered'));
verifyNumElements(testCase, c, 1);
verifyEqual(testCase, c.field, 'chemical.value.substance');
end

% ============ a fit's coefficient and constraint symbols ====================
% did-schema docs/plans/did_v2_go_forward_class_audit.md, Decided by Jess
% Haley: [unbound term fields sorted] (2026-11-10) item (2), a model fit's
% `coefficients.variable` and `constraints.variable` are open by design (a
% model's own symbols, a term or a label); [tuning fit coefficients named by
% symbol] (2026-11-11), a fit names "each coefficient (and each constraint)
% by its symbol in the writer's equation". So a symbol such as 's' or 'C' is
% not looked up in the term registry in those two slots, and only there.

function testAFitsConstraintSymbolPassesArmed(testCase)
needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
nr = did2.convert.tuningFitModels('contrast', 'naka_rushton_RB');
% a standalone model_fit: Naka-Rushton RB, constraints n = 1 and s = 1
f = did2.build.fitEntry(did2.build.term(nr.node, nr.name), ...
    'Target', 'model_fit.value', ...
    'Coefficients', {symbol('Rm'), 12.1; symbol('c50'), 0.3}, ...
    'Fields', struct('constraints', did2.build.list(item('n', 1), item('s', 1))));
verifyEqual(testCase, f.constraints(2).variable.name, 's');
verifyEqual(testCase, f.coefficients(1).variable.name, 'Rm');
% one constraint, on a tuning curve's fit (movshon: C = 0)
mv = did2.convert.tuningFitModels('sf', 'movshon');
g = did2.build.fitEntry(did2.build.term(mv.node, mv.name), ...
    'Coefficients', {symbol('k'), 1; symbol('fc'), 2}, ...
    'Fields', struct('constraints', did2.build.list(item('C', 0))));
verifyEqual(testCase, g.constraints(1).variable.name, 'C');
end

function testAFitsCoefficientSymbolStillPassesArmed(testCase)
needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
nr = did2.convert.tuningFitModels('contrast', 'naka_rushton_RBNS');
f = did2.build.fitEntry(did2.build.term(nr.node, nr.name), ...
    'Target', 'model_fit.value', ...
    'Coefficients', {symbol('Rm'), 12.1; symbol('c50'), 0.3; symbol('n'), 2; symbol('s'), 1});
verifyEqual(testCase, f.coefficients(4).variable.name, 's');
end

function testTheSameSymbolInANonExemptSlotIsStillRefused(testCase)
% control: the exemption is the two fit paths, not the name. 's' as a fit's
% model or as a condition's variable is still looked up, and refused.
needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
verifyError(testCase, @() did2.build.fitEntry(symbol('s'), ...
    'Target', 'model_fit.value', ...
    'Fields', struct('constraints', did2.build.list(item('s', 1)))), ...
    'did2:build:unregisteredTerm');
verifyError(testCase, @() did2.build.condition(symbol('s'), 'Value', 1), ...
    'did2:build:unregisteredTerm');
end

function testTheCensusDoesNotListAFitsSymbols(testCase)
% the unregistered-terms census is filled by the same check, so it lists
% the control and not the exempt symbols
needRegistry(testCase);
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
prevC = did2.build.unregisteredTerms('-collect', true);
testCase.addTeardown(@() did2.build.unregisteredTerms('-collect', prevC));
did2.build.unregisteredTerms('-reset');
testCase.addTeardown(@() did2.build.unregisteredTerms('-reset'));
did2.build.fitEntry(symbol('a model nobody registered'), ...
    'Target', 'model_fit.value', ...
    'Coefficients', {symbol('Rm'), 12.1; symbol('c50'), 0.3}, ...
    'Fields', struct('constraints', did2.build.list(item('n', 1), item('s', 1))));
did2.build.fitEntry(symbol('a model nobody registered'), ...
    'Fields', struct('constraints', did2.build.list(item('C', 0))));
L = did2.build.unregisteredTerms();
verifyEqual(testCase, unique({L.name}), {'a model nobody registered'}, ...
    'only the model is recorded, not Rm, c50, n, s or C');
verifyFalse(testCase, any(contains({L.field}, 'constraints')));
verifyFalse(testCase, any(contains({L.field}, 'coefficients')));
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

function t = symbol(name)
% a coefficient's symbol as a label ({node '', name}), as the migrators write it
arguments
    name {mustBeText}
end
t = struct('node', '', 'name', char(name));
end

function c = item(name, x)
% a constraint {variable, numeric} (new numeric shape) or {variable, value} (old)
arguments
    name {mustBeText}
    x (1,1) double
end
if strcmp(did2.build.numericShape(), 'new')
    c = struct('variable', symbol(name), 'numeric', x);
else
    c = struct('variable', symbol(name), 'value', x);
end
end
