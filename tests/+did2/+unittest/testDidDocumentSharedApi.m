function tests = testDidDocumentSharedApi
% testDidDocumentSharedApi - did.document's dependency, file and property API
% as ndi.document inherits it.
%
%   Run with:
%       results = runtests('did2.unittest.testDidDocumentSharedApi');
%
%   NDI-matlab V2 deletes its own copies of dependency_value,
%   dependency_value_n, set_dependency_value, remove_dependency_value_n,
%   remove_file, reset_file_info and setproperties and inherits these, as
%   NDI main already does. One implementation then serves v1 and V2
%   documents alike, so what NDI's copies did for a V2 document has to hold
%   here.
%
%   These live in did2.unittest, not did.unittest, because did2.unittest is
%   the package the "Analyse and test code" job runs (test-code.yml,
%   TestSuite.fromPackage("did2.unittest", ...)). A test under
%   tests/+did/+unittest/ is not run by any workflow, which is how
%   dependency_value_n reading a .value field that a constructed document no
%   longer has went unnoticed: did.unittest.TestDocumentMergeAndProperties
%   covers that case and is never run.
%
%   Every document here is built from a struct, so no definition path or
%   PathConstantFixture is needed.

tests = functiontests(localfunctions);
end

% ---- helpers ----------------------------------------------------------

function props = depsProps(depends)
% A minimal body with the given depends_on entries.
props = struct();
props.base = struct('id', 'doc_under_test', 'name', '', 'datestamp', '');
props.depends_on = depends;
end

function doc = docWithPlaceholder()
% The shape a blank definition carries: a declared name, an empty target,
% keyed `value` as in the definition JSON. The constructor renames the key.
doc = did.document(depsProps(struct('name', {'item1','item2'}, 'value', {'',''})));
end

function names = depNames(doc)
names = {doc.document_properties.depends_on.name};
end

function props = filesProps()
props = struct();
props.base = struct('id', 'doc_with_files', 'name', '', 'datestamp', '');
loc = struct('delete_original', 0, 'uid', '', 'location', '', ...
    'parameters', '', 'location_type', 'file', 'ingest', 0);
locA = loc; locA.uid = 'uidA'; locA.location = '/tmp/a.bin';
locB = loc; locB.uid = 'uidB'; locB.location = '/tmp/b.bin';
props.files = struct();
props.files.file_list = {'data.bin'};
props.files.file_info = struct('name', 'data.bin', 'locations', [locA locB]);
end

% ---- the V2 depends_on shape ------------------------------------------

function testConstructorKeysEntriesByDocumentId(testCase)
% The premise of the readers below: after construction an entry carries
% document_id and no value.
doc = docWithPlaceholder();
verifyTrue(testCase, isfield(doc.document_properties.depends_on, 'document_id'));
verifyFalse(testCase, isfield(doc.document_properties.depends_on, 'value'));
end

% ---- dependency_value_n -----------------------------------------------

function testDependencyValueNFindsAnUnnumberedEntry(testCase)
% The unnumbered fallback reads the entry's target. It used to read
% .value, which a constructed document does not have, so this threw.
doc = docWithPlaceholder();
doc = doc.set_dependency_value('item1', 'a_value');
verifyEqual(testCase, doc.dependency_value_n('item1'), {'a_value'});
end

function testAnUnsetUnnumberedEntryIsNotAMatch(testCase)
% A declared name with an empty target is a placeholder, not an entry.
doc = docWithPlaceholder();
verifyError(testCase, @() doc.dependency_value_n('item1'), ?MException);
verifyEmpty(testCase, doc.dependency_value_n('item1', 'ErrorIfNotFound', 0));
end

function testNumberedEntriesAreReadInOrder(testCase)
doc = docWithPlaceholder();
doc = doc.add_dependency_value_n('extra', 'first');
doc = doc.add_dependency_value_n('extra', 'second');
verifyEqual(testCase, doc.dependency_value_n('extra'), {'first','second'});
end

function testV1IdKeyedEntriesAreReadToo(testCase)
% v1 bodies key the target `id`. The constructor canonicalises that as well,
% so a v1 document reads the same through the same code.
doc = did.document(depsProps(struct('name', {'item1_1','item1_2'}, 'id', {'x','y'})));
verifyEqual(testCase, doc.dependency_value_n('item1'), {'x','y'});
verifyEqual(testCase, doc.dependency_value('item1_2'), 'y');
end

% ---- dependency_value / set_dependency_value --------------------------

function testDependencyValueReadsWhatWasSet(testCase)
doc = docWithPlaceholder();
doc = doc.set_dependency_value('item2', 'abc123');
verifyEqual(testCase, doc.dependency_value('item2'), 'abc123');
verifyEqual(testCase, doc.document_properties.depends_on(2).document_id, 'abc123');
end

