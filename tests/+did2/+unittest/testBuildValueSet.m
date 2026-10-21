function tests = testBuildValueSet
%TESTBUILDVALUESET did2.build refuses a value outside its variable's closed list.
%
%   A DID-schema binding row may carry `values`, a CLOSED list of the terms
%   its variable admits; an empty list admits nothing yet (Jess Haley,
%   2026-10-21; DID-schema V_eta_term_registry_plan.md, "Closed value
%   sets"). The match rule is tested on a registry written here; the
%   builder itself on the schema in DID_SCHEMA_PATH, when its registry
%   carries the material type list.
%
%   Example:
%       results = runtests('did2.unittest.testBuildValueSet');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build value-set tests');
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the match rule =======================================

function testAValueInTheListPassesAndOneOutsideFails(testCase)
reg = registry();
[tf, why, governed] = did2.schema.valueInSet(term('EMPTY:0000354', 'material type'), ...
    term('EMPTY:0000321', 'assay plate'), reg);
verifyTrue(testCase, tf, why);
verifyTrue(testCase, governed);
% the prefix is read by key, spelling or synonym, ignoring case
verifyTrue(testCase, did2.schema.valueInSet(term('empty:0000354', ''), ...
    term('ncit:C96141', 'Petri Dish'), reg));
[tf, why] = did2.schema.valueInSet(term('EMPTY:0000354', 'material type'), ...
    term('EMPTY:0000325', 'bacterial patch'), reg);
verifyFalse(testCase, tf);
verifyTrue(testCase, contains(why, 'not one of the 2 admitted value(s) of "material type"'), why);
end

function testEveryEntryOfAKeyedValueIsChecked(testCase)
reg = registry();
v = [term('EMPTY:0000321', 'assay plate'), term('EMPTY:0000325', 'bacterial patch')];
verifyFalse(testCase, did2.schema.valueInSet(term('EMPTY:0000354', ''), v, reg));
end

function testAnEmptyListAdmitsNothing(testCase)
[tf, why, governed] = did2.schema.valueInSet(term('EMPTY:0000357', 'culture type'), ...
    term('EMPTY:0000325', 'bacterial patch'), registry());
verifyFalse(testCase, tf);
verifyTrue(testCase, governed);
verifyTrue(testCase, contains(why, 'closed list is empty'), why);
end

function testARowWithNoListGovernsNothing(testCase)
reg = registry();
[tf, ~, governed] = did2.schema.valueInSet(term('NCIT:C45293', 'species'), ...
    term('NCBITaxon:6239', 'Caenorhabditis elegans'), reg);
verifyTrue(testCase, tf);
verifyFalse(testCase, governed, 'a subtree row is not a closed list');
[tf, ~, governed] = did2.schema.valueInSet(term('NCIT:C16608', 'Gene Expression'), ...
    term('', 'anything'), reg);
verifyTrue(testCase, tf);
verifyFalse(testCase, governed, 'term_valued false names no list');
[tf, ~, governed] = did2.schema.valueInSet(term('EMPTY:9999999', 'unbound'), ...
    term('', 'anything'), reg);
verifyTrue(testCase, tf);
verifyFalse(testCase, governed);
end

% ===================== the builder, on the schema in use ====================

function testTheBuilderRefusesAValueOutsideTheList(testCase)
cache = did2.schema.cache.shared();
assumeFalse(testCase, did2.schema.valueInSet(term('EMPTY:0000354', 'material type'), ...
    term('EMPTY:0000325', 'bacterial patch'), cache.bindingRegistry), ...
    'the schema in DID_SCHEMA_PATH carries no closed material type list');
prev = did2.schema.cache.strictMode('TermRegistry', true);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
var = did2.build.term('EMPTY:0000354', 'material type');
verifyError(testCase, @() did2.build.statement('assertion', did.ido.unique_id(), var, ...
    did2.build.term('EMPTY:0000325', 'bacterial patch'), 'SessionId', testCase.TestData.sid, 'ValueKind', 'term'), ...
    'did2:build:valueOutsideSet');
doc = did2.build.statement('assertion', did.ido.unique_id(), var, ...
    did2.build.term('EMPTY:0000321', 'assay plate'), 'SessionId', testCase.TestData.sid, 'ValueKind', 'term');
verifyNotEmpty(testCase, doc);
end

function testDisarmedTheBuilderDoesNotCheckTheList(testCase)
cache = did2.schema.cache.shared();
assumeFalse(testCase, did2.schema.valueInSet(term('EMPTY:0000354', 'material type'), ...
    term('EMPTY:0000325', 'bacterial patch'), cache.bindingRegistry), ...
    'the schema in DID_SCHEMA_PATH carries no closed material type list');
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
doc = did2.build.statement('assertion', did.ido.unique_id(), ...
    did2.build.term('EMPTY:0000354', 'material type'), ...
    did2.build.term('EMPTY:0000325', 'bacterial patch'), 'SessionId', testCase.TestData.sid, 'ValueKind', 'term');
verifyNotEmpty(testCase, doc, 'a migration disarms the check, as it disarms the term registry');
end

% ===================== helpers ==============================================

function t = term(node, name)
t = struct('node', char(node), 'name', char(name));
end

function r = registry()
r = jsondecode(['{"subject_statement_bindings": [' ...
    '{"variable": {"node": "NCIT:C45293", "name": "species"}, "class": "assertion",' ...
    ' "ontology": "NCBITaxon", "root_node": "NCBITaxon:1"},' ...
    '{"variable": {"node": "EMPTY:0000354", "name": "material type"}, "class": "assertion",' ...
    ' "node_form": "curie", "values": [' ...
    '  {"node": "EMPTY:0000321", "name": "assay plate"},' ...
    '  {"node": "NCIT:C96141", "name": "Petri Dish"}]},' ...
    '{"variable": {"node": "EMPTY:0000357", "name": "culture type"}, "class": "assertion",' ...
    ' "node_form": "curie", "values": []},' ...
    '{"variable": {"node": "NCIT:C16608", "name": "Gene Expression"},' ...
    ' "class": "spatial_gene_expression_pyramid", "term_valued": false}]}']);
end
