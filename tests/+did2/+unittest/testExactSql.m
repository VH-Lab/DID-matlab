function tests = testExactSql
% testExactSql - which queries skip the in-memory recheck, and that skipping it changes nothing.
%
%   did2.database.compileQuery reports a query EXACT when every term
%   compiles to SQL that matches a stored document exactly when the
%   in-memory evaluator (did2.query) does; did2.database.sqlitedb then skips
%   the recheck. For every operator counted exact, and for the ones that are
%   not, these tests check:
%     1. the exactness compileQuery reports (testHookIsExact);
%     2. the search WITHOUT the recheck returns exactly what the search
%        WITH it returns (testHookAlwaysRecheck), and what the evaluator
%        matches over the same documents.
%   The documents include the shapes an exact term must not be fooled by:
%   a missing field, an empty value, a value differing only in case, a
%   subclass, an edge by `document_id` and by the v1 `value` spelling, two
%   edges of one name, and a did_v1 document stored without validation that
%   holds a NUMBER in a text path (always rechecked).
%
%   Filtered out if mksqlite is not on the MATLAB path.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, 'mksqlite is not on the MATLAB path; skipping the v2 SQLite tests.');
end
thisDir = fileparts(mfilename('fullpath'));
did2.schema.cache.setSchemaPath(fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal'));
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

function setup(testCase)
testCase.TestData.tmpFile = [tempname() '.sqlite'];
db = did2.database.sqlitedb(testCase.TestData.tmpFile);
testCase.TestData.db = db;
a1 = demoA('a1', 'sessA', 'alpha');
a2 = demoA('a2', 'sessA', 'Alpha');
a3 = demoA('a3', 'sessB', '');
a4 = did2.document.blank('demoA');            % no value set
a4 = a4.set('base.session_id', 'sessB');
a4 = a4.set('base.name', 'a4');
b1 = did2.document.blank('demoB');
b1 = b1.set('base.session_id', 'sessA');
b1 = b1.set('base.name', 'b1');
b1 = b1.set('demoA.value', 'alpha');
b1 = b1.set('demoB.value_b', 'beta');
c1 = demoC('c1', 'sessA', {'item1', a1.get('base.id'); 'item2', a2.get('base.id')});
c2 = demoC('c2', 'sessA', {'item1', a2.get('base.id'); 'item2', a1.get('base.id'); ...
    'item3', a3.get('base.id')});
c3 = demoC('c3', 'sessB', {'item1', a3.get('base.id'); 'item2', a3.get('base.id')});
docs = {a1, a2, a3, a4, b1, c1, c2, c3};
db.add(docs(1:5));
db.add(docs(6:8), 'Validate', false);   % edges set directly, as testSqliteDb does
% a did_v1 document, stored without validation, with a NUMBER where the
% schema declares text, and its edge in the v1 `value` spelling
v1 = struct('document_class', struct('class_name', 'demoC', 'class_version', '1.0.0', ...
    'schema_version', 'did_v1', 'superclasses', struct('class_name', 'base')), ...
    'base', struct('id', 'v1doc_0000000000000001', 'session_id', 'sessA', 'name', 'v1', ...
        'datestamp', '2026-11-06T00:00:00.000Z', 'creation_timestamp', '2026-11-06T00:00:00.000Z'), ...
    'demoC', struct('value', 5), ...
    'depends_on', struct('name', {'item1', 'item2'}, 'value', {a1.get('base.id'), a3.get('base.id')}));
v1doc = did2.document(v1);
db.add({v1doc}, 'Validate', false);
testCase.TestData.docs = [docs, {v1doc}];
testCase.TestData.ids = struct('a1', a1.get('base.id'), 'a2', a2.get('base.id'), ...
    'a3', a3.get('base.id'));
end

function teardown(testCase)
try
    testCase.TestData.db.close();
catch
end
if isfile(testCase.TestData.tmpFile)
    delete(testCase.TestData.tmpFile);
end
end

% ---- helpers ----

function doc = demoA(name, sess, value)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sess);
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', value);
end

function doc = demoC(name, sess, edges)
doc = did2.document.blank('demoC');
doc = doc.set('base.session_id', sess);
doc = doc.set('base.name', name);
doc = doc.set('demoC.value', name);
doc = doc.set('depends_on', struct('name', edges(:, 1)', 'document_id', edges(:, 2)'));
end

function names = check(testCase, q, expectExact)
% exactness as expected; the search with and without the recheck agree with
% each other and with the evaluator
db = testCase.TestData.db;
verifyEqual(testCase, db.testHookIsExact(q), expectExact, 'exactness');
db.testHookAlwaysRecheck(false);
fast = namesOf(db.search(q));
db.testHookAlwaysRecheck(true);
checked = namesOf(db.search(q));
db.testHookAlwaysRecheck(false);
expected = {};
for k = 1:numel(testCase.TestData.docs)
    d = testCase.TestData.docs{k};
    if q.matches(d)
        expected{end+1} = d.get('base.name'); %#ok<AGROW>
    end
end
verifyEqual(testCase, fast, checked, 'skipping the recheck changed the answer');
verifyEqual(testCase, checked, sort(expected), 'the database and the evaluator disagree');
names = fast;
end

function n = namesOf(docs)
n = sort(cellfun(@(d) char(d.get('base.name')), docs, 'UniformOutput', false));
if isempty(n); n = {}; end
end

% ---- exact operators ----

function testIsaIsExact(testCase)
verifyEqual(testCase, check(testCase, did2.query('', 'isa', 'demoA'), true), ...
    sort({'a1', 'a2', 'a3', 'a4', 'b1'}));
