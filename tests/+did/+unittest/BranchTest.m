
classdef BranchTest < matlab.unittest.TestCase
    % Test the branching functionality of the DID database

    properties (Constant)
        db_filename = 'test2.sqlite' % Holds the path to the SQLite database
    end

    properties
        db            % Holds the database object
        dG            % Holds the digraph object
        node_names    % Holds the node names
        root_indexes  % Holds the indexes of root nodes
    end

    methods (TestClassSetup)
        function setupClass(testCase)

            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            % Create an empty database with a starting branch
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);

            testCase.generateTree()
        end
    end

    methods
        function generateTree(testCase)
            % Step 2: Generate a tree and a set of node names
            [G, testCase.node_names] = did.test.helper.utility.make_tree(1, 4, 0.8, 10);
            testCase.dG = digraph(G, testCase.node_names);
            testCase.root_indexes = find(cellfun(@(x) ~any(x == '_'), testCase.node_names));
        end
    end

    methods (Test)
        function testAddBranchNodes(testCase)
            % Step 3: Add the tree to the database as a set of branches
            disp(['Adding ' int2str(numel(testCase.node_names)) ' random branches...']);
            did.test.helper.branch.add_branch_nodes(testCase.db, '', testCase.dG, testCase.root_indexes);
        end

        function testVerifyBranchNodes(testCase)
            % Step 4a: Verify we have all the branches
            disp('Verifying branches...');
            [b, missing] = did.test.helper.branch.verify_branch_nodes(testCase.db, testCase.dG);
            b=logical(b);
            testCase.verifyTrue(b, 'Some branches are missing.');
            if ~b
                disp(missing);
            end
        end

        function testVerifyBranchRelationships(testCase)
            % Step 4b: Verify the branch relationships
            disp('Verifying branch relationships...');
            [b, msg] = did.test.helper.branch.verify_branch_node_structure(testCase.db, testCase.dG);
            b=logical(b);
            testCase.verifyTrue(b, msg);
        end

        function testMultiRootForestIsRefused(testCase)
            % Regression for issue #165. add_branch_nodes used to build a
            % multi-root forest silently wrong: an empty starting branch id
            % leaves the current branch alone, and add_branch reads an empty
            % parent as "the current branch", so the first root was a root and
            % every root after it became a child of whatever was added last.
            % verify_branch_node_structure would have caught the result, but
            % BranchTest builds make_tree(1,...) -- a single root -- so the
            % path was never taken.
            %
            % It cannot be built correctly either: set_branch validates its
            % argument and rejects '', so did.database has no way to clear the
            % current branch and therefore no way to make a second root. The
            % helper must refuse rather than mislead.
            %
            % This runs against its OWN database. testCase.db is built once in
            % TestClassSetup and shared by every test in this class, so the
            % branch added below would surface as an unexpected sub-branch in
            % testRandomBranchDeletions. A fresh database also has no current
            % branch, which is what makes the single-root case below add a
            % genuine root rather than a child.
            scratch_db = did.implementations.sqlitedb('test_multiroot.sqlite');

            two_roots = digraph(sparse(zeros(2)), {'a','b'});

            testCase.verifyError(...
                @() did.test.helper.branch.add_branch_nodes(scratch_db, '', two_roots, [1 2]), ...
                'DID:Test:MultiRootTree');

            % A single root is still added normally, and is genuinely a root
            one_root = digraph(sparse(zeros(1)), {'solo'});
            did.test.helper.branch.add_branch_nodes(scratch_db, '', one_root, 1);
            testCase.verifyTrue(ismember('solo', scratch_db.all_branch_ids()));
            testCase.verifyEmpty(scratch_db.get_branch_parent('solo'));
        end

        function testRandomBranchDeletions(testCase)
            % Step 5: Randomly delete some branches and re-verify
            num_random_deletions = min(35, numel(testCase.node_names));
            disp(['Verifying branch relationships after ' int2str(num_random_deletions) ' random deletions...']);

            for j = 1:num_random_deletions
                testCase.dG = did.test.helper.branch.delete_random_branch(testCase.db, testCase.dG);
            end

            % Step 6: Re-examine the integrity of branches
            [b, msg] = did.test.helper.branch.verify_branch_node_structure(testCase.db, testCase.dG);
            b=logical(b);
            testCase.verifyTrue(b, ['After random deletions: ' msg]);
        end
    end
end
