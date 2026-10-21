function params = jParameterList(s, prefix)
%JPARAMETERLIST A v1 settings struct as did-schema #88 `method.parameters`
%   entries (one `{variable, <one value form>}` per setting).
%
%   PARAMS = jParameterList(S) flattens S (a v1 `input_parameters` block, a
%   sorter's settings, ...): a nested scalar struct contributes its fields as
%   'outer.inner'. Each leaf becomes ONE entry, its variable a label of the
%   setting's v1 name:
%     numeric or logical scalar  -> `quantity` (value, and the source as text)
%     char / string scalar       -> `text`
%     anything else (an array, a struct array, a cell)
%                                -> `text`, the value JSON-encoded
%   The last row is a CONSERVATIVE CHOICE, recorded with the port: #88's entry
%   has no matrix form (V_eta_method_plan.md open follow-up (b)), and text
%   keeps every element rather than dropping the setting. Empty values are
%   skipped (a setting that holds nothing says nothing). [] when S has no
%   settings.

if nargin < 2; prefix = ''; end
params = [];
if ~isstruct(s) || ~isscalar(s)
    return;
end
fn = fieldnames(s);
entries = {};
for k = 1:numel(fn)
    name = [prefix fn{k}];
    v = s.(fn{k});
    if isstruct(v) && isscalar(v)
        inner = jParameterList(v, [name '.']);
        if ~isempty(inner)
            entries{end+1} = inner; %#ok<AGROW>
        end
        continue;
    end
    if isempty(v)
        continue;
    end
    var = did2.build.label(strrep(name, '_', ' '));
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        e = did2.build.parameter(var, 'Value', double(v), 'SourceValue', num2str(double(v), 17));
    elseif ischar(v) && (isrow(v) || isempty(v))
        e = did2.build.parameter(var, 'Text', v);
    elseif isstring(v) && isscalar(v)
        e = did2.build.parameter(var, 'Text', char(v));
    else
        e = did2.build.parameter(var, 'Text', char(jsonencode(v)));
    end
    entries{end+1} = e; %#ok<AGROW>
end
if ~isempty(entries)
    params = did2.build.list(entries{:});
end
end
