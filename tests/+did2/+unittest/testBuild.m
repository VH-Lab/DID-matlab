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
% The term registry check (tenet T19, strictMode 'TermRegistry') is OFF for
% this file, whatever DID_ENFORCE_TERM_REGISTRY says: these tests build from
% made-up terms ('voltage', 'colour palette', a bare {name:'time'}) to test the
% builder's mechanics. test-builder.yml and test-migrators-quick.yml set
% DID_ENFORCE_TERM_REGISTRY=0 for that reason; test-code.yml does not, so once
% this file stopped filtering itself there (AMENDMENT 6's dimensions.n), every
% made-up term was refused (run 39745771053). The registry check itself is
% tested with the switch ARMED in testBuildTermRegistry, testBuildSourceUnit,
% testBuildValueSet and testBuildMatrix/testTermChecksStillCoverVariableAndUnit.
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
cache = did2.schema.cache.shared();
testCase.TestData.schemaPath = cache.schemaPath;
if ~isPost73(cache)
    assumeFail(testCase, sprintf(['did2.build targets the #73 V_eta schema; ' ...
        'the loaded schema (%s) predates it (no data.dimensions.n -- ' ...
        'data_body AMENDMENT 6 -- or no ' ...
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
    % data_body AMENDMENT 6 (2026-10-22): `dimensions` {term, n, chunk}
    % replaced `keys`; the builder writes only the new shape
    if strcmp(char(dataFields{k}.name), 'dimensions') && isfield(dataFields{k}, 'fields')
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

function [given, written] = sourceUnit(node, name, spelling)
% A source unit in the shape the schema in use declares (did-schema
% V_eta_source_unit_plan.md): the unit's term where `source_unit` is an
% ontology_term, the source's spelling where it is char; and what the builder
% writes for it. testBuildSourceUnit pins both shapes whatever is loaded.
if did2.schema.cache.shared().sourceUnitIsTerm()
    given = did2.build.term(node, name);
else
    given = spelling;
end
written = given;
end

% ===================== document ============================================

function testDocumentBuildsASubject(testCase)
sid = testCase.TestData.sid;
[cls, fields, supers] = subjectSpec('mouse 7');
doc = did2.build.document(cls, fields, 'SessionId', sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
verifyEqual(testCase, doc.document_class.schema_version, 'V_eta');
verifyEqual(testCase, {doc.document_class.superclasses.class_name}, supers);
verifyEqual(testCase, sessionIdWritten(doc), sid);
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

function testSessionIdIsWrittenWhereTheSchemaDeclaresIt(testCase)
% did-schema V_eta_relation_inheritance_plan.md (2026-10-20): `base.session_id`
% became the required `session_id` edge. 'SessionId' writes whichever the
% loaded base declares -- exactly one of the two, never both.
sid = testCase.TestData.sid;
[cls, fields] = subjectSpec('m1');
doc = did2.build.document(cls, fields, 'SessionId', sid);
names = {doc.depends_on.name};
if did2.schema.cache.shared().sessionIdIsEdge()
    verifyFalse(testCase, isfield(doc.base, 'session_id'), ...
        'on the edge shape base.session_id must not be written as well');
    verifyEqual(testCase, nnz(strcmp(names, 'session_id')), 1, ...
        'the session_id edge is written once');
    verifyEqual(testCase, doc.depends_on(strcmp(names, 'session_id')).document_id, sid);
else
    verifyEqual(testCase, doc.base.session_id, sid);
    verifyFalse(testCase, any(strcmp(names, 'session_id')), ...
        'on the field shape no session_id edge is written');
end
end

function testSessionIdIsGivenOnlyThroughTheOption(testCase)
% 'SessionId' is the only way to give the session id: on the edge shape it IS
% the session_id edge, so naming that edge in 'Edges' too is a second id for an
% edge that takes one; on the field shape no class declares such an edge
sid = testCase.TestData.sid;
[cls, fields] = subjectSpec('m1');
if did2.schema.cache.shared().sessionIdIsEdge()
    expected = 'did2:build:repeatedEdge';
else
    expected = 'did2:build:unknownEdge';
end
verifyError(testCase, @() did2.build.document(cls, fields, 'SessionId', sid, ...
    'Edges', struct('session_id', newId())), expected);
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
verifyError(testCase, @() did2.build.document('observation', fields, ...
    'SessionId', sid, 'Edges', struct('time_reference_id', newId()), ...
    'ValueKind', 'voltage'), ...
    'did2:build:missingEdge');
% an edge no class in the chain declares
verifyError(testCase, @() did2.build.document('observation', fields, ...
    'SessionId', sid, 'Edges', struct(ent, newId(), ...
    'time_reference_id', newId(), 'probe_id', newId()), 'ValueKind', 'voltage'), ...
    'did2:build:unknownEdge');
% the entity edge is not `multiple`
verifyError(testCase, @() did2.build.document('observation', fields, ...
    'SessionId', sid, 'Edges', struct(ent, {{newId(), newId()}}, ...
    'time_reference_id', newId()), 'ValueKind', 'voltage'), 'did2:build:repeatedEdge');
% time_reference_id IS multiple (T15): repeated names, in order
t1 = newId(); t2 = newId();
doc = did2.build.document('observation', fields, 'SessionId', sid, ...
    'Edges', {ent, newId(); 'time_reference_id', {t1, t2}}, 'ValueKind', 'voltage');
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

function testCovariateShapeAndVariableOnceAreKnownSchemaRules(testCase)
% Jess Haley 2026-10-22 [covariate rules named], 6.1a: did-schema declares
% covariate_shape and variable_once as schema rules. A class that names them
% must build (they are checked in checkRules part 2 for every document), not
% raise did2:build:unknownRule as an unimplemented rule would.
src = testCase.TestData.schemaPath;
tmp = tempname;
mkdir(tmp);
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
[cls, fields] = subjectSpec('m1');
subjectFile = fullfile(tmp, [cls '.json']);
jsonText = fileread(subjectFile);
brace = find(jsonText == '{', 1);
jsonText = [jsonText(1:brace) ...
    '"rules": [{"name": "covariate_shape", "fields": ["local_identifier"], ' ...
    '"statement": "named for this test"}, {"name": "variable_once", ' ...
    '"fields": ["local_identifier"], "statement": "named for this test"}], ' ...
    jsonText(brace+1:end)];
fid = fopen(subjectFile, 'w');
fwrite(fid, jsonText);
fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
doc = did2.build.document(cls, fields, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, doc.document_class.class_name, cls);
end

function testCyclicCountCovariateIsRefusedOnTheDocument(testCase)
% [covariate details] 5.1a, checked where the document is built too: a
% covariate handed in as a plain struct (not through did2.build.covariate)
% with `cyclic` on a `count` is refused as covariate_cyclic.
sid = testCase.TestData.sid;
v = did2.build.valueCell('voltage', zeros(1, 3));
dims = did2.build.dimension('time', 3);
cov = struct('variable', struct('node', '', 'name', 'sample number'), ...
    'along', 0, 'count', [1 2 3], 'cyclic', true);
try
    did2.build.statement('observation', newId(), 'voltage', v, ...
        'Dimensions', dims, 'Covariates', cov, 'TimeReferenceIds', {newId()}, ...
        'SessionId', sid, 'ValueKind', 'voltage');
    verifyFail(testCase, 'a cyclic count covariate was accepted');
catch err
    verifyEqual(testCase, err.identifier, 'did2:build:ruleViolated');
    verifySubstring(testCase, err.message, 'covariate_cyclic');
end
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
[mV, written] = sourceUnit('om:millivolt', 'millivolt', 'mV');
v = did2.build.valueCell('voltage', [0.012 0.013], 'SourceValue', [12 13], ...
    'SourceUnit', mV, 'Approximate', false);
verifyEqual(testCase, size(v), [1 2]);
verifyEqual(testCase, fieldnames(v)', {'volts', 'source_unit', 'source_value', 'approximate'}, ...
    'cell fields come out in the schema''s declared order');
verifyEqual(testCase, [v.volts], [0.012 0.013]);
verifyEqual(testCase, {v.source_unit}, {written, written});
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
    'SourceValue', 500, 'SourceUnit', sourceUnit('om:milligramPerLitre', 'milligram per litre', 'mg/L'));
verifyEqual(testCase, c.grams_per_liter, 0.5);
verifyFalse(testCase, isfield(c, 'molar'));
verifyError(testCase, @() did2.build.valueCell('concentration', 1, 'Canonical', 'ppm'), ...
    'did2:build:unknownField');
end

% ===================== dimension / covariate / list ========================
% did-schema data_body AMENDMENT 6 (Jess Haley, 2026-10-22 [covariates],
% [along by index], [matrix covariate], [bare dimension]).

function testDimension(testCase)
d = did2.build.dimension('time', 1000);
verifyEqual(testCase, d.term.name, 'time');
verifyEqual(testCase, d.n, 1000);
verifyFalse(testCase, isfield(d, 'chunk'), 'no Chunk given, no chunk written');
d = did2.build.dimension('time', 1000, 'Chunk', 100);
verifyEqual(testCase, d.chunk, 100);
verifyError(testCase, @() did2.build.dimension({'a', 'b'}, 2), 'did2:build:typeMismatch');
end

function testRegularCovariate(testCase)
c = did2.build.covariate('time', 0, 'Unit', 'second', 'Origin', 0, 'Spacing', 0.001);
verifyEqual(testCase, c.along, 0);
verifyEqual(testCase, c.origin.value, 0);
verifyEqual(testCase, c.spacing.value, 0.001);
verifyEqual(testCase, c.unit.name, 'second');
verifyFalse(testCase, isfield(c, 'quantity') || isfield(c, 'term') || isfield(c, 'regular') ...
    || isfield(c, 'n'), 'AMENDMENT 6 removed `regular` and the entry''s `n`');
end

function testCovariateValueForms(testCase)
c = did2.build.covariate('channel', 1, 'Term', {'A1', 'A2'});
verifyEqual(testCase, {c.term.name}, {'A1', 'A2'});
c = did2.build.covariate('depth', 0, 'Value', [1 2 3], 'SourceValue', [1000 2000 3000], 'Unit', 'meter');
verifyEqual(testCase, c.quantity.value, [1 2 3]);
verifyEqual(testCase, c.quantity.source_value, [1000 2000 3000]);
c = did2.build.covariate('trial number', 0, 'Count', [1 2 3]);
verifyEqual(testCase, c.count, [1 2 3]);
c = did2.build.covariate('note', 0, 'Text', {'a', 'b'});
verifyEqual(testCase, cellstr(c.text), {'a', 'b'});
c = did2.build.covariate('control condition', 0, 'Logical', [true false true]);
verifyEqual(testCase, c.logical, [true false true]);
verifyClass(testCase, c.logical, 'logical');
c = did2.build.covariate('encounter', 0, 'Document', 0);
verifyEqual(testCase, c.document, 0);
c = did2.build.covariate('colour', 0, 'Matrix', ones(4, 3));
verifyEqual(testCase, c.matrix, ones(4, 3));
end

function testCovariateRules(testCase)
% exactly one value form
verifyError(testCase, @() did2.build.covariate('x', 0, 'Value', [1 2], 'Term', {'a', 'b'}), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', 0), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('time', 0, 'Origin', 0), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', 0, 'Origin', 0, 'Spacing', 1, 'Value', [1 2]), ...
    'did2:build:ruleViolated');
% along: non-empty, distinct, 0-based
verifyError(testCase, @() did2.build.covariate('x', [], 'Value', 1), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', [0 0], 'Value', 1), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', -1, 'Value', 1), 'did2:build:ruleViolated');
% origin+spacing and document run along ONE dimension
verifyError(testCase, @() did2.build.covariate('x', [0 1], 'Origin', 0, 'Spacing', 1), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', [0 1], 'Document', 0), ...
    'did2:build:ruleViolated');
% cyclic only on an origin+spacing or a quantity covariate along one
% dimension (Jess Haley 2026-10-22 [covariate details], 5.1a: not on a count
% or a matrix, which a numeric covariate along one dimension could be before)
verifyError(testCase, @() did2.build.covariate('x', 0, 'Term', {'a'}, 'Cyclic', true), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', [0 1], 'Value', ones(2), 'Cyclic', true), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', 0, 'Count', [1 2 3], 'Cyclic', true), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate('x', 0, 'Matrix', ones(3, 2), 'Cyclic', true), ...
    'did2:build:ruleViolated');
c = did2.build.covariate('direction', 0, 'Value', [0 90 180 270], 'Unit', 'degree', 'Cyclic', true);
verifyTrue(testCase, c.cyclic);
c = did2.build.covariate('phase', 0, 'Origin', 0, 'Spacing', 90, 'Unit', 'degree', 'Cyclic', true);
verifyTrue(testCase, c.cyclic);
% a unit only on a number, a count or a matrix
verifyError(testCase, @() did2.build.covariate('x', 0, 'Term', {'a'}, 'Unit', 'second'), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.covariate({'a', 'b'}, 0, 'Value', [1 2]), ...
    'did2:build:typeMismatch');
end

function testCovariatesAreCheckedAgainstTheDimensions(testCase)
% covariate_along (an index past the dimensions) and covariate_shape (the
% extents of the along dimensions; a matrix: those, then its own shape) are
% checked where the dimensions are: when the document is built.
sid = testCase.TestData.sid;
v = did2.build.valueCell('voltage', zeros(1, 6));
common = {'TimeReferenceIds', {newId()}, 'SessionId', sid, 'ValueKind', 'voltage'};
dims = did2.build.list(did2.build.dimension('time', 3), did2.build.dimension('channel', 2));
build = @(covs) did2.build.statement('observation', newId(), 'voltage', v, ...
    'Dimensions', dims, 'Covariates', covs, 'DatumOrder', 'F', common{:});
% along out of range
verifyError(testCase, @() build(did2.build.covariate('x', 2, 'Value', [1 2])), ...
    'did2:build:ruleViolated');
% one dimension: n values
verifyError(testCase, @() build(did2.build.covariate('time', 0, 'Value', [1 2])), ...
    'did2:build:ruleViolated');
build(did2.build.covariate('time', 0, 'Value', [0 1 2]));
% two dimensions: their extents, in `along`'s order
doc = build(did2.build.covariate('good', [0 1], 'Logical', true(3, 2)));
verifyEqual(testCase, size(doc.data.covariates.logical), [3 2]);
verifyError(testCase, @() build(did2.build.covariate('good', [1 0], 'Logical', true(3, 2))), ...
    'did2:build:ruleViolated');
build(did2.build.covariate('good', [1 0], 'Logical', true(2, 3)));
% matrix: a whole array at each position -- leading extents, then its shape
doc = build(did2.build.covariate('rgb', 1, 'Matrix', ones(2, 3)));
verifyEqual(testCase, size(doc.data.covariates.matrix), [2 3]);
verifyError(testCase, @() build(did2.build.covariate('rgb', 1, 'Matrix', ones(3, 3))), ...
    'did2:build:ruleViolated');
% document: along one dimension (n checked against the other document in batch)
build(did2.build.covariate('encounter', 0, 'Document', 0));
% a bare dimension (no covariate) is allowed
did2.build.statement('observation', newId(), 'voltage', v, 'Dimensions', dims, ...
    'DatumOrder', 'F', common{:});
end

function testCovariateDocumentPositionsFromAnotherDocument(testCase)
% A covariate takes its positions from a value document through `key_id`,
% chosen by its `document` (was a key's `positions_from`). Position k is
% entry k of that document's value.
cache = did2.schema.cache.shared();
data = jsondecode(fileread(fullfile(cache.schemaPath, 'data.json')));
assumeTrue(testCase, any(strcmp({data.depends_on.name}, 'key_id')), ...
    'the loaded schema has no key_id edge');
list = newId();
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', [0.01 0.02 0.03]), ...
    'Dimensions', did2.build.dimension('encounter', 3), ...
    'Covariates', did2.build.covariate('encounter', 0, 'Document', 0), ...
    'KeyIds', {list}, 'TimeReferenceIds', {newId()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage');
hit = doc.depends_on(strcmp({doc.depends_on.name}, 'key_id'));
verifyEqual(testCase, {hit.document_id}, {list});
verifyEqual(testCase, doc.data.covariates.document, 0);
end

function testListMergesRaggedEntries(testCase)
covs = did2.build.list( ...
    did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 1, 'Unit', 'second'), ...
    did2.build.covariate('channel', 1, 'Value', [1 2]));
verifyEqual(testCase, size(covs), [1 2]);
verifyEmpty(testCase, covs(2).origin, 'absent fields are [] -- the schema cache''s absent marker');
verifyEmpty(testCase, covs(1).quantity);
verifyEqual(testCase, covs(2).quantity.value, [1 2]);
verifyEqual(testCase, size(did2.build.list()), [0 0]);
end

% ===================== condition / parameter / fitEntry ====================

function testCondition(testCase)
c = did2.build.condition('trial type', 'Term', 'catch');
verifyEqual(testCase, c.term.name, 'catch');
q = did2.build.condition('OD600', 'Quantity', 0.4, 'SourceValue', '0.40');
verifyEqual(testCase, q.quantity.value, 0.4);
verifyEqual(testCase, q.quantity.source_value, '0.40', 'the source text is kept verbatim');
v = did2.build.condition('OD600', 'Value', 0.4, 'SourceValue', 0.4);
verifyEqual(testCase, v.quantity.value, 0.4, '''Value'' is the same option as ''Quantity''');
verifyEqual(testCase, v.quantity.source_value, '0.4', 'a numeric SourceValue is written as text');
n = did2.build.condition('trial count', 'Count', 12);
verifyEqual(testCase, n.count, 12);
t = did2.build.condition('protocol', 'Text', 'free run');
verifyEqual(testCase, t.text, 'free run');
verifyError(testCase, @() did2.build.condition('x', 'Value', 1, 'Quantity', 2), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.condition('x', 'Count', 1, 'Quantity', 2), ...
    'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.condition('x', 'Count', [1 2]), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.condition('x'), 'did2:build:ruleViolated');
end

function testParameter(testCase)
p = did2.build.parameter('threshold', 'Value', 4.5, 'SourceValue', '4.5', 'Unit', 'volt');
verifyEqual(testCase, p.quantity.value, 4.5);
verifyEqual(testCase, p.quantity.source_value, '4.5');
verifyFalse(testCase, isfield(p, 'value'));
a = did2.build.parameter('threshold', 'Value', 4.5, 'Approximate', true);
verifyTrue(testCase, a.approximate);
n = did2.build.parameter('passes', 'Count', 3);
verifyEqual(testCase, n.count, 3);
verifyError(testCase, @() did2.build.parameter('x', 'Value', [1 2]), 'did2:build:ruleViolated');
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
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', [0.01 0.02 0.03]), ...
    'Dimensions', did2.build.dimension('time', 3), ...
    'Covariates', did2.build.covariate('time', 0, 'Unit', 'second', 'Origin', 0, 'Spacing', 0.1), ...
    'Conditions', did2.build.condition('temperature', 'Quantity', 22, 'Unit', 'celsius'), ...
    'MethodParameters', did2.build.parameter('gain', 'Value', 100), ...
    'TimeReferenceIds', {newId()}, 'InstrumentId', newId(), 'SessionId', sid, 'ValueKind', 'voltage');
% an `observation` listing `voltage` (since 2026-10-08)
[cls, supers] = leafSpec('observation', 'voltage');
verifyEqual(testCase, doc.document_class.class_name, cls);
verifyEqual(testCase, {doc.document_class.superclasses.class_name}, supers);
verifyEqual(testCase, [doc.voltage.value.volts], [0.01 0.02 0.03]);
[stmt, ~] = vetaNamesOf();
verifyEqual(testCase, doc.(stmt).variable.name, 'voltage');
verifyTrue(testCase, any(strcmp({doc.depends_on.name}, 'instrument_id')));
end

function testStatementNeedsATimeReference(testCase)
% subject_interaction declares time_reference_id with min_count 1
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage'), ...
    'did2:build:missingEdge');
end

function testStatementCrossFieldChecks(testCase)
sid = testCase.TestData.sid;
v = did2.build.valueCell('voltage', 0.01);
common = {'TimeReferenceIds', {newId()}, 'SessionId', sid};
% one variable used as both a covariate and a condition (variable_once)
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    v, 'Dimensions', did2.build.dimension('time', 1), ...
    'Covariates', did2.build.covariate('time', 0, 'Value', 0), ...
    'Conditions', did2.build.condition('time', 'Quantity', 1), common{:}, 'ValueKind', 'voltage'), ...
    'did2:build:ruleViolated');
