classdef TestSeriesMemberFetch < matlab.unittest.TestCase
    % Fetch a file series MEMBER whose bytes are not on this machine.
    %
    % TestFileSeriesRoundTrip covers a series whose members were ingested
    % here, and the manifest-only-remote case. This suite covers the shape a
    % DOWNLOADED dataset actually has: the document and its manifest are
    % reachable, and the member bytes are not here at all. Until #188 that
    % was terminal -- seriesMemberPath resolved the member as far as its uid
    % and stopped, because a member carries no orig_location of its own.
    %
    % What makes it fetchable is that the member does not need a location of
    % its own: the SERIES MANIFEST has one, the member's uid is in the
    % handler's context, and a handler that can reach the manifest's store
    % can reach a sibling object in it. DID composes no URL and learns no
    % scheme; the handler does all of that.
    %
    % One thing is pinned here beyond "the bytes come back", because getting
    % it wrong is silent WRONG BYTES rather than a failure: a handler that
    % resolves the uid out of SOURCEPATH -- which is the manifest's -- rather
    % than out of the context is caught and refused.
    %
    % That guard is also what lets a manifest whose own location is a local
    % file be offered to a handler at all. It was excluded at first, which
    % made the feature inert for a lazily synced dataset -- local manifest,
    % remote members -- so testALocalFileManifestIsAlsoHandedToAHandler now
    % pins the opposite. See VH-Lab/DID-matlab#191.
    %
    % See VH-Lab/DID-matlab#188.

    properties (Constant)
        db_filename = 'seriesmemberfetchdb.sqlite'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function p = writeMember(~, folder, name, bytes)
            if ~isfolder(folder), mkdir(folder); end
            p = fullfile(folder, name);
            fid = fopen(p, 'w');
            fwrite(fid, uint8(bytes), 'uint8');
            fclose(fid);
        end

        function p = manifestLocation(testCase, doc)
            % Where addFileSeries left the manifest, before add_docs moves it.
            files = doc.document_properties.files;
            k = find(strcmpi('chunkdata.bin', {files.file_info.name}));
            testCase.assertNotEmpty(k, 'the manifest was not added as a file');
            p = files.file_info(k(1)).locations(1).location;
        end

        function [db, doc, contents, srcByUid, manifestCopy] = remoteManifestSeries(testCase)
            % A three-member series whose MANIFEST is only available
            % remotely, built the way TestFileSeriesRoundTrip builds it: add
            % the series, keep a copy of the manifest for a handler to serve,
            % then re-point the manifest's location before add_docs.
            %
            % The members are ingested normally here; the caller decides
            % whether to take them back off the machine.
            %
            % SRCBYUID maps every uid the document knows -- the manifest's
            % and each member's -- to a local file holding those bytes, which
            % is what lets a test handler behave like a store keyed by uid.
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
            manifestUid = testCase.manifestUidOf(doc);

            doc = doc.remove_file('chunkdata.bin');
            doc = doc.add_file('chunkdata.bin', ...
                'https://nosuchserver.invalid/chunkdata.bin.manifest');

            db.add_docs(doc);

            srcByUid = containers.Map('KeyType', 'char', 'ValueType', 'char');
            srcByUid(testCase.manifestUidOf(doc)) = manifestCopy;
            srcByUid(manifestUid) = manifestCopy;   % the pre-repoint uid too
            e = doc.seriesIngestLocations('chunkdata.bin');
            for i = 1:numel(e)
                srcByUid(e(i).uid) = locs{e(i).index};
            end
        end

        function [db, doc, contents, srcByUid, manifestCopy] = ndicloudManifestSeries(testCase)
            % Same shape as remoteManifestSeries, but the manifest is
            % re-pointed with an explicit ndicloud location_type and an
            % ndic:// address -- the shape a document takes after a
            % SyncFiles=false round trip through NDI Cloud, and the case
            % VH-Lab/DID-matlab#201 is filed for. Members are ingested
            % normally, so the interesting miss is the manifest.
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
            preRepointUid = testCase.manifestUidOf(doc);

            doc = doc.remove_file('chunkdata.bin');
            doc = doc.add_file('chunkdata.bin', ...
                'ndic://demo-dataset/chunkdata.bin.manifest', ...
                'location_type', 'ndicloud', 'ingest', 0);

            db.add_docs(doc);

            srcByUid = containers.Map('KeyType', 'char', 'ValueType', 'char');
            srcByUid(testCase.manifestUidOf(doc)) = manifestCopy;
            srcByUid(preRepointUid) = manifestCopy;
            e = doc.seriesIngestLocations('chunkdata.bin');
            for i = 1:numel(e)
                srcByUid(e(i).uid) = locs{e(i).index};
            end
        end

        function uid = manifestUidOf(testCase, doc)
            uids = doc.fileUids('chunkdata.bin');
            testCase.assertNotEmpty(uids, 'the manifest has no uid');
            uid = uids{1};
        end

        function uids = memberUidsOf(~, doc)
            e = doc.seriesIngestLocations('chunkdata.bin');
            uids = cell(1, numel(e));
            for i = 1:numel(e)
                uids{e(i).index} = e(i).uid;
            end
        end

        function takeMembersOffTheMachine(testCase, db, doc)
            % Delete every member's ingested bytes, leaving the document and
            % the manifest record untouched. What a freshly downloaded
            % dataset looks like before anything is opened.
            uids = testCase.memberUidsOf(doc);
            for i = 1:numel(uids)
                if isempty(uids{i}), continue, end
                p = fullfile(db.FileDir, uids{i});
                if isfile(p), delete(p); end
                p = fullfile(did.common.PathConstants.filecachepath, uids{i});
                if isfile(p), delete(p); end
            end
        end

        function tryOpen(~, db, doc_id, name, handler)
            % Open and swallow the expected miss, so a verifyWarning can see
            % the warning without the error ending the test first.
            try
                f = db.open_doc(doc_id, name, 'customFileHandler', handler);
                fopen(f); fclose(f);
            catch
                % the miss is asserted separately
            end
        end

        function bytes = readAll(testCase, f)
            fopen(f);
            testCase.assertGreaterThan(f.fid, 0, 'the member did not open');
            closer = onCleanup(@() fclose(f)); %#ok<NASGU>
            bytes = uint8(fread(f, Inf, 'uint8')');
        end
    end

    methods (Test)

        % ---- the acceptance case ----------------------------------------

        function testAbsentMemberIsFetchedThroughTheHandler(testCase)
            % THE TEST THE CHANGE EXISTS FOR. The member is not here; the
            % handler is asked for it, by uid, and its bytes come back.
            [db, doc, contents, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            testCase.assertFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'), ...
                'precondition: the member must not be on this machine');

            function serve(destPath, ~, ctx)
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f), contents{2}, ...
                'the fetched member did not read back byte for byte');
        end

        function testEachFetchedMemberIsItsOwnBytes(testCase)
            % A fetch that returned the manifest, or whichever member came
            % first, would still pass a test that only checked SOMETHING
            % came back.
            [db, doc, contents, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            function serve(destPath, ~, ctx)
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            for i = 1:numel(contents)
                name = sprintf('chunkdata.bin_%d', i);
                f = db.open_doc(doc.id(), name, 'customFileHandler', @serve);
                testCase.verifyEqual(testCase.readAll(f), contents{i}, name);
            end
        end

        % ---- what the handler is told -----------------------------------

        function testHandlerGetsTheSeriesNameAndTheMemberUid(testCase)
            % Half of what #188 is about: seriesName reaching the handler at
            % OPEN time, where before it was populated only at ingest. The
            % uid is the member's; the sourcePath is the MANIFEST's, since
            % that is the only location the record holds.
            [db, doc, ~, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);
            memberUids = testCase.memberUidsOf(doc);

            ctxs = {}; srcs = {};
            function serve(destPath, sourcePath, ctx)
                ctxs{end+1} = ctx; srcs{end+1} = sourcePath;
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            fopen(f); fclose(f);

            % Two calls: the manifest first (it is remote too), then the
            % member. Only the second carries a series name.
            testCase.assertNumElements(ctxs, 2, ...
                'the manifest and then the member');
            memberCtx = ctxs{2};
            testCase.verifyEqual(memberCtx.mode, 'open', ...
                'the member is fetched on the read path');
            testCase.verifyEqual(memberCtx.seriesName, 'chunkdata.bin', ...
                'seriesName must name the series at open time, not just at ingest');
            testCase.verifyEqual(memberCtx.filename, 'chunkdata.bin_2', ...
                'filename is the member the caller asked for');
            testCase.verifyEqual(memberCtx.uid, memberUids{2}, ...
                'uid is the MEMBER''s uid, from the manifest slot');
            testCase.verifyEqual(memberCtx.documentId, doc.id());

            testCase.verifyEqual(srcs{2}, ...
                'https://nosuchserver.invalid/chunkdata.bin.manifest', ...
                'sourcePath is the manifest''s location: a member has none');
            testCase.verifyNotEqual(memberCtx.uid, testCase.manifestUidOf(doc), ...
                'the context uid must not be the manifest''s');
        end

        function testAMemberThatIsHereDoesNotReachTheHandler(testCase)
            % One fetch happens only when there is nothing to read. The
            % manifest is remote in this fixture, so the handler is called
            % once for it -- and never for the member, which is ingested.
            [db, doc, contents, srcByUid] = testCase.remoteManifestSeries();

            ctxs = {};
            function serve(destPath, ~, ctx)
                ctxs{end+1} = ctx;
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f), contents{2});

            testCase.assertNumElements(ctxs, 1, ...
                'only the manifest was missing');
            testCase.verifyEqual(ctxs{1}.seriesName, '', ...
                'the manifest is an ordinary file, not a member');
        end

        function testAFetchedMemberIsCachedAndNotFetchedAgain(testCase)
            % One fetch per member, not one per call: the cache placement is
            % what makes the second read cheap. A 28,000-member level read
            % twice must not be 56,000 downloads.
            [db, doc, contents, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            ctxs = {};
            function serve(destPath, ~, ctx)
                ctxs{end+1} = ctx;
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            fopen(f); fclose(f);
            nAfterFirst = numel(ctxs);

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f), contents{2});
            testCase.verifyEqual(numel(ctxs), nAfterFirst, ...
                'the second open must be served from the cache');

            testCase.verifyTrue(db.exist_doc(doc.id(), 'chunkdata.bin_2'), ...
                'and the member is now on this machine for good');
        end

        % ---- a failed fetch is a miss, never an exception ----------------

        function testAHandlerThatErrorsIsACleanMiss(testCase)
            % seriesMemberPath is called speculatively, so a handler that
            % blows up must leave today's behaviour: the member is reported
            % absent through do_open_doc's own error, not through whatever
            % the handler threw.
            [db, doc, ~, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            function serve(destPath, ~, ctx)
                if isempty(ctx.seriesName)
                    copyfile(srcByUid(ctx.uid), destPath);   % the manifest
                    return
                end
                error('Test:handlerBlewUp', 'no network');
            end

            testCase.verifyError( ...
                @() db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve), ...
                'DID:SQLITEDB:open');

            try
                db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
                testCase.verifyFail('open_doc should have errored');
            catch err
                testCase.verifySubstring(err.message, 'chunkdata.bin', ...
                    'the message must still name the series');
                testCase.verifySubstring(err.message, 'not on this machine');
            end
        end

        function testAHandlerThatWritesNothingIsACleanMiss(testCase)
            [db, doc, ~, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            function serve(destPath, ~, ctx)
                if isempty(ctx.seriesName)
                    copyfile(srcByUid(ctx.uid), destPath);   % the manifest
                end
                % and nothing at all for a member
            end

            testCase.verifyError( ...
                @() db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve), ...
                'DID:SQLITEDB:open');
        end

        function testNoHandlerIsStillTheOldBehaviour(testCase)
            % Without a handler DID retrieves nothing itself, so an absent
            % member is absent -- exactly as before #188.
            [db, doc] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            testCase.verifyError(@() db.open_doc(doc.id(), 'chunkdata.bin_2'), ...
                'DID:SQLITEDB:open');
        end

        function testExistDocStillDoesNotFetch(testCase)
            % check_exist_doc reports what is on this machine. It passes no
            % handler and does not permit retrieval, so the member fetch has
            % to sit behind the same gate the manifest fetch does.
            [db, doc, ~, srcByUid] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'));

            % Even after the manifest has been brought here by an open, so
            % that resolution can get all the way to the member's uid.
            function serve(destPath, ~, ctx)
                if isKey(srcByUid, ctx.uid) && isempty(ctx.seriesName)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end
            try
                db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            catch
                % expected: the manifest arrives, the member does not
            end
            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'), ...
                'exist_doc must not go to the network to answer a local question');
        end

        % ---- the two ways this would be silent wrong bytes ---------------

        function testALocalFileManifestIsAlsoHandedToAHandler(testCase)
            % A manifest whose own location is an ordinary local file IS
            % offered, and this is the case that matters most in practice.
            %
            % It was refused at first, reasoning that a handler handed a
            % local path might simply copy it, putting the MANIFEST's bytes
            % into the member's cache slot. That is a real mistake and it is
            % still caught -- by the byte comparison in
            % testAHandlerThatReturnsTheManifestIsRefused, which does not
            % care whether the path it was given was local.
            %
            % What the refusal also assumed was that a local manifest means a
            % database with no remote store to fetch from. That is false, and
            % false for the shape this whole mechanism exists to serve: a
            % dataset synced from a remote store brings its document files
            % down to local paths and leaves the series MEMBERS behind, so
            % the manifest is an ordinary file on disk while every member it
            % names is still remote. Under the old rule the handler was never
            % asked and every member of such a series read as absent. See
            % VH-Lab/NDI-matlab#966, where it made the feature inert for its
            % main caller.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            root = fullfile(pwd, 'store');
            contents = {uint8(1:10), uint8(11:20)};
            locs = {testCase.writeMember(root, 'a.bin', contents{1}), ...
                    testCase.writeMember(root, 'b.bin', contents{2})};
            doc = did.document('demoSeries', 'demoSeries.value', 1);
            doc = doc.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);
            db.add_docs(doc);

            % The manifest stays exactly where add_docs put it: a local file.
            testCase.takeMembersOffTheMachine(db, doc);

            srcByUid = containers.Map('KeyType', 'char', 'ValueType', 'char');
            e = doc.seriesIngestLocations('chunkdata.bin');
            for i = 1:numel(e)
                srcByUid(e(i).uid) = locs{e(i).index};
            end

            called = false;
            function serve(destPath, ~, ctx)
                called = true;
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyTrue(called, ...
                'a local-file manifest location must still be dispatched');
            testCase.verifyEqual(testCase.readAll(f), contents{2}, ...
                'the member fetched from a local-manifest series has wrong bytes');
        end

        function testAHandlerThatReturnsTheManifestIsRefused(testCase)
            % The version-skew case, and the reason it is worth catching. A
            % handler written before #188 takes the uid out of SOURCEPATH --
            % which is the manifest's -- and so serves the manifest's bytes
            % for every member. Accepting them would cache the manifest
            % under the member's uid and every later read would return it
            % happily. Refuse them, loudly.
            [db, doc, ~, srcByUid, manifestCopy] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);
            memberUids = testCase.memberUidsOf(doc);

            function serveTheManifestAlways(destPath, ~, ~)
                copyfile(manifestCopy, destPath);
            end

            testCase.verifyWarning( ...
                @() testCase.tryOpen(db, doc.id(), 'chunkdata.bin_2', @serveTheManifestAlways), ...
                'DID:SQLITEDB:FileSeries:HandlerReturnedManifest');

            testCase.verifyFalse(db.exist_doc(doc.id(), 'chunkdata.bin_2'), ...
                'nothing may be left in the cache under the member''s uid');
            testCase.verifyFalse( ...
                isfile(fullfile(did.common.PathConstants.filecachepath, memberUids{2})), ...
                'and specifically not the manifest''s bytes');

            % A handler that does read the context is unaffected.
            function serve(destPath, ~, ctx)
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end
            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f), uint8(11:20));
        end

        function testATwoArgHandlerIsNeverAskedForAMember(testCase)
            % A two-argument handler is given no context at all, so it has no
            % way to learn the member's uid: everything it could do with the
            % manifest's location is wrong. It keeps working for the manifest
            % itself, which is an ordinary file.
            [db, doc, ~, ~, manifestCopy] = testCase.remoteManifestSeries();
            testCase.takeMembersOffTheMachine(db, doc);

            calls = 0;
            function serveManifest(destPath, ~)
                calls = calls + 1;
                copyfile(manifestCopy, destPath);
            end

            testCase.verifyError( ...
                @() db.open_doc(doc.id(), 'chunkdata.bin_2', ...
                    'customFileHandler', @serveManifest), ...
                'DID:SQLITEDB:open');
            testCase.verifyEqual(calls, 1, ...
                'the manifest, and only the manifest, is asked of a 2-arg handler');
        end

        % ---- the cloud-only manifest case (VH-Lab/DID-matlab#201) --------

        function testNdicloudManifestIsRetrievedThroughTheHandler(testCase)
            % A series arrived from a SyncFiles=false cloud round trip. The
            % manifest's file_info entry is location_type='ndicloud' with an
            % ndic:// address, and its bytes are not on this machine at all.
            % Opening a member must offer the manifest's location to the
            % handler with the manifest's own uid in the context, and land
            % the bytes at filecachepath/<manifestUid> so nothing else has
            % to fetch it again.
            [db, doc, contents, srcByUid] = testCase.ndicloudManifestSeries();
            manifestUid = testCase.manifestUidOf(doc);

            ctxs = {}; srcs = {};
            function serve(destPath, sourcePath, ctx)
                ctxs{end+1} = ctx; srcs{end+1} = sourcePath;
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f), contents{2}, ...
                'the fetched member did not read back byte for byte');

            testCase.assertNotEmpty(ctxs, 'the handler was never asked');
            manifestCtx = ctxs{1};
            testCase.verifyEqual(manifestCtx.uid, manifestUid, ...
                'the ctx uid on the manifest fetch must be the manifest''s');
            testCase.verifyEqual(manifestCtx.seriesName, '', ...
                'the manifest is an ordinary file, not a member');
            testCase.verifyEqual(manifestCtx.mode, 'open');
            testCase.verifyEqual(srcs{1}, ...
                'ndic://demo-dataset/chunkdata.bin.manifest', ...
                'sourcePath is the manifest''s ndic:// location, verbatim');

            testCase.verifyTrue( ...
                isfile(fullfile(did.common.PathConstants.filecachepath, manifestUid)), ...
                'the manifest must land at filecachepath/<manifestUid>');
        end

        function testDifferentMembersShareOneManifestFetch(testCase)
            % The manifest is fetched once per session, not once per member
            % open: the acceptance rule that keeps a 28,000-member level
            % from turning into 28,000 manifest downloads. Assert the
            % handler is called for the manifest exactly once across two
            % opens of different members.
            [db, doc, contents, srcByUid] = testCase.ndicloudManifestSeries();
            manifestUid = testCase.manifestUidOf(doc);

            manifestCalls = 0;
            function serve(destPath, ~, ctx)
                if strcmp(ctx.uid, manifestUid)
                    manifestCalls = manifestCalls + 1;
                end
                if isKey(srcByUid, ctx.uid)
                    copyfile(srcByUid(ctx.uid), destPath);
                end
            end

            f1 = db.open_doc(doc.id(), 'chunkdata.bin_1', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f1), contents{1});
            f2 = db.open_doc(doc.id(), 'chunkdata.bin_2', 'customFileHandler', @serve);
            testCase.verifyEqual(testCase.readAll(f2), contents{2});

            testCase.verifyEqual(manifestCalls, 1, ...
                'the manifest fetch must be shared across member opens');
        end

        function testManifestFetchThatWritesNothingRaisesTheStandardMiss(testCase)
            % Handler-refused case for the manifest: when the handler cannot
            % service the manifest's location, resolution reports "not on
            % this machine" through DID:SQLITEDB:open -- the same shape and
            % message a caller could match on before this change, so an
            % out-of-band failure stays visible without changing the API.
            [db, doc] = testCase.ndicloudManifestSeries();

            function serveNothingForManifest(destPath, ~, ~) %#ok<INUSD>
                % write nothing at all
            end

            testCase.verifyError( ...
                @() db.open_doc(doc.id(), 'chunkdata.bin_2', ...
                    'customFileHandler', @serveNothingForManifest), ...
                'DID:SQLITEDB:open');

            try
                db.open_doc(doc.id(), 'chunkdata.bin_2', ...
                    'customFileHandler', @serveNothingForManifest);
                testCase.verifyFail('open_doc should have errored');
            catch err
                testCase.verifySubstring(err.message, 'chunkdata.bin', ...
                    'the message must name the series');
                testCase.verifySubstring(err.message, 'not on this machine', ...
                    'the current miss message is what callers pattern-match on');
            end
        end
    end
end
