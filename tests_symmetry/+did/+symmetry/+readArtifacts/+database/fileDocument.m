classdef fileDocument < matlab.unittest.TestCase
    % FILEDOCUMENT - Open a file-bearing document's files from either language
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/database/test_file_document.py.
    %
    % Reading the Python artifact is the half that matters most here. MATLAB's
    % do_open_doc resolves a file by selecting from 'docs, files' and never
    % reads locations back out of the document JSON, so a Python-written
    % document whose files table was empty was completely unreadable from
    % MATLAB -- including a plain local file sitting on disk.
    %
    % Assumes rather than fails when the artifact is absent, so this test can
    % land in either repository first without blocking the other: each
    % repository's symmetry job checks out the other's main branch.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testFileDocumentArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'database', 'fileDocument', 'testFileDocumentArtifacts');

            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);

            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            dbPath = fullfile(artifactDir, manifest.dbFilename);
            testCase.assumeTrue(isfile(dbPath), ...
                ['Database file not found: ' dbPath]);

            db = did.implementations.sqlitedb(dbPath);

            % The document itself must be there.
            docs = db.get_docs(manifest.docId, 'OnMissing', 'ignore');
            testCase.verifyNotEmpty(docs, ...
                ['Document ' manifest.docId ' from ' SourceType ' not found.']);

            % jsondecode gives a struct array for a homogeneous list and a cell
            % array otherwise; normalize so both shapes iterate the same way.
            files = manifest.files;
            if ~iscell(files)
                files = num2cell(files);
            end

            for i = 1:numel(files)
                entry = files{i};
                expected = double(entry.bytes(:))';

                f = db.open_doc(manifest.docId, entry.name);
                fopen(f);
                testCase.verifyGreaterThan(f.fid, 0, ...
                    ['Could not open ' entry.name ' from ' SourceType ...
                     '. MATLAB resolves a file only through the files table, ' ...
                     'so an empty table makes every file unreachable.']);
                data = fread(f, Inf, 'uint8');
                fclose(f);

                testCase.verifyEqual(data(:)', expected, ...
                    ['Content mismatch for ' entry.name ' from ' SourceType '.']);
            end
        end
    end
end
