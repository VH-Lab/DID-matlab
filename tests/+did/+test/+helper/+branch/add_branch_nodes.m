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
    % DG must have a single root. A forest with several roots is refused with
    % DID:Test:MultiRootTree rather than built incorrectly - see issue #165.
    %
    % See also: did.test.helper.utility.make_tree, did.test.helper.branch
    %

    if nargin<4
        % NARGIN<3 here previously, but node_start_index is the FOURTH input,
        % so a 3-argument call fell through to an undefined variable instead
        % of defaulting. Every caller passes four, which is why it never
        % showed.
        node_start_index = 0;
    end

    if isscalar(node_start_index) && node_start_index == 0 % find the roots
        % FIND, not the bare logical mask: the loop below indexes
        % dG.Nodes{node_start_index(i),1}, and a logical mask would make that
        % dG.Nodes{0,1} for every non-root. Dead code until now, since every
        % caller passes explicit indices.
        node_start_index = find(cellfun(@(x) ~any(x=='_'), dG.Nodes{:,1}));
    end

    % A forest with more than one root cannot be built through the database
    % API, and building it silently wrong is worse than refusing (issue #165).
    % An empty STARTING_DB_BRANCH_ID leaves the current branch alone, and
    % add_branch reads an empty parent as "the current branch" -- so the first
    % root is genuinely a root, and every root after it becomes a child of
    % whatever was added last. There is no way to avoid that here: set_branch
    % validates its argument and rejects '', so did.database cannot clear the
    % current branch, and therefore cannot create a second root at all.
    if isempty(starting_db_branch_id) && numel(node_start_index) > 1
        error('DID:Test:MultiRootTree', ...
            ['Cannot add a %d-root forest: did.database has no way to create ' ...
             'a second root branch, because set_branch cannot clear the ' ...
             'current branch. Build the tree with make_tree(1,...) so it has ' ...
             'a single root. See issue #165.'], numel(node_start_index));
    end

    for i=1:numel(node_start_index)
        node_here = dG.Nodes{node_start_index(i),1};
        % drop out of cell, should be a 1x1 cell
        node_here = node_here{1,1};
        if ~isempty(starting_db_branch_id)
            % if empty, assume we are at the beginning with no parent branch
            db.set_branch(starting_db_branch_id);
        end
        %disp(['Adding branch ' node_here ' to parent ' starting_db_branch_id '.']);
        db.add_branch(node_here);
        pre_ID = dG.predecessors(node_here);
        pre_ID_indexes = find(ismember(dG.Nodes{:,1},pre_ID));
        if ~isempty(pre_ID_indexes)
            % call recursively
            did.test.helper.branch.add_branch_nodes(db,node_here,dG,pre_ID_indexes);
        end
    end
