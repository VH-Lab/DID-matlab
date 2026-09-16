classdef fileSeriesDocument < matlab.unittest.TestCase
    % FILESERIESDOCUMENT - A database holding an ingested file series
    %
    % The fileDocument pair covers a document whose files each have a
    % files-table row. A SERIES member deliberately has none: it is resolved
    % through the manifest, and reproducing that is the whole point of the
    % feature (VH-Lab/DID-matlab#173). A port could make member reads "work"
    % by giving each member a row and would pass a naive read-back test while
    % putting back the ~8-11 MB of per-member JSON the manifest exists to
    % remove. So this artifact pins the ABSENCE as hard as it pins the bytes.
    %
    % Four things are recorded here that a port has to reproduce, and that
    % nothing else in the symmetry suite would catch:
    %
    %   1. members land at <FileDir>/<uid>, under the uid the manifest gives
    %      that slot -- the pairing the ingest side and the read side share;
    %   2. the files table holds ONE row, the manifest's, and no member's;
    %   3. the stored document JSON keeps files.series_info with
    %      ingest_locations present but EMPTY, not removed. DID-matlab used
    %      rmfield here and it was wrong (commit 87ebcf6): a stored document
    %      then had a narrower struct than a fresh one, and adding a series
    %      to it failed at runtime much later. A port using `del` instead of
    %      an empty list rediscovers exactly that;
    %   4. NAME_<i> is ONE-based in a document and ZERO-based in the
    %      manifest. The series here is SPARSE, so an off-by-one resolves a
    %      present member to a gap or to its neighbour rather than merely
    %      shifting everything.
    %
    % Deliberately no customFileHandler and nothing remote: retrieval needs a
    % live handler and cannot be a static artifact. What is checkable without
    % one is the layout the handler would place bytes into, which is what
    % this records.

    properties (Constant)
        dbFilename = 'file_series_document_test.sqlite'
        branchName = 'branch_main'
        % demoSeries declares 'chunkdata.bin' as a series and 'plainfile.ext'
        % as an ordinary file.
        seriesName = 'chunkdata.bin'
        % A sparse series: six slots, members present at 2, 5 and 6 only.
        % Gaps at the first slot and at an interior pair.
        presentSlots = [2 5 6]
        slotCount = 6
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
        function b = bytesOf(slot)
            % Member at SLOT holds ten bytes starting at slot*10, so a
            % resolution that returns the wrong member is a failure rather
            % than a pass. Distinct from the manifest's own bytes too.
            b = uint8(slot*10 + (0:9));
        end
    end

    methods (Test)
        function testFileSeriesDocumentArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'database', 'fileSeriesDocument', ...
                'testFileSeriesDocumentArtifacts'); %#ok<*PROPLC>

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            dbPath = fullfile(artifactDir, testCase.dbFilename);
            db = did.implementations.sqlitedb(dbPath);
            db.add_branch(testCase.branchName);

            % Write the members where addFileSeries will find them. They keep
            % a common parent so the manifest records a relative source name
            % per member rather than none.
            sourceRoot = fullfile(artifactDir, 'members');
            mkdir(sourceRoot);
            slots = testCase.presentSlots;
            locs = cell(1, numel(slots));
            for i = 1:numel(slots)
                locs{i} = fullfile(sourceRoot, sprintf('chunk_%d.bin', slots(i)));
                fid = fopen(locs{i}, 'w');
                testCase.assertNotEqual(fid, -1, ['Could not create ' locs{i}]);
                fwrite(fid, ...
                    did.symmetry.makeArtifacts.database.fileSeriesDocument.bytesOf(slots(i)), ...
                    'uint8');
                fclose(fid);
            end

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            % deleteOriginal 0 so the sources stay in the artifact for a
            % reader that wants to compare against them directly.
            doc = doc.addFileSeries(testCase.seriesName, locs, ...
                'indices', slots, 'deleteOriginal', 0);

            % Capture what the manifest recorded BEFORE add_docs, since
            % ingest_locations is stripped on the way in.
            entries = doc.seriesIngestLocations(testCase.seriesName);
            memberUids = repmat({''}, 1, testCase.slotCount);
            for i = 1:numel(entries)
                memberUids{entries(i).index} = entries(i).uid;
            end
            manifestUids = doc.fileUids(testCase.seriesName);
            manifestUid = manifestUids{1};

            db.add_docs(doc);

            % --- the manifest for the reader -----------------------------
            members = struct('slot', {}, 'uid', {}, 'filename', {}, 'bytes', {});
            for i = 1:numel(slots)
                members(i).slot = slots(i);
                members(i).uid = memberUids{slots(i)};
                members(i).filename = sprintf('%s_%d', testCase.seriesName, slots(i));
                members(i).bytes = double( ...
                    did.symmetry.makeArtifacts.database.fileSeriesDocument.bytesOf(slots(i)));
            end
            absent = setdiff(1:testCase.slotCount, slots);
            absentNames = cell(1, numel(absent));
            for i = 1:numel(absent)
                absentNames{i} = sprintf('%s_%d', testCase.seriesName, absent(i));
            end

            artifact = struct();
            artifact.dbFilename = testCase.dbFilename;
            artifact.branchName = testCase.branchName;
            artifact.docId = doc.id();
            artifact.seriesName = testCase.seriesName;
            artifact.slotCount = testCase.slotCount;
            artifact.manifestUid = manifestUid;
            % Where the bytes are, relative to the database file, so a reader
            % need not know how FileDir is derived to find them.
            artifact.fileDirRelative = 'files';
            artifact.members = members;
            % These names parse as members and the manifest records no uid
            % for them: exist_doc must answer false and must NOT resolve them
            % to a neighbouring slot.
            artifact.absentMemberNames = absentNames;
            % A files-table row per member is what this design refuses. The
            % reader asserts the count, not just the manifest's presence.
            artifact.expectedFilesTableFilenames = {testCase.seriesName};
            % Present-but-empty, never absent. See commit 87ebcf6.
            artifact.storedIngestLocationsAreEmptyNotAbsent = true;

            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(artifact, 'PrettyPrint', true));
            fclose(fid);

            % --- self-check ----------------------------------------------
            % Everything claimed above, verified here before any
            % cross-language claim rests on it.

            % 1. every present member reads back byte for byte, by name.
            for i = 1:numel(slots)
                name = sprintf('%s_%d', testCase.seriesName, slots(i));
                testCase.assertTrue(db.exist_doc(doc.id(), name), ...
                    ['Member ' name ' was not ingested.']);
                f = db.open_doc(doc.id(), name);
                fopen(f);
                testCase.assertGreaterThan(f.fid, 0, ['Could not open ' name]);
                data = fread(f, Inf, 'uint8');
                fclose(f);
                testCase.verifyEqual(data(:)', ...
                    double(did.symmetry.makeArtifacts.database.fileSeriesDocument.bytesOf(slots(i))), ...
                    ['Wrong bytes for ' name]);
            end

            % 2. the gaps answer false, and do not resolve to a neighbour.
            for i = 1:numel(absent)
                testCase.verifyFalse( ...
                    db.exist_doc(doc.id(), absentNames{i}), ...
                    ['An absent slot resolved: ' absentNames{i}]);
            end

            % 3. members land at <FileDir>/<uid>.
            for i = 1:numel(slots)
                testCase.verifyTrue( ...
                    isfile(fullfile(db.FileDir, memberUids{slots(i)})), ...
                    sprintf('member %d is not at FileDir/<uid>', slots(i)));
            end

            % 4. one files-table row, the manifest's. THE design decision.
            rows = db.run_sql_query(['SELECT filename FROM docs,files ' ...
                ' WHERE docs.doc_id="' doc.id() '" ' ...
                '   AND files.doc_idx=docs.doc_idx'], true);
            testCase.verifyEqual({rows.filename}, {testCase.seriesName}, ...
                'a member must not get a files-table row of its own');

            % 5. the stored document keeps series_info with ingest_locations
            %    empty rather than removed.
            stored = db.get_docs(doc.id());
            storedSeries = stored.document_properties.files.series_info;
            testCase.assertTrue(isfield(storedSeries, 'ingest_locations'), ...
                'ingest_locations must be present, not removed (87ebcf6)');
            k = find(strcmpi(testCase.seriesName, {storedSeries.name}));
            testCase.assertNotEmpty(k, 'the stored document lost its series');
            testCase.verifyEmpty(storedSeries(k(1)).ingest_locations, ...
                'ingest_locations must be empty in a stored document');

            % 6. the manifest itself is still an ordinary file of the
            %    document, readable under the series' own name.
            f = db.open_doc(doc.id(), testCase.seriesName);
            fopen(f);
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>
            testCase.verifyEqual(char(fread(f, 8, 'uint8')'), 'DIDFSER1', ...
                'opening the series name must give the manifest itself');
        end
    end
end
