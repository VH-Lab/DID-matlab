classdef TestModification < matlab.unittest.TestCase
    % TestValidModification
    % Test case for making modifications to documents

    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
        plot_document_dependencies = getpref('didtools', 'plot_document_dependencies', true)
    end

    properties
        db
    end

    properties (Abstract, TestParameter)
        value_modifier
        dependency_modifier
        id_modifier
        other_modifier
        remover
    end

    methods (Abstract)
        doVerification(testCase, b)

        %addDocumentsToDatabase(testCase, docs)
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            % Step 1: make an empty database with a starting branch
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
        end
    end

    methods
        function b = createModifiedDocuments(testCase, options)
            arguments
                testCase
                options.value_modifier = 'sham';
                options.id_modifier = 'sham';
                options.dependency_modifier = 'sham'; % primarily for demoC
                options.other_modifier = 'sham';
                options.remover = 'sham';
            end

            [G, node_names, docs] = did.test.helper.documents.make_doc_tree_invalid([10 10 10],...
                'value_modifier', options.value_modifier,...
                'id_modifier', options.id_modifier,...
                'dependency_modifier', options.dependency_modifier,...
                'other_modifier', options.other_modifier,...
                'remover', options.remover);

            if testCase.plot_document_dependencies
                figure;
                dG = digraph(G,node_names);
                plot(dG,'layout','circle');
                title('The dependency relationships among the randomly generated documents.');
            end

            b = false;

            try
                testCase.db.add_docs(docs);
            catch E
                b = true; % caught the invalidation
                testCase.assertSubstring(E.identifier, "DID:Database", "Expected error to be a DID database error")
                if ~startsWith(E.identifier, "DID:Database")
                    getReport(E)
                end
            end

            % [b2,msg2] = did.test.helper.documents.verify_db_document_structure(testCase.db, G, docs);
            % b = b & b2;
            % %msg = [msg newline msg2];

            if ~nargout; clear b; end
        end
    end

    methods (Test)

        function testValueModifier(testCase, value_modifier)
            b = testCase.createModifiedDocuments('value_modifier', value_modifier);
            testCase.doVerification(b);
        end

        function testDependencyModifier(testCase, dependency_modifier)
            b = testCase.createModifiedDocuments('dependency_modifier', dependency_modifier);
            testCase.doVerification(b);
        end

        function testIdModifier(testCase, id_modifier)
            b = testCase.createModifiedDocuments('id_modifier', id_modifier);
            testCase.doVerification(b);
        end

        function testOtherModifier(testCase, other_modifier)
            b = testCase.createModifiedDocuments('other_modifier', other_modifier);
            testCase.doVerification(b);
        end

        function testRemover(testCase, remover)
            b = testCase.createModifiedDocuments('remover', remover);
            testCase.doVerification(b);
        end
    end
end
