classdef seriesManifest < matlab.unittest.TestCase
    % SERIESMANIFEST - Read a file series manifest the other language wrote
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/file/test_series_manifest.py.
    %
    % THE HALF THAT WAS MISSING. Both languages have written these manifests
    % since VH-Lab/DID-matlab#173, and DID-python has read both languages'
    % output since then -- but nothing read PYTHON's. So the shared binary
    % format was proven in one direction only, and a DID-python writer that
    % drifted would have been caught by nothing: its own reader agrees with
    % it by construction.
    %
    % The symmetry job's honesty gates could not see the hole either. They
    % fail on a SKIP, or on an artifact missing for a test that exists; a
    % reader nobody wrote is neither, so nSkipped == 0 and nPassed > 0 both
    % passed while this leg compared nothing.
    %
    % A member has no file_info entry and no files-table row, so the manifest
    % is the only record of its uid. A reader that is even slightly wrong
    % resolves a member to the wrong file -- and because a uid names a cache
    % slot, the wrong file is the failure no later read can detect.
    % docs/notes/file_series_manifest.md is the spec.
    %
    % The five artifacts are described in the makeArtifacts half: dense,
    % sparse, named (the empty-name edges), allEmpty and wideUid. This reads
    % whichever language produced them.
    %
    % Manifests are copied out of the artifact directory before being opened,
    % so this cannot disturb an artifact the other language has yet to read.
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

    methods (Static)
        function c = rowCell(v)
            % Normalize a jsondecode result to a 1xN cell of char.
            %
            % jsondecode gives an Nx1 cell for a JSON array of strings, [] for
            % an empty array, and a bare char for a one-element array; the
            % readers return 1xN. Without this the comparisons below would
            % fail on orientation rather than on content.
            if isempty(v)
                c = {};
            elseif iscell(v)
                c = reshape(v, 1, []);
            elseif ischar(v)
                c = {v};
            else
                c = num2cell(reshape(v, 1, []));
            end
        end
    end

    methods
        function verifyStringCell(testCase, actual, expected, label)
            % Compare cells of char by CONTENT.
            %
            % verifyEqual would compare dimensions too, and an absent member's
            % uid is the empty string: jsondecode yields 0x0 char where the
            % reader may yield 1x0. Those are the same uid and a difference in
            % them is not the thing this test is for.
            actual = did.symmetry.readArtifacts.file.seriesManifest.rowCell(actual);
            expected = did.symmetry.readArtifacts.file.seriesManifest.rowCell(expected);
            testCase.verifyEqual(numel(actual), numel(expected), ...
                [label ': wrong number of entries']);
            for i = 1:numel(expected)
                testCase.verifyTrue(strcmp(actual{i}, expected{i}), ...
                    sprintf('%s: entry %d is "%s", expected "%s"', ...
                        label, i, actual{i}, expected{i}));
            end
        end
    end

    methods (Test)
        function testSeriesManifestArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'file', 'seriesManifest', 'testSeriesManifestArtifacts');

            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);
            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            testCase.verifyEqual(manifest.magic, 'DIDFSER1', ...
                'the artifact does not describe a series manifest set');
            testCase.verifyEqual(double(manifest.formatVersion), 1);
            testCase.verifyEqual(manifest.indexBase, 'zero', ...
                ['the uids array is stated in ZERO-based terms; a reader ' ...
                 'that assumed one-based would be off by one everywhere']);

            % Work on a copy: the other language may not have read this yet.
            scratch = fullfile(pwd, 'seriesManifest');
            copyfile(artifactDir, scratch);

            % jsondecode gives a struct array for a homogeneous list and a
            % cell array otherwise -- and this list is NOT homogeneous, since
            % sourceNames is [] for some entries and a list for others.
            entries = manifest.files;
            if ~iscell(entries)
                entries = num2cell(entries);
            end
            testCase.assertNotEmpty(entries, ...
                [SourceType ' recorded no manifests, so this compared nothing']);

            for k = 1:numel(entries)
                e = entries{k};
                thisPath = fullfile(scratch, e.file);
                testCase.assertTrue(isfile(thisPath), ...
                    [SourceType ' names a manifest it did not write: ' e.file]);

                m = did.file.readSeriesManifest(thisPath);

                testCase.verifyEqual(double(m.count), double(e.count), ...
                    [e.name ': slot count']);
                testCase.verifyEqual(double(m.uidWidth), double(e.uidWidth), ...
                    [e.name ': uid_width is a HEADER FIELD, not the constant ' ...
                     '33 that did.ido.unique_id happens to produce -- every ' ...
                     'slot offset is computed from it']);
                testCase.verifyStringCell(m.uids, e.uids, [e.name ' uids']);
                testCase.verifyEqual(logical(m.hasSourceNames), ...
                    logical(e.hasSourceNames), ...
                    [e.name ': "no name section" and "a section of nothing" ' ...
                     'are different files and different flags']);

                if e.hasSourceNames
                    testCase.verifyStringCell(m.sourceNames, e.sourceNames, ...
                        [e.name ' sourceNames']);
                else
                    testCase.verifyEmpty(m.sourceNames, ...
                        [e.name ': no name section means no names']);
                end

                % The O(1) slot read must agree with the whole-file read for
                % every slot, absent ones included. That path is the reason
                % this format was chosen over inline file_info, so a reader
                % that has the two disagree -- most easily by mis-computing
                % 32 + i*uid_width -- has given the property away while still
                % passing a whole-file read.
                expectedUids = did.symmetry.readArtifacts.file.seriesManifest.rowCell(e.uids);
                for slot = 1:double(e.count)
                    [u, c] = did.file.readSeriesManifestUid(thisPath, slot);
                    testCase.verifyTrue(strcmp(u, expectedUids{slot}), ...
                        sprintf('%s slot %d: read "%s", expected "%s"', ...
                            e.name, slot, u, expectedUids{slot}));
                    testCase.verifyEqual(double(c), double(e.count), ...
                        sprintf('%s slot %d: count', e.name, slot));
                end

                % One past the end is a miss, not an error: a document may
                % name NAME_<i> for an i the series never had.
                testCase.verifyEmpty( ...
                    did.file.readSeriesManifestUid(thisPath, double(e.count)+1), ...
                    [e.name ': one past the end must be a miss']);
            end
        end
    end
end
