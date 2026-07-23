function tests = testValidateReferences
%TESTVALIDATEREFERENCES Unit tests for did2.validate.references.
%
%   Exercises the depends_on referential-integrity checker.
%
%   Run with:
%       results = runtests('did2.unittest.testValidateReferences');

tests = functiontests(localfunctions);
end

% ---- fixture setup / teardown ----

function setupOnce(testCase)
thisDir = fileparts(mfilename('fullpath'));
fixtureDir = fullfile(fileparts(thisDir), 'fixtures', 'V_delta');
did2.schema.cache.setSchemaPath(fixtureDir);
testCase.TestData.fixtureDir = fixtureDir;
end

function teardownOnce(~)
did2.schema.cache.resetSingleton();
end

% ---- batch-internal resolution ----

function testNoOrphansWhenBatchSelfContained(testCase)
parent = makeDemoA('parent');
child  = makeDemoA('child');
child  = setDependsOn(child, 'parent_id', parent.get('base.id'));
report = did2.validate.references({parent, child});
verifyEqual(testCase, report.total_docs, 2);
verifyEqual(testCase, report.edges_examined, 1);
verifyEqual(testCase, report.orphan_count, 0);
end

function testEmptyEdgeValueDoesNotCount(testCase)
doc = makeDemoA('alice');
doc = setDependsOn(doc, 'optional_id', '');
report = did2.validate.references({doc});
verifyEqual(testCase, report.edges_examined, 0);
verifyEqual(testCase, report.orphan_count, 0);
end

function testOrphanEdgeReported(testCase)
child = makeDemoA('child');
child = setDependsOn(child, 'parent_id', ...
    'deadbeefdeadbeef_0000111122223333');
report = did2.validate.references({child});
verifyEqual(testCase, report.orphan_count, 1);
verifyEqual(testCase, report.orphans(1).edge_name, 'parent_id');
verifyEqual(testCase, report.orphans(1).edge_document_id, ...
    'deadbeefdeadbeef_0000111122223333');
verifyEqual(testCase, report.orphans(1).doc_id, child.get('base.id'));
verifyEqual(testCase, report.orphans(1).doc_class, 'demoA');
end

function testMultipleOrphansOnOneDoc(testCase)
doc = makeDemoA('lonely');
doc = setDependsOn(doc, ...
    {'a_id', 'b_id'}, ...
    {'aaaaaaaaaaaaaaaa_0000111122223333', ...
     'bbbbbbbbbbbbbbbb_0000111122223333'});
report = did2.validate.references({doc});
verifyEqual(testCase, report.edges_examined, 2);
verifyEqual(testCase, report.orphan_count, 2);
end

function testMixedResolvedAndOrphan(testCase)
parent = makeDemoA('parent');
child  = makeDemoA('child');
child  = setDependsOn(child, ...
    {'parent_id', 'missing_id'}, ...
    {parent.get('base.id'), ...
     'ccccccccccccccccc_0000111122223333'});
report = did2.validate.references({parent, child});
verifyEqual(testCase, report.edges_examined, 2);
verifyEqual(testCase, report.orphan_count, 1);
verifyEqual(testCase, report.orphans(1).edge_name, 'missing_id');
end

% ---- KnownIds extra set ----

function testKnownIdsAllowsOrphanResolution(testCase)
doc = makeDemoA('child');
ghostId = 'deadbeefdeadbeef_0000111122223333';
doc = setDependsOn(doc, 'ghost_id', ghostId);
report = did2.validate.references({doc}, 'KnownIds', {ghostId});
verifyEqual(testCase, report.orphan_count, 0);
end

% ---- database lookup ----

function testDatabaseResolvesOrphanFromPriorBatch(testCase)
if isempty(which('mksqlite'))
    assumeFail(testCase, ...
        'mksqlite is not on the MATLAB path; skipping the DB-backed reference test.');
end
tmp = [tempname() '.sqlite'];
cleanup = onCleanup(@() safeDelete(tmp)); %#ok<NASGU>
db = did2.database.sqlitedb(tmp);
parent = makeDemoA('first-batch-parent');
db.add(parent);

child = makeDemoA('second-batch-child');
child = setDependsOn(child, 'parent_id', parent.get('base.id'));

batchOnly = did2.validate.references({child});
verifyEqual(testCase, batchOnly.orphan_count, 1, ...
    'Edge should be orphan when DB is not consulted.');

withDb = did2.validate.references({child}, 'Database', db);
verifyEqual(testCase, withDb.orphan_count, 0, ...
    'Edge should resolve via the DB.');
end

% ---- input shape variants ----

function testAcceptsStructArrayOfBodies(testCase)
parent = makeDemoA('p');
child  = makeDemoA('c');
child  = setDependsOn(child, 'parent_id', parent.get('base.id'));
arr = [parent.toStruct(); child.toStruct()];
report = did2.validate.references(arr);
verifyEqual(testCase, report.total_docs, 2);
verifyEqual(testCase, report.orphan_count, 0);
end

function testAcceptsDocumentObjectArray(testCase)
parent = makeDemoA('p');
child  = makeDemoA('c');
child  = setDependsOn(child, 'parent_id', parent.get('base.id'));
arr = [parent, child];
report = did2.validate.references(arr);
verifyEqual(testCase, report.total_docs, 2);
verifyEqual(testCase, report.orphan_count, 0);
end

% ---- helpers ----

function doc = makeDemoA(name)
doc = did2.document.blank('demoA');
doc = doc.set('base.session_id', sprintf('session-%s', name));
doc = doc.set('base.name', name);
doc = doc.set('demoA.value', name);
end

function doc = setDependsOn(doc, names, values)
if ischar(names)
    names = {names};
end
if ischar(values)
    values = {values};
end
deps = struct('name', {}, 'document_id', {});
for k = 1:numel(names)
    deps(end+1) = struct( ...
        'name',        names{k}, ...
        'document_id', values{k}); %#ok<AGROW>
end
s = doc.toStruct();
s.depends_on = deps;
doc = did2.document(s);
end

function safeDelete(path)
if exist(path, 'file')
    delete(path);
end
end
