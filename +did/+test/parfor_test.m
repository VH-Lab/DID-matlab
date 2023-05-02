function [b,msg] = parfor_test(varargin)
% did.test.parfor_test - test the ability of did.database class to handle parallel processing
%
% [B,MSG] = did.test.parfor_test()
% 
% Tests the ability of DID to allow addition of documents in parallel threads.
%
% This function saves its files in the DID test path and uses the filename.
% 'test_db_docs.sqlite' filename.
%
% B is 1 if the test succeeds, and 0 otherwise.
% MSG has an error message if the test fails.



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
  % make 0 of type C because we don't want dependencies here
[G,node_names,docs] = did.test.documents.make_doc_tree([30 30 0]);

figure;
dG = digraph(G,node_names);
plot(dG,'layout','circle');
title('The dependency relationships among the randomly generated documents.');

parfor i=1:numel(docs),
	db.add_docs(docs{i});
end;

% Step 3: check the database results
[b,msg] = did.test.documents.verify_db_document_structure(db, G, docs);