% ... or twice among the covariates
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    v, 'Dimensions', did2.build.dimension('time', 1), ...
    'Covariates', did2.build.list(did2.build.covariate('time', 0, 'Value', 0), ...
    did2.build.covariate('time', 0, 'Count', 0)), common{:}, 'ValueKind', 'voltage'), ...
    'did2:build:ruleViolated');
% a dimension's term may repeat (a channel x channel matrix), and a
% covariate's variable may be its dimension's term
did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', zeros(1, 4)), ...
    'Dimensions', did2.build.list(did2.build.dimension('channel', 2), did2.build.dimension('channel', 2)), ...
    'Covariates', did2.build.covariate('channel', 0, 'Term', {'A', 'B'}), ...
    'DatumOrder', 'F', common{:}, 'ValueKind', 'voltage');
% inline parameters AND a method_parameters_id: never both, until did-schema
% declares method_shared_and_own (Jess Haley 2026-10-22 [method shared plus
% own]), which allows settings only this run had beside the shared method
if schemaDeclaresRule('interaction', 'method_shared_and_own')
    did2.build.statement('observation', newId(), 'voltage', ...
        v, 'MethodParameters', did2.build.parameter('gain', 'Value', 1), ...
        'MethodParametersId', newId(), common{:}, 'ValueKind', 'voltage');
