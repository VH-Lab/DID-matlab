classdef TestSqlColumnNameValues < matlab.unittest.TestCase
    % Values that are SQLite column names are searched as values (#240)
    %
    % did.database/query_struct_to_sql_str put query values into the SQL as
    % double-quoted literals. SQLite reads a double-quoted token as a column
    % name when a column of that name is in scope, so
    %   did.query('base.name','exact_string','value')
    % compared doc_data.value with itself and matched every document, and
    % 'field_idx' failed with "ambiguous column name". The same held for a
    % branch id, document id or file name in sqlitedb's own queries: a
    % branch named 'branch_id' held every document of every branch.
    %
    % The search is compared with did.datastructures.fieldsearch (brute
    % force) for every value that is a column name of docs, branch_docs,
    % fields or doc_data, for exact_string, exact_string_anycase,
    % contains_string and regexp and their negations; 'isa' is checked
    % against the known classes; and a branch named after a column is
    % checked to hold only its own documents.

    properties (Constant)
        db_filename = 'test_db_sql_column_names.sqlite'
        names = {'value', 'doc_id', 'field_idx', 'class', 'field_name', ...
            'alpha', 'O''Brien', 'say "hi"'}
    end

    properties
        db    % did.implementations.sqlitedb
        docs  % the did.documents added, in order
    end

    properties (TestParameter)
        textValue = {'value', 'doc_idx', 'doc_id', 'field_idx', 'field_name', ...
            'json_name', 'class', 'json_code', 'branch_id', 'timestamp', ...
            'alpha', 'O''Brien', 'zzz'}
        stringOp = {'exact_string', 'exact_string_anycase', 'contains_string', 'regexp'}
        negate = {false, true}
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
            testCase.docs = cell(1, numel(testCase.names));
            for i = 1:numel(testCase.names)
                testCase.docs{i} = did.document('demoA', 'base.name', testCase.names{i}, ...
                    'demoA.value', i);
            end
            testCase.db.add_docs(testCase.docs, 'a', 'Validate', false);
        end
    end

    methods
        function ids = expectedIds(testCase, s)
            % The ids of the documents that fieldsearch matches with S
            ids = {};
            for k = 1:numel(testCase.docs)
                if did.datastructures.fieldsearch(testCase.docs{k}.document_properties, s)
                    ids{end+1} = testCase.docs{k}.id(); %#ok<AGROW>
                end
            end
            ids = sort(ids(:));
        end

        function ids = allIds(testCase)
            ids = sort(cellfun(@(d) d.id(), testCase.docs(:), 'UniformOutput', false));
        end

        function ids = sortedSearch(testCase, q, varargin)
            ids = testCase.db.search(q, varargin{:});
            testCase.verifyClass(ids, 'cell');
            ids = sort(ids(:));
        end
    end

    methods (Test)
        function testStringSearchMatchesFieldsearch(testCase, textValue, stringOp, negate)
            s = did.query('base.name', stringOp, textValue).searchstructure;
            if negate
                s.operation = ['~' stringOp];
            end
            msg = sprintf('%s ''%s''', s.operation, textValue);
            testCase.verifyEqual(testCase.sortedSearch(s), testCase.expectedIds(s), msg);
        end

        function testIssueExample(testCase)
            % The example of issue #240: one document is named 'value'
            found = testCase.sortedSearch(did.query('base.name', 'exact_string', 'value'));
            testCase.verifyEqual(found, {testCase.docs{1}.id()});
            found = testCase.sortedSearch(did.query('base.name', 'regexp', 'value'));
            testCase.verifyEqual(found, {testCase.docs{1}.id()});
            % 'field_idx' was an ambiguous column name: an error
            found = testCase.sortedSearch(did.query('base.name', 'exact_string', 'field_idx'));
            testCase.verifyEqual(found, {testCase.docs{3}.id()});
        end

        function testIsaColumnName(testCase, textValue)
            % No document is of a class named after a column ...
            if any(strcmp(textValue, {'demoA', 'base'}))
                return
            end
            found = testCase.sortedSearch(did.query('', 'isa', textValue));
            testCase.verifyEmpty(found, sprintf('isa ''%s''', textValue));
        end

        function testIsaKnownClass(testCase)
            % ... and the real classes still match
            testCase.verifyEqual(testCase.sortedSearch(did.query('', 'isa', 'demoA')), testCase.allIds());
            testCase.verifyEqual(testCase.sortedSearch(did.query('', 'isa', 'base')), testCase.allIds());
            testCase.verifyEmpty(testCase.sortedSearch(did.query('', 'isa', 'demoB')));
        end

        function testHasfieldStillWorks(testCase)
            testCase.verifyEqual(testCase.sortedSearch(did.query('base.name', 'hasfield')), testCase.allIds());
            testCase.verifyEqual(testCase.sortedSearch(did.query('base', 'hasfield')), testCase.allIds());
            testCase.verifyEmpty(testCase.sortedSearch(did.query('value', 'hasfield')));
        end

        function testBranchNamedAfterColumn(testCase)
            % A branch named 'branch_id' holds only its own documents
            db2 = did.implementations.sqlitedb('test_db_branch_named_branch_id.sqlite');
            db2.add_branch('a');
            d1 = did.document('demoA', 'base.name', 'first', 'demoA.value', 1);
            db2.add_docs({d1}, 'a', 'Validate', false);
            db2.add_branch('branch_id', 'a');
            d2 = did.document('demoA', 'base.name', 'second', 'demoA.value', 2);
            db2.add_docs({d2}, 'a', 'Validate', false);   % on 'a' only

            idsA = db2.get_doc_ids('a');
            idsB = db2.get_doc_ids('branch_id');
            testCase.verifyEqual(sort(idsA(:)), sort({d1.id(); d2.id()}));
            testCase.verifyEqual(idsB(:), {d1.id()}, ...
                'branch ''branch_id'' must not hold the document added to ''a''');
            found = db2.search(did.query('', 'isa', 'demoA'), 'branch_id');
            testCase.verifyEqual(found(:), {d1.id()});
        end
    end
end
