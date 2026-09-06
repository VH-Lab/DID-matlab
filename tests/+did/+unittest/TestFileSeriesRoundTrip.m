classdef TestFileSeriesRoundTrip < matlab.unittest.TestCase
    % Ingest a file series and read its members back, byte for byte.
    %
    % TestDocumentFileSeries covers what a document RECORDS about a series and
    % TestSeriesManifest covers the manifest format. Neither of them, and
    % nothing else in either repo, ever opened a member and read its bytes --
    % because until now nothing could: addFileSeries recorded where the members
    % were, and no code copied them anywhere or resolved NAME_<i> to anything.
    %
    % So this suite is the one that fails if the feature is not actually
    % wired up end to end. It mirrors
    % ndi.unittest.cloud.FileSeriesRoundTripTest/testMembersSurviveTheRoundTrip,
    % which gates on database_existbinarydoc(doc.id(), 'chunkdata.bin_1') and
    % then compares bytes.
    %
    % See VH-Lab/DID-matlab#173.

    properties (Constant)
        db_filename = 'fileseriesroundtripdb.sqlite'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function p = writeMember(~, folder, name, bytes)
            % Write one member's bytes, creating FOLDER if needed.
            if ~isfolder(folder), mkdir(folder); end
            p = fullfile(folder, name);
            fid = fopen(p, 'w');
            fwrite(fid, uint8(bytes), 'uint8');
            fclose(fid);
        end

        function [db, doc, locs, contents] = ingestedSeries(testCase, indices)
            % A three-member series, ingested. Each member holds different
            % bytes, so a resolution that returns the WRONG member is a
            % failure rather than a pass.
            if nargin < 2, indices = []; end

            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            root = fullfile(pwd, 'store');
            contents = {uint8(1:10), uint8(11:20), uint8(21:30)};
            locs = cell(1, numel(contents));
            for i = 1:numel(contents)
                locs{i} = testCase.writeMember(root, sprintf('member%d.bin', i), contents{i});
            end

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            if isempty(indices)
                doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);
            else
                doc = doc.addFileSeries('chunkdata.bin', locs, ...
                    'indices', indices, 'deleteOriginal', 0);
            end
            db.add_docs(doc);
        end

        function bytes = readMember(testCase, db, doc_id, name)
            % Open a member through the database and read all of it.
            f = db.open_doc(doc_id, name);
            fopen(f);
            testCase.assertGreaterThan(f.fid, 0, ...
                ['Could not open series member ' name '.']);
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>
            bytes = uint8(fread(f, Inf, 'uint8')');
        end
    end

    methods (Test)

        % ---- the acceptance case --------------------------------------

        function testMembersSurviveTheRoundTrip(testCase)
            % THE TEST THE WHOLE CHANGE EXISTS FOR. Write members, ingest
            % them, read each one back and compare bytes.
            [db, doc, ~, contents] = testCase.ingestedSeries();

            for i = 1:numel(contents)
                name = sprintf('chunkdata.bin_%d', i);
                testCase.assertTrue(db.exist_doc(doc.id(), name), ...
                    ['Series member ' name ' was not ingested.']);
                testCase.verifyEqual(testCase.readMember(db, doc.id(), name), ...
                    contents{i}, ...
                    ['Series member ' name ' did not read back byte for byte.']);
            end
        end

        function testEachMemberResolvesToItsOwnBytes(testCase)
            % A resolution that is off by one, or that returns the manifest,
            % or that returns whichever member happens to be first, would
            % still pass a test that only checked that SOMETHING came back.
            [db, doc, ~, contents] = testCase.ingestedSeries();

            first  = testCase.readMember(db, doc.id(), 'chunkdata.bin_1');
            second = testCase.readMember(db, doc.id(), 'chunkdata.bin_2');
            third  = testCase.readMember(db, doc.id(), 'chunkdata.bin_3');

            testCase.verifyEqual(first,  contents{1});
            testCase.verifyEqual(second, contents{2});
            testCase.verifyEqual(third,  contents{3});
            testCase.verifyNotEqual(first, second);
        end

        function testMembersLandUnderTheirManifestUid(testCase)
            % The pairing the ingest side and the read side share. If a member
            % were stored under any other name, the manifest would point at
            % nothing.
            [db, doc] = testCase.ingestedSeries();

            [~, manifestPath] = db.exist_doc(doc.id(), 'chunkdata.bin');
            testCase.assertNotEmpty(manifestPath, ...
                'precondition: the manifest itself must be ingested');
            m = did.file.readSeriesManifest(manifestPath);

            for i = 1:m.count
                testCase.verifyTrue(isfile(fullfile(db.FileDir, m.uids{i})), ...
                    sprintf('member %d is not at FileDir/<uid>', i));
            end
        end

        % ---- the design decision, asserted -----------------------------

        function testMembersGetNoFilesTableRow(testCase)
            % Manifest resolution, not per-member rows. This is the choice the
            % feature exists to make: 28,000 members of a lightsheet pyramid
            % level must not become 28,000 rows. A change that "fixed" the
            % read path by giving members rows would pass every other test
            % here and quietly undo the feature, so it is pinned.
            [db, doc] = testCase.ingestedSeries();

            rows = db.run_sql_query(['SELECT filename FROM docs,files ' ...
                ' WHERE docs.doc_id="' doc.id() '" AND files.doc_idx=docs.doc_idx'], true);
            names = {rows.filename};

            testCase.verifyTrue(any(strcmp(names, 'chunkdata.bin')), ...
                'the manifest is an ordinary file and keeps its row');
            testCase.verifyFalse(any(strcmp(names, 'chunkdata.bin_1')), ...
                'a member must not get a files-table row of its own');
            testCase.verifyEqual(numel(names), 1, ...
                'the manifest is the only files row this document needs');
        end

        function testStoredDocumentCarriesNoMemberPaths(testCase)
            % Ingestion reads the member paths and the stored JSON must not
            % keep them. Asserted after a real add_docs rather than on
            % stripSeriesIngestLocations in isolation.
            [db, doc, locs] = testCase.ingestedSeries();

            stored = db.get_docs(doc.id());
            json = did.datastructures.jsonencodenan(stored.document_properties);
            for i = 1:numel(locs)
                testCase.verifyEmpty(strfind(json, locs{i}), ...
                    'a member path must not reach the stored document');
            end
        end

        function testStoredDocumentStillResolvesItsMembers(testCase)
            % The document as it comes BACK from the database -- ingest
            % locations stripped -- must still resolve a member. Everything
            % needed is the declaration plus the manifest, which is exactly
            % the claim the stripping rests on.
            [db, doc, ~, contents] = testCase.ingestedSeries();

            stored = db.get_docs(doc.id());
            testCase.assertEmpty(stored.seriesIngestLocations('chunkdata.bin'), ...
                'precondition: the stored document has no member paths left');

            [tf, p] = db.cachedPathForFile(stored, 'chunkdata.bin_2');
            testCase.verifyTrue(tf);
            fid = fopen(p, 'r');
            closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
            testCase.verifyEqual(uint8(fread(fid, Inf, 'uint8')'), contents{2});
        end

        % ---- sparse series ---------------------------------------------

        function testSparseSeriesResolvesOnlyThePresentSlots(testCase)
            % The case a NAME_# entry cannot express. Members 2, 5 and 6 of a
            % six-slot series: the gaps must answer "no", and the present ones
            % must answer with their own bytes and not their neighbours'.
            [db, doc, ~, contents] = testCase.ingestedSeries([2 5 6]);

            present = [2 5 6];
            for i = 1:numel(present)
                name = sprintf('chunkdata.bin_%d', present(i));
                testCase.verifyTrue(db.exist_doc(doc.id(), name), name);
                testCase.verifyEqual(testCase.readMember(db, doc.id(), name), ...
                    contents{i}, name);
            end

            for absent = [1 3 4]
                testCase.verifyFalse( ...
                    db.exist_doc(doc.id(), sprintf('chunkdata.bin_%d', absent)), ...
                    'an absent slot must not resolve to a neighbour');
            end
        end

        function testMemberBeyondTheSeriesDoesNotExist(testCase)
            [db, doc] = testCase.ingestedSeries();

            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_99'));
            testCase.verifyError(@() db.open_doc(doc.id(), 'chunkdata.bin_99'), ...
                'DID:SQLITEDB:open', ...
                'a member that does not exist must report the name asked for');
        end

        function testUndeclaredNumberedNameIsStillRejected(testCase)
            % The series rule must not turn every NAME_<n> into a resolvable
            % file. 'plainfile.ext' is declared as an ordinary file, not a
            % series, so 'plainfile.ext_1' is nothing.
            [db, doc] = testCase.ingestedSeries();

            testCase.verifyFalse(db.exist_doc(doc.id(), 'plainfile.ext_1'));
            testCase.verifyError(@() db.open_doc(doc.id(), 'plainfile.ext_1'), ...
                'DID:SQLITEDB:open');
        end

        % ---- the manifest and the members are separate things ------------

        function testManifestIsStillReadableAsAnOrdinaryFile(testCase)
            % A series' declared name is its manifest, an ordinary file in
            % file_list. Nothing about member resolution may change that:
            % code that knows nothing about series still carries it.
            [db, doc] = testCase.ingestedSeries();

            f = db.open_doc(doc.id(), 'chunkdata.bin');
            fopen(f);
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>
            testCase.verifyEqual(char(fread(f, 8, 'uint8')'), 'DIDFSER1', ...
                'opening the series name must give the manifest itself');
        end

        function testExistDocAndCachedPathForFileAgree(testCase)
            % The two resolutions of a member -- one through the database,
            % one from the document in hand -- must give the same file. They
            % differ only in what they need to get there.
            [db, doc] = testCase.ingestedSeries();

            for i = 1:3
                name = sprintf('chunkdata.bin_%d', i);
                [tfExist, pExist]   = db.exist_doc(doc.id(), name);
                [tfCached, pCached] = db.cachedPathForFile(doc, name);
                testCase.verifyTrue(tfExist, name);
                testCase.verifyEqual(tfCached, tfExist, name);
                testCase.verifyEqual(pCached, pExist, name);
            end
        end

        function testCachedPathForFileReachesNoDatabase(testCase)
            % A member must resolve on the fast path too, or iterating a
            % pyramid level -- the case the whole feature exists for -- is
            % back to a query per file. NoQueryDatabase errors on every
            % database operation, so a pass means none was reached.
            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'a.bin', uint8(1:10))};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);

            % Place the manifest and the member where a uid-named root would
            % have them, by hand: this test must not use a real database.
            fileRoot = fullfile(pwd, 'stubFileDir');
            mkdir(fileRoot);
            files = doc.document_properties.files;
            k = find(strcmpi('chunkdata.bin', {files.file_info.name}));
            manifestSource = files.file_info(k(1)).locations(1).location;
            manifestUid    = files.file_info(k(1)).locations(1).uid;
            copyfile(manifestSource, fullfile(fileRoot, manifestUid));

            e = doc.seriesIngestLocations('chunkdata.bin');
            copyfile(e(1).location, fullfile(fileRoot, e(1).uid));

            db = did.test.helper.NoQueryDatabaseWithRoots({fileRoot});
            [tf, p] = db.cachedPathForFile(doc, 'chunkdata.bin_1');

            testCase.verifyTrue(tf);
            testCase.verifyEqual(p, fullfile(fileRoot, e(1).uid));
        end

        % ---- ingest behaviour -------------------------------------------

        function testDeleteOriginalRemovesTheMemberSources(testCase)
            % A series follows add_file: a local file's original is deleted on
            % ingest unless the caller says otherwise. 28,000 sources left
            % behind is the same disk twice.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'a.bin', uint8(1:10)), ...
                    testCase.writeMember(root, 'b.bin', uint8(11:20))};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs);   % default: delete
            db.add_docs(doc);

            for i = 1:numel(locs)
                testCase.verifyFalse(isfile(locs{i}), ...
                    'the member''s original should have been deleted');
            end
            testCase.verifyTrue(db.exist_doc(doc.id(), 'chunkdata.bin_1'), ...
                'and the ingested copy is what is left');
        end

        function testKeepingTheOriginalsLeavesThemAlone(testCase)
            [db, doc, locs] = testCase.ingestedSeries();   % deleteOriginal 0

            for i = 1:numel(locs)
                testCase.verifyTrue(isfile(locs{i}), ...
                    'deleteOriginal 0 must leave every source in place');
            end
            testCase.verifyTrue(db.exist_doc(doc.id(), 'chunkdata.bin_1'));
        end

        function testUrlMembersAreNotIngested(testCase)
            % A URL member is a reference. Nothing is copied for it, and it
            % resolves to nothing locally -- which is the honest answer, not
            % an error.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'a.bin', uint8(1:10)), ...
                    'https://nosuchserver.example/b.bin'};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);
            db.add_docs(doc);

            testCase.verifyTrue(db.exist_doc(doc.id(), 'chunkdata.bin_1'));
            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'), ...
                'nothing was copied in for a URL member');
        end

        function testDocumentWithNoSeriesIsUnaffected(testCase)
            % The ordinary NAME_# convention still resolves from inline
            % file_info, and a document declaring no series is untouched by
            % any of this.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            local = testCase.writeMember(pwd, 'filename1.ext', uint8(1:10));
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);
            db.add_docs(doc);

            testCase.verifyTrue(db.exist_doc(doc.id(), 'filename1.ext'));
            testCase.verifyFalse(db.exist_doc(doc.id(), 'filename1.ext_1'));
        end

    end
end