else
    verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
        v, 'MethodParameters', did2.build.parameter('gain', 'Value', 1), ...
        'MethodParametersId', newId(), common{:}, 'ValueKind', 'voltage'), 'did2:build:ruleViolated');
end
% the same knob twice
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    v, 'MethodParameters', did2.build.list(did2.build.parameter('gain', 'Value', 1), ...
    did2.build.parameter('gain', 'Value', 2)), common{:}, 'ValueKind', 'voltage'), 'did2:build:ruleViolated');
% `chunk` belongs to a sampled_body's dimensions only
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    v, 'Dimensions', did2.build.dimension('time', 1, 'Chunk', 1), common{:}, 'ValueKind', 'voltage'), ...
    'did2:build:ruleViolated');
% data_type only for plain-array bytes (Jess Haley, 2026-10-21): data_body
% true alone does not need one (the body may be an opaque_body, whose format
% term is the encoding). A bare inline array where the schema declares a cell
% is refused by the type check before any rule is read.
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    [0.01 0.02], common{:}, 'ValueKind', 'voltage'), 'did2:build:typeMismatch');
did2.build.statement('observation', newId(), 'voltage', [], ...
    'DataBody', true, common{:}, 'ValueKind', 'voltage');
end

function testValueInlineOrBody(testCase)
% did-schema rule `value_inline_or_body` on `value` (data_body AMENDMENT 5,
% Jess Haley, 2026-10-21; decided, not signed): a value is inline or in data
% bodies, never neither. It replaces the required `value` of nine classes.
if ~valueRuleDeclared()
    assumeFail(testCase, ['the loaded schema''s `value` does not declare ' ...
        '`value_inline_or_body` (did-schema before 697427d)']);
