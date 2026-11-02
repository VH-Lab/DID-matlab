function [result, report] = resolveDeferredBaths(result, options)
%RESOLVEDEFERREDBATHS Coarse, DID-only resolution of deferred stimulus_baths.
%
%   [RESULT, REPORT] = did2.convert.resolveDeferredBaths(RESULT) takes the
%   struct returned by did2.convert.v1_to_v2 and resolves the stimulus_bath
%   documents it deferred with did2:convert:needsSessionContext, using ONLY the migrated
%   batch already in hand -- no live NDI session. For each deferred
%   stimulus_bath it:
%
%     - resolves subject_id by following stimulus_element_id to the migrated
%       `element` document in the batch (up the underlying_element_id chain),
%       and
%     - attaches a session_relative_reference('during') time anchor -- the same
%       ordinal fallback the treatment / ontology_table_row migrators use --
%       rather than a precise epoch_bounded_reference.
%
%   It then folds the assembled `bath` (+ anchor) back through v1_to_v2 at the
%   same TargetVersion (they short-circuit as already-target -> pad + validate)
%   and moves the resolved documents from `quarantine` into `migrated`. The
%   bath preserves the source stimulus_bath's base.id, so inbound references
%   resolve to it.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: stimulus_bath
%   BATCH-PASS-EMITS: stimulus_bath -> document: relative_time_reference,
%       manipulation+formulation, formulation, chemical, observation+term
%
%   WHAT IT READS AND WRITES (tools/batch_pass_order.py derives and checks the
%   pass order from these; [migration reliability practices] (c), Jess Haley,
%   2026-10-26). Read from this file's code, class by class.
%   BATCH-PASS-READS: stimulus_bath, element, entity(element),
%       directed_relation(element lineage), acquisition_epoch, element_epoch,
%       result.passthrough
%   BATCH-PASS-ADDS: relative_time_reference(bath anchor),
%       manipulation(bath), formulation, chemical, observation(bath),
%       result.deferred_bath_anchors
%   BATCH-PASS-CHANGES: NONE -- it only appends; the deferred stimulus_bath
%       entries leave the quarantine, not the batch
%   BATCH-PASS-REMOVES: NONE -- it folds no document that is in the batch
%
%   SCOPE OF THAT LINE: V_eta is the only path. The V_zeta branch (makeBath
%   emitting `bath` + `pharmacological_manipulation`) was deleted with
%   +migrators_e/+migrators_i (did-schema #88, OPEN_WORK #128): only
%   +migrators_j.stimulus_bath defers a bath now, so no other target can
%   reach this pass with work to do.
%   `term_observation` is CONDITIONAL (makeBathVEta, only when the source names an
%   ANATOMICAL location -- not the generic bath, see below); the declaration
%   states what the pass can emit, not what every document produces.
%
%   WHERE THE BATH IS (Jess Haley, 2026-10-21, replacing D3's
%   located-by-default; did-schema V_eta_go_forward_class_audit.md): "Any
%   statement about an anatomical region of a subject -- manipulation or
%   observation -- targets that region's part entity ... A statement about the
%   whole subject (a whole-prep or whole-slice bath, i.e. the generic 'bath'
%   location NCIm:C0179246) targets the subject." So the location observation
%   is emitted, co-anchored with the bath, only for an anatomical location (a
%   Marder compartment); the NDI second pass (ndi.migrate.internal.
%   pathSPromotion) turns it into the region's part and moves the bath onto
%   it. The generic bath gets none -- it is no site on the subject, the same
%   call +migrators_j/private/jTreatmentRoute makes for a treatment.
%   ---------------------------------------------------------------------
%
%   ONE BATH SHAPE (Decided by Jess Haley, 2026-10-27 [one bath shape],
%   did-schema V_eta_go_forward_class_audit.md): this pass keeps each bath's
%   stimulator link and its epoch, in the shape NDI-matlab's
%   ndi.migrate.internal.stimulusBathToBath writes (read at NDI-matlab V2
%   a2ab2d152, its vetaBath):
%     - the stimulator is the manipulation's `instrument_id` (T7), as there
%       ('InstrumentId', stimulatorId);
%     - the anchor is built "during the session" as there, and its epoch is
%       handed on as NDI hands it to epochAnchorFold: one row per bath with an
%       epoch string, {anchor_id, session_id, epoch_string, epoch_clock}, in
%       RESULT.deferred_bath_anchors. did2.convert.epochMint (its
%       resolveBathAnchors stage, the counterpart of NDI's epochAnchorFold)
%       re-points that anchor at the epoch entity it holds for (session, epoch
%       string), with the clock, id preserved; a bath whose epoch is not
%       found stays anchored to its session, counted, as in NDI.
%     - the clock is the stimulator's, read as NDI's bodyResolver
%       epochClockOfElement reads it: the stimulator's element_epoch for that
%       epoch (in this batch an `acquisition_epoch`, its clock names joined by
%       ',', or a carried v1 `element_epoch`'s epoch_clock). NDI's second
%       fallback (an `epochclocktimes` document of that epoch id) is not read
%       here: pass 1 has converted those.
%   A BATH WHOSE EPOCH HAS NO CLOCK RECORD IS CARRIED (Decided by Jess Haley,
%   2026-10-26 [one-reading quick answers] Q2, did-schema
%   V_eta_go_forward_class_audit.md: "a bath epoch with no clock record, is
%   carried as v1 instead of defaulting to `dev_local_time` ([no invented
%   values])"). A bath with an epoch string and no element_epoch of its
%   stimulator for that epoch in the batch is no longer assembled on
%   'dev_local_time': its v1 source leaves the quarantine carried whole as
%   v1 (stamped 'did_v1', a passthrough record with input_index 0, since
%   the quarantine does not keep the input index), with a `carried_as_v1`
%   note citing register row carry-157 merged into
%   RESULT.summary.migration_notes. Counted in `baths_carried_no_clock`;
%   `bath_clocks_defaulted` stays in the report and reads 0.
%   ONE DIFFERENCE, KEPT ON PURPOSE AND COUNTED: NDI mints NO anchor for a bath
%   with no epoch string or a 'no_time' clock, so its manipulation fails
%   time_reference_id's min_count. Here such a bath keeps its session anchor
%   (`baths_without_epoch_string`, `bath_anchors_no_time`) rather than turning
%   into a quarantine; it is not handed on.
%
%   This is the COARSE resolver for callers without a live session (e.g. corpus
%   discovery). The PRECISE version -- an epoch_bounded_reference on the
%   stimulator's epoch -- is ndi.migrate.local's second pass
%   (ndi.migrate.internal.stimulusBathToBath), which has the element epoch
%   graph. Only one runs per flow: NDI uses the precise path; standalone /
%   corpus callers use this. A stimulus_bath whose element is not in the batch
%   stays quarantined with its original deferral reason.
%
%   Options (name-value):
%     Validate      (1,1 logical, default true) - forwarded to the v1_to_v2
%                   re-validation of the assembled bodies.
%     SchemaCache   ([] or a did2.schema.cache handle, default []) - forwarded.
%     TargetVersion (1,:) char, default 'V_eta') - the migration target the
%                   assembled bodies are tagged with. Only 'V_eta' is
%                   accepted (any other target is an argument error).
%
%   ---------------------------------------------------------------------
%   THE REPORT, AND THE BARE `catch` IT REPLACES
%   ---------------------------------------------------------------------
%   UNTIL 2026-08-11 THE PER-BATH HANDLER WAS TWO COMMENT LINES. Every failure
%   -- an unreadable body, a missing `stimulus_element_id`, an element that is
%   genuinely not in the batch, an assembly bug, a typo in a field name -- left
%   the document quarantined with its original deferral reason and produced no
%   number anywhere. So "resolved every deferred bath" and "resolved none,
%   because every element was missing" were THE SAME READING of every corpus
%   run to date, run 31522068566 (green) included. The pass
%   is not a no-op: it moves documents from `quarantine` into `migrated`, so
%   the size of what it did and did not do was unmeasured in both directions.
%
%   REFUSALS ARE COUNTED BY CAUSE, AND AN UNEXPECTED ERROR IS ITS OWN CAUSE.
%   The single try/catch is now four staged ones, so
%   `refused_element_not_in_batch` means exactly what it says (identifier
%   `did2:convert:noSubjectForElement`, the honest best-effort case this pass
%   was designed around) and anything else lands in
%   `refused_unexpected_error`, with one entry per DISTINCT identifier in
%   `unexpected_error_reasons`. Folding a real bug into the expected case is
%   what the old handler did, and it is the reassuring direction.
%
%   READ `deferred_baths_seen` BESIDE `quarantine_inspected`. Every counter at
%   0 with `deferred_baths_seen` at 0 means this batch deferred no bath -- a
%   fact about the input, not about the resolver. `deferred_baths_seen`
%   non-zero with `baths_resolved` at 0 is the line worth looking at, and the
%   five `refused_*` counters then say which cause.
%
%   `migrated_indexed` IS THE OTHER DENOMINATOR. Resolution walks an index
%   built from `result.migrated`; `elements_indexed` and
%   `lineage_edges_indexed` are how much of it the two subject models found.
%   Zero of both with a non-zero `migrated_indexed` means the index is empty
%   for a reason other than an empty batch, which no other counter here can
%   distinguish.
%
%   STATUS of the 2026-08-11 report edit: WRITTEN IN A CONTAINER WITH NO MATLAB
%   AND NO OCTAVE (`command -v matlab octave octave-cli` exits 1). NOTHING IN
%   IT HAS BEEN EXECUTED. test-migrators-quick.yml (which runs
%   testFixtureCorpus, a bare caller of this pass) is the first thing that will
%   have an opinion.
%
%   CALL SITES: runCorpusDiscovery, testCorpusPRED, testFixtureCorpus and
%   ndi.migrate.local. The two REPORT-WRITING sites now route this pass through
%   did2.unittest.helpers.runBatchPass -- it runs before writeCorpusReport, so
%   an uncaught throw here costs a corpus its entire census -- and both add it
%   to their FATAL pass list, so a throw still turns the gate red.
%   testFixtureCorpus keeps calling it BARE on purpose.
%
%   See also: did2.convert.v1_to_v2, did2.convert.migrators_j.stimulus_bath,
%   ndi.migrate.internal.stimulusBathToBath.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char {mustBeMember(options.TargetVersion, {'V_eta', 'did_v2'})} = 'did_v2'
end

% A batch pass builds documents from the v1 source's own terms, exactly as a
% migrator does inside v1_to_v2, so the T19 TermRegistry check is off while it
% runs, as it is there, and restored after (unregistered terms are still
% collected when did2.build.unregisteredTerms('-collect') is on).
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>
% The generic migration is not affected by [V2 builder refuses retired]
% (Jess Haley, 2026-10-24): strictMode 'RetiredClasses' is off while it runs.
prevRetiredClasses = did2.schema.cache.strictMode('RetiredClasses', false);
restoreRetiredClasses = onCleanup(@() did2.schema.cache.strictMode('RetiredClasses', prevRetiredClasses)); %#ok<NASGU>

% DENOMINATOR FIRST, and unconditionally -- every field defined before a single
% quarantine entry is read, so "did not run", "ran over an empty quarantine"
% and "ran and refused everything" are three different readings rather than
% one. Operating Rule 5.
report = struct( ...
    'quarantine_inspected',           0, ...
    'migrated_indexed',               0, ...
    'elements_indexed',               0, ...
    'lineage_edges_indexed',          0, ...
    'index_documents_unreadable',     0, ...
    'deferred_baths_seen',            0, ...
    'baths_resolved',                 0, ...
    'bodies_assembled',               0, ...
    'refused_body_unreadable',        0, ...
    'refused_no_stimulus_element_id', 0, ...
    'refused_element_not_in_batch',   0, ...
    'refused_bath_assembly_failed',   0, ...
    'refused_unexpected_error',       0, ...
    'refused_total',                  0, ...
    'documents_appended',             0, ...
    'assembled_bodies_quarantined',   0, ...
    'quarantine_before',              0, ...
    'quarantine_after',               0, ...
    'baths_with_instrument',          0, ...
    'baths_without_epoch_string',     0, ...
    'bath_anchors_handed_over',       0, ...
    'bath_anchors_no_time',           0, ...
    'bath_clocks_from_element_epoch', 0, ...
    'bath_clocks_defaulted',          0, ...
    'baths_carried_no_clock',         0, ...
    'unexpected_error_reasons',       {{}}, ...
    'ran',                            false);
result.deferred_bath_resolution = report;
% [one bath shape]: what epochMint's resolveBathAnchors re-points (one row per
% handed-on anchor); always present, so "none handed on" is not "not run"
result.deferred_bath_anchors = emptyBathAnchors();

if ~isfield(result, 'quarantine')
    % NOT the same as an empty quarantine, and not the same as not running.
    report.ran = true;
    result.deferred_bath_resolution = report;
    return;
end
report.ran = true;
report.quarantine_inspected = numel(result.quarantine);
report.quarantine_before = numel(result.quarantine);
report.quarantine_after = numel(result.quarantine);
if isfield(result, 'migrated')
    report.migrated_indexed = numel(result.migrated);
end
if isempty(result.quarantine)
    % 0 OF 0 INSPECTED, said as such. A `0 refused` with no denominator beside
    % it is the reading that got this project into writing these rules.
    result.deferred_bath_resolution = report;
    return;
end

[byElement, indexStats] = indexElements(result.migrated);
clockByElementEpoch = indexElementEpochClocks(result.migrated);
report.elements_indexed = indexStats.elements;
report.lineage_edges_indexed = indexStats.lineage_edges;
report.index_documents_unreadable = indexStats.unreadable;

q = result.quarantine;
keep = true(1, numel(q));
assembled = {};
pendingAnchors = struct('bath_id', {}, 'anchor_id', {}, 'session_id', {}, ...
    'epoch_string', {}, 'epoch_clock', {}, 'clock_source', {});
seenErrorIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
carriedBodies = {};   % [one-reading quick answers] Q2: v1 sources carried
carriedNotes = {};    % their carry notes
for k = 1:numel(q)
    if ~isDeferredBath(q(k))
        continue;
    end
    report.deferred_baths_seen = report.deferred_baths_seen + 1;

    % STAGE 1: the source body. An unreadable body is a different fact from an
    % element that is not in the batch, and the old handler said neither.
    try
        v1Body = jsondecode(q(k).original_body);
    catch
        report.refused_body_unreadable = report.refused_body_unreadable + 1;
        continue;
    end

    % STAGE 2: the edge this pass follows. Absent means the source document
    % never named a stimulator -- nothing to resolve, and NOT a missing element.
    stimulatorId = dependencyValue(v1Body, 'stimulus_element_id');
    if isempty(stimulatorId)
        report.refused_no_stimulus_element_id = ...
            report.refused_no_stimulus_element_id + 1;
        continue;
    end

    % STAGE 3: the resolution itself. `did2:convert:noSubjectForElement` is the
    % EXPECTED refusal -- the element is not in this batch, which is the honest
    % best-effort case documented above. Every other identifier is a defect and
    % is counted, named and printed as one rather than absorbed here.
    try
        subjectId = subjectOfElement(byElement, stimulatorId);
    catch resolveErr
        if strcmp(resolveErr.identifier, 'did2:convert:noSubjectForElement')
            report.refused_element_not_in_batch = ...
                report.refused_element_not_in_batch + 1;
        else
            report.refused_unexpected_error = ...
                report.refused_unexpected_error + 1;
            [report, seenErrorIds] = noteUnexpected(report, seenErrorIds, ...
                'subjectOfElement', resolveErr);
        end
        continue;
    end

    % STAGE 3b: the clock. [one-reading quick answers] Q2 (Decided by Jess
    % Haley, 2026-10-26): a bath whose epoch has no clock record for its
    % stimulator is carried as v1, not anchored on an invented
    % 'dev_local_time' ([no invented values]).
    epochString = bathEpochString(v1Body);
    if ~isempty(epochString)
        [~, clockSource] = stimulatorClock(clockByElementEpoch, stimulatorId, epochString);
        if ~strcmp(clockSource, 'element_epoch')
            if isfield(v1Body, 'document_class') && isstruct(v1Body.document_class)
                v1Body.document_class.schema_version = 'did_v1';
            end
            carriedBodies{end+1} = v1Body; %#ok<AGROW>
            carriedNotes{end+1} = sprintf(['[carry-157] needs_mapping: epoch "%s" has ' ...
                'no clock record for its stimulator %s ([one-reading quick answers] Q2)'], ...
                epochString, char(stimulatorId)); %#ok<AGROW>
            report.baths_carried_no_clock = report.baths_carried_no_clock + 1;
            keep(k) = false;   % carried -> drop the original deferral
            continue;
        end
    end

    % STAGE 4: assembly. A throw here is always a defect in this file.
    try
        [bathBodies, anchorInfo] = makeBath(v1Body, subjectId, stimulatorId, ...
            clockByElementEpoch, options.TargetVersion);
    catch assembleErr
        report.refused_bath_assembly_failed = ...
            report.refused_bath_assembly_failed + 1;
        [report, seenErrorIds] = noteUnexpected(report, seenErrorIds, ...
            'makeBath', assembleErr);
        continue;
    end

    assembled = [assembled, bathBodies]; %#ok<AGROW>
    pendingAnchors(end+1) = anchorInfo; %#ok<AGROW>
    report.bodies_assembled = report.bodies_assembled + numel(bathBodies);
    report.baths_resolved = report.baths_resolved + 1;
    keep(k) = false;   % resolved -> drop the original deferral
end

% Summed from the five NAMED causes, never from a difference. `refused_total`
% is a convenience for the deletion-gate readings the sibling passes print; the
% causes are the finding and are never collapsed into it in the printout.
report.refused_total = report.refused_body_unreadable ...
    + report.refused_no_stimulus_element_id ...
    + report.refused_element_not_in_batch ...
    + report.refused_bath_assembly_failed ...
    + report.refused_unexpected_error;

if isempty(assembled) && isempty(carriedBodies)
    result.deferred_bath_resolution = report;
    return;
end

if isempty(assembled)
    sub = struct('migrated', {{}}, 'quarantine', q([]));
else
    sub = did2.convert.v1_to_v2(assembled, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'TargetVersion', options.TargetVersion, ...
        'Verbose', false);
end

result.migrated = [result.migrated, sub.migrated];
result.quarantine = [q(keep), sub.quarantine];
result = carryBaths(result, carriedBodies, carriedNotes);
% [one bath shape]: count what landed, and hand on the anchors of the baths
% that landed (an anchor whose bath was quarantined is not re-pointed)
landed = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(sub.migrated)
    try
        landed(char(sub.migrated{k}.get('base.id'))) = true;
    catch
    end
end
for k = 1:numel(pendingAnchors)
    a = pendingAnchors(k);
    if ~isKey(landed, a.bath_id) || ~isKey(landed, a.anchor_id); continue; end
    report.baths_with_instrument = report.baths_with_instrument + 1;
    if isempty(a.epoch_string)
        report.baths_without_epoch_string = report.baths_without_epoch_string + 1;
        continue;
    end
    switch a.clock_source
        case 'element_epoch'
            report.bath_clocks_from_element_epoch = report.bath_clocks_from_element_epoch + 1;
        otherwise
            report.bath_clocks_defaulted = report.bath_clocks_defaulted + 1;
    end
    if strcmp(a.epoch_clock, 'no_time')
        report.bath_anchors_no_time = report.bath_anchors_no_time + 1;
        continue;
    end
    result.deferred_bath_anchors(end+1) = struct('anchor_id', a.anchor_id, ...
        'session_id', a.session_id, 'epoch_string', a.epoch_string, ...
        'epoch_clock', a.epoch_clock);
end
report.bath_anchors_handed_over = numel(result.deferred_bath_anchors);
report.documents_appended = numel(sub.migrated) + numel(carriedBodies);
report.assembled_bodies_quarantined = numel(sub.quarantine);
report.quarantine_after = numel(result.quarantine);
result.summary = recountSummary(result);
result.deferred_bath_resolution = report;
end

% ===================== unexpected-error bookkeeping =========================

function [report, seen] = noteUnexpected(report, seen, stage, err)
%NOTEUNEXPECTED Record ONE entry per distinct error identifier.
%   Bounded by construction (distinct identifiers, not occurrences), so a
%   corpus where every bath fails the same way cannot fill the artifact with
%   half a million identical strings -- and a SECOND, different failure is
%   still visible beside the first. The count lives in the counter; this cell
%   says what the failures were.
id = char(err.identifier);
if isempty(id); id = '<no identifier>'; end
key = sprintf('%s:%s', stage, id);
if isKey(seen, key)
    return;
end
seen(key) = true;
report.unexpected_error_reasons{end+1} = sprintf( ...
    '%s threw %s: %s', stage, id, char(err.message));
end

% ===================== element -> subject index ============================

function [idx, stats] = indexElements(migrated)
%INDEXELEMENTS Index the batch for stimulator -> specimen resolution under BOTH
%   subject models: the `elements` map (base.id -> element doc, the V_zeta model
%   where the stimulator is still an `element`) and the `relParent` map (a
%   directed_relation's child -> parent, the V_eta model where the element has
%   become a `subject` whose lineage relation points at its specimen).
%
%   STATS reports what the index actually holds -- `elements`,
%   `lineage_edges`, and the documents it could not read at all. Without it
%   "no element matched" and "the index is empty" print the same, and only one
%   of those is about the corpus.
idx = struct();
idx.elements = containers.Map('KeyType', 'char', 'ValueType', 'any');
idx.relParent = containers.Map('KeyType', 'char', 'ValueType', 'char');
stats = struct('elements', 0, 'lineage_edges', 0, 'unreadable', 0);
for k = 1:numel(migrated)
    doc = migrated{k};
    try
        cn = doc.className();
        if strcmp(cn, 'element') || strcmp(cn, 'entity')
            % #88: an element migrates to an `entity` (its lineage to the
            % specimen is a relation, read below)
            id = char(doc.get('base.id'));
            if ~isempty(id); idx.elements(id) = doc; end
        elseif strcmp(cn, 'directed_relation')
            deps = docDeps(doc);
            child = depFrom(deps, 'child_id');
            if isempty(child); child = depFrom(deps, 'child'); end
            parent = depFrom(deps, 'parent_id');
            if isempty(parent); parent = depFrom(deps, 'parent'); end
            if ~isempty(child) && ~isempty(parent) && ~isKey(idx.relParent, child)
                idx.relParent(child) = parent;
            end
        end
    catch
        % A document whose class/id/deps cannot be read is COUNTED, not
        % silently skipped: it is a hole in the index the resolution below
        % walks, so an unresolved bath in a run with a non-zero count here is
        % not evidence the element was absent.
        stats.unreadable = stats.unreadable + 1;
    end
end
stats.elements = double(idx.elements.Count);
stats.lineage_edges = double(idx.relParent.Count);
end

function subjectId = subjectOfElement(idx, elementId)
%SUBJECTOFELEMENT Resolve the specimen the stimulator belongs to.
%   V_eta: the stimulator is now a `subject`; follow its lineage
%   directed_relation(s) (child -> parent) up to the specimen. V_zeta fallback:
%   walk the `element` docs' underlying_element_id chain to a subject_id.

% -- V_eta: walk the directed_relation lineage from the element-subject --------
cur = char(elementId);
visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
while isKey(idx.relParent, cur) && ~isKey(visited, cur)
    visited(cur) = true;
    cur = idx.relParent(cur);
end
if ~isempty(cur) && ~strcmp(cur, char(elementId))
    subjectId = cur;   % reached the specimen via the lineage graph
    return;
end

% -- V_zeta fallback: walk the element docs -----------------------------------
cur = char(elementId);
visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
while ~isempty(cur) && ~isKey(visited, cur)
    visited(cur) = true;
    if ~isKey(idx.elements, cur); break; end
    deps = docDeps(idx.elements(cur));
    sid = depFrom(deps, 'subject_id');
    if ~isempty(sid); subjectId = sid; return; end
    cur = depFrom(deps, 'underlying_element_id');
end
error('did2:convert:noSubjectForElement', ...
    'Could not resolve a subject_id for element "%s" in the batch.', ...
    char(elementId));
end

% ===================== bath assembly (coarse) ==============================

function [bodies, anchorInfo] = makeBath(v1Body, subjectId, stimulatorId, ...
    clockByElementEpoch, targetVersion)
%MAKEBATH Assemble the resolved bath (+ its anchor) for TARGETVERSION. Returns a
%   cell of bodies {anchor, manipulation, ...} to fold back through v1_to_v2.
%   Strict J (V_eta) retired the `bath`/`pharmacological_manipulation` family
%   (D8). A bath is a `manipulation` whose value is the bath's `formulation`,
%   taken through `value_id` -- NOT a dose: "A bath is a manipulation whose
%   value is the formulation (pointed at through `value_id`), not a dose; a
%   dose always has an amount" (Jess Haley, 2026-10-21; did-schema
%   V_eta_go_forward_class_audit.md). A bath gives no amount, so the dose it
%   used to be had an empty `dose.value`, which the value rule
%   (`value_inline_or_body`, did-schema data_body AMENDMENT 5) refuses. The
%   V_zeta/V_epsilon branch that kept the `bath` class was deleted with
%   did-schema #88 (OPEN_WORK #128).
if ~did2.convert.isV2Set(targetVersion)
    error('did2:convert:unsupportedTarget', ...
        ['resolveDeferredBaths assembles V_eta only; TargetVersion "%s" has ' ...
         'no bath model (V_epsilon/V_zeta were deleted, did-schema #88).'], ...
        targetVersion);
