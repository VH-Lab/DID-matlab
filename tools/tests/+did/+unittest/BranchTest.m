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
            [G, testCase.node_names] = did.test.fun.make_tree(1, 4, 0.8, 10);
            testCase.dG = digraph(G, testCase.node_names);
            testCase.root_indexes = find(cellfun(@(x) ~any(x == '_'), testCase.node_names));
        end
    end
    
    methods (Test)
        function testAddBranchNodes(testCase)
            % Step 3: Add the tree to the database as a set of branches
            disp(['Adding ' int2str(numel(testCase.node_names)) ' random branches...']);
            did.test.branch.add_branch_nodes(testCase.db, '', testCase.dG, testCase.root_indexes);
        end
        
        function testVerifyBranchNodes(testCase)
            % Step 4a: Verify we have all the branches
            disp('Verifying branches...');
            [b, missing] = did.test.branch.verify_branch_nodes(testCase.db, testCase.dG);
            b=logical(b);
            testCase.verifyTrue(b, 'Some branches are missing.');
            if ~b
                disp(missing);
            end
        end
        
        function testVerifyBranchRelationships(testCase)
            % Step 4b: Verify the branch relationships
            disp('Verifying branch relationships...');
            [b, msg] = did.test.branch.verify_branch_node_structure(testCase.db, testCase.dG);
            b=logical(b);
            testCase.verifyTrue(b, msg);
        end
        
        function testRandomBranchDeletions(testCase)
            % Step 5: Randomly delete some branches and re-verify
            num_random_deletions = min(35, numel(testCase.node_names));
            disp(['Verifying branch relationships after ' int2str(num_random_deletions) ' random deletions...']);
            
            for j = 1:num_random_deletions
                testCase.dG = did.test.branch.delete_random_branch(testCase.db, testCase.dG);
            end
            
            % Step 6: Re-examine the integrity of branches
            [b, msg] = did.test.branch.verify_branch_node_structure(testCase.db, testCase.dG);
            b=logical(b);
            testCase.verifyTrue(b, ['After random deletions: ' msg]);
        end
    end
end
