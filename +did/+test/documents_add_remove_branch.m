function [b,msg] = documents_add_remove_branch(varargin)
% did.test.documents_add_remove_branch - test the branching functionality of a DID database
%
% [B,MSG] = did.test.document_add_remove_branch()
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
db_filename = [dirname filesep 'test_db_docs_and_branch.sqlite'];
if isfile(db_filename), 
	delete(db_filename);
end;
db = did.implementations.sqlitedb(db_filename); 

[branchG,branch_node_names] = did.test.fun.make_tree(1,4,0.8,10);

[doc_struct.G,doc_struct.node_names,doc_struct.docs] = did.test.documents.make_doc_tree([30 30 30]);

[doc_struct_out, branch_node_indexes] = did.test.fun.addrm_docs_to_branches(db,...
	branchG, branch_node_names, doc_struct);

 % now check all branches

save graph_output.mat branchG branch_node_names doc_struct_out branch_node_indexes doc_struct -mat

for i=1:numel(doc_struct_out),
	db.set_branch(branch_node_names{i});
	[b,msg] = did.test.documents.verify_db_document_structure(db,...
		doc_struct_out{i}.G,doc_struct_out{i}.docs);
	if ~b,
		disp(['Failed to validate documents in branch ' branch_node_names{i} '.']);
		return;
	end;
end;