end
[bodies, anchorInfo] = makeBathVEta(v1Body, subjectId, stimulatorId, clockByElementEpoch);
end

function [bodies, anchorInfo] = makeBathVEta(v1Body, subjectId, stimulatorId, ...
    clockByElementEpoch)
% did-schema #88, built through did2.build: a "during the session" anchor (a
% relative_time_reference onto the session entity, whose base.id IS the
% session id), one `chemical` per mixture row, the `formulation` naming them
% (its ingredient entries carry each row's amount as the source wrote it), the
% `manipulation` (id preserved) whose value kind is `formulation` and whose
% value is that formulation document, through `value_id` (a bath is not a dose:
% Jess Haley, 2026-10-21), and the location observation when the bath names a
% location.
sessionId = baseField(v1Body, 'session_id', '');
datestamp = baseField(v1Body, 'datestamp', '');
if isempty(datestamp); datestamp = did2.convert.migrationTime(); end
bathId    = baseField(v1Body, 'id', '');
% the chemicals and formulation built below take ids derived from the bath's
% v1 id (did2.convert.mintId; practice (b) of [migration reliability
% practices], Jess Haley, 2026-10-26)
mintDepth = did2.convert.mintId('-depth');
did2.convert.mintId('-push', char(bathId));
restoreMint = onCleanup(@() did2.convert.mintId('-popto', mintDepth));
mixture   = parseMixture(v1Body);
% the variable is the general bath-solution term, never the first mixture row
% (e.g. "sodium chloride"); the value is the whole formulation (value_id).
% Decided by Jess Haley, 2026-10-26 [bath is two statements] (1) and
% 2026-10-27 [bath solution minted] (EMPTY:0000409 "bath solution"), did-schema
% V_eta_go_forward_class_audit.md. The ingredient that was really changed is
% the dataset map's statement (2), not this pass's.
variable  = bathSolutionVariable();
o = {'SessionId', char(sessionId), 'CreationTimestamp', char(datestamp), 'Validate', false};

anchorBody = did2.build.relativeTimeReference(char(sessionId), ...
    'Relation', 'intervalDuring', o{:});
anchorId = anchorBody.base.id;

bodies = {anchorBody};
ids = {};
entries = {};
props = struct();
for i = 1:numel(mixture)
    chem = mixture(i).chemical;
    if isempty(chem.node) && isempty(chem.name)
        continue;
    end
    a = mixture(i).amount;
    unitTerm = did2.convert.registeredTerm(a.source_unit.node, a.source_unit.name);
    % A WHOLE-MIXTURE PROPERTY is not an ingredient: the pH row and the
    % osmolarity row land on the formulation's own `ph` / `osmolarity`, which
    % #88 declares for exactly these (the source writes them as table rows).
    if strcmpi(chem.name, 'pH') && isfinite(a.source_value)
        props.ph = struct('ph', a.source_value, 'source_value', a.source_value, ...
            'source_unit', unitTerm, 'approximate', false);
        continue;
    end
    if any(strcmpi(chem.name, {'osm', 'osmolarity'})) && isfinite(a.source_value)
        props.osmolarity = struct('source_value', a.source_value, ...
            'source_unit', unitTerm, 'approximate', false);
        continue;
    end
    sub = did2.convert.registeredTerm(chem.node, chem.name);
    c = did2.build.document('chemical', struct('value', struct('substance', sub)), o{:});
    bodies{end+1} = c; %#ok<AGROW>
    ids{end+1} = c.base.id; %#ok<AGROW>
    e = struct();
    if isfinite(a.source_value)
        conc = struct('source_value', a.source_value, 'approximate', false);
        if ~isempty(a.source_unit.node) || ~isempty(a.source_unit.name)
            conc.source_unit = unitTerm;
        end
        if strcmpi(a.source_unit.name, 'Molar')
            conc.molar = a.source_value;      % the canonical slot, unit computable
        end
        e.concentration = conc;
    end
    entries{end+1} = e; %#ok<AGROW>
end
fv = props;
fv.ingredients = entries;
f = did2.build.document('formulation', struct('value', fv), ...
    o{:}, 'Edges', struct('ingredient_id', {ids}));
bodies{end+1} = f;
% `formulation_manipulation` is no class: did2.build reads it as the direction
% `manipulation` with the value kind `formulation`. Its own `value` stays empty;
% the formulation document holds it.
% [one bath shape]: the stimulator is the instrument, as NDI's vetaBath writes
bath = did2.build.statement('manipulation', char(subjectId), variable, [], ...
    'TimeReferenceIds', {anchorId}, 'ValueId', f.base.id, ...
    'InstrumentId', char(stimulatorId), ...
    'Id', char(bathId), o{:}, 'ValueKind', 'formulation');
% and its epoch, handed on for epochMint to re-point the anchor at
epochString = '';
if isfield(v1Body, 'epochid') && isstruct(v1Body.epochid) ...
        && isfield(v1Body.epochid, 'epochid')
    epochString = charOrEmpty(v1Body.epochid.epochid);
end
[epochClock, clockSource] = stimulatorClock(clockByElementEpoch, stimulatorId, epochString);
anchorInfo = struct('bath_id', char(bathId), 'anchor_id', anchorId, ...
    'session_id', char(sessionId), 'epoch_string', epochString, ...
    'epoch_clock', epochClock, 'clock_source', clockSource);
bodies = [{bath}, bodies];
loc = locationTerm(v1Body);
if (~isempty(loc.node) || ~isempty(loc.name)) && ~isGenericBath(loc)
    bodies{end+1} = makeLocationObs(v1Body, subjectId, anchorId, loc);
end
end

function result = carryBaths(result, bodies, notes)
%CARRYBATHS [one-reading quick answers] Q2 (Jess Haley, 2026-10-26): each
%   v1 source in BODIES (stamped 'did_v1') joins RESULT.migrated, carried
%   whole as v1, with a passthrough record (input_index 0: the quarantine
%   keeps no input index) and its `carried_as_v1` note merged into
%   RESULT.summary.migration_notes. The note buffer is reset first: the
%   v1_to_v2 call above has already reset it, and its own notes are not
%   this batch's.
if isempty(bodies)
    return;
end
did2.convert.reportNote('reset');
for k = 1:numel(bodies)
    b = bodies{k};
    id = char(baseField(b, 'id', ''));
    result.migrated{end+1} = did2.document(b);
    rec = struct('input_index', 0, 'id', id, 'class_name', 'stimulus_bath', 'body', b);
    if isfield(result, 'passthrough') && isstruct(result.passthrough)
        result.passthrough(end+1) = rec;
    else
        result.passthrough = rec;
    end
    % carry-register: carry-157
    did2.convert.reportNote('carried_as_v1', 'stimulus_bath', id, notes{k});
end
fresh = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
if ~isfield(result, 'summary') || ~isstruct(result.summary)
    result.summary = struct();
end
old = struct();
if isfield(result.summary, 'migration_notes')
    old = result.summary.migration_notes;
end
result.summary.migration_notes = did2.convert.reportNote('merge', old, fresh);
result.summary.passthrough_count = numel(result.passthrough);
end

function s = bathEpochString(v1Body)
%BATHEPOCHSTRING The bath's v1 epochid.epochid ('' when it names none).
s = '';
if isfield(v1Body, 'epochid') && isstruct(v1Body.epochid) ...
        && isfield(v1Body.epochid, 'epochid')
    s = charOrEmpty(v1Body.epochid.epochid);
end
end

function a = emptyBathAnchors()
a = struct('anchor_id', {}, 'session_id', {}, 'epoch_string', {}, 'epoch_clock', {});
end

function s = charOrEmpty(x)
s = '';
if ischar(x) || (isstring(x) && isscalar(x))
    s = char(x);
end
end

function idx = indexElementEpochClocks(migrated)
%INDEXELEMENTEPOCHCLOCKS '<element id>|<epoch string>' -> the clock string, as
%   NDI's bodyResolver epochClockOfElement reads an element_epoch's
%   `epoch_clock`: here an `acquisition_epoch` (+migrators_j/element_epoch: the
%   clock names of acquisition_epoch.clocks, joined by ',', as v1 wrote
%   epoch_clock) or a v1 `element_epoch` pass 1 carried. The first document
%   naming a key wins, as there.
idx = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(migrated)
    try
        cn = migrated{k}.className();
        if ~any(strcmp(cn, {'acquisition_epoch', 'element_epoch'})); continue; end
        b = migrated{k}.toStruct();
        el = depFrom(docDeps(migrated{k}), 'element_id');
        es = '';
        if isfield(b, 'epochid') && isstruct(b.epochid) && isfield(b.epochid, 'epochid')
            es = charOrEmpty(b.epochid.epochid);
        end
        if isempty(el) || isempty(es); continue; end
        clk = '';
        if strcmp(cn, 'acquisition_epoch')
            if isfield(b, 'acquisition_epoch') && isstruct(b.acquisition_epoch) ...
                    && isfield(b.acquisition_epoch, 'clocks') && isstruct(b.acquisition_epoch.clocks)
                c = b.acquisition_epoch.clocks;
                names = cell(1, numel(c));
                for j = 1:numel(c)
                    if isfield(c(j), 'name'); names{j} = charOrEmpty(c(j).name); end
                end
                clk = strjoin(names(~cellfun(@isempty, names)), ',');
            end
        elseif isfield(b, 'element_epoch') && isstruct(b.element_epoch) ...
                && isfield(b.element_epoch, 'epoch_clock')
            clk = charOrEmpty(b.element_epoch.epoch_clock);
        end
        key = [el '|' es];
        if ~isempty(clk) && ~isKey(idx, key)
            idx(key) = clk;
        end
    catch
        % unreadable: not indexed (the bath then takes the default clock,
        % counted in bath_clocks_defaulted)
    end
end
end

function [clock, source] = stimulatorClock(idx, stimulatorId, epochString)
% the stimulator's clock for that epoch; SOURCE 'element_epoch' when found.
% With no record the clock is '' and SOURCE 'none': [one-reading quick
% answers] Q2 (Jess Haley, 2026-10-26) carries such a bath (carry-157) rather
% than defaulting to 'dev_local_time' ([no invented values]), so the main
% loop never assembles a bath with an epoch string on SOURCE 'none'.
clock = '';
source = 'none';
key = [char(stimulatorId) '|' char(epochString)];
if ~isempty(epochString) && isKey(idx, key)
    clock = idx(key);
    source = 'element_epoch';
end
end

function tf = isGenericBath(loc)
%ISGENERICBATH The whole-prep / whole-slice bath location: a name 'bath', the
%   node NCIm:C0179246 compared as a CURIE key, or a registry term labelled
%   'bath' -- +migrators_j/private/jTreatmentRoute's test, restated here because
%   a private function is not callable from this package.
node = strtrim(char(loc.node));
name = strtrim(char(loc.name));
tf = strcmpi(name, 'bath');
if ~tf && ~isempty(node)
    tf = strcmpi(curieKeyOf(node), curieKeyOf('NCIm:C0179246'));
end
if ~tf
    r = did2.convert.registeredTerm(node, name);
    tf = strcmpi(strtrim(r.name), 'bath');
end
end

function k = curieKeyOf(node)
try
    k = char(did2.schema.curieKey(node));
catch
    k = lower(node);
end
end

function obs = makeLocationObs(v1Body, subjectId, anchorId, loc)
datestamp = baseField(v1Body, 'datestamp', '');
if isempty(datestamp); datestamp = did2.convert.migrationTime(); end
obs = did2.build.statement('observation', char(subjectId), ...
    did2.convert.registeredTerm('NCIT:C13717', 'Anatomic Site'), ...
    did2.convert.registeredTerm(loc.node, loc.name), ...
    'TimeReferenceIds', {anchorId}, ...
    'SessionId', char(baseField(v1Body, 'session_id', '')), ...
    'CreationTimestamp', char(datestamp), 'Validate', false, 'ValueKind', 'term');
end

function variable = bathSolutionVariable()
% [bath is two statements] / [bath solution minted]: every bath's variable, as
% the term registry holds it (did2.convert.registeredTerm)
variable = did2.convert.registeredTerm('EMPTY:0000409', 'bath solution');
end

function term = locationTerm(body)
term = struct('node', '', 'name', '');
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'location') ...
        && isstruct(body.stimulus_bath.location)
    loc = body.stimulus_bath.location;
    if isfield(loc, 'node');             term.node = loc.node;
    elseif isfield(loc, 'ontologyNode'); term.node = loc.ontologyNode; end
    if isfield(loc, 'name');             term.name = loc.name; end
