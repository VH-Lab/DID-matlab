function run_db_queries
%TEST_DID_RUN_QUERY_TESTS runs tests using the function 'test_did_db_queries'
%
%   [TEST_RESULTS,TEST_MESSAGES] = TEST_DID_RUN_QUERY_TESTS() 
%
%   returns array of b values: b = 1 if test passes, b = 0 if at least one test fails
%
%   stores output internally in the cell array test_messages: An empty message for each test that passes, 
%   the failure messages from 'test_did_db_queries' for each test that fails

test_results = [];
test_messages = {};

[b,msg] = did.test.db_queries('Do_EXACT_STRING_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_NOT_EXACT_STRING_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_AND_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_AND_test',1,'doc_id_ind_for_and',1,'doc_value_ind_for_and',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_OR_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_NOT_BLUH_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_CONTAINS_STRING_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
% [b,msg] = did.test.db_queries('Do_CONTAINS_STRING_test',1,'param1_contains_string','');
% test_results(end+1) = b;
% test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_CONTAINS_STRING_test',1,'param1_contains_string','bc');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_CONTAINS_STRING_test',1,'param1_contains_string','_c');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_NOT_CONTAINS_STRING_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_LESSTHAN_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_LESSTHANEQ_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_GREATERTHAN_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_GREATERTHANEQ_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_HASFIELD_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_HASFIELD_test',1,'fieldname','demoA.value');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_HASMEMBER_test',1,'fieldname','demoA.value');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_DEPENDS_ON_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;

[b,msg] = did.test.db_queries('Do_ISA_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.db_queries('Do_REGEXP_test',1);
test_results(end+1) = b;
test_messages{end+1} = msg;
end

