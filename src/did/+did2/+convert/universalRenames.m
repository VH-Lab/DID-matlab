function postBody = universalRenames(preBody)
%UNIVERSALRENAMES Apply did_v1 -> V_delta universal renames.
%
%   POSTBODY = did2.convert.universalRenames(PREBODY) returns a copy of
%   PREBODY with the cross-cutting transformations from
%   did-schema/schemas/V_delta/conversions/from_did_v1/_universal_renames.md
%   applied. Per-class migrators run after this pass and assume their
%   input is the semi-V_delta shape produced here.
%
%   Transformations applied:
%
%     - snake_case document_class.class_name (e.g., ontologyImage ->
%       ontology_image) and rename the matching top-level property
%       block key in lockstep.
%     - normalise document_class.superclasses[i] entries: derive
%       class_name from a v1 `definition` path when absent (the
%       basename of the path, stripped of `.json`), and snake_case
%       the result.
%     - field-level snake_case pass inside every class property block
%       (e.g., pyraview.nativeRate -> pyraview.native_rate,
%       pyraview.dataType -> pyraview.data_type). Only the *immediate*
%       field names of each block are renamed; nested struct values
%       (e.g., filter.parameters.sampleFrequency) are left alone for
%       per-class migrators to handle if needed.
%     - rewrite depends_on entries to the V_delta (name,
%       document_id) shape. Accepts v1 (name, id [, version]) and
%       the earlier V_delta draft (name, value); precedence is
%       document_id > value > id when more than one is populated.
%       `version` is always dropped (V_delta does not support
%       per-document version branches). See did-schema#52 for the
%       V_delta-side rename rationale.
%     - rename `app.name` -> `app.app_name` and `app.version` ->
%       `app.app_version` on any document carrying a top-level `app`
%       block. V_delta's `app` schema names these fields with the
%       `app_` prefix; v1 carries the same data under the unprefixed
%       names. Documents whose v1 class did not include the `app`
%       superclass (most non-calc docs) are unaffected.
%     - reconcile legacy `ndi_document` block: pre-base v1 documents
%       carried document-identity fields under `ndi_document` rather
%       than `base`. If a v1 body has `ndi_document` but no `base`,
%       rename `ndi_document` -> `base`. If both are present, discard
%       `ndi_document` (base wins; ndi_document is stale).
%     - default base.schema_version to 'V_delta' when absent so the
%       new V_delta-required field on base is satisfied.
%
%   Field-level renames that change identifiers (not just case) inside
%   a class's property block are class-specific (see the conversion
%   markdowns under did-schema's schemas/V_delta/conversions/from_did_v1/)
%   and are handled by per-class migrators, not here.
%
%   Throws did2:convert:missingDocumentClass when PREBODY has no
%   document_class.class_name.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'document_class') ...
        || ~isstruct(preBody.document_class) ...
        || ~isfield(preBody.document_class, 'class_name')
    error('did2:convert:missingDocumentClass', ...
        'v1 body is missing document_class.class_name.');
end

postBody = preBody;

v1ClassName = char(postBody.document_class.class_name);
v2ClassName = snakeCase(v1ClassName);
v2ClassName = v1ToVDeltaClassName(v2ClassName);
postBody.document_class.class_name = v2ClassName;
if ~strcmp(v1ClassName, v2ClassName) && isfield(postBody, v1ClassName)
    postBody.(v2ClassName) = postBody.(v1ClassName);
    postBody = rmfield(postBody, v1ClassName);
end

if isfield(postBody.document_class, 'superclasses') ...
        && isstruct(postBody.document_class.superclasses) ...
        && ~isempty(postBody.document_class.superclasses)
    postBody.document_class.superclasses = ...
        normaliseSuperclasses(postBody.document_class.superclasses);
end

if isfield(postBody, 'depends_on') ...
        && isstruct(postBody.depends_on) ...
        && ~isempty(postBody.depends_on)
    postBody.depends_on = renameDependsOnEntries(postBody.depends_on);
end

postBody = snakeCasePropertyBlocks(postBody);

if isfield(postBody, 'ndi_document')
    if isfield(postBody, 'base')
        postBody = rmfield(postBody, 'ndi_document');
    else
        postBody.base = postBody.ndi_document;
        postBody = rmfield(postBody, 'ndi_document');
    end
