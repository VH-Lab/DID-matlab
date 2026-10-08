function tests = testBuild
%TESTBUILD did2.build: V_eta documents built from the schema, checked on the way.
%
%   The builder targets the #73 V_eta schema (did-schema main after PR #76).
%   The rest of this suite is pinned to the pre-#73 tag `v_eta-pre73`, so when
%   the loaded schema predates #73 every test here is FILTERED (assumeFail)
%   with a message saying so -- never silently passed. test-builder.yml runs
%   this file against did-schema main and fails if anything was filtered.
%
%   Each builder has at least one test that the document it makes passes
%   did2.schema.cache.validateDocument (the builders call it by default), and
%   one that a malformed input raises the builder's own error id.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   test-builder.yml is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testBuild');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping did2.build tests');
cache = did2.schema.cache.shared();
testCase.TestData.schemaPath = cache.schemaPath;
if ~isPost73(cache)
    assumeFail(testCase, sprintf(['did2.build targets the #73 V_eta schema; ' ...
        'the loaded schema (%s) predates it (no data.keys.n or no ' ...
        'base.creation_timestamp). test-builder.yml runs these tests ' ...
        'against did-schema main.'], cache.schemaPath));
end
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function tf = isPost73(cache)
tf = false;
if ~cache.hasClass('data') || ~cache.hasClass('base')
    return;
end
baseNames = cellfun(@(d) char(d.name), cache.ownFields('base'), 'UniformOutput', false);
if ~any(strcmp(baseNames, 'creation_timestamp'))
    return;
end
dataFields = cache.ownFields('data');
for k = 1:numel(dataFields)
    if strcmp(char(dataFields{k}.name), 'keys') && isfield(dataFields{k}, 'fields')
        sub = dataFields{k}.fields;
        if isstruct(sub)
            names = {sub.name};
        else
            names = cellfun(@(d) char(d.name), sub, 'UniformOutput', false);
        end
        tf = any(strcmp(names, 'n'));
        return;
    end
end
end

function id = newId()
id = did.ido.unique_id();
end

% ===================== document ============================================

