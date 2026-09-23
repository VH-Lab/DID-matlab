classdef pathAgreement < matlab.unittest.TestCase
    % PATHAGREEMENT - Record where this language thinks the file cache lives
    %
    % Mirrors DID-python's
    % tests/symmetry/make_artifacts/common/test_path_agreement.py.
    %
    % The two languages share one file cache directory. Everything else in
    % the symmetry suite checks that they agree on the *contents* of that
    % directory; nothing checked that they agree on *which* directory, and
    % that is the assumption all the rest rests on. If one side's path
    % changes, the caches silently stop being shared -- no error, no failing
    % test, just two half-populated caches and every file fetched twice.
    %
    % So each language writes its filecachepath here and the other asserts
    % it matches its own. Both run in the same job with the same
    % environment, which is what makes the comparison meaningful.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)
        function testPathAgreementArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'common', 'pathAgreement', ...
                'testPathAgreementArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            manifest = struct( ...
                'fileCachePath', did.common.PathConstants.filecachepath, ...
                'homeDirectory', did.common.homeDirectory());

            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest));
            fclose(fid);

            % Self-check before asking the other language to agree with it.
            testCase.verifyEqual(manifest.fileCachePath, ...
                fullfile(manifest.homeDirectory, 'Documents', 'DID', 'fileCache'));
        end
    end
end
