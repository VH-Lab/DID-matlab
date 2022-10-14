function [b,msg] = test_did_db_documents_add_remove_branch(varargin)
% TEST_DID_BRANCHES - test the branching functionality of a DID database
%
% [B,MSG] = TEST_DID_DB_DOCUMENTS()
% 
% Tests the document adding functions of the did.database class, using the
% did.implementations.sqlitedb class.
%  
% This function first tries to delete a file 'test_db_docs_and_branch.sqlite', and then
% makes a new database with the same filename.

% Step 1: make an empty database with a starting branch
delete test_db_docs_and_branch.sqlite
db = did.implementations.sqlitedb('test_db_docs_and_branch.sqlite');

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