function testErrorIfNotFoundAcceptsADouble(testCase)
% NDI callers pass a literal 0 or 1; the arguments block takes it as logical.
doc = docWithPlaceholder();
verifyEmpty(testCase, doc.dependency_value('no_such', 'ErrorIfNotFound', 0));
verifyError(testCase, @() doc.dependency_value('no_such', 'ErrorIfNotFound', 1), ?MException);
end

function testSetDependencyValueAddsWhenToldNotToError(testCase)
doc = docWithPlaceholder();
verifyError(testCase, @() doc.set_dependency_value('new_one', 'v'), ?MException);
doc = doc.set_dependency_value('new_one', 'v', 'ErrorIfNotFound', 0);
verifyEqual(testCase, doc.dependency_value('new_one'), 'v');
end

function testSetDependencyValueCreatesTheListFromNone(testCase)
props = depsProps([]);
props = rmfield(props, 'depends_on');
doc = did.document(props);
doc = doc.set_dependency_value('item1', 'v', 'ErrorIfNotFound', 0);
verifyEqual(testCase, doc.dependency_value('item1'), 'v');
end

% ---- remove_dependency_value_n ----------------------------------------

function testRemoveDependencyValueNRenumbersWhatFollows(testCase)
doc = docWithPlaceholder();
doc = doc.add_dependency_value_n('probe_id', 'first');
doc = doc.add_dependency_value_n('probe_id', 'second');
doc = doc.add_dependency_value_n('probe_id', 'third');
doc = doc.remove_dependency_value_n('probe_id', '', 1);
verifyEqual(testCase, doc.dependency_value('probe_id_1'), 'second');
verifyEqual(testCase, doc.dependency_value('probe_id_2'), 'third');
verifyFalse(testCase, ismember('probe_id_3', depNames(doc)));
end

% ---- setproperties ----------------------------------------------------

function testSetPropertiesAssignsANestedPath(testCase)
doc = docWithPlaceholder();
doc = doc.setproperties('base.name', 'a_name', 'extra.deep.value', 5);
verifyEqual(testCase, doc.document_properties.base.name, 'a_name');
verifyEqual(testCase, doc.document_properties.extra.deep.value, 5);
end

function testSetPropertiesRejectsAPropertyNameThatIsNotOne(testCase)
doc = docWithPlaceholder();
verifyError(testCase, @() doc.setproperties('base.name); disp(''x''); %', 1), ?MException);
end

% ---- reset_file_info --------------------------------------------------

function testResetFileInfoClearsFileInfoAndSeriesInfo(testCase)
% NDI's copy cleared file_info only; did.document's also clears the
% per-instance series record. NDI V2's two callers that must keep it
% (ndi.cloud.sync.internal.updateFileInfoForLocalFiles and
% ndi.database.fun.extract_docs_files) save and restore it around the call.
props = filesProps();
props.files.series_info = struct('name', 'x', 'count', 1, 'n_present', 1, ...
    'source_root', '', 'ingest_locations', {{}});
doc = did.document(props);
doc = doc.reset_file_info();
verifyEmpty(testCase, doc.document_properties.files.file_info);
verifyTrue(testCase, isfield(doc.document_properties.files, 'series_info'));
verifyEmpty(testCase, doc.document_properties.files.series_info);
verifyEqual(testCase, doc.document_properties.files.file_list, {'data.bin'}, ...
    'the declaration is the class''s, not the instance''s, and stays');
end

function testResetFileInfoLeavesADocumentWithoutFilesAlone(testCase)
doc = docWithPlaceholder();
doc = doc.reset_file_info();
verifyFalse(testCase, isfield(doc.document_properties, 'files'));
end

% ---- remove_file ------------------------------------------------------

function testRemoveFileByNameRemovesEveryLocation(testCase)
doc = did.document(filesProps());
doc = doc.remove_file('data.bin');
verifyEmpty(testCase, doc.document_properties.files.file_info);
end

function testRemoveFileByLocationKeepsTheOthers(testCase)
doc = did.document(filesProps());
doc = doc.remove_file('data.bin', '/tmp/a.bin');
remaining = doc.document_properties.files.file_info(1).locations;
verifyNumElements(testCase, remaining, 1);
verifyEqual(testCase, remaining(1).location, '/tmp/b.bin');
end

function testRemoveFileRefusesAnUndeclaredName(testCase)
doc = did.document(filesProps());
verifyError(testCase, @() doc.remove_file('other.bin'), ?MException);
end

function testRemoveFileCanBeAskedToComplain(testCase)
doc = did.document(filesProps());
verifyError(testCase, @() doc.remove_file('data.bin', '/tmp/none.bin', ...
    'ErrorIfNoFileInfo', true), ?MException);
end
