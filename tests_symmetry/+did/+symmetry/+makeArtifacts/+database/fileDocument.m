classdef fileDocument < matlab.unittest.TestCase
    % FILEDOCUMENT - Generate artifacts holding a file-bearing document
    %
    % Mirrors DID-python's
    % tests/symmetry/make_artifacts/database/test_file_document.py.
    %
    % The buildDatabase symmetry pair covers demoA/demoB/demoC documents, none
    % of which declares a 'files' section, and it compares database summaries,
    % which carry no file information. So nothing in the symmetry suite
    % exercised the file subsystem across languages: no document had a file,
    % nothing called open_doc, and the compared summary had nowhere to show a
    % difference. This pair closes that.
    %
    % Note what MATLAB does that Python does not: a local file is ingested into
    % FileDir ('files/' beside the .sqlite file), named by the location's uid,
    % and the original is then deleted. The document JSON still holds the
    % original path, which no longer exists, so a reader can only find the file
    % through the 'files' table.

    properties (Constant)
        dbFilename = 'file_document_test.sqlite'
        branchName = 'branch_main'
        % demoFile declares exactly these two files, both mustbenotempty.
        fileNames = {'filename1.ext', 'filename2.ext'}
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (TestMethodTeardown)
        function teardownMethod(~)
            % Artifacts must persist in tempdir for the Python suite to read.
        end
    end

    methods (Test)
        function testFileDocumentArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'database', 'fileDocument', ...
                'testFileDocumentArtifacts'); %#ok<*PROPLC>

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Step 1: create the database and a branch
            dbPath = fullfile(artifactDir, testCase.dbFilename);
            db = did.implementations.sqlitedb(dbPath);
            db.add_branch(testCase.branchName);

            % Step 2: write the source files and attach them to a demoFile doc.
            % Content is deterministic and matches the Python side: file i holds
            % 10 consecutive bytes starting at (i-1)*10.
            doc = did.document('demoFile', 'demoFile.value', 1);
            for i = 1:numel(testCase.fileNames)
                sourcePath = fullfile(artifactDir, ['source_' testCase.fileNames{i}]);
                fid = fopen(sourcePath, 'w');
                testCase.assertNotEqual(fid, -1, ...
                    ['Could not create ' sourcePath]);
                fwrite(fid, uint8((i-1)*10 + (0:9)), 'uint8');
                fclose(fid);
                doc = doc.add_file(testCase.fileNames{i}, sourcePath);
            end

            db.add_docs(doc);

            % Step 3: write a manifest the reader can check against without
            % recomputing anything.
            manifest = struct();
            manifest.dbFilename = testCase.dbFilename;
            manifest.branchName = testCase.branchName;
            manifest.docId = doc.id();
            files = cell(1, numel(testCase.fileNames));
            for i = 1:numel(testCase.fileNames)
                entry = struct();
                entry.name = testCase.fileNames{i};
                entry.bytes = (i-1)*10 + (0:9);
                files{i} = entry;
            end
            manifest.files = files;

            manifestPath = fullfile(artifactDir, 'manifest.json');
            fid = fopen(manifestPath, 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest, 'PrettyPrint', true));
            fclose(fid);

            % Step 4: self-check. Every file must be readable through open_doc
            % here, before any cross-language claim is made about it. By this
            % point the originals have been ingested and deleted, so this also
            % confirms the files table is doing the work.
            for i = 1:numel(testCase.fileNames)
                f = db.open_doc(doc.id(), testCase.fileNames{i});
                fopen(f);
                testCase.assertGreaterThan(f.fid, 0, ...
                    ['Could not open ' testCase.fileNames{i}]);
                data = fread(f, Inf, 'uint8');
                fclose(f);
                testCase.verifyEqual(data(:)', double((i-1)*10 + (0:9)), ...
                    ['Wrong bytes for ' testCase.fileNames{i}]);
            end
        end
    end
end
