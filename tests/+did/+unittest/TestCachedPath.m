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
            % than turned into a bad path or an error. The surviving root is
            % given as a string rather than a char, since both are accepted.
            uid = did.ido.unique_id();
            otherRoot = fullfile(pwd, 'someFileDir');
            expected = testCase.writeFile(otherRoot, uid, 'z');

            testCase.verifyEqual( ...
                did.file.cachedPathForUid(uid, ...
                    'additionalRoots', {'', 5, string(otherRoot)}), ...
                expected);
        end

        % ---- did.document/fileUids -----------------------------------

        function testFileUidsReturnsRecordedUids(testCase)
            local = testCase.writeFile(pwd, 'filename1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);

            uids = doc.fileUids('filename1.ext');

            testCase.verifyClass(uids, 'cell');
            testCase.verifyNumElements(uids, 1);
            testCase.verifyEqual(uids{1}, ...
                doc.document_properties.files.file_info(1).locations(1).uid);
        end

        function testFileUidsReturnsAllLocationsInOrder(testCase)
            % add_file appends a location per call, and any of them may be
            % the one that is on disk, so all uids must come back.
            local = testCase.writeFile(pwd, 'filename1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);
            doc = doc.add_file('filename1.ext', 'https://nosuchserver.example/filename1.ext');

            uids = doc.fileUids('filename1.ext');
            recorded = {doc.document_properties.files.file_info(1).locations.uid};

            testCase.verifyEqual(uids, recorded);
        end

        function testFileUidsUnknownNameIsEmpty(testCase)
            doc = did.document('demoFile', 'demoFile.value', 1);
            testCase.verifyEmpty(doc.fileUids('nosuchfile.ext'));
        end

        % ---- did.database/cachedPathForFile ---------------------------

        function testFileUidsNameNotAddedIsEmpty(testCase)
            % A document that HAS files, asked for a declared name that was
            % never added. This is the ordinary miss for a caller walking a
            % pyramid level -- thousands of members present, this one absent --
            % and it takes a different path from a document whose file_info is
            % empty altogether, which is what the previous test covers.
            local = testCase.writeFile(pwd, 'filename1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);

            testCase.verifyEmpty(doc.fileUids('filename2.ext'));

            db = did.test.helper.NoQueryDatabase();
            [tf, p] = db.cachedPathForFile(doc, 'filename2.ext');
            testCase.verifyFalse(tf);
            testCase.verifyEmpty(p);
        end

        function testResolvesWithoutTouchingTheDatabase(testCase)
            % THE POINT OF THE WHOLE CHANGE. Every database operation on this
            % stub errors, so a pass means cachedPathForFile reached none of
            % them -- which is what makes it callable off the session's own
            % thread.
            local = testCase.writeFile(pwd, 'filename1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);
            uid = doc.document_properties.files.file_info(1).locations(1).uid;

            fileRoot = fullfile(pwd, 'stubFileDir');
            expected = testCase.writeFile(fileRoot, uid, 'abc');

            db = did.test.helper.NoQueryDatabaseWithRoots({fileRoot});
            [tf, p] = db.cachedPathForFile(doc, 'filename1.ext');

            testCase.verifyTrue(tf);
            testCase.verifyEqual(p, expected);
        end

        function testAbsentFileIsFalseNotAnError(testCase)
            % "Not on this machine" is an answer, not a failure: a caller
            % walking a level's files uses it to decide what to retrieve.
            local = testCase.writeFile(pwd, 'filename1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);

            db = did.test.helper.NoQueryDatabaseWithRoots({fullfile(pwd, 'emptyDir')});
            [tf, p] = db.cachedPathForFile(doc, 'filename1.ext');

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

        function testBaseClassDefaultSearchesTheGlobalCacheOnly(testCase)
            % did.database's do_cachedPathRoots default is what lets an
            % implementation with no uid-named file root of its own -- sqldb,
            % matlabdumbjsondb -- keep working unchanged. Both sqlitedb and
            % NoQueryDatabaseWithRoots override it, so without this test the
            % default is never executed and that claim is unproven.
            local = testCase.writeFile(pwd, 'filename1.ext', 'abc');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);
            uid = doc.document_properties.files.file_info(1).locations(1).uid;

            db = did.test.helper.NoQueryDatabase();

            % Not found while the file sits somewhere the default does not search
            testCase.writeFile(fullfile(pwd, 'notSearched'), uid, 'abc');
            testCase.verifyFalse(db.cachedPathForFile(doc, 'filename1.ext'), ...
                'the default must not search an arbitrary directory');

            % Found once it is in the global file cache
            expected = testCase.writeFile( ...
                did.common.PathConstants.filecachepath, uid, 'abc');
            [tf, p] = db.cachedPathForFile(doc, 'filename1.ext');
            testCase.verifyTrue(tf);
            testCase.verifyEqual(p, expected);
        end

        function testDocumentWithNoFilesBlockHasNoUids(testCase)
            % demoA declares no files at all, so document_properties has no
            % 'files' field. Asking for a file's uids is a legitimate question
            % with the answer "none", not an error.
            doc = did.document('demoA');

            testCase.verifyEmpty(doc.fileUids('anything.ext'));

            db = did.test.helper.NoQueryDatabase();
            [tf, p] = db.cachedPathForFile(doc, 'anything.ext');
            testCase.verifyFalse(tf);
            testCase.verifyEmpty(p);
        end

        function testAgreesWithExistDoc(testCase)
            % The two must give the same answer for the same file; they
            % differ only in what they need to get there.
            db = did.implementations.sqlitedb(testCase.db_filename);
            db.add_branch('a');

            local = testCase.writeFile(pwd, 'filename1.ext', 'abcdefghij');
            % demoFile declares both files mustbenotempty, so both are bound.
            % Binding only the first used to be accepted -- a required file
            % with no file_info entry fell out of checkfiles' empty match loop
            % and reached isvalid = 1 -- and is refused since issue #199.
            local2 = testCase.writeFile(pwd, 'filename2.ext', 'klmnopqrst');
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', local);
            doc = doc.add_file('filename2.ext', local2);
            db.add_docs(doc);

            [tfExist, pExist] = db.exist_doc(doc.id(), 'filename1.ext');
            [tfCached, pCached] = db.cachedPathForFile(doc, 'filename1.ext');

            testCase.verifyTrue(tfExist, ...
                'precondition: exist_doc should find the ingested file');
            testCase.verifyEqual(tfCached, tfExist);
            testCase.verifyEqual(pCached, pExist);
        end

    end
end
