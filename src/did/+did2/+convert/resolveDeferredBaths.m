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
%   SCOPE OF THAT LINE: V_eta is the only path. The V_zeta branch (makeBath
%   emitting `bath` + `pharmacological_manipulation`) was deleted with
%   +migrators_e/+migrators_i (did-schema #88, OPEN_WORK #128): only
%   +migrators_j.stimulus_bath defers a bath now, so no other target can
%   reach this pass with work to do.
%   `term_observation` is CONDITIONAL (makeBathVEta, only when the source names a
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
%     TargetVersion (1,:) char, default 'V_eta') - the migration target the
%                   assembled bodies are tagged with. Only 'V_eta' assembles;
%                   any other target counts each deferred bath under
%                   refused_bath_assembly_failed (none can occur: only
%                   +migrators_j defers a bath).
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
    options.TargetVersion (1,:) char = 'V_eta'
end

% A batch pass builds documents from the v1 source's own terms, exactly as a
% migrator does inside v1_to_v2, so the T19 TermRegistry check is off while it
% runs, as it is there, and restored after (unregistered terms are still
% collected when did2.build.unregisteredTerms('-collect') is on).
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
restoreTermRegistry = onCleanup(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry)); %#ok<NASGU>

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

function bodies = makeBath(v1Body, subjectId, targetVersion)
%MAKEBATH Assemble the resolved bath (+ its anchor) for TARGETVERSION. Returns a
%   cell of bodies {anchor, manipulation, ...} to fold back through v1_to_v2.
%   Strict J (V_eta) retired the `bath`/`pharmacological_manipulation` family
%   (D8): a bath is a delivered substance -> a `dose_manipulation`
%   subject_manipulation leaf, exactly as migrators_j.treatment routes a `bath`
%   keyword. The V_zeta/V_epsilon branch that kept the `bath` class was deleted
%   with did-schema #88 (OPEN_WORK #128).
if ~strcmp(targetVersion, 'V_eta')
    error('did2:convert:unsupportedTarget', ...
        ['resolveDeferredBaths assembles V_eta only; TargetVersion "%s" has ' ...
         'no bath model (V_epsilon/V_zeta were deleted, did-schema #88).'], ...
        targetVersion);
end
bodies = makeBathVEta(v1Body, subjectId);
end

function bodies = makeBathVEta(v1Body, subjectId)
% did-schema #88, built through did2.build: a "during the session" anchor (a
% relative_time_reference onto the session entity, whose base.id IS the
% session id), one `chemical` per mixture row, the `formulation` naming them
% (its ingredient entries carry each row's amount as the source wrote it), the
% `dose_manipulation` (id preserved) naming the formulation, and the location
% observation when the bath names a location.
sessionId = baseField(v1Body, 'session_id', '');
datestamp = baseField(v1Body, 'datestamp', '');
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
bathId    = baseField(v1Body, 'id', '');
mixture   = parseMixture(v1Body);
variable  = primaryChemical(mixture);
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
dose = did2.build.statement('dose_manipulation', char(subjectId), variable, [], ...
    'TimeReferenceIds', {anchorId}, 'Edges', struct('formulation_id', f.base.id), ...
    'Id', char(bathId), o{:});
bodies = [{dose}, bodies];
loc = locationTerm(v1Body);
if ~isempty(loc.node) || ~isempty(loc.name)
    bodies{end+1} = makeLocationObs(v1Body, subjectId, anchorId, loc);
end
end

function obs = makeLocationObs(v1Body, subjectId, anchorId, loc)
datestamp = baseField(v1Body, 'datestamp', '');
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
obs = did2.build.statement('term_observation', char(subjectId), ...
    did2.convert.registeredTerm('', 'anatomical location'), ...
    did2.convert.registeredTerm(loc.node, loc.name), ...
    'TimeReferenceIds', {anchorId}, ...
    'SessionId', char(baseField(v1Body, 'session_id', '')), ...
    'CreationTimestamp', char(datestamp), 'Validate', false);
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
