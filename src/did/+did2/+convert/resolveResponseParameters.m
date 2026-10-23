function [result, report] = resolveResponseParameters(result, options)
%RESOLVERESPONSEPARAMETERS Turn each stimulus-response parameters document into a shared `method`.
%
%   [RESULT, REPORT] = did2.convert.resolveResponseParameters(RESULT) takes the
%   struct returned by did2.convert.v1_to_v2 (after the sibling post-passes) and
%   performs the SECOND HALF of #61 -- the half a single-document migrator
%   cannot do. REPORT is also attached as RESULT.response_parameters_fold, so a
%   caller that ignores the second output still carries the measurement.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: stimulus_response_scalar_parameters_basic
%   BATCH-PASS-EMITS: stimulus_response_scalar_parameters_basic -> document:
%       method
%
%   `inline` IS NOT A SOFTER `document`, AND THE DISTINCTION IS THE THIRD OF
%   THE THREE EMISSION SHAPES row 107 names. The destination is the
%   `subject_interaction.method_parameters` BLOCK, written at :328 onto the
%   response document, with the `method_parameters_id` edge dropped at :329 --
%   no document is minted, and none may be, because subject_interaction.json
%   says a statement carries the inline field OR the edge, NEVER BOTH. The
%   class `method_parameters` nonetheless EXISTS in the built set
%   (schemas/V_eta/stable/method_parameters.json), which is what makes it the
%   decided target the ledger checks the emission against.
%
%   THIS PASS NOW DELETES the source documents THIS run's own edge-walk proves
%   unreferenced (team, 2026-08-21 -- the verify-before-delete, armed PER
%   DOCUMENT so nothing is deleted on the strength of the sample; see the walk
%   at the end of the file). A parameters document anything still points at is
%   KEPT. Until 2026-08-21 it deleted nothing and only MEASURED the eligible
%   count; that gate is now armed conditionally rather than pending.
%   ---------------------------------------------------------------------
%
%   STATUS: WRITTEN 2026-08-11 IN A CONTAINER WITH NO MATLAB. NOT ONE LINE OF
%   THIS FILE HAS BEEN EXECUTED. test-migrators-quick.yml is the first thing
%   with an opinion. Said here rather than in a commit message because a header
%   is what the next reader sees.
%
%   ---------------------------------------------------------------------
%   did-schema #88 AND JESS'S DECISION "b" (2026-10-21). READ THIS FIRST.
%   ---------------------------------------------------------------------
%   Decided by Jess Haley, 2026-10-21 ("b"): a v1
%   `stimulus_response_scalar_parameters_basic` becomes ONE standalone `method`
%   document per source parameters document (id PRESERVED), shared by every
%   response that used it; each response keeps `method_id` pointing at it, with
%   no inline method. So this pass NO LONGER INLINES and NO LONGER DELETES:
%     the response    a `calculation` whose value kind is `harmonic_component`;
%                     left exactly as pass 1 emitted it (edge `method_id`)
%     the parameters  each `stimulus_response_scalar_parameters_basic` is
%                     REPLACED IN PLACE by `method {term, parameters}` with the
%                     same id, so every `method_id` keeps resolving; the term
%                     is the app (`ndi.app.stimulus.tuning_response`)
%     the knobs       one `{variable, <one value form>}` entry each, the
%                     variable a label of the v1 field name (jParameterList's
%                     convention). A writer-empty `[]` knob takes the meaning
%                     NDI defines for it (Jess Haley, 2026-10-21, "c"):
%                     prestimulus_normalization -> 0, prestimulus_time -> left
%                     out; both counted in `knobs_empty_ndi_defined`. Any other
%                     empty knob is not stated and is counted in
%                     `knobs_empty_not_stated`.
%     the check       `freq_response` is still compared with the harmonic of
%                     EVERY response using the document; any disagreement
%                     leaves the parameters document unconverted
%     the counters    `methods_minted` replaces `inlined`;
%                     `parameters_documents_deleted` is 0 by construction
%   The prose below is the history of the inline design and is superseded
%   wherever it says "inline", "drop the edge" or "delete".
%
%   ---------------------------------------------------------------------
%   THE SIGNED MODEL, AND WHICH LINE OF IT THIS FILE IS
%   ---------------------------------------------------------------------
%   V_eta_stimulus_response_model_plan.md, TEAM-SIGN-OFF [stimulus response],
%   jess@walthamdatascience.com / 2026-08-08:
%
%       stimulus_response_scalar_parameters_basic  FOLD -> method_parameters
%                                                  (inline); id dropped
%
%   and that document's BUILD section, verbatim: *"One migrator plus one
%   resolver pass. A single-document migrator cannot inline the parameters -- it
%   cannot follow `stimulus_response_scalar_parameters_id` -- but the mechanism
%   exists: `did2.convert.resolveDeferredBaths` resolves deferred documents
%   against the migrated batch with no live session. Same shape here."*
%
%   The migrator half is +migrators_j/stimulus_response_scalar.m, which re-homes
%   the v1 edge onto `subject_interaction.method_parameters_id` and leaves the
%   inline field empty. THIS pass reads the referenced document out of the
%   migrated batch, writes the five run knobs INLINE, and REMOVES the edge --
%   because subject_interaction.json says, in the schema's own words, "A
%   statement carries the inline `method_parameters` field OR this edge, NEVER
%   BOTH (team, 2026-08-09)".
%
%   ---------------------------------------------------------------------
%   THE VERIFY-BEFORE-DELETE, NOW ARMED PER DOCUMENT (team, 2026-08-21).
%   ---------------------------------------------------------------------
%   The plan requires a corpus verify-before-delete before the parameters
%   documents may go, the same gate the ensemble fold got. (11,440 of them, and
%   10,124 responses, across five corpora -- test-code.yml run #257 / 0458dae,
%   2026-07-29, quoted from the plan's own corpus table. Those figures are a
%   SAMPLE and a year-old one; this pass reports what it actually saw and every
%   number below comes from the batch in hand, never from that table.) The team
%   armed the delete PER DOCUMENT: rather than a global flip once "our corpora
%   read 0 referenced" -- which would trust the sample -- this pass deletes ONLY
%   the `stimulus_response_scalar_parameters_basic` documents THIS run's own edge
%   walk proves unreferenced, and KEEPS any a real document still points at. A
%   dataset that references one is self-protecting: its edge lands in
%   `referenced` and the source stays. So the numbers it needs are still
%   measured, and now acted on for the eligible subset:
%
%       parameters_documents_seen              the denominator
%       parameters_documents_referenced_after  still pointed at -> KEPT
%       parameters_documents_unreferenced_after  eligible
%       parameters_documents_deleted           actually removed this run
%
%   `unreferenced_after` is computed by walking EVERY edge of EVERY migrated
%   document -- not by assuming this pass removed the only referent -- so the
%   deletion rests on a per-document measurement, never on the sample.
%
%   ---------------------------------------------------------------------
%   THE FIVE FIELDS, AND WHY `freq_response` IS NOT ONE OF THEM
%   ---------------------------------------------------------------------
%   The plan's mapping splits the source document's six fields two ways:
%
%       temporalfreqfunc, prestimulus_time, prestimulus_normalization,
%       isspike, spiketrain_dt          -> method_parameters (inline)
%       response_type + freq_response   -> value.harmonic
%
%   `freq_response` is the harmonic NUMBER, and the migrator has already put it
%   on `harmonic_component.value.harmonic` (via `response_type`, which the
%   writer derives from it two lines earlier -- tuning_response.m:262-266).
%   Copying it into `method_parameters` as well would store one fact in two
%   places, which is the drift surface the plan's own OPEN 3 records against
%   `tuning_curve`. So it is NOT copied -- and it is not ignored either: it is
%   CHECKED against the leaf's harmonic, and a disagreement REFUSES the inline
%   rather than picking a winner. A disagreement would mean the writer-derived
%   identity this whole fold rests on has broken somewhere, and the honest
%   response to that is to stop, not to guess.
%
%   EMPTY VALUES ARE COPIED, NOT SKIPPED. `prestimulus_time` and
%   `prestimulus_normalization` are `[]` at the writer (tuning_response.m:174-175)
%   on every document ever written, and the plan's own worked example shows them
%   inlined as `[]`. Dropping them would make "the writer's default was in
%   force" and "nobody recorded this" the same shape -- and the second is a
%   claim the source never made.
%
%   ---------------------------------------------------------------------
%   WHAT IT REFUSES, AND WHY EACH REFUSAL IS COUNTED RATHER THAN SILENT
%   ---------------------------------------------------------------------
%     no `method_parameters_id` on the leaf   -> leaves_without_edge (not a
%                                                refusal: a leaf whose source
%                                                had no parameters edge is
%                                                complete as it stands)
%     the referenced document is not in batch -> refused_not_in_batch
%     two documents claim that id             -> refused_ambiguous
%     it is there but of the wrong class      -> refused_wrong_class
%     it carries none of the five fields      -> refused_no_fields
%     the leaf already has inline parameters  -> refused_inline_present
%     freq_response ~= value.harmonic         -> refused_harmonic_mismatch
%
%   A refused leaf is LEFT EXACTLY AS PASS 1 EMITTED IT -- edge intact, document
%   intact. Refusing costs nothing: the edge still resolves, and the state the
%   corpus is green in today is the state a refusal preserves.
%
%   ---------------------------------------------------------------------
%   WHY `leaves_seen` IS EXPECTED TO BE 0 ON EVERY CORPUS TODAY
%   ---------------------------------------------------------------------
%   AND WHY THAT MUST NOT READ AS "NOTHING TO DO". +migrators_j/
%   stimulus_response_scalar.m carries an EPOCH GATE: when the v1 body has an
%   `element_epochid` string but `jEpochDocId` answers '' -- which it does for
%   every did_v1 document by construction, and the writer sets that string
%   unconditionally -- the fold is SUPPRESSED and the document passes through
%   whole. So pass 1 emits no harmonic_component calculation on real corpora
%   until #60 stamps the `epoch_id` edge.
%
%   A pass whose every counter is 0 is exactly the shape this project keeps
%   getting burned by, so the report separates the two readings itself:
%
%       leaves_seen                     0   nothing to inline
%       suppressed_responses_seen       N   ...because THIS many v1 responses
%                                           are still passing through unfolded
%
%   (N is whatever the batch holds. The plan's table put it at 10,124 over five
%   corpora in 2026-07, which is an illustration of the SHAPE, not a prediction
%   of any run's output.)
%
%   `suppressed_responses_seen` counts surviving `stimulus_response_scalar`
%   documents in the batch. Zero leaves beside a non-zero suppression count is
%   "blocked upstream"; zero beside zero is "this corpus has no responses"; and
%   a non-zero `leaves_seen` with `inlined` at 0 is a real defect in this file.
%   Those three used to be one number.
%
%   ---------------------------------------------------------------------
%   ITS EFFECT ON THE 0-QUARANTINE GATE, STATED RATHER THAN DISCOVERED
%   ---------------------------------------------------------------------
%   TODAY: NONE, and for a reason that is structural rather than lucky. With no
%   leaf in the batch `changedIdx` is empty, the re-validation block never runs,
%   and not one document is touched -- so wiring this pass into the corpus
%   harnesses cannot move a corpus that is currently green at 0 quarantined.
%
%   ONCE #60 OPENS THE GATE: a rebuilt body that fails validation is appended to
%   `quarantine` WHILE THE ORIGINAL STAYS IN `migrated` -- identical to
%   did2.convert.resolveSessionAnchors, deliberately. Nothing is lost, and the
%   0-quarantine gate goes RED. That is the intended behaviour and not a
%   regression to route around: an inline that the schema rejects is a defect in
%   this file, and `fold_quarantined` names it in the report so the cause is not
%   a mystery. The alternative -- swallow it and leave the document unfolded --
%   is a pass that quietly does nothing, which is the defect this project keeps
%   paying for.
%
%   Options (name-value), mirroring the sibling passes:
%     Validate       (1,1 logical, default true)  validate the changed bodies
%     SchemaCache    ([] or a did2.schema.cache)  override the shared cache
%     TargetVersion  (1,:) char, default 'V_eta'  no-op on other targets
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveSessionAnchors,
%   did2.convert.epochMint, did2.convert.resolveDeferredBaths,
%   did2.convert.migrators_j.stimulus_response_scalar,
%   did2.convert.migrators_j.stimulus_response_scalar_parameters_basic.

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

% DENOMINATOR FIRST, and unconditionally. Every field is defined before a single
% document is read, so "did not run" (ran == false, every counter 0) and "ran
% and found nothing" (ran == true, every counter 0) are different readings of
% the same struct rather than the same reading. Operating Rule 5.
report = struct( ...
    'documents_inspected',                     0, ...
    'documents_unreadable',                    0, ...
    'leaves_seen',                             0, ...
    'leaves_with_edge',                        0, ...
    'leaves_without_edge',                     0, ...
    'suppressed_responses_seen',               0, ...
    'parameters_documents_seen',               0, ...
    'leaves_already_on_method',                0, ...
    'methods_minted',                          0, ...
    'fields_copied',                           0, ...
    'knobs_empty_not_stated',                  0, ...
    'knobs_empty_ndi_defined',                 0, ...
    'harmonic_checked',                        0, ...
    'harmonic_uncheckable',                    0, ...
    'refused_not_in_batch',                    0, ...
    'refused_ambiguous',                       0, ...
    'refused_wrong_class',                     0, ...
    'refused_no_fields',                       0, ...
    'refused_inline_present',                  0, ...
    'refused_harmonic_mismatch',               0, ...
    'refused_total',                           0, ...
    'fold_quarantined',                        0, ...
    'parameters_documents_referenced_after',   0, ...
    'parameters_documents_unreferenced_after', 0, ...
    'parameters_documents_deleted',            0, ...   % never: converted in place
    'ran',                                     false);
result.response_parameters_fold = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % the harmonic_component value kind exists only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.response_parameters_fold = report;
    return;
end
report.ran = true;

DIRECTION  = 'calculation';            % did-schema #88: direction class ...
VALUE_KIND = 'harmonic_component';     % ... plus this value-kind mixin
METHOD_TERM = 'ndi.app.stimulus.tuning_response';   % as the migrator names it
METHOD = 'method';
PARAMS = 'stimulus_response_scalar_parameters_basic';
SOURCE = 'stimulus_response_scalar';
% The five run knobs, in the plan's own order. `freq_response` is deliberately
% absent -- see the header.
KNOBS = {'temporalfreqfunc', 'prestimulus_time', 'prestimulus_normalization', ...
    'isspike', 'spiketrain_dt'};

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ---------------------------------------------
% A document this cannot read is COUNTED, never dropped.
bodies    = cell(1, n);
classes   = repmat({''}, 1, n);
isLeaf    = false(1, n);
docIds    = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k}  = b;
        classes{k} = classNameOf(b);
        % did2.convert.statementKind: the #88 direction + mixin (it also reads
        % a pre-port document's joined class name that way)
        [leafDir, leafKind] = did2.convert.statementKind(b);
        isLeaf(k)  = strcmp(leafDir, DIRECTION) && strcmp(leafKind, VALUE_KIND);
        docIds{k}  = baseField(b, 'id');
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- index the batch by base.id, with a COUNT so a duplicate is refused ------
byId    = containers.Map('KeyType', 'char', 'ValueType', 'double');
idCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    % CLASS COUNTING FIRST, and NOT under the id guard below. An earlier draft
    % had both inside one `if ~isempty(id)`, so a document with no readable
    % `base.id` would have been missing from `parameters_documents_seen` --
    % silently shrinking the denominator of the verify-before-delete gate, which
    % is the one number here that a deletion would be justified by.
    if strcmp(classes{k}, PARAMS)
        report.parameters_documents_seen = report.parameters_documents_seen + 1;
    elseif strcmp(classes{k}, SOURCE)
        % A v1 response that pass 1 did NOT fold -- the epoch gate. See header.
        report.suppressed_responses_seen = report.suppressed_responses_seen + 1;
    end
    id = docIds{k};
    if isempty(id); continue; end
    if isKey(idCount, id)
        idCount(id) = idCount(id) + 1;
    else
        idCount(id) = 1;
        byId(id) = k;
    end
