classdef TestCachedPath < matlab.unittest.TestCase
    % Tests for resolving a document's file to a local path without a query.
    %
    % Covers did.file.cachedPathForUid, did.document/fileUids and
    % did.database/cachedPathForFile. See DID-matlab issue #173.

    properties (Constant)
        db_filename = 'cachedpathtestdb.sqlite'
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods
        function p = writeFile(~, folder, name, contents)
            % Create FOLDER if needed and write a small file into it.
            if ~isfolder(folder)
                mkdir(folder);
            end
            p = fullfile(folder, name);
            fid = fopen(p, 'w');
            fwrite(fid, contents, 'char');
            fclose(fid);
        end
    end

    methods (Test)

        % ---- did.file.cachedPathForUid -------------------------------

        function testUnsafeUidIsRefused(testCase)
            % A uid stands in for a basename, so anything that would leave
            % the root once joined must not produce a path -- whether or not
            % a file happens to sit there. See issue #167.
            unsafe = { '../escape', '..', '.', 'a/b', 'a\b', '', '  padded', ...
                       ['nul' char(0)] };
            for i = 1:numel(unsafe)
                testCase.verifyEmpty( ...
                    did.file.cachedPathForUid(unsafe{i}), ...
                    sprintf('uid %d should have been refused', i));
            end
        end

        function testFindsFileInGlobalCache(testCase)
            uid = did.ido.unique_id();
            expected = testCase.writeFile( ...
                did.common.PathConstants.filecachepath, uid, 'x');

            testCase.verifyEqual(did.file.cachedPathForUid(uid), expected);
        end

        function testFindsFileInAdditionalRoot(testCase)
            uid = did.ido.unique_id();
            otherRoot = fullfile(pwd, 'someFileDir');
            expected = testCase.writeFile(otherRoot, uid, 'y');

            testCase.verifyEqual( ...
                did.file.cachedPathForUid(uid, 'additionalRoots', {otherRoot}), ...
                expected);
        end

        function testGlobalCacheIsPreferredOverAdditionalRoot(testCase)
            % Order matters and is not arbitrary: do_open_doc searches the
            % global cache first, because a file retrieved from a remote
            % location once is kept there. cachedPathForFile must agree with
            % it, or the two would disagree about which copy is current.
            uid = did.ido.unique_id();
            otherRoot = fullfile(pwd, 'someFileDir');
            cachePath = testCase.writeFile( ...
                did.common.PathConstants.filecachepath, uid, 'cache');
            testCase.writeFile(otherRoot, uid, 'other');

            testCase.verifyEqual( ...
                did.file.cachedPathForUid(uid, 'additionalRoots', {otherRoot}), ...
                cachePath);
        end

        function testAbsentFileGivesEmpty(testCase)
            testCase.verifyEmpty(did.file.cachedPathForUid(did.ido.unique_id()));
        end

        function testEmptyAndInvalidRootsAreSkipped(testCase)
            % A root that is empty or not text must be stepped over rather
            % than turned into a bad path or an error.
            uid = did.ido.unique_id();
            otherRoot = fullfile(pwd, 'someFileDir');
            expected = testCase.writeFile(otherRoot, uid, 'z');

            testCase.verifyEqual( ...
                did.file.cachedPathForUid(uid, ...
                    'additionalRoots', {'', 5, otherRoot}), ...
                expected);
        end

        % ---- did.document/fileUids -----------------------------------

        function testFileUidsReturnsRecordedUids(testCase)
            local = testCase.writeFile(pwd, 'f1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('f1.ext', local);

            uids = doc.fileUids('f1.ext');

            testCase.verifyClass(uids, 'cell');
            testCase.verifyNumElements(uids, 1);
            testCase.verifyEqual(uids{1}, ...
                doc.document_properties.files.file_info(1).locations(1).uid);
        end

        function testFileUidsReturnsAllLocationsInOrder(testCase)
            % add_file appends a location per call, and any of them may be
            % the one that is on disk, so all uids must come back.
            local = testCase.writeFile(pwd, 'f1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('f1.ext', local);
            doc = doc.add_file('f1.ext', 'https://nosuchserver.example/f1.ext');

            uids = doc.fileUids('f1.ext');
            recorded = {doc.document_properties.files.file_info(1).locations.uid};

            testCase.verifyEqual(uids, recorded);
        end

        function testFileUidsUnknownNameIsEmpty(testCase)
            doc = did.document('demoFile', 'demoFile.value', 1);
            testCase.verifyEmpty(doc.fileUids('nosuchfile.ext'));
        end

        % ---- did.database/cachedPathForFile ---------------------------

        function testResolvesWithoutTouchingTheDatabase(testCase)
            % THE POINT OF THE WHOLE CHANGE. Every database operation on this
            % stub errors, so a pass means cachedPathForFile reached none of
            % them -- which is what makes it callable off the session's own
            % thread.
            local = testCase.writeFile(pwd, 'f1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('f1.ext', local);
            uid = doc.document_properties.files.file_info(1).locations(1).uid;

            fileRoot = fullfile(pwd, 'stubFileDir');
            expected = testCase.writeFile(fileRoot, uid, 'abc');

            db = did.test.helper.NoQueryDatabase({fileRoot});
            [tf, p] = db.cachedPathForFile(doc, 'f1.ext');

            testCase.verifyTrue(tf);
            testCase.verifyEqual(p, expected);
        end

        function testAbsentFileIsFalseNotAnError(testCase)
            % "Not on this machine" is an answer, not a failure: a caller
            % walking a level's files uses it to decide what to retrieve.
            local = testCase.writeFile(pwd, 'f1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('f1.ext', local);

            db = did.test.helper.NoQueryDatabase({fullfile(pwd, 'emptyDir')});
            [tf, p] = db.cachedPathForFile(doc, 'f1.ext');

            testCase.verifyFalse(tf);
            testCase.verifyEmpty(p);
        end

        function testUnknownFilenameIsFalse(testCase)
            doc = did.document('demoFile', 'demoFile.value', 1);
            db = did.test.helper.NoQueryDatabase();

            [tf, p] = db.cachedPathForFile(doc, 'nosuchfile.ext');

            testCase.verifyFalse(tf);
            testCase.verifyEmpty(p);
        end

        function testAgreesWithExistDoc(testCase)
            % The two must give the same answer for the same file; they
            % differ only in what they need to get there.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            local = testCase.writeFile(pwd, 'f1.ext', 'abcdefghij');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('f1.ext', local);
            db.add_docs(doc);

            [tfExist, pExist] = db.exist_doc(doc.id(), 'f1.ext');
            [tfCached, pCached] = db.cachedPathForFile(doc, 'f1.ext');

            testCase.verifyTrue(tfExist, ...
                'precondition: exist_doc should find the ingested file');
            testCase.verifyEqual(tfCached, tfExist);
            testCase.verifyEqual(pCached, pExist);
        end

    end
end
