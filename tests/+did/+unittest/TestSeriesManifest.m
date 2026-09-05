classdef TestSeriesManifest < matlab.unittest.TestCase
    % Round-trip and layout tests for the file series manifest.
    %
    % See docs/notes/file_series_manifest.md and DID-matlab issue #173.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
        end
    end

    methods
        function p = manifestPath(~)
            p = fullfile(pwd, 'series.manifest');
        end
    end

    methods (Test)

        function testRoundTripUidsOnly(testCase)
            uids = {did.ido.unique_id(), did.ido.unique_id(), did.ido.unique_id()};
            p = testCase.manifestPath();

            did.file.writeSeriesManifest(p, uids);
            m = did.file.readSeriesManifest(p);

            testCase.verifyEqual(m.count, 3);
            testCase.verifyEqual(m.uids, uids);
            testCase.verifyFalse(m.hasSourceNames);
            testCase.verifyEmpty(m.sourceNames);
        end

        function testAbsentMembersRoundTripAsEmpty(testCase)
            % A series is sparse: a zarr level never writes an all-fill
            % chunk. An absent slot must come back as '' rather than as
            % padding characters or an error.
            uids = {did.ido.unique_id(), '', did.ido.unique_id(), ''};
            p = testCase.manifestPath();

            did.file.writeSeriesManifest(p, uids);
            m = did.file.readSeriesManifest(p);

            testCase.verifyEqual(m.count, 4);
            testCase.verifyEqual(m.uids, uids);
        end

        function testRoundTripWithSourceNames(testCase)
            uids  = {did.ido.unique_id(), did.ido.unique_id(), did.ido.unique_id()};
            % Relative names, with a subfolder component -- the reason a bare
            % basename would not do -- plus one member with no name at all.
            names = {'0/0.0.0.0', '', '0/0.1.2.3'};
            p = testCase.manifestPath();

            did.file.writeSeriesManifest(p, uids, 'sourceNames', names);
            m = did.file.readSeriesManifest(p);

            testCase.verifyTrue(m.hasSourceNames);
            testCase.verifyEqual(m.uids, uids);
            testCase.verifyEqual(m.sourceNames, names);
        end

        function testSourceNamesSurviveNonAscii(testCase)
            % Names are written as UTF-8 bytes, so a non-ASCII path must
            % come back unchanged rather than mangled one byte per char.
            uids  = {did.ido.unique_id()};
            names = {['0/mu' char(956) '.chunk']};
            p = testCase.manifestPath();

            did.file.writeSeriesManifest(p, uids, 'sourceNames', names);
            m = did.file.readSeriesManifest(p);

            testCase.verifyEqual(m.sourceNames, names);
        end

        function testEmptySeriesRoundTrips(testCase)
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, {});
            m = did.file.readSeriesManifest(p);

            testCase.verifyEqual(m.count, 0);
            testCase.verifyEmpty(m.uids);
        end

        function testCustomUidWidthIsHonoured(testCase)
            uids = {'shortuid', ''};
            p = testCase.manifestPath();

            did.file.writeSeriesManifest(p, uids, 'uidWidth', 12);
            m = did.file.readSeriesManifest(p);

            testCase.verifyEqual(m.uidWidth, 12);
            testCase.verifyEqual(m.uids, uids);
        end

        function testUidWiderThanDeclaredIsAnError(testCase)
            % Silent truncation would resolve to the wrong file or to none,
            % and would be discovered a long way from here.
            p = testCase.manifestPath();
            testCase.verifyError( ...
                @() did.file.writeSeriesManifest(p, {'0123456789'}, 'uidWidth', 4), ...
                'DID:FileSeries:writeSeriesManifest:uidTooWide');
        end

        function testSourceNamesLengthMismatchIsAnError(testCase)
            p = testCase.manifestPath();
            testCase.verifyError( ...
                @() did.file.writeSeriesManifest(p, {'a','b'}, 'sourceNames', {'x'}), ...
                'DID:FileSeries:writeSeriesManifest:lengthMismatch');
        end

        function testNonCharUidIsAnError(testCase)
            p = testCase.manifestPath();
            testCase.verifyError( ...
                @() did.file.writeSeriesManifest(p, {5}), ...
                'DID:FileSeries:writeSeriesManifest:badUid');
        end

        function testBadMagicIsRejected(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w'); fwrite(fid, uint8('NOTAMANIFEST'), 'uint8'); fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:badMagic');
        end

        function testTruncatedFileIsRejected(testCase)
            % Half a manifest must not read as a short one: the count in the
            % header is what says how many members there are.
            uids = {did.ido.unique_id(), did.ido.unique_id(), did.ido.unique_id()};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids);

            % Cut at the header (32 bytes) plus exactly ONE complete
            % 33-byte uid record, so fread([33 3]) returns a 33-by-1 and
            % the shortfall is unambiguous. Read as BYTES: fileread would
            % decode the binary as text and mangle it on the way back out.
            fid = fopen(p, 'r'); raw = fread(fid, Inf, '*uint8'); fclose(fid);
            fid = fopen(p, 'w'); fwrite(fid, raw(1:65), 'uint8'); fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:truncated');
        end

        function testOnDiskLayoutMatchesTheSpec(testCase)
            % Pins the bytes, not just the round trip. A reader in another
            % language (DID-python) has to match this file, and a change
            % that keeps MATLAB self-consistent while moving a field would
            % otherwise pass every other test here.
            uids = {'abc', ''};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids, 'uidWidth', 4);

            fid = fopen(p, 'r', 'ieee-le');
            closer = onCleanup(@() fclose(fid));

            testCase.verifyEqual(char(fread(fid, 8, '*uint8')'), 'DIDFSER1');
            testCase.verifyEqual(fread(fid, 1, '*uint32'), uint32(1), ...
                'format_version');
            testCase.verifyEqual(fread(fid, 1, '*uint32'), uint32(0), ...
                'flags: no source names');
            testCase.verifyEqual(fread(fid, 1, '*uint32'), uint32(2), 'count');
            testCase.verifyEqual(fread(fid, 1, '*uint32'), uint32(4), 'uid_width');
            testCase.verifyEqual(fread(fid, 2, '*uint32')', uint32([0 0]), ...
                'reserved');

            % Member 0: 'abc' NUL-padded to 4. Member 1: absent, all NUL.
            testCase.verifyEqual(fread(fid, 4, '*uint8')', ...
                uint8([abs('abc') 0]));
            testCase.verifyEqual(fread(fid, 4, '*uint8')', uint8([0 0 0 0]));
        end

    end
end
