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
%     skipped_docs                documents whose schema could not be resolved
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
report.empty_dependency_count = sum(depCounts);
report.vacuous_field_count = sum(fldCounts);
end

% ===================== helpers =========================================

function cn = classNameOf(body)
cn = '';
if isfield(body, 'document_class') && isstruct(body.document_class) ...
        && isfield(body.document_class, 'class_name')
    cn = char(body.document_class.class_name);
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