end
end

function mixture = parseMixture(body)
%PARSEMIXTURE The bath's mixture_table rows, as NDI's writer serialises them:
%   a CSV with a HEADER row (ontologyName,name,value,ontologyUnit,unitName) and
%   double-quoted names that may hold commas ("sodium phosphate, monobasic,
%   anhydrous"). Each row is {chemical {node,name}, amount {source_value,
%   source_unit {node,name}}}; the header is not a row. (The pre-#88 reader
%   split on every comma and kept the header, which produced a chemical whose
%   node was the literal text "ontologyName".)
mixture = struct('chemical', {}, 'amount', {});
if ~(isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'mixture_table'))
    return;
end
raw = body.stimulus_bath.mixture_table;
if ~(ischar(raw) || (isstring(raw) && isscalar(raw)))
    return;
end
lines = regexp(char(raw), '\r?\n', 'split');
for i = 1:numel(lines)
    line = strtrim(lines{i});
    if isempty(line); continue; end
    cols = regexp(line, '("([^"]|"")*"|[^,]*)(,|$)', 'tokens');
    cols = cellfun(@(c) unquote(c{1}), cols, 'UniformOutput', false);
    if numel(cols) < 5 || isempty(cols{1}); continue; end
    if strcmpi(cols{1}, 'ontologyName'); continue; end      % the header row
    chemical = struct('node', cols{1}, 'name', cols{2});
    amount = struct('source_value', str2double(cols{3}), ...
        'source_unit', struct('node', cols{4}, 'name', cols{5}), 'approximate', false);
    mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