end

% --- which responses point at which parameters document --------------------
% The responses are NOT changed by this pass (Jess Haley, 2026-10-21, "b"):
% each keeps its `method_id`, no inline method. This walk only finds, per
% parameters document, the responses that use it -- for the harmonic check.
refsTo = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:n
    if ~isLeaf(k); continue; end
    report.leaves_seen = report.leaves_seen + 1;
    b = bodies{k};
    paramId = depValue(b, 'method_id');
    if isempty(paramId)
        report.leaves_without_edge = report.leaves_without_edge + 1;
        continue;
    end
    report.leaves_with_edge = report.leaves_with_edge + 1;
    if ~isKey(byId, paramId)
        report.refused_not_in_batch = report.refused_not_in_batch + 1;
        continue;
    end
    if idCount(paramId) > 1
        report.refused_ambiguous = report.refused_ambiguous + 1;
        continue;
    end
    cls = classes{byId(paramId)};
    if strcmp(cls, METHOD)
        % already a method document (a re-run): nothing to do for this edge
        report.leaves_already_on_method = report.leaves_already_on_method + 1;
        continue;
    end
    if ~strcmp(cls, PARAMS)
        report.refused_wrong_class = report.refused_wrong_class + 1;
        continue;
    end
    if isKey(refsTo, paramId)
        refsTo(paramId) = [refsTo(paramId), k];
    else
        refsTo(paramId) = k;
    end