function testDocumentBuildsASubject(testCase)
sid = testCase.TestData.sid;
[cls, fields, supers] = subjectSpec('mouse 7');
doc = did2.build.document(cls, fields, 'SessionId', sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
verifyEqual(testCase, doc.document_class.schema_version, 'V_eta');
verifyEqual(testCase, {doc.document_class.superclasses.class_name}, supers);
verifyEqual(testCase, doc.base.session_id, sid);
verifyNotEmpty(testCase, doc.base.id);
verifyFalse(testCase, isfield(doc.base, 'name'), ...
    'base.name is did_v1 only (#73 item 54); a V_eta document never writes it');
verifyMatches(testCase, doc.base.creation_timestamp, ...
    '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$');
verifyEqual(testCase, doc.(cls).local_identifier, 'mouse 7');
verifyFalse(testCase, isfield(doc.(cls), 'description'), ...
    'an optional field that was not given is left out, not blank-filled');
end

function testDocumentKeepsAGivenIdAndTimestamp(testCase)
id = newId();
[cls, fields] = subjectSpec('m1');
doc = did2.build.document(cls, fields, ...
    'SessionId', testCase.TestData.sid, 'Id', id, ...
    'CreationTimestamp', '2024-03-01T09:00:00.000Z');
verifyEqual(testCase, doc.base.id, id);
verifyEqual(testCase, doc.base.creation_timestamp, '2024-03-01T09:00:00.000Z');
end

function testDocumentRefusesWhatTheSchemaDoesNotDeclare(testCase)
sid = testCase.TestData.sid;
[cls, fields] = subjectSpec('m1');
withSpecies = fields;
withSpecies.species = 'mouse';
verifyError(testCase, @() did2.build.document(cls, withSpecies, 'SessionId', sid), ...
    'did2:build:unknownField');
withBase = fields;
withBase.base = struct('name', 'x');
verifyError(testCase, @() did2.build.document(cls, withBase, 'SessionId', sid), ...
    'did2:build:unknownField');
% the required field: `subject.local_identifier`, or `entity.type` since 2026-10-08
verifyError(testCase, @() did2.build.document(cls, struct(), 'SessionId', sid), ...
    'did2:build:missingField');
verifyError(testCase, @() did2.build.document(cls, fields), 'did2:build:missingField');
[stmt, ~] = vetaNamesOf();
verifyError(testCase, @() did2.build.document(stmt, struct(), ...
    'SessionId', sid), 'did2:build:abstractClass');
end

function testEdgesAreCheckedAgainstTheChain(testCase)
sid = testCase.TestData.sid;
v = did2.build.valueCell('voltage', 0.01);
fields = struct('variable', 'voltage', 'value', v);
[~, ent] = vetaNamesOf();   % entity_id (subject_id before 2026-10-08)
% the statement's entity edge is required
verifyError(testCase, @() did2.build.document('voltage_observation', fields, ...
    'SessionId', sid, 'Edges', struct('time_reference_id', newId())), ...
    'did2:build:missingEdge');
% an edge no class in the chain declares
verifyError(testCase, @() did2.build.document('voltage_observation', fields, ...
    'SessionId', sid, 'Edges', struct(ent, newId(), ...
    'time_reference_id', newId(), 'probe_id', newId())), 'did2:build:unknownEdge');
% the entity edge is not `multiple`
verifyError(testCase, @() did2.build.document('voltage_observation', fields, ...
    'SessionId', sid, 'Edges', struct(ent, {{newId(), newId()}}, ...
    'time_reference_id', newId())), 'did2:build:repeatedEdge');
% time_reference_id IS multiple (T15): repeated names, in order
t1 = newId(); t2 = newId();
doc = did2.build.document('voltage_observation', fields, 'SessionId', sid, ...
    'Edges', {ent, newId(); 'time_reference_id', {t1, t2}});
names = {doc.depends_on.name};
verifyEqual(testCase, sum(strcmp(names, 'time_reference_id')), 2);
ids = {doc.depends_on(strcmp(names, 'time_reference_id')).document_id};
verifyEqual(testCase, ids, {t1, t2});
verifyTrue(testCase, all(isfield(doc.depends_on, {'name', 'document_id'})));
end

function testUnknownSchemaRuleIsAnErrorNotASkip(testCase)
% Copy the schema set, add a rule nobody implemented, and build against it.
src = testCase.TestData.schemaPath;
tmp = tempname;
mkdir(tmp);
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
[cls, fields] = subjectSpec('m1');
subjectFile = fullfile(tmp, [cls '.json']);
% Insert the rule as TEXT: a jsondecode/jsonencode round trip would turn every
% one-element array in the schema into an object and change what is tested.
jsonText = fileread(subjectFile);
brace = find(jsonText == '{', 1);
jsonText = [jsonText(1:brace) ...
    '"rules": [{"name": "a_rule_nobody_implemented", "fields": ["local_identifier"], ' ...
    '"statement": "made up for this test"}], ' jsonText(brace+1:end)];
fid = fopen(subjectFile, 'w');
fwrite(fid, jsonText);
fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
verifyError(testCase, @() did2.build.document(cls, fields, ...
    'SessionId', testCase.TestData.sid), 'did2:build:unknownRule');
end

% ===================== term / label / datumType ============================

function testTermAndLabel(testCase)
t = did2.build.term('ncit:C14238', 'mouse');
verifyEqual(testCase, t, struct('node', 'ncit:C14238', 'name', 'mouse'));
l = did2.build.label({'A1', 'A2'});
verifyEqual(testCase, size(l), [1 2]);
verifyEqual(testCase, {l.node}, {'', ''});
verifyError(testCase, @() did2.build.term('', ''), 'did2:build:emptyTerm');
verifyError(testCase, @() did2.build.term({'a', 'b'}, {'x'}), 'did2:build:sizeMismatch');
end

function testDatumType(testCase)
verifyEqual(testCase, did2.build.datumType('int16'), 'int16');
[dt, src] = did2.build.datumType('double');
verifyEqual(testCase, {dt, src}, {'float64', 'double'});
verifyEqual(testCase, did2.build.datumType('double', 'Complex', true), 'complex128');
verifyEqual(testCase, did2.build.datumType('single', 'Complex', true), 'complex64');
verifyEqual(testCase, did2.build.datumType('ubit1'), 'bool');
verifyEqual(testCase, did2.build.datumType('string'), 'utf8');
verifyError(testCase, @() did2.build.datumType('char'), 'did2:build:unknownDatumType');
verifyError(testCase, @() did2.build.datumType('int8', 'Complex', true), 'did2:build:unknownDatumType');
end

% ===================== valueCell ===========================================

function testValueCellVoltage(testCase)
v = did2.build.valueCell('voltage', [0.012 0.013], 'SourceValue', [12 13], ...
    'SourceUnit', 'mV', 'Approximate', false);
verifyEqual(testCase, size(v), [1 2]);
verifyEqual(testCase, fieldnames(v)', {'volts', 'source_unit', 'source_value', 'approximate'}, ...
    'cell fields come out in the schema''s declared order');
verifyEqual(testCase, [v.volts], [0.012 0.013]);
verifyEqual(testCase, {v.source_unit}, {'mV', 'mV'});
end

function testValueCellLeavesOutWhatWasNotGiven(testCase)
v = did2.build.valueCell('time', 1.5);
verifyEqual(testCase, fieldnames(v)', {'seconds'});
end

function testValueCellOptionsMustBeDeclared(testCase)
c = did2.build.valueCell('count', int32(4));
verifyEqual(testCase, c.count, 4);
verifyError(testCase, @() did2.build.valueCell('count', 4, 'SourceUnit', 'cells'), ...
    'did2:build:unknownField');
verifyError(testCase, @() did2.build.valueCell('count', 4.5), 'did2:build:typeMismatch');
verifyError(testCase, @() did2.build.valueCell('voltage', [1 2], 'SourceValue', [1 2 3]), ...
    'did2:build:sizeMismatch');
verifyError(testCase, @() did2.build.valueCell('term', 'x'), 'did2:build:notACell');
end

function testValueCellDateNeedsItsPrecision(testCase)
verifyError(testCase, @() did2.build.valueCell('date', {'2024-03-01T00:00:00Z'}), ...
    'did2:build:missingField');
d = did2.build.valueCell('date', {'2024-03-01T00:00:00Z'}, ...
    'Fields', struct('precision', 'day'), 'SourceValue', {'1 March 2024'});
verifyEqual(testCase, d.instant, '2024-03-01T00:00:00Z');
verifyEqual(testCase, d.precision, 'day');
verifyError(testCase, @() did2.build.valueCell('date', {'2024'}, ...
    'Fields', struct('precision', 'decade')), 'did2:build:notInEnum');
end

function testValueCellPicksANamedCanonical(testCase)
c = did2.build.valueCell('concentration', 0.5, 'Canonical', 'grams_per_liter', ...
    'SourceValue', 500, 'SourceUnit', 'mg/L');
verifyEqual(testCase, c.grams_per_liter, 0.5);
verifyFalse(testCase, isfield(c, 'molar'));
verifyError(testCase, @() did2.build.valueCell('concentration', 1, 'Canonical', 'ppm'), ...
    'did2:build:unknownField');
end

% ===================== key / list ==========================================

function testRegularKey(testCase)
k = did2.build.key('time', 1000, 'Unit', 'second', 'Origin', 0, 'Spacing', 0.001);
verifyTrue(testCase, k.regular);
verifyEqual(testCase, k.origin.value, 0);
verifyEqual(testCase, k.spacing.value, 0.001);
verifyEqual(testCase, k.unit.name, 'second');
verifyFalse(testCase, isfield(k, 'values') || isfield(k, 'labels'));
end

function testKeyRules(testCase)
verifyError(testCase, @() did2.build.key('time', 10, 'Origin', 0), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.key('x', 2, 'Values', [1 2], 'Labels', {'a', 'b'}), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.key('x', 2), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.key('x', 3, 'Values', [1 2]), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.key('x', 2, 'Labels', {'a'}), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.key('x', 2, 'Origin', 0, 'Spacing', 1, 'Values', [1 2]), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.key({'a', 'b'}, 2, 'Values', [1 2]), ...
    'did2:build:typeMismatch');
end

function testKeyLabelsFromNames(testCase)
k = did2.build.key('channel', 2, 'Labels', {'A1', 'A2'});
verifyFalse(testCase, k.regular);
verifyEqual(testCase, {k.labels.name}, {'A1', 'A2'});
end

function testKeyPositionsFromAnotherDocument(testCase)
% did-schema 2026-10-05: a key takes its positions from a data_type document
% through `key_id`, chosen by the key's `positions_from` (was key_labels_id /
% labels_from). Position k is entry k of that document's value.
k = did2.build.key('encounter', 3, 'PositionsFrom', 0);
verifyFalse(testCase, k.regular);
verifyEqual(testCase, k.positions_from, 0);
verifyError(testCase, @() did2.build.key('encounter', 3, 'PositionsFrom', 0, ...
    'Values', [1 2 3]), 'did2:build:ruleViolated');
cache = did2.schema.cache.shared();
data = jsondecode(fileread(fullfile(cache.schemaPath, 'data.json')));
assumeTrue(testCase, any(strcmp({data.depends_on.name}, 'key_id')), ...
    'the loaded schema predates key_id (did-schema 2026-10-05)');
list = newId();
doc = did2.build.statement('voltage_observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', [0.01 0.02 0.03]), 'Keys', k, ...
    'KeyIds', {list}, 'TimeReferenceIds', {newId()}, ...
    'SessionId', testCase.TestData.sid);
