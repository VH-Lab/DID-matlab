function [props, values, why] = tuningStatedValues(inputParameters)
%TUNINGSTATEDVALUES The number each `exact_number` selection of a v1
%   tuningcurve_calc fixes a stimulus property at.
%
%   [PROPS, VALUES, WHY] = did2.convert.tuningStatedValues(INPUTPARAMETERS)
%     INPUTPARAMETERS  tuningcurve_calc.input_parameters (a struct); its
%                      `selection` (a struct, a struct array or a cell of
%                      structs, as jsondecode reads it) is searched for the
%                      entries {property, operation 'exact_number', value
%                      <one finite number>}
%   PROPS are the v1 stimulus properties of those selections, in selection
%   order (a 1 x n cellstr; {} when there is none), VALUES the number each
%   states (1 x n double). A property stated twice at one number is listed
%   once. WHY is '' when every such selection was read, else why it could not
%   be (PROPS still lists the selections; VALUES is then []).
%
%   THE DECISION. Decided by Jess Haley, 2026-11-11 [tuning stated value is a
%   condition] (did-schema did_v2_go_forward_class_audit.md): a v1 tuning
%   curve whose writer chose its stimuli with a selection rule fixing a
%   property at a stated number (e.g. tFrequency exact_number 4) has that
%   property and value as a condition on the calculation (temporal frequency
%   = 4), true of every point, exactly as [tuning best value is a condition]
%   (did2.convert.tuningBestValues) does for a value chosen as `best`; the
%   stimid rebuild ([tuning stimids rebuild], did2.convert.tuningStimids)
%   works from that condition. The rule itself stays once, in the v1
%   `selection` setting ([tuning selection rule stated once]).
%
%   THE WRITER (NDI-matlab locked `main` 73f46d1, +ndi/+calc/+stimulus/
%   tuningcurve.m `calculate`): a selection whose operation is not one of the
%   writer's own response checks (hasnumericvalue..., numberatleast) and
%   whose value is none of the words it handles itself ('best', 'greatest',
%   'least', 'deal', 'varies', 'constant', 'not') is passed to the stimulus
%   query as the constraint {field <property>, operation, param1 <value>}, so
%   'exact_number' with a number keeps only the stimuli whose property is
%   exactly that number. The `best` value is read by tuningBestValues, a
%   `deal` value is stim_property_list; a value that is not one finite number
%   (text, an array) is not a stated number and is not read here.
%
%   A curve is not read (WHY says which) when one property is stated at two
%   different numbers (the writer would keep no stimulus).
%
%   See also did2.convert.tuningBestValues, did2.convert.tuningStimids,
%   did2.convert.tuningNames.

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
vals = [];
for k = 1:numel(sel)
    s = sel{k};
    if ~(isstruct(s) && isscalar(s) && isfield(s, 'value') && isfield(s, 'property') ...
            && isfield(s, 'operation'))
        continue;
    end
    op = s.operation;
    if isstring(op) && isscalar(op); op = char(op); end
    if ~(ischar(op) && strcmp(strtrim(op), 'exact_number'))
        continue;
    end
    v = s.value;
    if ~((isnumeric(v) || islogical(v)) && isscalar(v) && isfinite(double(v)))
        continue;
    end
    p = s.property;
    if isstring(p) && isscalar(p); p = char(p); end
    if ~ischar(p) || isempty(strtrim(p))
        why = 'an exact_number selection names no property';
        return;
    end
    p = strtrim(p);
    ix = find(strcmp(p, props), 1);
    if ~isempty(ix)
        if vals(ix) ~= double(v)
            why = sprintf('"%s" is stated at %.17g and at %.17g', p, vals(ix), double(v));
            return;
        end
        continue;
    end
    props{end+1} = p; %#ok<AGROW>
    vals(end+1) = double(v); %#ok<AGROW>
end
if isempty(props)
    return;
end
values = vals;
end
