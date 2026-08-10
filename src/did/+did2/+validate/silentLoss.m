function report = silentLoss(docs, opts)
%SILENTLOSS Report-only audit for data that migrates away without a trace.
%
%   REPORT = did2.validate.silentLoss(DOCS) inspects already-migrated
%   documents and counts two things the existing gates CANNOT see:
%
%     1. a REQUIRED depends_on edge that is empty
%     2. a REQUIRED field whose value is present but VACUOUS -- a struct
%        whose every leaf is blank, e.g. an ontology_term {node:'', name:''}
%
%   WHY THIS EXISTS
%   ---------------
%   A migrator that reads a field the source document does not have emits an
%   EMPTY BUT PERFECTLY VALID document. Two independent holes let it through:
%
%     did2.schema.cache/isEmptyValue calls a struct empty only when it has NO
%     FIELDNAMES, so {node:'',name:''} satisfies mustBeNonEmpty.
%
%     depends_on non-emptiness is enforced NOWHERE: the schema cache never
%     checks dependencies, and did2.validate.references deliberately SKIPS
%     empty edges as "intentionally unfilled optional dependencies".
%
%   So the corpus reports 0 quarantine and 0 orphans while the content is
%   gone. That is how ontology_image migrated every document to an
%   observation about nobody, of nothing, for months without a red test.
%
%   REPORT-ONLY, ON PURPOSE
%   -----------------------
%   This RAISES NOTHING and CHANGES NO OUTCOME. Turning these into hard
%   failures today would quarantine a large, unknown number of documents and
%   block the 0-quarantine gate before a single migrator has been fixed. The
%   census comes first: it says which migrators are losing data and how many
%   real documents each one touches, which is what ranks the repair work.
%   Enforcement lands only once these counts reach zero.
%
%   See did-schema/schemas/V_eta_ground_truth_plan.md, Phase 1.
%
%   REPORT fields:
%     total_docs                  documents inspected
%     empty_required_dependency   struct array {class_name, edge_name, count}
%     vacuous_required_field      struct array {class_name, block, field_name, count}
%     empty_dependency_count      total occurrences
%     vacuous_field_count         total occurrences
%     family_count_violation      #63: struct array {class_name, edge_name,
%                                 declared, found, count} -- a NUMBERED edge
%                                 family whose instance count falls outside the
%                                 declared min_count/max_count. REPORT ONLY.
%     family_violation_count      total occurrences
%     family_uniqueness_violation #52: struct array {class_name, edge_name,
%                                 unique_by, key, count} -- two members of one
%                                 numbered family referring to documents that
%                                 AGREE on the family's `referent_unique_by`
%                                 path, i.e. two members nothing distinguishes.
%                                 REPORT ONLY.
%     family_uniqueness_violation_count   total occurrences
%     uniqueness_denominator      #52's own denominators (see below)
%     skipped_docs                documents whose schema could not be resolved
%
%   #52 -- WHAT MAKES TWO MEMBERS OF A FAMILY DIFFERENT
%   ---------------------------------------------------
%   #63 declared HOW MANY members a family may carry. It could not say what
%   makes two of them distinct, so `time_reference_1` and `time_reference_2` on
%   one document were undefined in meaning: a bare index cannot tell a
%   start-anchor from a same-instant-other-clock from a recurrence.
%
%   The signed time model (`V_eta_time_reference_model_plan.md` CHANGE 5) closed
%   that by ELIMINATION -- split-anchored intervals have no instance, recurrence
%   dissolves into N statements, epoch extent and statement time live on
%   different documents -- leaving ONE live case, SAME EXTENT / N CLOCKS, whose
%   discriminator already exists INSIDE THE REFERENCED DOCUMENT as `value.clock`.
%   The schema now says so machine-readably, as `referent_unique_by` on the
%   family (did-schema tools/build_v_eta.py, `_EDGE_REFERENT_UNIQUE`). This
%   function reads that key; it does not know the word "time_reference".
%
%   WHY IT LIVES HERE AND NOWHERE ELSE. The path is evaluated on the REFERENCED
%   document, so checking it needs the other documents.
%     * did2.schema.cache sees ONE document. It cannot resolve a target, and a
%       version that passed whenever it could not is the all-zero census one
%       more time.
%     * did2.validate.references walks edges but is handed IDS, not bodies (its
%       'Database' mode has only ids), so it can say an edge resolves and not
%       what it resolves TO.
%     * silentLoss is handed the whole migrated batch. That is where the data
%       is, so that is where the check is. It is therefore a BATCH property and
%       is stated as one -- there is no per-document form of this rule.
%
%   THE DENOMINATORS ARE THE POINT (operating rule 5). A zero here can mean four
%   different things and they must be distinguishable from the report alone:
%     uniqueness_families_declared   (class, family) pairs carrying the rule
%     docs_with_family               documents carrying >=1 member
%     docs_multi_member              documents carrying >1 member  <-- BELOW
%                                    THIS THE RULE CANNOT FIRE AT ALL
%     members_examined               family members inspected
%     members_resolved               target found in this batch
%     members_unresolved             target NOT in the batch -- NOT CHECKED
%     members_no_key                 target resolved but the path is absent or
%                                    blank -- NOT CHECKED
%     members_keyed_by_node          compared on the ontology CURIE
%     members_keyed_by_name          compared on the label, because the node is
%                                    empty (the NDIC clocktype terms are not
%                                    minted -- #67)
%
%   Name/value:
%     'SchemaCache'  a did2.schema.cache (defaults to the shared singleton)

arguments
    docs
    opts.SchemaCache = []
end

report = struct( ...
    'total_docs',                0, ...
    'empty_required_dependency', struct('class_name', {}, 'edge_name', {}, 'count', {}), ...
    'vacuous_required_field',    struct('class_name', {}, 'block', {}, 'field_name', {}, 'count', {}), ...
    'empty_dependency_count',    0, ...
    'vacuous_field_count',       0, ...
    'family_count_violation',    struct('class_name', {}, 'edge_name', {}, ...
                                        'declared', {}, 'found', {}, 'count', {}), ...
    'family_violation_count',    0, ...
    'family_uniqueness_violation', struct('class_name', {}, 'edge_name', {}, ...
                                        'unique_by', {}, 'key', {}, 'count', {}), ...
    'family_uniqueness_violation_count', 0, ...
    'uniqueness_denominator',    struct( ...
        'families_declared',     0, ...
        'docs_with_family',      0, ...
        'docs_multi_member',     0, ...
        'members_examined',      0, ...
        'members_resolved',      0, ...
        'members_unresolved',    0, ...
        'members_no_key',        0, ...
        'members_keyed_by_node', 0, ...
        'members_keyed_by_name', 0), ...
    'skipped_docs',              0);

[bodies, unreadable] = vBodies(docs);
% total_docs counts what was HANDED IN, not what could be parsed. Counting the
% survivors made an all-zero report indistinguishable from a clean one -- see
% the note in +validate/private/vBodies.m.
report.total_docs = numel(bodies) + unreadable;
report.skipped_docs = unreadable;
if isempty(bodies)
    return;
end

cache = opts.SchemaCache;
if isempty(cache)
    try
        cache = did2.schema.cache.shared();
    catch
        report.skipped_docs = numel(bodies);
        return;   % no schema available -- report nothing rather than guess
    end
end

depKeys = {}; depCounts = [];
fldKeys = {}; fldCounts = [];
famKeys = {}; famCounts = [];
uniKeys = {}; uniCounts = [];

% #52. The id -> body index the uniqueness check resolves through. Built ONCE,
% up front, over the whole batch -- this is the thing a per-document validator
% does not have and cannot fake. Documents with no `base.id` simply do not enter
% it; they can still REFER, they just cannot be referred to.
idIndex = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(bodies)
    thisId = bodyId(bodies{k});
    if ~isempty(thisId) && ~idIndex.isKey(thisId)
        idIndex(thisId) = bodies{k}; %#ok<NASGU>
    end
end
uniqueFamilySeen = {};   % (class|family) pairs that actually carry the rule

for k = 1:numel(bodies)
    body = bodies{k};
    % The audit must never be able to break a migration. Any document we
    % cannot resolve is counted as skipped, not failed.
    try
        className = classNameOf(body);
        if isempty(className); report.skipped_docs = report.skipped_docs + 1; continue; end

        % --- 1. required depends_on edges that are empty -----------------
        required = requiredDependencies(cache, className);
        for d = 1:numel(required)
            name = required{d};
            if ~edgeIsPopulated(body, name)
                key = sprintf('%s|%s', className, name);
                [depKeys, depCounts] = bump(depKeys, depCounts, key);
            end
        end

        % --- 1b. NUMBERED families: is the INSTANCE COUNT in range? -------
        % #63. `mustBeNonEmpty` cannot describe a family -- a missing instance
        % is not a blank one -- so three families were declared REQUIRED and
        % verified by nothing. What is checkable is how many instances exist.
        % REPORT ONLY: the counts have never been measured, and enforcing a
        % minimum before knowing them is how a gate turns red on real data.
        families = declaredFamilies(cache, className);
        for f = 1:numel(families)
            fam = families(f);
            found = countFamily(body, fam.name);
            bad = found < fam.min_count || ...
                  (~isnan(fam.max_count) && found > fam.max_count);
            if bad
                key = sprintf('%s|%s|%s|%d', className, fam.name, ...
                    describeRange(fam), found);
                [famKeys, famCounts] = bump(famKeys, famCounts, key);
            end
        end

        % --- 1c. NUMBERED families: are the members DISTINGUISHABLE? ------
        % #52. Everything above this line is about ONE document. This is not:
        % the discriminator lives on the REFERENCED document, so the family is
        % resolved through idIndex and read there. A member whose target is not
        % in this batch is counted as UNRESOLVED and compared with nothing --
        % it is NOT silently treated as unique, which would turn an incremental
        % import into a clean bill of health it did not earn.
        for f = 1:numel(families)
            fam = families(f);
            if isempty(fam.unique_by); continue; end
            famKey = sprintf('%s|%s', className, fam.name);
            if ~any(strcmp(uniqueFamilySeen, famKey))
                uniqueFamilySeen{end+1} = famKey; %#ok<AGROW>
            end
            memberIds = familyMemberIds(body, fam.name);
            if isempty(memberIds); continue; end
            report.uniqueness_denominator.docs_with_family = ...
                report.uniqueness_denominator.docs_with_family + 1;
            if numel(memberIds) > 1
                report.uniqueness_denominator.docs_multi_member = ...
                    report.uniqueness_denominator.docs_multi_member + 1;
            end
            seenKeys = {};
            for m = 1:numel(memberIds)
                report.uniqueness_denominator.members_examined = ...
                    report.uniqueness_denominator.members_examined + 1;
                if ~idIndex.isKey(memberIds{m})
                    report.uniqueness_denominator.members_unresolved = ...
                        report.uniqueness_denominator.members_unresolved + 1;
                    continue;
                end
                report.uniqueness_denominator.members_resolved = ...
                    report.uniqueness_denominator.members_resolved + 1;
                [dkey, how] = referentKey(idIndex(memberIds{m}), fam.unique_by);
                switch how
                    case 'node'
                        report.uniqueness_denominator.members_keyed_by_node = ...
                            report.uniqueness_denominator.members_keyed_by_node + 1;
                    case 'name'
                        report.uniqueness_denominator.members_keyed_by_name = ...
                            report.uniqueness_denominator.members_keyed_by_name + 1;
                    otherwise
                        % The path is absent or blank on the referent. NOT a
                        % violation and NOT a pass: there is nothing to compare.
                        % Today this is the COMMON case -- only
                        % `relative_reference` declares `value.clock`, and every
                        % live anchor is still a session_*_reference.
                        report.uniqueness_denominator.members_no_key = ...
                            report.uniqueness_denominator.members_no_key + 1;
                        continue;
                end
                if any(strcmp(seenKeys, dkey))
                    % One occurrence per DUPLICATE member, not per pair: the
                    % second member sharing a clock is the one nothing
                    % distinguishes from the first.
                    key = sprintf('%s|%s|%s|%s', className, fam.name, ...
                        sanitise(fam.unique_by), sanitise(dkey));
                    [uniKeys, uniCounts] = bump(uniKeys, uniCounts, key);
                else
                    seenKeys{end+1} = dkey; %#ok<AGROW>
                end
            end
        end

        % --- 2. required fields whose value is vacuous -------------------
        tagged = cache.fieldsFor(className);
        for f = 1:numel(tagged)
            fd = tagged(f).fieldDef;
            if ~isstruct(fd) || ~isfield(fd, 'name') || ~isfield(fd, 'mustBeNonEmpty')
                continue;
            end
            if ~logical(fd.mustBeNonEmpty); continue; end
            fname = char(fd.name);
            % look for the field in whichever block hosts it -- placement
            % rules mean it is not always the declaring class's block
            blocks = fieldnames(body);
            for b = 1:numel(blocks)
                bn = blocks{b};
                if any(strcmp(bn, {'document_class', 'depends_on', 'file', 'files'}))
                    continue;
                end
                blk = body.(bn);
                if ~isstruct(blk) || ~isscalar(blk) || ~isfield(blk, fname)
                    continue;
                end
                if isVacuous(blk.(fname))
                    key = sprintf('%s|%s|%s', className, bn, fname);
                    [fldKeys, fldCounts] = bump(fldKeys, fldCounts, key);
                end
            end
        end
    catch
        report.skipped_docs = report.skipped_docs + 1;
    end
end

report.empty_required_dependency = explode(depKeys, depCounts, ...
    {'class_name', 'edge_name'});
report.vacuous_required_field = explode(fldKeys, fldCounts, ...
    {'class_name', 'block', 'field_name'});
% #63. THE BUG THIS LINE PAIR FIXES: famKeys/famCounts were accumulated in the
% loop and then never assigned, so the counter measured correctly and threw the
% answer away -- the report read `family_violation_count: 0` on a document the
% detector had just flagged. It is the silentLoss failure mode one level up: a
% zero that means "not reported", not "nothing wrong". Two CI rounds and a
% revert were spent on the detector before a probe printed the report itself.
report.family_count_violation = explode(famKeys, famCounts, ...
    {'class_name', 'edge_name', 'declared', 'found'});
% #52, assigned in the SAME place and for the same reason the line above exists:
% a counter that accumulates and never assigns reports a zero that means "not
% reported". That bug has been shipped once in this file already.
report.family_uniqueness_violation = explode(uniKeys, uniCounts, ...
    {'class_name', 'edge_name', 'unique_by', 'key'});
report.empty_dependency_count = sum(depCounts);
report.vacuous_field_count = sum(fldCounts);
report.family_violation_count = sum(famCounts);
report.family_uniqueness_violation_count = sum(uniCounts);
report.uniqueness_denominator.families_declared = numel(uniqueFamilySeen);
end

% ===================== helpers =========================================

function cn = classNameOf(body)
cn = '';
if isfield(body, 'document_class') && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    cn = char(body.document_class.class_name);
end
end

function fams = declaredFamilies(cache, className)
%DECLAREDFAMILIES #63/#52: numbered edge families in the class chain, with the
%   instance counts they declare. A family entry is `name_#`; `min_count` /
%   `max_count` say how many concrete instances a valid document carries.
%   `mustBeNonEmpty` is NOT consulted -- it cannot describe a family, which is
%   the whole reason these fields exist.
%
%   #52 adds `unique_by`, read from the schema key `referent_unique_by`: a
%   dotted path evaluated ON THE REFERENCED document that no two members of the
%   family may agree on. '' when the family declares none, which is most of
%   them -- `derived_from_#` members are N different inputs and no uniqueness
%   rule has been decided for them. NOTHING HERE KNOWS THE WORD
%   `time_reference`: the rule is data in the schema, exactly as min_count is,
%   so a fourth family acquires it by being declared and not by being special-
%   cased here.
fams = struct('name', {}, 'min_count', {}, 'max_count', {}, 'unique_by', {});
try
    chain = cache.classChain(className);
catch
    return;
end
for k = 1:numel(chain)
    try
        c = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isfield(c, 'depends_on'); continue; end
    % jsondecode returns a CELL when the dependency objects in one class do not all
    % carry the same keys -- which is normal now that only NUMBERED families declare
    % min_count/max_count. `[deps{:}]` throws on mismatched fieldnames, and the throw
    % was swallowed by the caller's try/catch, so the census went quiet exactly where
    % it should have spoken. Iterate element-wise, as requiredDependencies does.
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
        n = char(dep.name);
        if ~contains(n, '#'); continue; end
        lo = 0; hi = NaN;
        if isfield(dep, 'min_count') && ~isempty(dep.min_count); lo = double(dep.min_count); end
        if isfield(dep, 'max_count') && ~isempty(dep.max_count); hi = double(dep.max_count); end
        if any(strcmp({fams.name}, n)); continue; end
        fams(end+1) = struct('name', n, 'min_count', lo, 'max_count', hi); %#ok<AGROW>
    end
end
end

function n = countFamily(body, famName)
%COUNTFAMILY How many concrete instances of `prefix_#` the document carries.
%   Counts the EDGES PRESENT, whatever their value: a family violation is about
%   how many instances exist, not whether one of them is blank (that is the
%   separate, and separately reported, empty-edge check).
n = 0;
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on); return; end
prefix = strrep(famName, '#', '');
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if ~isfield(d, 'name'); continue; end
    nm = char(d.name);
    if ~startsWith(nm, prefix); continue; end
    tail = nm(numel(prefix)+1:end);
    if ~isempty(tail) && all(isstrprop(tail, 'digit')); n = n + 1; end
