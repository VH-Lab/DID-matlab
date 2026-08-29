classdef TestFileCache < matlab.unittest.TestCase
    % Test did.file.fileCache, which sqlitedb.do_open_doc consults on every
    % document-file open.
    %
    % fileCache had no test coverage. That is how resizeAndAdd came to
    % catalogue every file after the first under the first file's name, and
    % how removeFile's "not in manifest" error came to reference a variable
    % that does not exist.
    %
    % The .fileCacheInfo layout asserted here is the one DID-python's
    % FileCache also reads and writes.

    properties (Constant)
        NameCharacters = 33
        HeaderSize = 2+8+8+8
    end

    properties
        cacheDir
        sourceDir
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
            testCase.cacheDir = fullfile(pwd,'cache');
            testCase.sourceDir = fullfile(pwd,'sources');
            mkdir(testCase.cacheDir);
            mkdir(testCase.sourceDir);
        end
    end

    methods
        function fc = makeCache(testCase, maxSize, reduceSize)
            if nargin < 2, maxSize = 100000; end
            if nargin < 3, reduceSize = 80000; end
            fc = did.file.fileCache(testCase.cacheDir, testCase.NameCharacters, ...
                uint64(maxSize), uint64(reduceSize));
        end

        function p = makeSource(testCase, index, nBytes)
            p = fullfile(testCase.sourceDir, ['source_' int2str(index)]);
            fid = fopen(p,'w','ieee-le');
            fwrite(fid, uint8(mod(index,256))*ones(1,nBytes), 'uint8');
            fclose(fid);
        end
    end

    methods (Static)
        function n = nameOf(index)
            n = sprintf('%033d', index);
        end
    end

    methods (Test)

        function testTheIndexIsTheDocumentedBinaryLayout(testCase)
            % Read .fileCacheInfo with plain fread, so a change of layout is
            % caught rather than round-tripped over. DID-python builds this
            % same file byte by byte and reads it back.
            testCase.makeCache(100000, 80000);
            fid = fopen(fullfile(testCase.cacheDir,'.fileCacheInfo'),'r','ieee-le');
            raw = uint8(fread(fid, Inf, 'uint8'))';
            fclose(fid);

            testCase.verifyEqual(numel(raw), testCase.HeaderSize);
            testCase.verifyEqual(typecast(raw(1:2),'uint16'), uint16(testCase.NameCharacters));
            testCase.verifyEqual(typecast(raw(3:10),'uint64'), uint64(100000));
            testCase.verifyEqual(typecast(raw(11:18),'uint64'), uint64(80000));
            testCase.verifyEqual(typecast(raw(19:26),'uint64'), uint64(0));
        end

        function testGetProperties(testCase)
            fc = testCase.makeCache(100000, 80000);
            p = fc.getProperties();
            testCase.verifyEqual(p.fileNameCharacters, uint16(testCase.NameCharacters));
            testCase.verifyEqual(p.maxSize, uint64(100000));
            testCase.verifyEqual(p.reduceSize, uint64(80000));
            testCase.verifyEqual(p.currentSize, uint64(0));
        end

        function testReopeningKeepsTheStoredSettings(testCase)
            testCase.makeCache(60000, 50000);
            reopened = did.file.fileCache(testCase.cacheDir);
            testCase.verifyEqual(reopened.maxSize, uint64(60000));
            testCase.verifyEqual(reopened.reduceSize, uint64(50000));
            testCase.verifyEqual(reopened.fileNameCharacters, uint16(testCase.NameCharacters));
        end

        function testReopeningWithoutTheNameWidthCanStillReadTheRows(testCase)
            % The header carries the name width, so the scalar properties
            % came back right even when the table underneath had been built
            % at the default 32. The rows are fixed-width, so that table read
            % the file at the wrong offsets and the catalog came back
            % garbled -- visible only once something read a row.
            fc = testCase.makeCache();
            fc.addFile(testCase.makeSource(1,40), testCase.nameOf(1));
            fc.addFile(testCase.makeSource(2,60), testCase.nameOf(2));

            reopened = did.file.fileCache(testCase.cacheDir);
            [fn, sz] = reopened.fileList(true);
            testCase.verifyEqual(size(fn), [2 testCase.NameCharacters]);
            testCase.verifyEqual(fn(:,1:testCase.NameCharacters), ...
                [testCase.nameOf(1); testCase.nameOf(2)]);
            testCase.verifyEqual(sz, uint64([40;60]));
            testCase.verifyTrue(logical(reopened.isFile(testCase.nameOf(2))));
        end

        function testTheNameWidthCannotBeChanged(testCase)
            testCase.makeCache();
            testCase.verifyError(...
                @() did.file.fileCache(testCase.cacheDir, uint16(40)), ?MException);
        end

        function testAddThenFind(testCase)
            fc = testCase.makeCache();
            fc.addFile(testCase.makeSource(1,40), testCase.nameOf(1));
            testCase.verifyTrue(logical(fc.isFile(testCase.nameOf(1))));
            testCase.verifyTrue(isfile(fullfile(testCase.cacheDir, testCase.nameOf(1))));
            p = fc.getProperties();
            testCase.verifyEqual(p.currentSize, uint64(40));
        end

        function testAddingMovesTheOriginalUnlessCopyIsAsked(testCase)
            fc = testCase.makeCache();
            moved = testCase.makeSource(1,40);
            fc.addFile(moved, testCase.nameOf(1));
            testCase.verifyFalse(isfile(moved));

            copied = testCase.makeSource(2,40);
            fc.addFile(copied, testCase.nameOf(2), 'copy', true);
            testCase.verifyTrue(isfile(copied));
        end

        function testAWrongLengthNameIsRefused(testCase)
            fc = testCase.makeCache();
            testCase.verifyError(...
                @() fc.addFile(testCase.makeSource(1,40), 'short'), ?MException);
        end

        function testAddingTheSameNameTwiceIsRefused(testCase)
            fc = testCase.makeCache();
            fc.addFile(testCase.makeSource(1,40), testCase.nameOf(1));
            testCase.verifyError(...
                @() fc.addFile(testCase.makeSource(2,40), testCase.nameOf(1)), ?MException);
        end

        function testSeveralFilesEachGetTheirOwnRow(testCase)
            % resizeAndAdd built its row cell indexed by the loop variable,
            % so the second file's name landed in the last-accessed column
            % and was immediately overwritten -- every file after the first
            % was catalogued under the first file's name.
            fc = testCase.makeCache();
            fc.resizeAndAdd(uint64([10 20 30]), ...
                {testCase.nameOf(1), testCase.nameOf(2), testCase.nameOf(3)});

            [fn, sz] = fc.fileList(true);
            testCase.verifyEqual(size(fn,1), 3);
            testCase.verifyEqual(fn(:,1:testCase.NameCharacters), ...
                [testCase.nameOf(1); testCase.nameOf(2); testCase.nameOf(3)]);
            testCase.verifyEqual(sz, uint64([10;20;30]));
        end

        function testTheIndexStaysSortedByName(testCase)
            fc = testCase.makeCache();
            for k = [5 1 9 3]
                fc.addFile(testCase.makeSource(k,10), testCase.nameOf(k));
            end
            fn = fc.fileList(true);
            testCase.verifyEqual(fn, sortrows(fn));
        end

        function testFileListOnAnEmptyCache(testCase)
            fc = testCase.makeCache();
            testCase.verifyEmpty(fc.fileList(true));
        end

        function testRemove(testCase)
            fc = testCase.makeCache();
            fc.addFile(testCase.makeSource(1,40), testCase.nameOf(1));
            fc.addFile(testCase.makeSource(2,60), testCase.nameOf(2));
            fc.removeFile(testCase.nameOf(1));

            testCase.verifyFalse(logical(fc.isFile(testCase.nameOf(1))));
            testCase.verifyFalse(isfile(fullfile(testCase.cacheDir, testCase.nameOf(1))));
            fn = fc.fileList(true);
            testCase.verifyEqual(size(fn,1), 1);
            p = fc.getProperties();
            testCase.verifyEqual(p.currentSize, uint64(60));
        end

        function testRemovingWhatIsNotThereReportsTheName(testCase)
            % The error message referenced an undefined variable, so this
            % raised "Unrecognized function or variable 'filename'" instead
            % of saying which file was missing.
            fc = testCase.makeCache();
            testCase.verifyError(@() fc.removeFile(testCase.nameOf(1)), ?MException);
            try
                fc.removeFile(testCase.nameOf(1));
            catch err
                testCase.verifySubstring(err.message, 'is not in file cache manifest');
                testCase.verifySubstring(err.message, testCase.nameOf(1));
            end
        end

        function testClear(testCase)
            fc = testCase.makeCache();
            for k = 1:3
                fc.addFile(testCase.makeSource(k,40), testCase.nameOf(k));
            end
            fc.clear();
            testCase.verifyEmpty(fc.fileList(true));
            p = fc.getProperties();
            testCase.verifyEqual(p.currentSize, uint64(0));
            for k = 1:3
                testCase.verifyFalse(isfile(fullfile(testCase.cacheDir, testCase.nameOf(k))));
            end
        end

        function testTouch(testCase)
            fc = testCase.makeCache();
            fc.addFile(testCase.makeSource(1,40), testCase.nameOf(1));
            [~,~,before] = fc.fileList(true);
            testCase.verifyEqual(fc.touch(testCase.nameOf(1)), 1);
            [~,~,after] = fc.fileList(true);
            testCase.verifyGreaterThanOrEqual(after, before);
            testCase.verifyEqual(fc.touch(testCase.nameOf(2)), 0);
        end

        function testLeastRecentlyUsedFilesAreEvicted(testCase)
            fc = testCase.makeCache(100000, 80000);
            fc.addFile(testCase.makeSource(0,40000), testCase.nameOf(0));
            pause(0.05);  % distinct access times; datenum resolution is coarse
            fc.addFile(testCase.makeSource(1,40000), testCase.nameOf(1));
            pause(0.05);
            % 40000 more would be 120000, over the cap, so the cache is cut
            % back to 80000 -- which costs exactly the oldest file.
            fc.addFile(testCase.makeSource(2,40000), testCase.nameOf(2));

            fn = fc.fileList(true);
            testCase.verifyEqual(size(fn,1), 2);
            testCase.verifyFalse(isfile(fullfile(testCase.cacheDir, testCase.nameOf(0))));
            testCase.verifyTrue(isfile(fullfile(testCase.cacheDir, testCase.nameOf(2))));
            p = fc.getProperties();
            testCase.verifyEqual(p.currentSize, uint64(80000));
        end

        function testAFileLargerThanTheCacheIsRefused(testCase)
            fc = testCase.makeCache();
            testCase.verifyError(...
                @() fc.addFile(testCase.makeSource(1,200000), testCase.nameOf(1)), ...
                ?MException);
        end

    end
end
