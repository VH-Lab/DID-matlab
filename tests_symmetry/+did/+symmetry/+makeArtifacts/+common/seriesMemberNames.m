classdef seriesMemberNames < matlab.unittest.TestCase
    % SERIESMEMBERNAMES - Conformance vectors for the NAME_<i> parse rule
    %
    % Not a file format: a RULE, which is why it sits beside pathAgreement
    % rather than in +file. did.document/seriesMemberOf decides whether a
    % filename names a series member, and every other resolution rests on it
    % -- is_in_file_list accepts the name because of it, and a database
    % implementation looks for bytes because of it. The rule is implemented
    % once per language, from prose, with nothing shared to check against.
    %
    % Getting it wrong is not a crash. A rule that is too permissive turns
    % every NAME_<n> in a document into a member of some series and sends
    % resolution after files that do not exist; one that is too strict makes
    % real members unreachable. Both are quiet.
    %
    % The vectors are asserted against the live implementation below before
    % being written out, so this file cannot claim something MATLAB does not
    % do.
    %
    % THE PART A PORT SHOULD NOT COPY. MATLAB parses the index with str2num,
    % which EVALUATES its argument: 'chunkdata.bin_1+1' would parse as member
    % 2, and a name ending in something like 'pi' can parse as a number. That
    % is an artifact of the implementation, not a decision, so those inputs
    % are deliberately absent from the vectors -- pinning them would oblige
    % DID-python to reproduce an eval it should not want. A port should use a
    % strict integer parse; the vectors here are all inputs where a strict
    % parse and str2num agree.
    %
    % WHERE VALIDATION LIVES. seriesMemberOf PARSES; it does not validate.
    % 'chunkdata.bin_0' and 'chunkdata.bin_-1' both parse, and it is
    % sqlitedb/seriesMemberPath that rejects an index below 1 or non-integer.
    % The split matters: a port that rejects them in the parser answers the
    % same in the end but disagrees here, and this table says which side the
    % line falls on.

    properties (Constant)
        documentClass = 'demoSeries'
        % demoSeries declares chunkdata.bin as a file SERIES and
        % plainfile.ext as an ordinary file. Both are in the file list; only
        % one is a series, which is the distinction the rule turns on.
        seriesName = 'chunkdata.bin'
        ordinaryFileName = 'plainfile.ext'
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
        function testSeriesMemberNamesArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', ...
                'matlabArtifacts', 'common', 'seriesMemberNames', ...
                'testSeriesMemberNamesArtifacts');
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            doc = did.document(testCase.documentClass, 'demoSeries.value', 1);

            % {name, expected stem ('' for a miss), expected index ([] for a
            % miss), why this case is here}
            v = {
                'chunkdata.bin_1',    'chunkdata.bin',  1, ...
                    'the ordinary case'
                'chunkdata.bin_12',   'chunkdata.bin', 12, ...
                    'multi-digit, so a single-character parse fails here'
                'chunkdata.bin_007',  'chunkdata.bin',  7, ...
                    'leading zeros are not significant'
                'CHUNKDATA.BIN_3',    'chunkdata.bin',  3, ...
                    ['matching is case-insensitive AND the DECLARED spelling ' ...
                     'comes back, not the caller''s: everything downstream ' ...
                     'looks the stem up again where the declared spelling is ' ...
                     'what is stored']
                'chunkdata.bin_0',    'chunkdata.bin',  0, ...
                    'parses; seriesMemberPath is what rejects an index below 1'
                'chunkdata.bin_-1',   'chunkdata.bin', -1, ...
                    'likewise parses, and is likewise rejected downstream'
                'chunkdata.bin_1_2',  '',              [], ...
                    ['the LAST underscore splits, so the candidate stem is ' ...
                     '"chunkdata.bin_1", which is not declared. A first-' ...
                     'underscore or greedy match would wrongly resolve this']
                'plainfile.ext_1',    '',              [], ...
                    ['declared as an ordinary FILE, not a series. Without ' ...
                     'this check every numbered filename becomes a member']
                'chunkdata.bin',      '',              [], ...
                    'the series name is the manifest, never a member'
                'chunkdata.bin_',     '',              [], ...
                    'nothing after the underscore is not an index'
                'nosuchseries_1',     '',              [], ...
                    'an undeclared stem'
                '_1',                 '',              [], ...
                    'an empty candidate stem'
                '',                   '',              [], ...
                    'the empty name is a miss, not an error'
                };

            cases = struct('name', {}, 'isMember', {}, 'stem', {}, ...
                'index', {}, 'why', {});

            for i = 1:size(v, 1)
                thisName     = v{i, 1};
                expectedStem = v{i, 2};
                expectedIdx  = v{i, 3};

                [stem, index] = doc.seriesMemberOf(thisName);

                % Assert against the live rule BEFORE recording it.
                testCase.verifyEqual(stem, expectedStem, ...
                    sprintf('stem for "%s"', thisName));
                testCase.verifyEqual(index, expectedIdx, ...
                    sprintf('index for "%s"', thisName));

                cases(i).name     = thisName;
                cases(i).isMember = ~isempty(stem);
                cases(i).stem     = stem;
                if isempty(expectedIdx)
                    % An empty array, not 0: a miss has no index, and 0 is
                    % itself a legitimate parsed value in this table.
                    cases(i).index = [];
                else
                    cases(i).index = expectedIdx;
                end
                cases(i).why      = v{i, 4};
            end

            manifest = struct( ...
                'documentClass', testCase.documentClass, ...
                'declaredSeries', {{testCase.seriesName}}, ...
                'declaredOrdinaryFiles', {{testCase.ordinaryFileName}}, ...
                'rule', ['split on the LAST underscore; the tail must parse ' ...
                         'as a number; the head must be a DECLARED series ' ...
                         'name, matched case-insensitively; the declared ' ...
                         'spelling is what comes back'], ...
                'validationLivesInTheCaller', ['seriesMemberOf parses only. ' ...
                         'An index below 1, or a non-integer, is rejected by ' ...
                         'did.implementations.sqlitedb/seriesMemberPath.'], ...
                'cases', cases);
            fid = fopen(fullfile(artifactDir, 'manifest.json'), 'w');
            testCase.assertNotEqual(fid, -1, 'Could not write manifest.json');
            fprintf(fid, '%s', jsonencode(manifest, 'PrettyPrint', true));
            fclose(fid);

            % The declarations the vectors rest on, asserted rather than
            % assumed: if demoSeries ever stopped declaring these, every miss
            % above would still "pass" for the wrong reason.
            testCase.verifyTrue(doc.isFileSeries(testCase.seriesName), ...
                'precondition: chunkdata.bin must be a declared series');
            testCase.verifyFalse(doc.isFileSeries(testCase.ordinaryFileName), ...
                'precondition: plainfile.ext must NOT be a declared series');
        end
    end
end
