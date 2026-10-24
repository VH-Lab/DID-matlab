classdef TestNegatedOr < matlab.unittest.TestCase
    % Test that the SQLite search applies the negation of a '~or'
    %
    % did.database/search_doc_ids used to strip the '~' of a '~or' and
    % search it as a plain 'or'. Every search here is compared with
    % did.datastructures.fieldsearch applied to each document of the
    % branch, with and without the search indexes (without them there are
    % no candidate documents). did.query cannot build a '~or', so the
    % search structures are built directly, and use no 'isa' (which
    % fieldsearch knows only as did.query/to_searchstructure expands it). See issue #237; mirrors
    % DID-python's tests/test_negated_or.py.

    properties (Constant)
        db_filename = 'test_db_negated_or.sqlite'
        numA = 30  % demoA documents
        numB = 20  % demoB documents (also demoA)
    end

    properties
        db      % did.test.helper.QueryLogSqlitedb
        ids     % base.id of every document, in order added
        props   % document_properties of every document, in the same order
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.test.helper.QueryLogSqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
            docs = {};
            for i = 1:testCase.numA
                docs{end+1} = did.document('demoA', 'base.name', sprintf('n%d', i), ...
                    'demoA.value', i); %#ok<AGROW>
            end
            for i = 1:testCase.numB
                docs{end+1} = did.document('demoB', 'base.name', sprintf('b%d', i), ...
                    'demoA.value', i, 'demoB.value', 100 + i); %#ok<AGROW>
            end
            testCase.db.add_docs(docs, 'a', 'Validate', false);
            testCase.ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.props = cellfun(@(d) d.document_properties, docs, 'UniformOutput', false);
        end
    end

    methods (TestMethodTeardown)
        function restoreDefaults(testCase)
            testCase.db.noSearchIndexes = false;
        end
    end

    methods
        function s = term(~, field, operation, param1, param2)
            if nargin < 5
                param2 = '';
            end
            s = struct('field', field, 'operation', operation, ...
                'param1', param1, 'param2', param2);
        end

        function s = nameIs(testCase, name)
            s = testCase.term('base.name', 'exact_string', name);
        end

        function s = isA(testCase)
            % every document (fieldsearch knows no 'isa', so field terms
            % stand in for class tests)
            s = testCase.term('demoA.value', 'greaterthan', 0);
        end

        function s = isB(testCase)
            % the demoB documents
            s = testCase.term('demoB.value', 'greaterthan', 0);
        end

        function s = idIs(testCase, k)
            s = testCase.term('base.id', 'exact_string', testCase.ids{k});
        end

        function s = notOr(testCase, a, b)
            s = testCase.term('', '~or', a, b);
        end

        function s = orOf(testCase, a, b)
            s = testCase.term('', 'or', a, b);
        end

        function expected = fieldsearchIds(testCase, q)
            % The documents that fieldsearch matches; an AND (a struct
            % array) matches when every element does
            tf = false(1, numel(testCase.ids));
            for k = 1:numel(testCase.ids)
                tf(k) = true;
                for j = 1:numel(q)
                    if ~did.datastructures.fieldsearch(testCase.props{k}, q(j))
                        tf(k) = false;
                        break
                    end
                end
            end
            expected = sort(testCase.ids(tf));
            expected = expected(:);
        end

        function verifyMatchesFieldsearch(testCase, q, msg)
            expected = testCase.fieldsearchIds(q);
            found = testCase.db.search(q, 'a');
            testCase.verifyEqual(sort(found(:)), expected, [msg ': with the search indexes']);
            testCase.db.noSearchIndexes = true;
            found = testCase.db.search(q, 'a');
            testCase.db.noSearchIndexes = false;
            testCase.verifyEqual(sort(found(:)), expected, [msg ': without the search indexes']);
        end
    end

    methods (Test)
        function testTopLevelNegatedOr(testCase)
            q = testCase.notOr(testCase.nameIs('n1'), testCase.nameIs('b2'));
            testCase.verifyMatchesFieldsearch(q, '~or(n1, b2)');
            found = testCase.db.search(q, 'a');
            testCase.verifyNumElements(found, numel(testCase.ids) - 2, ...
                'every document but n1 and b2 must be found');
            testCase.verifyFalse(any(ismember(testCase.ids([1 testCase.numA+2]), found)));

            % an OR of other terms, and one that matches nothing
            q = testCase.notOr(testCase.isB(), ...
                testCase.term('demoA.value', 'lessthan', 5));
            testCase.verifyMatchesFieldsearch(q, '~or(demoB, value < 5)');
            q = testCase.notOr(testCase.nameIs('nope'), testCase.nameIs('nope2'));
            testCase.verifyMatchesFieldsearch(q, '~or of names that do not exist');
            q = testCase.notOr(testCase.isA(), testCase.nameIs('n1'));
            testCase.verifyMatchesFieldsearch(q, '~or that matches every document');
        end

        function testNegatedOrNestedInOr(testCase)
            % search_or_operands searches the ~or operand on its own
            q = testCase.orOf(testCase.nameIs('n3'), ...
                testCase.notOr(testCase.isB(), ...
                testCase.term('demoA.value', 'greaterthan', 10)));
            testCase.verifyMatchesFieldsearch(q, 'n3 OR ~or(demoB, value > 10)');

            % deeper: (n4 OR b5) OR ~or(n6 OR n7, ~or(demoA, n1))
            inner = testCase.notOr(testCase.isA(), testCase.nameIs('n1'));
            q = testCase.orOf(testCase.orOf(testCase.nameIs('n4'), testCase.nameIs('b5')), ...
                testCase.notOr(testCase.orOf(testCase.nameIs('n6'), testCase.nameIs('n7')), inner));
            testCase.verifyMatchesFieldsearch(q, 'a ~or of a ~or, nested in an OR');
        end

        function testNegatedOrInsideAnd(testCase)
            % the demoB term leaves 20 candidates, so the ~or is searched
            % restricted to them: the candidates minus the OR's matches
            notOrTerm = testCase.notOr(testCase.nameIs('b1'), ...
                testCase.term('demoB.value', 'greaterthan', 115));
            q = [testCase.isB(), notOrTerm];
            testCase.verifyMatchesFieldsearch(q, 'demoB AND ~or(b1, demoB.value > 115)');

            testCase.db.clearQueryLog();
            testCase.db.search(q, 'a');
            queries = {testCase.db.queryLog.query};
            testCase.verifyFalse(any(contains(queries, 'FROM docs,branch_docs')), ...
                'restricted to candidates, the ~or must not list every document of the branch');

            % the ~or first in the given order, and an OR holding a ~or
            q = [notOrTerm, testCase.isB()];
            testCase.verifyMatchesFieldsearch(q, '~or(b1, demoB.value > 115) AND demoB');
            q = [testCase.isB(), ...
                testCase.orOf(testCase.nameIs('b2'), notOrTerm)];
            testCase.verifyMatchesFieldsearch(q, 'demoB AND (b2 OR ~or(...))');
        end

        function testNegatedOrOfBaseIds(testCase)
            iB = testCase.numA + 3;
            q = testCase.notOr(testCase.idIs(2), testCase.idIs(iB));
            testCase.verifyMatchesFieldsearch(q, '~or of base.id lookups');
            found = testCase.db.search(q, 'a');
            testCase.verifyFalse(any(ismember(testCase.ids([2 iB]), found)), ...
                'the ids looked up must not be found');

            % deeper OR of ids, an id that does not exist, nested in an OR
            q = testCase.notOr(testCase.orOf(testCase.idIs(5), ...
                testCase.term('base.id', 'exact_string', 'no_such_id')), testCase.idIs(6));
            testCase.verifyMatchesFieldsearch(q, '~or of a nested OR of base.id lookups');
            q = testCase.orOf(testCase.idIs(1), q);
            testCase.verifyMatchesFieldsearch(q, 'base.id OR ~or of base.id lookups');

            % inside an AND, restricted to the demoB candidates
            q = [testCase.isB(), ...
                testCase.notOr(testCase.idIs(iB), testCase.idIs(1))];
            testCase.verifyMatchesFieldsearch(q, 'demoB AND ~or of base.id lookups');
            q = [testCase.idIs(iB), testCase.notOr(testCase.idIs(iB), testCase.idIs(1))];
            testCase.verifyMatchesFieldsearch(q, 'base.id AND ~or of that base.id');
        end
    end
end
