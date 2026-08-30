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
            % Build a demoFile document referencing real files on disk
            %
            % The demoFile schema requires both filename1.ext and filename2.ext,
            % so both are created and attached. add_file defaults a local path
            % to ingest=1, so add_docs copies each into the file cache and
            % records its path in files.cached_location.
            fnames = {'filename1.ext', 'filename2.ext'};
            doc = did.document('demoFile', 'demoFile.value', 1);
            for i = 1:numel(fnames)
                fullfilename = fullfile(pwd, fnames{i});
                fid = fopen(fullfilename, 'w', 'ieee-le');
                testCase.assertNotEqual(fid, -1, ...
                    ['Could not open file ' fullfilename ' for writing.']);
                fwrite(fid, char((i-1)*10 + (0:9)), 'char');
                fclose(fid);

                doc = doc.add_file(fnames{i}, fullfilename);
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

            testCase.db.remove_docs(doc.id());

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
