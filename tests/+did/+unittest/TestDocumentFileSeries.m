classdef TestDocumentFileSeries < matlab.unittest.TestCase
    % Document-level file series: declaration, authoring and enumeration.
    %
    % See VH-Lab/DID-matlab#173. The manifest format itself is covered by
    % TestSeriesManifest; this covers did.document's use of it.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function p = writeMember(~, folder, name)
            if ~isfolder(folder), mkdir(folder); end
            p = fullfile(folder, name);
            fid = fopen(p,'w'); fwrite(fid, uint8(1:10), 'uint8'); fclose(fid);
        end

        function props = declaration(~, fileList, fileSeries)
            % A minimal document_properties struct carrying just the file
            % declarations, for exercising the constructor's validation
            % without a class definition.
            props = struct();
            props.base = struct('id', did.ido.unique_id(), 'name', 'test');
            props.files = struct('file_list', {fileList}, ...
                'file_series', {fileSeries});
        end

        function p = manifestLocation(testCase, doc, name)
            % Where addFileSeries left the manifest. add_file records the
            % location and does not move it until add_docs runs, so the file
            % is still there for a test to inspect.
            files = doc.document_properties.files;
            k = find(strcmpi(name,{files.file_info.name}));
            testCase.assertNotEmpty(k, 'the manifest was not added as a file');
            p = files.file_info(k(1)).locations(1).location;
        end
    end

    methods (Test)

        % ---- declaration ---------------------------------------------

        function testSeriesNamesFromClassDefinition(testCase)
            doc = did.document('demoSeries');
            testCase.verifyEqual(doc.seriesNames(), {'chunkdata.bin'});
            testCase.verifyTrue(doc.isFileSeries('chunkdata.bin'));
            testCase.verifyTrue(doc.isFileSeries('CHUNKDATA.BIN'), ...
                'matching must be case-insensitive, as is_in_file_list is');
            testCase.verifyFalse(doc.isFileSeries('plainfile.ext'));
        end

        function testClassWithNoSeriesHasNone(testCase)
            doc = did.document('demoFile','demoFile.value',1);
            testCase.verifyEmpty(doc.seriesNames());
            testCase.verifyFalse(doc.isFileSeries('filename1.ext'));
        end

        function testCountIsZeroBeforeTheSeriesIsAdded(testCase)
            doc = did.document('demoSeries');
            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, 0);
            testCase.verifyEqual(nPresent, 0);
        end

        % ---- authoring -----------------------------------------------

        function testAddDenseSeries(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), ...
                    testCase.writeMember(root,'b'), ...
                    testCase.writeMember(root,'c')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, 3);
            testCase.verifyEqual(nPresent, 3);
        end

        function testAddSparseSeriesRecordsSlotsNotJustMembers(testCase)
            % The case a NAME_# entry cannot express: members 1, 3 and 7 of a
            % seven-slot series, with nothing written for the gaps.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), ...
                    testCase.writeMember(root,'b'), ...
                    testCase.writeMember(root,'c')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'indices', [1 3 7]);

            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, 7, 'count is the number of SLOTS');
            testCase.verifyEqual(nPresent, 3, 'n_present is what exists');
        end

        function testMembersLandInTheRightManifestSlots(testCase)
            % Members are ONE-based; the manifest array is ZERO-based. This
            % pins the conversion, which is the only place the two differ and
            % the boundary that has produced off-by-ones before.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), ...
                    testCase.writeMember(root,'b')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'indices', [1 4]);

            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));

            testCase.verifyEqual(m.count, 4);
            testCase.verifyNotEmpty(m.uids{1}, 'member 1 -> array slot 1');
            testCase.verifyEmpty(m.uids{2});
            testCase.verifyEmpty(m.uids{3});
            testCase.verifyNotEmpty(m.uids{4}, 'member 4 -> array slot 4');
            testCase.verifyNotEqual(m.uids{1}, m.uids{4});
        end

        function testSourceNamesAreRelativeToTheDerivedRoot(testCase)
            % Absolute paths are never recorded: a full path exposes a
            % directory layout as soon as a document is shared.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(fullfile(root,'0'),'a'), ...
                    testCase.writeMember(fullfile(root,'1'),'b')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            testCase.verifyEqual(doc.seriesSourceRoot('chunkdata.bin'), root);

            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyTrue(m.hasSourceNames);
            testCase.verifyEqual(m.sourceNames, {'0/a','1/b'}, ...
                'relative, and separated with / on every platform');
        end

        function testExplicitSourceRootOverridesTheDerivedOne(testCase)
            % Deriving would give the member's own directory (.../level0),
            % so the recorded name would be just 'a'. Passing the root
            % explicitly is what makes it 'level0/a', which is how a caller
            % says where the tree starts rather than where the file sits.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(fullfile(root,'level0'),'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'sourceRoot', root);

            testCase.verifyEqual(doc.seriesSourceRoot('chunkdata.bin'), root);

            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyEqual(m.sourceNames, {'level0/a'}, ...
                'relative to the root that was given, not to a derived one');
        end

        function testLocationOutsideAnExplicitRootIsRefused(testCase)
            % Recording it would put an absolute path in the manifest, which
            % is the directory-layout disclosure relative names exist to
            % prevent -- so this refuses rather than falling back.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), ...
                    testCase.writeMember(fullfile(pwd,'elsewhere'),'b')};

            doc = did.document('demoSeries');
            testCase.verifyError(...
                @() doc.addFileSeries('chunkdata.bin', locs, 'sourceRoot', root), ...
                'DID:Document:addFileSeries:notUnderRoot');
        end

        function testUidWidthReachesTheManifest(testCase)
            % The last documented option without a test. It is a pass-through
            % to did.file.writeSeriesManifest, but a dropped one would write a
            % header whose stride disagrees with the reader's, so pin that it
            % arrives. A did.ido uid is 33 characters, and the writer refuses a
            % width that cannot hold one, so this widens rather than narrows.
            locs = {testCase.writeMember(fullfile(pwd,'store'),'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'uidWidth', 40);

            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyEqual(m.uidWidth, 40);
            testCase.verifyEqual(numel(m.uids{1}), 33, ...
                'the uid itself is unchanged; only the slot is wider');
        end

        function testSourceNamesCanBeDeclined(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'recordSourceNames', false);

            testCase.verifyEmpty(doc.seriesSourceRoot('chunkdata.bin'));
            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyFalse(m.hasSourceNames);
        end

        function testMembersWithNoCommonRootRecordNoSourceNames(testCase)
            % Nothing in common but the filesystem root, so there is no root
            % worth recording and the alternative -- absolute paths -- is the
            % disclosure the relative form exists to avoid. Record none.
            %
            % The paths are fictional on purpose: addFileSeries never opens a
            % member, it only writes the manifest, so root derivation is pure
            % string work and needs no filesystem to exercise.
            locs = {'/aaa/one/x', '/bbb/two/y'};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            testCase.verifyEmpty(doc.seriesSourceRoot('chunkdata.bin'));
            testCase.verifyEqual(doc.seriesCount('chunkdata.bin'), 2, ...
                'membership is still recorded; only the names are dropped');

            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyFalse(m.hasSourceNames);
            testCase.verifyNotEmpty(m.uids{1});
            testCase.verifyNotEmpty(m.uids{2});
        end

        function testUrlMembersAreGivenNoRoot(testCase)
            % A URL carries no home directory to leak and is stored whole, so
            % it gets no root and no relative name.
            locs = {'https://example.org/store/a', 'https://example.org/store/b'};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            testCase.verifyEmpty(doc.seriesSourceRoot('chunkdata.bin'));
            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyFalse(m.hasSourceNames);
        end

        function testMembersInDifferentSubtreesAreStillRecorded(testCase)
            % Deliberately NOT claiming "no common root": the working-folder
            % fixture puts pwd under tempdir, so two paths under it always
            % share one. What this pins is that members spread across
            % subtrees are still all recorded, whatever root is derived.
            locs = {testCase.writeMember(fullfile(pwd,'one'),'a'), ...
                    testCase.writeMember(fullfile(pwd,'two'),'b')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));
            testCase.verifyEqual(m.count, 2, 'the members are still recorded');
            testCase.verifyNotEmpty(m.uids{1});
            testCase.verifyNotEmpty(m.uids{2});
        end

        % ---- ingest locations -----------------------------------------
        %
        % Transient: they record where each member's bytes currently sit so
        % that ingestion can copy them, and are stripped before the document's
        % JSON is stored. See VH-Lab/DID-matlab#173.

        function testIngestLocationsRecordEveryPresentMember(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), testCase.writeMember(root,'b')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(numel(e), 2);
            testCase.verifyEqual([e.index], [1 2]);
            testCase.verifyEqual({e.location}, locs);
            testCase.verifyEqual({e.location_type}, {'file','file'});
            testCase.verifyEqual([e.ingest], [1 1]);
        end

        function testIngestLocationUidsMatchTheManifestSlots(testCase)
            % The pairing is the whole point: ingestion copies location -> uid,
            % and the manifest is what later resolves NAME_i -> uid. If the two
            % disagreed, a member would be stored under a uid nothing looks up.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), testCase.writeMember(root,'b')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'indices', [2 5]);

            e = doc.seriesIngestLocations('chunkdata.bin');
            m = did.file.readSeriesManifest(testCase.manifestLocation(doc,'chunkdata.bin'));

            testCase.verifyEqual([e.index], [2 5]);
            for j = 1:numel(e)
                testCase.verifyEqual(e(j).uid, m.uids{e(j).index}, ...
                    'the ingest uid must be the uid the manifest gives that slot');
            end
        end

        function testSparseSeriesRecordsOnlyPresentMembers(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'indices', 4);

            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(n, 4);
            testCase.verifyEqual(nPresent, 1);
            testCase.verifyEqual(numel(e), 1, ...
                'absent slots have no bytes to ingest');
            testCase.verifyEqual(e.index, 4);
        end

        function testLocationsSurviveWhenSourceNamesAreDeclined(testCase)
            % The regression this record exists for. recordSourceNames false
            % used to leave no root and no names, so nothing recorded where the
            % members were and the series could never be ingested.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'recordSourceNames', false);

            testCase.verifyEmpty(doc.seriesSourceRoot('chunkdata.bin'), ...
                'no provenance is recorded, as asked');
            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(numel(e), 1);
            testCase.verifyEqual(e.location, locs{1}, ...
                'but ingestion still knows where the member is');
        end

        function testUrlMembersAreNotIngestedAndKeepTheirOriginal(testCase)
            % Mirrors add_file: a URL is a reference, not something to copy in
            % and then delete.
            locs = {'https://example.org/store/a'};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(e.location_type, 'url');
            testCase.verifyEqual(e.ingest, 0);
            testCase.verifyEqual(e.delete_original, 0);
        end

        function testDeleteOriginalDefaultsPerTypeAndCanBeOverridden(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);
            e = doc.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(e.delete_original, 1, ...
                'a local file follows add_file, which deletes the original');

            doc2 = did.document('demoSeries');
            doc2 = doc2.addFileSeries('chunkdata.bin', locs, 'deleteOriginal', 0);
            e2 = doc2.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(e2.delete_original, 0, ...
                'and a caller with 28,000 members can say no');
        end

        function testIngestLocationsAreEmptyBeforeTheSeriesIsAdded(testCase)
            doc = did.document('demoSeries');
            testCase.verifyEmpty(doc.seriesIngestLocations('chunkdata.bin'));
            testCase.verifyEmpty(doc.seriesIngestLocations('nosuch.bin'));
        end

        % ---- stripping -------------------------------------------------

        function testStripRemovesLocationsAndKeepsTheRest(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            props = did.document.stripSeriesIngestLocations(doc.document_properties);
            si = props.files.series_info;
            testCase.verifyTrue(isfield(si,'ingest_locations'), ...
                'the field stays, so a stored document keeps a fresh one''s shape');
            testCase.verifyEmpty(si.ingest_locations, ...
                'but carries nothing');
            testCase.verifyEqual(si.name, 'chunkdata.bin');
            testCase.verifyEqual(si.count, 1);
            testCase.verifyEqual(si.n_present, 1);
            testCase.verifyEqual(si.source_root, root, ...
                'provenance is kept; only the pending paths go');
        end

        function testStrippedPropertiesCarryNoMemberPaths(testCase)
            % What the database stores must not contain a member path at all.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), testCase.writeMember(root,'b')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            props = did.document.stripSeriesIngestLocations(doc.document_properties);
            json = did.datastructures.jsonencodenan(props);
            testCase.verifyEmpty(strfind(json, locs{1}), ...
                'a member path must not reach the stored JSON');
            testCase.verifyEmpty(strfind(json, locs{2}));
        end

        function testStripIsIdempotentAndSafeWithoutSeries(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            once = did.document.stripSeriesIngestLocations(doc.document_properties);
            twice = did.document.stripSeriesIngestLocations(once);
            testCase.verifyEqual(twice, once);

            % A document with no series still HAS a series_info -- an empty
            % struct array carrying the field names -- so this pins that
            % stripping leaves that field set alone. Removing the field
            % instead would leave a stored document one field short of a
            % fresh one, and adding a series to it would then fail.
            plain = did.document('demoFile','demoFile.value',1);
            testCase.verifyEqual(...
                did.document.stripSeriesIngestLocations(plain.document_properties), ...
                plain.document_properties, ...
                'a document with no series is untouched');
        end

        function testASeriesCanBeAddedToAStoredDocument(testCase)
            % The latent bug the test above guards against. A document that
            % has been stored comes back stripped; adding a series to it must
            % still work, which it cannot if stripping changed series_info's
            % field set.
            root = fullfile(pwd,'store');
            first = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', first);

            stored = did.document(...
                did.document.stripSeriesIngestLocations(doc.document_properties));
            stored = stored.removeFileSeries('chunkdata.bin');

            second = {testCase.writeMember(root,'b')};
            stored = stored.addFileSeries('chunkdata.bin', second);

            e = stored.seriesIngestLocations('chunkdata.bin');
            testCase.verifyEqual(numel(e), 1);
            testCase.verifyEqual(e.location, second{1});
        end

        function testAccessorIsEmptyOnAStoredDocument(testCase)
            % The round trip a reader takes: the database stores the stripped
            % properties and hands them back, and did.document(STRUCT) rebuilds
            % from them. document_properties is SetAccess=protected, so this is
            % also the only way to get a stripped document -- which is right,
            % since stripping belongs to storage, not to callers.
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            stored = did.document(...
                did.document.stripSeriesIngestLocations(doc.document_properties));

            testCase.verifyEmpty(stored.seriesIngestLocations('chunkdata.bin'), ...
                'a stored document no longer says where its members came from');
            testCase.verifyEqual(stored.seriesCount('chunkdata.bin'), 1, ...
                'but it still knows the series and its size');
        end

        % ---- refusals -------------------------------------------------

        % ---- declaration-level exclusivity ---------------------------
        %
        % These four run in the did.document constructor rather than in
        % addFileSeries, so they are reached by building the properties
        % struct directly. Using did.document(STRUCT) keeps deliberately
        % malformed declarations out of the example schema, where a future
        % reader would have to work out whether they were broken on purpose.

        function testValidDeclarationConstructs(testCase)
            % Positive control: without this, a validator that rejected
            % everything would pass all four refusal tests below.
            doc = did.document(testCase.declaration(...
                {'plainfile.ext','chunkdata.bin'}, {'chunkdata.bin'}));
            testCase.verifyEqual(doc.seriesNames(), {'chunkdata.bin'});
        end

        function testSeriesMustAlsoBeInFileList(testCase)
            % The series name IS its manifest, and a manifest is an ordinary
            % file, so it has to be declared as one.
            testCase.verifyError(...
                @() did.document(testCase.declaration(...
                    {'plainfile.ext'}, {'chunkdata.bin'})), ...
                'DID:Document:fileDeclarations:seriesNotInFileList');
        end

        function testSeriesBesideNumberedEntryIsRefused(testCase)
            % "chunkdata.bin_12" would match both mechanisms, and they would
            % disagree: the probe path stops at the first gap, which is the
            % case series exist to serve.
            testCase.verifyError(...
                @() did.document(testCase.declaration(...
                    {'chunkdata.bin','chunkdata.bin_#'}, {'chunkdata.bin'})), ...
                'DID:Document:fileDeclarations:seriesAndNumberedEntry');
        end

        function testLiteralEntryShadowedBySeriesIsRefused(testCase)
            % is_in_file_list resolves the trailing integer first, so this
            % literal entry could never be reached.
            testCase.verifyError(...
                @() did.document(testCase.declaration(...
                    {'chunkdata.bin','chunkdata.bin_3'}, {'chunkdata.bin'})), ...
                'DID:Document:fileDeclarations:shadowedBySeries');
        end

        function testShadowingIsCaughtForNamesStr2numEvaluates(testCase)
            % str2num EVALUATES its argument, so "_pi" and "_i" parse as
            % numbers and reach the series path too. Pinned because the
            % obvious rewrite to str2double would silently stop catching them.
            for suffix = {'_pi','_i'}
                testCase.verifyError(...
                    @() did.document(testCase.declaration(...
                        {'chunkdata.bin',['chunkdata.bin' suffix{1}]}, ...
                        {'chunkdata.bin'})), ...
                    'DID:Document:fileDeclarations:shadowedBySeries', ...
                    sprintf('suffix %s should be caught', suffix{1}));
            end
        end

        function testDuplicateSeriesNameIsRefused(testCase)
            % Case-insensitive, because is_in_file_list matches with strcmpi
            % and a difference it cannot see is not a difference.
            testCase.verifyError(...
                @() did.document(testCase.declaration(...
                    {'chunkdata.bin'}, {'chunkdata.bin','CHUNKDATA.BIN'})), ...
                'DID:Document:fileDeclarations:duplicateSeries');
        end


        function testUndeclaredSeriesIsRefused(testCase)
            doc = did.document('demoSeries');
            testCase.verifyError(@() doc.addFileSeries('nosuch.bin', {'x'}), ...
                'DID:Document:addFileSeries:notDeclared');
        end

        function testAddingTwiceIsRefused(testCase)
            locs = {testCase.writeMember(fullfile(pwd,'store'),'a')};
            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);
            testCase.verifyError(@() doc.addFileSeries('chunkdata.bin', locs), ...
                'DID:Document:addFileSeries:alreadyAdded');
        end

        function testZeroOrNegativeIndexIsRefused(testCase)
            % Members are one-based, matching the live NAME_# convention set
            % by ingested epoch data. A zero index is a caller assuming the
            % other base and must not pass silently.
            locs = {testCase.writeMember(fullfile(pwd,'store'),'a')};
            doc = did.document('demoSeries');
            testCase.verifyError( ...
                @() doc.addFileSeries('chunkdata.bin', locs, 'indices', 0), ...
                'DID:Document:addFileSeries:badIndex');
        end

        function testMismatchedAndDuplicateIndicesAreRefused(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a'), testCase.writeMember(root,'b')};
            doc = did.document('demoSeries');

            testCase.verifyError( ...
                @() doc.addFileSeries('chunkdata.bin', locs, 'indices', 1), ...
                'DID:Document:addFileSeries:lengthMismatch');
            testCase.verifyError( ...
                @() doc.addFileSeries('chunkdata.bin', locs, 'indices', [2 2]), ...
                'DID:Document:addFileSeries:duplicateIndex');
        end

        % ---- exclusivity ----------------------------------------------

        function testMemberNameResolvesButCannotBeAddedDirectly(testCase)
            doc = did.document('demoSeries');

            % is_in_file_list returns a DOUBLE flag, not a logical, so
            % compare rather than verifyTrue -- which requires a logical.
            testCase.verifyEqual(doc.is_in_file_list('chunkdata.bin_5'), 1, ...
                'a member name is valid for the class');

            p = testCase.writeMember(fullfile(pwd,'store'),'a');
            testCase.verifyError(@() doc.add_file('chunkdata.bin_5', p), ...
                'DID:Document:add_file:isSeriesMember');
        end

        function testUnrelatedNumberedNameIsStillRejected(testCase)
            doc = did.document('demoSeries');
            testCase.verifyEqual(doc.is_in_file_list('nosuch.bin_5'), 0);
        end

        % ---- membership, as a question anyone can ask -------------------
        %
        % seriesMemberOf is the public form of the rule is_in_file_list uses
        % internally. A database has to ask it too -- a member has no
        % files-table row, so resolving one starts by deciding whether the
        % name is a member at all -- and the two must not drift apart.

        function testSeriesMemberOfNamesTheSeriesAndTheSlot(testCase)
            doc = did.document('demoSeries');

            [stem, index] = doc.seriesMemberOf('chunkdata.bin_7');
            testCase.verifyEqual(stem, 'chunkdata.bin');
            testCase.verifyEqual(index, 7, ...
                'indices are one-based, as written in the name');
        end

        function testSeriesMemberOfReturnsTheDeclaredSpelling(testCase)
            % Matching is case-insensitive, but everything downstream looks
            % the stem up again -- in file_info, in the files table -- where
            % the declared spelling is what is stored.
            doc = did.document('demoSeries');

            testCase.verifyEqual(doc.seriesMemberOf('CHUNKDATA.BIN_2'), ...
                'chunkdata.bin');
        end

        function testSeriesMemberOfSaysNoRatherThanErroring(testCase)
            doc = did.document('demoSeries');

            names = {'chunkdata.bin', 'plainfile.ext_1', 'nosuch.bin_5', ...
                     'nounderscore', 'chunkdata.bin_', ''};
            for i = 1:numel(names)
                [stem, index] = doc.seriesMemberOf(names{i});
                testCase.verifyEmpty(stem, names{i});
                testCase.verifyEmpty(index, names{i});
            end
        end

        function testSeriesMemberOfAgreesWithIsInFileList(testCase)
            % The two rules are one rule. A name that is a member must be a
            % valid file name, and the enumerated NAME_# convention must keep
            % resolving without being mistaken for a series.
            doc = did.document('demoSeries');

            testCase.verifyNotEmpty(doc.seriesMemberOf('chunkdata.bin_5'));
            testCase.verifyEqual(doc.is_in_file_list('chunkdata.bin_5'), 1);

            testCase.verifyEmpty(doc.seriesMemberOf('nosuch.bin_5'));
            testCase.verifyEqual(doc.is_in_file_list('nosuch.bin_5'), 0);
        end

        function testSeriesMemberOfIsEmptyForAClassWithNoSeries(testCase)
            doc = did.document('demoFile','demoFile.value',1);
            testCase.verifyEmpty(doc.seriesMemberOf('filename1.ext_1'));
        end

        % ---- removal ---------------------------------------------------

        function testRemoveClearsTheRecordAndAllowsReAdding(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};
            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs);

            doc = doc.removeFileSeries('chunkdata.bin');

            [n, nPresent] = doc.seriesCount('chunkdata.bin');
            testCase.verifyEqual(n, 0);
            testCase.verifyEqual(nPresent, 0);
            testCase.verifyTrue(doc.isFileSeries('chunkdata.bin'), ...
                'the DECLARATION belongs to the class and survives removal');

            doc = doc.addFileSeries('chunkdata.bin', locs);
            testCase.verifyEqual(doc.seriesCount('chunkdata.bin'), 1);
        end

        function testRemovingAnUnaddedSeriesIsAnError(testCase)
            doc = did.document('demoSeries');
            testCase.verifyError(@() doc.removeFileSeries('chunkdata.bin'), ...
                'DID:Document:removeFileSeries:notAdded');
        end

    end
end
