function result = resolveDatasetEntities(result, options)
%RESOLVEDATASETENTITIES DID-only post-pass that finalizes the dataset entity layer.
%
%   RESULT = did2.convert.resolveDatasetEntities(RESULT) takes the struct
%   returned by did2.convert.v1_to_v2 (after resolveDeferredBaths) and does two
%   batch-level fixups the per-document migrators cannot:
%
%     1. DEDUPLICATE dataset entities. Every dataset-level source
%        (metadata_editor / dataset_remote / session_in_a_dataset /
%        dataset_session_info) mints a `dataset` entity keyed on the SAME dataset
%        id (D.id() = base.session_id), so a dataset with several such docs yields
%        several `dataset` entities with one shared base.id. This pass keeps ONE
%        per id -- the RICHEST (most populated dataset fields + global_identifiers,
%        so the metadata_editor dataset wins over a bare stub) -- and drops the
%        rest. Result: every dataset ends with exactly one canonical entity.
%
%     2. PRUNE unresolvable session-membership edges. session_in_a_dataset /
%        dataset_session_info emit `session -part_of-> dataset` best-effort; a
%        member session that is LINKED (its documents live in a separate session
%        db, not this batch) would leave the edge's child dangling. This pass drops
%        any `migrated_session_membership` relation whose child id is not present
%        in the batch -- the same honest best-effort stance as resolveDeferredBaths
%        (an unresolved membership is dropped rather than orphaning the corpus).
%        The precise, always-resolvable wiring is the ndi.migrate second pass,
%        which has the full session graph.
%
%   Idempotent and safe on inputs with no dataset entities. Options mirror the
%   sibling passes (Validate / SchemaCache / TargetVersion) for signature
%   symmetry; this pass only removes documents, so it does not re-validate.
%
%   See also: did2.convert.v1_to_v2, did2.convert.resolveDeferredBaths,
%   did2.convert.migrators_j.metadata_editor.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true %#ok<INUSA>
    options.SchemaCache = [] %#ok<INUSA>
    options.TargetVersion (1,:) char = 'V_eta' %#ok<INUSA>
end

if ~isfield(result, 'migrated') || isempty(result.migrated)
    return;
end
docs = result.migrated;
n = numel(docs);
keep = true(1, n);

% --- pass 1: index doc ids present + pick the richest dataset per id ----------
idsPresent = containers.Map('KeyType', 'char', 'ValueType', 'logical');
bestDatasetIdx = containers.Map('KeyType', 'char', 'ValueType', 'double');
bestDatasetRichness = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    id = char(docs{k}.get('base.id'));
    idsPresent(id) = true;
    if ~strcmp(docs{k}.className(), 'dataset'); continue; end
    r = datasetRichness(docs{k});
    if isKey(bestDatasetIdx, id)
        if r > bestDatasetRichness(id)
            keep(bestDatasetIdx(id)) = false;   % a poorer duplicate loses
            bestDatasetIdx(id) = k; bestDatasetRichness(id) = r;
        else
            keep(k) = false;
        end
    else
        bestDatasetIdx(id) = k; bestDatasetRichness(id) = r;
    end
end

% --- pass 2: drop best-effort membership edges whose member session is absent -
for k = 1:n
    if ~keep(k); continue; end
    doc = docs{k};
    if ~strcmp(doc.className(), 'directed_relation'); continue; end
    if ~strcmp(char(getBaseName(doc)), 'migrated_session_membership'); continue; end
    childId = depValueOf(doc, 'child');
    if isempty(childId) || ~isKey(idsPresent, childId)
        keep(k) = false;   % linked session not in this batch -> drop the edge
    end
end

result.migrated = docs(keep);
result.summary = recountSummary(result);
end

% ===================== helpers =========================================

function r = datasetRichness(doc)
%DATASETRICHNESS Non-empty dataset fields + global_identifier entries.
r = 0;
try
    ds = doc.get('dataset');
    if isstruct(ds)
        fn = fieldnames(ds);
        for i = 1:numel(fn)
            v = ds.(fn{i});
            if (ischar(v) || isstring(v)) && ~isempty(char(v)); r = r + 1; end
        end
    end
catch
end
try
    g = doc.get('entity.global_identifier');
    r = r + numel(g);
catch
end
end

function name = getBaseName(doc)
name = '';
try
    name = doc.get('base.name');
catch
end
end

function v = depValueOf(doc, name)
v = '';
try
    deps = doc.get('depends_on');
catch
    return;
end
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
