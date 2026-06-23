function corpusDir = runCorpusDiscovery(testCase, corpusName, corpusURL, innerDir, options)
%RUNCORPUSDISCOVERY Shared driver for v1 corpus discovery-mode tests.
%
%   CORPUSDIR = did2.unittest.helpers.runCorpusDiscovery(TESTCASE, CORPUSNAME,
%       CORPUSURL, INNERDIR) is the body of each per-corpus discovery
%   test. It handles the schema-path probe + override, downloads and
%   caches the corpus zip, runs every contained v1 document through
%   did2.convert.v1_to_v2 with Validate=true, writes the per-run
%   summary JSON under corpus-reports/<CORPUSNAME>-summary.json, and
%   prints a stdout summary that the CI log captures.
%
%   The test that calls this function is responsible for any
%   pre-call gating (e.g., env-var guards), and for the schema-path
%   teardown via did2.unittest.helpers.restoreSchemaPath.
%
%   Returns the corpus directory it walked, so callers can layer
%   extra assertions on top if they want.
%
%   This is **discovery mode**: nothing is asserted about the
%   migrated_count / quarantine_count split; the report is the
%   deliverable.

arguments
    testCase
    corpusName (1,:) char
    corpusURL  (1,:) char
    innerDir   (1,:) char
    options.TargetVersion (1,:) char = 'V_epsilon'
end

did2.unittest.helpers.installSchemaPath(testCase, sprintf('skipping %s corpus test', corpusName));

cacheName = ['did2-corpus-' innerDir];
corpusDir = did2.unittest.helpers.ensureCorpus(corpusURL, cacheName, innerDir);

files = dir(fullfile(corpusDir, '*.json'));
files = files(~startsWith({files.name}, '._'));
verifyGreaterThan(testCase, numel(files), 0, ...
    sprintf('No JSON files found under %s', corpusDir));

bodies = cell(numel(files), 1);
for k = 1:numel(files)
    bodies{k} = fileread(fullfile(files(k).folder, files(k).name));
end

result = did2.convert.v1_to_v2(bodies, 'Validate', true, ...
    'TargetVersion', options.TargetVersion);

reasons = did2.unittest.helpers.topQuarantineReasons(result.quarantine);
reportPath = did2.unittest.helpers.writeCorpusReport(corpusName, result, reasons);

% Per-term routing inventory (best-effort): makes the heuristic
% treatment / ontology_table_row routing auditable against real corpus
% terms so the authoritative per-term tables can be curated. Never let it
% break the discovery run -- the summary is the primary deliverable.
try
    did2.unittest.helpers.writeRoutingReport(corpusName, result.migrated);
catch routingErr
    fprintf('routing report skipped: %s\n', routingErr.message);
end

% Reference-integrity sweep (best-effort): after the 1->N splits and class
% folds, confirm every depends_on edge in the migrated batch resolves to a
% document in that batch. Orphans = dangling references the migration would
% introduce (e.g. a split that didn't preserve a referenced id, or a ref to
% a deferred/quarantined doc). Reported, not fatal -- discovery mode.
try
    refRep = did2.validate.references(result.migrated);
    fprintf('\n--- reference integrity (%s): %d orphan(s) of %d edges ---\n', ...
        corpusName, refRep.orphan_count, refRep.edges_examined);
    [orphNames, orphCounts] = aggregateOrphans(refRep.orphans);
    for i = 1:numel(orphNames)
        fprintf('  %6d  %s\n', orphCounts(i), orphNames{i});
    end
catch refErr
    fprintf('reference report skipped: %s\n', refErr.message);
end

fprintf('\n=== Corpus %s discovery summary (target %s) ===\n', ...
    corpusName, options.TargetVersion);
fprintf('total:            %d\n', result.summary.total);
fprintf('migrated_count:   %d\n', result.summary.migrated_count);
fprintf('quarantine_count: %d\n', result.summary.quarantine_count);
fprintf('report:           %s\n', reportPath);
fprintf('top quarantine reasons:\n');
for k = 1:min(numel(reasons), 15)
    fprintf('  %5d  [%s] %s\n', reasons(k).count, ...
        reasons(k).class_name, reasons(k).reason);
end
end

function [names, counts] = aggregateOrphans(orphans)
%AGGREGATEORPHANS Count dangling edges by "doc_class.edge_name", desc.
names = {};
counts = [];
for k = 1:numel(orphans)
    key = sprintf('%s.%s', orphans(k).doc_class, orphans(k).edge_name);
    idx = find(strcmp(names, key), 1);
    if isempty(idx)
        names{end+1} = key;  %#ok<AGROW>
        counts(end+1) = 1;   %#ok<AGROW>
    else
        counts(idx) = counts(idx) + 1;
    end
end
if ~isempty(counts)
    [counts, order] = sort(counts, 'descend');
    names = names(order);
end
end
