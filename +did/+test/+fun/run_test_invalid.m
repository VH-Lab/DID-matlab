function [test_results,test_messages] = run_test_invalid()
%RUN_TEST_INVALID runs tests for catching invalid modification to docs
%   Detailed explanation goes here
test_results = [];
test_messages = {};

[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','int2str');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','blank int');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','blank str');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','nan');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','double');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','too negative');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('value_modifier','too positive');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('id_modifier','substring');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('id_modifier','replace_underscore');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('id_modifier','add');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('id_modifier','replace_letter_invalid1');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('id_modifier','replace_letter_invalid2');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('dependency_modifier','invalid id');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('dependency_modifier','invalid name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('dependency_modifier','add dependency');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid definition');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid validation');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid class name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid property list name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','new class version number');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','class version string');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid superclass definition');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid session id');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid base name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('other_modifier','invalid datestamp');
test_results(end+1) = b;
test_messages{end+1} = msg;

[b,msg] = did.test.test_did_db_documents_invalid('remover','document_properties');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','base');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','session_id');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','id');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','datestamp');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','demoA');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','demoB');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','demoC');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','depends_on');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','depends_on.name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','depends_on.value');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','item1');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','item2');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','item3');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','value');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','document_class');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','definition');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','validation');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','class_name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','property_list_name');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','class_version');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','superclasses');
test_results(end+1) = b;
test_messages{end+1} = msg;
[b,msg] = did.test.test_did_db_documents_invalid('remover','superclasses.definition');
test_results(end+1) = b;
test_messages{end+1} = msg;

end

