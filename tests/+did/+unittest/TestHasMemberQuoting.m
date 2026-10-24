classdef TestHasMemberQuoting < matlab.unittest.TestCase
    % Test that 'hasmember' never reads its value as SQL
    %
    % did.database/query_struct_to_sql_str put a text 'hasmember' value
    % into the SQL unquoted, so 'name17' was read as a column (an error),
    % 'value' as the column doc_data.value (every document matched) and
    % '1 OR 1=1' as SQL (SQL injection). These tests check db.search for
    % text values, numbers and '~hasmember', on their own, inside an AND
    % (searched restricted to candidate documents) and inside an OR
    % (searched in a batch by search_or_operands). See issue #236.
    %
    % The expected documents are found by matches, which tests hasmember
    % by memberOf - the value is the whole field or an item of its
    % comma-separated list, as the SQL search has it - and every other
    % operation by did.datastructures.fieldsearch. fieldsearch itself is
    % no guide for a text hasmember: ismember(param1, value) compares
    % them character by character, and the logical array it returns is
    % then negated and ANDed element by element, so '~hasmember value'
    % matches only the names that share no character with 'value'.
    % For numbers, fieldsearch agrees, and the search is compared with
    % it too.

    properties (Constant)
        db_filename = 'test_db_hasmember.sqlite'
        names = {'value', '1 OR 1=1', 'say "hi"', 'x, value', 'alpha', 'n7', 'O''Brien'}
    end

    properties
        db    % did.test.helper.QueryLogSqlitedb
        docs  % the did.documents added, in order
    end

    properties (TestParameter)
        textValue = {'value', '1 OR 1=1', 'say "hi"', 'O''Brien', 'x, value', 'name17', 'zzz'}
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
        function ids = expectedIds(testCase, s, useFieldsearch)
            % The ids of the documents that match S (see matches), or, if
            % USEFIELDSEARCH is true, that fieldsearch matches with S
            if nargin < 3, useFieldsearch = false; end
            ids = {};
            for k = 1:numel(testCase.docs)
                props = testCase.docs{k}.document_properties;
                if useFieldsearch
                    isMatch = did.datastructures.fieldsearch(props, s);
                else
                    isMatch = testCase.matches(props, s);
                end
                if isMatch
                    ids{end+1} = testCase.docs{k}.id(); %#ok<AGROW>
                end
            end
            ids = sort(ids(:));
        end

        function tf = matches(testCase, props, s)
            % Does a document with properties PROPS match the search
            % structure S? hasmember is tested by memberOf, the rest by
            % fieldsearch
            if numel(s) > 1  % AND
                tf = true;
                for k = 1:numel(s)
                    tf = tf && testCase.matches(props, s(k));
                end
                return
            end
            op = lower(s.operation);
            switch op
                case 'or'
                    tf = testCase.matches(props, s.param1) || testCase.matches(props, s.param2);
                case {'hasmember', '~hasmember'}
                    [isthere, value] = did.datastructures.isfullfield(props, s.field);
                    tf = isthere && testCase.memberOf(s.param1, value);
                    if op(1) == '~'
                        tf = ~tf;  % as fieldsearch negates
                    end
                otherwise
                    tf = logical(did.datastructures.fieldsearch(props, s));
            end
        end

        function tf = memberOf(~, member, value)
            % Is MEMBER the whole of VALUE, or an item of the
            % comma-separated list in VALUE?
            if ischar(member)
                tf = ischar(value) && (strcmp(value, member) || ...
                    any(strcmp(strtrim(strsplit(value, ',')), member)));
            else
                tf = isnumeric(value) && isscalar(member) && any(value(:) == member);
            end
        end

        function verifySearch(testCase, s, msg)
            found = testCase.db.search(s);
            testCase.verifyClass(found, 'cell', msg);
            testCase.verifyEqual(sort(found(:)), testCase.expectedIds(s), msg);
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
                msg = sprintf('%s %g', s.operation, numberValue);
                testCase.verifySearch(s, msg);
                found = testCase.db.search(s);
                testCase.verifyEqual(sort(found(:)), testCase.expectedIds(s, true), ...
                    [msg ': vs. fieldsearch']);
            end
            s = testCase.hasMember('demoA.value', numberValue, false);
            testCase.verifyNumElements(testCase.db.search(s), ...
                double(numberValue <= numel(testCase.names)), ...
                sprintf('hasmember %g must match the one document holding it', numberValue));
        end

        function testInjectionMatchesOnlyItsOwnName(testCase)
            s = testCase.hasMember('base.name', '1 OR 1=1', false);
            found = testCase.db.search(s);
            testCase.verifyEqual(found(:), {testCase.docs{2}.id()}, ...
                'hasmember ''1 OR 1=1'' must match only the document of that name');
            s = testCase.hasMember('base.name', 'value', false);
            found = testCase.db.search(s);
            testCase.verifyEqual(sort(found(:)), sort({testCase.docs{1}.id(); testCase.docs{4}.id()}), ...
                'hasmember ''value'' must match the name and the list holding it');
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
