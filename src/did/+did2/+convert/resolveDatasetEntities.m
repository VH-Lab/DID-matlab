function [result, report] = resolveDatasetEntities(result, options)
%RESOLVEDATASETENTITIES DID-only post-pass that finalizes the dataset entity layer.
%
%   [RESULT, REPORT] = did2.convert.resolveDatasetEntities(RESULT) takes the
%   struct returned by did2.convert.v1_to_v2 (after resolveDeferredBaths) and
%   does two batch-level fixups the per-document migrators cannot. REPORT is
%   also attached as RESULT.dataset_entity_resolution, so a caller that ignores
%   the second output still carries the measurement.
%
%     1. DEDUPLICATE dataset entities. Every dataset-level source
%        (metadata_editor / dataset_remote / session_in_a_dataset /
%        dataset_session_info) mints a `dataset` entity keyed on the SAME dataset
%        id (D.id() = base.session_id), so a dataset with several such docs yields
%        several `dataset` entities with one shared base.id. This pass keeps ONE
%        per id -- the RICHEST (most populated dataset fields + global_identifiers,
%        so the metadata_editor dataset wins over a bare stub) -- and drops the
%        rest. Result: every dataset ends with exactly one canonical entity.
%
%     2. PRUNE unresolvable session-membership edges. session_in_a_dataset /
%        dataset_session_info emit `session -part_of-> dataset` best-effort; a
%        member session that is LINKED (its documents live in a separate session
%        db, not this batch) would leave the edge's child dangling. This pass drops
%        any `migrated_session_membership` relation whose child id is not present
%        in the batch -- the same honest best-effort stance as resolveDeferredBaths
%        (an unresolved membership is dropped rather than orphaning the corpus).
%        A precise, always-resolvable wiring from the live session graph is
%        UNBUILT. This sentence used to say it "is the ndi.migrate second
%        pass", present tense, which read as though production already did
%        this work better -- it did not do it at all: ndi.migrate.local never
%        called this function until 2026-08-10, and named it only in a comment
%        about where epochMint lives.
%
%   CALL SITES (all four, as of 2026-08-10): runCorpusDiscovery,
%   testCorpusPRED, testFixtureCorpus and -- newly -- ndi.migrate.local, as
%   V_eta second-pass step (4b), after strainAssembly and before epochMint.
%   The production wiring is WRITTEN BUT NOT EXECUTED (no MATLAB in the
%   container it was written in). Until it was added, the corpus gate and the
%   real migration path were different pipelines: every green run was green on
%   a dedup and a prune production skipped. See did2.unittest.testBatchPassWiring,
%   which prints the pass x call-site matrix precisely so this cannot recur.
%   AMENDED 2026-08-11: the two REPORT-WRITING call sites (runCorpusDiscovery,
%   testCorpusPRED) now route this pass through
%   did2.unittest.helpers.runBatchPass, so a throw here can no longer destroy
%   the corpus artifact -- and both sites add it to their FATAL pass list, so
%   the throw still turns the gate red. testFixtureCorpus keeps calling it
%   BARE on purpose (it writes no report, so a raw stack trace is strictly
%   better there), and ndi.migrate.local is unchanged.
%
%   Idempotent and safe on inputs with no dataset entities. Options mirror the
%   sibling passes (Validate / SchemaCache / TargetVersion) for signature
%   symmetry; this pass only removes documents, so it does not re-validate.
%
%   ---------------------------------------------------------------------
%   THE REPORT, AND WHY IT DID NOT EXIST UNTIL 2026-08-11
%   ---------------------------------------------------------------------
%   THIS PASS DELETED DOCUMENTS AND COUNTED NOTHING. Both `keep(k) = false`
%   sites above feed `result.migrated = docs(keep)`, and until this change no
%   counter, no denominator and no failure from either of them reached the
%   corpus report or the discovery log. Corpus run 31522068566 went green
%   with this pass composed at every call site; how many documents it removed
%   in that run is UNKNOWN and CANNOT BE RECOVERED from the artifacts, because
%   the only surviving number (`migrated_count`) is taken AFTER the removal.
%   (The document count for that run is not restated here -- it is not a
%   number this file measured, and the same figure is already attributed to a
%   different run id elsewhere in the tree.) That is the silentLoss defect
%   exactly -- an instrument reading nothing while its zero read as clean --
%   and Operating Rule 5 is what it violates.
%
%   THE TWO DELETION REASONS ARE DIFFERENT FACTS AND ARE NEVER SUMMED.
%   `duplicates_dropped_poorer_richness` is a dedup: the document's content
%   survives on the richer twin under the SAME base.id, so nothing is lost and
%   nothing dangles. `membership_dropped_child_absent` is a real edge
%   discarded: a `session -part_of-> dataset` statement that no longer exists
%   anywhere. A single "documents dropped" total would let the second hide
%   inside the first, so the report carries them apart and the printout prints
%   them on separate lines.
%
%   A THIRD REASON WAS HIDING INSIDE THE SECOND. The prune's condition is
%   `isempty(childId) || ~isKey(idsPresent, childId)`, which merges "this edge
%   names a member session that is not in the batch" (the linked-session case
%   the pass is FOR) with "this edge has no child edge at all" (a malformed
%   relation, which is a migrator defect and not a linked session).
%   `membership_dropped_no_child_edge` separates them. Behaviour is unchanged;
%   only the accounting is.
%
%   `documents_removed` IS AN ARITHMETIC CHECK, NOT A CATEGORY. It is read off
%   the keep mask, and `documents_removed_unattributed` is the difference
%   between it and the three named reasons. A non-zero value there means a
%   document was removed by a path that does not say why -- which is the
%   condition this report exists to make impossible to ship.
%
%   READ `documents_unreadable` BEFORE ANY ABSENCE-BASED NUMBER. The prune
%   decides on absence from `idsPresent`, and a document whose `base.id` could
%   not be read is not in that index. It is COUNTED and never dropped, but a
%   non-zero count means `membership_dropped_child_absent` is an upper bound
%   rather than a measurement, and the printout says so on its own line.
%
%   STATUS of the 2026-08-11 report edit: WRITTEN IN A CONTAINER WITH NO MATLAB
%   AND NO OCTAVE (`command -v matlab octave octave-cli` exits 1). NOTHING IN
%   IT HAS BEEN EXECUTED. test-migrators-quick.yml (which runs
%   testFixtureCorpus, a bare caller of this pass) is the first thing that will
%   have an opinion.
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveDeferredBaths,
%   did2.convert.migrators_j.metadata_editor.