end
sid = testCase.TestData.sid;
common = {'TimeReferenceIds', {newId()}, 'SessionId', sid};
% neither inline nor in bodies: refused
verifyError(testCase, @() did2.build.statement('observation', newId(), ...
    'voltage', [], common{:}, 'ValueKind', 'voltage'), 'did2:build:ruleViolated');
% in bodies, no inline value: builds
doc = did2.build.statement('observation', newId(), 'voltage', [], ...
    'DataBody', true, 'DatumType', did2.build.datumType('int16'), common{:}, 'ValueKind', 'voltage');
verifyEqual(testCase, doc.document_class.class_name, leafSpec('observation', 'voltage'));
% inline: builds
did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), common{:}, 'ValueKind', 'voltage');
% a shared standalone value (value_id): statement.json says the statement's
% own value is then empty (clarification, Jess Haley, 2026-10-21).
did2.build.statement('observation', newId(), 'voltage', [], ...
    'ValueId', newId(), common{:}, 'ValueKind', 'voltage');
end

function testDoseIngredientsMatchTheirEdges(testCase)
% did-schema dose.json (Jess Haley, 2026-10-21 [dose per ingredient]): rule
% `ingredients_match_edges` -- one `value.ingredients` entry per
% `ingredient_id` edge. `ingredient_in_formulation` needs the formulation and
% is left to a batch check, so building a dose never errors on it.
c = did2.schema.cache.shared();
if ~c.hasClass('dose') || ~isfield(c.getClass('dose'), 'rules') ...
        || ~any(strcmp(cellfun(@(r) char(r.name), asCell(c.getClass('dose').rules), ...
            'UniformOutput', false), 'ingredients_match_edges'))
    assumeFail(testCase, 'the loaded schema has no dose ingredients_match_edges rule');
end
sid = testCase.TestData.sid;
apbm = struct('amount_per_body_mass', struct('grams_per_gram', 1e-6, 'source_value', 1));
val = struct('volume', did2.build.valueCell('volume', NaN), 'ingredients', apbm);
base = struct('entity_id', newId(), 'time_reference_id', newId(), 'formulation_id', newId());
withEdge = base; withEdge.ingredient_id = {newId()};
doc = did2.build.document('manipulation', ...
    struct('variable', did2.build.term('', 'dose'), 'value', val), ...
    'ValueKind', 'dose', 'SessionId', sid, 'Edges', withEdge);
verifyEqual(testCase, doc.dose.value.ingredients(1).amount_per_body_mass.grams_per_gram, 1e-6);
verifyError(testCase, @() did2.build.document('manipulation', ...
    struct('variable', did2.build.term('', 'dose'), 'value', val), ...
    'ValueKind', 'dose', 'SessionId', sid, 'Edges', base), ...
    'did2:build:ruleViolated');
end

function c = asCell(x)
if iscell(x); c = x(:)'; else; c = num2cell(x(:)'); end
end