hit = doc.depends_on(strcmp({doc.depends_on.name}, 'key_id'));
verifyEqual(testCase, {hit.document_id}, {list});
end

function testListMergesRaggedEntries(testCase)
keys = did2.build.list( ...
    did2.build.key('time', 10, 'Origin', 0, 'Spacing', 1, 'Unit', 'second'), ...
    did2.build.key('channel', 2, 'Values', [1 2]));
verifyEqual(testCase, size(keys), [1 2]);
verifyEmpty(testCase, keys(2).origin, 'absent fields are [] -- the schema cache''s absent marker');
verifyEmpty(testCase, keys(1).values);
verifyEqual(testCase, keys(2).values.values, [1 2]);
verifyEqual(testCase, size(did2.build.list()), [0 0]);
end

% ===================== condition / parameter / fitEntry ====================

function testCondition(testCase)
c = did2.build.condition('trial type', 'Term', 'catch');
verifyEqual(testCase, c.term.value.name, 'catch');
q = did2.build.condition('OD600', 'Quantity', 0.4, 'SourceValue', 0.4);
verifyEqual(testCase, q.quantity.value.value, 0.4);
verifyError(testCase, @() did2.build.condition('x', 'Count', 1, 'Quantity', 2), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.condition('x', 'Count', [1 2]), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.condition('x'), 'did2:build:ruleViolated');
end

