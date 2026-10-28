function report = entityRequires(docs, opts)
%ENTITYREQUIRES REPORT-ONLY census of the entity-type `requires` fields.
%
%   REPORT = did2.validate.entityRequires(DOCS) counts, per entity type and per
%   field that binding_registry_meta.json's `entity_type_bindings` row for that
%   type `requires` (a session requires `local_identifier`, a person `name`, ...),
%   how many entities of that type were inspected and how many leave the field
%   blank. It QUARANTINES NOTHING and raises nothing: Jess Haley, 2026-10-21
%   ("b") -- the check is report-only first; arming it as a quarantining check
%   is a later decision, taken once a corpus run has given the count.
%
%   DOCS: did2.document objects or body structs (cell or array).
%   Options:
%     'SchemaCache'  a did2.schema.cache ([] = did2.schema.cache.shared())
%
%   ONE OF SEVERAL FIELDS. A requirement may name alternatives, any one of
%   which satisfies it, written 'a|b' in the report's `field`:
%     - a registry row's `requires_one_of`, a list of field lists (each list
%       one requirement), read when the row has it;
%     - [organization needs a name or an identifier] (Decided by Jess Haley,
%       2026-10-27, did-schema V_eta_go_forward_class_audit.md): "an
%       `organization` entity requires at least one of `name` and
%       `global_identifier`, not `name` alone, so an NDI Cloud organization
%       known only by `ndicloud:<id>` ... is valid". Built here first (the
%       decision's order: the DID-matlab rule, then did-schema's
%       entity_type_bindings): an organization row's `name` requirement reads
%       as `name|global_identifier` (ALTERNATIVES below) until the registry
%       states it.
%
%   REPORT, denominator first:
%     docs_inspected, docs_unreadable   every document handed in
%     entities_inspected                of those, `entity` documents
%     entities_untyped                  entities whose entity.type names nothing
%     entities_type_without_row         entities whose type has no registry row
%     registry_rows                     entity_type_bindings rows read
%     missing_total                     sum of `missing` below
%     by_type_field                     struct array {entity_type, field,
%                                       inspected, missing, missing_ids (first 20)}
%     registry_unavailable              true when no registry could be read
%                                       (every count is then NOT MEASURED)

arguments
    docs
    opts.SchemaCache = []
end

report = struct( ...
    'docs_inspected',            0, ...
    'docs_unreadable',           0, ...
    'entities_inspected',        0, ...
    'entities_untyped',          0, ...
    'entities_type_without_row', 0, ...
    'registry_rows',             0, ...
    'missing_total',             0, ...
    'by_type_field',             struct('entity_type', {}, 'field', {}, ...
                                        'inspected', {}, 'missing', {}, 'missing_ids', {}), ...
    'registry_unavailable',      false);

[bodies, unreadable] = vBodies(docs);
report.docs_inspected = numel(bodies) + unreadable;
report.docs_unreadable = unreadable;

rows = registryRows(opts.SchemaCache);
if isempty(rows)
    report.registry_unavailable = true;
end
report.registry_rows = numel(rows);
requiresByType = containers.Map('KeyType', 'char', 'ValueType', 'any');
typeByNode = containers.Map('KeyType', 'char', 'ValueType', 'char');
for r = 1:numel(rows)
    req = {};
    if isfield(rows{r}, 'requires') && ~isempty(rows{r}.requires)
        req = cellstr(rows{r}.requires);
    end
    req = reshape(req, 1, []);
    alt = ALTERNATIVES();
    ty = lower(char(rows{r}.type));
    for a = 1:size(alt, 1)
        if strcmp(ty, alt{a, 1})
            req(strcmp(req, alt{a, 2})) = {strjoin(alt{a, 3}, '|')};
        end
    end
    if isfield(rows{r}, 'requires_one_of') && ~isempty(rows{r}.requires_one_of)
        groups = rows{r}.requires_one_of;
        if ~iscell(groups); groups = {groups}; end
        for g = 1:numel(groups)
            req{end+1} = strjoin(cellstr(groups{g}), '|'); %#ok<AGROW>
        end
        req = unique(req, 'stable');
    end
    requiresByType(ty) = req;
    % the row's node too: an entity is matched BY NODE (Jess Haley 2026-10-22
    % [vocabulary nodes] L2), its stored name being the ontology label
    if isfield(rows{r}, 'node') && ~isempty(strtrim(char(rows{r}.node)))
        typeByNode(lower(strtrim(char(rows{r}.node)))) = lower(char(rows{r}.type));
    end
