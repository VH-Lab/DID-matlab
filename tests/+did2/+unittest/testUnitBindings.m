function tests = testUnitBindings
%TESTUNITBINDINGS A source unit outside its variable's closed unit list.
%
%   Decided by Jess Haley, 2026-10-27 [allowed units are closed source_unit
%   lists] and 2026-10-29 [allowed units are source units] (did-schema
%   V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G4): a variable's
%   did-schema binding_registry_meta.json `unit_bindings` row
%   {variable, source_units} is the closed list of units a SOURCE may give
%   its value in. did2.schema.unitInSet checks one unit,
%   did2.schema.unitBindingProblems a document, and the validator refuses
%   (did2:validation:unitOutsideSet) when strictMode('UnitBindings') is on.
%   The switch is DISARMED by default: writers of today give units outside
%   the seeded lists (did2.schema.cache strictMode, UnitBindings).
%
%   The registry here is a hand-made one, so the tests do not move when
%   did-schema adds rows; testTheLoadedRegistryHoldsTheSeededRows reads the
%   loaded one.
%
%   UNVERIFIED: written without MATLAB; CI is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testUnitBindings');

tests = functiontests(localfunctions);
end

% ---- one unit --------------------------------------------------------------------

function testAListedUnitIsAdmitted(testCase)
[tf, reason, governed] = did2.schema.unitInSet(timeTerm(), unit('om:millisecond-Time', 'millisecond'), registry());
verifyTrue(testCase, tf, reason);
verifyTrue(testCase, governed);
% by name, for a variable and a unit with no node
[tf, ~, governed] = did2.schema.unitInSet(struct('node', '', 'name', 'Time'), 'second', registry());
verifyTrue(testCase, tf);
verifyTrue(testCase, governed);
end

function testAnUnlistedUnitIsRefused(testCase)
[tf, reason, governed] = did2.schema.unitInSet(timeTerm(), unit('EMPTY:0000260', 'frame'), registry());
verifyFalse(testCase, tf);
verifyTrue(testCase, governed);
verifyTrue(testCase, contains(reason, 'EMPTY:0000260') && contains(reason, 'time'), reason);
end

function testAnUnboundVariableOrNoUnitIsNotGoverned(testCase)
[tf, ~, governed] = did2.schema.unitInSet(struct('node', 'NCIT:C25150', 'name', 'Age'), ...
    unit('om:day', 'day'), registry());
verifyTrue(testCase, tf);
verifyFalse(testCase, governed, 'no unit_bindings row');
[tf, ~, governed] = did2.schema.unitInSet(timeTerm(), struct('node', '', 'name', ''), registry());
verifyTrue(testCase, tf);
verifyFalse(testCase, governed, 'no unit stated');
[tf, ~, governed] = did2.schema.unitInSet(timeTerm(), unit('EMPTY:0000260', 'frame'), struct());
verifyTrue(testCase, tf);
verifyFalse(testCase, governed, 'a registry with no unit_bindings');
end

% ---- a document --------------------------------------------------------------------

function testADocumentsValueCellsAndEntriesAreRead(testCase)
doc = struct();
doc.document_class = struct('class_name', 'observation');
doc.base = struct('id', 'x');
doc.statement = struct('variable', timeTerm(), 'conditions', ...
    struct('variable', timeTerm(), 'source_unit', unit('om:hour', 'hour'), ...
    'quantity', struct('value', 3600, 'source_value', 1)));
doc.time = struct('value', struct('seconds', {1, 2}, 'source_value', {1, 2}, ...
    'source_unit', {unit('om:second-Time', 'second'), unit('EMPTY:0000260', 'frame')}));
doc.data = struct('covariates', struct('variable', timeTerm(), ...
    'source_unit', unit('EMPTY:0000260', 'frame')));
p = did2.schema.unitBindingProblems(doc, registry());
verifyEqual(testCase, numel(p), 3, strjoin(p, ' | '));
verifyTrue(testCase, any(contains(p, 'statement.conditions')), 'hour is not on the hand-made list');
verifyTrue(testCase, any(contains(p, 'time.value(2)')), 'the second value cell, in frames');
verifyTrue(testCase, any(contains(p, 'data.covariates')));
verifyFalse(testCase, any(contains(p, 'time.value(1)')), 'seconds are admitted');
end

function testADocumentWithNoBoundVariableHasNoProblems(testCase)
doc = struct();
doc.statement = struct('variable', struct('node', 'NCIT:C25150', 'name', 'Age'));
doc.time = struct('value', struct('seconds', 86400, 'source_value', 1, ...
    'source_unit', unit('om:day', 'day')));
verifyEmpty(testCase, did2.schema.unitBindingProblems(doc, registry()));
end

% ---- the switch and the loaded registry ---------------------------------------------

function testUnitBindingsIsDisarmedByDefault(testCase)
s = did2.schema.cache.strictMode('-reset');
if isempty(getenv('DID_ENFORCE_UNIT_BINDINGS'))
    verifyFalse(testCase, s.UnitBindings, ...
        'writers of today give units outside the lists: armed only on request');
end
end

function testTheLoadedRegistryHoldsTheSeededRows(testCase)
reg = did2.schema.cache.shared().bindingRegistry;
if ~isstruct(reg) || ~isfield(reg, 'unit_bindings')
    assumeFail(testCase, 'the loaded schema has no unit_bindings (did-schema before 74545bd)');
end
[tf, ~, governed] = did2.schema.unitInSet(timeTerm(), unit('om:second-Time', 'second'), reg);
verifyTrue(testCase, tf && governed, 'time admits seconds');
[tf, ~, governed] = did2.schema.unitInSet(struct('node', 'NCIT:C44477', 'name', 'X-Coordinate'), ...
    unit('om:micrometre', 'micrometre'), reg);
verifyTrue(testCase, tf && governed, 'X-Coordinate admits micrometres');
[tf, ~, governed] = did2.schema.unitInSet(timeTerm(), unit('EMPTY:0000260', 'frame'), reg);
verifyTrue(testCase, ~tf && governed, 'frame is not a time source unit (yet)');
end

% ---- fixture ------------------------------------------------------------------------

function t = timeTerm()
t = struct('node', 'om:Time', 'name', 'time');
end

function u = unit(node, name)
u = struct('node', node, 'name', name);
end

function r = registry()
row = struct('variable', timeTerm(), 'source_units', ...
    {{unit('om:second-Time', 'second'), unit('om:millisecond-Time', 'millisecond')}});
r = struct('unit_bindings', {{row}});
end
