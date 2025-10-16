classdef test_document < matlab.unittest.TestCase
    methods (Test)
        function test_dependency_management(testCase)
            % Create a document with a 'base' type
            doc = did.document('base');

            % Verify 'depends_on' field exists
            testCase.verifyTrue(isfield(doc.document_properties, 'depends_on'), ...
                "The 'depends_on' field should exist for 'base' document type.");

            % Test setting a new dependency value
            doc = doc.set_dependency_value('new_dependency', 'new_value', 'ErrorIfNotFound', false);
            retrieved_value = doc.dependency_value('new_dependency');
            testCase.verifyEqual(retrieved_value, 'new_value', ...
                "Failed to set and retrieve a new dependency value.");

            % Test updating an existing dependency value
            doc = doc.set_dependency_value('new_dependency', 'updated_value');
            retrieved_value = doc.dependency_value('new_dependency');
            testCase.verifyEqual(retrieved_value, 'updated_value', ...
                "Failed to update an existing dependency value.");
        end

        function test_file_management(testCase)
            % Create a document that supports files by including a 'files' field in its definition
            % For simplicity, we'll manually add the 'files' field to a base document
            doc = did.document('base');
            doc.document_properties.files = struct('file_list', {{'file1.txt'}}, 'file_info', []);
            doc = doc.reset_file_info(); % Initialize file_info

            % Add a file and verify it was added
            doc = doc.add_file('file1.txt', '/path/to/file1.txt');
            [isIn, ~, fI_index] = doc.is_in_file_list('file1.txt');
            testCase.verifyTrue(isIn, "File 'file1.txt' should be in the file list.");
            testCase.verifyNotEmpty(fI_index, "File info index should not be empty after adding a file.");

            % Verify the location of the added file
            testCase.verifyEqual(doc.document_properties.files.file_info(fI_index).locations.location, '/path/to/file1.txt', ...
                "The location of the added file is incorrect.");

            % Remove the file and verify it was removed
            doc = doc.remove_file('file1.txt');
            [~, ~, fI_index_after_removal] = doc.is_in_file_list('file1.txt');
            % After removal, searching for the file info should yield an empty index
            testCase.verifyEmpty(fI_index_after_removal, "File info should be empty after removing the file.");
        end
    end
end