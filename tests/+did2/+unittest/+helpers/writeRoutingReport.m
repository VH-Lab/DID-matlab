function reportPath = writeRoutingReport(corpusName, migrated)
%WRITEROUTINGREPORT Per-term -> routed-class inventory for routing curation.
%
%   REPORTPATH = did2.unittest.helpers.writeRoutingReport(NAME, MIGRATED)
%   walks the migrated observation/manipulation documents, extracts each
%   one's identity term (the property the row is ABOUT -- measured_property
%   / applied_property / procedure / factor / entity / first mixture
%   chemical), and aggregates (term_node, term_name, class_name) with
%   counts into <pwd>/corpus-reports/<NAME>-routing.json (picked up by the
%   upload-artifact step alongside the discovery summary).
%
%   Purpose: the treatment / ontology_table_row migrators route by
%   keyword/CURIE HEURISTICS, so everything migrates "green" but a term can
%   land in the wrong class with no error. This report makes routing
%   AUDITABLE against real corpus terms:
%     - rows whose class_name is generic_scalar_observation /
%       generic_categorical_observation are UNMATCHED terms (need a minted
%       class or a routing rule), and
%     - a term that appears under a surprising class is a mis-route to fix.
%   It is the data source for building the authoritative per-term routing
%   tables (discovery mode, the conversion docs' "Open questions").
%
%   Best-effort and side-effect-only: any failure is swallowed by the
%   caller so it never breaks the discovery run (the summary is primary).

reportDir = fullfile(pwd, 'corpus-reports');
if ~exist(reportDir, 'dir')
    mkdir(reportDir);
end
reportPath = fullfile(reportDir, [corpusName '-routing.json']);

keys = {};
nodes = {};
names = {};
classes = {};
counts = [];
for k = 1:numel(migrated)
    doc = migrated{k};
    cls = doc.className();
    [node, name] = identityTerm(doc);
    if isempty(node) && isempty(name)
        continue;   % not a property-bearing observation/manipulation
    end
    key = [node '|' name '|' cls];
    idx = find(strcmp(keys, key), 1);
    if isempty(idx)
        keys{end+1}    = key;   %#ok<AGROW>
        nodes{end+1}   = node;  %#ok<AGROW>
        names{end+1}   = name;  %#ok<AGROW>
        classes{end+1} = cls;   %#ok<AGROW>
        counts(end+1)  = 1;     %#ok<AGROW>
    else
        counts(idx) = counts(idx) + 1;
    end
end

if isempty(counts)
    entries = struct('term_node', {}, 'term_name', {}, ...
        'class_name', {}, 'count', {});
else
    [~, order] = sort(counts, 'descend');
    entries = struct('term_node', nodes(order), 'term_name', names(order), ...
        'class_name', classes(order), 'count', num2cell(counts(order)));
end

report = struct( ...
    'corpus',        corpusName, ...
    'generated_at',  char(datetime('now', 'TimeZone', 'UTC', ...
                        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
    'distinct_terms', numel(entries), ...
    'routes',        entries);

fid = fopen(reportPath, 'w');
if fid < 0
    error('did2:test:reportWriteFailed', ...
        'Could not open %s for writing.', reportPath);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(report, 'PrettyPrint', true));

% Echo the actionable breakdown to stdout so the CI log carries it (the
% JSON also ships as an artifact). The terms routed to the generic_*
% escape hatches are the UNMATCHED ones -- they need a minted class or a
% routing rule -- so list those in full, then the top routes overall.
fprintf('\n--- routing inventory (%s): %d distinct term->class routes ---\n', ...
    corpusName, numel(entries));
nUnmatched = 0;
for i = 1:numel(entries)
    if startsWith(entries(i).class_name, 'generic_')
        nUnmatched = nUnmatched + 1;
        fprintf('  UNMATCHED %6d  %-28s [%s] -> %s\n', entries(i).count, ...
            entries(i).term_node, entries(i).term_name, entries(i).class_name);
    end
end
fprintf('  (%d unmatched term routes to generic_*)\n', nUnmatched);
fprintf('  top routes:\n');
for i = 1:min(numel(entries), 30)
    fprintf('  %6d  %-28s [%s] -> %s\n', entries(i).count, ...
        entries(i).term_node, entries(i).term_name, entries(i).class_name);
end
end

% ===================== helpers ============================================

function [node, name] = identityTerm(doc)
%IDENTITYTERM The ontology term a migrated observation/manipulation is about.
node = '';
name = '';
% Single-term identity fields, in priority order across the tiers.
paths = { ...
    'observation.measured_property', ...        % observations
    'scalar_manipulation.applied_property', ...  % temperature_manipulation, ...
    'procedural_manipulation.procedure', ...     % procedural_manipulation, biological_transfer
    'environmental_manipulation.factor', ...     % environmental_manipulation
    'biological_transfer.entity'};               % biological_transfer (more specific)
for p = 1:numel(paths)
    t = tryGet(doc, paths{p});
    [node, name] = termOf(t);
    if ~isempty(node) || ~isempty(name)
        return;
    end
end
% Pharmacological tiers (injection/bath) carry the agent in mixture[1].chemical.
m = tryGet(doc, 'pharmacological_manipulation.mixture');
if ~isempty(m) && isstruct(m)
    [node, name] = termOf(m(1).chemical);
end
end

function [node, name] = termOf(t)
node = '';
name = '';
if isstruct(t) && isscalar(t)
    if isfield(t, 'node') && ischar(t.node); node = t.node; end
    if isfield(t, 'name') && ischar(t.name); name = t.name; end
end
end

function v = tryGet(doc, path)
v = [];
try
    v = doc.get(path);
catch
    v = [];
end
end