% THE SUPPRESSIONS BELOW ARE NOT UNIFORM, AND THAT IS MEASURED RATHER THAN
% TIDIED. Code-scanning alerts 211/212 flagged the `%#ok<INUSA>` on the
% `SchemaCache` and `TargetVersion` lines as suppressing a message that is no
% longer generated, and left the identical directive on `Validate` alone.
% `checkcode` was run over this exact file on a CI runner (matlab-scratch.yml,
% run 31536667302, probe 10) with and without `-notok`, which reports what a
% `%#ok` is hiding:
%
%     checkcode: 2 message(s) normally, 1 with -notok
%     NORMAL  line 110  MSNU   ...once suppressed here, but no longer generated
%     NORMAL  line 111  MSNU   ...once suppressed here, but no longer generated
%     -NOTOK  line 109  INUSA  Input argument might be unused after the
%                             function arguments block(s)
%
% So the alerts were RIGHT and the third directive is LOAD-BEARING: only
% `Validate` raises INUSA at all. The two dead ones are removed; the live one
% stays and says so. Deleting all three to make the block look consistent would
% have traded two cosmetic alerts for a real analyzer warning on every run --
% which is what nearly happened to two `%#ok<AGROW>` directives on the same day.
arguments
    result (1,1) struct
    options.Validate (1,1) logical = true %#ok<INUSA>
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% DENOMINATOR FIRST, and unconditionally. Every field is defined before a
% single document is read, so "did not run" and "ran and removed nothing" are
% different readings of the same struct rather than the same reading.
% Operating Rule 5; every corpus run this pass deleted documents in without
% reporting a single one is what happens without it.
report = struct( ...
    'documents_inspected',                0, ...
    'documents_unreadable',               0, ...
    'dataset_entities_seen',              0, ...
    'distinct_dataset_ids',               0, ...
    'duplicates_dropped_poorer_richness', 0, ...
    'duplicate_ties_incumbent_kept',      0, ...
    'membership_relations_seen',          0, ...
    'membership_kept_child_present',      0, ...
    'membership_dropped_child_absent',    0, ...
    'membership_dropped_no_child_edge',   0, ...
    'documents_removed',                  0, ...
    'documents_removed_unattributed',     0, ...
    'migrated_before',                    0, ...
    'migrated_after',                     0, ...
    'ran',                                false);
result.dataset_entity_resolution = report;

if ~isfield(result, 'migrated') || isempty(result.migrated)
    % RAN, over nothing. `0 of 0 inspected` and `0 removed of a full corpus`
    % must never print the same, so `ran` is set on this path too.
    report.ran = true;
    result.dataset_entity_resolution = report;
    return;
end
report.ran = true;
docs = result.migrated;
n = numel(docs);
keep = true(1, n);
report.documents_inspected = n;
report.migrated_before = n;

