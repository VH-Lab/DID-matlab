function [test_results,test_messages] = run_db_queries
%TEST_DID_RUN_QUERY_TESTS runs tests using the function 'test_did_db_queries'
%
%   [TEST_RESULTS,TEST_MESSAGES] = TEST_DID_RUN_QUERY_TESTS() 
%
%   returns array of b values: b = 1 if test passes, b = 0 if at least one test fails
%
%   stores output internally in the cell array test_messages: An empty message for each test that passes, 
%   the failure messages from 'test_did_db_queries' for each test that fails
%
%   An exception is thrown if at least one of the tests produces the wrong
%   output
%

test_results = [];
expected_results = [];
test_messages = {};
tests_as_strings = {}; %save the test code that is run as strings to make it easy to craft specified error messages

each_test = 'did.test.db_queries(''Do_EXACT_STRING_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_NOT_EXACT_STRING_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_AND_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_AND_test'',1,''doc_id_ind_for_and'',1,''doc_value_ind_for_and'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_OR_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_NOT_BLUH_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_CONTAINS_STRING_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
% [b,msg] = did.test.db_queries('Do_CONTAINS_STRING_test',1,'param1_contains_string','');
% test_results(end+1) = b;
% test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_CONTAINS_STRING_test'',1,''param1_contains_string'',''bc'');';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_CONTAINS_STRING_test'',1,''param1_contains_string'',''_c'');';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_NOT_CONTAINS_STRING_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_LESSTHAN_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_LESSTHANEQ_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_GREATERTHAN_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_GREATERTHANEQ_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_HASFIELD_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_HASFIELD_test'',1,''fieldname'',''demoA.value'');';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_HASMEMBER_test'',1,''fieldname'',''demoA.value'');';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_DEPENDS_ON_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_ISA_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;
each_test = 'did.test.db_queries(''Do_REGEXP_test'',1);';
tests_as_strings{end+1} = each_test;
[b,msg] = eval(each_test);
test_results(end+1) = b;
expected_results(end+1) = 1; %output should be 1 (query succeeded)
test_messages{end+1} = msg;

%return 0 and an error message detailing which test(s) fail if one of the tests is not producing the correct
%output; otherwise return 1 and an empty error message
if ~eqlen(test_results,expected_results)
%     ME = MException('MyComponent:run_db_queriesTestFailed', ...
%         'At least one of the tests failed unexpectedly');
%     throw(ME)
    try
        test_results = test_results==expected_results; %breaks if test_results and expected_results aren't the same length
    catch exception
        exception.message = 'There is an issue with the expected_results array';
    end
    tests_failed_inds = find(~test_results);
    for i = 1:numel(tests_failed_inds)
        each_fail = tests_failed_inds(i);
        test_messages{each_fail} = ['At least one of the tests failed unexpectedly: ',tests_as_strings{each_fail},newline,test_messages{each_fail}];
    end
end
end

