classdef TestDeepOr < matlab.unittest.TestCase
    % Long chains of ORs must not run into MATLAB's recursion limit
    %
    % q = q | did.query(...) in a loop nests one 'or' per term. Searching or
    % field-matching such a query used to recurse once per level, so a few
    % hundred terms (MATLAB's default recursion limit is 500) raised
    % MATLAB:recursionLimit before anything was matched. Both now walk the
    % chain through did.datastructures.orOperands. Mirrors DID-python's
    % tests/test_deep_or.py (issue #100 there).

    properties (Constant)
        db_filename = 'test_db_deep_or.sqlite'
        numDocs = 50
    end

    properties
        db
        ids
        depth % number of terms in a chain: well past the recursion limit
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
            testCase.depth = 3 * get(0, 'RecursionLimit');

            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
            docs = cell(1, testCase.numDocs);
            for i = 1:testCase.numDocs
                docs{i} = did.document('demoA', 'base.name', sprintf('n%d', i), ...
                    'demoA.value', i);
            end
            testCase.db.add_docs(docs, 'a', 'Validate', false);
            testCase.ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
        end
    end

    methods
        function q = nameChain(testCase)
            % name = n1 OR n2 OR ... OR n<depth>, nested one level per term;
            % only n1..n<numDocs> exist
            q = did.query('base.name', 'exact_string', 'n1');
            for i = 2:testCase.depth
                q = q | did.query('base.name', 'exact_string', sprintf('n%d', i));
            end
        end
    end

    methods (Test)
        function testSearchOfOrChainOfOtherTerms(testCase)
            % Not base.id lookups, so search_doc_ids walks the OR itself
            found = testCase.db.search(testCase.nameChain());
            testCase.verifyEqual(sort(found(:)), sort(testCase.ids(:)), ...
                'every document whose name is in the chain must be found');
        end

        function testSearchOfOrChainWithAnd(testCase)
            q = testCase.nameChain() & did.query('demoA.value', 'lessthaneq', 10);
            found = testCase.db.search(q);
            testCase.verifyEqual(sort(found(:)), sort(testCase.ids(1:10)'));
        end

        function testSearchOfOrChainOfIds(testCase)
            q = did.query('base.id', 'exact_string', testCase.ids{1});
            for i = 2:testCase.depth
                id = sprintf('no_such_id_%06d', i);
                if i <= testCase.numDocs
                    id = testCase.ids{i};
                end
                q = q | did.query('base.id', 'exact_string', id);
            end
            found = testCase.db.search(q);
            testCase.verifyEqual(sort(found(:)), sort(testCase.ids(:)));
        end

        function testFieldsearchOfOrChain(testCase)
            q = testCase.nameChain();
            testCase.verifyTrue(logical(did.datastructures.fieldsearch( ...
                struct('base', struct('name', 'n7')), q.searchstructure)));
            testCase.verifyFalse(logical(did.datastructures.fieldsearch( ...
                struct('base', struct('name', 'nope')), q.searchstructure)));
        end

        function testOrOperandsOrderAndNegatedOr(testCase)
            % (a OR b) OR NOT(c OR d), built directly: did.query has no '~or'
            leaf = @(v) struct('field', 'base.name', 'operation', 'exact_string', ...
                'param1', v, 'param2', '');
            ab = struct('field', '', 'operation', 'or', 'param1', leaf('a'), 'param2', leaf('b'));
            notCd = struct('field', '', 'operation', '~or', 'param1', leaf('c'), 'param2', leaf('d'));
            top = struct('field', '', 'operation', 'or', 'param1', ab, 'param2', notCd);

            operands = did.datastructures.orOperands(top);
            testCase.verifyNumElements(operands, 3);
            testCase.verifyEqual(operands{1}.param1, 'a');
            testCase.verifyEqual(operands{2}.param1, 'b');
            testCase.verifyEqual(operands{3}.operation, '~or', ...
                'a negated OR is one operand: its negation applies to its whole result');

            matches = @(name) logical(did.datastructures.fieldsearch( ...
                struct('base', struct('name', name)), top));
            testCase.verifyTrue(matches('a'));
            testCase.verifyTrue(matches('zzz'), 'zzz is neither c nor d');
            testCase.verifyFalse(matches('c'), 'c is neither a nor b, and is c or d');
        end
    end
end
