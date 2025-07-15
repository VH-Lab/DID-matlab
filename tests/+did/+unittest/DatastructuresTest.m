classdef DatastructuresTest < matlab.unittest.TestCase

    methods (Test)
        function testIsFullField(testCase)
            A = struct(...
                'a', struct('sub1', 1, 'sub2', 2), ...
                'b', 5 ...
            );

            [b, value] = did.datastructures.isfullfield(A, 'a.sub1');
            testCase.assertTrue(b)
            testCase.assertEqual(value, 1);

            [b, value] = did.datastructures.isfullfield(A, 'a.sub3');
            testCase.assertFalse(b)
            testCase.assertEmpty(value);
        end

        function testStructMerge(testCase)
            s1 = struct('a', 1, 'b', 2, 'c', 3);
            s2 = struct('a', 11, 'b', 12);

            S = did.datastructures.structmerge(s1, s2);
            testCase.verifyEqual(S.a, 11);
            testCase.verifyEqual(S.b, 12);
            testCase.verifyEqual(S.c, 3);

            s1 = struct('a', 1, 'b', 2, 'c', 3);
            s2 = struct('a', 11, 'b', 12, 'd', 4);

            S = did.datastructures.structmerge(s1, s2);
            testCase.verifyEqual(S.d, 4);

            fcn = @(varargin) did.datastructures.structmerge(s1, s2, "ErrorIfNewField", true);
            testCase.verifyError(fcn, 'DID:StructMerge:MissingField')
        end

        function testStructMergeAlphabetical(testCase)
            s1 = struct('b', 2, 'c', 3, 'a', 1);
            s2 = struct('b', 12, 'd', 4, 'a', 11);

            S = did.datastructures.structmerge(s1, s2, 'DoAlphabetical', true);
            fieldNamesResult = transpose( fieldnames(S) );

            testCase.verifyEqual(fieldNamesResult, {'a', 'b', 'c', 'd'})
        end

        function testStructMergeWithEmpty(testCase)
            s1 = struct.empty;
            s2 = struct('b', 12, 'd', 4, 'a', 11);

            S = did.datastructures.structmerge(s1, s2, 'DoAlphabetical', true);
            fieldNamesResult = transpose( fieldnames(S) );

            testCase.verifyEqual(fieldNamesResult, {'a', 'b', 'd'})
        end
    end
end
