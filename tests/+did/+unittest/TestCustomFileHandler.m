classdef TestCustomFileHandler < matlab.unittest.TestCase
    % Test retrieval of non-local file locations through customFileHandler.
    %
    % DID downloads nothing itself. A location that is not a local path is
    % handed to a caller-supplied handler, called as HANDLER(DESTPATH,
    % SOURCEPATH) and required to produce a file at DESTPATH. This is how a
    % downstream package (NDI) supplies retrieval without DID depending on it.
    %
    % These paths previously called ndi.cloud.api.files.getFile directly, in
    % both do_open_doc and do_add_doc, which made DID depend on NDI being on
    % the path.

    properties
        db          % Database object
        srcFile     % A real local file a handler can copy from
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % A fresh working folder and database per test, so documents added
            % by one test cannot collide with another.
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.implementations.sqlitedb('customhandlerdb.sqlite');
            testCase.db.add_branch('a');

            testCase.srcFile = fullfile(pwd, 'payload.bin');
            fid = fopen(testCase.srcFile, 'w', 'ieee-le');
            testCase.assertNotEqual(fid, -1, 'Could not create the payload file.');
            fwrite(fid, char(0:9), 'char');
            fclose(fid);
        end
    end

    methods
        function doc = remoteDoc(testCase, varargin)
            % A demoFile document whose first file is a remote location
            % explicitly marked for ingestion. Remote locations default to
            % ingest 0, so ingestion has to be asked for.
            % Both files are remote so that only the first, explicitly marked
            % for ingestion, exercises the retrieval branch. A local second
            % file would drag an unrelated copyfile/delete_original path into
            % the warning-free assertions below.
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file(doc_name(1), 'https://nosuchserver.invalid/one.ext', ...
                'ingest', 1, varargin{:});
            doc = doc.add_file(doc_name(2), 'https://nosuchserver.invalid/two.ext');
        end
    end

    methods (Test)
        function testIngestUsesTheHandler(testCase)
            % The handler is called and its file is accepted, so the add
            % completes without the "Failed to cache" warning.
            source = testCase.srcFile;
            handler = @(destPath, sourcePath) copyfile(source, destPath);
            doc = testCase.remoteDoc();

            testCase.verifyWarningFree( ...
                @() testCase.db.add_docs(doc, 'customFileHandler', handler));
        end

        function testIngestWithoutAHandlerWarnsButStillAdds(testCase)
            % Without a handler there is nothing that can retrieve a remote
            % location. That warns rather than failing the add -- the same
            % non-fatal behaviour ingestion has always had.
            doc = testCase.remoteDoc();

            testCase.verifyWarning( ...
                @() testCase.db.add_docs(doc), 'DID:SQLiteDB:add_doc');

            g = testCase.db.search(did.query('', 'isa', 'demoFile', ''));
            testCase.verifyNumElements(g, 1, ...
                'The document should still have been added.');
        end

        function testHandlerThatProducesNothingWarns(testCase)
            % MATLAB checks isfile(destPath) after the handler returns.
            handler = @(destPath, sourcePath) [];
            doc = testCase.remoteDoc();

            testCase.verifyWarning( ...
                @() testCase.db.add_docs(doc, 'customFileHandler', handler), ...
                'DID:SQLiteDB:add_doc');
        end

        function testHandlerThatErrorsWarns(testCase)
            % A throwing handler is caught and reported, not propagated.
            handler = @(destPath, sourcePath) error('the cloud is down');
            doc = testCase.remoteDoc();

            testCase.verifyWarning( ...
                @() testCase.db.add_docs(doc, 'customFileHandler', handler), ...
                'DID:SQLiteDB:add_doc');
        end

        function testDeleteOriginalSkipsARemoteLocation(testCase)
            % delete_original must not be applied to a location carrying a
            % '://' scheme: it is not ours to remove, and delete() on such a
            % string warns that the file was not found. Warning-free here is
            % what shows the guard is doing its job.
            source = testCase.srcFile;
            handler = @(destPath, sourcePath) copyfile(source, destPath);
            doc = testCase.remoteDoc('delete_original', 1);

            testCase.verifyWarningFree( ...
                @() testCase.db.add_docs(doc, 'customFileHandler', handler));
        end

        function testOpenDocUsesTheHandler(testCase)
            % The read side of the same contract: a document whose file is
            % only available remotely is retrieved through the handler.
            source = testCase.srcFile;
            handler = @(destPath, sourcePath) copyfile(source, destPath);

            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file(doc_name(1), 'https://nosuchserver.invalid/one.ext');
            doc = doc.add_file(doc_name(2), 'https://nosuchserver.invalid/two.ext');
            testCase.db.add_docs(doc);

            g = testCase.db.search(did.query('', 'isa', 'demoFile', ''));
            f = testCase.db.open_doc(g{1}, doc_name(1), ...
                'customFileHandler', handler);
            fopen(f);
            testCase.verifyGreaterThan(f.fid, 0, ...
                'The retrieved file should have opened.');
            data = fread(f, Inf, 'char');
            fclose(f);
            testCase.verifyEqual(numel(data), 10, ...
                'The retrieved file should hold the payload.');
        end

        function testOpenDocWithoutAHandlerErrors(testCase)
            % No handler and nothing local: DID cannot retrieve it itself.
            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file(doc_name(1), 'https://nosuchserver.invalid/one.ext');
            doc = doc.add_file(doc_name(2), 'https://nosuchserver.invalid/two.ext');
            testCase.db.add_docs(doc);

            g = testCase.db.search(did.query('', 'isa', 'demoFile', ''));
            testCase.verifyError( ...
                @() testCase.db.open_doc(g{1}, doc_name(1)), ...
                'DID:SQLITEDB:open');
        end
    end
end

function name = doc_name(index)
    % The two file names the demoFile class declares.
    names = {'filename1.ext', 'filename2.ext'};
    name = names{index};
end