end
end

function s = describeRange(fam)
if isnan(fam.max_count)
    s = sprintf('min %d', fam.min_count);
else
    s = sprintf('min %d max %d', fam.min_count, fam.max_count);
end
end

function names = requiredDependencies(cache, className)
%REQUIREDDEPENDENCIES Names of depends_on entries declared mustBeNonEmpty
%   anywhere in the class chain. Numbered edges (`derived_from_#`,
%   `time_reference_#`) are template names, not concrete edges, so they are
%   excluded -- a missing instance of one is not the same as a blank one.
names = {};
chain = cache.classChain(className);
for k = 1:numel(chain)
    try
        s = cache.getClass(chain{k});
    catch
        continue;
    end
    if ~isfield(s, 'depends_on'); continue; end
    deps = s.depends_on;
    if isstruct(deps)
        for d = 1:numel(deps)
            names = addRequired(names, deps(d));
        end
    elseif iscell(deps)
        for d = 1:numel(deps)
            names = addRequired(names, deps{d});
        end
    end
end
end

function names = addRequired(names, dep)
if ~isstruct(dep) || ~isfield(dep, 'name') || ~isfield(dep, 'mustBeNonEmpty')
    return;
end
if ~logical(dep.mustBeNonEmpty); return; end
n = char(dep.name);
if contains(n, '#'); return; end
if ~any(strcmp(names, n)); names{end+1} = n; end
end

