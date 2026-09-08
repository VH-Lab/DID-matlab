classdef seriesMemberNames < matlab.unittest.TestCase
    % SERIESMEMBERNAMES - Check the NAME_<i> parse rule against the other
    % language's conformance vectors
    %
    % Mirrors DID-python's
    % tests/symmetry/read_artifacts/common/test_series_member_names.py.
    %
    % The rule seriesMemberOf implements is written once per language, from
    % prose, with no shared code to check against -- so a table of inputs and
    % answers passed between them is the only thing that can catch a drift.
    % Too permissive turns every NAME_<n> in a document into a member and
    % sends resolution after files that do not exist; too strict makes real
    % members unreachable. Both are quiet, and neither shows up in a test
    % that only round-trips its own language.
    %
    % The makeArtifacts half has written these vectors since #173 and nothing
    % read them. The symmetry job's gates could not see that: they fail on a
    % SKIP, or on an artifact missing for a test that EXISTS. A reader nobody
    % wrote is neither.
    %
    % KNOWN DEVIATIONS are named in the table below rather than skipped
    % silently. A listed vector is still CHECKED -- against what THIS language
    % does, with the difference asserted to be the one that was agreed -- so
    % if either side moves again this fails rather than quietly widening the
    % allowance.
    %
    % Assumes rather than fails when the artifact is absent, so this can land
    % in either repository first without blocking the other.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Static)
        function d = deviations()
            % {name, this language's stem, this language's index, why}
            %
            % Empty as of DID-matlab#199 / DID-python#69: MATLAB's parse was
            % tightened from str2num (which EVALUATES) to a strict
            % all-digits check, matching DID-python's isdigit-based parse.
            % The '_-1' vector that used to be a MATLAB-only member is now
            % refused at the parse in both languages.
            d = cell(0, 4);
        end
    end

    methods (Test)
        function testSeriesMemberNamesArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'DID', 'symmetryTest', SourceType, ...
                'common', 'seriesMemberNames', 'testSeriesMemberNamesArtifacts');

            testCase.assumeTrue(isfolder(artifactDir), ...
                ['Artifact directory from ' SourceType ' does not exist.']);
            manifestFile = fullfile(artifactDir, 'manifest.json');
            testCase.assumeTrue(isfile(manifestFile), ...
                ['manifest.json not found in ' SourceType ' artifact directory.']);

            fid = fopen(manifestFile, 'r');
            rawJson = fread(fid, inf, '*char')';
            fclose(fid);
            manifest = jsondecode(rawJson);

            doc = did.document(manifest.documentClass, 'demoSeries.value', 1);

            % The declarations the vectors rest on. Without this every "miss"
            % below would pass for the wrong reason if demoSeries stopped
            % declaring the series at all.
            declaredSeries = manifest.declaredSeries;
            if ~iscell(declaredSeries), declaredSeries = {declaredSeries}; end
            for i = 1:numel(declaredSeries)
                testCase.assertTrue(doc.isFileSeries(declaredSeries{i}), ...
                    ['"' declaredSeries{i} '" must be a declared series in ' ...
                     manifest.documentClass]);
            end
            if isfield(manifest, 'declaredOrdinaryFiles')
                ordinary = manifest.declaredOrdinaryFiles;
                if ~iscell(ordinary), ordinary = {ordinary}; end
                for i = 1:numel(ordinary)
                    testCase.assertFalse(doc.isFileSeries(ordinary{i}), ...
                        ['"' ordinary{i} '" must NOT be a declared series']);
                end
            end

            % jsondecode gives a struct array for a homogeneous list and a
            % cell array otherwise; this list is heterogeneous, since index is
            % a number for some cases and null/[] for others.
            cases = manifest.cases;
            if ~iscell(cases)
                cases = num2cell(cases);
            end
            testCase.assertNotEmpty(cases, ...
                [SourceType ' recorded no vectors, so this compared nothing']);

            dev = did.symmetry.readArtifacts.common.seriesMemberNames.deviations();
            devNames = dev(:, 1);
            checked = 0;
            seenDeviations = false(1, size(dev, 1));

            for i = 1:numel(cases)
                c = cases{i};
                thisName = c.name;
                if isnumeric(thisName) && isempty(thisName)
                    thisName = '';   % jsondecode gives [] for ""
                end

                [stem, index] = doc.seriesMemberOf(thisName);

                k = find(strcmp(thisName, devNames), 1);
                if ~isempty(k)
                    seenDeviations(k) = true;
                    testCase.verifyEqual(stem, dev{k, 2}, ...
                        sprintf(['"%s" is a KNOWN deviation whose MATLAB stem ' ...
                                 'is pinned as "%s" (%s). Either the rule ' ...
                                 'changed or the deviation was resolved -- ' ...
                                 'update the table, do not widen it.'], ...
                                thisName, dev{k, 2}, dev{k, 4}));
                    testCase.verifyEqual(index, dev{k, 3}, ...
                        sprintf('"%s": deviation index', thisName));
                    continue
                end

                recordedStem = c.stem;
                if isnumeric(recordedStem) && isempty(recordedStem)
                    recordedStem = '';
                end
                recordedIndex = [];
                if isfield(c, 'index') && ~isempty(c.index)
                    recordedIndex = double(c.index);
                end

                why = '';
                if isfield(c, 'why'), why = c.why; end

                testCase.verifyTrue(strcmp(stem, recordedStem), ...
                    sprintf('stem for "%s": %s recorded "%s", this language answers "%s". %s', ...
                        thisName, SourceType, recordedStem, stem, why));
                if isempty(recordedIndex)
                    testCase.verifyEmpty(index, ...
                        sprintf('index for "%s": %s recorded a miss, this language answers one. %s', ...
                            thisName, SourceType, why));
                else
                    testCase.verifyEqual(double(index), recordedIndex, ...
                        sprintf('index for "%s": %s recorded %g. %s', ...
                            thisName, SourceType, recordedIndex, why));
                end

                % isMember must agree with the stem it was derived from, or
                % the artifact is internally inconsistent whatever the rule
                % says.
                testCase.verifyEqual(logical(c.isMember), ~isempty(recordedStem), ...
                    sprintf('"%s": isMember disagrees with stem in the artifact', ...
                        thisName));
                checked = checked + 1;
            end

            testCase.verifyGreaterThan(checked, 0, ...
                [SourceType ' contributed no non-deviation vectors, so this ' ...
                 'compared nothing across languages']);

            % A deviation the other language no longer records must not go
            % unnoticed: it either got fixed (good -- remove it here) or the
            % vector was dropped (and the allowance is now stale).
            if strcmp(SourceType, 'pythonArtifacts')
                testCase.verifyTrue(all(seenDeviations), ...
                    ['the deviation table names a vector ' SourceType ' no ' ...
                     'longer records. Re-check whether the difference still ' ...
                     'exists and remove the entry if it does not.']);
            end
        end
    end
end
