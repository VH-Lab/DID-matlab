classdef TestDependsOnParity < matlab.unittest.TestCase
    % depends_on means the same thing on every search path
    %
    % did.query documents depends_on(NAME, VALUE) as "the document has a
    % dependency named NAME with value VALUE", where only NAME '*' is a
    % wildcard (any name). did.query/to_searchstructure gives fieldsearch
    % exactly that (an exact, case-sensitive match), but sqlitedb searched
    % meta.depends_on with LIKE "%NAME,VALUE;%", which is neither anchored
    % nor case-sensitive: an empty NAME matched any name, 'id' also matched
    % 'subject_id', and 'ID' matched 'id'.
    %
    % Each case is run on the SQLite search and on fieldsearch, and both
    % must return the documents listed. The same documents and cases are in
    % DID-python's tests/test_depends_on_parity.py; keep the two identical,
    % so that the languages cannot drift apart again.

    properties (Constant)
        db_filename = 'test_db_depends_on.sqlite'
    end

    properties (TestParameter)
        % label = {operation, name, value, expected documents}
        searchCase = struct( ...
            'emptyName',            {{'depends_on',  '',           'X', {}}}, ...
            'starName',             {{'depends_on',  '*',          'X', {'A','B','C'}}}, ...
            'exactName',            {{'depends_on',  'id',         'X', {'B'}}}, ...
            'longerName',           {{'depends_on',  'subject_id', 'X', {'A'}}}, ...
            'nameCase',             {{'depends_on',  'ID',         'X', {'C'}}}, ...
            'valueCase',            {{'depends_on',  'element_id', 'X', {}}}, ...
            'valueCaseLower',       {{'depends_on',  'element_id', 'x', {'E'}}}, ...
            'secondDependency',     {{'depends_on',  'element_id', 'Y', {'B'}}}, ...
            'starSecondDependency', {{'depends_on',  '*',          'Y', {'B'}}}, ...
            'nameValueApart',       {{'depends_on',  'id',         'Y', {}}}, ...
            'starIsNotGlob',        {{'depends_on',  'subject*',   'X', {}}}, ...
            'noSuchValue',          {{'depends_on',  '*',          'Z', {}}}, ...
            'notExactName',         {{'~depends_on', 'id',         'X', {'A','C','D','E'}}}, ...
            'notStarName',          {{'~depends_on', '*',          'X', {'D','E'}}}, ...
            'notEmptyName',         {{'~depends_on', '',           'X', {'A','B','C','D','E'}}}, ...
            'notNameCase',          {{'~depends_on', 'ID',         'X', {'A','B','D','E'}}})
    end

    properties
        db
        docs  % struct: document label -> did.document
        ids   % struct: document label -> document id
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            % label -> {dependency names; dependency values}
            dependencies = struct( ...
                'A', {{ {'subject_id'}; {'X'} }}, ...
                'B', {{ {'id', 'element_id'}; {'X', 'Y'} }}, ...
                'C', {{ {'ID'}; {'X'} }}, ...
                'D', {{ {}; {} }}, ...
                'E', {{ {'element_id'}; {'x'} }});
            labels = fieldnames(dependencies);
            docList = cell(1, numel(labels));
            for i = 1:numel(labels)
                dep = dependencies.(labels{i});
                props = did.document('demoC').document_properties;
                props.depends_on = struct('name', dep{1}, 'value', dep{2});
                docList{i} = did.document(props);
                testCase.docs.(labels{i}) = docList{i};
                testCase.ids.(labels{i}) = docList{i}.id();
            end

            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
            testCase.db.add_docs(docList, 'a', 'Validate', false);
        end
    end

    methods
        function q = caseQuery(~, searchCase)
            q = did.query('', searchCase{1}, searchCase{2}, searchCase{3});
        end

        function expected = expectedIds(testCase, searchCase)
            expected = cellfun(@(label) testCase.ids.(label), searchCase{4}, ...
                'UniformOutput', false);
            expected = did.unittest.TestDependsOnParity.sortedIds(expected);
        end
    end

    methods (Static)
        function ids = sortedIds(ids)
            % a sorted column cell array of ids, cell(0,1) if there are none
            if isempty(ids)
                ids = cell(0, 1);
            else
                ids = sort(ids(:));
            end
        end
    end

    methods (Test)
        function testSqliteSearch(testCase, searchCase)
            found = testCase.db.search(testCase.caseQuery(searchCase));
            testCase.verifyEqual(did.unittest.TestDependsOnParity.sortedIds(found), ...
                testCase.expectedIds(searchCase));
        end

        function testFieldsearch(testCase, searchCase)
            searchstruct = testCase.caseQuery(searchCase).to_searchstructure();
            labels = fieldnames(testCase.docs);
            found = cell(0, 1);
            for i = 1:numel(labels)
                doc = testCase.docs.(labels{i});
                if did.datastructures.fieldsearch(doc.document_properties, searchstruct)
                    found{end+1, 1} = doc.id(); %#ok<AGROW>
                end
            end
            testCase.verifyEqual(did.unittest.TestDependsOnParity.sortedIds(found), ...
                testCase.expectedIds(searchCase));
        end

        function testSqliteSearchWithinAnd(testCase, searchCase)
            % The same, as the second term of an AND: then it is checked
            % against the documents the first term found only
            q = did.query('', 'isa', 'demoC') & testCase.caseQuery(searchCase);
            found = testCase.db.search(q);
            testCase.verifyEqual(did.unittest.TestDependsOnParity.sortedIds(found), ...
                testCase.expectedIds(searchCase));
        end

        function testTwoDependencies(testCase)
            q = did.query('', 'depends_on', 'id', 'X') & ...
                did.query('', 'depends_on', 'element_id', 'Y');
            found = testCase.db.search(q);
            testCase.verifyEqual(found(:), {testCase.ids.B});
        end
    end
end