function testParameter(testCase)
p = did2.build.parameter('threshold', 'Value', 4.5, 'SourceValue', '4.5', 'Unit', 'volt');
verifyEqual(testCase, p.value.value, 4.5);
verifyEqual(testCase, p.value.source_value, '4.5');
t = did2.build.parameter('detection method', 'Term', 'negative crossing');
verifyEqual(testCase, t.term.name, 'negative crossing');
verifyError(testCase, @() did2.build.parameter('x', 'Value', 1, 'Text', 'a'), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.parameter('x', 'Text', 'a', 'Unit', 'volt'), ...
    'did2:build:ruleViolated');
end

function testFitEntry(testCase)
f = did2.build.fitEntry('von Mises', ...
    'Coefficients', {'amplitude', 12.1; 'preferred direction', 90}, ...
    'Goodness', struct('r2', 0.91));
verifyEqual(testCase, f.model.name, 'von Mises');
verifyEqual(testCase, size(f.coefficients), [1 2]);
verifyEqual(testCase, f.coefficients(2).variable.name, 'preferred direction');
verifyEqual(testCase, f.goodness.r2, 0.91);
verifyError(testCase, @() did2.build.fitEntry('m', 'Goodness', struct('chi2', 1)), ...
    'did2:build:unknownField');
end

function testCompositeReportsTheNestedPath(testCase)
try
    did2.build.composite('relative_time_reference', 'value', ...
        struct('start', struct('seconds', 1, 'minutes', 2)));
    verifyFail(testCase, 'an undeclared nested field must raise');
catch err
    verifyEqual(testCase, err.identifier, 'did2:build:unknownField');
    verifySubstring(testCase, err.message, 'value.start');
    verifySubstring(testCase, err.message, 'minutes');
end
end

% ===================== statement ===========================================

function testStatementValidates(testCase)
sid = testCase.TestData.sid;
doc = did2.build.statement('voltage_observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', [0.01 0.02 0.03]), ...
    'Keys', did2.build.key('time', 3, 'Unit', 'second', 'Origin', 0, 'Spacing', 0.1), ...
    'Conditions', did2.build.condition('temperature', 'Quantity', 22, 'Unit', 'celsius'), ...
    'MethodParameters', did2.build.parameter('gain', 'Value', 100), ...
    'TimeReferenceIds', {newId()}, 'InstrumentId', newId(), 'SessionId', sid);
