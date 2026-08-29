classdef fileCache < matlab.unittest.TestCase
    % FILECACHE - Generate a file cache artifact both languages can read
    %
    % Mirrors DID-python's
    % tests/symmetry/make_artifacts/file/test_file_cache.py.
    %
    % Both languages call the cache index '.fileCacheInfo' and both write this
    % binary layout: a 26-byte header (fileNameCharacters as uint16, then
    % maxSize, reduceSize and currentSize as uint64) followed by fixed-width
    % {char[n], double, uint64} rows. Unit tests in each language assert that
    % layout from the inside. This pair is the only thing that checks one
    % language can read what the other actually wrote.
    %
    % It matters because the two are expected to share a directory:
    % do_open_doc consults filecachepath on every document-file open, and
    % DID-python's open_doc now does the same.

    properties (Constant)
        nameCharacters = 33
        maxSize = 100000
        reduceSize = 80000
        % Fixed last-access times rather than now(), so both languages can
        % compare the stored doubles exactly. A format error shows up as a
        % wildly different number, not as a rounding difference.
        fixedTimes = [738000.5, 738001.25, 738002.75]
        sizes = [10, 20, 30]
        cacheDirName = 'cache'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Static)
        function n = nameOf(index)
            % The 33-character name a cached file takes: a did unique id is 33 long.
            n = sprintf('%033d', index);
        end
    end

    methods (Test)
        function testFileCacheArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'file', 'fileCache', 'testFileCacheArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            cacheDir = fullfile(artifactDir, testCase.cacheDirName);
            sourceDir = fullfile(artifactDir, 'sources');
            mkdir(cacheDir);
            mkdir(sourceDir);

            fc = did.file.fileCache(cacheDir, uint16(testCase.nameCharacters), ...
                uint64(testCase.maxSize), uint64(testCase.reduceSize));

            for i = 1:numel(testCase.sizes)
                sourcePath = fullfile(sourceDir, ['source_' int2str(i)]);
                fid = fopen(sourcePath, 'w', 'ieee-le');
                testCase.assertNotEqual(fid, -1, ['Could not create ' sourcePath]);
                % Deterministic content: file i is sizes(i) copies of byte i.
                fwrite(fid, repmat(uint8(i), 1, testCase.sizes(i)), 'uint8');
                fclose(fid);
                fc.addFile(sourcePath, ...
                    did.symmetry.makeArtifacts.file.fileCache.nameOf(i));
            end

            % Stamp known access times over the now() values addFile wrote, so
            % the reader can assert the exact doubles rather than a tolerance.
            bT = did.file.binaryTable(...
                did.file.fileobj('fullpathfilename', ...
                    fullfile(cacheDir, did.file.fileCache.cacheInfoFileName)), ...
                {'char','double','uint64'}, ...
                [testCase.nameCharacters 8 8], ...
                [testCase.nameCharacters 1 1], ...
                2+8+8+8);
            for i = 1:numel(testCase.fixedTimes)
                bT.writeEntry(i, 2, testCase.fixedTimes(i));
            end

            % Manifest for the reader.
            entries = struct('name', {}, 'size', {}, 'lastAccess', {}, 'bytes', {});
            for i = 1:numel(testCase.sizes)
                entries(i).name = did.symmetry.makeArtifacts.file.fileCache.nameOf(i);
                entries(i).size = testCase.sizes(i);
                entries(i).lastAccess = testCase.fixedTimes(i);
                entries(i).bytes = repmat(i, 1, testCase.sizes(i));
            end
            manifest = struct( ...
                'cacheDirName', testCase.cacheDirName, ...
                'fileNameCharacters', testCase.nameCharacters, ...
                'maxSize', testCase.maxSize, ...
                'reduceSize', testCase.reduceSize, ...
                'currentSize', sum(testCase.sizes), ...
                'entries', entries);
            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest));
            fclose(fid);

            % Self-check: reopen and confirm what we claim, before any
            % cross-language claim is made about it.
            reopened = did.file.fileCache(cacheDir);
            testCase.verifyEqual(reopened.fileNameCharacters, uint16(testCase.nameCharacters));
            p = reopened.getProperties();
            testCase.verifyEqual(p.currentSize, uint64(sum(testCase.sizes)));
            [fn, sz, la] = reopened.fileList(true);
            testCase.verifyEqual(size(fn,1), numel(testCase.sizes));
            testCase.verifyEqual(sz(:)', uint64(testCase.sizes));
            testCase.verifyEqual(la(:)', testCase.fixedTimes);
        end
    end
end
