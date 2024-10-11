function [b,msg] = verify_branch_node_structure(db, dG)
% VERIFY_BRANCH_NODES - verify branch structure in a digraph are in database
% 
% [B, MSG] = VERIFY_BRANCH_NODES_STRUCTURE(DB, DG)
%
% Verify that all of the branch nodes specified in the digraph object DG are
% present in the did.database object DB and have the same graph relationships.
%
% B is 1 if all nodes are present with the right structure and 0 otherwise.
% MSG includes an error message of the first detected erroneous node. 
%

node_names = dG.Nodes{:,1};

b = 1;
msg = '';

current_branch = db.get_branch();

for i=1:numel(node_names),
	% Step 1: check to make sure parents and children match
	s = dG.successors(node_names(i));
	p = dG.predecessors(node_names(i));
	s_ = db.get_branch_parent(node_names{i});
	p_ = db.get_sub_branches(node_names{i});

	if isempty(s_),
		s_ = cell(0,1);
	else,
		s_ = {s_}; % turn it into a cell array, to match s
	end;

	% make sure they are equal
	if ~isempty(setxor(s,s_)),
		b = 0;
		msg = ['Error in parent of ' node_names{i} '.'];
	end;
	if ~isempty(setxor(p,p_)),
		b = 0;
		msg = ['Error in sub_branch of ' node_names{i} '.'];
	end;

	% now try examing the same by setting the current branch
	
	db.set_branch(node_names{i});
	s_ = db.get_branch_parent();
	p_ = db.get_sub_branches();

	if isempty(s_),
		s_ = cell(0,1);
	else,
		s_ = {s_}; % turn it into a cell array, to match s
	end;
	
	if ~isempty(setxor(s,s_)),
		b = 0;
		msg = ['Error in parent of ' node_names{i} '.'];
	end;
	if ~isempty(setxor(p,p_)),
		b = 0;
		msg = ['Error in sub_branch of ' node_names{i} '.'];
	end;

	if b==0, 
		break;
	end;
end;

db.set_branch(current_branch); % return to previous branch


