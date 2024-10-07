function [b,msg] = branches(varargin)
% did.test.branches - test the branching functionality of a DID database
%
% [B,MSG] = did.test.branches()
% 
% Tests the branching functions of the did.database class, using the
% did.implementations.sqlitedb class.
%  
% This function saves its files in the DID test path.
% 
% This function first tries to delete a file 'test2.sqlite', and then
% makes a new database with the same filename.
%
% B is 1 if the test succeeds, and 0 otherwise.
% MSG has an error message if the test fails.
%

b = 1;
msg = '';

% Step 1: make an empty database with a starting branch
did.globals;
dirname = did.common.PathConstants.testpath;
db_filename = [dirname filesep 'test2.sqlite'];
if isfile(db_filename), 
	delete(db_filename);
end;
db = did.implementations.sqlitedb(db_filename); 

% Step 2: generate a tree and a set of node names

[G,node_names] = did.test.fun.make_tree(1, 4, 0.8, 10);
dG = digraph(G,node_names);
root_indexes = find(cellfun(@(x) ~any(x=='_'), node_names)); % find the root nodes

% Step 3: add the tree to the database as a set of branches
	
disp(['Adding ' int2str(numel(node_names)) ' random branches...']);
did.test.branch.add_branch_nodes(db, '', dG, root_indexes);

% Step 4: verify that the branch order is right
% Step 4a: let's start by verifying we have all the branches

disp(['Verifying branches...']);
[b,missing] = did.test.branch.verify_branch_nodes(db,dG);

if ~b,
	missing,
	error(['We are missing the branches listed above.']);
end;

% Step 4b: now look at all the relationships

disp(['Verifying branch relationships...']);
[b,msg] = did.test.branch.verify_branch_node_structure(db,dG);
if ~b,
	msg = msg;
	return;
end;
	
% Step 5: pick a branch at random to delete

num_random_deletions = min(35,numel(node_names));
disp(['Verifying branch relationships after ' ...
	int2str(num_random_deletions) ' random end-point deletions...']);

for j=1:num_random_deletions,
	dG = did.test.branch.delete_random_branch(db,dG);
end;

% Step 6: re-examine integrity of branches 
[b,msg] = did.test.branch.verify_branch_node_structure(db,dG);
if ~b,
	msg = ['After random deletions: ' msg];
end;

