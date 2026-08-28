classdef TestFileValidation < matlab.unittest.TestCase
    % TestFileValidation
    % Regression tests for did.database file-validation helpers:
    %   - checkfiles must REJECT a document that is missing a required file
    %     (previously it set an error message but fell through to isvalid = 1,
    %      so schema validation failed open).
    %   - canfindonefile's http branch referenced an undefined variable `url`
    %     (the loop variable is fileLocation); the resulting error was swallowed
    %     so every http-hosted required file was reported missing.

    methods (Test)

        function testCheckfilesRejectsMissingRequiredFile(testCase)
            % A required file that is absent from the actual file_list must
            % make checkfiles return isvalid = 0 (was fail-open: isvalid = 1).
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

        function testCanfindonefileLocalMissingNoUrlError(testCase)
            % The (non-http) local-path branch must simply report not-found for
            % a path that does not exist - never throw an undefined-variable
            % error. Regression guard for the `url`/`fileLocation` typo.
            loc = struct('location', tempname);  % a path guaranteed not to exist
            found = did.database.canfindonefile(loc);
            testCase.verifyFalse(logical(found));
        end

        function testCanfindonefileFindsExistingLocalFile(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            f = fullfile(pwd, 'exists.bin');
            fid = fopen(f, 'w'); testCase.assertNotEqual(fid, -1);
            fwrite(fid, uint8(0:9)); fclose(fid);
            loc = struct('location', f);
            testCase.verifyTrue(logical(did.database.canfindonefile(loc)));
        end

        function testCanfindonefileHttpFailureWarns(testCase)
            % An unreachable http location must now WARN (distinguishable from a
            % genuinely absent file) instead of silently swallowing the error,
            % and must exercise the fixed req.send(fileLocation) call.
            loc = struct('location', 'http://localhost:0/does-not-exist');
            testCase.verifyWarning(@() did.database.canfindonefile(loc), ...
                'DID:Database:FileCheck');
        end

    end
end
