classdef TestFileValidation < matlab.unittest.TestCase
    % TestFileValidation
    % Regression tests for did.database's file-validation helpers.
    %
    % checkfiles must REJECT a document that is missing a required file. It
    % used to set an error message and then fall through to isvalid = 1, so
    % add_docs committed the document anyway -- schema validation failed open.
    %
    % Trimmed from audriB's original in PR #154: the two canfindonefile tests
    % that asserted a non-local location is NOT found have been dropped. That
    % was true of the branch as it stood then; since #156 this package
    % deliberately does no network I/O during validation, so a location it
    % cannot pre-check is admitted and its reachability is reported when the
    % file is read. A URL behaves as a mustbenotempty == 0 file does.

    methods (Test)

        function testCheckfilesRejectsMissingRequiredFile(testCase)
            % A required file absent from the actual file_list must make
            % checkfiles return isvalid = 0 (was fail-open: isvalid = 1).
            expectedNames    = {'required.bin'};
            mustHaveValue    = {true};
            actualFileNames  = {};
            doc_name         = 'mydoc';
            files            = struct([]);   % not reached - missing_files short-circuits
            actual_file_list = {};           % required.bin absent here

            [isvalid, errmsg] = did.database.checkfiles( ...
                expectedNames, mustHaveValue, actualFileNames, ...
                doc_name, files, actual_file_list);

            testCase.verifyEqual(isvalid, 0, ...
                'checkfiles must reject a document missing a required file');
            testCase.verifyNotEmpty(errmsg, ...
                'checkfiles must report an error message for the missing file');
        end

        function testUnboundRequiredFileIsNotBlamedOnTheFileList(testCase)
            % The file IS in the document's file_list; what is absent is the
            % entry bound to it in file_info. checkfiles used to be handed a
            % {} file_list (the caller lost it to an exception) and so reported
            % this as a file_list problem; with the real file_list it used to
            % report nothing at all, because a required name with no match fell
            % out of an empty loop and reached isvalid = 1. See issue #199.
            expectedNames    = {'generic_file.ext'};
            mustHaveValue    = {true};
            actualFileNames  = {};              % nothing bound
            doc_name         = 'generic_file doc 123';
            files            = [];              % what a stored doc carries
            actual_file_list = {'generic_file.ext'};   % declared, and correct

            [isvalid, errmsg] = did.database.checkfiles( ...
                expectedNames, mustHaveValue, actualFileNames, ...
                doc_name, files, actual_file_list);

            testCase.verifyEqual(isvalid, 0, ...
                'a required file with nothing bound to it must be rejected');
            testCase.verifySubstring(errmsg, 'generic_file.ext', ...
                'the message must name the file that is not bound');
            testCase.verifySubstring(errmsg, 'file_info', ...
                'the message must name the field that is actually empty');
            testCase.verifyFalse(contains(errmsg, 'from the file_list'), ...
                ['the file_list holds the name and is correct: ' errmsg]);
        end

        function testUnboundRequiredFileWithAnEmptyStructFileInfo(testCase)
            % The same condition reached with the OTHER empty: a 0x0 struct
            % array, which did.document/reset_file_info produces and which
            % yields {} from {s.name} without throwing. Same answer.
            expectedNames    = {'generic_file.ext'};
            mustHaveValue    = {true};
            actualFileNames  = {};
            doc_name         = 'generic_file doc 123';
            files            = did.datastructures.emptystruct('name','locations');
            actual_file_list = {'generic_file.ext'};

            [isvalid, errmsg] = did.database.checkfiles( ...
                expectedNames, mustHaveValue, actualFileNames, ...
                doc_name, files, actual_file_list);

            testCase.verifyEqual(isvalid, 0, ...
                'the two empties mean the same thing and must be treated alike');
            testCase.verifySubstring(errmsg, 'generic_file.ext');
            testCase.verifySubstring(errmsg, 'file_info');
            testCase.verifyFalse(contains(errmsg, 'from the file_list'), ...
                ['the file_list holds the name and is correct: ' errmsg]);
        end

        function testDeclaredOptionalFileNeedNotBeBound(testCase)
            % mustbenotempty = 0 means the file need not be there. Reporting
            % the unbound required file above must not start refusing these.
            [isvalid, errmsg] = did.database.checkfiles( ...
                {'optional.bin'}, {false}, {}, 'mydoc', [], {'optional.bin'});

            testCase.verifyEqual(isvalid, 1, ...
                'an optional file that is not bound is not an error');
            testCase.verifyEmpty(errmsg);
        end

        function testMissingFromFileListKeepsItsOwnMessage(testCase)
            % The other absence: the name is not in the document's file_list at
            % all. That IS a file_list problem, and keeps saying so.
            [isvalid, errmsg] = did.database.checkfiles( ...
                {'required.bin'}, {true}, {}, 'mydoc', [], {'other.bin'});

            testCase.verifyEqual(isvalid, 0);
            testCase.verifySubstring(errmsg, 'file_list');
            testCase.verifySubstring(errmsg, 'required.bin');
        end

        function testCanfindonefileFindsExistingLocalFile(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            f = fullfile(pwd, 'exists.bin');
            fid = fopen(f, 'w'); testCase.assertNotEqual(fid, -1);
            fwrite(fid, uint8(0:9)); fclose(fid);
            loc = struct('location', f);
            testCase.verifyTrue(logical(did.database.canfindonefile(loc)));
        end

    end
end
