function [dG_out] = delete_random_branch(db, dG)
    % DELETE_RANDOM_BRANCH - delete a random branch from a database and digraph
    %
    % [DG_OUT, B, MSG] = DELETE_RANDOM_BRANCH(DB, DG)
    %
    % Selects a branch node for deletion from the did.database DB and the
    % digraph object DG, which contains an identical graph structure.
    %
    % A node that has no children is selected at random.
    %
    % DG_OUT is the updated digraph DG.
    %

    node_names = dG.Nodes{:,1};
    G = dG.adjacency(); % get the adjacency matrix

    end_points = find(sum(G,1)==0);

    n = randi(numel(end_points)); % draw an end-point at random

    remove_node = node_names{end_points(n)};
    % p = dG.predecessors(remove_node), % should be empty, only for debugging

    db.delete_branch(remove_node);
    dG_out = dG.rmnode(remove_node);
