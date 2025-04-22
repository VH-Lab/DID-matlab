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
    end
end