function testAnUnrecordedAmountIsNaNAndCountsAsStated(testCase)
% Jess Haley, 2026-10-21 (did-schema V_eta_go_forward_class_audit.md): an
% unrecorded amount is written as NaN in its quantity (e.g. a dose's
% volume.liters: NaN), and V2 stores NaN the way V1 does. So a NaN-valued
% dose is a STATED value under value_inline_or_body, and it survives a
% did2.database.sqlitedb write and read (did2.document/toJSON writes the
% literal NaN; plain jsonencode wrote null, which read back as []).
if ~valueRuleDeclared() || ~composes() || ~did2.schema.cache.shared().hasClass('dose')
    assumeFail(testCase, 'the loaded schema has no value rule, no value kinds or no dose');
end
sid = testCase.TestData.sid;
% dose requires the formulation given (dose.json `formulation_id`)
edges = struct('entity_id', newId(), 'time_reference_id', newId(), ...
    'formulation_id', newId());
unknown = struct('volume', did2.build.valueCell('volume', NaN));
doc = did2.build.document('manipulation', ...
    struct('variable', did2.build.term('', 'dose'), 'value', unknown), ...
    'ValueKind', 'dose', 'SessionId', sid, 'Edges', edges);
verifyTrue(testCase, isnan(doc.dose.value.volume.liters));
% the rule is in force for dose: an empty value is refused
verifyError(testCase, @() did2.build.document('manipulation', ...
    struct('variable', did2.build.term('', 'dose'), 'value', struct()), ...
    'ValueKind', 'dose', 'SessionId', sid, 'Edges', edges), ...
    'did2:build:ruleViolated');
if isempty(which('mksqlite'))
    return;   % the database half needs mksqlite
end
f = [tempname() '.sqlite'];
db = did2.database.sqlitedb(f);
cleanup = onCleanup(@() closeAndDelete(db, f)); %#ok<NASGU>
d = did2.document(doc);
db.add(d);
back = db.get(d.get('base.id'));
verifyTrue(testCase, isnan(back.get('dose.value.volume.liters')), ...
    'the unrecorded amount must read back as NaN, not []');
back.validate();
end

function closeAndDelete(db, f)
try
    db.close();
catch
end
if isfile(f)
    delete(f);
end
end

function testFormulationValuedThroughValueIdSkipsIngredientsOrProduct(testCase)
% A bath is a manipulation valued by its formulation (Jess Haley, 2026-10-21):
% the statement's own `value` is empty and `value_id` names the formulation
% document, which holds the ingredients. `ingredients_or_product` and
% `value_inline_or_body` both pass; without the edge the statement is refused.
sid = testCase.TestData.sid;
common = {'TimeReferenceIds', {newId()}, 'SessionId', sid};
doc = did2.build.statement('manipulation', newId(), 'treatment', [], ...
    'ValueId', newId(), common{:}, 'ValueKind', 'formulation');
verifyTrue(testCase, any(strcmp({doc.depends_on.name}, 'value_id')));
verifyError(testCase, @() did2.build.statement('manipulation', newId(), ...
    'treatment', [], common{:}, 'ValueKind', 'formulation'), 'did2:build:ruleViolated');
end

function testADoseStatesAnAmountPerIngredient(testCase)
% Jess Haley, 2026-10-21 [dose per ingredient] (did-schema dose.json): the
% top-level quantities are the whole formulation; `value.ingredients` holds
% the amount of specific ingredients, one entry per repeated `ingredient_id`
% edge on the dose, same order (rule ingredients_match_edges). Each such
% ingredient must be one of the formulation's (rule ingredient_in_formulation,
% which needs the formulation, so did2.build.checkDoseIngredients checks it).
if ~composes() || ~doseHasIngredients()
    assumeFail(testCase, 'the loaded schema''s dose has no ingredient_id edge');
end
% the substances and the variable are the example's, not registry terms
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
sid = testCase.TestData.sid;
chemA = did2.build.document('chemical', struct('value', struct('substance', ...
    did2.build.term('NCIT:C227', 'alprazolam'))), 'SessionId', sid);
chemB = did2.build.document('chemical', struct('value', struct('substance', ...
    did2.build.term('EFO:0002677', 'saline'))), 'SessionId', sid);
form = did2.build.document('formulation', struct('value', struct('ingredients', ...
    {{struct('concentration', struct('source_value', NaN)), ...
      struct('concentration', struct('source_value', NaN))}})), ...
    'SessionId', sid, 'Edges', struct('ingredient_id', ...
    {{chemA.base.id, chemB.base.id}}));
perMass = struct('amount_per_body_mass', struct('grams_per_gram', 1e-6, ...
    'source_value', 1));
value = struct('volume', did2.build.valueCell('volume', NaN), ...
    'ingredients', perMass);
doc = did2.build.statement('manipulation', newId(), 'treatment', value, ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid, ...
    'Edges', struct('formulation_id', form.base.id, 'ingredient_id', {{chemA.base.id}}), 'ValueKind', 'dose');
blk = blockWith(doc, 'value');
verifyEqual(testCase, doc.(blk).value.ingredients(1).amount_per_body_mass.grams_per_gram, 1e-6);
verifyTrue(testCase, isnan(doc.(blk).value.volume.liters));
verifyEqual(testCase, sum(strcmp({doc.depends_on.name}, 'ingredient_id')), 1);
did2.build.checkDoseIngredients(doc, form);                  % alprazolam is in it
% one entry, no edge (or two edges, one entry): refused
verifyError(testCase, @() did2.build.statement('manipulation', newId(), ...
    'treatment', value, 'TimeReferenceIds', {newId()}, 'SessionId', sid, ...
    'Edges', struct('formulation_id', form.base.id), 'ValueKind', 'dose'), 'did2:build:ruleViolated');
verifyError(testCase, @() did2.build.statement('manipulation', newId(), ...
    'treatment', value, 'TimeReferenceIds', {newId()}, 'SessionId', sid, ...
    'Edges', struct('formulation_id', form.base.id, 'ingredient_id', ...
    {{chemA.base.id, chemB.base.id}}), 'ValueKind', 'dose'), 'did2:build:ruleViolated');
% an ingredient that is not the formulation's: refused by the cross-document check
other = did2.build.statement('manipulation', newId(), 'treatment', value, ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid, ...
    'Edges', struct('formulation_id', form.base.id, 'ingredient_id', {{newId()}}), 'ValueKind', 'dose');
verifyError(testCase, @() did2.build.checkDoseIngredients(other, form), ...
    'did2:build:ruleViolated');
end

function tf = doseHasIngredients()
c = did2.schema.cache.shared();
tf = false;
if ~c.hasClass('dose')
    return;
end
s = c.getClass('dose');
d = s.depends_on;
if iscell(d)
    names = cellfun(@(x) char(x.name), d, 'UniformOutput', false);
