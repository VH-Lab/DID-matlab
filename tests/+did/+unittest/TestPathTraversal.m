classdef TestPathTraversal < matlab.unittest.TestCase
    % Directory-traversal guards on ingest and open_doc.
    %
    % Regression test for DID-matlab issue #167 (parity with
    % DID-python#58) and its follow-up #169: a document's
    % file_info(i).locations(j).uid and .location are attacker-controlled
    % when the document is pulled from a cloud store, and both used to
    % reach the filesystem verbatim -- fullfile(FileDir, uid) on the
    % write side, and copyfile / isfile on the read side.
    %
    % The behaviour to pin:
    %
    % * an unsafe uid (path separator, '.', '..', empty basename, NUL) is
    %   refused at ingest -- the document is not partly written. The
    %   destination <FileDir>/<uid> is fully constrained by that check;
    % * a legitimate ingest source outside the database directory is
    %   accepted (see #169): "add this file to my DB" is the normal call
    %   and the destination is already contained by the uid check above;
    % * on the read side, a row written by an older, unguarded DID that
    %   carries such a value is filtered out -- open_doc cannot be steered
    %   into reading a file outside the database directory through it.

    properties
        db      % Database object
        dbFile  % Absolute path to the .sqlite file (its parent is db_dir)
        srcFile % A real local file to use as an ingest source
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.dbFile = fullfile(pwd, 'traversal.sqlite');
            testCase.db = did.implementations.sqlitedb(testCase.dbFile);
            testCase.db.add_branch('a');

            testCase.srcFile = fullfile(pwd, 'source.bin');
            fid = fopen(testCase.srcFile, 'w', 'ieee-le');
            testCase.assertNotEqual(fid, -1, ...
                'Could not create the source payload file.');
            fwrite(fid, char(0:9), 'char');
            fclose(fid);
        end
    end

    methods
        function doc = docWithLocation(testCase, uid, location, location_type, ingest)
            % Build a demoFile document and overwrite the first file's
            % first location.uid / .location. add_file auto-assigns a uid
            % via did.ido.unique_id(), which we mutate here so the test
            % can supply an unsafe value.
            if nargin < 4 || isempty(location_type)
                location_type = 'file';
            end
            if nargin < 5 || isempty(ingest)
                ingest = 1;
            end
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', location, ...
                'ingest', ingest, 'delete_original', 0, ...
                'location_type', location_type);
            doc = doc.add_file('filename2.ext', testCase.srcFile, ...
                'ingest', 0, 'delete_original', 0);
            % Overwrite the auto-assigned uid with the test's chosen one.
            props = doc.document_properties;
            props.files.file_info(1).locations(1).uid = uid;
            doc = doc.setproperties('files', props.files);
        end
    end

    methods (Test)
        % -- uid refused at ingest --------------------------------------

        function testUidWithParentTraversalIsRefused(testCase)
            doc = testCase.docWithLocation('../../.ssh/authorized_keys', ...
                testCase.srcFile);
            testCase.verifyError( ...
                @() testCase.db.add_docs(doc), ...
                'DID:SQLITEDB:PathTraversal');
        end

        function testUidWithAPathSeparatorIsRefused(testCase)
            doc = testCase.docWithLocation('a/b', testCase.srcFile);
            testCase.verifyError( ...
                @() testCase.db.add_docs(doc), ...
                'DID:SQLITEDB:PathTraversal');
        end

        function testUidThatIsADotSegmentIsRefused(testCase)
            for bad = {'.', '..'}
                doc = testCase.docWithLocation(bad{1}, testCase.srcFile);
                testCase.verifyError( ...
                    @() testCase.db.add_docs(doc), ...
                    'DID:SQLITEDB:PathTraversal');
            end
        end

        function testUidWithANullByteIsRefused(testCase)
            doc = testCase.docWithLocation(['ok' char(0) '.txt'], ...
                testCase.srcFile);
            testCase.verifyError( ...
                @() testCase.db.add_docs(doc), ...
                'DID:SQLITEDB:PathTraversal');
        end

        function testARefusedUidLeavesNoDocumentInTheDatabase(testCase)
            % Refuse, do not substitute -- and do not write half of it.
            doc = testCase.docWithLocation('../evil', testCase.srcFile);
            try
                testCase.db.add_docs(doc);
                testCase.verifyFail('add_docs should have refused.');
            catch err
                testCase.verifyEqual(err.identifier, ...
                    'DID:SQLITEDB:PathTraversal');
            end

            % A refused ingest must not leave any row for this doc_id
            % behind -- neither the docs row nor a files row. run_sql_query
            % may return an empty numeric or a struct with an empty field
            % depending on the driver's shape; the direct signal that the
            % doc landed anyway is being able to get_docs it.
            count = testCase.db.run_sql_query( ...
                sprintf('SELECT COUNT(*) AS n FROM docs WHERE doc_id="%s"', ...
                    doc.id()), true);
            n = 0;
            try, n = double(count(1).n); catch, end
            testCase.verifyEqual(n, 0, ...
                'A refused ingest must not leave the document behind.');
        end

        function testARefusedUidDoesNotWriteTheDestFile(testCase)
            % ../<basename> lands next to db_dir -- a real filesystem escape.
            dbDir = fileparts(testCase.dbFile);
            outside = fullfile(fileparts(dbDir), 'outside-file.bin');
            if isfile(outside), delete(outside); end
            cleanup = onCleanup(@() (isfile(outside) && delete(outside))); %#ok<NASGU>

            doc = testCase.docWithLocation('../outside-file.bin', ...
                testCase.srcFile);
            testCase.verifyError( ...
                @() testCase.db.add_docs(doc), ...
                'DID:SQLITEDB:PathTraversal');
            testCase.verifyFalse(isfile(outside), ...
                'The traversal target must not have been written.');
        end

        % -- legitimate ingest source outside db_dir is accepted --------

        function testLegitimateSourceOutsideDbDirIsIngested(testCase)
            % See DID-matlab issue #169. Ingest workflows commonly stage
            % the source file somewhere outside the database directory
            % ("take this file from wherever it lives and add it to my
            % DB"). The destination path is already constrained under
            % <FileDir>/<uid> by isSafeUid, so a source outside db_dir is
            % not an attack -- refusing it broke downstream ingest.
            outsideDir = fullfile(tempdir, ['did-outside-' char(java.util.UUID.randomUUID())]);
            mkdir(outsideDir);
            cleanupDir = onCleanup(@() rmdir(outsideDir, 's')); %#ok<NASGU>
            outsideSource = fullfile(outsideDir, 'staged.bin');
            fid = fopen(outsideSource, 'w');
            testCase.assertNotEqual(fid, -1, ...
                'Could not create the staged source file.');
            fwrite(fid, uint8([1 2 3 4]), 'uint8');
            fclose(fid);

            doc = testCase.docWithLocation('u-outside', outsideSource);
            testCase.db.add_docs(doc);

            % The ingested copy must land at <FileDir>/<uid>.
            fileDir = testCase.db.FileDir;
            testCase.verifyTrue(isfile(fullfile(fileDir, 'u-outside')), ...
                'The ingested copy must land at <FileDir>/<uid>.');
        end

        % -- static predicates ------------------------------------------

        function testIsSafeUidPredicate(testCase)
            % A plain basename is safe; anything with a separator, a dot
            % segment, a NUL, or padding whitespace is not.
            good = {'u', 'u-plain', 'abc.bin', 'f0123456789abcdef', ...
                    ['u' char(1)]};   % low control chars other than NUL are fine
            bad  = {'', '.', '..', '../evil', 'a/b', 'a\b', ...
                    ['x' char(0)], ' u', 'u '};
            for k = 1:numel(good)
                testCase.verifyTrue( ...
                    did.implementations.sqlitedb.isSafeUid(good{k}), ...
                    sprintf('"%s" should be safe', good{k}));
            end
            for k = 1:numel(bad)
                testCase.verifyFalse( ...
                    did.implementations.sqlitedb.isSafeUid(bad{k}), ...
                    sprintf('"%s" should be refused', bad{k}));
            end
        end

        function testContainsTraversalPredicate(testCase)
            testCase.verifyTrue(did.implementations.sqlitedb.containsTraversal('../a'));
            testCase.verifyTrue(did.implementations.sqlitedb.containsTraversal('a/../b'));
            testCase.verifyTrue(did.implementations.sqlitedb.containsTraversal('a\..\b'));
            testCase.verifyFalse(did.implementations.sqlitedb.containsTraversal('a/b/c'));
            testCase.verifyFalse(did.implementations.sqlitedb.containsTraversal(''));
        end
    end
end
