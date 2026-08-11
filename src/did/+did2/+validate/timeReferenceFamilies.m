function report = timeReferenceFamilies(docs, opts)
%TIMEREFERENCEFAMILIES  #52 evidence: how many time references does one
%   statement carry, and when it carries more than one, WHAT SHAPE ARE THEY?
%
%   REPORT = did2.validate.timeReferenceFamilies(DOCS) inspects an already-
%   migrated batch and answers four questions, each with its own denominator:
%
%     1. how many statements carry a time reference at all
%     2. the DISTRIBUTION of member count per statement (1 is the well-defined
%        case; >=2 is the regime #52 exists to decide)
%     3. for the multi-member ones, the SHAPES that occur -- read off the
%        REFERENCED documents, not off the index
%     4. which emitter produced each shape, as far as the documents say
%
%   REPORT-ONLY. It raises nothing, changes no outcome, and has no strictMode
%   switch. It is EVIDENCE FOR A TEAM DECISION, not a gate.
%
%   ------------------------------------------------------------------------
%   WHAT IT DOES NOT DO, AND WHY THAT IS DELIBERATE
%   ------------------------------------------------------------------------
%   IT PROPOSES NO ROLE NAMES. Whether `time_reference_1` should become
%   `start_anchor`, or stay an index, or acquire some third vocabulary is a
%   V_eta disposition and only the team makes one. This function's whole job is
%   to hand over the distribution and the shapes so that call rests on measured
%   instances rather than on a signature someone read. Nothing here writes,
%   suggests or hard-codes a role name, and the shape keys are built out of
%   SCHEMA-DECLARED field paths (`referent_unique_by`) plus the two structural
%   facts a reference carries (`relative_to`, and whether it has start/duration)
%   -- so a shape label is a description of the data, never a name for a role.
%
%   ------------------------------------------------------------------------
%   HOW IT DIFFERS FROM THE #52 COUNTER ALREADY IN silentLoss
%   ------------------------------------------------------------------------
%   `did2.validate.silentLoss` carries `family_uniqueness_violation`: it asks
%   whether two members of one family AGREE on the discriminator the schema
%   declares (`referent_unique_by`), i.e. whether the rule CHANGE 5 signed is
%   being broken. That is a pass/fail question about a rule.
%
%   This asks a prior, descriptive question the rule does not answer: HOW OFTEN
%   does a family have more than one member, and what do those members look like
%   RELATIVE TO EACH OTHER. A batch can satisfy uniqueness perfectly and still
%   be full of shapes nobody has decided the meaning of -- distinct clocks and
%   distinct anchors are both "unique", and they mean different things.
%
%   It is a SEPARATE FILE on purpose, and not an addition to silentLoss: that
%   file is 1,898 lines and owned elsewhere, and a censusing instrument that
%   needs a second author touching a shared file is how two counters end up
%   sharing one bug.
%
%   ------------------------------------------------------------------------
%   WHY THIS IS A BATCH INSTRUMENT AND CANNOT BE ANYTHING ELSE
%   ------------------------------------------------------------------------
%   Every property that distinguishes two members lives on the REFERENCED
%   document, not on the one carrying the edges. `did2.schema.cache` sees one
%   document; `did2.validate.references` is handed ids, not bodies. So the shape
%   can only be computed where the whole migrated batch is in hand, which is
%   here. A member whose referent is NOT in the batch is therefore NOT SHAPEABLE
%   and is counted as such -- never folded into a shape it might have had.
%
%   ------------------------------------------------------------------------
%   THE THREE FAMILIES IT CAN SEE, AND HOW IT FINDS THEM
%   ------------------------------------------------------------------------
%   NOTHING HERE KNOWS THE STRING `time_reference_#`. A family qualifies when
%   its `must_refer_to_document_class` resolves to a class whose chain contains
%   `time_reference` -- the same discovery rule silentLoss's #72 block uses, and
%   the reason `epoch`'s family qualifies at all (it refers to
%   `relative_reference`, a SUBCLASS, so a name-matching sweep would miss it).
%   Read from did-schema V_eta at the time of writing, 245 schema files scanned,
%   14 numbered families found, of which THREE refer to a time reference:
%
%       subject_interaction.time_reference_#  -> time_reference       min 1
%       directed_relation.time_reference_#    -> time_reference       min 0
%       epoch.time_reference_#                -> relative_reference   min 0
%
%   The discriminator path is likewise READ, not assumed: `referent_unique_by`
%   is `value.clock` on all three today. If that key is renamed the shape label
%   renames with it, because the label is the path's last segment.
%
%   ------------------------------------------------------------------------
%   THE DENOMINATORS ARE THE DELIVERABLE (operating rule 5)
%   ------------------------------------------------------------------------
%   A zero in this report can mean at least five different things, and they must
%   be distinguishable FROM THE REPORT ALONE:
%
%     docs_inspected              handed in, parseable or not
%     docs_unreadable             vBodies could not parse it
%     docs_unclassifiable         readable, no class name
%     docs_class_unresolved       class named, but the schema cache has no chain
%     docs_declaring_family       class chain declares a time-reference family
%                                 <-- AT ZERO NOTHING COULD HAVE CARRIED ONE,
%                                     and every count below says nothing at all
%     slots_examined              (document, family) pairs -- the unit of every
%                                 statement-level count below
%     statements_with_reference   slots with >=1 POPULATED member
%     statements_multi_reference  slots with >=2 populated members
%                                 <-- AT ZERO THE SHAPE TABLE CANNOT FIRE
%
%   `reference_census_vacuous` and `shape_census_vacuous` state this in the
%   report rather than leaving it to the reader, each with a REASON in words.
%   `headline` restates the top denominators unconditionally, on every path out
%   of this function including the early returns -- a block whose denominator is
%   set only on the happy path is the original silentLoss defect verbatim.
%
%   ------------------------------------------------------------------------
%   THE SLOT, NOT THE DOCUMENT, IS THE UNIT -- AND THAT IS MEASURED
%   ------------------------------------------------------------------------
%   A class could in principle declare two time-reference families, which would
%   make "statements" and "documents" different numbers. None does today, so the
%   two coincide -- and `docs_declaring_two_families` COUNTS the assumption
%   instead of resting on it. If it is ever non-zero, read the slot counters as
%   (document, family) pairs and not as documents.
%
%   ------------------------------------------------------------------------
%   WHAT THE TREE CAN CURRENTLY EMIT (a prediction, stated as one)
%   ------------------------------------------------------------------------
%   Grepped over src/ at the time of writing, COMMENT LINES EXCLUDED and this
%   file excluded from its own count (the first draft of this paragraph said
%   "57 sites" by counting both):
%
%       DENOMINATOR: 258 .m files under src/, all scanned
%       44 code lines, in 35 files, write a literal `time_reference_1`
%        0 code lines anywhere write `time_reference_2` or higher
%        1 site numbers a family programmatically
%
%   That one site is `did2.convert.resolveValidIntervals:857-860`, whose
%   split-anchor branch mints two instants when an interval's two ends resolve
%   to different (epoch, clock, tolerance) anchors. The signed model predicts
%   that branch NEVER FIRES (every `markvalidinterval` call site passes one
%   reference for both ends) and the pass already counts it as
%   `split_anchor_intervals`.
%
%   So the expectation is: every statement carries exactly ONE reference, the
%   count distribution has a single row at 1, and the shape table is VACUOUS.
%   THAT IS A PREDICTION AND NOT A RESULT -- no corpus run has exercised this
%   function. A vacuous shape table is the outcome to expect, and this report
%   says VACUOUS rather than printing zeros that read as clean.
%
%   ------------------------------------------------------------------------
%   STATUS: WRITTEN WITHOUT MATLAB AND NOT EXECUTED HERE
%   ------------------------------------------------------------------------
%   No MATLAB and no Octave were available in the container this was written in.
%   The only checks performed locally were structural. CI is the first execution
%   of every line of it, and tests/+did2/+unittest/testTimeReferenceFamilies.m
%   is the gate.
%
%   Name/value:
%     'SchemaCache'  a did2.schema.cache (defaults to the shared singleton)
%
%   See also did2.validate.silentLoss, did2.validate.isFragment.

