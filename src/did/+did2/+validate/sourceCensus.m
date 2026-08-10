function report = sourceCensus(v1Bodies)
%SOURCECENSUS Measure the v1 SOURCE corpus for facts the V_eta build is blocked on.
%
%   REPORT = did2.validate.sourceCensus(V1BODIES) reads the ORIGINAL did_v1
%   documents -- not the migrated ones -- and answers three questions that three
%   separate open items each say must be MEASURED before a build may proceed.
%   Every other instrument in this package inspects the OUTPUT of a migration;
%   this one inspects the input, because these questions are about what the
%   source data actually contains.
%
%   V1BODIES may be a cell of JSON strings (what the corpus tests read off
%   disk), a cell of structs, or a struct array.
%
%   REPORT-ONLY. Raises nothing, gates nothing, changes no outcome.
%
%   THE THREE QUESTIONS
%   -------------------
%   1. IS GROUPING ON `epochid.epochid` SAFE?  (V_eta_epoch_plan.md, "HAZARD
%      for the build -- synthetic epoch ids COLLIDE".) The epoch model mints one
%      `epoch` document per distinct epoch-id string. That is only correct if
%      the string is unique per epoch, and it is not:
%
%        ndi.file.navigator.m:271   id = ['epoch_' ndi.ido.unique_id()]
%                                   unique per recording -> grouping is SAFE
%        ndi.element.oneepoch.m:42  epoch_id = ['whole_session_' reference]
%                                   DETERMINISTIC -- every element in a session
%                                   produces the SAME string -> grouping would
%                                   FUSE their epochs into one document
%
%      The plan says, in as many words: do not build the grouping without
%      either measuring this or keying the group on (epoch id, owning object).
%      `epoch_id_by_prefix` is that measurement. `synthetic_epoch_ids` is the
%      exposure: the `whole_session_` ids with the number of distinct elements
%      each would fuse. `cross_session_epoch_ids` is a second, prefix-blind
%      check -- one id under two `base.session_id`s cannot be one recording.
%
%   2. DOES A `session` DOCUMENT EXIST IN EVERY CORPUS?
%      (V_eta_time_reference_model_plan.md, fork A.) Making `relative_to`
%      REQUIRED assumes the referent exists. An earlier revision of that plan
%      asserted no `session` document is ever written, from a grep that could
%      not have matched; the correction records that `ndi.session.dir` creates
%      and persists one. This counts them rather than arguing about them, and
%      reports the distinct `base.session_id` values alongside so the two
%      numbers can be compared.
%
%      WHAT IT DOES NOT CLAIM: that a session document's `base.id` is the same
%      string as the `base.session_id` its siblings carry. That linkage is not
%      verified here, so both sets are reported and neither is joined to the
%      other.
%
%   3. DOES ONE STIMULATION APPROACH COVER SEVERAL INTERACTIONS?
%      (V_eta_go_forward_class_audit.md misc-singletons sign-off.) Decides
%      whether `interaction_purpose` earns its `interaction_id_#` family or
%      collapses to a plain field on `subject_interaction`. The measurement,
%      quoted from the item: for every `openminds_stimulus` document take its
%      epoch id, then count the DISTINCT SUBJECTS among the
%      `stimulus_presentation` documents sharing that epoch.
%
%      Both classes carry the `epochid` superclass and both depend on
%      `stimulus_element_id` (NDI origin/main templates), so this is computable
%      from the source documents alone.
%
%      DO NOT substitute the class totals for this. 635 approaches against
%      2,670 presentations is not a ratio: only some datasets write approaches
%      at all, so the two counts come from different populations.
%
%   REPORT fields (denominator first, unconditionally):
%     total_docs                 documents handed in
%     skipped_docs               documents that could not be parsed
%     by_class                   struct: normalised class name -> count
%
%     docs_with_epoch_id         documents carrying a non-empty epoch id
%     distinct_epoch_ids         how many distinct id strings
%     epoch_id_by_prefix         struct array {prefix, distinct_ids, doc_count}
%                                prefix is 'epoch_', 'whole_session_' or 'other'
%     synthetic_epoch_ids        struct array {epoch_id, doc_count,
%                                distinct_elements, distinct_classes} for the
%                                `whole_session_` ids. distinct_elements is the
%                                FUSION FACTOR: how many per-element spans
%                                grouping would collapse into one document.
%     synthetic_epoch_id_count   how many such ids
%     cross_session_epoch_ids    ids appearing under >1 base.session_id
%     cross_session_epoch_id_count  how many
%
%     session_doc_count          documents of class `session`
%     session_doc_ids            their base.id values
%     distinct_session_ids       distinct base.session_id across the corpus
%
%     approach_doc_count         `openminds_stimulus` documents
%     approach_epochs            distinct epoch ids among them
%     presentation_doc_count     `stimulus_presentation` documents -- THE OTHER
%                                SIDE'S DENOMINATOR. Without it, "no approach
%                                epoch has a presentation" cannot be told apart
%                                from "this census never saw a presentation".
%     presentation_docs_with_epoch  how many of those carry an epoch id at all
%     approach_epochs_no_presentation
%                                approach epochs with no presentation document
%     approach_epoch_prefixes    struct array {prefix, n_distinct, n_docs} --
%     presentation_epoch_prefixes  the SAME three buckets as epoch_id_by_prefix,
%                                but per class, so the two sides can be read
%                                against each other. Dab has 635 approaches and
%                                1,242 presentations that share NO epoch id;
%                                the pooled histogram cannot say why, because it
%                                mixes every class together.
%     approach_presentation_shared_epochs
%                                epoch ids carried by BOTH classes. Zero here is
%                                the finding, not the absence of one.
%     subjects_per_approach_epoch
%                                struct array {n_subjects, n_epochs} -- the
%                                distribution that answers question 3
%
%   See also: did2.validate.silentLoss, did2.validate.fileList.

arguments
    v1Bodies
end

report = struct( ...
    'total_docs',                  0, ...
    'skipped_docs',                0, ...
    'by_class',                    struct(), ...
    'docs_with_epoch_id',          0, ...
    'distinct_epoch_ids',          0, ...
    'epoch_id_by_prefix',          struct('prefix', {}, 'distinct_ids', {}, 'doc_count', {}), ...
    'synthetic_epoch_ids',         struct('epoch_id', {}, 'doc_count', {}, ...
                                          'distinct_elements', {}, 'distinct_classes', {}), ...
    'synthetic_epoch_id_count',    0, ...
    'cross_session_epoch_ids',     {{}}, ...
    'cross_session_epoch_id_count', 0, ...
    'session_doc_count',           0, ...
    'session_doc_ids',             {{}}, ...
    'distinct_session_ids',        0, ...
    'approach_doc_count',          0, ...
    'approach_epochs',             0, ...
    'presentation_doc_count',      0, ...
    'presentation_docs_with_epoch', 0, ...
    'approach_epochs_no_presentation', 0, ...
    'approach_epoch_prefixes',     struct('prefix', {}, 'n_distinct', {}, 'n_docs', {}), ...
    'presentation_epoch_prefixes', struct('prefix', {}, 'n_distinct', {}, 'n_docs', {}), ...
    'approach_presentation_shared_epochs', 0, ...
    'subjects_per_approach_epoch', struct('n_subjects', {}, 'n_epochs', {}));

items = normalise(v1Bodies);
report.total_docs = numel(items);
if isempty(items); return; end

% --- read every document once into a flat row -----------------------------
% Parsing is the only step that can fail, and a document it fails on is
% COUNTED, never dropped: an all-zero census that cannot read its input must
% not be indistinguishable from a clean one. That is the silentLoss failure.
rows = struct('class_name', {}, 'epoch_id', {}, 'element_id', {}, ...
              'doc_id', {}, 'session_id', {});
for k = 1:numel(items)
    try
        b = asBody(items{k});
        if isempty(b) || ~isstruct(b)
            report.skipped_docs = report.skipped_docs + 1; continue;
        end
        r = struct( ...
            'class_name',  normClass(classNameOf(b)), ...
            'epoch_id',    epochIdOf(b), ...
            'element_id',  edgeValue(b, {'stimulus_element_id', 'element_id'}), ...
            'doc_id',      baseField(b, 'id'), ...
            'session_id',  baseField(b, 'session_id'));
        if isempty(r.class_name)
            report.skipped_docs = report.skipped_docs + 1; continue;
        end
        rows(end+1) = r; %#ok<AGROW>
    catch
        report.skipped_docs = report.skipped_docs + 1;
    end
end
if isempty(rows); return; end

classes = {rows.class_name};
report.by_class = tally(classes);

% --- question 1: is grouping on the epoch id safe? ------------------------
epochIds = {rows.epoch_id};
hasEpoch = ~cellfun(@isempty, epochIds);
report.docs_with_epoch_id = sum(hasEpoch);
uniqEpochs = unique(epochIds(hasEpoch));
report.distinct_epoch_ids = numel(uniqEpochs);

prefixes = {'epoch_', 'whole_session_', 'other'};
for p = 1:numel(prefixes)
    if strcmp(prefixes{p}, 'other')
        sel = hasEpoch & ~startsWithAny(epochIds, prefixes(1:end-1));
    else
        sel = hasEpoch & startsWithAny(epochIds, prefixes(p));
    end
    report.epoch_id_by_prefix(end+1) = struct( ...
        'prefix',       prefixes{p}, ...
        'distinct_ids', numel(unique(epochIds(sel))), ...
        'doc_count',    sum(sel)); %#ok<AGROW>
end

% THE EXPOSURE, for the SYNTHETIC ids only.
%
% A first draft of this counted every id whose documents name more than one
% element and called that the fusion set. THAT IS WRONG, and wrong in the
% direction that manufactures alarm: many elements sharing one epoch is the
% NORMAL case -- a recording epoch is one span that every probe, element and
% spike train in it refers to -- so the measure would have flagged essentially
% every `epoch_` id as a hazard.
%
% The fusion is specific to the DETERMINISTIC ids. `whole_session_<reference>`
% is minted per ELEMENT (ndi.element.oneepoch.m:42) and evaluates to the same
% string for every element in a session, so grouping on it collapses N
% per-element spans into one document, and N -- the distinct element count --
% is exactly the fusion factor. For an `epoch_<uid>` the same count is expected
% to exceed 1 and means nothing.
synth = struct('epoch_id', {}, 'doc_count', {}, ...
               'distinct_elements', {}, 'distinct_classes', {});
for u = 1:numel(uniqEpochs)
    if ~startsWith(uniqEpochs{u}, 'whole_session_'); continue; end
    sel = strcmp(epochIds, uniqEpochs{u});
    synth(end+1) = struct( ...
        'epoch_id',          uniqEpochs{u}, ...
        'doc_count',         sum(sel), ...
        'distinct_elements', numel(unique(nonEmpty({rows(sel).element_id}))), ...
        'distinct_classes',  numel(unique(classes(sel)))); %#ok<AGROW>
end
if ~isempty(synth)
    [~, order] = sort([synth.distinct_elements], 'descend');
    synth = synth(order);
end
report.synthetic_epoch_ids = synth;
report.synthetic_epoch_id_count = numel(synth);

% A SECOND collision indicator, independent of the prefix and of any assumption
% about how NDI mints ids: one id string appearing under more than one
% `base.session_id`. A recording epoch belongs to one session, so this cannot
% happen legitimately, and unlike the element count it means the same thing for
% every prefix. It catches a collision arriving by a route neither writer above
% describes -- which is the whole reason not to rely on the prefix alone.
crossSession = {};
for u = 1:numel(uniqEpochs)
    sel = strcmp(epochIds, uniqEpochs{u});
    if numel(unique(nonEmpty({rows(sel).session_id}))) > 1
        crossSession{end+1} = uniqEpochs{u}; %#ok<AGROW>
    end
end
report.cross_session_epoch_ids = crossSession;
report.cross_session_epoch_id_count = numel(crossSession);

% --- question 2: is there a session document? -----------------------------
isSession = strcmp(classes, 'session');
report.session_doc_count = sum(isSession);
report.session_doc_ids = unique(nonEmpty({rows(isSession).doc_id}));
report.distinct_session_ids = numel(unique(nonEmpty({rows.session_id})));

% --- question 3: does one approach cover several interactions? ------------
isApproach     = strcmp(classes, 'openmindsstimulus');
isPresentation = strcmp(classes, 'stimuluspresentation');
report.approach_doc_count = sum(isApproach);
approachEpochs = unique(nonEmpty({rows(isApproach).epoch_id}));
report.approach_epochs = numel(approachEpochs);

% THE OTHER SIDE'S DENOMINATOR. Corpus Dab reported 635 approaches and 635
% approach epochs with NO presentation document -- every single one. That may be
% the real answer, or it may mean this census never saw a presentation, or saw
% them without epoch ids. WITHOUT THESE TWO COUNTS THE ZERO IS UNREADABLE, which
% is the exact failure this file was written to stop happening to other people's
% instruments and which it then shipped with itself.
report.presentation_doc_count = sum(isPresentation);
report.presentation_docs_with_epoch = sum(isPresentation & hasEpoch);

% WHY THE TWO SIDES DO NOT MEET -- the prefix cross-tab.
%
% Dab reports 635 approaches over 635 epochs, 1,242 presentations of which
% 1,242 carry an epoch id, and ZERO overlap. Both classes carry the SAME
% `epochid` superclass and the SAME `stimulus_element_id` dependency, so the
% disjointness is not explained by their shape, and the whole-corpus prefix
% histogram cannot answer it either: it pools every class together. Dab's two
% buckets (1,605 distinct `epoch_` ids over 3,845 docs; 149 distinct `other`
% ids over 6,207 docs) are consistent with the two sides sitting in DIFFERENT
% buckets, but consistent-with is not measured.
%
% So measure it per class. Until this exists, "no approach epoch has a
% presentation" is a number nobody can interpret -- and an uninterpretable
% number is what the whole approach measurement is currently blocked on.
report.approach_epoch_prefixes     = prefixTally({rows(isApproach).epoch_id});
report.presentation_epoch_prefixes = prefixTally({rows(isPresentation).epoch_id});
report.approach_presentation_shared_epochs = numel(intersect( ...
    unique(nonEmpty({rows(isApproach).epoch_id})), ...
    unique(nonEmpty({rows(isPresentation).epoch_id}))));

counts = [];
noPresentation = 0;
for u = 1:numel(approachEpochs)
    sel = isPresentation & strcmp(epochIds, approachEpochs{u});
    if ~any(sel); noPresentation = noPresentation + 1; continue; end
    counts(end+1) = numel(unique(nonEmpty({rows(sel).element_id}))); %#ok<AGROW>
end
report.approach_epochs_no_presentation = noPresentation;
% GUARD THE EMPTY CASE EXPLICITLY. MEASURED, not reasoned about -- the shapes
% were printed by the CI probe rather than assumed:
%
%     counts = []          size [0 0]
%     unique(counts)       size [0 1]   -> `for n = ...` runs ONCE
%     unique(counts(:)')   size [1 0]   -> runs zero times
%
% `for` iterates over the COLUMNS of its argument, and `unique` on a 0-by-0
% returns a 0-by-1: ONE column, of zero rows. So the loop body executed once
% with an empty `n`, and corpus Dab printed a distribution row with a blank
% subject count against 0 epochs -- from a distribution that has no rows at all.
%
% A phantom row in a report is a number someone will read, and this one appeared
% directly under "635 approach epochs with NO presentation document", which is
% exactly where a reader looks hardest.
%
% `for x = unique(v)` is a latent extra-iteration bug anywhere v can be empty.
% This is the only such site in src/ and tests/ (checked); the transpose alone
% would fix it, and the isempty guard is kept because it states the intent.
if ~isempty(counts)
    for n = unique(counts(:)')
        report.subjects_per_approach_epoch(end+1) = struct( ...
            'n_subjects', n, 'n_epochs', sum(counts == n)); %#ok<AGROW>
    end
end
end

% ===================== helpers =========================================

function items = normalise(v1Bodies)
if isempty(v1Bodies)
    items = {};
elseif iscell(v1Bodies)
    items = v1Bodies(:)';
elseif isstruct(v1Bodies)
    items = num2cell(v1Bodies(:)');
else
    items = {v1Bodies};
end
end

function b = asBody(item)
%ASBODY A v1 document as a struct: JSON text, a struct, or a did2.document.
b = [];
if ischar(item) || isstring(item)
    b = jsondecode(char(item));
elseif isstruct(item)
    b = item;
else
    for prop = {'documentProperties', 'document_properties', 'body'}
        try
            v = item.(prop{1});
            if isstruct(v) && ~isempty(fieldnames(v)); b = v; return; end
        catch
            % wrong shape for this accessor -- try the next
        end
    end
end
end

function cn = classNameOf(b)
cn = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function n = normClass(name)
%NORMCLASS Lowercase, underscores stripped. V_eta is snake_case and NDI is
%   camelCase, and a comparison that picks one spelling silently matches
%   nothing -- `demo_ndi` was dispositioned DELETE off a grep against a
%   repository that has never contained that string. Normalising both sides is
%   the mechanical form of that check.
n = lower(strrep(char(name), '_', ''));
end

function id = epochIdOf(b)
%EPOCHIDOF The epoch-id STRING, from whichever spelling this document uses.
%   `epochid` is a superclass whose block holds the string 11+ live NDI
%   queries match on; V_eta's rename moves it to `epoch_id`. Both are read,
%   plus the block-level `epoch_id` field `epochfiles_ingested` declares.
id = '';
for blk = {'epochid', 'epoch_id'}
    if ~isfield(b, blk{1}) || ~isstruct(b.(blk{1})); continue; end
    s = b.(blk{1});
    for fld = {'epochid', 'epoch_id', 'epochId'}
        if isfield(s, fld{1})
            v = s.(fld{1});
            if (ischar(v) || isstring(v)) && ~isempty(char(v))
                id = char(v); return;
            end
        end
    end
end
end

function v = edgeValue(b, names)
%EDGEVALUE First non-empty depends_on value among NAMES.
%   Tolerant of the three key spellings the pipeline uses at different stages
%   (`value`, `document_id`, raw v1 `id`), and iterates element-wise: a
%   jsondecode'd depends_on is a CELL whenever its entries do not all carry the
%   same keys, and `[deps{:}]` throws on that -- a throw that was once swallowed
%   by a caller's try/catch, leaving a census quiet exactly where it should have
%   spoken.
v = '';
if ~isfield(b, 'depends_on'); return; end
deps = b.depends_on;
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
    if ~any(strcmp(char(d.name), names)); continue; end
    for key = {'value', 'document_id', 'id'}
        if isfield(d, key{1})
            val = d.(key{1});
            if (ischar(val) || isstring(val)) && ~isempty(char(val))
                v = char(val); return;
            end
        end
    end
end
end

function v = baseField(b, name)
v = '';
if ~isfield(b, 'base') || ~isstruct(b.base) || ~isfield(b.base, name); return; end
x = b.base.(name);
if ischar(x) || isstring(x); v = char(x); end
end

function out = nonEmpty(c)
out = c(~cellfun(@isempty, c));
end

function tf = startsWithAny(strs, prefixes)
tf = false(1, numel(strs));
for k = 1:numel(strs)
    s = strs{k};
    if isempty(s); continue; end
    for p = 1:numel(prefixes)
        if startsWith(s, prefixes{p}); tf(k) = true; break; end
    end
end
end

function t = tally(names)
%TALLY A struct of countable name -> count, field-name-safe.
t = struct();
u = unique(names);
for k = 1:numel(u)
    f = matlab.lang.makeValidName(u{k});
    t.(f) = sum(strcmp(names, u{k}));
end
end

function t = prefixTally(ids)
%PREFIXTALLY Distinct-and-total counts per epoch-id PREFIX for one class.
%   The three buckets match the whole-corpus histogram so the two can be read
%   against each other: `epoch_` (minted by ndi.file.navigator),
%   `whole_session_` (synthetic, ndi.element.oneepoch) and everything else.
ids = ids(:)';
keep = {};
for k = 1:numel(ids)
    v = ids{k};
    if (ischar(v) || isstring(v)) && ~isempty(char(v)); keep{end+1} = char(v); end %#ok<AGROW>
end
t = struct('prefix', {}, 'n_distinct', {}, 'n_docs', {});
names = {'epoch_', 'whole_session_', 'other'};
for p = 1:numel(names)
    if strcmp(names{p}, 'other')
        sel = ~startsWith(keep, 'epoch_') & ~startsWith(keep, 'whole_session_');
    else
        sel = startsWith(keep, names{p});
    end
    if isempty(keep); sel = false(1,0); end
    t(end+1) = struct('prefix', names{p}, ...
        'n_distinct', numel(unique(keep(sel))), 'n_docs', sum(sel)); %#ok<AGROW>
end
end
