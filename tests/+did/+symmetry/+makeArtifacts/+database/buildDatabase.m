classdef buildDatabase < matlab.unittest.TestCase
    % BUILDDATABASE - Generate DID database artifacts for cross-language symmetry testing
    %
    % This test creates a small DID database with random documents (demoA, demoB, demoC)
    % across multiple branches, then uses did.util.databaseSummary to export a JSON
    % summary of each branch for comparison with other DID implementations (e.g., Python).

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

            % Create the root branch and add documents
            testCase.db.add_branch(branchNames{1});
            [~, ~, rootDocs] = did.test.helper.documents.make_doc_tree([3 3 3]);
            testCase.db.add_docs(rootDocs);

            % Create branch_dev as child of branch_main and add documents
            testCase.db.set_branch(branchNames{1});
            testCase.db.add_branch(branchNames{2});
            [~, ~, devDocs] = did.test.helper.documents.make_doc_tree([2 2 2]);
            testCase.db.add_docs(devDocs);

            % Create branch_feature as child of branch_main and add documents
            testCase.db.set_branch(branchNames{1});
            testCase.db.add_branch(branchNames{3});
            [~, ~, featureDocs] = did.test.helper.documents.make_doc_tree([2 1 2]);
            testCase.db.add_docs(featureDocs);

            % Step 3: Generate summary using did.util.databaseSummary
            summary = did.util.databaseSummary(testCase.db);
            summary.dbFilename = testCase.dbFilename;

            % Step 4: Write summary JSON (one file per branch + overall summary)
            jsonBranchesDir = fullfile(artifactDir, 'jsonBranches');
            mkdir(jsonBranchesDir);

            for i = 1:numel(branchNames)
                branchName = branchNames{i};
                safeName = matlab.lang.makeValidName(branchName);
                branchData = summary.branches.(safeName);

                branchJsonStr = did.datastructures.jsonencodenan(branchData);
                branchJsonFile = fullfile(jsonBranchesDir, ['branch_' branchName '.json']);
                fid = fopen(branchJsonFile, 'w');
                testCase.verifyGreaterThan(fid, 0, ...
                    ['Could not create JSON file for branch ' branchName]);
                if fid > 0
                    fprintf(fid, '%s', branchJsonStr);
                    fclose(fid);
                end
            end

            % Write the full summary JSON
            summaryJsonStr = did.datastructures.jsonencodenan(summary);
            fid = fopen(fullfile(artifactDir, 'summary.json'), 'w');
            testCase.verifyGreaterThan(fid, 0, 'Could not create summary.json');
            if fid > 0
                fprintf(fid, '%s', summaryJsonStr);
                fclose(fid);
            end

            % Step 5: Verify artifacts were created
            testCase.verifyTrue(isfile(dbPath), 'Database file was not created.');
            testCase.verifyTrue(isfile(fullfile(artifactDir, 'summary.json')), ...
                'summary.json was not created.');
            for i = 1:numel(branchNames)
                branchFile = fullfile(jsonBranchesDir, ['branch_' branchNames{i} '.json']);
                testCase.verifyTrue(isfile(branchFile), ...
                    ['Branch JSON file missing for ' branchNames{i}]);
            end

            % Step 6: Self-check — re-summarize and compare to verify consistency
            summaryCheck = did.util.databaseSummary(testCase.db);
            summaryCheck.dbFilename = testCase.dbFilename;
            selfReport = did.util.compareDatabaseSummary(summary, summaryCheck);
            testCase.verifyTrue(selfReport.isEqual, ...
                ['Self-check failed: ' strjoin(selfReport.messages, '; ')]);
        end
    end
end
