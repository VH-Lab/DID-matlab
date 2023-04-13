function [b,msg] = documents_add_remove(varargin)
% did.test.documents_add_remove - test the branching functionality of a DID database
%
% [B,MSG] = did.test.documents_add_remove()
% 
% Tests the document adding functions of the did.database class, using the
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
[G{1},node_names{1},docs{1}] = did.test.documents.make_doc_tree([30 30 30]);

figure;
dG = digraph(G{1},node_names{1});
plot(dG,'layout','circle');
title('The dependency relationships among the randomly generated documents.');

db.add_docs(docs{1});
%for i=1:numel(docs{1})
%	db.add_doc(docs{1}{i});
%end

% Step 3: check the database results
[b,msg] = did.test.documents.verify_db_document_structure(db, G{1}, docs{1});

for i=[2:2:10],

	disp('will now delete some documents/nodes and check.');

	[docs_to_delete,docs_to_delete_seed,G{i},node_names{i},docs{i}] = ...
		did.test.documents.rm_doc_tree(2, G{i-1},node_names{i-1},docs{i-1});

	if ~isempty(docs_to_delete_seed),
		db.remove_docs(docs_to_delete_seed);
	end;
	
	[b,msg] = did.test.documents.verify_db_document_structure(db, G{i}, docs{i});

	if ~b,
		return;
	end;

	disp('will now add some documents/nodes and check.');

	N = numel(docs{i});
	[G{i+1},node_names{i+1},docs{i+1}] = did.test.documents.add_doc_tree([5 5 5],...
		G{i},node_names{i},docs{i});
	db.add_docs(docs{i+1}(N+1:numel(docs{i+1})));
	%for n=N+1:numel(docs{i+1}),
	%	db.add_doc(docs{i+1}{n});
	%end;

	[b,msg] = did.test.documents.verify_db_document_structure(db, G{i+1}, docs{i+1});

	if ~b,
		return;
	end;
end;


