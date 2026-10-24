classdef TestHasMemberQuoting < matlab.unittest.TestCase
    % Test 'hasmember': one rule in fieldsearch and SQL, never read as SQL
    %
    % did.database/query_struct_to_sql_str put a text 'hasmember' value
    % into the SQL unquoted, so 'name17' was read as a column (an error),
    % 'value' as the column doc_data.value (every document matched) and
    % '1 OR 1=1' as SQL (SQL injection). And did.datastructures.fieldsearch
    % used ismember, which compares two texts character by character, so
    % it matched another rule than the SQL did. Both now match one rule
    % (see fieldsearch), as DID-python's field_search does:
    %   - text is a member of text that is the whole value or an item of
    %     its comma-separated list;
    %   - anything is a member of a cell array that holds an equal element,
    %     and a number of a numeric array that holds it;
    %   - text is never a member of a number, nor a number of text.
    %
    % testRule checks fieldsearch against a table of cases (the same table
    % as DID-python's tests/test_hasmember_quoting.py). The other tests
    % compare db.search with fieldsearch for text values, numbers and
    % '~hasmember', on their own, inside an AND (searched restricted to
    % candidate documents) and inside an OR (searched in a batch by
    % search_or_operands). See issue #236.

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
            entries = testCase.db.queryLog;
            numQueries = nnz(startsWith({entries.query}, 'SELECT DISTINCT docs.doc_id'));
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

        function testStructField(testCase)
            % A struct (base) has no members: its fields are not searched
            testCase.verifyIds(testCase.hasMember('base', 'value', false), [], ...
                'hasmember ''value'' in the struct base');
        end

        function testInAnAnd(testCase, textValue)
            % 'demoA.value < 100' is searched first and leaves every
            % document as a candidate, so hasmember is searched restricted
            % to them
            for negate = [false true]
                s = [testCase.allDocs(), ...
                    testCase.hasMember('base.name', textValue, negate)];
                testCase.db.clearQueryLog();
                testCase.verifySearch(s, sprintf('demoA.value < 100 AND %s ''%s''', s(2).operation, textValue));
                entries = testCase.db.queryLog;
                testCase.verifyTrue(any(contains({entries.query}, 'INDEXED BY')), ...
                    'hasmember in an AND must be searched restricted to candidates');
            end
            for negate = [false true]
                s = [testCase.allDocs(), ...
                    testCase.hasMember('demoA.value', 5, negate)];
                testCase.verifySearch(s, sprintf('demoA.value < 100 AND %s 5', s(2).operation));
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

            % every operand is a single SQL term, so the OR is one batch
            s = testCase.orOf(terms(1:3));
            testCase.db.clearQueryLog();
            testCase.verifySearch(s, 'an OR of text hasmembers');
            testCase.verifyEqual(testCase.countDocQueries(), 1, ...
                'an OR of hasmembers must be searched in one batched query');

            % ...and restricted to candidates, inside an AND
            s = [testCase.allDocs(), testCase.orOf(terms)];
            testCase.verifySearch(s, 'demoA.value < 100 AND an OR of hasmembers');
        end
    end
end
