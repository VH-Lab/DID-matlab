function [b,msg] = test_did_db_documents_invalid(varargin)
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

% Step 1: make an empty database with a starting branch
db_filename = [pwd filesep 'test_db_docs.sqlite'];
if isfile(db_filename),
	delete(db_filename);
end;
db = did.implementations.sqlitedb(db_filename);
db.add_branch('a');

% Step 2: generate a set of documents with node names and a graph of the dependencies
modifier = 'sham';
did.datastructures.assign(varargin{:});
[G,node_names,docs] = did.test.documents.make_doc_tree_invalid([30 30 30],modifier);

figure;
dG = digraph(G,node_names);
plot(dG,'layout','circle');
title('The dependency relationships among the randomly generated documents.');

try
    db.add_docs(docs);
catch E
    b = 1;
    msg = [E.message newline 'Error due to the following modifier: ' '''' modifier ''''];
    disp(msg);
    return
end
% db.add_docs(docs);
%for i=1:numel(docs)
%	db.add_doc(docs{i});
%end

% Step 3: check the database results
[b,msg] = did.test.documents.verify_db_document_structure(db, G, docs);
