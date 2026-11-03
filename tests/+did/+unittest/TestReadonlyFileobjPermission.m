classdef TestReadonlyFileobjPermission < matlab.unittest.TestCase
    % TESTREADONLYFILEOBJPERMISSION - did.file.readonly_fileobj accepts the
    % read-only permissions 'r' and 'rb' and refuses any write or append.
    %
    % Regression test for VH-Lab/DID-matlab#220: vhlab-toolbox's
    % vhsb_readheader reopens the file object it is given with
    % fopen(fo,'r','ieee-le'), which readonly_fileobj refused, so NDI's
    % readtimeseries on a .vhsb file failed.

    properties
        FileName
    end

    methods (TestMethodSetup)
        function makeFile(testCase)
            testCase.FileName = [tempname '.bin'];
            fid = fopen(testCase.FileName, 'w', 'ieee-le');
            fwrite(fid, uint8(1:10), 'uint8');
            fclose(fid);
            testCase.addTeardown(@() delete(testCase.FileName));
        end
    end

    methods (Test)
        function testROpensAndReads(testCase)
            fo = did.file.readonly_fileobj('fullpathfilename', testCase.FileName);
            fo = fopen(fo, 'r', 'ieee-le');   % as vhsb_readheader calls it
            testCase.addTeardown(@() fclose(fo));
            testCase.verifyGreaterThan(fo.fid, 0, '''r'' did not open the file.');
            data = fread(fo, 10, 'uint8');
            testCase.verifyEqual(data(:)', 1:10);
        end

        function testRbOpensAndReads(testCase)
            fo = did.file.readonly_fileobj('fullpathfilename', testCase.FileName);
            fo = fopen(fo, 'rb');
            testCase.addTeardown(@() fclose(fo));
            testCase.verifyGreaterThan(fo.fid, 0);
            data = fread(fo, 10, 'uint8');
            testCase.verifyEqual(data(:)', 1:10);
        end

        function testOpensInBinaryMode(testCase)
            % 'r' is opened as 'rb': the stored permission stays binary.
            fo = did.file.readonly_fileobj('fullpathfilename', testCase.FileName);
            fo = fopen(fo, 'r');
            testCase.addTeardown(@() fclose(fo));
            testCase.verifyEqual(char(fo.permission), 'rb');
        end

        function testWriteAndAppendRefused(testCase)
            fo = did.file.readonly_fileobj('fullpathfilename', testCase.FileName);
            for p = {'w', 'wb', 'r+', 'rb+', 'r+b', 'a', 'ab', 'a+', 'w+', 'W', 'A'}
                testCase.verifyError(@() fopen(fo, p{1}), ...
                    'DID:File:ReadOnly_Fileobj', ...
                    sprintf('Permission ''%s'' was not refused.', p{1}));
            end
            % and the file is unchanged
            fid = fopen(testCase.FileName, 'r');
            data = fread(fid, Inf, 'uint8');
            fclose(fid);
            testCase.verifyEqual(data(:)', 1:10);
        end

        function testConstructorRefusesWrite(testCase)
            for p = {'w', 'r+', 'a'}
                testCase.verifyError(@() did.file.readonly_fileobj( ...
                    'fullpathfilename', testCase.FileName, 'permission', p{1}), ...
                    'DID:File:ReadOnly_Fileobj', ...
                    sprintf('Constructor permission ''%s'' was not refused.', p{1}));
            end
        end
    end
end
