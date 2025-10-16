classdef test_fileobj < matlab.unittest.TestCase
    methods (Test)
        function test_constructor(testCase)
            % Test creating a fileobj
            theFileObj = did.file.fileobj();
            testCase.verifyEqual(theFileObj.fid, -1);
            testCase.verifyEqual(theFileObj.permission, 'r');
            testCase.verifyEqual(theFileObj.machineformat, 'n');
            testCase.verifyEqual(theFileObj.fullpathfilename, '');
        end

        function test_custom_file_handler_error(testCase)
            % Test that passing customFileHandler to the constructor throws an error
            my_handler = @(x) disp(['File operation: ' x]);

            testCase.verifyError(@() did.file.fileobj('customFileHandler', my_handler), ...
                'MATLAB:TooManyInputs', ...
                'The constructor should throw a standard parser error for an unmatched parameter.');
        end
    end
end
