function tests = testSqliteDbNonFinite
% testSqliteDbNonFinite - NaN, Inf and -Inf survive a V2 write and read.
%
%   DECISION (Jess Haley, 2026-10-21, did-schema
%   V_eta_go_forward_class_audit.md): "An unrecorded amount is written as NaN
%   in its quantity (e.g. a dose's volume.liters: NaN), and V2 stores NaN the
%   way V1 does."
%
%   V1 writes document text with did.datastructures.jsonencodenan, which is
%   jsonencode(..., 'ConvertInfAndNaN', false): NaN, Inf and -Inf are written
%   as the literals NaN, Infinity and -Infinity, and jsondecode reads them
%   back. V2's did2.document/toJSON used plain jsonencode, which writes a
%   non-finite number as null; jsondecode reads a scalar null back as [], so
%   a NaN amount came out of the database as an ABSENT one, and Inf as NaN
%   inside an array. These tests were written before the encoder changed.
%
%   WHAT IS PINNED, in order:
%     1. the premise (plain jsonencode loses a scalar NaN; jsondecode reads
%        the V1 literals);
%     2. did2.document writes what V1 writes and reads it back, scalar and
%        matrix;
%     3. through did2.database.sqlitedb: the stored text carries the
%        literals, a read gives the numbers back, SQLite's JSON functions
%        (json_extract, json_type, json_each, json_tree -- the ones
%        compileQuery uses) accept the stored text without error, the
%        queryable_scalar_elem and queryable_array_elem sidecars hold what
%        json_extract gives, and every query answers as the in-memory
%        evaluator (did2.query.matches) does.
%
%   The schema is a hermetic copy of the V_delta fixtures plus one class,
%   demoNumeric, written by this file (a double scalar, a matrix, and an
%   array of structures with a double sub-field, all queryable).
%
%   Run with:
%       results = runtests('did2.unittest.testSqliteDbNonFinite');

tests = functiontests(localfunctions);
end

% ---- fixture ---------------------------------------------------------------

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
schemaDir = tempname();
mkdir(schemaDir);
copyfile(fullfile(fixtureDir, '*.json'), schemaDir);
writeDemoNumeric(fullfile(schemaDir, 'demoNumeric.json'));
did2.schema.cache.setSchemaPath(schemaDir);
testCase.TestData.schemaDir = schemaDir;
end

function teardownOnce(testCase)
did2.schema.cache.resetSingleton();
if isfolder(testCase.TestData.schemaDir)
    rmdir(testCase.TestData.schemaDir, 's');
end
end

function setup(testCase)
testCase.TestData.tmpFile = '';
testCase.TestData.db = [];
end

function teardown(testCase)
try
    testCase.TestData.db.close();
catch
end
if ~isempty(testCase.TestData.tmpFile) && isfile(testCase.TestData.tmpFile)
    delete(testCase.TestData.tmpFile);
end
end

function db = openDb(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, 'mksqlite is not on the MATLAB path; skipping the SQLite half.');
end
testCase.TestData.tmpFile = [tempname() '.sqlite'];
db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
end

% ===================== 1. the premise =======================================

function testPlainJsonencodeLosesAScalarNaN(testCase)
% THE DEFECT IN ONE LINE: why V2 could not store an unrecorded amount.
s = jsondecode(jsonencode(struct('liters', NaN)));
verifyEmpty(testCase, s.liters, ...
    ['jsondecode(jsonencode(NaN)) now gives a value back. MATLAB changed; ' ...
     'the ConvertInfAndNaN option in did2.document may no longer be needed.']);
end

function testJsondecodeReadsTheV1Literals(testCase)
s = jsondecode('{"a":NaN,"b":Infinity,"c":-Infinity,"d":[1,NaN,Infinity,-Infinity]}');
verifyTrue(testCase, isnan(s.a));
verifyEqual(testCase, s.b, Inf);
verifyEqual(testCase, s.c, -Inf);
verifyTrue(testCase, isequaln(s.d(:)', [1 NaN Inf -Inf]));
end

% ===================== 2. did2.document =====================================

function testToJSONWritesWhatV1Writes(testCase)
props = nonFiniteProps();
doc = did2.document(props);
txt = doc.toJSON();
verifyEqual(testCase, txt, jsonencode(props, 'ConvertInfAndNaN', false), ...
    'V2 must write a non-finite number exactly as jsonencode(..., ''ConvertInfAndNaN'', false)');
v1 = jsondecode(did.datastructures.jsonencodenan(props));
verifyTrue(testCase, isequaln(jsondecode(txt), v1), ...
    'V2 text and V1 text must decode to the same values');
verifyNotEmpty(testCase, strfind(txt, 'NaN'));
verifyNotEmpty(testCase, strfind(txt, 'Infinity'));
end

function testDocumentRoundTripKeepsNonFinite(testCase)
doc = did2.document(nonFiniteProps());
back = did2.document.fromJSON(doc.toJSON());
verifyTrue(testCase, isnan(back.get('demoNumeric.amount')), ...
    'a scalar NaN must read back as NaN, not []');
verifyEqual(testCase, back.get('demoNumeric.upper'), Inf);
verifyEqual(testCase, back.get('demoNumeric.lower'), -Inf);
end

function testMatrixWritesTheLiterals(testCase)
% A `matrix` field is written by did2.document's own array writer (data_body
% AMENDMENT 4), not by jsonencode; it must spell the literals as jsonencode
% does and read back at its shape with Inf kept (null would read back NaN).
m = [1 NaN; Inf -Inf];
doc = makeNumeric('m', 5, m, []);
txt = doc.toJSON();
lits = jsonencode([NaN Inf -Inf], 'ConvertInfAndNaN', false);
verifyEqual(testCase, lits, '[NaN,Infinity,-Infinity]', ...
    'the spellings this file and did2.document assume');
verifyNotEmpty(testCase, strfind(txt, '[[1,NaN],[Infinity,-Infinity]]'), txt);
back = did2.document.fromJSON(txt);
verifyTrue(testCase, isequaln(back.get('demoNumeric.samples'), m), ...
    'a matrix with NaN/Inf/-Inf must read back at its shape with every value');
end

% ===================== 3. did2.database.sqlitedb ============================

function testStoredTextCarriesTheLiterals(testCase)
db = openDb(testCase);
doc = makeNumeric('n', NaN, [1 NaN Inf], readings([NaN 2]));
db.add(doc);
row = mksqlite(db.testHookDbId(), 'SELECT body FROM documents WHERE id = ?', ...
    doc.get('base.id'));
body = char(row.body);
verifyNotEmpty(testCase, strfind(body, '"amount":NaN'), body);
verifyNotEmpty(testCase, strfind(body, 'Infinity'), body);
end

function testReadBackKeepsNonFinite(testCase)
db = openDb(testCase);
docs = {makeNumeric('nan', NaN, [], []), makeNumeric('inf', Inf, [], []), ...
    makeNumeric('ninf', -Inf, [], []), makeNumeric('five', 5, [], [])};
db.add(docs);
want = [NaN Inf -Inf 5];
for k = 1:numel(docs)
    got = db.get(docs{k}.get('base.id')).get('demoNumeric.amount');
    verifyTrue(testCase, isequaln(got, want(k)), sprintf( ...
        '%s read back as %s', docs{k}.get('base.name'), mat2str(got)));
end
% and the read-back document still validates (an [] amount would too, which
% is why the value is checked above and not only this)
for k = 1:numel(docs)
    db.get(docs{k}.get('base.id')).validate();
end
end

function testSqliteJsonFunctionsAcceptTheLiterals(testCase)
% compileQuery reaches the body through json_extract / json_type / json_each
% / json_tree. SQLite reads NaN and Infinity as JSON5 (3.42+): NaN is JSON
% null, Infinity a real. A build that rejected them would error here.
db = openDb(testCase);
doc = makeNumeric('n', NaN, [1 NaN Inf], readings([NaN Inf]));
db.add(doc);
dbid = db.testHookDbId();
v = mksqlite(dbid, 'SELECT sqlite_version() AS v');
fprintf('SQLite under mksqlite: %s\n', char(v.v));
r = mksqlite(dbid, ['SELECT json_type(body, ''$.demoNumeric.amount'') AS t, ' ...
    'json_extract(body, ''$.demoNumeric.amount'') IS NULL AS nan_is_null, ' ...
    'json_extract(body, ''$.demoNumeric.samples[0][2]'') AS inf ' ...
    'FROM documents']);
verifyEqual(testCase, char(r.t), 'null', 'NaN reads as JSON null');
verifyEqual(testCase, double(r.nan_is_null), 1);
verifyEqual(testCase, double(r.inf), Inf, 'Infinity reads as a real infinity');
e = mksqlite(dbid, ['SELECT COUNT(*) AS n FROM documents, ' ...
    'json_each(json_extract(documents.body, ''$.demoNumeric.readings''))']);
verifyEqual(testCase, double(e.n), 2);
t = mksqlite(dbid, 'SELECT COUNT(*) AS n FROM documents, json_tree(documents.body)');
verifyGreaterThan(testCase, double(t.n), 0);
end

function testSidecarsHoldWhatJsonExtractGives(testCase)
% queryable_scalar_elem mirrors json_extract(body, path): no row for NaN
% (JSON null), a real infinity for Infinity.
db = openDb(testCase);
a = makeNumeric('nan', NaN, [], readings([NaN 1]));
b = makeNumeric('inf', Inf, [], readings(Inf));
db.add({a, b});
dbid = db.testHookDbId();
q = @(id) mksqlite(dbid, ['SELECT value_num FROM queryable_scalar_elem ' ...
    'WHERE doc_id = ? AND path = ''demoNumeric.amount'''], id);
verifyEmpty(testCase, q(a.get('base.id')), 'a NaN amount has no scalar row');
rb = q(b.get('base.id'));
verifyEqual(testCase, numel(rb), 1);
verifyEqual(testCase, double(rb.value_num), Inf);
arr = mksqlite(dbid, ['SELECT COUNT(*) AS n FROM queryable_array_elem ' ...
    'WHERE path = ''demoNumeric.readings[*].value''']);
verifyGreaterThan(testCase, double(arr.n), 0, ...
    'the array sidecar was filled (a write that errored would leave none)');
end

function testQueriesAgreeWithTheInMemoryEvaluator(testCase)
db = openDb(testCase);
docs = {makeNumeric('nan', NaN, [], readings([NaN 1])), ...
    makeNumeric('inf', Inf, [], readings(Inf)), ...
    makeNumeric('ninf', -Inf, [], readings(-Inf)), ...
    makeNumeric('five', 5, [], readings(5))};
db.add(docs);
queries = {
    did2.query('demoNumeric.amount', 'exact_number', 5)
    did2.query('demoNumeric.amount', '~exact_number', 5)
    did2.query('demoNumeric.amount', 'exact_number', NaN)
    did2.query('demoNumeric.amount', 'greaterthan', 1e300)
    did2.query('demoNumeric.amount', 'lessthan', -1e300)
    did2.query('demoNumeric.amount', 'greaterthaneq', 0)
    did2.query('demoNumeric.amount', 'lessthaneq', 5)
    did2.query('demoNumeric.amount', 'hasfield', '')
    did2.query('demoNumeric.readings[*].value', 'exact_number', 1)
    did2.query('demoNumeric.readings[*].value', 'greaterthan', 1e300)
    did2.query('demoNumeric.readings[*].value', 'lessthan', 0)
    };
for k = 1:numel(queries)
    q = queries{k};
    hits = db.search(q);
    got = sort(cellfun(@(d) d.get('base.name'), hits, 'UniformOutput', false));
    want = {};
    for j = 1:numel(docs)
        if q.matches(docs{j})
            want{end+1} = docs{j}.get('base.name'); %#ok<AGROW>
        end
    end
    verifyEqual(testCase, got, sort(want), sprintf( ...
        'query %d (%s): the database and the in-memory evaluator disagree', ...
        k, describe(q)));
end
end

% ---- helpers ---------------------------------------------------------------

function props = nonFiniteProps()
props = struct('document_class', struct('class_name', 'unknownToAnySchema'), ...
    'demoNumeric', struct('amount', NaN, 'upper', Inf, 'lower', -Inf));
end

function doc = makeNumeric(name, amount, samples, readingsValue)
doc = did2.document.blank('demoNumeric');
doc = doc.set('base.session_id', 'session-nonfinite');
doc = doc.set('base.name', name);
doc = doc.set('demoNumeric.amount', amount);
doc = doc.set('demoNumeric.samples', samples);
if isempty(readingsValue)
    readingsValue = struct('value', {});
end
doc = doc.set('demoNumeric.readings', readingsValue);
end

function r = readings(values)
r = struct('value', num2cell(values));
end

function s = describe(q)
try
    s = jsonencode(q.toStruct(), 'ConvertInfAndNaN', false);
catch
    s = class(q);
end
end

function writeDemoNumeric(path)
f = @(name, type, queryable, doc) struct('name', name, 'type', type, ...
    'blank_value', [], 'default_value', [], 'mustBeNonEmpty', false, ...
    'mustBeScalar', false, 'mustNotHaveNaN', false, 'queryable', queryable, ...
    'ontology', [], 'documentation', doc, 'constraints', struct());
amount = f('amount', 'double', true, 'A quantity; NaN when unrecorded.');
amount.mustBeScalar = true;
samples = f('samples', 'matrix', false, 'A matrix written by did2.document''s array writer.');
value = f('value', 'double', true, 'A reading.');
value.mustBeScalar = true;
readingsField = f('readings', 'structure', true, 'An array of readings.');
readingsField.fields = {value};
s = struct();
s.document_class = struct('class_name', 'demoNumeric', 'class_version', '1.0.0', ...
    'superclasses', {{struct('class_name', 'base')}}, 'maturity_level', 'stable');
s.depends_on = {};
s.file = {};
s.fields = {amount, samples, readingsField};
fid = fopen(path, 'w');
fwrite(fid, jsonencode(s, 'PrettyPrint', true), 'char');
fclose(fid);
end
