classdef fileCacheStaleRow < matlab.unittest.TestCase
    % FILECACHESTALEROW - A file cache left in a divergent state, on purpose
    %
    % The fileCache pair covers a HEALTHY cache: index and disk agree, and
    % each language reads what the other wrote. This one covers the state a
    % shared cache actually gets into, and it is a separate artifact rather
    % than an extension of that one precisely so the healthy pair keeps
    % meaning what it means.
    %
    % Two divergences, both from did.file.fileCache/check:
    %
    %   a STALE ROW  - the index promises a file that is not on disk. Left by
    %                  an interrupted eviction, a failed move, or a lock race.
    %                  This is the one that POISONS a uid: isFile consults
    %                  the index, so it answers true while the bytes are
    %                  gone, and addFile used to refuse the caller who
    %                  actually had them -- the file never re-cacheable until
    %                  the row was dropped. DID-matlab#174 made addFile
    %                  retract the promise instead (commit 4a0f9a5).
    %   an ORPHAN    - a file on disk with no index row. Harmless in itself:
    %                  it does not count against currentSize. It occupies
    %                  space, and a language that treats every file in the
    %                  directory as cached would double-count it.
    %
    % WHY THIS IS A CROSS-LANGUAGE CONCERN AT ALL. One cache directory, two
    % languages, and either can be the one that dies mid-write. So whichever
    % arrives next has to reconcile a state it did not create, and the two
    % must agree on what "stale" and "orphan" mean before they can agree on
    % what to do. A port that errors here, or that silently serves a stale
    % row as a hit, breaks a cache the other language is still using.
    %
    % The artifact is NOT repaired by this test: check() is called with its
    % read-only defaults so the divergence survives for the reader. Repairing
    % it here would leave nothing to read.

    properties (Constant)
        nameCharacters = 33
        maxSize = 100000
        reduceSize = 80000
        % Four entries, of which the second is the one whose bytes go away.
        sizes = [10, 20, 30, 40]
        staleIndex = 2
        % Fixed last-access times, as in the fileCache artifact, so the
        % reader can assert exact doubles rather than a tolerance.
        fixedTimes = [738000.5, 738001.25, 738002.75, 738003.5]
        orphanSize = 15
        cacheDirName = 'cache'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (TestMethodTeardown)
        function teardownMethod(~)
            % Artifacts must persist in tempdir for the Python suite to read.
        end
    end

    methods (Static)
        function n = nameOf(index)
            % The 33-character name a cached file takes. Kept distinct from
            % the fileCache artifact's numbering by starting at 101, so the
            % two artifacts cannot be confused if a reader mixes them up.
            n = sprintf('%033d', 100 + index);
        end

        function n = orphanName()
            n = sprintf('%033d', 999);
        end
    end

    methods (Test)
        function testFileCacheStaleRowArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'file', 'fileCacheStaleRow', ...
                'testFileCacheStaleRowArtifacts');
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            cacheDir = fullfile(artifactDir, testCase.cacheDirName);
            sourceDir = fullfile(artifactDir, 'sources');
            mkdir(cacheDir);
            mkdir(sourceDir);

            fc = did.file.fileCache(cacheDir, uint16(testCase.nameCharacters), ...
                uint64(testCase.maxSize), uint64(testCase.reduceSize));

            % Add all four normally. File i is sizes(i) copies of byte i.
            for i = 1:numel(testCase.sizes)
                sourcePath = fullfile(sourceDir, ['source_' int2str(i)]);
                fid = fopen(sourcePath, 'w', 'ieee-le');
                testCase.assertNotEqual(fid, -1, ['Could not create ' sourcePath]);
                fwrite(fid, repmat(uint8(i), 1, testCase.sizes(i)), 'uint8');
                fclose(fid);
                fc.addFile(sourcePath, ...
                    did.symmetry.makeArtifacts.file.fileCacheStaleRow.nameOf(i));
            end

            % Stamp known access times over the now() values addFile wrote.
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

            % THE STALE ROW. Delete the bytes directly rather than through
            % removeFile, which would drop the row too and leave a healthy
            % cache. This is what an interrupted eviction leaves behind.
            staleName = did.symmetry.makeArtifacts.file.fileCacheStaleRow.nameOf( ...
                testCase.staleIndex);
            delete(fullfile(cacheDir, staleName));

            % THE ORPHAN. A plausible cache file that was never added, so no
            % row names it.
            orphanFile = did.symmetry.makeArtifacts.file.fileCacheStaleRow.orphanName();
            fid = fopen(fullfile(cacheDir, orphanFile), 'w', 'ieee-le');
            testCase.assertNotEqual(fid, -1, 'Could not create the orphan');
            fwrite(fid, repmat(uint8(9), 1, testCase.orphanSize), 'uint8');
            fclose(fid);

            % --- the manifest for the reader -----------------------------
            entries = struct('name', {}, 'size', {}, 'lastAccess', {}, ...
                'bytes', {}, 'onDisk', {});
            for i = 1:numel(testCase.sizes)
                entries(i).name = did.symmetry.makeArtifacts.file.fileCacheStaleRow.nameOf(i);
                entries(i).size = testCase.sizes(i);
                entries(i).lastAccess = testCase.fixedTimes(i);
                entries(i).bytes = repmat(i, 1, testCase.sizes(i));
                entries(i).onDisk = (i ~= testCase.staleIndex);
            end

            % currentSize still counts the stale row's bytes: nothing
            % decremented it, which is exactly why a stale row is a
            % divergence and not merely a missing file.
            manifest = struct( ...
                'cacheDirName', testCase.cacheDirName, ...
                'fileNameCharacters', testCase.nameCharacters, ...
                'maxSize', testCase.maxSize, ...
                'reduceSize', testCase.reduceSize, ...
                'staleRowName', staleName, ...
                'orphanFileName', orphanFile, ...
                'orphanSize', testCase.orphanSize, ...
                'consistentEntries', numel(testCase.sizes) - 1, ...
                'currentSize', sum(testCase.sizes), ...
                'currentSizeIncludesStaleRow', true, ...
                'entries', entries);
            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest));
            fclose(fid);

            % --- self-check, read-only -----------------------------------
            reopened = did.file.fileCache(cacheDir);

            % The index still carries every name, the stale one included.
            [fn, ~, la] = reopened.fileList(true);
            testCase.verifyEqual(size(fn,1), numel(testCase.sizes), ...
                'the index must still carry a row for the stale entry');
            testCase.verifyEqual(la(:)', testCase.fixedTimes);

            % isFile consults the INDEX, so it answers true for a file that
            % is not there. That asymmetry is the whole point of the state.
            testCase.verifyTrue(reopened.isFile(staleName), ...
                'isFile reads the index, so a stale row still answers true');
            testCase.verifyFalse(isfile(fullfile(cacheDir, staleName)), ...
                'but the bytes are gone');

            p = reopened.getProperties();
            testCase.verifyEqual(p.currentSize, uint64(sum(testCase.sizes)), ...
                'nothing decremented currentSize for the deleted bytes');

            % check() with its read-only defaults names both divergences and
            % leaves them in place.
            report = reopened.check();
            testCase.verifyEqual(report.staleRows, {staleName}, ...
                'check must name exactly the stale row');
            testCase.verifyEqual(report.orphanFiles, {orphanFile}, ...
                'check must name exactly the orphan');
            testCase.verifyEqual(report.consistent, numel(testCase.sizes) - 1);
            testCase.verifyEqual(report.repaired.rowsDropped, 0, ...
                'the artifact must survive its own self-check unrepaired');
            testCase.verifyEqual(report.repaired.filesDeleted, 0);

            % And the divergence is still on disk for the reader.
            testCase.verifyTrue(reopened.isFile(staleName));
            testCase.verifyTrue(isfile(fullfile(cacheDir, orphanFile)));
        end
    end
end
