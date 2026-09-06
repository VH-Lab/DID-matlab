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

        function testSourceNamesCanBeDeclined(testCase)
            root = fullfile(pwd,'store');
            locs = {testCase.writeMember(root,'a')};

            doc = did.document('demoSeries');
            doc = doc.addFileSeries('chunkdata.bin', locs, 'recordSourceNames', false);

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