arguments
    docs
    opts.SchemaCache = []
end

report = trfNewReport();

[bodies, unreadable] = vBodies(docs);
% docs_inspected counts what was HANDED IN, not what could be parsed. Taking a
% denominator from the survivors is what made an all-zero census look clean for
% two days -- see +validate/private/vBodies.m.
report.docs_inspected = numel(bodies) + unreadable;
report.docs_unreadable = unreadable;

cache = opts.SchemaCache;
if isempty(cache)
    try
        cache = did2.schema.cache.shared();
    catch
        cache = [];
    end
end
if isempty(cache)
    % NO CACHE => NO CHAINS => NO FAMILIES. Say so; do not report a clean batch.
    report.schema_cache_available = false;
    report = trfFinalise(report);
    return;
end
report.schema_cache_available = true;

if isempty(bodies)
    report = trfFinalise(report);
    return;
end

% ---- index the batch by document id -------------------------------------
% The shape is a property of the REFERENCED bodies, so they have to be findable.
idIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    thisId = trfBodyId(bodies{k});
    if isempty(thisId) || isKey(idIndex, thisId); continue; end
    idIndex(thisId) = k;
end
report.docs_with_an_id = double(idIndex.Count);

famMemo = containers.Map('KeyType', 'char', 'ValueType', 'any');
chainMemo = containers.Map('KeyType', 'char', 'ValueType', 'any');
pending = {};

