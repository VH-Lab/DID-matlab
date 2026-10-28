function [props, values, why] = tuningBestValues(inputParameters, logText)
%TUNINGBESTVALUES The value each `best` selection of a v1 tuningcurve_calc
%   chose, read from the curve's log.
%
%   [PROPS, VALUES, WHY] = did2.convert.tuningBestValues(INPUTPARAMETERS, LOGTEXT)
%     INPUTPARAMETERS  tuningcurve_calc.input_parameters (a struct); its
%                      `selection` (a struct, a struct array or a cell of
%                      structs, as jsondecode reads it) is searched for the
%                      entries whose `value` is the text 'best' (any case, as
%                      the writer compares it)
%     LOGTEXT          tuningcurve_calc.log
%   PROPS are the v1 stimulus properties of those selections, in selection
%   order (a 1 x n cellstr; {} when the curve has no `best` selection), VALUES
%   the value the log states for each (1 x n double). WHY is '' when every
%   `best` selection's value was read, else why it could not be (PROPS still
%   lists the selections; VALUES is then []).
%
%   THE DECISION. Decided by Jess Haley, 2026-10-28 [tuning best value is a
%   condition] (did-schema V_eta_go_forward_class_audit.md): "the angle a v1
%   tuning curve's `angle ... best` selection chose, stored only in its `log`
%   ("angle best value is 90."), becomes a condition on the calculation (e.g.
%   orientation = 90 degrees, true of every point of the curve), and the rule
%   becomes a method parameter (e.g. orientation selection = best); the
%   migration reads the value from the log once, and the stimid rebuild
%   ([tuning stimids rebuild]) works from the conditions) a curve whose log
%   does not state the chosen value is carried as before (carry-056)."
%
%   THE WRITER (NDI-matlab locked `main` 441530d, +ndi/+calc/+stimulus/
%   tuningcurve.m `calculate`): for each selection whose value is 'best' it
%   appends [property ' best value is ' num2str(value) ','] to the log, turns
%   the last ',' into '.', and then appends one 'dealing <p> = <v>,' per dealt
%   property. An older writer wrote 'angle best value is 90.sz_{1}dealing
%   sFrequency = 0.04,'. Both shapes are read: the statement starts the log or
%   follows a ',', and its number is followed by ',', '.' or the end.
%   num2str keeps 4 significant digits after the point, so a value it rounded
%   is read rounded; the stimid rebuild ([tuning stimids rebuild]) then finds
%   no stimulus at it and the curve is carried, never stated wrong.
%
%   A curve is not read (WHY says which) when a `best` property is named twice,
%   when the log states it zero or several times, or when the stated value is
%   not a finite number.
%
%   See also did2.convert.tuningStimids, did2.convert.tuningNames.

props = {};
values = [];
why = '';
sel = [];
if isstruct(inputParameters) && isscalar(inputParameters) ...
        && isfield(inputParameters, 'selection')
    sel = inputParameters.selection;
end
if isstruct(sel)
    sel = num2cell(reshape(sel, 1, []));
elseif ~iscell(sel)
    sel = {};
end
for k = 1:numel(sel)
    s = sel{k};
    if ~(isstruct(s) && isscalar(s) && isfield(s, 'value') && isfield(s, 'property'))
        continue;
    end
    v = s.value;
    if isstring(v) && isscalar(v); v = char(v); end
    if ~(ischar(v) && strcmpi(strtrim(v), 'best'))
        continue;
    end
    p = s.property;
    if isstring(p) && isscalar(p); p = char(p); end
    if ~ischar(p) || isempty(strtrim(p))
        why = 'a best selection names no property';
        return;
    end
    props{end+1} = strtrim(p); %#ok<AGROW>
end
if isempty(props)
    return;
end
if numel(unique(props)) ~= numel(props)
    why = sprintf('two best selections of %s', strjoin(props, ', '));
    return;
end
if isstring(logText) && isscalar(logText); logText = char(logText); end
if ~ischar(logText)
    logText = '';
end
num = '[-+]?(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][-+]?\d+)?|[-+]?Inf|NaN';
vals = zeros(1, numel(props));
for k = 1:numel(props)
    pat = ['(?:^|,)' regexptranslate('escape', props{k}) ' best value is (' num ')(?=[,.]|$)'];
    t = regexp(logText, pat, 'tokens');
    if isempty(t)
        why = sprintf('the log does not state the value the "%s best" selection chose', props{k});
        return;
    end
    if numel(t) > 1
        why = sprintf('the log states the "%s best" value %d times', props{k}, numel(t));
        return;
    end
    x = str2double(t{1}{1});
    if ~isfinite(x)
        why = sprintf('the log states the "%s best" value as %s', props{k}, t{1}{1});
        return;
    end
    vals(k) = x;
end
values = vals;
end
