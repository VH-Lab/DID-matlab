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

        function writeHeader(~, fid, flags, count, uidWidth, version)
            % Hand-build a header so the corruption cases can be produced
            % without going through the writer, which would refuse them.
            fwrite(fid, uint8('DIDFSER1'), 'uint8');
            fwrite(fid, uint32(version), 'uint32');
            fwrite(fid, uint32(flags), 'uint32');
            fwrite(fid, uint32(count), 'uint32');
            fwrite(fid, uint32(uidWidth), 'uint32');
            fwrite(fid, zeros(1,2,'uint32'), 'uint32');
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

        function testEmptySourceNamesAtEveryPosition(testCase)
            % An empty name is equal offsets, and the first version of the
            % reader compared them AFTER converting to a one-based index,
            % which made every empty name look like a decreasing offset.
            % The middle case caught it; first, last and all-empty are
            % where the remaining off-by-ones would hide.
            uids = {did.ido.unique_id(), did.ido.unique_id(), ...
                    did.ido.unique_id(), did.ido.unique_id()};
            p = testCase.manifestPath();

            cases = { {'', '0/a', '0/b', '0/c'}, ...   % empty first
                      {'0/a', '0/b', '0/c', ''}, ...   % empty last
                      {'', '', '', ''}, ...            % all empty
                      {'0/a', '', '', '0/d'} };        % empty run in the middle

            for k = 1:numel(cases)
                names = cases{k};
                did.file.writeSeriesManifest(p, uids, 'sourceNames', names);
                m = did.file.readSeriesManifest(p);
                testCase.verifyEqual(m.sourceNames, names, ...
                    sprintf('source name case %d did not round-trip', k));
                testCase.verifyEqual(m.uids, uids, ...
                    sprintf('uids disturbed in source name case %d', k));
            end
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

        function testShortFileIsRejected(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w'); fwrite(fid, uint8('DID'), 'uint8'); fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:badMagic');
        end

        function testUnsupportedVersionIsRejected(testCase)
            % A future writer must not have its file read as if it were
            % version 1 and silently misinterpreted.
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 0, 0, 33, 2);
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:badVersion');
        end

        function testZeroUidWidthIsRejected(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 0, 1, 0, 1);
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:badUidWidth');
        end

        function testDecreasingNameOffsetIsRejected(testCase)
            % The error path guarding the comparison that the empty-name bug
            % lived in. Only its happy side was exercised, so a comparison
            % wrong in the OTHER direction would have gone unnoticed.
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 1, 2, 4, 1);            % flags bit 0 set
            fwrite(fid, uint8([abs('ab') 0 0]), 'uint8');     % member 0 uid
            fwrite(fid, uint8([abs('cd') 0 0]), 'uint8');     % member 1 uid
            fwrite(fid, uint32([0 2 1]), 'uint32');           % decreasing at member 1
            fwrite(fid, uint8(abs('x')), 'uint8');
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:badOffsets');
        end

        function testTruncatedNameSectionIsRejected(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 1, 1, 4, 1);
            fwrite(fid, uint8([abs('ab') 0 0]), 'uint8');
            fwrite(fid, uint32([0 8]), 'uint32');   % claims 8 name bytes
            fwrite(fid, uint8(abs('xy')), 'uint8'); % holds 2
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:truncated');
        end

        function testTruncatedOffsetTableIsRejected(testCase)
            % Distinct from a truncated name-BYTE section: here the offset
            % table itself is short, so the reader never learns how many
            % name bytes to expect and must not read the members it has as
            % if the file were whole.
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 1, 2, 4, 1);
            fwrite(fid, uint8([abs('ab') 0 0]), 'uint8');
            fwrite(fid, uint8([abs('cd') 0 0]), 'uint8');
            fwrite(fid, uint32([0 1]), 'uint32');   % 2 offsets; 3 are required
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifest(p), ...
                'DID:FileSeries:readSeriesManifest:truncated');
        end

        function testUnwritableDestinationIsAnError(testCase)
            % A manifest that silently fails to write would leave a series
            % whose members cannot be resolved at all.
            p = fullfile(pwd, 'no_such_directory', 'series.manifest');

            testCase.verifyError( ...
                @() did.file.writeSeriesManifest(p, {did.ido.unique_id()}), ...
                'DID:FileSeries:writeSeriesManifest:cannotOpen');
        end

        function testStringUidsAndNamesAreAccepted(testCase)
            % Callers mix char and string; both must write identically.
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, {"abc", ""}, ...
                'sourceNames', {"0/a", ""}, 'uidWidth', 8);
            m = did.file.readSeriesManifest(p);

            testCase.verifyEqual(m.uids, {'abc', ''});
            testCase.verifyEqual(m.sourceNames, {'0/a', ''});
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

        % ---- single-slot reads ---------------------------------------
        %
        % did.file.readSeriesManifestUid is how a member is resolved on the
        % read path: one seek instead of the whole uid block. It must agree
        % with readSeriesManifest slot for slot, or NAME_<i> would resolve to
        % a different file depending on which reader asked.

        function testSingleSlotAgreesWithTheWholeManifest(testCase)
            uids = {did.ido.unique_id(), '', did.ido.unique_id(), ...
                    did.ido.unique_id(), ''};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids);

            m = did.file.readSeriesManifest(p);
            for i = 1:numel(uids)
                [oneUid, count] = did.file.readSeriesManifestUid(p, i);
                testCase.verifyEqual(oneUid, m.uids{i}, ...
                    sprintf('slot %d must match the whole-manifest read', i));
                testCase.verifyEqual(count, m.count);
            end
        end

        function testSingleSlotSkipsTheSourceNameSection(testCase)
            % The name section is unbounded in size and is provenance, not
            % resolution. Reading one uid must not depend on it at all --
            % including when it is present.
            uids  = {did.ido.unique_id(), did.ido.unique_id()};
            names = {'level0/0.0.0', 'level0/0.0.1'};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids, 'sourceNames', names);

            testCase.verifyEqual(did.file.readSeriesManifestUid(p, 2), uids{2});
        end

        function testSlotBeyondTheCountIsEmptyNotAnError(testCase)
            % A sparse series is asked about slots it does not have, and the
            % caller acts on "no such member" -- so it is an answer.
            uids = {did.ido.unique_id()};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids);

            [oneUid, count] = did.file.readSeriesManifestUid(p, 99);
            testCase.verifyEmpty(oneUid);
            testCase.verifyEqual(count, 1, ...
                'the count is reported whether or not the slot exists');
        end

        function testAbsentSlotIsEmpty(testCase)
            uids = {did.ido.unique_id(), '', did.ido.unique_id()};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids);

            testCase.verifyEmpty(did.file.readSeriesManifestUid(p, 2));
        end

        function testSingleSlotHonoursACustomUidWidth(testCase)
            % The offset of slot i is 32 + (i-1)*uid_width, so a reader that
            % assumed 33 would return the wrong bytes for every slot but the
            % first -- and would return something, not nothing.
            uids = {'aaa', 'bbb', 'ccc'};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids, 'uidWidth', 4);

            testCase.verifyEqual(did.file.readSeriesManifestUid(p, 1), 'aaa');
            testCase.verifyEqual(did.file.readSeriesManifestUid(p, 2), 'bbb');
            testCase.verifyEqual(did.file.readSeriesManifestUid(p, 3), 'ccc');
        end

        function testSingleSlotRejectsANonManifest(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w'); fwrite(fid, uint8('NOTAMANIFEST'), 'uint8'); fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 1), ...
                'DID:FileSeries:readSeriesManifestUid:badMagic');
        end

        function testSingleSlotRejectsAnUnsupportedVersion(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 0, 1, 33, 2);
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 1), ...
                'DID:FileSeries:readSeriesManifestUid:badVersion');
        end

        function testSingleSlotRejectsAZeroUidWidth(testCase)
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 0, 1, 0, 1);
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 1), ...
                'DID:FileSeries:readSeriesManifestUid:badUidWidth');
        end

        function testSingleSlotRejectsAHeaderCutShort(testCase)
            % Magic and nothing else. The header fields come back empty, and
            % an empty version must not compare equal to 1 and fall through
            % into the uid block.
            p = testCase.manifestPath();
            fid = fopen(p, 'w'); fwrite(fid, uint8('DIDFSER1'), 'uint8'); fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 1), ...
                'DID:FileSeries:readSeriesManifestUid:truncated');
        end

        function testSingleSlotRejectsAPartialHeader(testCase)
            % Magic, version and flags, but no count or uid_width. The two
            % fields the seek arithmetic is built from are missing.
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            fwrite(fid, uint8('DIDFSER1'), 'uint8');
            fwrite(fid, uint32([1 0]), 'uint32');
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 1), ...
                'DID:FileSeries:readSeriesManifestUid:truncated');
        end

        function testSingleSlotRejectsAShortUidRecord(testCase)
            % The seek lands inside the file but the record runs off the end.
            % Returning the short read as a uid would resolve the member to
            % the wrong file; returning '' would call it absent. Neither is
            % true, so this errors.
            p = testCase.manifestPath();
            fid = fopen(p, 'w', 'ieee-le');
            testCase.writeHeader(fid, 0, 1, 33, 1);
            fwrite(fid, uint8('abc'), 'uint8');   % 3 bytes of a 33-byte record
            fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 1), ...
                'DID:FileSeries:readSeriesManifestUid:truncated');
        end

        function testSingleSlotRejectsATruncatedFile(testCase)
            % The header promises three members; the file holds one. Reading
            % slot 3 must say so rather than returning '' , which the caller
            % would read as "that member was never written".
            uids = {did.ido.unique_id(), did.ido.unique_id(), did.ido.unique_id()};
            p = testCase.manifestPath();
            did.file.writeSeriesManifest(p, uids);

            fid = fopen(p, 'r'); raw = fread(fid, Inf, '*uint8'); fclose(fid);
            fid = fopen(p, 'w'); fwrite(fid, raw(1:65), 'uint8'); fclose(fid);

            testCase.verifyError(@() did.file.readSeriesManifestUid(p, 3), ...
                'DID:FileSeries:readSeriesManifestUid:truncated');
        end

    end
end
