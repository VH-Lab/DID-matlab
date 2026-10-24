classdef TestHasMemberQuoting < matlab.unittest.TestCase
    % Test 'hasmember': one rule, searched by brute force, never as SQL
    %
    % did.database/query_struct_to_sql_str put a text 'hasmember' value
    % into the SQL unquoted, so 'name17' was read as a column (an error),
    % 'value' as the column doc_data.value (every document matched) and
    % '1 OR 1=1' as SQL (SQL injection). And each implementation had its
    % own rule: did.datastructures.fieldsearch used ismember, which
    % compares two texts character by character; the SQL matched an item
    % of a comma-separated list, and could not see the members of arrays
    % and cells at all (doc2sql stores them as '[1 3] double'); DID-python
    % tested for a substring. Now hasmember has one rule (see fieldsearch):
    %   - text is a member of text that is the whole value or an item of
    %     its comma-separated list;
    %   - anything is a member of a cell array that holds an equal element,
    %     and a number of a numeric array that holds it;
    %   - text is never a member of a number, nor a number of text;
    % and the SQLite search tests it by brute force with fieldsearch (see
    % did.database/isBruteForceTerm), as DID-python does, so no hasmember
    % value goes into SQL.
    %
    % testRule checks fieldsearch against a table of cases (the same table
    % as DID-python's tests/test_hasmember_quoting.py). The other tests
    % compare db.search with fieldsearch for text values, numbers, array
    % and cell fields and '~hasmember', on their own, inside an AND (only
    % the candidates are tested) and inside an OR. See issue #236.

    properties (Constant)
        db_filename = 'test_db_hasmember.sqlite'
        names = {'value', '1 OR 1=1', 'say "hi"', 'x, value', 'alpha', 'n7', 'O''Brien', '5'}
    end

    properties
        db    % did.test.helper.QueryLogSqlitedb
        docs  % the did.documents added, in order
    end

    properties (TestParameter)
        textValue = {'value', '1 OR 1=1', 'say "hi"', 'O''Brien', 'x, value', 'name17', 'zzz', '5', ''}
        numberValue = {3, 5, 99}
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.test.helper.QueryLogSqlitedb(testCase.db_filename);
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

        function verifySearch(testCase, s, msg)
            found = testCase.db.search(s);
            testCase.verifyClass(found, 'cell', msg);
            testCase.verifyEqual(sort(found(:)), testCase.expectedIds(s), msg);
        end

        function verifyIds(testCase, s, docIndexes, msg)
            % The search and fieldsearch must both find the documents
            % DOCINDEXES, no more
            expected = cellfun(@(d) d.id(), testCase.docs(docIndexes), 'UniformOutput', false);
            testCase.verifyEqual(testCase.expectedIds(s), sort(expected(:)), [msg ': fieldsearch']);
            testCase.verifySearch(s, msg);
        end

        function s = hasMember(~, field, value, negate)
            s = did.query(field, 'hasmember', value).searchstructure;
            if negate
                s.operation = '~hasmember';
            end
        end

        function s = orOf(~, terms)
            % Left-nested OR of search structures, as q = q | ... builds it
            s = terms{1};
            for k = 2:numel(terms)
                s = struct('field', '', 'operation', 'or', 'param1', s, 'param2', terms{k});
            end
        end

        function s = allDocs(~)
            % A term that matches every document, and that search_doc_ids
            % searches before hasmember (fieldsearch has no 'isa')
            s = did.query('demoA.value', 'lessthan', 100).searchstructure;
        end

        function numQueries = countDocQueries(testCase)
            % The SQL searches run since the query log was cleared
            entries = testCase.db.queryLog;
            numQueries = nnz(startsWith({entries.query}, 'SELECT DISTINCT docs.doc_id'));
        end

        function verifyLoadedOnly(testCase, numDocs, msg)
            % Since the query log was cleared, NUMDOCS documents were
            % loaded, and the documents of the branch were not listed
            entries = testCase.db.queryLog;
            queries = {entries.query};
            testCase.verifyFalse(any(startsWith(queries, 'SELECT docs.doc_id FROM docs')), ...
                [msg ': the branch must not be listed']);
            testCase.verifyEqual(nnz(startsWith(queries, 'SELECT json_code FROM docs')), numDocs, ...
                [msg ': documents loaded']);
        end
    end

    methods (Test)
        function testRule(testCase)
            % {value, member, is a member}; the same table as DID-python's
            cases = {
                'value',        'value',     true
                'x, value',     'value',     true
                'x,value ,y',   'value',     true
                'valuex',       'value',     false
                'value',        'x, value',  false
                'eulav',        'value',     false  % ismember matched this
                'a.b',          '.',         false  % the member is not a pattern
                '',             '',          true
                5,              5,           true
                [1 2 3],        2,           true
                [1 2 3],        4,           false
                true,           1,           true
                {'a', 'b'},     'b',         true
                {'a', 'b'},     'a,b',       false
                {1, 'a'},       1,           true
                '5',            5,           false
                5,              '5',         false
                'a',            97,          false  % ismember matched this
                struct('a',1),  'a',         false
                };
            for k = 1:size(cases, 1)
                [value, member, isMember] = cases{k, :};
                A = struct('f', {value});
                s = struct('field', 'f', 'operation', 'hasmember', 'param1', member, 'param2', '');
                testCase.verifyEqual(logical(did.datastructures.fieldsearch(A, s)), isMember, ...
                    sprintf('case %d: hasmember', k));
                s.operation = '~hasmember';
                testCase.verifyEqual(logical(did.datastructures.fieldsearch(A, s)), ~isMember, ...
                    sprintf('case %d: ~hasmember', k));
            end
        end

        function testText(testCase, textValue)
            for negate = [false true]
                s = testCase.hasMember('base.name', textValue, negate);
                testCase.verifySearch(s, sprintf('%s ''%s''', s.operation, textValue));
            end
        end

        function testNumber(testCase, numberValue)
            % doc2sql stores demoA.value as a number
            for negate = [false true]
                s = testCase.hasMember('demoA.value', numberValue, negate);
                testCase.verifySearch(s, sprintf('%s %g', s.operation, numberValue));
            end
            s = testCase.hasMember('demoA.value', numberValue, false);
            testCase.verifyNumElements(testCase.db.search(s), ...
                double(numberValue <= numel(testCase.names)), ...
                sprintf('hasmember %g must match the one document holding it', numberValue));
        end

        function testExpectedDocuments(testCase)
            testCase.verifyIds(testCase.hasMember('base.name', '1 OR 1=1', false), 2, ...
                'hasmember ''1 OR 1=1''');
            testCase.verifyIds(testCase.hasMember('base.name', 'value', false), [1 4], ...
                'hasmember ''value'' (the name and the list holding it)');
            testCase.verifyIds(testCase.hasMember('base.name', 'value', true), [2 3 5 6 7 8], ...
                '~hasmember ''value''');
            testCase.verifyIds(testCase.hasMember('base.name', 'O''Brien', false), 7, ...
                'hasmember ''O''''Brien''');
        end

        function testTextAndNumbersDoNotMix(testCase)
            % base.name '5' is text; demoA.value 3 is a number
            testCase.verifyIds(testCase.hasMember('base.name', 5, false), [], ...
                'hasmember 5 in the text ''5''');
            testCase.verifyIds(testCase.hasMember('base.name', '5', false), 8, ...
                'hasmember ''5'' in the text ''5''');
            testCase.verifyIds(testCase.hasMember('demoA.value', '3', false), [], ...
                'hasmember ''3'' in the number 3');
            testCase.verifyIds(testCase.hasMember('demoA.value', 3, false), 3, ...
                'hasmember 3 in the number 3');
        end

        function testNumbersNoValueHolds(testCase)
            % Inf is written as 9e999 and NaN is a member of nothing; no
            % document holds either, so ~hasmember matches every one
            for member = {Inf, -Inf, NaN}
                msg = sprintf('hasmember %g', member{1});
                testCase.verifyIds(testCase.hasMember('demoA.value', member{1}, false), [], msg);
                testCase.verifyIds(testCase.hasMember('demoA.value', member{1}, true), ...
                    1:numel(testCase.names), ['~' msg]);
            end
        end

        function testMissingField(testCase)
            % No document has demoB.value: none holds a member of it, so
            % ~hasmember matches every one (as in fieldsearch)
            testCase.verifyIds(testCase.hasMember('demoB.value', 1, false), [], ...
                'hasmember in a missing field');
            testCase.verifyIds(testCase.hasMember('demoB.value', 1, true), ...
                1:numel(testCase.names), '~hasmember in a missing field');
        end

        function testArrayAndCellFields(testCase)
            % doc2sql stores these as a summary ('[1 3] double', '[1 2]
            % cell'), which SQL could not search; brute force can
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            db = did.implementations.sqlitedb('list_fields.sqlite');
            db.add_branch('a');
            docs = {did.document('demoA', 'base.name', 'numbers', 'demoA.value', [1 2 3]), ...
                did.document('demoA', 'base.name', 'other', 'demoA.value', [4 5]), ...
                did.document('demoA', 'base.name', 'names', 'demoA.value', {'alpha', 'beta'})};
            db.add_docs(docs, 'a', 'Validate', false);
            ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            stored = db.get_docs(ids);  % the documents as the search sees them
            cases = {
                'demoA.value', 2,       1
                'demoA.value', 5,       2
                'demoA.value', 6,       []
                'demoA.value', 'beta',  3
                'demoA.value', 'gamma', []
                'base.name',   'other', 2
                };
            for k = 1:size(cases, 1)
                [field, member, matching] = cases{k, :};
                for negate = [false true]
                    s = testCase.hasMember(field, member, negate);
                    if negate
                        expected = ids(setdiff(1:3, matching));
                    else
                        expected = ids(matching);
                    end
                    expected = sort(expected(:));
                    msg = sprintf('%s %s in %s', s.operation, num2str(member), field);
                    found = db.search(s);
                    testCase.verifyEqual(sort(found(:)), expected, msg);
                    fieldsearchIds = cell(0, 1);
                    for j = 1:numel(stored)
                        if did.datastructures.fieldsearch(stored(j).document_properties, s)
                            fieldsearchIds{end+1, 1} = stored(j).id(); %#ok<AGROW>
                        end
                    end
                    testCase.verifyEqual(sort(fieldsearchIds), expected, [msg ': fieldsearch']);
                end
            end
        end

        function testStructField(testCase)
            % A struct (base) has no members: its fields are not searched
            testCase.verifyIds(testCase.hasMember('base', 'value', false), [], ...
                'hasmember ''value'' in the struct base');
        end

        function testInAnAnd(testCase, textValue)
            % 'demoA.value < 4' is searched first and leaves 3 candidates,
            % so hasmember loads and tests those 3 documents only
            firstThree = did.query('demoA.value', 'lessthan', 4).searchstructure;
            for negate = [false true]
                s = [firstThree, testCase.hasMember('base.name', textValue, negate)];
                msg = sprintf('demoA.value < 4 AND %s ''%s''', s(2).operation, textValue);
                testCase.db.clearQueryLog();
                testCase.verifySearch(s, msg);
                testCase.verifyLoadedOnly(3, msg);
            end
            for negate = [false true]
                s = [firstThree, testCase.hasMember('demoA.value', 2, negate)];
                testCase.verifySearch(s, sprintf('demoA.value < 4 AND %s 2', s(2).operation));
            end
        end

        function testInAnOr(testCase)
            terms = {testCase.hasMember('base.name', 'value', false), ...
                testCase.hasMember('base.name', '1 OR 1=1', false), ...
                testCase.hasMember('base.name', 'say "hi"', false), ...
                testCase.hasMember('base.name', 'O''Brien', true), ...
                testCase.hasMember('demoA.value', 6, false), ...
                testCase.hasMember('demoA.value', 2, true)};
            for k = 1:numel(terms)
                others = terms([1:k-1 k+1:end]);
                s = testCase.orOf([terms(k), {did.query('base.name', 'exact_string', 'alpha').searchstructure}]);
                testCase.verifySearch(s, sprintf('%s ''%s'' OR ...', terms{k}.operation, ...
                    num2str(terms{k}.param1)));
                s = testCase.orOf([terms(k) others(1)]);
                testCase.verifySearch(s, sprintf('%s ''%s'' OR another hasmember', ...
                    terms{k}.operation, num2str(terms{k}.param1)));
            end

            % every operand is brute-forced, so no SQL search is run
            s = testCase.orOf(terms(1:3));
            testCase.db.clearQueryLog();
            testCase.verifySearch(s, 'an OR of text hasmembers');
            testCase.verifyEqual(testCase.countDocQueries(), 0, ...
                'hasmember must not be searched in SQL');

            % ...and restricted to candidates, inside an AND
            s = [testCase.allDocs(), testCase.orOf(terms)];
            testCase.verifySearch(s, 'demoA.value < 100 AND an OR of hasmembers');
        end
    end
end
