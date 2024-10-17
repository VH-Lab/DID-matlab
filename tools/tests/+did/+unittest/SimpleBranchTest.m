classdef SimpleBranchTest < matlab.unittest.TestCase
    % Test the branching functionality of the DID database
    
    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
    end

    properties
        db            % Holds the database object
        G            % Holds the digraph object
        docs
        node_names    % Holds the node names
        root_indexes  % Holds the indexes of root nodes
    end
    
    methods (TestClassSetup)
        function setupClass(testCase)

            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            % Create an empty database with a starting branch
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');

            testCase.generateTree()
        end
    end

    methods
        function generateTree(testCase)
            % Step 2: generate a set of documents with node names and a graph of the dependencies
            [testCase.G, testCase.node_names, testCase.docs] = ...
                did.test.documents.make_doc_tree([10 10 10]);
            
            figure;
            dG = digraph(testCase.G, testCase.node_names);
            plot(dG,'layout','circle');
            title('The dependency relationships among the randomly generated documents.');
            
            testCase.db.add_docs(testCase.docs);
        end
    end
    
    methods (Test)
        function testAddBranchNodes(testCase)
            % Step 3: now, add a new branch 'a_a'. The documents in the graph should be
            % accessible from the new branch 'a_a'.
            testCase.db.add_branch('a_a');
            
            % Step 4: check the database results
            [b,msg] = did.test.documents.verify_db_document_structure(testCase.db, testCase.G, testCase.docs);
            
            testCase.db.set_branch('a');
            [b,msg] = did.test.documents.verify_db_document_structure(testCase.db, testCase.G, testCase.docs);
        end
        
        function testRemoveDocumentsFromBranchAndVerifyOtherBranch(testCase)
            
            % Step 5: now, delete all the documents from branch a_a and check to make
            % sure there are still in branch a
            testCase.db.set_branch('a_a');
            
            docs_to_remove = {};
            for i=1:numel(testCase.docs)
                docs_to_remove{end+1} = testCase.docs{i}.id(); %#ok<AGROW>
            end
            
            testCase.db.remove_docs(docs_to_remove);
            
            testCase.db.set_branch('a');
            [b, msg] = did.test.documents.verify_db_document_structure(testCase.db, testCase.G, testCase.docs);
        end

    end
end
