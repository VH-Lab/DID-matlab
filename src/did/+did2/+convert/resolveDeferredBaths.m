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
%   BATCH-PASS-EMITS: stimulus_bath -> document: session_relative_reference,
%       dose_manipulation, term_observation
%
%   SCOPE OF THAT LINE: it states the V_eta path (makeBathVEta, :396), which is
%   what the corpus harness runs -- runCorpusDiscovery.m:46 defaults
%   `TargetVersion` to 'V_eta'. THIS FILE'S DEFAULT IS 'V_zeta', and on that
%   branch makeBath (:341) emits `bath` + `pharmacological_manipulation`
%   instead. Those are V_zeta classes with no V_eta home, so they are
%   deliberately NOT declared: the ledger this declaration feeds is the V_eta
%   one, and naming them there would credit a class V_eta retired.
%   `term_observation` is CONDITIONAL (:462-466, only when the source names a
%   location); the declaration states what the pass can emit, not what every
%   document produces.
%   ---------------------------------------------------------------------
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
%     TargetVersion (1,:) char, default 'V_zeta') - the migration target the
%                   assembled bodies are tagged with (Brainstorm I).
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
%   See also: did2.convert.v1_to_v2, did2.convert.migrators_i.stimulus_bath,
%   ndi.migrate.internal.stimulusBathToBath.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_zeta'
end

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
    'unexpected_error_reasons',       {{}}, ...
    'ran',                            false);
result.deferred_bath_resolution = report;

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
report.elements_indexed = indexStats.elements;
report.lineage_edges_indexed = indexStats.lineage_edges;
report.index_documents_unreadable = indexStats.unreadable;

q = result.quarantine;
keep = true(1, numel(q));
assembled = {};
seenErrorIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
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

    % STAGE 4: assembly. A throw here is always a defect in this file.
    try
        bathBodies = makeBath(v1Body, subjectId, options.TargetVersion);
    catch assembleErr
        report.refused_bath_assembly_failed = ...
            report.refused_bath_assembly_failed + 1;
        [report, seenErrorIds] = noteUnexpected(report, seenErrorIds, ...
            'makeBath', assembleErr);
        continue;
    end

    assembled = [assembled, bathBodies]; %#ok<AGROW>
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

if isempty(assembled)
    result.deferred_bath_resolution = report;
    return;
end

sub = did2.convert.v1_to_v2(assembled, ...
    'Validate', options.Validate, ...
    'SchemaCache', options.SchemaCache, ...
    'TargetVersion', options.TargetVersion, ...
    'Verbose', false);

result.migrated = [result.migrated, sub.migrated];
result.quarantine = [q(keep), sub.quarantine];
report.documents_appended = numel(sub.migrated);
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
        if strcmp(cn, 'element')
            id = char(doc.get('base.id'));
            if ~isempty(id); idx.elements(id) = doc; end
        elseif strcmp(cn, 'directed_relation')
            deps = docDeps(doc);
            child = depFrom(deps, 'child');
            parent = depFrom(deps, 'parent');
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

function bodies = makeBath(v1Body, subjectId, targetVersion)
%MAKEBATH Assemble the resolved bath (+ its anchor) for TARGETVERSION. Returns a
%   cell of bodies {anchor, manipulation, ...} to fold back through v1_to_v2.
%   Strict J (V_eta) retired the `bath`/`pharmacological_manipulation` family
%   (D8): a bath is a delivered substance -> a `dose_manipulation`
%   subject_manipulation leaf, exactly as migrators_j.treatment routes a `bath`
%   keyword. Earlier targets (V_zeta/E) keep the `bath` class.
if strcmp(targetVersion, 'V_eta')
    bodies = makeBathVEta(v1Body, subjectId);
    return;
end

sessionId = baseField(v1Body, 'session_id', '');
datestamp = baseField(v1Body, 'datestamp', '');
bathId    = baseField(v1Body, 'id', did.ido.unique_id());
mixture   = parseMixture(v1Body);

% session_relative_reference('during'): the ordinal fallback anchor.
anchorId = did.ido.unique_id();
anchorBody = struct();
anchorBody.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
% Session identity rides on base.session_id; no redundant session_id edge
% (it only produced discovery-mode orphans). See V_zeta
% session_relative_reference (depends_on now empty).
anchorBody.depends_on = struct('name', {}, 'value', {});
anchorBody.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'creation_timestamp', datestamp);
anchorBody.time_reference = struct('is_approximate', true);
anchorBody.session_relative_reference = struct('relation', 'during');

