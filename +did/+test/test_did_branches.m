function [b,msg] = test_did_branches(varargin)
% TEST_DID_BRANCHES - test the branching functionality of a DID database
%
% 
%
%

	 % Step 1: make an empty database with a starting branch

	db = did.implementations.sqlitedb('test2.sqlite');

	db.add_branch('TOP_');

	 % Step 2: generate a tree and a set of node names

	[G,node_names] = did.test.fun.make_tree(4, 3, 0.8, 10);
	dG = digraph(G,node_names);
	root_indexes = cellfun(@(x) ~any(x=='_'), node_names); % find the root nodes

	 % Step 3: add the tree to the database as a set of branches

	add_branch_nodes(db, 'TOP_', dG, root_indexes); % this is not tested

	% Step 4: verify that the branch order is right

	% Step 5: pick a branch at random to delete

		branch_index = randi(size(G,1));
		node_to_delete = dG.Nodes{branch_index,1};
		dG = dG.rmnode(node_to_delete);
		db.delete_branch(node_to_delete);

		% verify the branch order is right

end % test_did_branches

function add_branch_nodes(db, starting_db_branch_id, dG, node_start_index)
		% not tested!
	if nargin<3,
		node_start_index = 0;
	end;

	if node_start_index == 0,
		node_start_index = cellfun(@(x) ~any(x=='_'), dG.Nodes{:,1});
	end;

	for i=1:numel(node_start_index)
		node_here = dG.Nodes{node_start_index(i),1};
		db.set_branch(starting_db_branch_id);
		disp(['Adding branch ' node_here ' to parent ' starting_db_branch_id '.']);
		db.add_branch(node_here);
		pre_ID = dG.predecessors(node_here);
		pre_ID_indexes = ismember(dG.Nodes{:,1},pre_ID);
		add_branch_nodes(db, dG.Nodes{node_start_index(i),1}, dG, pre_ID_indexes);
	end;

end % add_branch_nodes
