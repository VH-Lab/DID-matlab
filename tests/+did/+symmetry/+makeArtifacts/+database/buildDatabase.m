classdef buildDatabase < matlab.unittest.TestCase
    % BUILDDATABASE - Generate DID database artifacts for cross-language symmetry testing
    %
    % This test creates a small DID database with random documents (demoA, demoB, demoC)
    % across multiple branches, then exports the database file and per-branch JSON
    % audit files as artifacts for comparison with other DID implementations (e.g., Python).

    properties (Constant)
        dbFilename = 'symmetry_test.sqlite'
    end

    properties
        db          % The did.database object
        artifactDir % Path where artifacts will be saved
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (TestMethodTeardown)
        function teardownMethod(~)
            % Override teardown to do nothing: artifacts must persist in tempdir
            % so that the Python test suite can read them.
        end
    end

    methods (Test)
        function testBuildDatabaseArtifacts(testCase)
            % Use a fixed seed for reproducibility across runs
            rng('default');

            % Determine the artifact directory
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'database', 'buildDatabase', ...
                'testBuildDatabaseArtifacts'); %#ok<*PROPLC>
            testCase.artifactDir = artifactDir;

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Step 1: Create the database
            dbPath = fullfile(artifactDir, testCase.dbFilename);
            testCase.db = did.implementations.sqlitedb(dbPath);

            % Step 2: Create 3 branches in a simple hierarchy:
            %   branch_main
            %     ├── branch_dev
            %     └── branch_feature
            branchNames = {'branch_main', 'branch_dev', 'branch_feature'};

            % Create the root branch
            testCase.db.add_branch(branchNames{1});

            % Generate initial documents for the root branch (small counts)
            [~, ~, rootDocs] = did.test.helper.documents.make_doc_tree([3 3 3]);
            testCase.db.add_docs(rootDocs);

            % Create branch_dev as child of branch_main
            testCase.db.set_branch(branchNames{1});
            testCase.db.add_branch(branchNames{2});

            % Add some additional documents to branch_dev
            [~, ~, devDocs] = did.test.helper.documents.make_doc_tree([2 2 2]);
            testCase.db.add_docs(devDocs);

            % Create branch_feature as child of branch_main
            testCase.db.set_branch(branchNames{1});
            testCase.db.add_branch(branchNames{3});

            % Add some additional documents to branch_feature
            [~, ~, featureDocs] = did.test.helper.documents.make_doc_tree([2 1 2]);
            testCase.db.add_docs(featureDocs);

            % Step 3: Export per-branch JSON audit files
            jsonBranchesDir = fullfile(artifactDir, 'jsonBranches');
            mkdir(jsonBranchesDir);

            % Build metadata structure
            metadata = struct();
            metadata.branchNames = {branchNames{:}}; %#ok<CCAT>
            metadata.branchHierarchy = struct();
            metadata.branchHierarchy.branch_main = {{'branch_dev', 'branch_feature'}};
            metadata.branchHierarchy.branch_dev = {{}};
            metadata.branchHierarchy.branch_feature = {{}};
            metadata.dbFilename = testCase.dbFilename;
            branchDocCounts = struct();

            for i = 1:numel(branchNames)
                branchName = branchNames{i};
                testCase.db.set_branch(branchName);

                % Get all document IDs in this branch
                docIds = testCase.db.get_doc_ids(branchName);

                % Retrieve full documents
                branchDocsData = cell(1, numel(docIds));
                for j = 1:numel(docIds)
                    doc = testCase.db.get_docs(docIds{j});
                    branchDocsData{j} = doc.document_properties;
                end

                % Write the branch JSON file
                branchJsonStr = did.datastructures.jsonencodenan(branchDocsData);
                branchJsonFile = fullfile(jsonBranchesDir, ['branch_' branchName '.json']);
                fid = fopen(branchJsonFile, 'w');
                testCase.verifyGreaterThan(fid, 0, ...
                    ['Could not create JSON file for branch ' branchName]);
                if fid > 0
                    fprintf(fid, '%s', branchJsonStr);
                    fclose(fid);
                end

                % Track document counts for metadata
                branchDocCounts.(branchName) = numel(docIds);
            end

            % Step 4: Write metadata.json
            metadata.branchDocCounts = branchDocCounts;
            metadataJsonStr = did.datastructures.jsonencodenan(metadata);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            testCase.verifyGreaterThan(fid, 0, 'Could not create metadata.json');
            if fid > 0
                fprintf(fid, '%s', metadataJsonStr);
                fclose(fid);
            end

            % Verify artifacts were created
            testCase.verifyTrue(isfile(dbPath), 'Database file was not created.');
            testCase.verifyTrue(isfolder(jsonBranchesDir), 'jsonBranches directory was not created.');
            testCase.verifyTrue(isfile(fullfile(artifactDir, 'metadata.json')), 'metadata.json was not created.');

            for i = 1:numel(branchNames)
                branchFile = fullfile(jsonBranchesDir, ['branch_' branchNames{i} '.json']);
                testCase.verifyTrue(isfile(branchFile), ...
                    ['Branch JSON file missing for ' branchNames{i}]);
            end
        end
    end
end