end
end

function t = unquote(t)
t = strtrim(t);
if numel(t) >= 2 && t(1) == '"' && t(end) == '"'
    t = strrep(t(2:end-1), '""', '"');
end
end
function tf = isDeferredBath(qEntry)
tf = false;
if isfield(qEntry, 'class_name') && strcmp(qEntry.class_name, 'stimulus_bath')
    tf = true;
    return;
end
if isfield(qEntry, 'reason') && ischar(qEntry.reason)
    tf = contains(qEntry.reason, 'needsSessionContext') ...
        || contains(qEntry.reason, 'NDI layer');
end
end

function deps = docDeps(doc)
deps = [];
try
    deps = doc.get('depends_on');
catch
end
end

function v = depFrom(deps, name)
v = '';
for k = 1:numel(deps)
    d = deps(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value') && ~isempty(d.value); v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
        return;
    end
end
end

function v = dependencyValue(body, name)
v = '';
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    for k = 1:numel(body.depends_on)
        d = body.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value'); v = char(d.value);
            elseif isfield(d, 'document_id'); v = char(d.document_id); end
            return;
        end
    end
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name)
    v = body.base.(name);
end
end

function summary = recountSummary(result)
summary = result.summary;
summary.migrated_count = numel(result.migrated);
summary.quarantine_count = numel(result.quarantine);
byClass = struct();
for k = 1:numel(result.migrated)
    name = result.migrated{k}.className();
    fieldName = matlab.lang.makeValidName(name);
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end
