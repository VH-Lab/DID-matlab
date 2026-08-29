classdef TestLockFile < matlab.unittest.TestCase
    % Test did.file.checkout_lock_file and did.file.lock_expiration_time.
    %
    % These matter across languages. DID-python locks the same files with
    % the same "<file>-lock" name, and once both languages share a file
    % cache they contend for the same lock. A reader that understands only
    % its own expiry format cannot tell an expired lock from an unreadable
    % one, so a process that died holding the lock would shut the other
    % language out permanently -- exactly the crash the one-hour expiry is
    % there to recover from.

    properties
        lockFile
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
            testCase.lockFile = fullfile(pwd, 'thing.bin-lock');
        end
    end

    methods
        function writeLock(testCase, expirationText, key)
            fid = fopen(testCase.lockFile, 'wt');
            testCase.assertNotEqual(fid, -1);
            fprintf(fid, '%s\n%s\n', expirationText, key);
            fclose(fid);
        end
    end

    methods (Test)

        function testIsoIsParsed(testCase)
            % What both languages write now.
            t = did.file.lock_expiration_time('2026-08-29T14:35:12.123456');
            testCase.verifyEqual(year(t), 2026);
            testCase.verifyEqual(month(t), 8);
            testCase.verifyEqual(day(t), 29);
            testCase.verifyEqual(hour(t), 14);
            testCase.verifyEqual(minute(t), 35);
        end

        function testIsoWithoutFractionalSecondsIsParsed(testCase)
            t = did.file.lock_expiration_time('2026-08-29T14:35:12');
            testCase.verifyEqual(year(t), 2026);
            testCase.verifyEqual(hour(t), 14);
        end

        function testTheLegacyCharDatetimeFormIsParsed(testCase)
            % What this package wrote before: char(datetime(...)). Locks
            % written by an older DID must still expire.
            t = did.file.lock_expiration_time('29-Aug-2026 14:35:12');
            testCase.verifyEqual(year(t), 2026);
            testCase.verifyEqual(month(t), 8);
            testCase.verifyEqual(day(t), 29);
            testCase.verifyEqual(hour(t), 14);
        end

        function testUnparseableTextReportsNoExpiry(testCase)
            % Inf is the sentinel checkout_lock_file waits on. Guessing an
            % expiry here would mean stealing a lock we cannot read.
            testCase.verifyEqual(did.file.lock_expiration_time('not a time'), Inf);
            testCase.verifyEqual(did.file.lock_expiration_time(''), Inf);
        end

        function testWhatWeWriteIsWhatWeCanRead(testCase)
            [fid, key] = did.file.checkout_lock_file(testCase.lockFile);
            testCase.assertGreaterThan(fid, -1);
            C = did.file.readlines(testCase.lockFile);
            testCase.verifyEqual(numel(C), 2);
            t = did.file.lock_expiration_time(C{1});
            testCase.verifyFalse(isinf(t), ...
                'a lock we wrote must have an expiry we can read back');
            did.file.release_lock_file(testCase.lockFile, key);
            testCase.verifyFalse(isfile(testCase.lockFile));
        end

        function testWeWriteIso8601(testCase)
            % Not char(datetime(...)): that renders month names in the
            % ambient locale, so a lock written by a French-locale MATLAB
            % could not be read by an English one, and DID-python's
            % datetime.fromisoformat cannot read it at all.
            [~, key] = did.file.checkout_lock_file(testCase.lockFile);
            C = did.file.readlines(testCase.lockFile);
            testCase.verifyNotEmpty( ...
                regexp(strtrim(C{1}), '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', 'once'), ...
                sprintf('"%s" is not ISO 8601', strtrim(C{1})));
            did.file.release_lock_file(testCase.lockFile, key);
        end

        function testAnExpiredLockIsReclaimed(testCase)
            past = datetime('now','TimeZone','UTCLeapSeconds') - hours(1);
            past.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSS';
            testCase.writeLock(char(past), 'someoneElsesKey');

            [fid, key] = did.file.checkout_lock_file(testCase.lockFile, 5, false);
            testCase.verifyGreaterThan(fid, -1, ...
                'an expired lock must be reclaimable, or a crash wedges the file forever');
            did.file.release_lock_file(testCase.lockFile, key);
        end

        function testAnExpiredLockInPythonsFormatIsReclaimed(testCase)
            % Byte-for-byte what DID-python's checkout_lock_file writes:
            % datetime.isoformat(), then the key.
            past = datetime('now','TimeZone','UTCLeapSeconds') - hours(1);
            past.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSS';
            testCase.writeLock(char(past), '2026-08-29T13:00:00_0f1e2d3c-4b5a-6789-abcd-ef0123456789');

            [fid, key] = did.file.checkout_lock_file(testCase.lockFile, 5, false);
            testCase.verifyGreaterThan(fid, -1, ...
                'MATLAB must be able to expire a lock DID-python left behind');
            did.file.release_lock_file(testCase.lockFile, key);
        end

        function testAnExpiredLockInTheLegacyFormatIsReclaimed(testCase)
            past = datetime('now','TimeZone','UTCLeapSeconds') - hours(1);
            testCase.writeLock(char(past), 'someoneElsesKey');  % char(datetime(...))

            [fid, key] = did.file.checkout_lock_file(testCase.lockFile, 5, false);
            testCase.verifyGreaterThan(fid, -1, ...
                'a lock written by an older DID must still expire');
            did.file.release_lock_file(testCase.lockFile, key);
        end

        function testALiveLockIsNotStolen(testCase)
            future = datetime('now','TimeZone','UTCLeapSeconds') + hours(1);
            future.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSS';
            testCase.writeLock(char(future), 'someoneElsesKey');

            fid = did.file.checkout_lock_file(testCase.lockFile, 1, false);
            testCase.verifyLessThan(fid, 0, 'a live lock must not be taken');
            testCase.verifyTrue(isfile(testCase.lockFile), 'and must not be deleted');
        end

        function testAnUnreadableLockIsNotStolen(testCase)
            % Fail safe: an expiry we cannot parse means wait, not take.
            testCase.writeLock('whatever this is', 'someoneElsesKey');

            fid = did.file.checkout_lock_file(testCase.lockFile, 1, false);
            testCase.verifyLessThan(fid, 0);
            testCase.verifyTrue(isfile(testCase.lockFile));
        end

        function testTheWrongKeyDoesNotRelease(testCase)
            future = datetime('now','TimeZone','UTCLeapSeconds') + hours(1);
            future.Format = 'uuuu-MM-dd''T''HH:mm:ss.SSSSSS';
            testCase.writeLock(char(future), 'someoneElsesKey');

            testCase.verifyEqual(did.file.release_lock_file(testCase.lockFile, 'myKey'), 0);
            testCase.verifyTrue(isfile(testCase.lockFile));
        end

    end
end
