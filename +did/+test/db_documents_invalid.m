function [b,msg] = db_documents_invalid(options)
% TEST_DID_BRANCHES - test the branching functionality of a DID database
%
% [B,MSG] = TEST_DID_DB_DOCUMENTS()
% 
% Tests the document adding functions of the did.database class, using the
% did.implementations.sqlitedb class.
%  
% This function first tries to delete a file 'test_db_docs.sqlite'
% in the current directory, and then makes a new database with the same
% filename.
%
% This version takes name/value pairs that may make changes that are invalid 
% to the schema:
% -----------------------------------------------------------------------------------------------------
% | Parameter (default)                        | Description                                          |
% |--------------------------------------------|------------------------------------------------------|
% | value_modifier ('sham')                    | How should we modify the value field?                |
% | id_modifier ('sham')                       | How should we modify the id field?                   |
% | dependency_modifier ('sham')               | How should we modify the doc dependencies?           |
% | other_modifier ('sham')                    | How should we modify other fields?                   |
% | remover ('sham')                           | Which field should we remove?                        |
% |--------------------------------------------|------------------------------------------------------|

arguments
    options.value_modifier = 'sham';
    options.id_modifier = 'sham';
    options.dependency_modifier = 'sham'; % primarily for demoC
    options.other_modifier = 'sham';
    options.remover = 'sham'; 
end


% Step 1: make an empty database with a starting branch
db_filename = [pwd filesep 'test_db_docs.sqlite'];
if isfile(db_filename),
	delete(db_filename);
end;
db = did.implementations.sqlitedb(db_filename);
db.add_branch('a');

% Step 2: generate a set of documents with node names and a graph of the dependencies
value_modifier = options.value_modifier;
id_modifier = options.id_modifier;
dependency_modifier = options.dependency_modifier; % primarily for demoC
other_modifier = options.other_modifier;
remover = options.remover; 

[G,node_names,docs] = did.test.documents.make_doc_tree_invalid([30 30 30],... 
    'value_modifier',value_modifier,... %add assign varargin to make_doc_tree_invalid
    'id_modifier',id_modifier,...
    'dependency_modifier', dependency_modifier,...
    'other_modifier', other_modifier,...
    'remover',remover);

figure;
dG = digraph(G,node_names);
plot(dG,'layout','circle');
title('The dependency relationships among the randomly generated documents.');

b=0;
msg = '';
try
    db.add_docs(docs);
catch E
    b = 1; %caught the invalidation
    msg = [E.message newline 'Error due to one of the following modifiers: '...
        newline 'value_modifier:' '''' value_modifier ''''...
        newline 'id_modifier:' '''' id_modifier ''''...
        newline 'dependency_modifier:' '''' dependency_modifier ''''...
        newline 'other_modifier:' '''' other_modifier ''''...
        newline 'remover:' '''' remover ''''];
    disp(msg);
    return
end
%db.add_docs(docs);
% for i=1:numel(docs)
% 	db.add_doc(docs{i});
% end

% Step 3: check the database results
[b2,msg2] = did.test.documents.verify_db_document_structure(db, G, docs);
b = b & b2;
msg = [msg newline msg2];