bathBody = struct();
bathBody.document_class = struct('class_name', 'bath', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'pharmacological_manipulation', ...
        'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
bathBody.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
bathBody.base = struct('id', bathId, 'session_id', sessionId, ...
    'name', 'migrated_bath', 'creation_timestamp', datestamp);
if strcmp(targetVersion, 'V_zeta')
    bathBody.subject_interaction = struct( ...
        'method', struct('node', '', 'name', ''), ...
        'variable', primaryChemical(mixture), ...
        'target_structure', {struct('node', {}, 'name', {})});
    bathBody.manipulation = struct('notes', '');
end
bathBody.pharmacological_manipulation = struct('mixture', mixture);
bathBody.bath = struct('kind', 'drug', 'location', locationTerm(v1Body));
bodies = {anchorBody, bathBody};
end

function bodies = makeBathVEta(v1Body, subjectId)
%MAKEBATHVETA Assemble a strict-J `dose_manipulation` (+ session anchor) from a
%   deferred stimulus_bath. Mirrors migrators_j.treatment.makeDoseManipulation:
%   the primary chemical is the spine identity (subject_statement.variable), the
%   whole bath mixture becomes the dose formulation's chemicals, and the bath
%   rides on the resolved subject over a session-relative window. The bath
%   `location` has no strict-J home on the subject (it is the chamber, not a
%   subject site) and is dropped -- a discovery follow-up if it proves needed.
sessionId = baseField(v1Body, 'session_id', '');
datestamp = baseField(v1Body, 'datestamp', '');
bathId    = baseField(v1Body, 'id', did.ido.unique_id());
mixture   = parseMixture(v1Body);
variable  = primaryChemical(mixture);

% session-relative anchor (the ordinal fallback; base.session_id carries session)
anchorId = did.ido.unique_id();
anchorBody = struct();
anchorBody.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
anchorBody.depends_on = struct('name', {}, 'value', {});
anchorBody.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'creation_timestamp', datestamp);
anchorBody.time_reference = struct('is_approximate', true);
anchorBody.session_relative_reference = struct('relation', 'during');

% the bath mixture -> dose formulation chemicals ({substance, amount}).
% `substance` is a non-empty ontology_term, so skip parseMixture's blank
% fallback entry (both node and name empty) rather than emit an invalid chemical.
chemicals = struct('substance', {}, 'amount', {});
for i = 1:numel(mixture)
    chem = mixture(i).chemical;
    if isempty(chem.node) && isempty(chem.name)
        continue;
    end
    chemicals(end+1) = struct('substance', chem, ...
        'amount', mixture(i).amount); %#ok<AGROW>
end
formulation = struct();
formulation.chemicals = chemicals;

dose = struct();
dose.document_class = struct('class_name', 'dose_manipulation', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_manipulation', 'class_version', '1.0.0'), ...
        struct('class_name', 'dose',                 'class_version', '1.0.0')], ...
    'schema_version', 'V_eta');
dose.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
dose.base = struct('id', bathId, 'session_id', sessionId, ...
    'name', 'migrated_bath', 'creation_timestamp', datestamp);
dose.subject_statement = struct('variable', variable, 'storage_mode', 'inline');
dose.subject_interaction = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
dose.subject_manipulation = struct('notes', '');
dose.dose = struct('value', struct('formulation', formulation, ...
    'volume', struct('source_unit', '', 'source_value', 0.0, 'approximate', false), ...
    'route', struct('node', '', 'name', '')));

bodies = {anchorBody, dose};

% carry the bath location (otherwise dropped): a merely-located site is a
% term_observation about the subject (D3), the same disposition treatment /
% virus_injection give a site. Emitted only when the source names a location.
loc = locationTerm(v1Body);
if ~isempty(loc.node) || ~isempty(loc.name)
    bodies{end+1} = makeLocationObs(v1Body, subjectId, anchorId, loc);
end
end

function obs = makeLocationObs(v1Body, subjectId, anchorId, loc)
%MAKELOCATIONOBS A term_observation carrying the bath's location term, about the
%   bathed subject, on the same session anchor as the dose.
sessionId = baseField(v1Body, 'session_id', '');
datestamp = baseField(v1Body, 'datestamp', '');
obs = struct();
obs.document_class = struct('class_name', 'term_observation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_observation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_bath_location', 'creation_timestamp', datestamp);
obs.subject_statement = struct('variable', struct('node', '', 'name', 'anatomical location'), ...
    'storage_mode', 'inline');
obs.subject_interaction = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
obs.subject_observation = struct();
obs.term = struct('value', loc);   % value rides the `term` composite block
end

function variable = primaryChemical(mixture)
variable = struct('node', '', 'name', '');
if ~isempty(mixture) && isfield(mixture, 'chemical')
    variable = mixture(1).chemical;
end
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
mixture = struct('chemical', {}, 'amount', {});
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'mixture_table')
    raw = body.stimulus_bath.mixture_table;
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        lines = strsplit(char(raw), newline);
        for i = 1:numel(lines)
            cols = strsplit(strtrim(lines{i}), ',', 'CollapseDelimiters', false);
            if numel(cols) < 5 || isempty(strtrim(cols{1}))
                continue;
            end
            chemical = struct('node', strtrim(cols{1}), 'name', strtrim(cols{2}));
            amount = struct('source_value', str2double(cols{3}), ...
                'source_unit', strtrim(cols{5}), 'approximate', false);
            mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
        end
    end
end
if isempty(mixture)
    mixture(1) = struct( ...
        'chemical', struct('node', '', 'name', ''), ...
        'amount', struct('source_value', 0.0, 'source_unit', '', ...
            'approximate', false));
end
end

% ===================== small helpers =======================================

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
