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
%     - rewrite depends_on entries from the V_alpha (name, id [,
%       version]) shape to the V_delta (name, value) shape. An
%       existing non-empty `value` is preserved; the `id` and
%       `version` keys are removed.
%     - rename `app.name` -> `app.app_name` and `app.version` ->
%       `app.app_version` on any document carrying a top-level `app`
%       block. V_delta's `app` schema names these fields with the
%       `app_` prefix; v1 carries the same data under the unprefixed
%       names. Documents whose v1 class did not include the `app`
%       superclass (most non-calc docs) are unaffected.
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
name = char(name);
if isempty(name)
    out = name;
    return;
end
result = name(1);
for k = 2:numel(name)
    c = name(k);
    isUpper = c >= 'A' && c <= 'Z';
    if isUpper && result(end) ~= '_'
        result = [result, '_', char(c + ('a' - 'A'))]; %#ok<AGROW>
    elseif isUpper
        result = [result, char(c + ('a' - 'A'))]; %#ok<AGROW>
    else
        result = [result, c]; %#ok<AGROW>
    end
end
if ~isempty(result) && result(1) >= 'A' && result(1) <= 'Z'
    result(1) = char(result(1) + ('a' - 'A'));
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
% Rename camelCase field names inside every class property block to
% snake_case. The property blocks are scalar struct values at the
% document top level; structural keys are skipped.
skip = {'document_class', 'depends_on', 'file', 'files'};
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
out = entries;
if ~isfield(out, 'id')
    return;
end
ids = {out.id};
if isfield(out, 'value')
    values = {out.value};
else
    values = repmat({''}, 1, numel(out));
end
for k = 1:numel(out)
    if isempty(values{k})
        values{k} = ids{k};
    end
end
out = rmfield(out, 'id');
if isfield(out, 'version')
    out = rmfield(out, 'version');
end
for k = 1:numel(out)
    out(k).value = values{k};
end
end
