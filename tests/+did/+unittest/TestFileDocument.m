classdef TestFileDocument < matlab.unittest.TestCase
    % Test the functionality of the did.document and did.database file components

    properties (Constant)
        db_filename = 'filetestdb.sqlite' % Holds the path to the SQLite database
    end

    properties
        db             % Database object
        doc            % Document object
        fullfilename   % Full file paths for test files
        fname          % Filenames
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            testCase.applyFixture(did.test.fixture.PathConstantFixture)

            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');

            testCase.createExampleFiles()
            testCase.addFakeURLs()
            testCase.addDocumentToDatabase()
            testCase.deleteOriginalFiles()
        end
    end

    methods
        function createExampleFiles(testCase)
            % Step 2: Create example files with 10 consecutive binary numbers

            testCase.fname = {'filename1.ext', 'filename2.ext'};
            testCase.doc = did.document('demoFile', 'demoFile.value', 1);

            for i = 1:numel(testCase.fname)
                testCase.fullfilename{i} = fullfile(pwd, testCase.fname{i});
                fid = fopen(testCase.fullfilename{i}, 'w', 'ieee-le');
                testCase.assertNotEqual(fid, -1, ['Could not open file ', testCase.fullfilename{i}, ' for writing.']);

                fwrite(fid, char((i-1)*10 + (0:9)), 'char');
                fclose(fid);

                % Add the file to the document
                testCase.doc = testCase.doc.add_file(testCase.fname{i}, testCase.fullfilename{i});
            end
        end

        function addFakeURLs(testCase)
            % Step 3: Add fake URLs to the document
            url_prefix = 'https://nosuchserver.com.notthere/';
            for i = 1:numel(testCase.fname)
                testCase.doc = testCase.doc.add_file(testCase.fname{i}, [url_prefix, testCase.fname{i}]);
            end
        end

        function addDocumentToDatabase(testCase)
            % Step 4: Add the document to the database
            testCase.db.add_docs(testCase.doc);
        end

        function deleteOriginalFiles(testCase)
            % Step 5: Delete the original files from the filesystem
            for i = 1:numel(testCase.fullfilename)
                if isfile(testCase.fullfilename{i})
                    delete(testCase.fullfilename{i});
                end
            end
        end
    end

    methods (Test)
        function testFileDocumentOperations(testCase)
            % Perform the test of the file document operations

            % Search and retrieve documents from the database
            g = testCase.db.search(did.query('', 'isa', 'demoFile', ''));
            doc_g = testCase.db.get_docs(g);

            % Verify file contents
            data = {};
            for i = 1:numel(testCase.fname)
                % Open the file stored in the database
                f = testCase.db.open_doc(g{1}, testCase.fname{i});
                fopen(f);
                testCase.assertGreaterThan(f.fid, 0, ['Could not open document file ', testCase.fname{i}, '.']);

                % Read and compare file data
                data{i} = fread(f, Inf, 'char');
                fclose(f);
                expectedData = (i-1)*10 + (0:9)';
                testCase.verifyTrue( logical(did.datastructures.eqlen(data{i}, expectedData)), ...
                    ['Data for file ', testCase.fname{i}, ' did not match.']);
            end
        end

        function testExistDocRequiresFileOnDisk(testCase)
            % Regression: check_exist_doc must verify the file is actually on
            % disk (isfile), not merely that a files-table row exists, and must
            % return a path that points to a real file. Previously the
            % single-row branch returned tf = true without ever calling isfile.
            g = testCase.db.search(did.query('', 'isa', 'demoFile', ''));
            doc_id = g{1};

            % After setup the file is cached, so it exists and the returned
            % path must be a real file.
            [tf, fpath] = testCase.db.exist_doc(doc_id, testCase.fname{1});
            testCase.verifyTrue(logical(tf), ...
                'exist_doc should report the cached file as existing');
            testCase.verifyTrue(isfile(fpath), ...
                'exist_doc must return a path that points to a real file');

            % Remove the cached file from disk (the files-table row remains).
            % Restore it immediately afterwards so shared fixture state used by
            % other Test methods is unaffected, then assert.
            backup = [fpath '.existdoc.bak'];
            copyfile(fpath, backup);
            delete(fpath);
            tf2 = testCase.db.exist_doc(doc_id, testCase.fname{1});
            movefile(backup, fpath);   % restore before asserting

            testCase.verifyFalse(logical(tf2), ...
                'exist_doc must return false when no cached file is on disk');
        end
    end
end
