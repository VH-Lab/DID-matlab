classdef TestFileCache < matlab.unittest.TestCase
    % TestFileCache
    % Regression test for did.file.fileCache.resizeAndAdd, which corrupted the
    % cache manifest when adding more than one file in a single call: the
    % filename was written to data_here{i} (indexed by the loop counter) instead
    % of data_here{1}, and data_here was never reset between iterations, so from
    % the second file on the wrong name/size were recorded.

    methods (Test)

        function testResizeAndAddMultipleFiles(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            cacheDir = fullfile(pwd, 'cache');
            mkdir(cacheDir);
            fc = did.file.fileCache(cacheDir, uint16(32), uint64(1e6), uint64(8e5));

            nameA = repmat('a', 1, 32);   % fileCache requires 32-char names
            nameB = repmat('b', 1, 32);
            szA = uint64(100);
            szB = uint64(250);

            % Add two files below maxSize in a single call (the not-full branch).
            fc.resizeAndAdd([szA szB], {nameA, nameB});

            testCase.verifyTrue(logical(fc.isFile(nameA)), ...
                'first file must be recorded in the manifest');
            testCase.verifyTrue(logical(fc.isFile(nameB)), ...
                'second file must be recorded in the manifest (was lost)');

            p = fc.getProperties();
            testCase.verifyEqual(uint64(p.currentSize), szA + szB, ...
                'currentSize must equal the sum of both added file sizes');
        end

    end
end
