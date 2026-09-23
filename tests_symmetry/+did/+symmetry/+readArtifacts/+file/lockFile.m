classdef lockFile < matlab.unittest.TestCase
    % LOCKFILE - Honour lock files the other language wrote
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/file/test_lock_file.py.
    %
    % The maker leaves one live lock and one already expired. This side must
    % refuse the first and reclaim the second. Reclaiming is the half that was
    % broken: this package used to write its expiry as char(datetime(...)) --
    % '29-Aug-2026 14:35:12' -- which DID-python's datetime.fromisoformat
    % cannot parse, and its checkout_lock_file swallowed the error, so the
    % lock read as one that never expires.
    %
    % The locks are copied out of the artifact directory first, since
    % reclaiming one deletes it and the other language may not have read it.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function [manifest, working] = artifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'file', 'lockFile', 'testLockFileArtifacts');
            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);
            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            working = fullfile(pwd, 'locks');
            if ~isfolder(working)
                mkdir(working);
            end
            copyfile(fullfile(artifactDir, manifest.liveLock), ...
                fullfile(working, manifest.liveLock));
            copyfile(fullfile(artifactDir, manifest.expiredLock), ...
                fullfile(working, manifest.expiredLock));
        end
    end

    methods (Test)
        function testBothExpiriesAreReadable(testCase, SourceType)
            [manifest, working] = testCase.artifacts(SourceType);
            names = {manifest.liveLock, manifest.expiredLock};
            for i = 1:numel(names)
                C = did.file.readlines(fullfile(working, names{i}));
                % Inf means "no expiry could be read", which is
                % indistinguishable from a lock that never expires.
                testCase.verifyFalse(isinf(did.file.lock_expiration_time(C{1})), ...
                    ['could not read the expiry ' SourceType ' wrote to ' names{i}]);
            end
        end

        function testAnExpiredLockIsReclaimed(testCase, SourceType)
            [manifest, working] = testCase.artifacts(SourceType);
            path = fullfile(working, manifest.expiredLock);

            [fid, key] = did.file.checkout_lock_file(path, 3, false);
            testCase.verifyGreaterThan(fid, -1, ...
                ['could not reclaim an expired lock written by ' SourceType ...
                 '. A crashed process would wedge a shared cache permanently.']);
            did.file.release_lock_file(path, key);
        end

        function testALiveLockIsNotStolen(testCase, SourceType)
            [manifest, working] = testCase.artifacts(SourceType);
            path = fullfile(working, manifest.liveLock);

            fid = did.file.checkout_lock_file(path, 1, false);
            testCase.verifyLessThan(fid, 0, ...
                ['took a live lock held by ' SourceType]);
            testCase.verifyTrue(isfile(path), 'and deleted it');
        end
    end
end
