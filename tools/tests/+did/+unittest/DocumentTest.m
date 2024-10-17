classdef DocumentTest < matlab.unittest.TestCase
% Test the document adding functions of the did.database class

    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
    end

    properties
        db            % Holds the database object
        dG            % Holds the digraph object
        node_names    % Holds the node names
        root_indexes  % Holds the indexes of root nodes
    end
    
    methods (TestMethodSetup)
        function setupMethod(testCase)

            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            testCase.applyFixture(did.test.fixture.PathConstantFixture)

            % Step 1: Create an empty database with a starting branch
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
        end
    end
    
    methods (Test)
        function testAddDocuments(testCase)
            % Generate a set of documents with node names and a graph of the dependencies
            [G,node_names,docs] = did.test.documents.make_doc_tree([30 30 30]);
            
            figure;
            testCase.dG = digraph(G,node_names);
            plot(testCase.dG,'layout','circle');
            title('The dependency relationships among the randomly generated documents.');
            
            testCase.db.add_docs(docs);

            % Step 3: check the database results
            [b, msg] = did.test.documents.verify_db_document_structure(testCase.db, G, docs);

            b = logical(b);
            testCase.verifyTrue(b, msg);
        end
    
        function testRemoveDocuments(testCase)
            % Step 2: generate a set of documents with node names and a graph of the dependencies
            [G{1},node_names{1},docs{1}] = did.test.documents.make_doc_tree([30 30 30]);
            
            figure;
            dG = digraph(G{1},node_names{1});
            plot(dG,'layout','circle');
            title('The dependency relationships among the randomly generated documents.');
            
            testCase.db.add_docs(docs{1});
            %for i=1:numel(docs{1})
            %	db.add_doc(docs{1}{i});
            %end
            
            % Step 3: check the database results
            [b, msg] = did.test.documents.verify_db_document_structure(testCase.db, G{1}, docs{1});
            b = logical(b);
            testCase.verifyTrue(b, msg);

            for i=[2:2:10],
            
	            disp('will now delete some documents/nodes and check.');
            
	            [docs_to_delete,docs_to_delete_seed,G{i},node_names{i},docs{i}] = ...
		            did.test.documents.rm_doc_tree(2, G{i-1},node_names{i-1},docs{i-1});
            
	            if ~isempty(docs_to_delete_seed),
		            testCase.db.remove_docs(docs_to_delete_seed);
	            end;
	            
	            [b,msg] = did.test.documents.verify_db_document_structure(testCase.db, G{i}, docs{i});
	            b = logical(b);
                testCase.verifyTrue(b, msg);
            
	            disp('will now add some documents/nodes and check.');
            
	            N = numel(docs{i});
	            [G{i+1},node_names{i+1},docs{i+1}] = did.test.documents.add_doc_tree([5 5 5],...
		            G{i},node_names{i},docs{i});
	            testCase.db.add_docs(docs{i+1}(N+1:numel(docs{i+1})));
            
	            [b,msg] = did.test.documents.verify_db_document_structure(testCase.db, G{i+1}, docs{i+1});
	            
                b = logical(b);
                testCase.verifyTrue(b, msg);
            end
        end
    end
end
