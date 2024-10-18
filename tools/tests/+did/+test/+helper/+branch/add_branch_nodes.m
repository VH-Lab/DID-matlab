function add_branch_nodes(db, starting_db_branch_id, dG, node_start_index)
% ADD_BRANCH_NODES - add a tree of nodes to a DID database
%
% ADD_BRANCH_NODES(DB, STARTING_DB_BRANCH_ID, DG, NODE_START_INDEX)
%
% Add a tree of nodes described by a digraph object DG to the did.database
% object DB. DG should be a graph of a tree, such as that returned by
% did.test.helper.utility.make_tree().
%
% STARTING_DB_BRANCH_ID describes the branch in DB that we should add on
% to. If it is empty, then we assume we are adding the first branch.
% NODE_START_INDEX is the index number or numbers of the nodes in
% DG to add to the database.
%
% See also: did.test.helper.utility.make_tree, did.test.helper.branch
% 


if nargin<3,
	node_start_index = 0;
end;

if node_start_index == 0, % find the roots
	node_start_index = cellfun(@(x) ~any(x=='_'), dG.Nodes{:,1});
end;

for i=1:numel(node_start_index)
	node_here = dG.Nodes{node_start_index(i),1};
	% drop out of cell, should be a 1x1 cell
	node_here = node_here{1,1};
	if ~isempty(starting_db_branch_id),
		% if empty, assume we are at the beginning with no parent branch
		db.set_branch(starting_db_branch_id);
	end;
	%disp(['Adding branch ' node_here ' to parent ' starting_db_branch_id '.']);
	db.add_branch(node_here);
	pre_ID = dG.predecessors(node_here);
	pre_ID_indexes = find(ismember(dG.Nodes{:,1},pre_ID));
	if ~isempty(pre_ID_indexes),
		% call recursively
    		did.test.helper.branch.add_branch_nodes(db,node_here,dG,pre_ID_indexes);
	end;
end;


