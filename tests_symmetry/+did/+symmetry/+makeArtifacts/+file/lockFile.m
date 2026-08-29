classdef lockFile < matlab.unittest.TestCase
    % LOCKFILE - Leave lock files for the other language to read
    %
    % Mirrors DID-python's
    % tests/symmetry/make_artifacts/file/test_lock_file.py.
    %
    % Once both languages share a file cache they contend for the same
    % '<file>-lock'. Agreeing on the name is not enough: a reader that cannot
    % parse the other's expiry cannot tell an expired lock from an unreadable
    % one, so a process that died holding the lock would shut the other
    % language out permanently -- the exact crash the one-hour expiry exists
    % to survive.
    %
    % Two locks are left behind: one live, one already expired. The other
    % language must refuse the first and reclaim the second. Nothing here
    % needs real concurrency, which keeps it deterministic.

    properties (Constant)
        liveLock = 'live.bin-lock'
        expiredLock = 'expired.bin-lock'
        liveKey = 'symmetryLiveKey'
        expiredKey = 'symmetryExpiredKey'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)
        function testLockFileArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'file', 'lockFile', 'testLockFileArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            now_ = datetime('now', 'TimeZone', 'UTCLeapSeconds');
            testCase.writeLock(fullfile(artifactDir, testCase.liveLock), ...
                now_ + hours(1), testCase.liveKey);
            testCase.writeLock(fullfile(artifactDir, testCase.expiredLock), ...
                now_ - hours(1), testCase.expiredKey);

            manifest = struct( ...
                'liveLock', testCase.liveLock, ...
                'expiredLock', testCase.expiredLock, ...
                'liveKey', testCase.liveKey, ...
                'expiredKey', testCase.expiredKey);
            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest));
            fclose(fid);

            % Self-check: our own reader must agree about both before we ask
            % the other language to.
            for name = {testCase.liveLock, testCase.expiredLock}
                C = did.file.readlines(fullfile(artifactDir, name{1}));
                testCase.verifyFalse(isinf(did.file.lock_expiration_time(C{1})), ...
                    ['could not read back the expiry we wrote to ' name{1}]);
            end
        end
    end

    methods
        function writeLock(testCase, path, when, key)
            % Written exactly as did.file.checkout_lock_file writes one.
            when.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSS';
            fid = fopen(path, 'wt');
            testCase.assertNotEqual(fid, -1, ['Could not create ' path]);
            fprintf(fid, '%s\n%s\n', char(when), key);
            fclose(fid);
        end
    end
end
