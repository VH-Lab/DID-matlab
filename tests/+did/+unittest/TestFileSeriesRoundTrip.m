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

        function [db, doc, contents, manifestCopy] = remoteManifestSeries(testCase)
            % A series whose members are ingested normally but whose MANIFEST
            % is only available remotely -- the shape a downloaded dataset
            % has, and the one that makes open_doc fetch the manifest before
            % it can resolve anything.
            %
            % Built by re-pointing the manifest's location after addFileSeries
            % rather than by faking a download: the manifest is an ordinary
            % file of the document, so remove_file and add_file are all it
            % takes, and MANIFESTCOPY is what a handler will serve.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            root = fullfile(pwd, 'store');
            contents = {uint8(1:10), uint8(11:20), uint8(21:30)};
            locs = cell(1, numel(contents));
            for i = 1:numel(contents)
                locs{i} = testCase.writeMember(root, sprintf('member%d.bin', i), contents{i});
            end

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);

            manifestCopy = fullfile(pwd, 'kept.manifest');
            copyfile(testCase.manifestLocation(doc), manifestCopy);

            doc = doc.remove_file('chunkdata.bin');
            doc = doc.add_file('chunkdata.bin', ...
                'https://nosuchserver.invalid/chunkdata.bin.manifest');

            db.add_docs(doc);
        end

        function doc = remoteMemberDoc(testCase)
            % A one-member series whose member is a remote location marked for
            % ingestion. document_properties is SetAccess=protected, so the
            % edit is made on a copy and a new document built from it -- the
            % same route a document read from JSON takes.
            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'placeholder.bin', uint8(1:10))};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);

            props = doc.document_properties;
            props.files.series_info(1).ingest_locations(1).location = ...
                'https://nosuchserver.invalid/member1.bin';
            props.files.series_info(1).ingest_locations(1).location_type = 'url';
            props.files.series_info(1).ingest_locations(1).ingest = 1;
            props.files.series_info(1).ingest_locations(1).delete_original = 0;
            doc = did.document(props);
        end

        function p = manifestLocation(testCase, doc)
            % Where addFileSeries left the manifest. add_file records the
            % location and does not move it until add_docs runs.
            files = doc.document_properties.files;
            k = find(strcmpi('chunkdata.bin', {files.file_info.name}));
            testCase.assertNotEmpty(k, 'the manifest was not added as a file');
            p = files.file_info(k(1)).locations(1).location;
        end

        function p = localPathOf(~, db, doc, name)
            % The on-disk path of a document's own file, by uid.
            uids = doc.fileUids(name);
            p = did.file.cachedPathForUid(uids{1}, ...
                'additionalRoots', {db.FileDir});
        end

        function [doc, fileRoot] = seriesOnDiskOnly(testCase)
            % A one-member series whose manifest and member sit in a plain
            % directory, with no database anywhere. What the no-query
            % accessors have to work from.
            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'a.bin', uint8(1:10))};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);

            fileRoot = fullfile(pwd, 'stubFileDir');
            if ~isfolder(fileRoot), mkdir(fileRoot); end

            files = doc.document_properties.files;
            k = find(strcmpi('chunkdata.bin', {files.file_info.name}));
            copyfile(files.file_info(k(1)).locations(1).location, ...
                fullfile(fileRoot, files.file_info(k(1)).locations(1).uid));

            e = doc.seriesIngestLocations('chunkdata.bin');
            copyfile(e(1).location, fullfile(fileRoot, e(1).uid));
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

        % ---- when a member cannot be reached ----------------------------

        function testAbsentBytesForARecordedMemberSayWhichProblemItIs(testCase)
            % "does not include a file named chunkdata.bin_2" would send the
            % caller after a naming problem they do not have. The manifest
            % records this member; only its bytes are gone. The two are the
            % same false from exist_doc and must not be the same message from
            % open_doc.
            [db, doc] = testCase.ingestedSeries();

            [~, memberPath] = db.exist_doc(doc.id(), 'chunkdata.bin_2');
            testCase.assertNotEmpty(memberPath, 'precondition: the member was ingested');
            delete(memberPath);

            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'));
            testCase.verifyError(@() db.open_doc(doc.id(), 'chunkdata.bin_2'), ...
                'DID:SQLITEDB:open');

            % The distinction is in the message, so check it rather than the
            % identifier the "no such member" case shares with it.
            try
                db.open_doc(doc.id(), 'chunkdata.bin_2');
                testCase.verifyFail('open_doc should have errored');
            catch err
                testCase.verifySubstring(err.message, 'chunkdata.bin', ...
                    'the message must name the series the member belongs to');
                testCase.verifySubstring(err.message, 'not on this machine');
            end
        end

        function testCorruptManifestIsReportedRatherThanReadAsAnAbsentMember(testCase)
            % A file that is not a readable manifest is a broken series, not a
            % missing member. Reporting it as merely absent would send the
            % caller looking for a file that was never the problem.
            [db, doc] = testCase.ingestedSeries();

            [~, manifestPath] = db.exist_doc(doc.id(), 'chunkdata.bin');
            testCase.assertNotEmpty(manifestPath);
            fid = fopen(manifestPath, 'w');
            fwrite(fid, uint8('NOTAMANIFESTATALL'), 'uint8');
            fclose(fid);

            testCase.verifyWarning( ...
                @() db.exist_doc(doc.id(), 'chunkdata.bin_1'), ...
                'DID:SQLITEDB:FileSeries:BadManifest');

            % The no-query path has no way to report it, so it answers "not
            % here" rather than throwing at a caller iterating a level.
            [tf, p] = db.cachedPathForFile(doc, 'chunkdata.bin_1');
            testCase.verifyFalse(tf);
            testCase.verifyEmpty(p);
        end

        % ---- the cloud shape: a manifest that is not local yet -----------

        function testRemoteManifestIsRetrievedThroughTheHandler(testCase)
            % The case the feature is for. The members are here, the manifest
            % is not, and nothing can be resolved until it is fetched -- so
            % open_doc fetches it, through the same customFileHandler contract
            % every other non-local file uses.
            [db, doc, contents, manifestCopy] = testCase.remoteManifestSeries();

            handler = @(destPath, sourcePath) copyfile(manifestCopy, destPath);
            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', handler);
            fopen(f);
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>

            testCase.verifyEqual(uint8(fread(f, Inf, 'uint8')'), contents{2});
        end

        function testRemoteManifestWithoutAHandlerCannotResolve(testCase)
            % No handler and no local manifest: DID retrieves nothing itself,
            % so there is nothing to resolve the member against.
            [db, doc] = testCase.remoteManifestSeries();

            testCase.verifyError(@() db.open_doc(doc.id(), 'chunkdata.bin_2'), ...
                'DID:SQLITEDB:open');
        end

        function testExistDocDoesNotFetchTheManifest(testCase)
            % check_exist_doc reports what is on this machine. Answering it
            % must not go to the network, so a member whose manifest is only
            % remote is false -- the same answer it already gives for a file
            % whose row exists but whose bytes were never fetched.
            [db, doc] = testCase.remoteManifestSeries();

            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'));
        end

        % ---- ingest behaviour -------------------------------------------

        function testRemoteMemberIsIngestedThroughTheHandler(testCase)
            % A member whose bytes are not a local path is retrieved by the
            % caller's handler, exactly as a file_info location is.
            %
            % The document is built by hand because addFileSeries does not
            % currently mint an ingestable remote member -- it marks a URL
            % ingest 0, following add_file's default. The shape is still a
            % legitimate one for a document to carry (DID-python writes these
            % too), and the ingest loop treats it the same way the file loop
            % does, so it is covered here rather than left to be discovered
            % the first time such a document arrives.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            payload = testCase.writeMember(fullfile(pwd,'src'), 'payload.bin', uint8(1:10));
            doc = testCase.remoteMemberDoc();

            handler = @(destPath, sourcePath) copyfile(payload, destPath);
            testCase.verifyWarningFree( ...
                @() db.add_docs(doc, 'customFileHandler', handler));

            testCase.verifyTrue(db.exist_doc(doc.id(), 'chunkdata.bin_1'));
            f = db.open_doc(doc.id(), 'chunkdata.bin_1');
            fopen(f);
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>
            testCase.verifyEqual(uint8(fread(f, Inf, 'uint8')'), uint8(1:10));
        end

        function testRemoteMemberWithoutAHandlerWarnsButStillAdds(testCase)
            % Nothing can retrieve it, which warns rather than failing the
            % add -- the non-fatal behaviour ingestion has always had.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            doc = testCase.remoteMemberDoc();

            testCase.verifyWarning(@() db.add_docs(doc), 'DID:SQLiteDB:add_doc');
            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_1'), ...
                'nothing was retrieved, so nothing is there');
            testCase.verifyNumElements( ...
                db.search(did.query('', 'isa', 'demoSeries', '')), 1, ...
                'the document should still have been added');
        end


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

        % ---- refusing a series that cannot be ingested --------------------

        function testStoredDocumentCannotBeAddedToAFreshDatabase(testCase)
            % #173's addendum: add_docs must refuse a document whose series
            % has members it cannot locate, rather than storing something
            % broken. A document read back has had its ingest_locations
            % stripped, so a database that has never held it has no way to
            % fill the manifest's uids -- and the member loop would skip them
            % in silence, since an empty list is simply zero passes.
            [db, doc] = testCase.ingestedSeries();
            stored = db.get_docs(doc.id());

            other = did.implementations.sqlitedb('otherdb.sqlite');
            other.add_branch('a');

            testCase.verifyError(@() other.add_docs(stored), ...
                'DID:SQLITEDB:FileSeries:MembersNotLocatable');
        end

        function testRefusalHappensBeforeAnythingIsWritten(testCase)
            % Refusing after the docs row went in would leave the broken
            % document half-stored, which is the state the guard exists to
            % prevent.
            [db, doc] = testCase.ingestedSeries();
            stored = db.get_docs(doc.id());

            other = did.implementations.sqlitedb('otherdb.sqlite');
            other.add_branch('a');
            try
                other.add_docs(stored);
            catch
                % expected; the point is what is left behind
            end

            rows = other.run_sql_query( ...
                ['SELECT doc_id FROM docs WHERE doc_id="' stored.id() '"'], true);
            testCase.verifyEmpty(rows, ...
                'nothing about the refused document should have been written');
        end

        function testTheGuardExemptsADocumentTheDatabaseAlreadyHolds(testCase)
            % The exemption that keeps the guard honest. Re-adding a document
            % this database already holds is ordinary -- its members were
            % ingested when it first arrived, so an empty ingest_locations is
            % expected there, not a fault.
            %
            % Reaching the DUPLICATE_DOC check is the proof: had the guard
            % fired it would have raised MembersNotLocatable first, since it
            % sits above that check and above every write.
            [db, doc] = testCase.ingestedSeries();
            stored = db.get_docs(doc.id());

            testCase.verifyError(@() db.add_docs(stored), ...
                'DID:SQLITEDB:DUPLICATE_DOC');
        end

        function testADeclaredButEmptySeriesIsNotRefused(testCase)
            % A series that was never populated has nothing to locate, so
            % there is nothing to complain about.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            db.add_docs(doc);

            testCase.verifyNumElements( ...
                db.search(did.query('', 'isa', 'demoSeries', '')), 1);
        end

        % ---- one fetch per uid --------------------------------------------

        function testRetrievalUsesAUniqueTempNamePerFetch(testCase)
            % The cross-process defect from #173: every fetch wrote to
            % temppath/<uid>, one fixed name per uid. PathConstants.temppath
            % is tempdir/didtemp -- per USER, not per process -- so two MATLAB
            % processes sharing it could see each other's half-written
            % download, and the loser's addFile then failed outright.
            %
            % The handler records where it was told to write, which is the
            % only place that path is observable.
            [db, doc, ~, manifestCopy] = testCase.remoteManifestSeries();

            recordFile = fullfile(pwd, 'fetches.txt');
            handler = @(destPath, sourcePath) ...
                localCopyAndRecord(destPath, manifestCopy, recordFile);

            db.open_doc(doc.id(), 'chunkdata.bin', 'customFileHandler', handler);

            testCase.assertTrue(isfile(recordFile), ...
                'precondition: the handler should have been asked to fetch');
            lines = strtrim(strsplit(fileread(recordFile), newline));
            lines = lines(~cellfun('isempty', lines));
            testCase.assertNumElements(lines, 1);

            uids = doc.fileUids('chunkdata.bin');
            [~, base, ext] = fileparts(lines{1});

            testCase.verifyNotEqual([base ext], uids{1}, ...
                'the scratch copy must not be named for the uid alone');
            testCase.verifySubstring(lines{1}, uids{1}, ...
                'but it should still say which uid it belongs to');
            testCase.verifyEqual(ext, '.part', ...
                'and should be marked as a partial download');
        end

        function testAFetchThatLosesTheRaceUsesTheWinnersBytes(testCase)
            % The other half of single-flight: a peer that never took the lock
            % can still finish first. Simulated by having the handler place
            % the same uid in the cache while this fetch is still in flight,
            % so addFile refuses the name we were about to store under.
            %
            % Those are the same bytes, so losing must be silent and the
            % winner's copy used. Before, addFile's error escaped and turned a
            % redundant download into a failed open.
            [db, doc, ~, manifestCopy] = testCase.remoteManifestSeries();
            uids = doc.fileUids('chunkdata.bin');

            handler = @(destPath, sourcePath) ...
                localCopyAndPreempt(destPath, manifestCopy, uids{1});

            f = db.open_doc(doc.id(), 'chunkdata.bin', 'customFileHandler', handler);
            fopen(f);
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>

            testCase.verifyEqual(char(fread(f, 8, 'uint8')'), 'DIDFSER1', ...
                'the manifest should still open, from whichever copy won');
        end

        function testAFailedFetchLeavesNoPartialBehind(testCase)
            % The leak a unique temp name introduces. The old fixed
            % temppath/<uid> was at least overwritten by the next attempt; a
            % uniquely named .part that nobody deletes stays forever, one per
            % failed fetch.
            %
            % It is not only litter. NDI's customFileHandler short-circuits on
            % isfile(destPath) and reports success without downloading, so a
            % leftover partial could be taken for a finished download and
            % moved into the cache under that uid -- silently wrong bytes for
            % every later read. See VH-Lab/DID-matlab#173.
            [db, doc] = testCase.remoteManifestSeries();

            recordFile = fullfile(pwd, 'failed-fetches.txt');
            handler = @(destPath, sourcePath) ...
                localWriteThenFail(destPath, recordFile);

            testCase.verifyError(@() db.open_doc(doc.id(), 'chunkdata.bin', ...
                'customFileHandler', handler), 'DID:SQLITEDB:open');

            testCase.assertTrue(isfile(recordFile), ...
                'precondition: the handler should have been asked to fetch');
            lines = strtrim(strsplit(fileread(recordFile), newline));
            lines = lines(~cellfun('isempty', lines));
            testCase.assertNotEmpty(lines);

            for i = 1:numel(lines)
                testCase.verifyFalse(isfile(lines{i}), ...
                    'a failed fetch must not leave its partial download behind');
            end
        end

        % ---- series accessors -------------------------------------------
        %
        % seriesCount answers from the document; WHICH slots are filled is
        % recorded only in the manifest, so seriesHas and seriesMembers read
        % it. Both still run no query and touch no network.

        function testSeriesHasAnswersPerSlot(testCase)
            [db, doc] = testCase.ingestedSeries();

            for i = 1:3
                testCase.verifyTrue(db.seriesHas(doc, 'chunkdata.bin', i), ...
                    sprintf('member %d was added', i));
            end
            testCase.verifyFalse(db.seriesHas(doc, 'chunkdata.bin', 4), ...
                'the series has three slots');
        end

        function testSeriesHasFollowsTheGapsOfASparseSeries(testCase)
            % The case a NAME_# entry cannot express, asked directly.
            [db, doc] = testCase.ingestedSeries([2 5 6]);

            for i = [2 5 6]
                testCase.verifyTrue(db.seriesHas(doc, 'chunkdata.bin', i), ...
                    sprintf('member %d is present', i));
            end
            for i = [1 3 4 99]
                testCase.verifyFalse(db.seriesHas(doc, 'chunkdata.bin', i), ...
                    sprintf('member %d is not', i));
            end
        end

        function testSeriesMembersListsOnlyTheFilledSlots(testCase)
            [db, doc] = testCase.ingestedSeries([2 5 6]);

            [indices, uids] = db.seriesMembers(doc, 'chunkdata.bin');

            testCase.verifyEqual(indices, [2 5 6], ...
                'the gaps are skipped, not returned as empties');
            testCase.verifyNumElements(uids, 3);

            m = did.file.readSeriesManifest( ...
                testCase.localPathOf(db, doc, 'chunkdata.bin'));
            for k = 1:numel(indices)
                testCase.verifyEqual(uids{k}, m.uids{indices(k)}, ...
                    'each uid must be the one the manifest gives that slot');
            end
        end

        function testSeriesMembersUidsResolveToTheMemberBytes(testCase)
            % The shape the accessor exists for: one manifest read, then N
            % resolutions that are pure functions of a uid -- no query, no
            % network, callable from any thread.
            [db, doc, ~, contents] = testCase.ingestedSeries();

            [indices, uids] = db.seriesMembers(doc, 'chunkdata.bin');
            testCase.assertEqual(indices, [1 2 3]);

            for k = 1:numel(uids)
                p = did.file.cachedPathForUid(uids{k}, ...
                    'additionalRoots', {db.FileDir});
                testCase.assertNotEmpty(p, 'the member should be on disk');
                fid = fopen(p, 'r');
                theseBytes = uint8(fread(fid, Inf, 'uint8')');
                fclose(fid);
                testCase.verifyEqual(theseBytes, contents{k});
            end
        end

        function testSeriesHasIsAboutTheManifestNotTheDisk(testCase)
            % The two questions are deliberately separate: a caller deciding
            % what to fetch needs to know what SHOULD be there. Deleting the
            % bytes changes exist_doc's answer and must not change this one.
            [db, doc] = testCase.ingestedSeries();

            [~, memberPath] = db.exist_doc(doc.id(), 'chunkdata.bin_2');
            testCase.assertNotEmpty(memberPath);
            delete(memberPath);

            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'), ...
                'the bytes are gone');
            testCase.verifyTrue(db.seriesHas(doc, 'chunkdata.bin', 2), ...
                'but the series still records the member');
        end

        function testSeriesAccessorsAreEmptyWithoutALocalManifest(testCase)
            % Nothing is fetched to answer, so a manifest that is only remote
            % gives the same "not here" cachedPathForFile gives.
            [db, doc] = testCase.remoteManifestSeries();

            testCase.verifyFalse(db.seriesHas(doc, 'chunkdata.bin', 1));
            [indices, uids] = db.seriesMembers(doc, 'chunkdata.bin');
            testCase.verifyEmpty(indices);
            testCase.verifyEmpty(uids);
        end

        function testSeriesAccessorsRefuseAnUndeclaredName(testCase)
            [db, doc] = testCase.ingestedSeries();

            testCase.verifyFalse(db.seriesHas(doc, 'plainfile.ext', 1), ...
                'an ordinary file is not a series');
            testCase.verifyEmpty(db.seriesMembers(doc, 'plainfile.ext'));
            testCase.verifyFalse(db.seriesHas(doc, 'nosuch.bin', 1));
        end

        function testSeriesAccessorsSurviveACorruptManifest(testCase)
            % An accessor is what a caller walks a level with, so a damaged
            % manifest must come back as "nothing here" rather than throwing
            % part way through the walk. It is also SILENT here: open_doc is
            % where the corruption is reported, once, where it can be acted
            % on -- warning per accessor call would mean thousands of them.
            [db, doc] = testCase.ingestedSeries();

            manifestPath = testCase.localPathOf(db, doc, 'chunkdata.bin');
            fid = fopen(manifestPath, 'w');
            fwrite(fid, uint8('NOTAMANIFESTATALL'), 'uint8');
            fclose(fid);

            testCase.verifyWarningFree(@() db.seriesHas(doc, 'chunkdata.bin', 1));
            testCase.verifyFalse(db.seriesHas(doc, 'chunkdata.bin', 1));

            [indices, uids] = db.seriesMembers(doc, 'chunkdata.bin');
            testCase.verifyEmpty(indices);
            testCase.verifyEmpty(uids);
        end

        function testSeriesAccessorsReachNoDatabase(testCase)
            % Same promise cachedPathForFile makes, and for the same reason:
            % a viewer walking a level cannot hold a session per worker.
            [doc, fileRoot] = testCase.seriesOnDiskOnly();

            db = did.test.helper.NoQueryDatabaseWithRoots({fileRoot});

            testCase.verifyTrue(db.seriesHas(doc, 'chunkdata.bin', 1));
            [indices, uids] = db.seriesMembers(doc, 'chunkdata.bin');
            testCase.verifyEqual(indices, 1);
            testCase.verifyNumElements(uids, 1);
        end

        % ---- ingesting a series whose bytes are remote --------------------

        function testIngestOptionLetsARemoteSeriesBeIngested(testCase)
            % Without 'ingest', addFileSeries marks a URL member a reference
            % and nothing copies it -- so a series stored remotely could never
            % be taken in at all. With it, each member is retrieved through
            % the same customFileHandler a single file uses.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            payload = testCase.writeMember(fullfile(pwd,'src'), 'payload.bin', uint8(1:10));
            locs = {'https://nosuchserver.invalid/a.bin', ...
                    'https://nosuchserver.invalid/b.bin'};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'ingest', 1);

            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual([e.ingest], [1 1], ...
                'the option must reach every member');
            testCase.verifyEqual([e.delete_original], [0 0], ...
                'a remote original is still never ours to delete');

            handler = @(destPath, sourcePath) copyfile(payload, destPath);
            testCase.verifyWarningFree( ...
                @() db.add_docs(doc, 'customFileHandler', handler));

            for i = 1:2
                name = sprintf('chunkdata.bin_%d', i);
                testCase.verifyTrue(db.exist_doc(doc.id(), name), name);
                testCase.verifyEqual(testCase.readMember(db, doc.id(), name), ...
                    uint8(1:10), name);
            end
        end

        function testIngestOptionDefaultsAreUnchanged(testCase)
            % The default stays add_file's per-type rule, so every existing
            % caller behaves exactly as before.
            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'a.bin', uint8(1:10)), ...
                    'https://nosuchserver.invalid/b.bin'};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);

            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual([e.ingest], [1 0], ...
                'a local file is taken in, a URL is a reference');
        end

        function testIngestOptionCanAlsoDeclineALocalMember(testCase)
            % The override runs both ways: a local member left in place, with
            % the document recording where it is rather than copying it.
            root = fullfile(pwd, 'store');
            locs = {testCase.writeMember(root, 'a.bin', uint8(1:10))};

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'ingest', 0);

            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(e.ingest, 0);
            testCase.verifyEqual(e.location_type, 'file', ...
                'declining ingestion must not change what the location IS');
        end

    end
