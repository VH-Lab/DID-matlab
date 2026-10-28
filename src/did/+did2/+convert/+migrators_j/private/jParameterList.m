function [params, unknown] = jParameterList(s, prefix, nameFn)
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
%
%   [PARAMS, UNKNOWN] = jParameterList(S, PREFIX, NAMEFN) names each entry
%   through NAMEFN instead: [V2NAME, FOUND] = NAMEFN(V1PATH) (e.g.
%   @(n) did2.convert.tuningNames('v2', n), [parameter names map by table],
%   Jess Haley, 2026-10-27). A path NAMEFN does not hold is not written and is
%   listed in UNKNOWN (the caller carries the document).

if nargin < 2; prefix = ''; end
if nargin < 3; nameFn = []; end
params = [];
unknown = {};
if ~isstruct(s) || ~isscalar(s)
    return;
end
fn = fieldnames(s);
entries = {};
for k = 1:numel(fn)
    name = [prefix fn{k}];
    v = s.(fn{k});
    if isstruct(v) && isscalar(v)
        [inner, innerUnknown] = jParameterList(v, [name '.'], nameFn);
        unknown = [unknown, innerUnknown]; %#ok<AGROW>
        if ~isempty(inner)
            entries{end+1} = inner; %#ok<AGROW>
        end
        continue;
    end
    if isempty(v)
        continue;
    end
    if isempty(nameFn)
        var = jLabel(strrep(name, '_', ' '));
    else
        [v2, known] = nameFn(name);
        if ~known
            unknown{end+1} = name; %#ok<AGROW>
            continue;
        end
        var = jLabel(v2);
    end
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        e = did2.build.parameter(var, 'Value', double(v), 'SourceValue', shortestText(double(v)));
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

function t = shortestText(x)
% The shortest decimal text that reads back as exactly X ('0.1', not
% '0.10000000000000001'), so the source value is lossless and readable.
for p = 1:17
    t = sprintf('%.*g', p, x);
    if str2double(t) == x
        return;
    end
end
end
