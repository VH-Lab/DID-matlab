function [s, bad] = methodParameters(params)
%METHODPARAMETERS A v1 `input_parameters` struct rebuilt from a method's
%   parameter entries (the inverse of +migrators_j/private/jParameterList).
%
%   [S, BAD] = methodParameters(PARAMS). PARAMS is `method.parameters` (a
%   struct array, a cell, or empty). jParameterList wrote one entry per
%   non-empty v1 field, named by its path with '_' as ' ' and nested fields
%   joined by '.', valued by:
%     quantity.value   a numeric or logical scalar (read back as the number)
%     text             a text value, or any other value as its JSON text
%                      (a struct array such as tuningcurve_calc's `selection`,
%                      a numeric vector): text that is a JSON array or object
%                      is read back with jsondecode
%   The name is read back with ' ' as '_', the spelling every NDI calculator
%   parameter has (a field name with a space cannot be a MATLAB field). An
%   entry in another form (term, count, matrix, logical) is not one
%   jParameterList writes: it is listed in BAD.

s = struct();
bad = {};
if isempty(params)
    return;
end
if isstruct(params)
    params = num2cell(reshape(params, 1, []));
end
for k = 1:numel(params)
    e = params{k};
    [~, name] = termParts(getIn(e, 'variable'));
    if isempty(name)
        bad{end+1} = sprintf('method parameter %d has no name', k); %#ok<AGROW>
        continue;
    end
    if isfield(e, 'quantity') && isstruct(e.quantity) && isfield(e.quantity, 'value')
        v = e.quantity.value;
    elseif isfield(e, 'text')
        v = char(e.text);
        if ~isempty(v) && any(v(1) == '[{')
            try
                v = jsondecode(v);
            catch
                % not JSON: the text itself
            end
        end
    else
        bad{end+1} = sprintf('method parameter "%s" is not a number or text', name); %#ok<AGROW>
        continue;
    end
    steps = strsplit(strrep(name, ' ', '_'), '.');
    s = setPath(s, steps, v);
end
end

function s = setPath(s, steps, v)
%SETPATH S with S.(STEPS{1}).(STEPS{2})... set to V.
if isscalar(steps)
    s.(steps{1}) = v;
    return;
end
inner = struct();
if isfield(s, steps{1}) && isstruct(s.(steps{1})) && isscalar(s.(steps{1}))
    inner = s.(steps{1});
end
s.(steps{1}) = setPath(inner, steps(2:end), v);
end
