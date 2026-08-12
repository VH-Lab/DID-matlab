function [result, report] = foldGenericFiles(result, options)
%FOLDGENERICFILES Fold did_v1 `generic_file` into a statement + an `opaque_body`.
%
%   [RESULT, REPORT] = did2.convert.foldGenericFiles(RESULT) takes the struct
%   did2.convert.v1_to_v2 returns (after the sibling post-passes) and rewrites
%   every `generic_file` document it can fold HONESTLY into
%
%       term_observation   the statement -- `subject_id` from the source's
%                          `document_id`, `variable` from the SIBLING
%                          ontologyLabel's `ontologyNode`, storage_mode 'body'.
%                          ITS base.id IS THE SOURCE'S base.id, unchanged.
%       opaque_body        the bytes -- format from `format_ontology`,
%                          filename from `filename`, content_hash from
%                          `checksum`, `statement` -> the observation, and the
%                          attached file carried over verbatim. Fresh id.
%
%   1 -> 2. A document it cannot fold is LEFT EXACTLY AS IT IS, counted under
%   the reason it was refused.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set --
%   the grammar is in the parser's docstring.
%
%   BATCH-PASS-CONSUMES: generic_file, ontology_label
%   BATCH-PASS-EMITS: generic_file -> document: term_observation, opaque_body
%   BATCH-PASS-EMITS: ontology_label -> nothing: read at :332-341 for the
%       sibling label's `ontologyNode`, which becomes the observation's
%       `variable`. The label document itself is left exactly where it is.
%   ---------------------------------------------------------------------
%
%   ---------------------------------------------------------------------
%   STATUS: WRITTEN 2026-08-11 in a container with NO MATLAB AND NO OCTAVE
%   (`command -v matlab octave octave-cli` -> nothing, exit 1), so nothing here
%   was ever run by its author. CI IS THE ONLY THING THAT HAS EXECUTED IT.
%   First execution, fixture run 31496802183 / job 93796494861, printed by the
%   fold itself:
%
%       --- generic_file fold: 181 inspected, 2 generic_file(s),
%           2 label(s) of which 1 point at a file ---
%         folded 1   refused 1 (no label 1 / ambiguous 0 / node empty 0 /
%         no document_id 0 / referent absent 0)   quarantined 0
%         dates dropped 1
%
%   That run went RED, on this file, for one reason -- `containers.Map.Count`
%   is a uint64 and this report's counters are doubles (fixed below, at the
%   source). Every other assertion in testFixtureCorpus GATE 4 passed on that
%   same run, along with GATE 1 (0 quarantine) and GATE 2 (0 orphans).
%
%   WHAT IS STILL UNEXECUTED ANYWHERE: the four refusal arms other than
%   `no label`, and the quarantine-degradation path. They are reachable only
%   from shapes the fixture does not contain, and no corpus contains a
%   `generic_file` at all.
%   ---------------------------------------------------------------------
%
%   THE DECISION THIS BUILDS. Team, 2026-08-11, verbatim (recorded in
%   did-schema/schemas/V_eta_OPEN_WORK.md, "generic_file folds to opaque_body +
%   a subject_statement"): *"opaque_body + a subject_statement whose variable
%   comes from that sibling label -- 'subject S has a plasmid map, here are the
%   bytes.' Is the correct way"*. Option (b) -- bytes hung directly off the
%   subject with `format_ontology` as its own descriptor -- is REJECTED.
%
%   ---------------------------------------------------------------------
%   THE JOIN, RE-DERIVED FROM THE WRITER (not taken from the decision note)
%   ---------------------------------------------------------------------
%   NDI origin/main `42c94e53b`, +ndi/+setup/+conv/+babu/import.m. Two
%   construction sites, plasmid (:526-537) and LC-MS (:575-586):
%
%       generic_file = struct('filename',<f>,'formatOntology',<CURIE>, ...
%           'checksum',checksum,'dateCreated',<datenum>,'dateUpdated',<datenum>);
%       doc = ndi.document('generic_file','generic_file',generic_file) + ...
%       doc = doc.add_file('generic_file.ext',lcmsFile,'delete_original',0);
%       doc = doc.set_dependency_value('document_id', <the subject-ish id>);
%       label = ndi.document('ontologyLabel','ontologyLabel', ...
%           struct('ontologyNode','EDAM:data_1286')) + session.newdocument;
%       label = label.set_dependency_value('document_id', doc.id);
%
%   So the chain runs LABEL -> FILE -> SUBJECT, and the label points DOWN at
%   the file, not the other way round:
%
%       ontologyLabel --document_id--> generic_file --document_id--> <subject>
%         ontologyNode  = WHAT the data is   -> `variable`
%                         formatOntology = HOW it is encoded -> `format`
%
%       plasmid   EDAM:data_1286   EMPTY:0000253
%       LC-MS     EDAM:data_2536   EDAM:format_3620
%
%   ONE CORRECTION TO THE JOIN AS IT WAS HANDED TO ME. It was written as
%   `generic_file --document_id--> subject_group`. That is the PLASMID branch
%   only. The LC-MS branch sets `document_id` from
%   `lcmsTable.SubjectDocumentIdentifier{i}`, which import.m:550 fills from
%   `subjectTable.SubjectDocumentIdentifier` -- a SUBJECT document id -- and
%   only the single 'All_set' row is overwritten with `subject_group_lcms.id`
%   at :562. So the referent is a subject OR a subject_group depending on the
%   branch and the row. This pass therefore does NOT check the referent's
%   class; it checks only that the id RESOLVES inside the batch. The V_eta
%   tombstone already reasoned this out and types the edge `subject`, because
%   migrators_j.subject_group folds 1->1 carrying the v1 `base` block, so a
%   subject_group id is a subject id after migration.
%
%   ---------------------------------------------------------------------
%   WHY A BATCH PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   The `variable` lives in a DIFFERENT DOCUMENT. No per-document migrator can
%   reach the sibling ontologyLabel, so `migrators_j.generic_file` could only
%   ever emit a statement with a guessed or blank `variable` -- and
%   `subject_statement.variable` is mustBeNonEmpty, so a blank one quarantines.
%   Everything the fold needs (the file, its label, the referent) is already in
%   the migrated batch and none of it needs a session, a database or the file
%   BYTES, which is the standing criterion that put `epochMint` and
%   `resolveSessionAnchors` DID-side rather than in the NDI second pass.
%
%   THE FILE BYTES ARE NEVER READ. Only the declaration is carried: the `files`
%   block moves to the body untouched.
%
%   ---------------------------------------------------------------------
%   THE ID IS PRESERVED, AND WHY THAT IS BOTH SAFE AND NECESSARY
%   ---------------------------------------------------------------------
%   The statement takes the source `generic_file`'s `base.id`; only the
%   opaque_body gets a fresh one. Re-verified rather than repeated:
%
%       $ cd NDI-matlab && git grep -c "generic_file_id" origin/main
%       (no output -- 0 files of 91 templates / 1467 files)
%       $ cd DID-matlab && grep -rn "generic_file_id" src/ tests/
%       (no output -- 0 migrator references)
%
%   Nothing joins to this class by id, so a decompose cannot strand a referent.
%   That LICENSES the decompose; it does not licence carelessness -- a
%   dissolution that changed ids produced 11,448 orphans in Soph. Preserving is
%   also NECESSARY here and not merely tidy: the sibling ontologyLabel's
%   `document_id` points AT the generic_file, and that edge is the only join
%   the label has. Preserve the id and the label keeps resolving, at the
%   statement, with no second document to rewrite.
%
%   ---------------------------------------------------------------------
%   THE LABEL IS **NOT** CONSUMED. IT IS LEFT PASSING THROUGH.
%   ---------------------------------------------------------------------
%   This pass MUTATES NO ontology_label DOCUMENT AT ALL -- not the ones it
%   reads, and by construction not the ones it does not. `report.labels_deleted`
%   and `report.labels_modified` are reported every run and are 0 by
%   construction, so the claim is readable from the log instead of trusted.
%   Four reasons, in the order they mattered:
%
%     1. SIZE. `ontology_label` is a `retire` guarded passthrough of ~7,007
%        documents, the overwhelming majority of which label things that have
%        nothing to do with `generic_file` (10 of 10 writer sites call
%        `set_dependency_value('document_id',...)`; only 2 of them label a
%        generic_file -- babu/import.m:534 and :583, against 8 haley/doImport.m
%        sites labelling image stacks). A pass that consumed the ones it read
%        would make one class behave two ways depending on what its sibling
%        happens to be, and would do it to a class ten times the size of the
%        one being built.
%     2. READING IS NOT CONSUMING. The label document is the RECORD of the
%        labelling act; the statement's `variable` is a PROJECTION of it. If
%        the leaf-class question below is ever answered differently, the
%        `variable` has to be re-derived -- and it can be, because the label is
%        still there pointing at the same id.
%     3. THE EDGE STILL RESOLVES. Because the statement keeps the source id,
%        `ontology_label.document_id` needs no rewrite. Deleting the label
%        would instead take `orphan_count` DOWN while losing a fact, which is
%        the one direction the gates cannot see (testFixtureCorpus GATE 3
%        exists for exactly this and asserts on this very edge).
%     4. IT IS NOT THIS PASS'S DECISION TO MAKE. `ontology_label`'s own
%        disposition is deferred to the NDI second pass; retiring 7,007
%        documents as a side effect of a 2-site fold would be that decision
%        taken sideways.
%
%   The duplication that leaves is bounded and explainable: the label says
%   "document X is EDAM:data_1286", the statement says "subject S has
%   EDAM:data_1286 data, bytes here". Both remain true; neither is derived from
%   a guess.
%
%   ---------------------------------------------------------------------
%   THE LEAF CLASS IS THE ONE THING THIS BUILD HAD TO CHOOSE, SO IT IS STATED
%   ---------------------------------------------------------------------
%   The team said `subject_statement`. `subject_statement` is ABSTRACT --
%   `did2:validation:abstractInstantiation`, +did2/+schema/cache.m:670-674 --
%   and every concrete statement in V_eta is direction x data_type (T3), so a
%   `data_type` composite has to be named. NO `data_type` composite carries an
%   uninterpreted payload: of the 40 composites, every one either REQUIRES a
%   typed `value` (term, image, date, tuning_curve, ...) or names a physical
%   quantity the bytes of a plasmid map do not have.
%
%   CHOSEN: `term_observation` (subject_observation + term), with
%   `subject_statement.variable` = the label's node, verbatim per the team, and
%   `term.value` = THE SAME NODE. That restatement is the cost, and it is
%   deliberate: `term.value` is mustBeNonEmpty, the label's node is the only
%   term this document carries, and a statement whose value slot repeats its
%   variable is REDUNDANT but TRUE. The alternatives were worse:
%
%     * an empty `term.value` -> mustBeNonEmpty -> every Babu document
%       QUARANTINES. The gate would stay green (0 generic_file in all six
%       corpora) while the data it exists for was rejected.
%     * `count_observation` with an empty `count` block, which is what
%       migrators_j.private.jSorterOutput does for an opaque sorter directory.
%       It validates (`count.value` is optional) and the class name is FALSE:
%       a plasmid map is not a count of anything. A false class name survives
%       every gate we have.
%     * minting a `data_type` for "uninterpreted bytes". That is a MODEL call
%       (Rule 4, and T12's mint-of-last-resort test), and T13 has already
%       killed one container-named composite for this exact reason -- `array`
%       was removed because a bare payload container duplicates the body tier.
%       Proposing it is in scope; deciding it is not.
%
%   So: when a composite for an opaque payload exists, `term.value` drops and
%   the class name changes. Because the id is preserved, that is a class
%   rename, not a re-identification -- nothing downstream has to be found again.
%
%   ---------------------------------------------------------------------
%   WHAT THE FOLD LOSES, SAID PLAINLY
%   ---------------------------------------------------------------------
%   `date_created` and `date_updated` (MATLAB datenums, the source file's
%   filesystem timestamps) have NO home. The SIGNED data_body model
%   (did-schema/schemas/V_eta_data_body_model_plan.md, section 6) lists
%   format / compression / filename / content_hash / description and the
%   statement edge -- and no dates. They survive only on a REFUSED document.
%
%   This CONTRADICTS the team note's "THE ONE REMAINING BLOCKER IS ONE FIELD",
%   which named only `checksum`; the older build_v_eta.py comment had it right
%   ("no content_hash ... and no created/updated dates"). Two fields were
%   missing, not one. `checksum` is fixed -- opaque_body now declares
%   `content_hash` and this pass carries the MD5 into it. The dates are NOT,
%   and inventing a slot for them (stuffing them into `description`, or
%   re-purposing `base.datestamp`, which means when the DOCUMENT was made) is
%   the kind of convention that lives in a migrator and nowhere else.
%   `report.date_fields_dropped` counts them every run so the loss has a
%   number beside it instead of a sentence in a header.
%
%   ---------------------------------------------------------------------
%   ONE MORE DIVERGENCE, REPORTED NOT REPAIRED
%   ---------------------------------------------------------------------
%   `opaque_body` declares its file slot `body_data`; the carried block names
%   `generic_file.ext`. The files block is moved VERBATIM, because the slot
%   name is how the stored bytes are found and renaming it in the manifest
%   without renaming the blob would lose them. `did2.validate.fileList` will
%   therefore report `opaque_body|body_data` declared-but-absent and
%   `opaque_body|generic_file.ext` present-but-undeclared. That audit is
%   REPORT-ONLY and non-gating, and the same divergence already exists on
%   migrators_j/image_stack.m:356 (source slot `imageStack` -> sampled_body).
%   It is one question -- what a body's file slot is called after a fold --
%   and it is not this fold's to answer alone.
%
%   Idempotent: a second run finds no `generic_file` and folds nothing.
%   Off-target (TargetVersion ~= 'V_eta') it returns its input untouched with
%   `ran` false -- `opaque_body` and the statement tier exist only in V_eta.
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveSessionAnchors,
%   did2.convert.resolveLawnPlateSubjects,
%   did2.unittest.testFoldGenericFiles, did2.unittest.testBatchPassWiring.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% DENOMINATOR FIRST AND UNCONDITIONALLY (Operating Rule 5). The report is
% attached BEFORE a single document is read, so "the pass never ran" and "the
% pass ran and found nothing" can never print the same. `ran` is the
% discriminator; the counts are meaningless while it is false.
report = struct( ...
    'pass',                          'did2.convert.foldGenericFiles', ...
    'documents_inspected',           0, ...
    'documents_unreadable',          0, ...
    'generic_files_seen',            0, ...
    'ontology_labels_seen',          0, ...
    'labels_pointing_at_a_file',     0, ...
    'files_folded',                  0, ...
    'refused_no_label',              0, ...
    'refused_ambiguous_label',       0, ...
    'refused_label_node_empty',      0, ...
    'refused_no_document_id',        0, ...
    'refused_referent_not_in_batch', 0, ...
    'refused_total',                 0, ...
    'fold_quarantined',              0, ...
    'date_fields_dropped',           0, ...
    'labels_deleted',                0, ...
    'labels_modified',               0, ...
    'ran',                           false);
result.generic_file_fold = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % opaque_body + the statement tier exist only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.generic_file_fold = report;
    return;
end
report.ran = true;

docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

% --- read every document once ----------------------------------------------
% A document this cannot read is COUNTED, never dropped.
bodies    = cell(1, n);
classes   = repmat({''}, 1, n);
docIds    = repmat({''}, 1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
        bodies{k}  = b;
        classes{k} = classNameOf(b);
        docIds{k}  = baseField(b, 'id');
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
    end
end

% --- index ids present, and the labels that point at a generic_file ---------
idsPresent = containers.Map('KeyType', 'char', 'ValueType', 'logical');
genericIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~isempty(docIds{k}); idsPresent(docIds{k}) = true; end
    if strcmp(classes{k}, 'generic_file') && ~isempty(docIds{k})
        genericIdx(docIds{k}) = k;
    end
end
% double(), NOT genericIdx.Count. `containers.Map.Count` is a **uint64**, and
% this line shipped without the cast: fixture run 31496802183, job 93796494861,
%
%     verifyEqual failed.
%     --> Classes do not match.
%         Actual Class:   uint64
%         Expected Class: double
%
% Every other counter in this report is a double, so an unconverted Count made
% ONE field of the struct a different numeric type from its neighbours -- which
% jsonencode would have hidden in the artifact and any strict comparison
% downstream would have tripped on later, further from the cause. Fixed at the
% source rather than by loosening the assertion.
report.generic_files_seen = double(genericIdx.Count);

% A label is matched to its target ONLY when the target is a generic_file in
% this batch. Every other label -- the ~7,007 that are not about a file, and
% any whose target is out of batch -- is not even looked up, and none is
% touched either way.
labelNode  = containers.Map('KeyType', 'char', 'ValueType', 'char');
labelCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~strcmp(classes{k}, 'ontology_label'); continue; end
    report.ontology_labels_seen = report.ontology_labels_seen + 1;
    targetId = depValueOf(bodies{k}, 'document_id');
    if isempty(targetId) || ~isKey(genericIdx, targetId); continue; end
    report.labels_pointing_at_a_file = report.labels_pointing_at_a_file + 1;
    if isKey(labelCount, targetId)
        labelCount(targetId) = labelCount(targetId) + 1;
    else
        labelCount(targetId) = 1;
        labelNode(targetId)  = charField(blockOf(bodies{k}, 'ontology_label'), ...
            {'ontology_node', 'ontologyNode'});
    end
end

% --- fold every generic_file that can be folded honestly --------------------
rebuilt    = {};      % the new bodies, statement and body interleaved
changedIdx = [];      % index into docs of the source each PAIR replaces
pairBodyId = {};      % the fresh opaque_body id of each pair
fileIds = genericIdx.keys();
for f = 1:numel(fileIds)
    id  = fileIds{f};
    k   = genericIdx(id);
    b   = bodies{k};
    blk = blockOf(b, 'generic_file');

    subjectId = depValueOf(b, 'document_id');
    if isempty(subjectId)
        report.refused_no_document_id = report.refused_no_document_id + 1;
        continue;
    end
    if ~isKey(idsPresent, subjectId)
        % `subject_id` is REQUIRED on the statement while the source's
        % `document_id` was optional, so folding an unresolvable referent would
        % turn a quiet passthrough into a dangling REQUIRED edge. Refusing
        % leaves the document exactly as the corpus is green with today. In a
        % subset/discovery batch this is the expected answer, not a defect --
        % the same stance jSessionAnchor's note records.
        report.refused_referent_not_in_batch = ...
            report.refused_referent_not_in_batch + 1;
        continue;
    end
    if ~isKey(labelCount, id)
        report.refused_no_label = report.refused_no_label + 1;
        continue;
    end
    if labelCount(id) > 1
        % Two labels on one file is two answers to "what is this". Refuse
        % rather than take the first: a guessed `variable` is the queryable
        % identity of the statement and would be indistinguishable from a read
        % one afterwards.
        report.refused_ambiguous_label = report.refused_ambiguous_label + 1;
        continue;
    end
    node = labelNode(id);
    if isempty(node)
        report.refused_label_node_empty = report.refused_label_node_empty + 1;
        continue;
    end

    bodyId = did.ido.unique_id();
    rebuilt{end+1} = makeStatement(b, node, subjectId);       %#ok<AGROW>
    rebuilt{end+1} = makeOpaqueBody(b, blk, bodyId, id);      %#ok<AGROW>
    changedIdx(end+1) = k;                                    %#ok<AGROW>
    pairBodyId{end+1} = bodyId;                               %#ok<AGROW>
    if ~isempty(charField(blk, {'date_created'})) ...
            || ~isempty(charField(blk, {'date_updated'})) ...
            || isNumericField(blk, 'date_created') ...
            || isNumericField(blk, 'date_updated')
        report.date_fields_dropped = report.date_fields_dropped + 1;
    end
end

report.refused_total = report.refused_no_label ...
    + report.refused_ambiguous_label ...
    + report.refused_label_node_empty ...
    + report.refused_no_document_id ...
    + report.refused_referent_not_in_batch;

if isempty(changedIdx)
    result.generic_file_fold = report;
    return;
end

% --- validate through the same door every other pass uses -------------------
% The bodies are tagged schema_version == TargetVersion, so v1_to_v2
% short-circuits them (isAlreadyTarget) to ensureClassBlocks + validate. A pair
% is accepted ONLY IF BOTH HALVES SURVIVE: a statement without its bytes, or
% bytes with no statement to hang off, is worse than an unfolded document.
out = did2.convert.v1_to_v2(rebuilt, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);

produced = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(out.migrated)
    try
        produced(char(out.migrated{k}.get('base.id'))) = out.migrated{k};
    catch
    end
end

appended = {};
for j = 1:numel(changedIdx)
    stmtId = docIds{changedIdx(j)};      % PRESERVED: the source's own id
    bodyId = pairBodyId{j};
    if isempty(stmtId) || ~isKey(produced, stmtId) || ~isKey(produced, bodyId)
        % Degrade to "not folded": the ORIGINAL stays in the batch.
        report.fold_quarantined = report.fold_quarantined + 1;
        continue;
    end
    docs{changedIdx(j)} = produced(stmtId);
    appended{end+1} = produced(bodyId); %#ok<AGROW>
    report.files_folded = report.files_folded + 1;
end

if ~isempty(out.quarantine)
    if isfield(result, 'quarantine') && ~isempty(result.quarantine)
        result.quarantine = [result.quarantine, out.quarantine];
    else
        result.quarantine = out.quarantine;
    end
end

result.migrated = [docs, appended];
result.summary = recountSummary(result);
result.generic_file_fold = report;
end

% ===================== the two bodies ==================================

function body = makeStatement(src, node, subjectId)
%MAKESTATEMENT The term_observation, WITH THE SOURCE'S OWN base.id.
%   `variable` is the label's node (the team's instruction, verbatim);
%   `term.value` restates it because that field is mustBeNonEmpty and the node
%   is the only term the source carries -- see the header for why that
%   redundancy was preferred to a false class name or a quarantine.
%
%   NO `sample_time`: the schema says so itself ("For body-backed values the
%   cadence lives in sampled_body.sample_time instead"), and this value is
%   body-backed. NO `time_reference_#`: it is optional, and the only times the
%   source carries are filesystem datenums, which are not an anchor.
term = struct('node', char(node), 'name', '');
body = struct();
body.document_class = struct('class_name', 'term_observation', ...
    'class_version', '1.0.0', ...
    'superclasses', supersOf({'subject_observation', 'term'}), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', 'subject_id', 'value', char(subjectId));
if isfield(src, 'base') && isstruct(src.base)
    body.base = src.base;               % THE ID IS NOT TOUCHED.
end
body.subject_statement   = struct('variable', term, 'storage_mode', 'body');
body.subject_interaction = struct('method', struct('node', '', 'name', ''));
body.subject_observation = struct();
body.term = struct('value', term);
% NOTHING from the source `generic_file` block reaches the statement: filename,
% format_ontology and checksum all belong to the BYTES and land on the
% opaque_body; the two datenums land nowhere (see the header).
end

function body = makeOpaqueBody(src, blk, bodyId, statementId)
%MAKEOPAQUEBODY The bytes. Fresh id; `statement` -> the observation.
%   format       <- format_ontology  (the CURIE verbatim; NOT re-expressed as
%                                     an {node,name} pair -- `format` is a char
%                                     and manufacturing a name half is the
%                                     invention the tombstone refused too)
%   filename     <- filename
%   content_hash <- checksum         (the field added for this fold)
%   description  is LEFT EMPTY. jSorterOutput puts an MD5 in `description`
%                because it had nowhere else; that stopgap is not repeated now
%                that `content_hash` exists.
body = struct();
body.document_class = struct('class_name', 'opaque_body', ...
    'class_version', '1.0.0', ...
    'superclasses', supersOf({'data_body'}), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', 'statement', 'value', char(statementId));
body.base = freshBase(src, bodyId, 'migrated_generic_file_bytes');
body.opaque_body = struct( ...
    'format',       charField(blk, {'format_ontology', 'formatOntology'}), ...
    'filename',     charField(blk, {'filename'}), ...
    'content_hash', charField(blk, {'checksum'}), ...
    'description',  '');
% The BYTES ARE NOT READ; the manifest moves verbatim. See the header on the
% body_data / generic_file.ext slot-name divergence.
if isfield(src, 'files'); body.files = src.files; end
if isfield(src, 'file');  body.file  = src.file;  end
end

% ===================== helpers =========================================

function supers = supersOf(chain)
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
end

function base = freshBase(src, id, name)
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isstruct(src) && isfield(src, 'base') && isstruct(src.base)
    if isfield(src.base, 'session_id'); sessionId = src.base.session_id; end
    if isfield(src.base, 'datestamp') && ~isempty(src.base.datestamp)
        ds = src.base.datestamp;
    end
end
base = struct('id', char(id), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end

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
    v = char(b.base.(name));
end
end

function blk = blockOf(b, className)
blk = struct();
if isstruct(b) && isfield(b, className) && isstruct(b.(className))
    blk = b.(className);
end
end

function v = charField(block, names)
%CHARFIELD The first of NAMES present and non-empty, as char.
%   Both spellings are accepted for the same reason every nested read in
%   +migrators_j does: universalRenames snake_cases a block's immediate field
%   names, but a body that reached us another way may still carry the did_v1
%   camelCase, and reading one spelling only is the bug that made the calc fold
%   emit nothing on every real document for weeks.
v = '';
if ~isstruct(block); return; end
for i = 1:numel(names)
    if isfield(block, names{i})
        raw = block.(names{i});
        if ischar(raw) || isstring(raw)
            c = char(raw);
            if ~isempty(c); v = c; return; end
        end
    end
end
end

function tf = isNumericField(block, name)
tf = isstruct(block) && isfield(block, name) && isnumeric(block.(name)) ...
    && ~isempty(block.(name));
end

function v = depValueOf(b, name)
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
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