end

if isfield(postBody, 'app') && isstruct(postBody.app) ...
        && isscalar(postBody.app)
    postBody.app = renameAppBlockFields(postBody.app);
end

if isfield(postBody, 'base') && isstruct(postBody.base) ...
        && isscalar(postBody.base) ...
        && ~isfield(postBody.base, 'schema_version')
    postBody.base.schema_version = 'V_delta';
end
end

function block = renameAppBlockFields(block)
% V_delta `app` declares `app_name` and `app_version`; v1 carries the
% same data under `name` and `version`. Apply the rename whenever a
% v1 document ships an `app` block, regardless of its concrete class.
% (7 v1 classes in the 20211116 corpus carry an app block: every
% calculator class plus jrclust_clusters, neuron_extracellular,
% stimulus_presentation, control_stimulus_ids.)
if isfield(block, 'name') && ~isfield(block, 'app_name')
    block.app_name = block.name;
    block = rmfield(block, 'name');
elseif isfield(block, 'name')
    block = rmfield(block, 'name');
end
if isfield(block, 'version') && ~isfield(block, 'app_version')
    block.app_version = block.version;
    block = rmfield(block, 'version');
elseif isfield(block, 'version')
    block = rmfield(block, 'version');
end
end

function out = v1ToVDeltaClassName(name)
% Map v1 class names that drift from V_delta's underscore-separated
% canonical form. v1 occasionally drops the underscore between
% adjacent words in a calc class name (e.g., `contrasttuning_calc`
% instead of `contrast_tuning_calc`); V_delta keeps the
% underscored convention to match the NDI calculator class
% hierarchy (`ndi.calc.vis.contrast_tuning`, etc.). This rename
% pass bridges the two without forcing V_delta names to be
% inconsistent.
table = { ...
    'contrasttuning_calc',      'contrast_tuning_calc'; ...
    'contrastsensitivity_calc', 'contrast_sensitivity_calc'};
for k = 1:size(table, 1)
    if strcmp(name, table{k, 1})
        out = table{k, 2};
        return;
    end
end
out = name;
end

function out = snakeCase(name)
% Acronym-aware snake_case.
%
% A run of two or more consecutive uppercase letters is treated as a
% single acronym and lowercased without internal underscores
% ('sensitivity_RBNS' -> 'sensitivity_rbns'; 'XMLParser' ->
% 'xml_parser'). The conventional camelCase boundary (lowercase
% followed by uppercase, or acronym followed by mixed-case word) is
% preserved.
%
% Specifically, an uppercase letter at position k inserts a `_`
% before its lowercased form if EITHER:
%   - the previous input char is not uppercase (classic camelCase
%     boundary, e.g., 'data' -> 'T'), OR
%   - the previous input char IS uppercase AND the next input char
%     is lowercase (acronym -> word transition, e.g., 'XML' -> 'P'
%     in 'XMLParser')
% otherwise the uppercase letter is appended without a separator
% (continuing an acronym, or sitting just after an existing `_`).
name = char(name);
n = numel(name);
if n == 0
    out = name;
    return;
end
result = lower(name(1));
for k = 2:n
    c = name(k);
    isUpper = c >= 'A' && c <= 'Z';
    if ~isUpper
        result = [result, c]; %#ok<AGROW>
        continue;
    end
    prev = name(k-1);
    prevUpper = prev >= 'A' && prev <= 'Z';
    nextLower = (k < n) && (name(k+1) >= 'a' && name(k+1) <= 'z');
    needSep = (~prevUpper || (prevUpper && nextLower)) ...
        && result(end) ~= '_';
    if needSep
        result = [result, '_', char(c + ('a' - 'A'))]; %#ok<AGROW>
    else
        result = [result, char(c + ('a' - 'A'))]; %#ok<AGROW>
    end
end
out = result;
end

function out = normaliseSuperclasses(sc)
% Make sure each superclass entry has a class_name field, deriving it
% from a v1 `definition` path (e.g., $NDIDOCUMENTPATH/data/filter.json
% -> filter) when absent. snake_case any class_name found.
names = cell(1, numel(sc));
for k = 1:numel(sc)
    if isfield(sc(k), 'class_name') && ~isempty(sc(k).class_name)
        names{k} = snakeCase(char(sc(k).class_name));
    elseif isfield(sc(k), 'definition') && ~isempty(sc(k).definition)
        names{k} = snakeCase(deriveClassNameFromDefinition(sc(k).definition));
    else
        names{k} = '';
    end