% ===================== pass 1: counts ======================================
for k = 1:numel(bodies)
    b = bodies{k};
    cn = trfClassName(b);
    if isempty(cn)
        report.docs_unclassifiable = report.docs_unclassifiable + 1;
        continue;
    end
    report.docs_classified = report.docs_classified + 1;
    [fams, resolved] = trfTimeFamilies(cache, cn, famMemo, chainMemo);
    if ~resolved
        report.docs_class_unresolved = report.docs_class_unresolved + 1;
        continue;
    end
    if isempty(fams); continue; end
    report.docs_declaring_family = report.docs_declaring_family + 1;
    if numel(fams) > 1
        report.docs_declaring_two_families = report.docs_declaring_two_families + 1;
    end
    for f = 1:numel(fams)
        report.slots_examined = report.slots_examined + 1;
        vals = trfFamilyMemberValues(b, fams(f).name);
        report.members_examined = report.members_examined + numel(vals);
        if isempty(vals)
            report.slots_with_no_member = report.slots_with_no_member + 1;
            continue;
        end
        blank = cellfun(@isempty, vals);
        report.members_blank = report.members_blank + sum(blank);
        ids = vals(~blank);
        if isempty(ids)
            % A member that is PRESENT AND BLANK is not a reference. It satisfies
            % min_count and names no document; the empty-edge census owns it.
            report.slots_with_blank_members_only = ...
                report.slots_with_blank_members_only + 1;
            continue;
        end
        report.statements_with_reference = report.statements_with_reference + 1;
        report.count_distribution = trfBumpCount(report.count_distribution, numel(ids));
        if numel(ids) >= 2
            report.statements_multi_reference = report.statements_multi_reference + 1;
            rec = struct();
            rec.doc_index = k;
            rec.family    = fams(f).name;
            rec.unique_by = fams(f).unique_by;
            rec.member_ids = ids;
            pending{end+1} = rec; %#ok<AGROW>
        end
    end
end

% ===================== pass 2: shapes ======================================
for p = 1:numel(pending)
    rec = pending{p};
    b   = bodies{rec.doc_index};
    ids = rec.member_ids;
    report.shape_denominator.multi_slots_examined = ...
        report.shape_denominator.multi_slots_examined + 1;
    report.shape_denominator.multi_members_examined = ...
        report.shape_denominator.multi_members_examined + numel(ids);

    refs = cell(1, numel(ids));
    nUnresolved = 0;
    for m = 1:numel(ids)
        if isKey(idIndex, ids{m})
            refs{m} = bodies{idIndex(ids{m})};
        else
            refs{m} = [];
            nUnresolved = nUnresolved + 1;
        end
    end
    report.shape_denominator.multi_members_unresolved = ...
        report.shape_denominator.multi_members_unresolved + nUnresolved;
    report.shape_denominator.multi_members_resolved = ...
        report.shape_denominator.multi_members_resolved + (numel(ids) - nUnresolved);

    if nUnresolved > 0
        % NOT SHAPEABLE. An incremental import can hand us the statement without
        % its anchors; guessing a shape from the members we happen to hold is
        % the same error as a census that drops what it cannot read.
        key = trfUnresolvedKey();
        report.shape_denominator.multi_slots_unresolved = ...
            report.shape_denominator.multi_slots_unresolved + 1;
    else
        key = trfShapeKey(cache, refs, rec.unique_by, chainMemo);
        report.shape_denominator.multi_slots_shaped = ...
            report.shape_denominator.multi_slots_shaped + 1;
    end

    report.shape   = trfBumpShape(report.shape, key, numel(ids), b, rec.family);
    report.emitter = trfBumpEmitter(report.emitter, key, b, refs);
    if isempty(trfBaseName(b))
        report.emitter_denominator.multi_slots_without_statement_name = ...
            report.emitter_denominator.multi_slots_without_statement_name + 1;
    else
        report.emitter_denominator.multi_slots_with_statement_name = ...
            report.emitter_denominator.multi_slots_with_statement_name + 1;
    end
end

report = trfFinalise(report);
end

% ===================== report scaffolding ==================================

