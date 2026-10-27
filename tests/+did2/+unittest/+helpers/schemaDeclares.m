function tf = schemaDeclares(className, steps)
%SCHEMADECLARES Does the V2 schema in use declare the field STEPS (a cellstr
%   path of field names) of class CLASSNAME? For a test whose expectation
%   changes when a did-schema change lands (e.g. [contrast metrics added],
%   Jess Haley, 2026-10-27: the fit entry's relative_max_gain, saturation_index
%   and sensitivity, written by the migrators only once the schema declares
%   them). False when the class or a step is not declared.
%
%   tf = did2.unittest.helpers.schemaDeclares('tuning_curve', ...
%       {'value', 'model_fit', 'metrics', 'relative_max_gain'})
arguments
    className (1,:) char
    steps cell
end
tf = false;
try
    f = did2.schema.cache.shared().getClass(className);
catch
    return;
end
for k = 1:numel(steps)
    if ~isfield(f, 'fields') || isempty(f.fields)
        return;
    end
    fs = f.fields;
    if isstruct(fs); fs = num2cell(reshape(fs, 1, [])); end
    hit = [];
    for j = 1:numel(fs)
        if isstruct(fs{j}) && isfield(fs{j}, 'name') && strcmp(char(fs{j}.name), steps{k})
            hit = fs{j};
            break;
        end
    end
    if isempty(hit)
        return;
    end
    f = hit;
end
tf = true;
end