end
out = struct('class_name', names);
end

function name = deriveClassNameFromDefinition(definition)
[~, name, ~] = fileparts(char(definition));
end

function postBody = snakeCasePropertyBlocks(postBody)
% Rename top-level property-block keys to snake_case (so v1
% inherited blocks with camelCase names like `imageStack_parameters`
% match V_delta's snake-cased class names), and rename camelCase
% field names inside each block to snake_case. Structural keys
% (document_class, depends_on, file, files) are skipped.
skip = {'document_class', 'depends_on', 'file', 'files'};
topKeys = fieldnames(postBody);
% First pass: snake_case top-level block keys for any property
% block whose value is a struct. (The concrete-class block key has
% already been moved by the caller; this catches inherited blocks
% like the v1 `imageStack_parameters` parent of `imageStack`.)
for k = 1:numel(topKeys)
    key = topKeys{k};
    if any(strcmp(key, skip))
        continue;
    end
    value = postBody.(key);
    if ~isstruct(value) || ~isscalar(value)
        continue;
    end
    snakeKey = snakeCase(key);
    if ~strcmp(snakeKey, key)
        if isfield(postBody, snakeKey)
            % Snake-case form already exists; drop the camel
            % duplicate to avoid clobbering.
            postBody = rmfield(postBody, key);
        else
            postBody.(snakeKey) = value;
            postBody = rmfield(postBody, key);
        end
    end
end
% Second pass: snake_case the field names inside each property
% block.
topKeys = fieldnames(postBody);
for k = 1:numel(topKeys)
    key = topKeys{k};
    if any(strcmp(key, skip))
        continue;
    end
    value = postBody.(key);
    if ~isstruct(value) || ~isscalar(value)
        continue;
    end
    postBody.(key) = snakeCaseBlockFields(value);
end
end

function block = snakeCaseBlockFields(block)
fns = fieldnames(block);
for k = 1:numel(fns)
    fn = fns{k};
    sc = snakeCase(fn);
    if ~strcmp(fn, sc)
        if isfield(block, sc)
            % A snake_case field already exists; keep it and drop the
            % camelCase duplicate to avoid clobbering.
            block = rmfield(block, fn);
        else
            block.(sc) = block.(fn);
            block = rmfield(block, fn);
        end
    end
end
end

function out = renameDependsOnEntries(entries)
%RENAMEDEPENDSONENTRIES Migrate depends_on entries to the V_delta shape.
%
%   V_delta entries carry `name` and `document_id`. Accepts three
%   input shapes and normalises to V_delta:
%     - v1 (V_alpha): {name, id [, version]}        - id -> document_id
%     - old V_delta draft: {name, value}             - value -> document_id
%     - current V_delta: {name, document_id}         - identity
%
%   When multiple legacy keys are present (an in-flight migration
%   that already wrote a value but left the v1 id behind), the
%   precedence is: document_id wins if non-empty, else value,
%   else id. `version` is always dropped (V_delta does not
%   support per-document version branches).
out = entries;

hasId        = isfield(out, 'id');
hasValue     = isfield(out, 'value');
hasDocId     = isfield(out, 'document_id');

if ~hasId && ~hasValue && ~hasDocId
    return;
end

n = numel(out);
docIds = cell(1, n);
for k = 1:n
    if hasDocId && ~isempty(out(k).document_id)
        docIds{k} = out(k).document_id;
    elseif hasValue && ~isempty(out(k).value)
        docIds{k} = out(k).value;
    elseif hasId
        docIds{k} = out(k).id;
    else
        docIds{k} = '';
    end
end

% Drop the legacy keys so the struct array's field schema is
% exactly {name, document_id} after the migration.
if hasId
    out = rmfield(out, 'id');
end
if hasValue
    out = rmfield(out, 'value');
end
if isfield(out, 'version')
    out = rmfield(out, 'version');
end

for k = 1:n
    out(k).document_id = docIds{k};
end
end
