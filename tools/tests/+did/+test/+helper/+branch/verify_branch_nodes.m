function [b,missing] = verify_branch_nodes(db, dG)
% VERIFY_BRANCH_NODES - verify all branch nodes in a digraph are in database
% 
% [B, MISSING] = VERIFY_BRANCH_NODES(DB, DG)
%
% Verify that all of the branch nodes specified in the digraph object DG are
% present in the did.database object DB.
%
% B is 1 if all nodes are present, and 0 otherwise.  MISSING is a cell array
% of strings with any nodes that are missing in the DB.
%

node_names = dG.Nodes{:,1};

all_branches = db.all_branch_ids();
missing = setdiff(node_names, all_branches);
b = 1;
if ~isempty(missing),
    b = 0;
end;

