classdef TestDocumentReclamation < matlab.unittest.TestCase
    % Test that a document removed from its last branch is removed completely
    %
    % Covers DID-matlab issue #55:
    %   1. the document's cached files are deleted from disk
    %   2. the document's field (doc_data) records are deleted
    %   3. the document's id is retired and can never be added again
    %
    % A document that another branch still references must be left alone by
    % all three.
    %
    % Also covers the two paths a database that predates issue #55 takes - or
    % one written by DID-python, which has no deleted_docs table at all: its
    % absence must never be an error, and the table must appear only when a
    % document is actually retired.

    properties (Constant)
        db_filename = 'test_db_reclaim.sqlite' % Path to the SQLite database
    end

    properties
        db % Holds the database object
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            testCase.applyFixture(did.test.fixture.PathConstantFixture)

            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
        end
    end

    methods
        function rows = queryRows(testCase, query_str)
            % Run a query and return its rows as a struct array ({} if none)
            rows = testCase.db.run_sql_query(query_str, true);
        end

        function idx = docIdx(testCase, doc_id)
            % Fetch the doc_idx of a document, or [] if the docs row is gone
            rows = testCase.queryRows(['SELECT doc_idx FROM docs WHERE doc_id="' doc_id '"']);
            if isempty(rows)
                idx = [];
            else
                idx = rows(1).doc_idx;
            end
        end

        function doc = makeFileDocument(testCase)
            % Build a demoFile document with both ingested and un-ingested files
            %
            % The demoFile schema requires both filename1.ext and filename2.ext,
            % so both are created and attached. Each name gets two locations, as
            % in TestFileDocument:
            %   - the local path, which add_file defaults to ingest=1, so
            %     add_docs copies it into the file cache and records the copy in
            %     files.cached_location;
            %   - a URL, which add_file defaults to ingest=0, so add_docs records
            %     a files row whose cached_location is empty and fetches nothing.
            % The document therefore exercises both branches of the cached-file
            % deletion loop: a row with a file to delete, and a row with none.
            fnames = {'filename1.ext', 'filename2.ext'};
            url_prefix = 'https://nosuchserver.com.notthere/';
            doc = did.document('demoFile', 'demoFile.value', 1);
            for i = 1:numel(fnames)
                fullfilename = fullfile(pwd, fnames{i});
                fid = fopen(fullfilename, 'w', 'ieee-le');
                testCase.assertNotEqual(fid, -1, ...
                    ['Could not open file ' fullfilename ' for writing.']);
                fwrite(fid, char((i-1)*10 + (0:9)), 'char');
                fclose(fid);

                doc = doc.add_file(fnames{i}, fullfilename);
                doc = doc.add_file(fnames{i}, [url_prefix fnames{i}]);
            end
        end

        function n = uncachedRowCountOf(testCase, doc_idx)
            % Count this document's files rows that have no cached copy
            rows = testCase.queryRows(...
                sprintf('SELECT cached_location FROM files WHERE doc_idx=%d', doc_idx));
            n = 0;
            for i = 1:numel(rows)
                if isempty(rows(i).cached_location)
                    n = n + 1;
                end
            end
        end

        function files = cachedFilesOf(testCase, doc_idx)
            % Return the non-empty cached_location values of a document
            rows = testCase.queryRows(...
                sprintf('SELECT cached_location FROM files WHERE doc_idx=%d', doc_idx));
            files = {};
            for i = 1:numel(rows)
                if ~isempty(rows(i).cached_location)
                    files{end+1} = rows(i).cached_location; %#ok<AGROW>
                end
            end
        end
    end

    methods (Test)
        function testFieldDataRemovedWithLastBranchReference(testCase)
            % Issue #55 item 2: do_remove_doc used to delete only the
            % branch_docs row, leaving the docs and doc_data records behind for
            % a document that no branch referenced any more.
            doc = did.document('demoA','demoA.value',1);
            testCase.db.add_docs(doc);

            doc_idx = testCase.docIdx(doc.id());
            testCase.assertNotEmpty(doc_idx, 'setup: the docs row should exist');
            testCase.assertNotEmpty(testCase.queryRows(...
                sprintf('SELECT field_idx FROM doc_data WHERE doc_idx=%d', doc_idx)), ...
                'setup: the document should have doc_data rows');

            testCase.db.remove_docs(doc.id());

            testCase.verifyEmpty(testCase.docIdx(doc.id()), ...
                'the docs row must be gone once no branch references the document');
            testCase.verifyEmpty(testCase.queryRows(...
                sprintf('SELECT field_idx FROM doc_data WHERE doc_idx=%d', doc_idx)), ...
                'the doc_data rows must be gone once no branch references the document');
        end

        function testCachedFilesDeletedWithLastBranchReference(testCase)
            % Issue #55 item 1: the ingested copies of the document's files were
            % left on disk, and their files rows left in the database.
            doc = testCase.makeFileDocument();
            testCase.db.add_docs(doc);

            doc_idx = testCase.docIdx(doc.id());
            testCase.assertNotEmpty(doc_idx, 'setup: the docs row should exist');
            cached_files = testCase.cachedFilesOf(doc_idx);
            testCase.assertNotEmpty(cached_files, ...
                'setup: the document should have cached files');
            for i = 1:numel(cached_files)
                testCase.assertTrue(isfile(cached_files{i}), ...
                    ['setup: the file should have been cached to ' cached_files{i}]);
            end

            % The URL locations gave this document files rows with no cached
            % copy. Removal must step over those rather than try to delete ''.
            testCase.assertGreaterThan(testCase.uncachedRowCountOf(doc_idx), 0, ...
                'setup: the document should also have un-ingested files rows');

            % debug on: the removal reports each cached file it deletes
            testCase.db.debug = true;
            testCase.db.remove_docs(doc.id());
            testCase.db.debug = false;

            for i = 1:numel(cached_files)
                testCase.verifyFalse(isfile(cached_files{i}), ...
                    ['the cached file must be deleted from disk: ' cached_files{i}]);
            end
            testCase.verifyEmpty(testCase.queryRows(...
                sprintf('SELECT uid FROM files WHERE doc_idx=%d', doc_idx)), ...
                'the files rows must be gone once no branch references the document');
        end

        function testRemovedDocumentIdCannotBeAddedAgain(testCase)
            % Issue #55 item 3: adding a document whose id was already removed
            % from every branch must be refused outright.
            doc = did.document('demoA','demoA.value',1);
            testCase.db.add_docs(doc);
            testCase.db.remove_docs(doc.id());

            testCase.verifyError(@() testCase.db.add_docs(doc), ...
                'DID:SQLITEDB:DELETED_DOC', ...
                'a retired document id must not be addable again');

            % ...and the refusal must survive closing and reopening the file,
            % so it has to be recorded in the database rather than in memory.
            testCase.db.close();
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.verifyError(@() testCase.db.add_docs(doc,'a'), ...
                'DID:SQLITEDB:DELETED_DOC', ...
                'the retired id must be recorded in the database, not just in memory');
        end

        function testDocumentOnAnotherBranchIsUntouched(testCase)
            % The reclamation must fire only when the LAST reference goes. A
            % document that branch 'a' still holds must keep its records and its
            % cached files after being removed from branch 'a_a'.
            doc = testCase.makeFileDocument();
            testCase.db.add_docs(doc);

            doc_idx = testCase.docIdx(doc.id());
            cached_files = testCase.cachedFilesOf(doc_idx);
            testCase.assertNotEmpty(cached_files, ...
                'setup: the document should have cached files');

            % Branch 'a_a' inherits the document from 'a'
            testCase.db.add_branch('a_a','a');
            testCase.db.remove_docs(doc.id(),'a_a');

            testCase.verifyEqual(testCase.docIdx(doc.id()), doc_idx, ...
                'the docs row must survive while branch a still references the document');
            testCase.verifyNotEmpty(testCase.queryRows(...
                sprintf('SELECT field_idx FROM doc_data WHERE doc_idx=%d', doc_idx)), ...
                'the doc_data rows must survive while another branch references the document');
            for i = 1:numel(cached_files)
                testCase.verifyTrue(isfile(cached_files{i}), ...
                    ['the cached file must survive while another branch ' ...
                     'references the document: ' cached_files{i}]);
            end
        end

        function testDatabaseWithoutDeletedDocsTableStillWorks(testCase)
            % A database written before issue #55 - or by DID-python, which has
            % no deleted_docs table at all - must stay fully usable. The table
            % is absent there, so its absence can never be an error, and it must
            % appear only when a document is actually retired, not merely
            % because such a database was opened.
            testCase.db.run_sql_query('DROP TABLE deleted_docs');
            testCase.assertEmpty(testCase.queryRows(...
                ['SELECT name FROM sqlite_master ' ...
                 'WHERE type=''table'' AND name=''deleted_docs''']), ...
                'setup: the deleted_docs table should be gone');

            % Adding must not care that the table is missing
            doc = did.document('demoA','demoA.value',1);
            testCase.verifyWarningFree(@() testCase.db.add_docs(doc));

            % Reading such a database must not create the table either
            testCase.db.get_docs(doc.id());
            testCase.verifyEmpty(testCase.queryRows(...
                ['SELECT name FROM sqlite_master ' ...
                 'WHERE type=''table'' AND name=''deleted_docs''']), ...
                'reading a database must not add the deleted_docs table to it');

            % Removing the last reference creates the table on demand...
            testCase.db.remove_docs(doc.id());
            testCase.verifyNotEmpty(testCase.queryRows(...
                ['SELECT name FROM sqlite_master ' ...
                 'WHERE type=''table'' AND name=''deleted_docs''']), ...
                'retiring an id must create the deleted_docs table on demand');

            % ...and the id is retired in it, exactly as in a database that
            % carried the table from the start
            testCase.verifyError(@() testCase.db.add_docs(doc), ...
                'DID:SQLITEDB:DELETED_DOC');
        end

        function testIdStillOnAnotherBranchIsNotRetired(testCase)
            % Removing a document from one branch while another branch still
            % holds it is not a deletion, so the id must stay usable. (A
            % file-less document is used here: re-adding a document that owns a
            % file re-runs the file-caching loop and trips the pre-existing
            % files.uid UNIQUE warning, which is a separate problem.)
            doc = did.document('demoA','demoA.value',1);
            testCase.db.add_docs(doc);

            % Branch 'a_a' inherits the document from 'a'
            testCase.db.add_branch('a_a','a');
            testCase.db.remove_docs(doc.id(),'a_a');

            testCase.verifyWarningFree(@() testCase.db.add_docs(doc,'a_a'));
            ids = testCase.db.search(did.query('base.id','exact_string',doc.id()),'a_a');
            testCase.verifyNumElements(ids, 1, ...
                'branch a_a should hold the document again after re-adding it');
        end
    end
end