else
    names = {d.name};
end
tf = any(strcmp(names, 'ingredient_id'));
end

function testTheValidatorRefusesAValueThatIsNowhere(testCase)
% did2.schema.cache.validateDocument enforces the same rule as the builder
% (switch ValueInlineOrBody, armed by default): a value document with no
% inline value, data_body not true and no value_id edge is refused with
% did2:validation:valueNowhere. Built valid (in bodies), then flipped.
if ~valueRuleDeclared()
    assumeFail(testCase, 'the loaded schema''s `value` does not declare `value_inline_or_body`');
end
cache = did2.schema.cache.shared();
sid = testCase.TestData.sid;
common = {'TimeReferenceIds', {newId()}, 'SessionId', sid};
doc = did2.build.statement('observation', newId(), 'voltage', [], ...
    'DataBody', true, 'DatumType', did2.build.datumType('int16'), common{:}, 'ValueKind', 'voltage');
cache.validateDocument(doc);                       % in bodies: valid
blk = blockWith(doc, 'data_body');
bad = doc;
bad.(blk).data_body = false;
verifyError(testCase, @() cache.validateDocument(bad), 'did2:validation:valueNowhere');
% switched off, the same document validates
prev = did2.schema.cache.strictMode('ValueInlineOrBody', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('ValueInlineOrBody', prev));
cache.validateDocument(bad);
did2.schema.cache.strictMode('ValueInlineOrBody', true);
% a shared value document named through value_id: valid
shared = did2.build.statement('observation', newId(), 'voltage', [], ...
    'ValueId', newId(), common{:}, 'ValueKind', 'voltage');
cache.validateDocument(shared);
end

function b = blockWith(doc, fieldName)
b = '';
names = setdiff(fieldnames(doc), {'document_class', 'depends_on', 'files', 'file'}, 'stable');
for k = 1:numel(names)
    if isstruct(doc.(names{k})) && isscalar(doc.(names{k})) && isfield(doc.(names{k}), fieldName)
        b = names{k};
        return;
    end
end
error('testBuild:noBlock', 'no block holds `%s`', fieldName);
end

function tf = valueRuleDeclared()
tf = false;
c = did2.schema.cache.shared().getClass('value');
if ~isfield(c, 'rules') || isempty(c.rules)
    return;
end
r = c.rules;
if iscell(r)
    names = cellfun(@(x) char(x.name), r, 'UniformOutput', false);
else
    names = {r.name};
end
tf = any(strcmp(names, 'value_inline_or_body'));
end

% ===================== method (did-schema #88, 2026-10-21) ====================

function testStatementWritesOneMethodBlock(testCase)
% DID-schema V_eta_method_plan.md: an interaction's technique and its settings
% are ONE block, `method: {term, parameters}`; `method_parameters` is gone
if ~methodIsABlock()
    return;   % a schema before #88: `method` is a bare term
end
doc = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), ...
    'Method', 'whole-cell patch clamp', ...
    'MethodParameters', did2.build.list(did2.build.parameter('gain', 'Value', 100), ...
        did2.build.parameter('filter', 'Term', 'bessel')), ...
    'TimeReferenceIds', {newId()}, 'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage');
verifyEqual(testCase, doc.interaction.method.term.name, 'whole-cell patch clamp');
verifyEqual(testCase, numel(doc.interaction.method.parameters), 2);
verifyEqual(testCase, doc.interaction.method.parameters(1).quantity.value, 100);
verifyFalse(testCase, isfield(doc.interaction, 'method_parameters'));
% a term alone, and settings alone, are each a block
t = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'Method', 'refrigeration', ...
    'TimeReferenceIds', {newId()}, 'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage');
verifyEqual(testCase, fieldnames(t.interaction.method), {'term'});
end

function testMethodDocument(testCase)
% the standalone `method` document: the same block, with an id of its own
if ~methodIsABlock()
    return;
end
sid = testCase.TestData.sid;
m = did2.build.method('drifting sinusoidal grating', did2.build.list( ...
        did2.build.parameter('orientation', 'Value', 90, 'Unit', 'degree'), ...
        did2.build.parameter('contrast', 'Value', 1)), ...
    'Name', 'default', 'SoftwareId', newId(), 'SessionId', sid);
verifyEqual(testCase, m.document_class.class_name, 'method');
verifyEqual(testCase, m.method.name, 'default');
verifyEqual(testCase, m.method.term.name, 'drifting sinusoidal grating');
verifyEqual(testCase, numel(m.method.parameters), 2);
verifyTrue(testCase, any(strcmp({m.depends_on.name}, 'software_id')));
% a blank: a term, no settings
b = did2.build.method('blank screen', [], 'SessionId', sid);
verifyFalse(testCase, isfield(b.method, 'parameters'));
% lineage points at another method
c = did2.build.method([], did2.build.parameter('contrast', 'Value', 0.5), ...
    'ParentId', m.base.id, 'SessionId', sid);
verifyEqual(testCase, c.depends_on(strcmp({c.depends_on.name}, 'parent_id')).document_id, m.base.id);
% the same knob twice
verifyError(testCase, @() did2.build.method('x', did2.build.list( ...
    did2.build.parameter('gain', 'Value', 1), did2.build.parameter('gain', 'Value', 2)), ...
    'SessionId', sid), 'did2:build:ruleViolated');
% a statement points at it by `method_id`
obs = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'MethodId', m.base.id, ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid, 'ValueKind', 'voltage');
verifyEqual(testCase, obs.depends_on(strcmp({obs.depends_on.name}, 'method_id')).document_id, m.base.id);
verifyFalse(testCase, isfield(obs.interaction, 'method'));
% the option's old name writes the same edge
old = did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'MethodParametersId', m.base.id, ...
    'TimeReferenceIds', {newId()}, 'SessionId', sid, 'ValueKind', 'voltage');
verifyTrue(testCase, any(strcmp({old.depends_on.name}, 'method_id')));
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01), 'MethodId', m.base.id, ...
    'MethodParametersId', m.base.id, 'TimeReferenceIds', {newId()}, 'SessionId', sid, 'ValueKind', 'voltage'), ...
    'did2:build:badOption');
end

function testInlineMethodOrMethodIdNeverBoth(testCase)
% "A statement carries the inline `method` block OR this edge, NEVER BOTH"
% (team 2026-08-09) -- on #88 the inline term alone counts. did-schema's rule
% method_shared_and_own (Jess Haley 2026-10-22 [method shared plus own])
% replaces it: beside `method_id` an inline block may ADD settings, with an
% empty term. An inline TERM beside method_id is refused either way.
if ~methodIsABlock()
    return;