function r = trfNewReport()
%TRFNEWREPORT Every field exists on EVERY path out, including the early
%   returns. A report whose denominators appear only when the happy path runs is
%   a report that prints zeros for a batch it never opened.
r = struct( ...
    'docs_inspected',                0, ...
    'docs_unreadable',               0, ...
    'docs_unclassifiable',           0, ...
    'docs_classified',               0, ...
    'docs_class_unresolved',         0, ...
    'docs_with_an_id',               0, ...
    'docs_declaring_family',         0, ...
    'docs_declaring_two_families',   0, ...
    'schema_cache_available',        false, ...
    'slots_examined',                0, ...
    'slots_with_no_member',          0, ...
    'slots_with_blank_members_only', 0, ...
    'members_examined',              0, ...
    'members_blank',                 0, ...
    'statements_with_reference',     0, ...
    'statements_multi_reference',    0, ...
    'count_distribution',            struct('members', {}, 'statements', {}), ...
    'shape',                         struct('shape_key', {}, 'statements', {}, ...
                                            'members', {}, ...
                                            'example_document_id', {}, ...
                                            'example_class_name', {}, ...
                                            'family', {}), ...
    'shape_denominator',             struct( ...
        'multi_slots_examined',      0, ...
        'multi_slots_shaped',        0, ...
        'multi_slots_unresolved',    0, ...
        'multi_members_examined',    0, ...
        'multi_members_resolved',    0, ...
        'multi_members_unresolved',  0), ...
    'emitter',                       struct('shape_key', {}, ...
                                            'statement_class', {}, ...
                                            'statement_name', {}, ...
                                            'anchor_names', {}, ...
                                            'statements', {}), ...
    'emitter_denominator',           struct( ...
        'multi_slots_with_statement_name',    0, ...
        'multi_slots_without_statement_name', 0), ...
    'reference_census_vacuous',        true, ...
    'reference_census_vacuous_reason', '', ...
    'shape_census_vacuous',            true, ...
    'shape_census_vacuous_reason',     '', ...
    'headline',                        '');
end

function r = trfFinalise(r)
%TRFFINALISE The two vacuity verdicts, and the headline that carries the
%   denominators whether or not anything was found.
%
%   VACUOUS IS NOT CLEAN, and the distinction is the whole reason this function
%   exists. "0 multi-reference statements" is a RESULT when statements carrying
%   a reference were examined, and it is NOTHING AT ALL when none were.

% --- the reference census -------------------------------------------------
if r.docs_inspected == 0
    r.reference_census_vacuous = true;
    r.reference_census_vacuous_reason = ...
        'VACUOUS: no document was handed in. Nothing was inspected.';
elseif ~r.schema_cache_available
    r.reference_census_vacuous = true;
    r.reference_census_vacuous_reason = [ ...
        'VACUOUS: no schema cache was available, so no class chain could be ' ...
        'resolved and no family could be discovered. This is "did not look", ' ...
        'NOT "found nothing".'];
elseif r.docs_declaring_family == 0
    r.reference_census_vacuous = true;
    r.reference_census_vacuous_reason = sprintf([ ...
        'VACUOUS: %d document(s) classified, NONE belonging to a class whose ' ...
        'chain declares a time-reference family. No document in this batch ' ...
        'could have carried a time reference, so every count below is empty ' ...
        'by construction and says nothing about time references.'], ...
        r.docs_classified);
else
    r.reference_census_vacuous = false;
    r.reference_census_vacuous_reason = sprintf([ ...
        'MEASURED: %d document(s) declare a time-reference family; %d slot(s) ' ...
        'examined; %d carry at least one populated member.'], ...
        r.docs_declaring_family, r.slots_examined, r.statements_with_reference);
end

% --- the shape census -----------------------------------------------------
if r.reference_census_vacuous
    r.shape_census_vacuous = true;
    r.shape_census_vacuous_reason = ...
        'VACUOUS: the reference census itself was vacuous -- see its reason.';
elseif r.statements_multi_reference == 0
    r.shape_census_vacuous = true;
    r.shape_census_vacuous_reason = sprintf([ ...
        'VACUOUS: %d statement(s) carry a time reference and EVERY ONE carries ' ...
        'exactly one. No statement is in the undefined regime, so the shape ' ...
        'table could not fire; its emptiness is "the case does not occur here", ' ...
        'not "the shapes are fine".'], r.statements_with_reference);
elseif r.shape_denominator.multi_slots_shaped == 0
    r.shape_census_vacuous = true;
    r.shape_census_vacuous_reason = sprintf([ ...
        'VACUOUS: %d multi-reference statement(s) found, and EVERY ONE had at ' ...
        'least one referent outside this batch, so no shape could be computed. ' ...
        'The regime is occupied and UNMEASURED -- this is the one zero that ' ...
        'must never read as clean.'], r.statements_multi_reference);
else
    r.shape_census_vacuous = false;
    r.shape_census_vacuous_reason = sprintf([ ...
        'MEASURED: %d multi-reference statement(s), %d shaped, %d not shapeable ' ...
        '(referent outside the batch), %d distinct shape(s).'], ...
        r.statements_multi_reference, r.shape_denominator.multi_slots_shaped, ...
        r.shape_denominator.multi_slots_unresolved, numel(r.shape));
end

