classdef DocumentAndBranchTest < matlab.unittest.TestCase
    % test the branching functionality of a DID database
    
    properties (Constant)
        db_filename = 'test_db_docs_and_branch.sqlite' % Holds the path to the SQLite database
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
            [branchG,branch_node_names] = did.test.helper.utility.make_tree(1,3,0.8,5);
            
            [doc_struct.G,doc_struct.node_names,doc_struct.docs] = did.test.helper.documents.make_doc_tree([10 10 10]);
            
            [doc_struct_out, branch_node_indexes] = did.test.helper.utility.addrm_docs_to_branches( testCase.db,...
	            branchG, branch_node_names, doc_struct);
            
             % now check all branches
            
            %save graph_output.mat branchG branch_node_names doc_struct_out branch_node_indexes doc_struct -mat
            
            for i = 1:numel(doc_struct_out)
	            testCase.db.set_branch(branch_node_names{i});
	            [b,msg] = did.test.helper.documents.verify_db_document_structure(testCase.db,...
		            doc_struct_out{i}.G,doc_struct_out{i}.docs);
                
                b = logical(b);
                testCase.verifyTrue(b, msg);
                if ~b
		            disp(['Failed to validate documents in branch ' branch_node_names{i} '.']);
                end
            end
        end
    end
end
