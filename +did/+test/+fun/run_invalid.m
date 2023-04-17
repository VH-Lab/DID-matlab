function [test_results,test_messages] = run_invalid
%RUN_TEST_INVALID runs tests for catching invalid modification to docs
%   no output is specified because it is called by did.test.suite.run (through the text
%   file did.test.suite.list)
%   within the function, the results and any error messages are stored in
%   the scalar array test_results and the cell array test_messages, respectively
%
%   b = 1 means the document was invalidated, b = 0 means the document was
%   NOT invalidated
%   
%   An exception is thrown if at least one of the tests produces the wrong
%   output
%

test_results_initial = [];
expected_results = [];
test_messages = {};
param1_list = {}; %keep track of params in case of error
param2_list = {};
param1 = 'value_modifier';param2 = 'int2str';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid(param1,param2); 
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'value_modifier';param2 = 'blank int';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid(param1,param2);
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'value_modifier';param2 = 'blank str';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('value_modifier','blank str');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'value_modifier';param2 = 'nan';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('value_modifier','nan');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'value_modifier';param2 = 'double';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('value_modifier','double');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'value_modifier';param2 = 'too negative';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('value_modifier','too negative');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'value_modifier';param2 = 'too positive';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('value_modifier','too positive');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'id_modifier';param2 = 'substring';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('id_modifier','substring');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'id_modifier';param2 = 'replace_underscore';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('id_modifier','replace_underscore');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'id_modifier';param2 = 'add';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('id_modifier','add');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'id_modifier';param2 = 'replace_letter_invalid1';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('id_modifier','replace_letter_invalid1');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'id_modifier';param2 = 'replace_letter_invalid2';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('id_modifier','replace_letter_invalid2');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'dependency_modifier';param2 = 'invalid id';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('dependency_modifier','invalid id');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'dependency_modifier';param2 = 'invalid name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('dependency_modifier','invalid name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
%%%% ADD HERE and below


param1 = 'dependency_modifier';param2 = 'add dependency';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('dependency_modifier','add dependency');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'dependency_modifier';param2 = 'invalid definition';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid definition');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'dependency_modifier';param2 = 'invalid validation';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid validation');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'invalid class name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid class name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'invalid property list name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid property list name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'new class version number';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','new class version number');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'class version string';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','class version string');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'invalid superclass definition';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid superclass definition');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'invalid sesion id';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid session id');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'invalid base name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid base name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'other_modifier';param2 = 'invalid datestamp';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid datestamp');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'document_properties';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','document_properties');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'base';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','base');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'session_id';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','session_id');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'id';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','id');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'datestamp';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','datestamp');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'demoA';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','demoA');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'demoB';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','demoB');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'demoC';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','demoC');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'depends_on';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','depends_on');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'depends_on.name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','depends_on.name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'depends_on.value';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','depends_on.value');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'item1';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','item1');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'item2';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','item2');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'item3';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','item3');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'value';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','value');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'document_class';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','document_class');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'definition';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','definition');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'validation';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','validation');
test_results_initial(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'class_name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','class_name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'property_list_name';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','property_list_name');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'class_version';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','class_version');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'superclass';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','superclasses');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
param1 = 'remover';param2 = 'superclasses.definition';
param1_list{end+1} = param1;param2_list{end+1}=param2;
[b,msg] = did.test.db_documents_invalid('remover','superclasses.definition');
test_results_initial(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;

%return 0 and a message detailing which test(s) fail if one of the tests is not producing the correct
%output; otherwise return 1 and the message from running the test
%expected_results = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1];
test_results = test_results_initial==expected_results; %will break if test_results and expected_results aren't the same length
if ~eqlen(test_results_initial,expected_results)
    failed_test_inds = find(~test_results); %get indices of failed tests to add to their test message
    for i = 1:numel(failed_test_inds)
        %put original message in the back (so as to not bury the lede)
        each_fail = failed_test_inds(i);
        test_messages{each_fail} = ['At least one of the tests failed unexpectedly: did.test.db_documents_invalid(''',param1_list{each_fail},''',''',param2_list{each_fail},''')',newline,test_messages{each_fail}];
    end
end

end