% --- pass 1: index doc ids present + pick the richest dataset per id ----------
idsPresent = containers.Map('KeyType', 'char', 'ValueType', 'logical');
bestDatasetIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
bestDatasetRichness = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    % A document this cannot read is COUNTED, never dropped -- the same stance
    % epochMint and resolveValidIntervals take. Before this guard existed an
    % unreadable id threw, and the throw landed between the post-passes and
    % writeCorpusReport, which costs the corpus its entire census.
    try
        id = char(docs{k}.get('base.id'));
        className = docs{k}.className();
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    idsPresent(id) = true;
    if ~strcmp(className, 'dataset'); continue; end
    report.dataset_entities_seen = report.dataset_entities_seen + 1;
    r = datasetRichness(docs{k});
    if isKey(bestDatasetIdx, id)
        report.duplicates_dropped_poorer_richness = ...
            report.duplicates_dropped_poorer_richness + 1;
        if r > bestDatasetRichness(id)
            keep(bestDatasetIdx(id)) = false;   % a poorer duplicate loses
            bestDatasetIdx(id) = k; bestDatasetRichness(id) = r;
        else
            keep(k) = false;
            % A TIE IS NOT A RANKING. Equal richness keeps the incumbent purely
            % because it was seen first, so which of the two survives is a
            % function of corpus file order. Counted separately because that is
            % a property of the input, not a decision this pass made.
            if r == bestDatasetRichness(id)
                report.duplicate_ties_incumbent_kept = ...
                    report.duplicate_ties_incumbent_kept + 1;
            end
        end
    else
        bestDatasetIdx(id) = k; bestDatasetRichness(id) = r;
    end
end
report.distinct_dataset_ids = double(bestDatasetIdx.Count);

% --- pass 2: drop best-effort membership edges whose member session is absent -
for k = 1:n
    if ~keep(k); continue; end
    doc = docs{k};
    try
        className = doc.className();
    catch
        continue;   % already counted in `documents_unreadable` above
    end
    if ~strcmp(className, 'directed_relation'); continue; end
    if ~strcmp(char(getBaseName(doc)), 'migrated_session_membership'); continue; end
    report.membership_relations_seen = report.membership_relations_seen + 1;
    childId = depValueOf(doc, 'child');
    if isempty(childId)
        % NOT the linked-session case. An edge with no child names nothing at
        % all, which is a defect in whatever emitted it.
        keep(k) = false;
        report.membership_dropped_no_child_edge = ...
            report.membership_dropped_no_child_edge + 1;
    elseif ~isKey(idsPresent, childId)
        keep(k) = false;   % linked session not in this batch -> drop the edge
        report.membership_dropped_child_absent = ...
            report.membership_dropped_child_absent + 1;
    else
        report.membership_kept_child_present = ...
            report.membership_kept_child_present + 1;
    end
end

result.migrated = docs(keep);
report.migrated_after = numel(result.migrated);
% THE ARITHMETIC CHECK. `documents_removed` comes off the mask, not off the
% reasons, so the two derivations can disagree -- and if they do, the
% difference is printed rather than reconciled away.
report.documents_removed = n - sum(keep);
report.documents_removed_unattributed = report.documents_removed ...
    - report.duplicates_dropped_poorer_richness ...
    - report.membership_dropped_child_absent ...
    - report.membership_dropped_no_child_edge;
result.summary = recountSummary(result);
result.dataset_entity_resolution = report;
end

% ===================== helpers =========================================

function r = datasetRichness(doc)
%DATASETRICHNESS Non-empty dataset fields + global_identifier entries.
r = 0;
try
    ds = doc.get('dataset');
    if isstruct(ds)
        fn = fieldnames(ds);
        for i = 1:numel(fn)
            v = ds.(fn{i});
            if (ischar(v) || isstring(v)) && ~isempty(char(v)); r = r + 1; end
        end
    end
catch
end
try
    g = doc.get('entity.global_identifier');
    r = r + numel(g);
catch
end
end

function name = getBaseName(doc)
name = '';
try
    name = doc.get('base.name');
catch
end
end

function v = depValueOf(doc, name)
v = '';
try
    deps = doc.get('depends_on');
catch
    return;
end
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(deps(k).name, name)
        if isfield(deps(k), 'value') && ~isempty(deps(k).value)
            v = char(deps(k).value);
        elseif isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
            v = char(deps(k).document_id);
        end
        return;
    end
end
end

function summary = recountSummary(result)
summary = struct();
if isfield(result, 'summary') && isstruct(result.summary); summary = result.summary; end
summary.migrated_count = numel(result.migrated);
if isfield(result, 'quarantine'); summary.quarantine_count = numel(result.quarantine); end
byClass = struct();
for k = 1:numel(result.migrated)
    fieldName = matlab.lang.makeValidName(result.migrated{k}.className());
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end
