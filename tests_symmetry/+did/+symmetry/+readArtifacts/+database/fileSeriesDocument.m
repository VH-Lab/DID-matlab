classdef fileSeriesDocument < matlab.unittest.TestCase
    % FILESERIESDOCUMENT - Open a file series the other language ingested
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/database/test_file_series_document.py.
    %
    % What this proves that no single-language test can: that the two
    % implementations agree about a series they did not both build. A member
    % has no files-table row and no file_info entry of its own, so resolving
    % one is entirely a matter of reading the OTHER language's manifest and
    % believing what it says about slots and uids. Get the slot base wrong,
    % or the uid offset, and a member resolves to its neighbour -- which is a
    % pass to any test that only checks that SOMETHING came back.
    %
    % The makeArtifacts half has written this artifact since #173 and nothing
    % read it. The symmetry job's gates could not see that: they fail on a
    % SKIP, or on an artifact missing for a test that EXISTS, and a reader
    % nobody wrote is neither.
    %
    % The series is SPARSE (slots 2, 5 and 6 of 6) and every member's bytes
    % are distinct, so an off-by-one lands on a gap or a neighbour rather
    % than shifting everything uniformly, and a wrong resolution fails rather
    % than passing.
    %
    % The artifact directory is copied before the database is opened: the
    % member bytes live in FileDir beside the database file, so the whole
    % directory goes, and the other language may not have read it yet.
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
        function testFileSeriesDocumentArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'database', 'fileSeriesDocument', 'testFileSeriesDocumentArtifacts');

            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);
            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            % Work on a copy, and take the WHOLE directory: the member bytes
            % live in FileDir beside the database, not inside it.
            scratch = fullfile(pwd, 'fileSeriesDocument');
            copyfile(artifactDir, scratch);

            dbPath = fullfile(scratch, manifest.dbFilename);
            testCase.assumeTrue(isfile(dbPath), ['Database file not found: ' dbPath]);

            db = did.implementations.sqlitedb(dbPath);
            docId = manifest.docId;
            seriesName = manifest.seriesName;

            doc = db.get_docs(docId, 'OnMissing', 'ignore');
            testCase.assertNotEmpty(doc, ...
                ['Document ' docId ' from ' SourceType ' not found.']);
            testCase.verifyTrue(doc.isFileSeries(seriesName), ...
                ['the document from ' SourceType ' lost its series declaration']);

            members = manifest.members;
            if ~iscell(members)
                members = num2cell(members);
            end
            testCase.assertNotEmpty(members, ...
                [SourceType ' recorded no members, so this compared nothing']);

            % --- 1. every present member reads back byte for byte ---------
            % BY NAME, so the whole NAME_<i> -> manifest slot -> uid -> bytes
            % chain is exercised. That chain has a one-based/zero-based
            % boundary in the middle of it.
            for i = 1:numel(members)
                m = members{i};
                expected = double(m.bytes(:))';

                [tf, thisPath] = db.exist_doc(docId, m.filename);
                testCase.verifyTrue(logical(tf), ...
                    [SourceType ': member ' m.filename ' did not resolve']);
                [~, base, ext] = fileparts(thisPath);
                testCase.verifyEqual([base ext], m.uid, ...
                    [m.filename ' resolved to a file not named by the ' ...
                     'manifest''s uid for that slot']);

                f = db.open_doc(docId, m.filename);
                fopen(f);
                closer = onCleanup(@() fclose(f)); %#ok<NASGU>
                data = fread(f, Inf, 'uint8');
                clear closer;
                testCase.verifyEqual(data(:)', expected, ...
                    [SourceType ': wrong bytes for ' m.filename ' -- a slot ' ...
                     'or uid offset that is off by one lands on a neighbour']);
            end

            % --- 2. the gaps answer false, and never a neighbour ----------
            absent = manifest.absentMemberNames;
            if ~iscell(absent)
                absent = {absent};
            end
            for i = 1:numel(absent)
                testCase.verifyFalse(logical(db.exist_doc(docId, absent{i})), ...
                    [SourceType ': absent slot ' absent{i} ' resolved to something']);
            end

            % --- 3. members are at FileDir/<uid> --------------------------
            fileDir = fullfile(scratch, manifest.fileDirRelative);
            for i = 1:numel(members)
                testCase.verifyTrue(isfile(fullfile(fileDir, members{i}.uid)), ...
                    sprintf('%s: member at slot %g is not at FileDir/<uid>', ...
                        SourceType, double(members{i}.slot)));
            end

            % --- 4. one files-table row, the manifest's -------------------
            % THE design decision: 28,000 members must not become 28,000
            % rows. A port that "fixed" member reads by giving each one a row
            % would pass every other check here.
            rows = db.run_sql_query(['SELECT filename FROM docs,files ' ...
                ' WHERE docs.doc_id="' docId '" ' ...
                '   AND files.doc_idx=docs.doc_idx'], true);
            expectedFilenames = manifest.expectedFilesTableFilenames;
            if ~iscell(expectedFilenames)
                expectedFilenames = {expectedFilenames};
            end
            testCase.verifyEqual(sort({rows.filename}), sort(expectedFilenames(:)'), ...
                [SourceType ': a series member must not get a files-table ' ...
                 'row of its own']);

            % --- 5. ingest_locations present but empty, never removed -----
            if isfield(manifest, 'storedIngestLocationsAreEmptyNotAbsent') && ...
                    manifest.storedIngestLocationsAreEmptyNotAbsent
                storedSeries = doc.document_properties.files.series_info;
                testCase.assertTrue(isfield(storedSeries, 'ingest_locations'), ...
                    [SourceType ': ingest_locations was REMOVED from the ' ...
                     'stored document rather than emptied. A document read ' ...
                     'back then has a narrower shape than a fresh one, and ' ...
                     'adding a series to it fails much later (87ebcf6)']);
                k = find(strcmpi(seriesName, {storedSeries.name}), 1);
                testCase.assertNotEmpty(k, ...
                    [SourceType ': the stored document lost its series']);
                testCase.verifyEmpty(storedSeries(k).ingest_locations, ...
                    [SourceType ': a stored document must not carry member ' ...
                     'source paths']);
            end

            % --- 6. the manifest is still an ordinary file ----------------
            f = db.open_doc(docId, seriesName);
            fopen(f);
            closer2 = onCleanup(@() fclose(f)); %#ok<NASGU>
            magic = char(fread(f, 8, 'uint8')');
            clear closer2;
            testCase.verifyEqual(magic, 'DIDFSER1', ...
                [SourceType ': opening the series name must give the ' ...
                 'manifest itself']);

            % --- 7. the accessors agree with the manifest -----------------
            [indices, uids] = db.seriesMembers(doc, seriesName);
            expectedSlots = zeros(1, numel(members));
            for i = 1:numel(members)
                expectedSlots(i) = double(members{i}.slot);
            end
            testCase.verifyEqual(double(indices(:)'), expectedSlots, ...
                [SourceType ': seriesMembers disagrees with the recorded slots']);
            for i = 1:numel(members)
                testCase.verifyTrue(strcmp(uids{i}, members{i}.uid), ...
                    sprintf('%s: seriesMembers uid %d', SourceType, i));
                testCase.verifyTrue( ...
                    db.seriesHas(doc, seriesName, expectedSlots(i)), ...
                    sprintf('%s: seriesHas says slot %g is empty', ...
                        SourceType, expectedSlots(i)));
            end
            for slot = 1:double(manifest.slotCount)
                if ~any(expectedSlots == slot)
                    testCase.verifyFalse(db.seriesHas(doc, seriesName, slot), ...
                        sprintf('%s: seriesHas claims a member at empty slot %d', ...
                            SourceType, slot));
                end
            end
        end
    end
end