end
common = {'TimeReferenceIds', {newId()}, 'SessionId', testCase.TestData.sid};
v = did2.build.valueCell('voltage', 0.01);
verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
    v, 'Method', 'refrigeration', 'MethodId', newId(), common{:}, 'ValueKind', 'voltage'), 'did2:build:ruleViolated');
if schemaDeclaresRule('interaction', 'method_shared_and_own')
    doc = did2.build.statement('observation', newId(), 'voltage', ...
        v, 'MethodParameters', did2.build.parameter('gain', 'Value', 1), ...
        'MethodId', newId(), common{:}, 'ValueKind', 'voltage');
    verifyEqual(testCase, doc.interaction.method.parameters.variable.name, 'gain');
    verifyTrue(testCase, any(strcmp({doc.depends_on.name}, 'method_id')));
else
    verifyError(testCase, @() did2.build.statement('observation', newId(), 'voltage', ...
        v, 'MethodParameters', did2.build.parameter('gain', 'Value', 1), ...
        'MethodId', newId(), common{:}, 'ValueKind', 'voltage'), 'did2:build:ruleViolated');
end
end

function tf = schemaDeclaresRule(className, ruleName)
% true when the loaded schema's CLASSNAME declares RULENAME in its `rules`
c = did2.schema.cache.shared();
tf = false;
if ~c.hasClass(className)
    return;
end
s = c.getClass(className);
if ~isfield(s, 'rules') || isempty(s.rules)
    return;
end
r = s.rules;
if isstruct(r); r = num2cell(r); end
tf = any(cellfun(@(x) strcmp(char(x.name), ruleName), r));
end

function testRelationMethodIsTheSameBlock(testCase)
if ~methodIsABlock()
    return;
end
rel = did2.build.directedRelation(newId(), newId(), did2.build.term('', 'part_of'), ...
    'Method', 'image registration', ...
    'MethodParameters', did2.build.parameter('threshold', 'Value', 0.5), ...
    'SessionId', testCase.TestData.sid);
verifyEqual(testCase, rel.relation.method.term.name, 'image registration');
verifyEqual(testCase, rel.relation.method.parameters.quantity.value, 0.5);
u = did2.build.undirectedRelation({newId(), newId()}, did2.build.term('', 'same_as'), ...
    'Method', 'manual curation', 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, u.relation.method.term.name, 'manual curation');
end

function tf = methodIsABlock()
% did-schema #88: the standalone class is `method` and carries `parameters`
c = did2.schema.cache.shared();
tf = false;
if c.hasClass('method')
    own = c.ownFields('method');
    tf = any(cellfun(@(d) strcmp(char(d.name), 'parameters'), own));
