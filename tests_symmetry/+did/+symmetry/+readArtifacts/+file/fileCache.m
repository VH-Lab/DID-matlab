classdef fileCache < matlab.unittest.TestCase
    % FILECACHE - Open a file cache the other language wrote
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/file/test_file_cache.py.
    %
    % The Python direction is the one that could not have worked before the
    % port: DID-python wrote this index as JSON under the same
    % '.fileCacheInfo' name, so neither language could read the other's.
    %
    % The cache is copied out of the artifact directory before it is opened,
    % so this test cannot disturb an artifact the other language has yet to
    % read.
    %
    % Assumes rather than fails when the artifact is absent, so this can land
    % in either repository first without blocking the other.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)
        function testFileCacheArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'file', 'fileCache', 'testFileCacheArtifacts');

            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);
            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            % Work on a copy: the other language may not have read this yet.
            cacheDir = fullfile(pwd, 'cache');
            copyfile(fullfile(artifactDir, manifest.cacheDirName), cacheDir);

            fc = did.file.fileCache(cacheDir);

            testCase.verifyEqual(double(fc.fileNameCharacters), ...
                double(manifest.fileNameCharacters), ...
                ['the name width in ' SourceType '''s header was misread; every ' ...
                 'row is fixed-width, so the whole index would be read at the ' ...
                 'wrong offsets']);

            p = fc.getProperties();
            testCase.verifyEqual(double(p.maxSize), double(manifest.maxSize));
            testCase.verifyEqual(double(p.reduceSize), double(manifest.reduceSize));
            testCase.verifyEqual(double(p.currentSize), double(manifest.currentSize));

            % jsondecode gives a struct array for a homogeneous list and a cell
            % array otherwise; normalize so both shapes iterate the same way.
            entries = manifest.entries;
            if ~iscell(entries)
                entries = num2cell(entries);
            end

            [fn, sz, la] = fc.fileList(true);
            testCase.verifyEqual(size(fn,1), numel(entries), ...
                ['wrong number of rows read from ' SourceType '''s .fileCacheInfo']);

            for i = 1:numel(entries)
                entry = entries{i};
                testCase.verifyEqual(fn(i,:), entry.name, ...
                    ['names read from ' SourceType '''s .fileCacheInfo do not match']);
                testCase.verifyEqual(double(sz(i)), double(entry.size));
                % Exact, not approximate: the maker stamped fixed doubles
                % precisely so a decoding error cannot hide in a tolerance.
                testCase.verifyEqual(la(i), entry.lastAccess, ...
                    ['last-access times from ' SourceType ' decoded wrongly; these ' ...
                     'are raw little-endian doubles and eviction orders on them']);

                testCase.verifyTrue(logical(fc.isFile(entry.name)));
                cachedFile = fullfile(cacheDir, entry.name);
                testCase.verifyTrue(isfile(cachedFile), ...
                    [entry.name ' is indexed but missing']);
                cfid = fopen(cachedFile, 'r', 'ieee-le');
                data = fread(cfid, Inf, 'uint8');
                fclose(cfid);
                testCase.verifyEqual(data(:)', double(entry.bytes(:))', ...
                    ['wrong bytes for ' entry.name ' from ' SourceType]);
            end
        end
    end
end
