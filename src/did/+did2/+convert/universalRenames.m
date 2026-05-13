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
%     - snake_case any document_class.superclasses[i].class_name.
%     - rewrite depends_on entries from the V_alpha (name, id [,
%       version]) shape to the V_delta (name, value) shape. An
%       existing non-empty `value` is preserved; the `id` and
%       `version` keys are removed.
%     - default base.schema_version to 'V_delta' when absent so the
%       new V_delta-required field on base is satisfied.
%
%   Field-level renames inside a class's property block are
%   class-specific (see the conversion markdowns under did-schema's
%   schemas/V_delta/conversions/from_did_v1/) and are not handled here.
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
postBody.document_class.class_name = v2ClassName;
if ~strcmp(v1ClassName, v2ClassName) && isfield(postBody, v1ClassName)
    postBody.(v2ClassName) = postBody.(v1ClassName);
    postBody = rmfield(postBody, v1ClassName);
end

if isfield(postBody.document_class, 'superclasses') ...
        && isstruct(postBody.document_class.superclasses) ...
        && ~isempty(postBody.document_class.superclasses)
    sc = postBody.document_class.superclasses;
    for k = 1:numel(sc)
        if isfield(sc(k), 'class_name')
            sc(k).class_name = snakeCase(char(sc(k).class_name));
        end
    end
    postBody.document_class.superclasses = sc;
end

if isfield(postBody, 'depends_on') ...
        && isstruct(postBody.depends_on) ...
        && ~isempty(postBody.depends_on)
    postBody.depends_on = renameDependsOnEntries(postBody.depends_on);
end

if isfield(postBody, 'base') && isstruct(postBody.base) ...
        && isscalar(postBody.base) ...
        && ~isfield(postBody.base, 'schema_version')
    postBody.base.schema_version = 'V_delta';
end
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
