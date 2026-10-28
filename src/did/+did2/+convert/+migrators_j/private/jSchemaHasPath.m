function tf = jSchemaHasPath(className, steps)
%JSCHEMAHASPATH Does the V2 schema in use declare the field STEPS of class
%   CLASSNAME? (e.g. jSchemaHasPath('tuning_curve', {'value', 'model_fit',
%   'metrics', 'relative_max_gain'})).
%
%   For a migrator whose output needs a field that a did-schema change adds:
%   the field is written only once the schema declares it, so a run against a
%   schema without it carries the document as before instead of writing a
%   document the validator refuses. FALSE when the class or any step is not
%   declared, or the schema cannot be read.

tf = false;
try
    s = did2.schema.cache.shared().getClass(className);
catch
    return;
end
fields = fieldsOf(s);
for k = 1:numel(steps)
    hit = [];
    for j = 1:numel(fields)
        f = fields{j};
        if isstruct(f) && isfield(f, 'name') && strcmp(char(f.name), steps{k})
            hit = f;
            break;
        end
    end
    if isempty(hit)
        return;
    end
    if k < numel(steps)
        fields = fieldsOf(hit);
    end
end
tf = true;
end

function c = fieldsOf(s)
c = {};
if ~isstruct(s) || ~isfield(s, 'fields') || isempty(s.fields)
    return;
end
f = s.fields;
if isstruct(f)
    c = num2cell(reshape(f, 1, []));
elseif iscell(f)
    c = reshape(f, 1, []);
end
end