% --- the headline ---------------------------------------------------------
% Denominator first and unconditionally, in one line a log tail can find.
r.headline = sprintf([ ...
    'DENOMINATOR: %d document(s) inspected (%d unreadable, %d unclassifiable, ' ...
    '%d class-unresolved); %d declare a time-reference family; %d slot(s); ' ...
    '%d statement(s) carry a reference; %d carry more than one.'], ...
    r.docs_inspected, r.docs_unreadable, r.docs_unclassifiable, ...
    r.docs_class_unresolved, r.docs_declaring_family, r.slots_examined, ...
    r.statements_with_reference, r.statements_multi_reference);
end

function k = trfUnresolvedKey()
%TRFUNRESOLVEDKEY The one shape key that is NOT a shape. It is a row in the
%   table so the table PARTITIONS multi_slots_examined -- a statement that could
%   not be shaped must still be countable in the same place the shaped ones are,
%   or it drops out of the accounting into a silence.
k = '<NOT SHAPEABLE -- referent outside the batch>';
end

% ===================== the shape ===========================================

function key = trfShapeKey(cache, refs, uniqueBy, chainMemo)
%TRFSHAPEKEY What distinguishes the members of one multi-member family.
%
%   FOUR PARTS, each read from the REFERENCED documents:
%
%     kind         how many members are absolute vs relative references. A
%                  mixed family is a different modelling situation from two
%                  relatives and must not collapse into one row.
%     <discriminator>  agreement on the path the SCHEMA declares as
%                  `referent_unique_by` (`value.clock` on all three families
%                  today). The label is the path's LAST SEGMENT, so a rename of
%                  the field renames the label and nothing here needs editing.
%     relative_to  agreement on the anchor edge. Two references on one clock
%                  anchored to DIFFERENT documents is the split-anchor shape;
%                  two on different clocks anchored to the SAME document is the
%                  same-extent-N-clocks shape. Both are "unique" by the #52
%                  rule, and they are not the same thing.
%     extent       per member, does it carry a start, a duration, both or
%                  neither. Instants and spans are the difference between "two
%                  ends of one interval" and "one interval described twice".
%
%   THESE ARE DESCRIPTIONS, NOT ROLE NAMES. Nothing here says what a member
%   MEANS; it says what the documents differ on. Naming is the team's.
if isempty(uniqueBy); uniqueBy = ''; end

kindPart  = trfKindPart(cache, refs, chainMemo);
discPart  = trfAgreementPart(trfLastSegment(uniqueBy), ...
                             trfTermKeys(refs, uniqueBy));
anchorPart = trfAgreementPart('relative_to', trfAnchorKeys(refs));
extentPart = trfExtentPart(refs);

key = sprintf('kind=%s | %s | %s | %s', kindPart, discPart, anchorPart, extentPart);
end

function part = trfKindPart(cache, refs, chainMemo)
%TRFKINDPART Composition of the family by reference class, as counts of labels.
labels = cell(1, numel(refs));
for k = 1:numel(refs)
    cn = trfClassName(refs{k});
    chain = trfChain(cache, cn, chainMemo);
    if any(strcmp(chain, 'absolute_reference'))
        labels{k} = 'abs';
    elseif any(strcmp(chain, 'relative_reference'))
        labels{k} = 'rel';
    elseif any(strcmp(chain, 'time_reference'))
        labels{k} = 'timeref';
    else
        % The edge declares `must_refer_to_document_class` but nothing enforces
        % it (must_refer is existence-only). A member pointing somewhere else is
        % a finding, not something to round off.
        labels{k} = 'other';
    end
end
part = trfTally(labels);
end

function part = trfAgreementPart(label, keys)
%TRFAGREEMENTPART Do the members agree, differ, or partly-differ on one key?
%   FIVE outcomes, and `absent` is NOT `same`: two blanks are not two equal
%   values, they are nothing to compare -- the distinction testFamilyUniqueness
%   already had to make for the uniqueness rule.
if isempty(label); label = 'key'; end
n = numel(keys);
blank = cellfun(@isempty, keys);
if all(blank)
    verdict = 'absent';
elseif any(blank)
    verdict = 'partly_absent';
else
    % `unique` on a cellstr, so this counts DISTINCT KEYS -- the cardinality
    % of the container is the quantity meant, not the contents of a 1x1 cell.
    u = unique(keys);
    if isscalar(u)
        verdict = 'same';
    elseif numel(u) == n
        verdict = 'distinct';
    else
        verdict = 'partly_shared';
    end
end
part = sprintf('%s=%s', label, verdict);
end

function part = trfExtentPart(refs)
%TRFEXTENTPART Does each member carry a start, a duration, both or neither?
labels = cell(1, numel(refs));
for k = 1:numel(refs)
    hasStart = ~isempty(trfPathValue(refs{k}, 'value.start'));
    hasDur   = ~isempty(trfPathValue(refs{k}, 'value.duration'));
    if hasStart && hasDur
        labels{k} = 'span';
    elseif hasStart
        labels{k} = 'instant';
    elseif hasDur
        labels{k} = 'duration_only';
    else
        labels{k} = 'no_extent';
    end