end

% --- one `method` document per parameters document, id PRESERVED ------------
changedIdx = [];
rebuilt = {};
% Per-changed-body counts, banked and only ADDED TO THE REPORT once the body
% has actually landed in `migrated` -- a counter measuring outcome, not intent.
copiedPer = [];
emptyPer = [];
definedPer = [];
for k = 1:n
    if ~strcmp(classes{k}, PARAMS); continue; end
    pid = docIds{k};
    pBlk = blockOf(bodies{k}, PARAMS);
    users = [];
    if ~isempty(pid) && isKey(refsTo, pid); users = refsTo(pid); end

    % NEVER BOTH. A response carrying an inline method BESIDE the edge already
    % breaks the schema's rule; which of the two is authoritative is not this
    % pass's call, so the parameters document is left as it is.
    inlineSeen = false;
    for u = users
        m = blockField(bodies{u}, 'interaction', 'method');
        if isstruct(m) && ~isempty(m) && ~isempty(fieldnames(m))
            inlineSeen = true;
        end
    end
    if inlineSeen
        report.refused_inline_present = report.refused_inline_present + 1;
        continue;
    end

    % freq_response vs every user's value.harmonic. Checked, never copied: the
    % writer dedups parameters documents by freq_response, so every response
    % sharing one must agree with it.
    mismatch = false;
    for u = users
        [verdict, checked] = harmonicAgrees(bodies{u}, pBlk);
        if checked
            report.harmonic_checked = report.harmonic_checked + 1;
        else
            report.harmonic_uncheckable = report.harmonic_uncheckable + 1;
        end
        if ~verdict; mismatch = true; end
    end
    if mismatch
        report.refused_harmonic_mismatch = report.refused_harmonic_mismatch + 1;
        continue;
    end

    [params, copied, emptied, defined] = knobsOf(pBlk, KNOBS);
    if copied == 0
        % A method with no settings records nothing the source said.
        report.refused_no_fields = report.refused_no_fields + 1;
        continue;
    end

    sid = depValue(bodies{k}, 'session_id');
    if isempty(sid); sid = baseField(bodies{k}, 'session_id'); end
    ts = baseField(bodies{k}, 'creation_timestamp');
    if isempty(ts); ts = baseField(bodies{k}, 'datestamp'); end
    mdoc = did2.build.method(did2.convert.registeredTerm('', METHOD_TERM), params, ...
        'SessionId', sid, 'Id', pid, 'CreationTimestamp', ts, 'Validate', false);

    rebuilt{end+1} = mdoc;       %#ok<AGROW>
    changedIdx(end+1) = k;       %#ok<AGROW>
    copiedPer(end+1) = copied;   %#ok<AGROW>
    emptyPer(end+1) = emptied;   %#ok<AGROW>
    definedPer(end+1) = defined; %#ok<AGROW>
