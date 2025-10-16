classdef test_query < matlab.unittest.TestCase
    methods (Test)
        function test_creation(testCase)
            % Test creating a query
            q = did.query('base.name', 'exact_string', 'myname');
            testCase.verifyEqual(q.searchstructure.field, 'base.name');
            testCase.verifyEqual(q.searchstructure.operation, 'exact_string');
            testCase.verifyEqual(q.searchstructure.param1, 'myname');
        end

        function test_invalid_operator(testCase)
            % Test that an invalid operator throws an error
            testCase.verifyError(@() did.query('base.name', 'invalid_op', 'myname'), 'MATLAB:validators:mustBeMember');
        end

        function test_and_query(testCase)
            % Test combining queries with AND
            q1 = did.query('base.name', 'exact_string', 'myname');
            q2 = did.query('base.age', 'greaterthan', 30);
            q_and = q1 & q2;
            testCase.verifyEqual(numel(q_and.searchstructure), 2);
            testCase.verifyEqual(q_and.searchstructure(1).field, 'base.name');
            testCase.verifyEqual(q_and.searchstructure(1).operation, 'exact_string');
            testCase.verifyEqual(q_and.searchstructure(1).param1, 'myname');
            testCase.verifyEqual(q_and.searchstructure(2).field, 'base.age');
            testCase.verifyEqual(q_and.searchstructure(2).operation, 'greaterthan');
            testCase.verifyEqual(q_and.searchstructure(2).param1, 30);
        end

        function test_or_query(testCase)
            % Test combining queries with OR
            q1 = did.query('base.name', 'exact_string', 'myname');
            q2 = did.query('base.age', 'greaterthan', 30);
            q_or = q1 | q2;
            testCase.verifyEqual(q_or.searchstructure.operation, 'or');
            testCase.verifyEqual(q_or.searchstructure.param1(1).field, 'base.name');
            testCase.verifyEqual(q_or.searchstructure.param1(1).operation, 'exact_string');
            testCase.verifyEqual(q_or.searchstructure.param1(1).param1, 'myname');
            testCase.verifyEqual(q_or.searchstructure.param2(1).field, 'base.age');
            testCase.verifyEqual(q_or.searchstructure.param2(1).operation, 'greaterthan');
            testCase.verifyEqual(q_or.searchstructure.param2(1).param1, 30);
        end
    end
end