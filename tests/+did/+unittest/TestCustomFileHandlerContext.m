classdef TestCustomFileHandlerContext < matlab.unittest.TestCase
    % Test the widened customFileHandler contract added for DID-matlab #186.
    %
    % A handler declared with two positional inputs still sees the old
    % HANDLER(destPath, sourcePath) call. A handler declared with three or
    % more, or with varargin, is called as HANDLER(destPath, sourcePath,
    % context) instead, receiving a per-call struct that carries the
    % documentId (and, for a series member being ingested, the series name)
    % so a downstream package like NDI can key a per-document URL cache and
    % call a batch presign endpoint instead of one API round trip per uid.
    %
    % Backward compatibility is what the existing TestCustomFileHandler and
    % TestFileSeriesRoundTrip suites already prove: they use two-argument
    % handlers everywhere and must continue to pass unchanged.

    properties
        db          % Database object
        payload     % A local file the handlers copy from
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.implementations.sqlitedb('contextdb.sqlite');
            testCase.db.add_branch('a');

            testCase.payload = fullfile(pwd, 'payload.bin');
            fid = fopen(testCase.payload, 'w', 'ieee-le');
            testCase.assertNotEqual(fid, -1);
            fwrite(fid, uint8(1:10), 'uint8');
            fclose(fid);
        end
    end

    methods (Test)
        function testAddFileGivesContextToAThreeArgHandler(testCase)
            % A remote file marked for ingestion goes through the file_info
            % branch of do_add_doc, so the handler is called there with
            % context describing the ordinary (non-series) case.
            payload = testCase.payload;
            calls = {};
            function record(destPath, sourcePath, ctx)
                calls{end+1} = ctx;
                copyfile(payload, destPath);
            end

            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', 'https://nosuchserver.invalid/one.ext', ...
                'ingest', 1);
            doc = doc.add_file('filename2.ext', 'https://nosuchserver.invalid/two.ext');

            testCase.verifyWarningFree(@() testCase.db.add_docs(doc, ...
                'customFileHandler', @record));

            testCase.assertNumElements(calls, 1, ...
                'Only the ingested file goes through the handler.');
            ctx = calls{1};
            testCase.verifyEqual(ctx.documentId, doc.id(), ...
                'documentId matches the document being added.');
            testCase.verifyEqual(ctx.filename, 'filename1.ext', ...
                'filename matches the file the handler is called for.');
            testCase.verifyEqual(ctx.seriesName, '', ...
                'seriesName is empty for a non-series file.');
            testCase.verifyEqual(ctx.mode, 'add', ...
                'mode is "add" in the add_docs path.');
            testCase.verifyNotEmpty(ctx.uid, ...
                'uid is the ingested file''s uid.');
        end

        function testAddSeriesMemberGivesSeriesContext(testCase)
            % The series-member ingest loop is where a batch presign scoped
            % to a fileSeries pays off. Every member call must see the same
            % documentId AND the seriesName, so NDI can key its cache by
            % (datasetId, documentId, seriesName) and hit the endpoint once.
            payload = testCase.payload;
            calls = {};
            function record(destPath, sourcePath, ctx)
                calls{end+1} = ctx;
                copyfile(payload, destPath);
            end

            doc = did.document('demoSeries', 'demoSeries.value', 1);
            locs = {'https://nosuchserver.invalid/a.bin', ...
                    'https://nosuchserver.invalid/b.bin', ...
                    'https://nosuchserver.invalid/c.bin'};
            doc = doc.addFileSeries('chunkdata.bin', locs, 'ingest', 1);

            testCase.verifyWarningFree(@() testCase.db.add_docs(doc, ...
                'customFileHandler', @record));

            testCase.assertNumElements(calls, 3, ...
                'Every ingested member goes through the handler.');
            for i = 1:3
                ctx = calls{i};
                testCase.verifyEqual(ctx.documentId, doc.id(), ...
                    sprintf('member %d: documentId', i));
                testCase.verifyEqual(ctx.seriesName, 'chunkdata.bin', ...
                    sprintf('member %d: seriesName is the series being ingested', i));
                testCase.verifyEqual(ctx.filename, sprintf('chunkdata.bin_%d', i), ...
                    sprintf('member %d: filename is NAME_<i>', i));
                testCase.verifyEqual(ctx.mode, 'add', ...
                    sprintf('member %d: mode', i));
                testCase.verifyNotEmpty(ctx.uid, ...
                    sprintf('member %d: uid', i));
            end
        end

        function testOpenDocGivesContextToAThreeArgHandler(testCase)
            % The read path. A document whose only location is remote is
            % retrieved through the handler; context lets a batching NDI
            % populate its cache before returning the first file.
            payload = testCase.payload;
            calls = {};
            function record(destPath, sourcePath, ctx)
                calls{end+1} = ctx;
                copyfile(payload, destPath);
            end

            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', 'https://nosuchserver.invalid/one.ext');
            doc = doc.add_file('filename2.ext', 'https://nosuchserver.invalid/two.ext');
            testCase.db.add_docs(doc);

            f = testCase.db.open_doc(doc.id(), 'filename1.ext', ...
                'customFileHandler', @record);
            fopen(f);
            fclose(f);

            testCase.assertNumElements(calls, 1);
            ctx = calls{1};
            testCase.verifyEqual(ctx.documentId, doc.id(), ...
                'documentId matches the opened document.');
            testCase.verifyEqual(ctx.filename, 'filename1.ext', ...
                'filename matches the requested file.');
            testCase.verifyEqual(ctx.seriesName, '', ...
                'seriesName is empty for an ordinary file open.');
            testCase.verifyEqual(ctx.mode, 'open', ...
                'mode is "open" in the open_doc path.');
            testCase.verifyNotEmpty(ctx.uid, ...
                'uid identifies the file being retrieved.');
        end

        function testTwoArgHandlerStillWorks(testCase)
            % The whole point of the arity dispatch. A pre-#186 handler
            % declared with exactly two inputs must never see the extra
            % third argument, or a strict `nargin` check inside it would
            % break. Verify by using a two-arg handler through the same
            % code paths above.
            payload = testCase.payload;

            % add-file path
            docA = did.document('demoFile', 'demoFile.value', 1);
            docA = docA.add_file('filename1.ext', 'https://nosuchserver.invalid/one.ext', ...
                'ingest', 1);
            docA = docA.add_file('filename2.ext', 'https://nosuchserver.invalid/two.ext');
            twoArg = @(destPath, sourcePath) copyfile(payload, destPath);
            testCase.verifyWarningFree(@() testCase.db.add_docs(docA, ...
                'customFileHandler', twoArg));

            % open path
            docB = did.document('demoFile', 'demoFile.value', 2);
            docB = docB.add_file('filename1.ext', 'https://nosuchserver.invalid/three.ext');
            docB = docB.add_file('filename2.ext', 'https://nosuchserver.invalid/four.ext');
            testCase.db.add_docs(docB);
            f = testCase.db.open_doc(docB.id(), 'filename1.ext', ...
                'customFileHandler', twoArg);
            fopen(f);
            testCase.verifyGreaterThan(f.fid, 0);
            fclose(f);
        end

        function testVarargHandlerReceivesContext(testCase)
            % nargin(handler) is negative for varargin. Dispatch must treat
            % that as "opts in" and pass 3 arguments so a varargin-style
            % handler can read the context.
            payload = testCase.payload;
            calls = {};
            function recordVararg(varargin)
                % varargin: {destPath, sourcePath, [context]}
                copyfile(payload, varargin{1});
                if numel(varargin) >= 3
                    calls{end+1} = varargin{3};
                else
                    calls{end+1} = struct(); % would fail the assertions below
                end
            end

            doc = did.document('demoFile', 'demoFile.value', 1);
            doc = doc.add_file('filename1.ext', 'https://nosuchserver.invalid/one.ext', ...
                'ingest', 1);
            doc = doc.add_file('filename2.ext', 'https://nosuchserver.invalid/two.ext');

            testCase.verifyWarningFree(@() testCase.db.add_docs(doc, ...
                'customFileHandler', @recordVararg));

            testCase.assertNumElements(calls, 1);
            ctx = calls{1};
            testCase.assertTrue(isfield(ctx, 'documentId'), ...
                'A varargin handler received context.');
            testCase.verifyEqual(ctx.documentId, doc.id());
            testCase.verifyEqual(ctx.mode, 'add');
        end
    end
end