end

report.refused_total = report.refused_not_in_batch ...
    + report.refused_ambiguous ...
    + report.refused_wrong_class ...
    + report.refused_no_fields ...
    + report.refused_inline_present ...
    + report.refused_harmonic_mismatch;

if ~isempty(changedIdx)
    % --- validate through the same door every other pass uses --------------
    % A body that cannot validate lands in `quarantine` and the ORIGINAL
    % parameters document is kept, so a bad conversion degrades to "not
    % converted" rather than to a lost document.
    out = did2.convert.v1_to_v2(rebuilt, ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', options.TargetVersion);

    report.fold_quarantined = numel(out.quarantine);
    if ~isempty(out.quarantine)
        if isfield(result, 'quarantine') && ~isempty(result.quarantine)
            result.quarantine = [result.quarantine, out.quarantine];
        else
            result.quarantine = out.quarantine;
        end
    end

    % Match on base.id (preserved), not on position.
    producedById = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for j = 1:numel(out.migrated)
        try
            producedById(char(out.migrated{j}.get('base.id'))) = j;
        catch
        end
    end
    for j = 1:numel(changedIdx)
        id = docIds{changedIdx(j)};
        if ~isempty(id) && isKey(producedById, id)
            docs{changedIdx(j)} = out.migrated{producedById(id)};
            report.methods_minted = report.methods_minted + 1;
            report.fields_copied = report.fields_copied + copiedPer(j);
            report.knobs_empty_not_stated = ...
                report.knobs_empty_not_stated + emptyPer(j);
            report.knobs_empty_ndi_defined = ...
                report.knobs_empty_ndi_defined + definedPer(j);
        end
    end

    result.migrated = docs;
    result.summary = recountSummary(result);
end

% --- who still points at each parameters document --------------------------
% Measured over every edge of every document, not inferred. Every parameters
% document is CONVERTED IN PLACE (id preserved), never deleted, so these are
% evidence about sharing, not a deletion gate: `referenced_after` counts the
% parameters documents some response (or anything else) uses.
referenced = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:n
    b = bodies{k};
    if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
        continue;
    end
    deps = b.depends_on;
    for d = 1:numel(deps)
        v = depEntryValue(deps(d));
        if ~isempty(v); referenced(v) = true; end
    end
end
for k = 1:n
    if ~strcmp(classes{k}, PARAMS); continue; end
    if ~isempty(docIds{k}) && isKey(referenced, docIds{k})
        report.parameters_documents_referenced_after = ...
            report.parameters_documents_referenced_after + 1;
    else
        report.parameters_documents_unreferenced_after = ...
            report.parameters_documents_unreferenced_after + 1;
    end
end

result.response_parameters_fold = report;
end

% ===================== the two comparisons =================================

function [agrees, checked] = harmonicAgrees(leafBody, pBlk)
%HARMONICAGREES Does the parameters document's `freq_response` match the leaf's
%   `harmonic_component.value.harmonic` (the value-kind block on #88)?
%
%   AGREES is true when they match OR when the comparison cannot be made;
%   CHECKED says which of those two it was, so "verified equal" and "could not
%   look" are separate numbers in the report instead of one reassuring one.
%   Returning true for uncheckable is deliberate: absence of `freq_response` is
%   not evidence of a mismatch, and refusing on it would strand documents for a
%   field the fold does not need.
agrees = true;
checked = false;
fr = numField(pBlk, {'freq_response', 'freqResponse'});
if isempty(fr) || ~isnumeric(fr) || ~isscalar(fr)
    return;
end
h = [];
if isfield(leafBody, 'harmonic_component') && isstruct(leafBody.harmonic_component) ...
        && isfield(leafBody.harmonic_component, 'value') ...
        && isstruct(leafBody.harmonic_component.value) ...
        && isfield(leafBody.harmonic_component.value, 'harmonic')
    h = leafBody.harmonic_component.value.harmonic;
end
if isempty(h) || ~isnumeric(h) || ~isscalar(h)
    return;
end
checked = true;
agrees = (double(fr) == double(h));
end

function [params, copied, emptied, defined] = knobsOf(pBlk, knobs)
%KNOBSOF The run knobs as did-schema #88 `method.parameters` entries, in the
%   plan's order. Snake + camelCase fallback per the standing migrator lesson.
%   An ABSENT knob is skipped. A PRESENT-but-EMPTY one cannot be an entry (#88:
%   exactly one value form) and is counted in EMPTIED rather than copied (see
%   the #88 note in the header). A numeric/logical scalar is a `quantity`
%   (value, and the source as text); a char is `text`; anything else is
%   `text`, JSON-encoded -- the jParameterList convention.
%
%   EMPTY SETTINGS WITH A MEANING NDI DEFINES (Decided by Jess Haley,
%   2026-10-21, [empty response settings] "c"). The writer documents what `[]`
%   means for two knobs (NDI origin/main +ndi/+app/+stimulus/tuning_response.m,
%   the parameter table above `temporalfreqfunc = ...`):
%     prestimulus_normalization  "[] or 0) No normalization"  -> written as 0
%     prestimulus_time           [] = no baseline period      -> LEFT OUT
%   Both are counted in DEFINED, not EMPTIED. The 0 carries no source_value:
%   the source wrote no number. Never NaN. Any OTHER empty knob has no defined
%   meaning, is not stated, and is counted in EMPTIED.
%   NOT named `inline`: that was a MATLAB function name for two decades.
params = [];
copied = 0;
emptied = 0;
defined = 0;
entries = {};
for k = 1:numel(knobs)
    name = knobs{k};
    camel = toCamel(name);
    if isfield(pBlk, name)
        v = pBlk.(name);
    elseif isfield(pBlk, camel)
        v = pBlk.(camel);
    else
        continue;
    end
    var = did2.convert.registeredTerm('', strrep(name, '_', ' '));
    if isempty(v)
        switch name
            case 'prestimulus_normalization'
                entries{end+1} = did2.build.parameter(var, 'Value', 0); %#ok<AGROW>
                copied = copied + 1;
                defined = defined + 1;
            case 'prestimulus_time'
                defined = defined + 1;      % no baseline period: left out
            otherwise
                emptied = emptied + 1;
        end
        continue;
    end
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        e = did2.build.parameter(var, 'Value', double(v), ...
            'SourceValue', shortestText(double(v)));
    elseif ischar(v) && isrow(v)
        e = did2.build.parameter(var, 'Text', v);
    elseif isstring(v) && isscalar(v)
        e = did2.build.parameter(var, 'Text', char(v));
    else
        e = did2.build.parameter(var, 'Text', char(jsonencode(v)));
    end
    entries{end+1} = e; %#ok<AGROW>
    copied = copied + 1;
end
if ~isempty(entries)
    params = did2.build.list(entries{:});
end
end

function t = shortestText(x)
% The shortest decimal text that reads back as exactly X (jParameterList's).
for p = 1:17
    t = sprintf('%.*g', p, x);
    if str2double(t) == x
        return;
    end
end
end

function out = toCamel(name)
%TOCAMEL 'prestimulus_time' -> 'prestimulusTime'. No regexp: this is called once
%   per knob per document, and strsplit has no dialect.
parts = strsplit(name, '_');
out = parts{1};
for k = 2:numel(parts)
    p = parts{k};
    if isempty(p); continue; end
    p(1) = upper(p(1));
    out = [out p]; %#ok<AGROW>
end
end

% ===================== readers =========================================

function cn = classNameOf(b)
cn = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function v = baseField(b, name)
v = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, name)
    x = b.base.(name);
    if ischar(x) || isstring(x); v = char(x); end
end
end

function blk = blockOf(b, className)
blk = struct();
if isstruct(b) && isfield(b, className) && isstruct(b.(className)) ...
        && isscalar(b.(className))
    blk = b.(className);
end
end

function v = blockField(b, className, fieldName)
v = [];
blk = blockOf(b, className);
if isfield(blk, fieldName); v = blk.(fieldName); end
end

function v = numField(blk, names)
v = [];
for k = 1:numel(names)
    if isstruct(blk) && isfield(blk, names{k})
        v = blk.(names{k});
        return;
    end
end
end

function v = depEntryValue(d)
%DEPENTRYVALUE One edge's target id, under any of the three live spellings.
%   Precedence copied from +did2/+validate/references.m: a body a migrator built
%   spells it `value`, a body through universalRenames spells it `document_id`.
v = '';
if ~isstruct(d); return; end
for key = {'document_id', 'value', 'id'}
    f = key{1};
    if isfield(d, f) && ~isempty(d.(f)) && (ischar(d.(f)) || isstring(d.(f)))
        v = char(d.(f));
        return;
    end
end
end

function v = depValue(b, name)
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
deps = b.depends_on;
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
        v = depEntryValue(deps(k));
        return;
    end
end
end

function deps = dropDep(deps, name)
%DROPDEP Remove one edge from a depends_on struct array.
%   Indexed deletion rather than rebuilding by concatenation: a struct array
%   whose entries carry different field sets (`value` on some, `document_id` on
%   others) cannot be concatenated element-by-element, and this pass runs on
%   bodies from both stages of the pipeline.
if ~isstruct(deps) || isempty(deps); return; end
keep = true(1, numel(deps));
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
        keep(k) = false;
    end
end
deps = deps(keep);
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
