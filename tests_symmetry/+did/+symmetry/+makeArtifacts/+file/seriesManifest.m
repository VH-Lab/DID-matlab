classdef seriesManifest < matlab.unittest.TestCase
    % SERIESMANIFEST - Generate file series manifests the other language must read
    %
    % The second shared BINARY format, after '.fileCacheInfo'. A series
    % member has no file_info entry and no files-table row: the manifest is
    % the only record of its uid, so a port that reads these bytes even
    % slightly differently resolves members to the wrong file or to none --
    % and, because a uid names a cache slot, the wrong file is the failure
    % that no later read can detect.
    %
    % docs/notes/file_series_manifest.md is the spec. Both languages must
    % agree on it exactly, as they had to for '.fileCacheInfo' and
    % '<file>-lock'. See VH-Lab/DID-python#64 section 3, which marks this a
    % cross-language contract rather than an ordinary port.
    %
    % WHAT EACH FILE IS FOR. Not one manifest but five, because the parts of
    % this format that are easy to get wrong are not exercised by an
    % ordinary one:
    %
    %   dense    - the baseline. Header fields, and member i at
    %              32 + i*uid_width with no name section (flags bit 0 clear).
    %   sparse   - absent members as all-NUL uid records. A series IS sparse:
    %              a zarr level never writes an all-fill chunk. A reader that
    %              treats NUL padding as content, or that compacts the array,
    %              resolves every later member to its neighbour.
    %   named    - the name section, with the empty-name EDGES: first empty,
    %              an interior run, last empty. Offsets are zero-based and
    %              half-open, so an empty name has EQUAL offsets -- and
    %              "equal" against "decreasing" is the comparison DID-matlab
    %              itself got wrong (commit 5780144: every empty name raised
    %              badOffsets, and the empty-name branch was unreachable).
    %              It went wrong precisely by converting to one-based first,
    %              which is the shortcut a port is most likely to take.
    %   allEmpty - the name section present but every name empty. Degenerate,
    %              and it separates "no name section" from "a section of
    %              nothing", which are different files and different flags.
    %   wideUid  - uid_width 40, with uids that actually use all 40. It is a
    %              HEADER FIELD, not the constant 33 that did.ido.unique_id
    %              happens to produce. A port that hardcodes 33 passes every
    %              other file here and fails only this one.
    %
    % Slots are ONE-BASED in this file, as they are throughout the MATLAB
    % API, and ZERO-BASED on disk. manifest.json states everything in the
    % file's own zero-based terms so the reader never has to guess which
    % convention a number is in.

    properties (Constant)
        artifactNames = {'dense', 'sparse', 'named', 'allEmpty', 'wideUid'}
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
        function u = uidOf(index, width)
            % A deterministic uid exactly WIDTH characters wide. Digits only,
            % so it is safe as a basename under did.file.isSafeUid and
            % identical in both languages without any encoding question.
            if nargin < 2, width = 33; end
            u = sprintf(['%0' int2str(width) 'd'], index);
        end
    end

    methods (Test)
        function testSeriesManifestArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'file', 'seriesManifest', ...
                'testSeriesManifestArtifacts');
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % --- dense: four members, no name section --------------------
            spec = struct();
            spec.dense.uids       = {uid(1), uid(2), uid(3), uid(4)};
            spec.dense.names      = {};
            spec.dense.uidWidth   = 33;

            % --- sparse: six slots, members present at 2, 5 and 6 --------
            % The gaps are at the first slot, an interior pair and nothing at
            % the end, so a reader that drops or shifts absents lands on a
            % different member for every present one.
            spec.sparse.uids      = {'', uid(12), '', '', uid(15), uid(16)};
            spec.sparse.names     = {};
            spec.sparse.uidWidth  = 33;

            % --- named: the empty-name edges -----------------------------
            % Slot 1 empty (first), slots 3 and 4 empty (an interior run),
            % slot 6 empty (last). Slots 2 and 5 carry names, and both keep a
            % subfolder: a bare basename would lose which level of a pyramid
            % a chunk came from, which is why relative names are stored.
            spec.named.uids       = {uid(21), uid(22), uid(23), ...
                                     uid(24), uid(25), uid(26)};
            spec.named.names      = {'', '0/0.1.2.3', '', '', '1/4.5.6.7', ''};
            spec.named.uidWidth   = 33;

            % --- allEmpty: a name section of nothing ---------------------
            spec.allEmpty.uids    = {uid(31), uid(32), uid(33)};
            spec.allEmpty.names   = {'', '', ''};
            spec.allEmpty.uidWidth = 33;

            % --- wideUid: uid_width 40, fully used -----------------------
            spec.wideUid.uids     = {uid(41, 40), uid(42, 40), uid(43, 40)};
            spec.wideUid.names    = {};
            spec.wideUid.uidWidth = 40;

            names = testCase.artifactNames;
            files = struct('name', {}, 'file', {}, 'count', {}, ...
                'uidWidth', {}, 'hasSourceNames', {}, 'uids', {}, ...
                'sourceNames', {});

            for k = 1:numel(names)
                thisName = names{k};
                thisSpec = spec.(thisName);
                fileName = [thisName '.manifest'];
                fullPath = fullfile(artifactDir, fileName);

                if isempty(thisSpec.names)
                    did.file.writeSeriesManifest(fullPath, thisSpec.uids, ...
                        'uidWidth', thisSpec.uidWidth);
                else
                    did.file.writeSeriesManifest(fullPath, thisSpec.uids, ...
                        'sourceNames', thisSpec.names, ...
                        'uidWidth', thisSpec.uidWidth);
                end

                files(k).name           = thisName;
                files(k).file           = fileName;
                files(k).count          = numel(thisSpec.uids);
                files(k).uidWidth       = thisSpec.uidWidth;
                files(k).hasSourceNames = ~isempty(thisSpec.names);
                % Stated in the file's own ZERO-BASED terms: entry j of this
                % array is member j-1 on disk. The reader should not have to
                % work out which convention a number arrived in.
                files(k).uids           = thisSpec.uids;
                if isempty(thisSpec.names)
                    files(k).sourceNames = {};
                else
                    files(k).sourceNames = thisSpec.names;
                end
            end

            manifest = struct( ...
                'magic', 'DIDFSER1', ...
                'formatVersion', 1, ...
                'indexBase', 'zero', ...
                'files', files);
            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest));
            fclose(fid);

            % --- self-check ----------------------------------------------
            % Confirm what is claimed before any cross-language claim rests
            % on it, exactly as the fileCache artifact does.
            for k = 1:numel(names)
                thisSpec = spec.(names{k});
                fullPath = fullfile(artifactDir, [names{k} '.manifest']);

                m = did.file.readSeriesManifest(fullPath);
                testCase.verifyEqual(m.count, numel(thisSpec.uids), names{k});
                testCase.verifyEqual(m.uidWidth, thisSpec.uidWidth, names{k});
                testCase.verifyEqual(m.uids, thisSpec.uids, names{k});
                testCase.verifyEqual(m.hasSourceNames, ~isempty(thisSpec.names), ...
                    names{k});
                if isempty(thisSpec.names)
                    testCase.verifyEmpty(m.sourceNames, names{k});
                else
                    testCase.verifyEqual(m.sourceNames, thisSpec.names, names{k});
                end

                % The O(1) slot read must agree with the whole-file read for
                % every slot. That path is the reason this format was chosen
                % over inline file_info, so a port that has it disagree --
                % most easily by mis-computing 32 + i*uid_width -- has given
                % away the property while still passing a whole-file read.
                for slot = 1:numel(thisSpec.uids)
                    [u, c] = did.file.readSeriesManifestUid(fullPath, slot);
                    testCase.verifyEqual(u, thisSpec.uids{slot}, ...
                        sprintf('%s slot %d', names{k}, slot));
                    testCase.verifyEqual(c, numel(thisSpec.uids), names{k});
                end

                % One past the end is a miss, not an error: a document may
                % name NAME_<i> for an i the series never had.
                testCase.verifyEmpty( ...
                    did.file.readSeriesManifestUid(fullPath, numel(thisSpec.uids)+1), ...
                    names{k});
            end

            function u = uid(index, width)
                % Forwards to the static, so the rule lives in one place and
                % a readArtifacts half can use the same one.
                if nargin < 2, width = 33; end
                u = did.symmetry.makeArtifacts.file.seriesManifest.uidOf(index, width);
            end
        end
    end
end
