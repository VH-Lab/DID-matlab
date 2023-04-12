function run_invalid
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

test_results = [];
expected_results = [];
test_messages = {};

[b,msg] = did.test.db_documents_invalid('value_modifier','int2str'); 
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('value_modifier','blank int');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('value_modifier','blank str');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('value_modifier','nan');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('value_modifier','double');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('value_modifier','too negative');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('value_modifier','too positive');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('id_modifier','substring');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('id_modifier','replace_underscore');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('id_modifier','add');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('id_modifier','replace_letter_invalid1');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('id_modifier','replace_letter_invalid2');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('dependency_modifier','invalid id');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('dependency_modifier','invalid name');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('dependency_modifier','add dependency');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid definition');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid validation');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid class name');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid property list name');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','new class version number');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','class version string');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid superclass definition');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid session id');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid base name');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('other_modifier','invalid datestamp');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;

[b,msg] = did.test.db_documents_invalid('remover','document_properties');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','base');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','session_id');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','id');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','name');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','datestamp');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','demoA');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','demoB');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','demoC');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','depends_on');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','depends_on.name');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','depends_on.value');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','item1');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','item2');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','item3');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','value');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','document_class');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','definition');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','validation');
test_results(end+1) = b; 
expected_results(end+1) = 0; %output should be 0 (validated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','class_name');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','property_list_name');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','class_version');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','superclasses');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;
[b,msg] = did.test.db_documents_invalid('remover','superclasses.definition');
test_results(end+1) = b; 
expected_results(end+1) = 1; %output should be 1 (invalidated)
test_messages{end+1} = msg;

%throw an exception if one of the tests is not producing the correct
%output:
%expected_results = [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,0,0,0,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1];
if ~eqlen(test_results,expected_results)
    ME = MException('MyComponent:run_invalidTestFailed', ...
        'At least one of the tests failed unexpectedly');
    throw(ME)
end

end