end

function localCopyAndRecord(destPath, sourceFile, recordFile)
    % A customFileHandler that notes the path it was handed before doing the
    % copy. A local function rather than a nested one so the handle can be
    % built with a plain anonymous wrapper.
    fid = fopen(recordFile, 'a');
    if fid > 0
        fprintf(fid, '%s\n', destPath);
        fclose(fid);
    end
    copyfile(sourceFile, destPath);
end

function localCopyAndPreempt(destPath, sourceFile, uid)
    % A customFileHandler that writes what it was asked for and then also
    % places the same bytes in the cache under UID -- what a peer process
    % would have done just before this fetch finished.
    copyfile(sourceFile, destPath);
    rival = [destPath '.rival'];
    copyfile(sourceFile, rival);
    did.common.getCache().addFile(rival, uid);
end

function localWriteThenFail(destPath, recordFile)
    % A customFileHandler that gets part way and then dies, the way an
    % interrupted transfer does: bytes on disk at destPath, and an error.
    fid = fopen(recordFile, 'a');
    if fid > 0
        fprintf(fid, '%s\n', destPath);
        fclose(fid);
    end
    fid = fopen(destPath, 'w');
    if fid > 0
        fwrite(fid, uint8(1:4), 'uint8');
        fclose(fid);
    end
    error('DID:Test:SimulatedTransferFailure', 'interrupted mid-transfer');
end
