function [b,msg] = documents_branch_simple(varargin)
% did.test.documents_branch_simple - test the branching functionality of a DID database
%
% [B,MSG] = did.test.documents_branch_simple()
% 
% Tests the document and branching functions of the did.database class, using the
% did.implementations.sqlitedb class.
% 
% This function saves its files in the DID test path and uses the filename.
% 'test_db_docs.sqlite' filename.
% 
% B is 1 if the test succeeds, and 0 otherwise.
% MSG has an error message if the test fails.
%



% Step 1: make an empty database with a starting branch
did.globals;
dirname = did_globals.path.testpath;
db_filename = [dirname filesep 'test_db_docs.sqlite'];
if isfile(db_filename),
	delete(db_filename); 
end;
db = did.implementations.sqlitedb(db_filename); 
db.add_branch('a');

% Step 2: generate a set of documents with node names and a graph of the dependencies
[G,node_names,docs] = did.test.documents.make_doc_tree([30 30 30]);

figure;
dG = digraph(G,node_names);
plot(dG,'layout','circle');
title('The dependency relationships among the randomly generated documents.');

db.add_docs(docs);
%for i=1:numel(docs)
%	db.add_doc(docs{i});
%end

% Step 3: now, add a new branch 'a_a'. The documents in the graph should be
% accessible from the new branch 'a_a'.

db.add_branch('a_a');

% Step 4: check the database results
[b,msg] = did.test.documents.verify_db_document_structure(db, G, docs);

db.set_branch('a');
[b,msg] = did.test.documents.verify_db_document_structure(db, G, docs);

% Step 5: now, delete all the documents from branch a_a and check to make
% sure there are still in branch a
db.set_branch('a_a');

docs_to_remove = {};
for i=1:numel(docs),
    docs_to_remove{end+1} = docs{i}.id();
end;

db.remove_docs(docs_to_remove);

db.set_branch('a');
[b,msg] = did.test.documents.verify_db_document_structure(db, G, docs);