end
part = ['extent=' trfTally(labels)];
end

function s = trfTally(labels)
%TRFTALLY '2rel', '1abs+1rel' -- counts of each distinct label, label order
%   sorted so the same composition always produces the same key.
if isempty(labels); s = 'none'; return; end
u = unique(labels);
parts = cell(1, numel(u));
for k = 1:numel(u)
    parts{k} = sprintf('%d%s', sum(strcmp(labels, u{k})), u{k});
end
s = strjoin(parts, '+');
end

function keys = trfTermKeys(refs, dottedPath)
%TRFTERMKEYS The comparison key for each member, off the declared path.
%   An ontology_term is keyed on the CURIE when it has one and on the LABEL when
%   it does not -- the NDIC clocktype terms are unminted (#67), so every real key
%   today is a label. Case-folded, because `NDIC:1` and `ndic:1` are one node.
keys = cell(1, numel(refs));
for k = 1:numel(refs)
    keys{k} = '';
    if isempty(dottedPath); continue; end
    v = trfPathValue(refs{k}, dottedPath);
    if isempty(v); continue; end
    if isstruct(v) && isscalar(v)
        if isfield(v, 'node') && ~isempty(v.node)
            keys{k} = lower(trfChar(v.node));
        elseif isfield(v, 'name') && ~isempty(v.name)
            keys{k} = lower(trfChar(v.name));
        end
    elseif ischar(v) || isstring(v)
        keys{k} = lower(trfChar(v));
    end
end
end

function keys = trfAnchorKeys(refs)
%TRFANCHORKEYS The `relative_to` referent of each member, '' when it has none.
%   An `absolute_reference` legitimately has none -- it is anchored to the
%   calendar -- which is why `absent` and `partly_absent` are their own verdicts
%   rather than being folded into `same`.
keys = cell(1, numel(refs));
for k = 1:numel(refs)
    keys{k} = trfEdgeValue(refs{k}, 'relative_to');
end
end

% ===================== table builders ======================================

function t = trfBumpCount(t, n)
%TRFBUMPCOUNT One row per distinct member count, kept in ascending order so the
%   distribution reads as a distribution.
for k = 1:numel(t)
    if t(k).members == n
        t(k).statements = t(k).statements + 1;
        return;
    end
end
t(end+1) = struct('members', n, 'statements', 1);
[~, order] = sort([t.members]);
t = t(order);
end

function t = trfBumpShape(t, key, nMembers, body, family)
%TRFBUMPSHAPE One row per distinct shape, with the FIRST statement seen kept as
%   the example -- the team asked for an id per shape so a row can be opened.
for k = 1:numel(t)
    if strcmp(t(k).shape_key, key) && t(k).members == nMembers
        t(k).statements = t(k).statements + 1;
        return;
    end
end
t(end+1) = struct('shape_key', key, 'statements', 1, 'members', nMembers, ...
    'example_document_id', trfBodyId(body), ...
    'example_class_name',  trfClassName(body), ...
    'family',              char(family));
end

function t = trfBumpEmitter(t, key, body, refs)
%TRFBUMPEMITTER Which emitter produced this shape, as far as the DOCUMENTS say.
%
%   `base.name` IS THE ONLY PROVENANCE A MIGRATED DOCUMENT CARRIES, and it is a
%   convention rather than a guaranteed field -- every batch pass and migrator
%   in the tree stamps a `migrated_*` string there (`migrated_valid_interval`,
%   `migrated_epoch_extent`, ...), so it identifies the emitter in practice
%   without being an interface. It is reported as a HINT and counted against its
%   own denominator (`multi_slots_with/without_statement_name`) so a batch whose
%   documents carry no name is visibly unattributed rather than silently
%   attributed to ''.
%
%   The ANCHOR names are carried too, and they are the sharper fingerprint: a
%   split-anchor pair is two `migrated_valid_interval_anchor` documents, which
%   names the pass even when the statement's own name is generic.
stmtName  = trfBaseName(body);
anchorNames = cell(1, numel(refs));
for k = 1:numel(refs)
    if isempty(refs{k})
        anchorNames{k} = '<unresolved>';
    else
        n = trfBaseName(refs{k});
        if isempty(n); n = '<unnamed>'; end
        anchorNames{k} = n;
    end
end
anchorJoined = strjoin(unique(anchorNames), '+');
stmtClass = trfClassName(body);
for k = 1:numel(t)
    if strcmp(t(k).shape_key, key) && strcmp(t(k).statement_class, stmtClass) ...
            && strcmp(t(k).statement_name, stmtName) ...
            && strcmp(t(k).anchor_names, anchorJoined)
        t(k).statements = t(k).statements + 1;
        return;
    end
end
t(end+1) = struct('shape_key', key, 'statement_class', stmtClass, ...
    'statement_name', stmtName, 'anchor_names', anchorJoined, 'statements', 1);
end

% ===================== schema readers ======================================

function [fams, resolved] = trfTimeFamilies(cache, className, famMemo, chainMemo)
%TRFTIMEFAMILIES The numbered families in CLASSNAME's chain that refer to a TIME
%   REFERENCE, with the discriminator path each declares.
%
%   RESOLVED is false when the class has no chain in the cache -- which is a
%   third answer, distinct from "no families", and is counted as such. A class
%   the cache cannot resolve is one we did not look at, not one that declares
%   nothing.
%
%   NO NAME MATCHING. The filter is `must_refer_to_document_class` resolved
%   through the class chain, so `epoch`'s family qualifies via
%   `relative_reference` and a fourth family acquires the same treatment by
%   being declared rather than by being listed here.
if isKey(famMemo, className)
    cached = famMemo(className);
    fams = cached.fams;
    resolved = cached.resolved;
    return;
end
fams = struct('name', {}, 'unique_by', {}, 'refers_to', {});
resolved = true;
try
    chain = cache.classChain(className);
catch
    resolved = false;
    % `{fams}` and not `fams`: a bare struct-array value inside a struct() call
    % is the one shape whose expansion rule is easy to get wrong. Wrapping it in
    % a 1x1 cell makes "one record holding a struct array" unambiguous.
    famMemo(className) = struct('fams', {fams}, 'resolved', resolved);
    return;
end
for k = 1:numel(chain)
    try
        c = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isfield(c, 'depends_on'); continue; end
    % jsondecode returns a CELL when the dependency objects in one class do not
    % all carry the same keys -- which is normal, since only numbered families
    % declare min_count/max_count. `[deps{:}]` throws on mismatched fieldnames
    % and the throw would be swallowed by the caller, so iterate element-wise.
    deps = c.depends_on;
    if isstruct(deps)
        items = num2cell(deps(:)');
    elseif iscell(deps)
        items = deps(:)';
    else
        continue;
    end
    for d = 1:numel(items)
        dep = items{d};
        if ~isstruct(dep) || ~isfield(dep, 'name'); continue; end
        nm = trfChar(dep.name);
        if ~contains(nm, '#'); continue; end
        if any(strcmp({fams.name}, nm)); continue; end
        refersTo = '';
        if isfield(dep, 'must_refer_to_document_class') ...
                && ~isempty(dep.must_refer_to_document_class)
            refersTo = trfChar(dep.must_refer_to_document_class);
        end
        if ~trfRefersToTimeReference(cache, refersTo, chainMemo); continue; end
        uq = '';
        if isfield(dep, 'referent_unique_by') && ~isempty(dep.referent_unique_by)
            uq = trfChar(dep.referent_unique_by);
        end
        fams(end+1) = struct('name', nm, 'unique_by', uq, ...
            'refers_to', refersTo); %#ok<AGROW>
    end
end
% NOT A DEAD STORE -- `containers.Map` is a handle class and this mutates the
% caller's map. See the note in trfChain.
famMemo(className) = struct('fams', {fams}, 'resolved', resolved);
end

function tf = trfRefersToTimeReference(cache, refersTo, chainMemo)
%TRFREFERSTOTIMEREFERENCE Is REFERSTO a time reference, or a subclass of one?
tf = false;
if isempty(refersTo); return; end
if strcmp(refersTo, 'time_reference'); tf = true; return; end
chain = trfChain(cache, refersTo, chainMemo);
tf = any(strcmp(chain, 'time_reference'));
end

function chain = trfChain(cache, className, memo)
%TRFCHAIN Root-first class chain, memoised, '' -> {}.
%
%   THE `memo(className) = chain` BELOW IS NOT A DEAD STORE, and GitHub code
%   scanning says it is. `containers.Map` is a HANDLE class, so `map(key) =
%   value` MUTATES THE CALLER'S MAP rather than rebinding a local; the analyzer
%   cannot see through the handle and reports the last write in a function as
%   unused. Deleting it would leave the results correct and the memo empty --
%   silently quadratic, with no test able to notice. The same false positive
%   fires on the two `famMemo(className) = ...` sites in trfTimeFamilies, and
%   has now fired six times across this repository; it is written down here so
%   the next reader does not have to re-derive it.
chain = {};
if isempty(className); return; end
if isKey(memo, className); chain = memo(className); return; end
try
    chain = reshape(cellstr(cache.classChain(className)), 1, []);
catch
    chain = {className};
end
memo(className) = chain;
end

% ===================== document readers ====================================
%
% THESE FOUR ARE DUPLICATED FROM did2.validate.silentLoss, and it is said out
% loud rather than hidden. They are local functions there, so they are not
% reachable from here; promoting them to +validate/private/ would mean editing
% silentLoss, which is owned elsewhere. `resolveValidIntervals` makes the same
% call for the same reason (see its `deEncodeApprox` note). If a third caller
% ever wants them, that is the signal to promote them once.

function vals = trfFamilyMemberValues(body, famName)
%TRFFAMILYMEMBERVALUES Every concrete member of `prefix_#`, in document order,
%   with '' for a member that is PRESENT AND BLANK. The distinction matters:
%   `time_reference_1 = ''` is a member that names no document, and folding it
%   in with a populated one would make "one anchor" and "one blank where an
%   anchor goes" the same number.
vals = {};
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
prefix = strrep(trfChar(famName), '#', '');
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name'); continue; end
    nm = trfChar(d.name);
    if ~startsWith(nm, prefix); continue; end
    tail = nm(numel(prefix)+1:end);
    if isempty(tail) || ~all(isstrprop(tail, 'digit')); continue; end
    vals{end+1} = trfDepValue(d); %#ok<AGROW>
end
end

function v = trfEdgeValue(body, name)
%TRFEDGEVALUE The referent of the FIRST edge carried under exactly NAME, or ''.
v = '';
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name'); continue; end
    if ~strcmp(trfChar(d.name), name); continue; end
    v = trfDepValue(d);
    return;
end
end

function v = trfDepValue(d)
%TRFDEPVALUE The referent id of one depends_on entry, or '' when it names
%   nothing. Tolerant of all three id spellings the pipeline uses at different
%   stages, the same tolerance silentLoss/edgeIsPopulated applies.
v = '';
if ~isstruct(d); return; end
for key = {'value', 'document_id', 'id'}
    if isfield(d, key{1}) && ~isempty(d.(key{1}))
        v = trfChar(d.(key{1}));
        return;
    end
end
end

function v = trfPathValue(body, dottedPath)
%TRFPATHVALUE Resolve a dotted path against a document body, SEARCHING the
%   property blocks for the first segment. The first segment is a FIELD name
%   ('value'), not a block name, because that is what a schema declares -- which
%   block hosts it depends on `placement` and on which class in the chain
%   declared it, so the block is searched for rather than assumed.
v = [];
if ~isstruct(body) || ~isscalar(body); return; end
parts = strsplit(trfChar(dottedPath), '.');
if isempty(parts) || isempty(parts{1}); return; end
blocks = fieldnames(body);
for b = 1:numel(blocks)
    bn = blocks{b};
    if any(strcmp(bn, {'document_class', 'depends_on', 'file', 'files'}))
        continue;
    end
    blk = body.(bn);
    if ~isstruct(blk) || ~isscalar(blk) || ~isfield(blk, parts{1}); continue; end
    cur = blk.(parts{1});
    ok = true;
    for p = 2:numel(parts)
        if isstruct(cur) && isscalar(cur) && isfield(cur, parts{p})
            cur = cur.(parts{p});
        else
            ok = false;
            break;
        end
    end
    if ok
        v = cur;
        return;
    end
end
end

function cn = trfClassName(body)
%TRFCLASSNAME The document's own class name, or ''.
cn = '';
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'document_class'); return; end
dc = body.document_class;
if ~isstruct(dc) || ~isscalar(dc) || ~isfield(dc, 'class_name'); return; end
cn = trfChar(dc.class_name);
end

function id = trfBodyId(body)
%TRFBODYID The document's own id, or '' -- the key the batch index is built on.
id = '';
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'base'); return; end
bs = body.base;
if ~isstruct(bs) || ~isscalar(bs) || ~isfield(bs, 'id'); return; end
id = trfChar(bs.id);
end

function nm = trfBaseName(body)
%TRFBASENAME The document's `base.name`, or '' -- the emitter hint.
nm = '';
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'base'); return; end
bs = body.base;
if ~isstruct(bs) || ~isscalar(bs) || ~isfield(bs, 'name'); return; end
nm = trfChar(bs.name);
end

function s = trfLastSegment(dottedPath)
%TRFLASTSEGMENT 'value.clock' -> 'clock'. The shape label follows the SCHEMA's
%   field name, so a rename of the discriminator renames the label with it.
s = '';
p = trfChar(dottedPath);
if isempty(p); return; end
parts = strsplit(p, '.');
s = parts{end};
end

function s = trfChar(v)
%TRFCHAR char/string/anything -> char, '' when it cannot be one.
s = '';
if ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif iscell(v) && isscalar(v) && ischar(v{1})
    % Spelled out rather than `iscellstr(v) && isscalar(v)`: that form needed an
    % `%#ok<ISCLSTR>` suppression which the analyzer now reports as stale, and
    % this says the same thing (a 1x1 cell holding a char) without one.
    s = v{1};
end
end