% `voltage_observation` is an `observation` listing `voltage` since 2026-10-08
[cls, supers] = leafSpec('voltage_observation');
verifyEqual(testCase, doc.document_class.class_name, cls);
verifyEqual(testCase, {doc.document_class.superclasses.class_name}, supers);
verifyEqual(testCase, [doc.voltage.value.volts], [0.01 0.02 0.03]);
[stmt, ~] = vetaNamesOf();
verifyEqual(testCase, doc.(stmt).variable.name, 'voltage');
verifyTrue(testCase, any(strcmp({doc.depends_on.name}, 'instrument_id')));
end

function testStatementNeedsATimeReference(testCase)
% subject_interaction declares time_reference_id with min_count 1
verifyError(testCase, @() did2.build.statement('voltage_observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'SessionId', testCase.TestData.sid), ...
    'did2:build:missingEdge');
end

function testStatementCrossFieldChecks(testCase)
sid = testCase.TestData.sid;
v = did2.build.valueCell('voltage', 0.01);
common = {'TimeReferenceIds', {newId()}, 'SessionId', sid};
% one variable used as both a key and a condition
verifyError(testCase, @() did2.build.statement('voltage_observation', newId(), 'voltage', ...
    v, 'Keys', did2.build.key('time', 1, 'Values', 0), ...
    'Conditions', did2.build.condition('time', 'Quantity', 1), common{:}), ...
    'did2:build:ruleViolated');
% inline parameters AND a method_parameters_id
verifyError(testCase, @() did2.build.statement('voltage_observation', newId(), 'voltage', ...
    v, 'MethodParameters', did2.build.parameter('gain', 'Value', 1), ...
    'MethodParametersId', newId(), common{:}), 'did2:build:ruleViolated');
% the same knob twice
verifyError(testCase, @() did2.build.statement('voltage_observation', newId(), 'voltage', ...
    v, 'MethodParameters', did2.build.list(did2.build.parameter('gain', 'Value', 1), ...
    did2.build.parameter('gain', 'Value', 2)), common{:}), 'did2:build:ruleViolated');
% `chunk` belongs to a sampled_body's keys only
verifyError(testCase, @() did2.build.statement('voltage_observation', newId(), 'voltage', ...
    v, 'Keys', did2.build.key('time', 1, 'Values', 0, 'Chunk', 1), common{:}), ...
    'did2:build:ruleViolated');
% data_body true needs a datum_type
verifyError(testCase, @() did2.build.statement('voltage_observation', newId(), 'voltage', ...
    [], 'DataBody', true, common{:}), 'did2:build:ruleViolated');
end

% ===================== value kinds (2026-10-08) ===============================

function testAValueKindIsListedAfterTheDirection(testCase)
% did-schema V_eta_entity_composition_plan.md sec. 1: a temperature reading is an
% `observation` whose superclasses list `temperature`'s chain after its own
if ~composes()
    return;   % a schema built before the composition has the join leaves
end
sid = testCase.TestData.sid;
v = did2.build.valueCell('temperature', 21.6);
c = did2.schema.cache.shared();
ent = 'entity_id';
a = did2.build.statement('temperature_observation', newId(), 'ambient temperature', v, ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid);
b = did2.build.document('observation', ...
    struct('variable', did2.build.term('', 'ambient temperature'), 'value', v), ...
    'ValueKind', 'temperature', 'SessionId', sid, ...
    'Edges', struct(ent, newId(), 'time_reference_id', newId()));
for doc = {a, b}
    d = doc{1};
    verifyEqual(testCase, d.document_class.class_name, 'observation');
    verifyEqual(testCase, {d.document_class.superclasses.class_name}, ...
        c.documentAncestors('observation', 'temperature'));
    verifyTrue(testCase, isfield(d, 'temperature'));
    verifyEqual(testCase, d.temperature.value.celsius, 21.6);
end
% a direction given no kind, or a kind on a class that takes none
verifyError(testCase, @() did2.build.document('observation', ...
    struct('variable', 'x'), 'SessionId', sid, ...
    'Edges', struct(ent, newId(), 'time_reference_id', newId())), ...
    'did2:build:missingValueKind');
[cls, fields] = subjectSpec('m1');
verifyError(testCase, @() did2.build.document(cls, fields, 'SessionId', sid, ...
    'ValueKind', 'temperature'), 'did2:build:missingValueKind');
end

function testTheValidatorChecksTheValueKind(testCase)
if ~composes()
    return;
end
sid = testCase.TestData.sid;
c = did2.schema.cache.shared();
doc = did2.build.statement('temperature_observation', newId(), 'ambient temperature', ...
    did2.build.valueCell('temperature', 21.6), 'TimeReferenceIds', {newId()}, ...
    'SessionId', sid);
c.validateDocument(doc);   % the built document is valid
% no kind listed
bad = doc;
own = c.superclasses('observation');
bad.document_class.superclasses = bad.document_class.superclasses(1:numel(own));
verifyError(testCase, @() c.validateDocument(bad), 'did2:validation:missingValueKind');
% a listed name that is not a value
bad = doc;
bad.document_class.superclasses(numel(own) + 1).class_name = 'session_in_a_dataset';
verifyError(testCase, @() c.validateDocument(bad), 'did2:validation:badValueKind');
% the kind's own block must be there
bad = rmfield(doc, 'temperature');
verifyError(testCase, @() c.validateDocument(bad), 'did2:validation:missingClassBlock');
% a named calculator carries its kind in its own chain, so it takes none
verifyEqual(testCase, c.documentAncestors('tuning_curve_calculation', ''), ...
    c.superclasses('tuning_curve_calculation'));
end

% ===================== bodies ==============================================

function testSampledBody(testCase)
sid = testCase.TestData.sid;
keys = did2.build.list( ...
    did2.build.key('time', 100, 'Unit', 'second', 'Origin', 0, 'Spacing', 0.01, 'Chunk', 50), ...
    did2.build.key('channel', 2, 'Labels', {'A1', 'A2'}));
body = did2.build.sampledBody(newId(), keys, 'DatumOrder', 'F', 'ByteOrder', 'little', ...
    'Chunks', 2, 'SessionId', sid);
verifyEqual(testCase, body.document_class.class_name, 'sampled_body');
verifyEqual(testCase, body.files.file_list, {'body_data_0', 'body_data_1'});
verifyEqual(testCase, body.sampled_body.datum_order, 'F');
verifyEqual(testCase, numel(body.data.keys), 2);
end

function testSampledBodyChecks(testCase)
sid = testCase.TestData.sid;
twoKeys = did2.build.list(did2.build.key('time', 2, 'Values', [0 1]), ...
    did2.build.key('channel', 1, 'Values', 1));
verifyError(testCase, @() did2.build.sampledBody(newId(), twoKeys, 'SessionId', sid), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.sampledBody(newId(), [], 'SessionId', sid), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.sampledBody(newId(), twoKeys, 'DatumOrder', 'X', ...
    'SessionId', sid), 'did2:build:notInEnum');
verifyError(testCase, @() did2.build.sampledBody(newId(), twoKeys, 'DatumOrder', 'C', ...
    'Files', {'data.bin'}, 'SessionId', sid), 'did2:build:unknownFile');
end

function testOpaqueBody(testCase)
body = did2.build.opaqueBody(newId(), 'application/pdf', 'HashAlgorithm', 'MD5', ...
    'ContentHash', 'd41d8cd98f00b204e9800998ecf8427e', 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, body.data_body.format, 'application/pdf');
verifyEqual(testCase, body.files.file_list, {'body_data_0'});
verifyError(testCase, @() did2.build.opaqueBody(newId(), '', 'SessionId', testCase.TestData.sid), ...
    'did2:build:missingField');
end

% ===================== time references =====================================

function testRelativeTimeReference(testCase)
sid = testCase.TestData.sid;
ref = did2.build.relativeTimeReference(newId(), 'Clock', 'dev_local_time', ...
    'Start', 12.5, 'StartSourceValue', 12500, 'StartSourceUnit', 'ms', ...
    'Duration', 2, 'SessionId', sid);
verifyEqual(testCase, ref.relative_time_reference.value.clock.name, 'dev_local_time');
verifyEqual(testCase, ref.relative_time_reference.value.start.seconds, 12.5);
verifyEqual(testCase, ref.relative_time_reference.value.duration.seconds, 2);
during = did2.build.relativeTimeReference(newId(), 'Relation', 'intervalDuring', 'SessionId', sid);
verifyEqual(testCase, during.relative_time_reference.value.relation.node, 'time:intervalDuring', ...
    'a name that exactly matches the bound value set is completed with its node');
verifyFalse(testCase, isfield(during.relative_time_reference.value, 'start'));
end

function testRelativeTimeReferenceRules(testCase)
sid = testCase.TestData.sid;
verifyError(testCase, @() did2.build.relativeTimeReference(newId(), 'Start', 1, ...
    'SessionId', sid), 'did2:build:ruleViolated');       % clock_with_start
verifyError(testCase, @() did2.build.relativeTimeReference(newId(), 'SessionId', sid), ...
    'did2:build:missingField');                          % no time at all
verifyError(testCase, @() did2.build.relativeTimeReference(newId(), 'Clock', 'utc', ...
    'Duration', 1, 'SessionId', sid), 'did2:build:ruleViolated');
end

function testAbsoluteTimeReference(testCase)
sid = testCase.TestData.sid;
ref = did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'SourceValue', '1 Mar 2024 10:00', 'SourceTimezone', 'Europe/Berlin', ...
    'Duration', 3600, 'SessionId', sid);
