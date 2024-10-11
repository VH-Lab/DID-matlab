classdef TestInvalidModification < matlab.unittest.TestCase
    % TestInvalidModification
    % Test case for catching invalid modification to documents
    
    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
        plot_document_dependencies = getpref('didtools', 'plot_document_dependencies', true)
    end

    properties
        db
    end

    properties (TestParameter)
        value_modifier = {'int2str', 'blank int', 'blank str', 'nan', 'double', 'too negative', 'too positive'}
        id_modifier = {'substring', 'replace_underscore', 'add', 'replace_letter_invalid1', 'replace_letter_invalid2'}
        dependency_modifier = {'invalid id', 'invalid name', 'add dependency'}
        other_modifier = {'invalid definition', 'invalid validation', 'invalid class name', 'invalid property list name', 'new class version number', 'class version string', 'invalid superclass definition', 'invalid session id', 'invalid base name', 'invalid datestamp'}
        remover = {'document_properties'}
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
        function b = createInvalidDocuments(testCase, options)
            arguments
                testCase
                options.value_modifier = 'sham';
                options.id_modifier = 'sham';
                options.dependency_modifier = 'sham'; % primarily for demoC
                options.other_modifier = 'sham';
                options.remover = 'sham';
            end

            [G, node_names, docs] = did.test.documents.make_doc_tree_invalid([30 30 30],... 
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
            end

            if ~nargout; clear b; end
        end
    end


    methods (Test)

        function testValueModifier(testCase, value_modifier)
            b = testCase.createInvalidDocuments('value_modifier', value_modifier);
            testCase.verifyTrue(b);
        end

        function testIdModifier(testCase, id_modifier)
            b = testCase.createInvalidDocuments('id_modifier', id_modifier);
            testCase.verifyTrue(b);
        end
        
        function testDependencyModifier(testCase, dependency_modifier)
            b = testCase.createInvalidDocuments('dependency_modifier', dependency_modifier);
            testCase.verifyTrue(b);
        end
        
        function testOtherModifier(testCase, other_modifier)
            b = testCase.createInvalidDocuments('other_modifier', other_modifier);
            testCase.verifyTrue(b);
        end
        
        function testOtherModifierInvalidValidation(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid validation');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidClassName(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid class name');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidPropertyListName(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid property list name');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierNewClassVersionNumber(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'new class version number');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierClassVersionString(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'class version string');
            testCase.verifyEqual(b, 0, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierInvalidSuperclassDefinition(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid superclass definition');
            testCase.verifyEqual(b, 1, msg);
        end
        
        function testOtherModifierInvalidSessionId(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid session id');
            testCase.verifyEqual(b, true, msg);
        end
        
        function testOtherModifierInvalidBaseName(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid base name');
            testCase.verifyEqual(b, false, msg); % expected output is 0 (validated)
        end
        
        function testOtherModifierInvalidDatestamp(testCase)
            [b, msg] = did.test.db_documents_invalid('other_modifier', 'invalid datestamp');
            testCase.verifyEqual(b, true, msg);
        end
        
        function testRemoverDocumentProperties(testCase)
            [b, msg] = did.test.db_documents_invalid('remover', 'document_properties');
            testCase.verifyEqual(b, true, msg);
        end
        
        % Continue for the remaining tests, following the same structure
        
    end
end