end
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
% A: an OLD-VINTAGE caller's joined name, which the builder still reads as the
% direction + kind (resolveLeaf); nothing in src writes it (testNoOldLeafNames).
a = did2.build.statement('temperature_observation', newId(), 'ambient temperature', v, ... % OLD-VINTAGE-INPUT
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
doc = did2.build.statement('observation', newId(), 'ambient temperature', ...
    did2.build.valueCell('temperature', 21.6), 'TimeReferenceIds', {newId()}, ...
    'SessionId', sid, 'ValueKind', 'temperature');
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
% a read path that re-stamps the chain (ensureClassBlocks) keeps the kind
again = did2.convert.ensureClassBlocks(doc, []);
verifyEqual(testCase, {again.document_class.superclasses.class_name}, ...
    {doc.document_class.superclasses.class_name});
verifyTrue(testCase, isfield(again, 'temperature'));
% a named calculator carries its kind in its own chain, so it takes none
verifyEqual(testCase, c.documentAncestors('tuning_curve_calculation', ''), ...
    c.superclasses('tuning_curve_calculation'));
end

% ===================== bodies ==============================================

function testSampledBody(testCase)
sid = testCase.TestData.sid;
dims = did2.build.list(did2.build.dimension('time', 100, 'Chunk', 50), ...
    did2.build.dimension('channel', 2));
covs = did2.build.list( ...
    did2.build.covariate('time', 0, 'Unit', 'second', 'Origin', 0, 'Spacing', 0.01), ...
    did2.build.covariate('channel', 1, 'Term', {'A1', 'A2'}));
body = did2.build.sampledBody(newId(), dims, 'Covariates', covs, 'DatumOrder', 'F', ...
    'ByteOrder', 'little', 'Chunks', 2, 'SessionId', sid);
% the dimensions may also be given by name
same = did2.build.sampledBody(newId(), 'Dimensions', dims, 'Covariates', covs, ...
    'DatumOrder', 'F', 'ByteOrder', 'little', 'Chunks', 2, 'SessionId', sid);
verifyEqual(testCase, same.data, body.data);
verifyError(testCase, @() did2.build.sampledBody(newId(), dims, 'Dimensions', dims, ...
    'DatumOrder', 'F', 'SessionId', sid), 'did2:build:ambiguousField');
verifyEqual(testCase, body.document_class.class_name, 'sampled_body');
verifyEqual(testCase, body.files.file_list, {'body_data_0', 'body_data_1'});
% `datum_order` sits on the block the schema declares it on: `data`, beside
% `dimensions` (`keys` before AMENDMENT 6), since did-schema #88 (D-5);
% `sampled_body` before. The other block
% does not carry it. Both shapes: testBuildDatumOrder.
where = did2.schema.cache.shared().datumOrderBlock();
verifyNotEmpty(testCase, where, 'the loaded schema declares datum_order nowhere');
verifyEqual(testCase, body.(where).datum_order, 'F');
other = setdiff({'data', 'sampled_body'}, {where});
verifyFalse(testCase, isfield(body.(other{1}), 'datum_order'), ...
    sprintf('datum_order is declared on `%s`, so `%s` must not carry it', where, other{1}));
verifyEqual(testCase, numel(body.data.dimensions), 2);
verifyEqual(testCase, numel(body.data.covariates), 2);
verifyEqual(testCase, [body.data.covariates.along], [0 1]);
verifyFalse(testCase, isfield(body.data, 'keys') || isfield(body.data, 'complete'));
end

function testSampledBodyChecks(testCase)
sid = testCase.TestData.sid;
twoKeys = did2.build.list(did2.build.dimension('time', 2), did2.build.dimension('channel', 1));
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
% `format` is an ontology term (lightsheet point 4, did-schema 877bbde): a bare
% CURIE is the node, and a known one gets its name.
body = did2.build.opaqueBody(newId(), 'EDAM:format_3591', 'HashAlgorithm', 'MD5', ...
    'ContentHash', 'd41d8cd98f00b204e9800998ecf8427e', 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, body.data_body.format.node, 'EDAM:format_3591');
verifyEqual(testCase, body.data_body.format.name, 'TIFF');
body = did2.build.opaqueBody(newId(), struct('node', 'EDAM:format_3508', 'name', 'PDF'), ...
    'SessionId', testCase.TestData.sid);
verifyEqual(testCase, body.data_body.format.node, 'EDAM:format_3508');
verifyEqual(testCase, body.data_body.format.name, 'PDF');
body = did2.build.opaqueBody(newId(), 'EDAM:format_9999', 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, body.data_body.format.node, 'EDAM:format_9999');
verifyTrue(testCase, ~isfield(body.data_body.format, 'name') || isempty(body.data_body.format.name), ...
    'an unknown CURIE keeps no name');
verifyEqual(testCase, body.files.file_list, {'body_data_0'});
verifyError(testCase, @() did2.build.opaqueBody(newId(), '', 'SessionId', testCase.TestData.sid), ...
    'did2:build:missingField');
% optional: the array as the format presents it (dimensions + covariates)
body = did2.build.opaqueBody(newId(), 'EDAM:format_3591', ...
    'Dimensions', did2.build.list(did2.build.dimension('y', 4), did2.build.dimension('x', 5)), ...
    'Covariates', did2.build.covariate('x', 1, 'Origin', 0, 'Spacing', 1), ...
    'DatumOrder', 'C', 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, numel(body.data.dimensions), 2);
verifyEqual(testCase, body.data.covariates.along, 1);
verifyError(testCase, @() did2.build.opaqueBody(newId(), 'EDAM:format_3591', ...
    'Dimensions', did2.build.dimension('y', 4, 'Chunk', 2), 'SessionId', testCase.TestData.sid), ...
    'did2:build:ruleViolated');
end

function testBodiesKeepAGivenIdAndMintOneOtherwise(testCase)
% Lightsheet point 11: a body can keep the id of the source document it
% migrates from ('Id', as did2.build.document's); '' mints a new one.
sid = testCase.TestData.sid;
keys = did2.build.dimension('time', 10);
id = newId();
body = did2.build.sampledBody(newId(), keys, 'SessionId', sid, 'Id', id);
verifyEqual(testCase, body.base.id, id);
body = did2.build.opaqueBody(newId(), 'EDAM:format_3591', 'SessionId', sid, 'Id', id);
verifyEqual(testCase, body.base.id, id);
a = did2.build.sampledBody(newId(), keys, 'SessionId', sid);
b = did2.build.opaqueBody(newId(), 'EDAM:format_3591', 'SessionId', sid);
verifyNotEmpty(testCase, a.base.id);
verifyNotEmpty(testCase, b.base.id);
verifyNotEqual(testCase, a.base.id, id);
verifyNotEqual(testCase, b.base.id, id);
end

% ===================== time references =====================================

function testRelativeTimeReference(testCase)
sid = testCase.TestData.sid;
ref = did2.build.relativeTimeReference(newId(), 'Clock', 'dev_local_time', ...
    'Start', 12.5, 'StartSourceValue', 12500, ...
    'StartSourceUnit', sourceUnit('om:millisecond-Time', 'millisecond', 'ms'), ...
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

function testCoordinateSystemDimensionsAreNotAmendment6s(testCase)
% coordinate_system has its own `dimensions` ({axis, positive_direction,
% spacing}); the AMENDMENT 6 checks read only the `data` and
% `acquisition_epoch` blocks (NDI #1021 V2 import stages, run 39739660924:
% 'Unrecognized field name "n"' from the Haley geometry import).
step = did2.build.valueCell('length', 1e-5);
cs = did2.build.document('coordinate_system', struct( ...
    'origin', did2.build.term('', 'image upper-left corner'), ...
    'dimensions', did2.build.list( ...
        struct('axis', did2.build.term('', 'x-axis'), ...
            'positive_direction', did2.build.term('', 'image right'), 'spacing', step))), ...
    'SessionId', testCase.TestData.sid, 'Edges', struct('referent_id', newId()));
verifyEqual(testCase, numel(cs.coordinate_system.dimensions), 1);
end

function testDirectedRelation(testCase)
child = newId(); parent = newId();
rel = did2.build.directedRelation(child, parent, did2.build.term('', 'part_of'), ...
    'Order', 2, 'SessionId', testCase.TestData.sid);
names = {rel.depends_on.name};
verifyEqual(testCase, rel.depends_on(strcmp(names, 'child_id')).document_id, child);
verifyEqual(testCase, rel.depends_on(strcmp(names, 'parent_id')).document_id, parent);
verifyEqual(testCase, rel.directed_relation.order, 2);
% did-schema T20 renamed `sequence` to `order`; only `order` is emitted
verifyFalse(testCase, isfield(rel.directed_relation, 'sequence'));
% prefixes match case-insensitively (CURIE_lookups_meta.json); the schema writes
% them lowercase since 2026-10-08, `BFO:` before
verifyEqual(testCase, lower(rel.directed_relation.relation.node), 'bfo:0000050', ...
    'part_of is completed from the bound relation value set');
end

function testRelationOrderCountsFromZeroAndMinusOneIsUnordered(testCase)
% Jess Haley, 2026-10-21 [author order from 0]: 0 is a real position, so an
% unordered relation writes -1 (did-schema: `order` blank/default -1, as
% `positions_from`), never 0.
child = newId(); parent = newId();
first = did2.build.directedRelation(child, parent, did2.build.term('', 'part_of'), ...
    'Order', 0, 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, first.directed_relation.order, 0);
none = did2.build.directedRelation(child, parent, did2.build.term('', 'part_of'), ...
    'SessionId', testCase.TestData.sid);
verifyEqual(testCase, none.directed_relation.order, -1);
verifyError(testCase, @() did2.build.directedRelation(child, parent, ...
    did2.build.term('', 'part_of'), 'Order', -1, 'SessionId', testCase.TestData.sid), ...
    'did2:build:badOption');
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
arguments
    localId {mustBeText}
end

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

function [cls, supers] = leafSpec(direction, kind)
% the class and superclasses a statement of DIRECTION with value kind KIND
% builds (did-schema #88): the direction, listing the kind's chain after its own
arguments
    direction {mustBeText}
    kind {mustBeText}
end

c = did2.schema.cache.shared();
cls = char(direction);
supers = c.documentAncestors(cls, char(kind));
end

function tf = composes()
% true on a schema whose statement directions take a value kind (2026-10-08)
c = did2.schema.cache.shared();
tf = c.hasClass('observation') && ~isempty(c.valueKindRule('observation'));
end

function sid = sessionIdWritten(doc)
% the session id a built document carries: base.session_id, or the session_id
% edge on a schema that declares one (did2.schema.cache/sessionIdIsEdge)
arguments
    doc (1,1) struct
end

sid = did2.schema.cache.sessionIdOf(doc);
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
