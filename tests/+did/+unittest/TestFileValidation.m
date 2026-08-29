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