function tf = edgeIsPopulated(body, name)
%EDGEISPOPULATED True when the body carries NAME with a non-empty value.
%   Tolerant of all three key spellings the pipeline uses at different
%   stages (`value`, `document_id`, raw v1 `id`).
tf = false;
if ~isfield(body, 'depends_on'); return; end
deps = body.depends_on;
if ~isstruct(deps); return; end
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name); continue; end
    for key = {'value', 'document_id', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            tf = true; return;
        end
    end
end
end

function tf = isVacuous(value)
%ISVACUOUS Present, but carrying nothing -- a struct whose every leaf is
%   blank, recursively. This is the case did2.schema.cache/isEmptyValue
%   misses: it calls a struct empty only when it has NO FIELDNAMES, so an
%   all-blank ontology_term {node:'', name:''} passes a required check.
%
%   A plain empty value ('' or []) is NOT reported here -- the existing
%   validator already catches those, so counting them would drown the
%   signal we are actually after.
tf = false;
if ~isstruct(value) || isempty(value); return; end
fn = fieldnames(value);
if isempty(fn); return; end   % genuinely empty -- the validator sees this
for k = 1:numel(value)
    for f = 1:numel(fn)
        v = value(k).(fn{f});
        if isstruct(v)
            if ~isVacuous(v) && ~(isempty(v) || isempty(fieldnames(v)))
                return;
            end
        elseif ~isempty(v)
            if islogical(v) || isnumeric(v)
                return;   % a real 0/false is a value, not a blank
            end
            if ischar(v) && ~isempty(strtrim(v)); return; end
            if isstring(v) && any(strlength(strtrim(v)) > 0); return; end
        end
    end
end
tf = true;
end

function [keys, counts] = bump(keys, counts, key)
idx = find(strcmp(keys, key), 1);
if isempty(idx)
    keys{end+1} = key; counts(end+1) = 1;
else
    counts(idx) = counts(idx) + 1;
end
end

function out = explode(keys, counts, partNames)
%EXPLODE Split "a|b|c" keys back into a struct array, highest count first.
args = {};
for p = 1:numel(partNames)
    args = [args, partNames(p), {{}}]; %#ok<AGROW>
end
args = [args, {'count'}, {{}}];
out = struct(args{:});     % 0x0 struct array with the right fields
if isempty(keys); return; end
[~, order] = sort(counts, 'descend');
for k = order(:)'
    parts = strsplit(keys{k}, '|');
    entry = struct();
    for p = 1:numel(partNames)
        if p <= numel(parts)
            entry.(partNames{p}) = parts{p};
        else
            entry.(partNames{p}) = '';
        end
    end
    entry.count = counts(k);
    out(end+1) = entry; %#ok<AGROW>
end
end
