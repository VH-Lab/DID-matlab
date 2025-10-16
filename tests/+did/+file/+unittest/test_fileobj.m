classdef test_fileobj < matlab.unittest.TestCase
    methods (Test)
        function test_constructor(testCase)
            % Test creating a fileobj
            fo = did.file.fileobj();
            testCase.verifyEqual(fo.fid, -1);
            testCase.verifyEqual(fo.permission, 'r');
            testCase.verifyEqual(fo.machineformat, 'n');
            testCase.verifyEqual(fo.fullpathfilename, '');
        end

        function test_custom_file_handler_error(testCase)
            % Test that passing customFileHandler to the constructor throws an error
            my_handler = @(x) disp(['File operation: ' x]);

            testCase.verifyError(@() did.file.fileobj('customFileHandler', my_handler), ...
                'MATLAB:InputParser:UnmatchedParameter', ...
                'The constructor should throw a standard parser error for an unmatched parameter.');
        end
    end
end
