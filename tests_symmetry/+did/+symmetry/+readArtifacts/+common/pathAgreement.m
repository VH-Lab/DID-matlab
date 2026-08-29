classdef pathAgreement < matlab.unittest.TestCase
    % PATHAGREEMENT - Check the other language names the same file cache
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/common/test_path_agreement.py.
    %
    % This is the assumption every other file-cache symmetry test rests on.
    % They check that the two languages agree on the contents of the shared
    % directory; this checks they agree on which directory. A divergence
    % here has no symptom -- no error, no failing test, just two
    % half-populated caches and every file fetched twice.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testPathAgreementArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'common', 'pathAgreement', 'testPathAgreementArtifacts');

            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);
            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            testCase.verifyEqual(manifest.fileCachePath, ...
                did.common.PathConstants.filecachepath, ...
                [SourceType ' names a different file cache directory. The two ' ...
                 'languages share this cache, so a divergence here means each ' ...
                 'silently keeps its own and every file is fetched twice.']);
        end
    end
end