verifyEqual(testCase, check(testCase, did2.query('', 'isa', 'demoB'), true), {'b1'});
check(testCase, did2.query('', '~isa', 'demoA'), true);
check(testCase, did2.query('', 'isa', 'nosuchclass'), true);
end

function testNamedDependsOnIsExact(testCase)
ids = testCase.TestData.ids;
verifyEqual(testCase, check(testCase, did2.query('', 'depends_on', 'item1', ids.a1), true), ...
    sort({'c1', 'v1'}));
check(testCase, did2.query('', 'depends_on', 'item2', {ids.a1, ids.a3}), true);
check(testCase, did2.query('', 'depends_on', 'item3', ids.a3), true);
check(testCase, did2.query('', '~depends_on', 'item1', ids.a1), true);
check(testCase, did2.query('', 'depends_on', '*', ids.a3), true);
end

function testExactStringOnAQueryableTextPathIsExact(testCase)
verifyEqual(testCase, check(testCase, did2.query('demoA.value', 'exact_string', 'alpha'), true), ...
    sort({'a1', 'b1'}));
check(testCase, did2.query('demoA.value', '~exact_string', 'alpha'), true);
check(testCase, did2.query('base.name', 'exact_string', 'c2'), true);
check(testCase, did2.query('demoB.value_b', 'exact_string', 'beta'), true);
end

function testTheV1NumberInATextPathIsStillRechecked(testCase)
% demoC.value is a queryable TEXT path; the v1 document holds the number 5
% there, which the sidecar keeps as the text '5'. The query is exact, and
% the v1 document is rechecked all the same, so it is not returned.
names = check(testCase, did2.query('demoC.value', 'exact_string', '5'), true);
verifyEmpty(testCase, names);
end

function testSessionScopeIsExact(testCase)
check(testCase, did2.query('base.session_id', 'exact_string', 'sessA'), true);
check(testCase, did2.query('base.session_id', 'exact_string', 'sessA') & ...
    did2.query('', 'isa', 'demoA'), true);
end

function testAndOrOfExactTermsIsExact(testCase)
ids = testCase.TestData.ids;
q = (did2.query('', 'isa', 'demoC') & did2.query('', 'depends_on', 'item1', ids.a2)) | ...
    did2.query('demoA.value', 'exact_string', 'Alpha');
verifyEqual(testCase, check(testCase, q, true), sort({'a2', 'c2'}));
end

% ---- inexact: the recheck stays ----

function testInexactOperatorsKeepTheRecheck(testCase)
check(testCase, did2.query('demoA.value', 'contains_string', 'lph'), false);
check(testCase, did2.query('demoA.value', 'exact_string_anycase', 'ALPHA'), false);
check(testCase, did2.query('demoA.value', 'regexp', '^a'), false);
% exact_string '' is not exact. (Its search also drops the documents whose
% value is empty, a3 and a4, which the evaluator matches: the sidecar keeps
% no row for an empty value. That is older than this change and is not
% about the recheck, so only the exactness is checked here.)
verifyFalse(testCase, testCase.TestData.db.testHookIsExact( ...
    did2.query('demoA.value', 'exact_string', '')));
check(testCase, did2.query('demoA.value', 'hasfield'), false);
check(testCase, did2.query('demoA.tags', 'hasmember', 'x'), false);
check(testCase, did2.query('', 'depends_on', 'item1', ''), false);
end

function testOneInexactTermMakesTheWholeQueryInexact(testCase)
q = did2.query('', 'isa', 'demoA') & did2.query('demoA.value', 'contains_string', 'Al');
verifyEqual(testCase, check(testCase, q, false), {'a2'});
q = did2.query('', 'isa', 'demoA') | did2.query('demoA.value', 'regexp', 'x');
check(testCase, q, false);
end

% ---- searchEdges: the same edges search's documents carry ----

function testSearchEdgesMatchesTheDocumentsOfSearch(testCase)
ids = testCase.TestData.ids;
queries = {did2.query('', 'isa', 'demoC'), ...                              % exact
    did2.query('', 'depends_on', 'item2', {ids.a1, ids.a3}), ...              % exact, v1 doc among them
    did2.query('demoC.value', 'contains_string', 'c'), ...                    % inexact
    did2.query('demoC.value', 'exact_string', '5')};                          % exact; v1 doc rechecked out
for k = 1:numel(queries)
    edgesMatchSearch(testCase, queries{k}, {'item1', 'item3'});
end
end

function edgesMatchSearch(testCase, q, names)
db = testCase.TestData.db;
got = db.searchEdges(q, names);
want = struct('doc_id', {}, 'name', {}, 'document_id', {});
db.testHookAlwaysRecheck(true);
docs = db.search(q);
db.testHookAlwaysRecheck(false);
for k = 1:numel(docs)
    s = docs{k}.toStruct();
    if ~isfield(s, 'depends_on'); continue; end
    d = s.depends_on;
    for j = 1:numel(d)
        e = d(j);
        if isfield(e, 'document_id'); v = e.document_id; else; v = e.value; end
        if any(strcmp(e.name, names)) && ~isempty(v)
            want(end+1) = struct('doc_id', char(s.base.id), 'name', char(e.name), ...
                'document_id', char(v)); %#ok<AGROW>
        end
    end
end
verifyEqual(testCase, {got.doc_id}, {want.doc_id}, 'searchEdges: documents or their order');
verifyEqual(testCase, {got.name}, {want.name}, 'searchEdges: edge names');
verifyEqual(testCase, {got.document_id}, {want.document_id}, 'searchEdges: targets');
end
