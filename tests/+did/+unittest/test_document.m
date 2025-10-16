classdef test_document < matlab.unittest.TestCase
    methods (Test)
        function test_dependency_management(testCase)
            % Create a document of type 'demoC', which has 'depends_on' fields
            doc = did.document('demoC');

            % Verify 'depends_on' field exists
            testCase.verifyTrue(isfield(doc.document_properties, 'depends_on'), ...
                "The 'depends_on' field should exist for 'demoC' document type.");

            % Test setting a new dependency value
            doc = doc.set_dependency_value('item1', 'new_value');
            retrieved_value = doc.dependency_value('item1');
            testCase.verifyEqual(retrieved_value, 'new_value', ...
                "Failed to set and retrieve a new dependency value.");

            % Test updating an existing dependency value
            doc = doc.set_dependency_value('item1', 'updated_value');
            retrieved_value = doc.dependency_value('item1');
            testCase.verifyEqual(retrieved_value, 'updated_value', ...
                "Failed to update an existing dependency value.");
        end

        function test_file_management(testCase)
            % Create a document of type 'demoFile', which is defined to handle files
            doc = did.document('demoFile');

            % Add a file and verify it was added
            doc = doc.add_file('filename1.ext', '/path/to/file1.txt');
            [isIn, ~, fI_index] = doc.is_in_file_list('filename1.ext');
            testCase.verifyTrue(isIn, "File 'filename1.ext' should be in the file list.");
            testCase.verifyNotEmpty(fI_index, "File info index should not be empty after adding a file.");

            % Verify the location of the added file
            testCase.verifyEqual(doc.document_properties.files.file_info(fI_index).locations.location, '/path/to/file1.txt', ...
                "The location of the added file is incorrect.");

            % Remove the file and verify it was removed
            doc = doc.remove_file('filename1.ext');
            [~, ~, fI_index_after_removal] = doc.is_in_file_list('filename1.ext');
            % After removal, searching for the file info should yield an empty index
            testCase.verifyEmpty(fI_index_after_removal, "File info should be empty after removing the file.");
        end
    end
end