end

idx = containers.Map('KeyType', 'char', 'ValueType', 'double');   % type|field -> row
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isstruct(b) || ~isfield(b, 'document_class') ...
            || ~strcmp(char(b.document_class.class_name), 'entity') ...
            || ~isfield(b, 'entity') || ~isstruct(b.entity)
        continue;
    end
    report.entities_inspected = report.entities_inspected + 1;
    t = '';
    if isfield(b.entity, 'type') && isstruct(b.entity.type) && isfield(b.entity.type, 'node') ...
            && isKey(typeByNode, lower(strtrim(char(b.entity.type.node))))
        t = typeByNode(lower(strtrim(char(b.entity.type.node))));
    elseif isfield(b.entity, 'type') && isstruct(b.entity.type) && isfield(b.entity.type, 'name')
        t = lower(strtrim(char(b.entity.type.name)));
    end
    if isempty(t)
        report.entities_untyped = report.entities_untyped + 1;
        continue;
    end
    if ~isKey(requiresByType, t)
        report.entities_type_without_row = report.entities_type_without_row + 1;
        continue;
    end
    req = requiresByType(t);
    for f = 1:numel(req)
        key = [t '|' req{f}];
        if ~isKey(idx, key)
            report.by_type_field(end+1) = struct('entity_type', t, 'field', req{f}, ...
                'inspected', 0, 'missing', 0, 'missing_ids', {{}});
            idx(key) = numel(report.by_type_field);
        end
        i = idx(key);
        report.by_type_field(i).inspected = report.by_type_field(i).inspected + 1;
        if all(cellfun(@(x) isBlank(b.entity, x), strsplit(req{f}, '|')))
            report.by_type_field(i).missing = report.by_type_field(i).missing + 1;
            report.missing_total = report.missing_total + 1;
            if numel(report.by_type_field(i).missing_ids) < 20
                id = '';
                if isfield(b, 'base') && isfield(b.base, 'id'); id = char(b.base.id); end
                report.by_type_field(i).missing_ids{end+1} = id;
            end
        end
    end
end
end

function a = ALTERNATIVES()
% {entity type, required field, the fields any one of which satisfies it}
a = {'organization', 'name', {'name', 'global_identifier'}};
end

function rows = registryRows(cache)
rows = {};
try
    if isempty(cache); cache = did2.schema.cache.shared(); end
    reg = cache.bindingRegistry;
catch
    return;
end
if ~isstruct(reg) || ~isfield(reg, 'entity_type_bindings'); return; end
e = reg.entity_type_bindings;
if isstruct(e); rows = num2cell(e(:)'); elseif iscell(e); rows = e(:)'; end
rows = rows(cellfun(@(r) isstruct(r) && isfield(r, 'type'), rows));
end

function tf = isBlank(s, name)
tf = true;
if ~isfield(s, name); return; end
v = s.(name);
if iscell(v)
    tf = isempty(v) || all(cellfun(@(x) (ischar(x) || isstring(x)) && isempty(strtrim(char(x))), v));
elseif ischar(v) || (isstring(v) && isscalar(v))
    tf = isempty(strtrim(char(v)));
elseif isstruct(v)
    tf = isempty(v) || (isfield(v, 'name') && isempty(strtrim(char(v.name))) ...
        && (~isfield(v, 'node') || isempty(strtrim(char(v.node)))));
else
    tf = isempty(v);
end
end
