classdef TestDbQueries < matlab.unittest.TestCase
    % TestDbQueries
    % Test case for verifying database queries using did.test.db_queries
    
    methods (Test)
        function testDoExactString(testCase)
            [b, msg] = did.test.db_queries('Do_EXACT_STRING_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoNotExactString(testCase)
            [b, msg] = did.test.db_queries('Do_NOT_EXACT_STRING_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoAnd(testCase)
            [b, msg] = did.test.db_queries('Do_AND_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoAndWithParams(testCase)
            [b, msg] = did.test.db_queries('Do_AND_test', 1, 'doc_id_ind_for_and', 1, 'doc_value_ind_for_and', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoOr(testCase)
            [b, msg] = did.test.db_queries('Do_OR_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoNotBluh(testCase)
            [b, msg] = did.test.db_queries('Do_NOT_BLUH_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoContainsString(testCase)
            [b, msg] = did.test.db_queries('Do_CONTAINS_STRING_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoContainsStringWithParam1(testCase)
            [b, msg] = did.test.db_queries('Do_CONTAINS_STRING_test', 1, 'param1_contains_string', 'bc');
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoContainsStringWithParam2(testCase)
            [b, msg] = did.test.db_queries('Do_CONTAINS_STRING_test', 1, 'param1_contains_string', '_c');
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoNotContainsString(testCase)
            [b, msg] = did.test.db_queries('Do_NOT_CONTAINS_STRING_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoLessThan(testCase)
            [b, msg] = did.test.db_queries('Do_LESSTHAN_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoLessThanEqual(testCase)
            [b, msg] = did.test.db_queries('Do_LESSTHANEQ_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoGreaterThan(testCase)
            [b, msg] = did.test.db_queries('Do_GREATERTHAN_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoGreaterThanEqual(testCase)
            [b, msg] = did.test.db_queries('Do_GREATERTHANEQ_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoHasField(testCase)
            [b, msg] = did.test.db_queries('Do_HASFIELD_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoHasFieldWithParam(testCase)
            [b, msg] = did.test.db_queries('Do_HASFIELD_test', 1, 'fieldname', 'demoA.value');
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoHasMember(testCase)
            [b, msg] = did.test.db_queries('Do_HASMEMBER_test', 1, 'fieldname', 'demoA.value');
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoDependsOn(testCase)
            [b, msg] = did.test.db_queries('Do_DEPENDS_ON_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoIsA(testCase)
            [b, msg] = did.test.db_queries('Do_ISA_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
        function testDoRegExp(testCase)
            [b, msg] = did.test.db_queries('Do_REGEXP_test', 1);
            testCase.verifyEqual(b, true, msg);
        end
        
    end
end