verifyEqual(testCase, ref.absolute_time_reference.value.start.utc, '2024-03-01T09:00:00.000Z');
verifyEqual(testCase, ref.absolute_time_reference.value.duration.seconds, 3600);
verifyError(testCase, @() did2.build.absoluteTimeReference('1 March 2024', 'SessionId', sid), ...
    'did2:build:typeMismatch');
end

function testTimeReferenceEnd(testCase)
% An end is its own fact with its own precision (did-schema: `value.end` on
% both time references): an approximate start with an exact end.
sid = testCase.TestData.sid;
ref = did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', 'Approximate', true, ...
    'End', '2024-03-01T10:00:00.000Z', 'Duration', 3600, 'DurationApproximate', true, ...
    'SessionId', sid);
v = ref.absolute_time_reference.value;
verifyTrue(testCase, v.start.approximate);
verifyEqual(testCase, v.end.utc, '2024-03-01T10:00:00.000Z');
verifyFalse(testCase, isfield(v.end, 'approximate'), 'the end is exact');
old = did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'SourceEnd', '1 Mar 2024 11:00', 'SessionId', sid);
verifyEqual(testCase, old.absolute_time_reference.value.end.source_value, '1 Mar 2024 11:00', ...
    '''SourceEnd'' keeps working: it fills end.source_value');
rel = did2.build.relativeTimeReference(newId(), 'Clock', 'dev_local_time', ...
    'Start', 10, 'StartApproximate', true, 'End', 70, 'SessionId', sid);
verifyEqual(testCase, rel.relative_time_reference.value.end.seconds, 70);
end

function testTimeReferenceEndRules(testCase)
% end_consistent: not before the start, and agreeing with a duration
sid = testCase.TestData.sid;
verifyError(testCase, @() did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'End', '2024-03-01T08:00:00.000Z', 'SessionId', sid), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'End', '2024-03-01T10:00:00.000Z', 'Duration', 60, 'SessionId', sid), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.relativeTimeReference(newId(), 'Clock', 'utc', ...
    'Start', 10, 'End', 5, 'SessionId', sid), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.relativeTimeReference(newId(), 'Clock', 'utc', ...
    'End', 5, 'SessionId', sid), 'did2:build:ruleViolated');           % end without start
verifyError(testCase, @() did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'End', 'tomorrow', 'SessionId', sid), 'did2:build:typeMismatch');
end

function testTolerance(testCase)
% CHANGE 7: a value may state a bound [minus plus] in its canonical unit --
% asymmetric (a transfer read off the video after it: 300 s earlier, 0 later).
sid = testCase.TestData.sid;
ref = did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'Tolerance', [300 0], 'End', '2024-03-01T10:00:00.000Z', 'EndTolerance', [0 0], ...
    'SessionId', sid);
v = ref.absolute_time_reference.value;
verifyEqual(testCase, v.start.tolerance, struct('minus', 300, 'plus', 0));
verifyTrue(testCase, v.start.approximate, 'a non-zero bound sets approximate');
verifyEqual(testCase, v.end.tolerance, struct('minus', 0, 'plus', 0));
verifyFalse(testCase, isfield(v.end, 'approximate'), '[0 0] states exact; not approximate');
rel = did2.build.relativeTimeReference(newId(), 'Clock', 'dev_local_time', ...
    'Start', 10, 'StartTolerance', [60 60], 'StartApproximate', false, 'SessionId', sid);
s = rel.relative_time_reference.value.start;
verifyEqual(testCase, s.tolerance, struct('minus', 60, 'plus', 60));
verifyFalse(testCase, s.approximate, 'an explicit Approximate is kept');
c = did2.build.valueCell('mass', [1.5 2.5], 'Tolerance', [0.05 0.05; 0 0.1]);
verifyEqual(testCase, c(2).tolerance, struct('minus', 0, 'plus', 0.1), 'one row per cell');
verifyFalse(testCase, isfield(rel.relative_time_reference.value, 'duration'));
verifyError(testCase, @() did2.build.absoluteTimeReference('2024-03-01T09:00:00.000Z', ...
    'Tolerance', [-1 0], 'SessionId', sid), 'did2:build:badTolerance');
verifyError(testCase, @() did2.build.relativeTimeReference(newId(), 'Clock', 'utc', ...
    'Start', 1, 'DurationTolerance', [1 1], 'SessionId', sid), 'did2:build:ruleViolated');
% CHANGE 7 amendment 1: counts, scores and dates take a bound too, in their own unit
n = did2.build.valueCell('count', 50, 'Tolerance', [5 5]);
verifyEqual(testCase, n.tolerance, struct('minus', 5, 'plus', 5), 'about 50, give or take 5');
verifyTrue(testCase, n.approximate);
end

% ===================== relations ===========================================

function testDirectedRelation(testCase)
child = newId(); parent = newId();
rel = did2.build.directedRelation(child, parent, did2.build.term('', 'part_of'), ...
    'Sequence', 2, 'SessionId', testCase.TestData.sid);
names = {rel.depends_on.name};
verifyEqual(testCase, rel.depends_on(strcmp(names, 'child_id')).document_id, child);
verifyEqual(testCase, rel.depends_on(strcmp(names, 'parent_id')).document_id, parent);
verifyEqual(testCase, rel.directed_relation.sequence, 2);
% prefixes match case-insensitively (CURIE_lookups_meta.json); the schema writes
% them lowercase since 2026-10-08, `BFO:` before
verifyEqual(testCase, lower(rel.directed_relation.relation.node), 'bfo:0000050', ...
    'part_of is completed from the bound relation value set');
end

function testUndirectedRelationNeedsTwoEntities(testCase)
sid = testCase.TestData.sid;
rel = did2.build.undirectedRelation({newId(), newId()}, did2.build.term('', 'same_as'), ...
    'SessionId', sid);
verifyEqual(testCase, sum(strcmp({rel.depends_on.name}, 'entity_id')), 2);
verifyError(testCase, @() did2.build.undirectedRelation({newId()}, ...
    did2.build.term('', 'same_as'), 'SessionId', sid), 'did2:build:missingEdge');
end

function [cls, fields, supers] = subjectSpec(localId)
% a subject as the schema in use builds one: `subject`, or since 2026-10-08
% (did-schema V_eta_entity_composition_plan.md sec. 4) an `entity` of type
% organism, whose `type` is required
if did2.schema.cache.shared().hasClass('subject')
    cls = 'subject';
    fields = struct('local_identifier', localId);
    supers = {'entity', 'base'};
else
    cls = 'entity';
    fields = struct('type', did2.build.term('', 'organism'), 'local_identifier', localId);
    supers = {'base'};
end
end

function [cls, supers] = leafSpec(leaf)
% the class and superclasses a statement leaf name builds: the leaf itself, or
% since 2026-10-08 its direction listing its value kind
c = did2.schema.cache.shared();
if c.hasClass(leaf)
    cls = leaf;
    supers = c.superclasses(leaf);
else
    parts = regexp(leaf, '^(.*)_([a-z]+)$', 'tokens', 'once');
    cls = parts{2};
    supers = c.documentAncestors(cls, parts{1});
end
end

function tf = composes()
% true on a schema whose statement directions take a value kind (2026-10-08)
c = did2.schema.cache.shared();
tf = c.hasClass('observation') && ~isempty(c.valueKindRule('observation'));
end

function [stmt, ent] = vetaNamesOf()
% the statement class and its entity edge as the schema in use spells them
% ('statement'/'entity_id' since 2026-10-08, did-schema V_eta_tenets.md T2;
% 'subject_statement'/'subject_id' before)
if did2.schema.cache.shared().hasClass('statement')
    stmt = 'statement'; ent = 'entity_id';
else
    stmt = 'subject_statement'; ent = 'subject_id';
end
end
