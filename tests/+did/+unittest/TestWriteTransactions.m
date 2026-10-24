classdef TestWriteTransactions < matlab.unittest.TestCase
    % Each write operation is one transaction, recovered by replay
    %
    % Until this, mksqlite autocommitted every statement on its own, so a
    % document that failed part-way through do_add_doc - an error, Ctrl-C, a
    % full disk, a poisoned handle - was left half-written. Now each write
    % operation (do_add_doc, do_remove_doc, do_add_branch, do_delete_branch)
    % is one transaction:
    %
    %   - a failure rolls the whole operation back;
    %   - files are deleted (delete_original, reclaimed cached copies) only
    %     once the operation has committed;
    %   - fields_cache is restored with the rollback;
    %   - a READONLY inside the operation (a poisoned handle, da83fa3) is
    %     recovered by reopening and replaying the operation's statements,
    %     each checked against what it did the first time;
    %   - just before COMMIT the path is checked to still name the file the
    %     connection opened, since SQLite notices a replaced file only when a
    %     write transaction starts, and a COMMIT after a later swap succeeds
    %     into a file that no longer has a name.
    %
    % Mirrors DID-python's tests/test_sqlitedb_transient_errors.py
    % (DID-python#93, #94). The tests that replace the database file need the
    % file's inode, which Windows does not give, and are skipped there.

    properties (Constant)
        db_filename = 'test_db_write_tx.sqlite'
    end

    properties
        db % a did.test.helper.WriteFaultSqlitedb
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture)

            testCase.db = did.test.helper.WriteFaultSqlitedb( ...
                fullfile(pwd, testCase.db_filename));
            testCase.db.add_branch('a');
        end
    end

    methods
        function rows = onDisk(testCase, query_str)
            % Run a query on a separate connection: what is really in the file
            id = mksqlite(0, 'open', testCase.db.connection);
            closer = onCleanup(@() mksqlite(id, 'close'));
            rows = mksqlite(id, query_str);
            clear closer
        end

        function tf = isOnDisk(testCase, doc_id)
            rows = testCase.onDisk(['SELECT doc_id FROM docs WHERE doc_id="' doc_id '"']);
            tf = ~isempty(rows);
        end

        function [doc, paths] = fileDocument(testCase, deleteOriginal)
            % A demoFile document whose two files are ingested
            names = {'filename1.ext', 'filename2.ext'};
            paths = cell(size(names));
            doc = did.document('demoFile', 'demoFile.value', 1);
            for i = 1:numel(names)
                paths{i} = fullfile(pwd, names{i});
                fid = fopen(paths{i}, 'w');
                testCase.assertNotEqual(fid, -1);
                fwrite(fid, char((i-1)*10 + (0:9)), 'char');
                fclose(fid);
                doc = doc.add_file(names{i}, paths{i}, ...
                    'ingest', 1, 'delete_original', deleteOriginal);
            end
        end
    end

    methods (Test)
        function testAFailedCommitLeavesNoPartialDocument(testCase)
            doc = did.document('demoA', 'demoA.value', 1);
            testCase.db.failCommit = true;
            testCase.verifyError(@() testCase.db.add_docs(doc), 'DID:Test:CommitRefused');
            testCase.verifyFalse(testCase.isOnDisk(doc.id()), ...
                'a document whose write did not commit must leave no docs row');
            testCase.verifyEmpty(testCase.onDisk('SELECT doc_idx FROM branch_docs'), ...
                'nor a branch_docs row');
        end

        function testTheFieldsCacheIsRestoredWithTheRollback(testCase)
            % The first demoA document adds its fields rows - and caches their
            % field_idx - inside the transaction that is rolled back. A stale
            % cache would point the next document's doc_data at fields that do
            % not exist.
            doc = did.document('demoA', 'demoA.value', 1);
            testCase.db.failCommit = true;
            testCase.verifyError(@() testCase.db.add_docs(doc), 'DID:Test:CommitRefused');
            testCase.db.failCommit = false;

            doc2 = did.document('demoA', 'demoA.value', 2);
            testCase.db.add_docs(doc2);

            orphans = testCase.onDisk(['SELECT field_idx FROM doc_data ' ...
                'WHERE field_idx NOT IN (SELECT field_idx FROM fields)']);
            testCase.verifyEmpty(orphans, 'every doc_data row must name a real field');
        end

        function testOriginalsAreDeletedOnlyOnceTheAddCommits(testCase)
            [doc, paths] = testCase.fileDocument(1);
            testCase.db.failCommit = true;
            testCase.verifyError(@() testCase.db.add_docs(doc), 'DID:Test:CommitRefused');
            for i = 1:numel(paths)
                testCase.verifyTrue(isfile(paths{i}), ...
                    'a rolled-back add must not delete the original');
            end

            testCase.db.failCommit = false;
            testCase.db.add_docs(doc);
            for i = 1:numel(paths)
                testCase.verifyFalse(isfile(paths{i}), ...
                    'delete_original deletes the source once the add commits');
            end
        end

        function testCachedFilesStayWhenARemoveRollsBack(testCase)
            doc = testCase.fileDocument(0);
            testCase.db.add_docs(doc);
            rows = testCase.onDisk('SELECT cached_location FROM files');
            cached = {rows.cached_location};
            cached = cached(~cellfun(@isempty, cached));
            testCase.assertNotEmpty(cached, 'setup: the files should be cached');

            testCase.db.failCommit = true;
            testCase.verifyError(@() testCase.db.remove_docs(doc.id()), 'DID:Test:CommitRefused');
            testCase.verifyTrue(testCase.isOnDisk(doc.id()));
            for i = 1:numel(cached)
                testCase.verifyTrue(isfile(cached{i}), ...
                    'a rolled-back remove must not delete the cached copies');
            end
        end

        function testAFileReplacedBetweenOperationsIsRecovered(testCase)
            testCase.assumeFalse(ispc, 'needs the file''s inode');
            first = did.document('demoA', 'demoA.value', 1);
            testCase.db.add_docs(first);
            replaceWithCopy(testCase.db.connection);

            second = did.document('demoA', 'demoA.value', 2);
            testCase.db.add_docs(second);

            testCase.verifyTrue(testCase.isOnDisk(first.id()));
            testCase.verifyTrue(testCase.isOnDisk(second.id()));
        end

        function testAFileReplacedDuringAWriteIsCaughtBeforeCommit(testCase)
            % The swap SQLite does not see: after the transaction's first
            % write. Without the pre-commit check the document would be
            % committed to the old, nameless file and lost.
            testCase.assumeFalse(ispc, 'needs the file''s inode');
            testCase.db.onInsertInto = 'branch_docs';
            testCase.db.beforeInsert = @replaceWithCopy;

            doc = did.document('demoA', 'demoA.value', 1);
            testCase.db.add_docs(doc);

            testCase.verifyTrue(testCase.isOnDisk(doc.id()), ...
                'the document must be in the file now at the path');
        end

        function testADeletedFileIsAnErrorNotANewDatabase(testCase)
            testCase.assumeFalse(ispc, 'needs the file''s inode');
            testCase.db.onInsertInto = 'branch_docs';
            testCase.db.beforeInsert = @(p) delete(p);

            doc = did.document('demoA', 'demoA.value', 1);
            try
                testCase.db.add_docs(doc);
                testCase.verifyFail('adding to a deleted database must fail');
            catch ME
                testCase.verifyEqual(ME.identifier, 'DID:SQLITEDB:FileReplaced');
                causes = cellfun(@(c) c.identifier, ME.cause, 'UniformOutput', false);
                testCase.verifyTrue(ismember('DID:SQLITEDB:DatabaseFileGone', causes));
            end
            testCase.verifyFalse(isfile(testCase.db.connection), ...
                'recovery must not create a new, empty database at the path');
        end

        function testAReplayThatReadsADifferentDatabaseIsRefused(testCase)
            % The file swapped in is an older copy, without the first
            % document. The second document's replayed INSERT then gets a
            % different doc_idx, so every doc_data row built from the first
            % one would point at the wrong document: refused, not committed.
            testCase.assumeFalse(ispc, 'needs the file''s inode');
            snapshot = [testCase.db.connection '.before'];
            copyfile(testCase.db.connection, snapshot);
            first = did.document('demoA', 'demoA.value', 1);
            testCase.db.add_docs(first);

            testCase.db.onInsertInto = 'doc_data';
            testCase.db.beforeInsert = @(p) movefile(snapshot, p, 'f');
            second = did.document('demoA', 'demoA.value', 2);
            try
                testCase.db.add_docs(second);
                testCase.verifyFail('a replay against a different database must be refused');
            catch ME
                causes = cellfun(@(c) c.identifier, ME.cause, 'UniformOutput', false);
                testCase.verifyTrue(ismember('DID:SQLITEDB:ReplayDiverged', causes));
            end
            testCase.verifyFalse(testCase.isOnDisk(second.id()));
        end
    end
end

function replaceWithCopy(path)
    % Replace the database with a byte-identical copy at the same path: the
    % open connection keeps the old inode, as when a sync client swaps a file.
    copyfile(path, [path '.moved']);
    movefile([path '.moved'], path, 'f');
end
