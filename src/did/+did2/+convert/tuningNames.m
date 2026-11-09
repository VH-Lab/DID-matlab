function [out, found] = tuningNames(direction, name)
%TUNINGNAMES The ONE name table between v1 tuning and response names and the
%   v2 variables they become.
%
%   [V2NAME, FOUND] = did2.convert.tuningNames('v2', V1NAME)
%   [V1NAME, FOUND] = did2.convert.tuningNames('v1', V2NAME)
%   T = did2.convert.tuningNames('table')    the table, {v1 name, v2 name; ...}
%
%   FOUND is false (and the output '') for a name the table does not hold.
%
%   THE DECISIONS (Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md):
%     [varied properties are conditions by V2 name] ("35 b"): each property in
%       a tuning curve's `stim_property_list` becomes a condition whose
%       variable is the variable the v2 stimulus `method` uses (e.g.
%       `sFrequency` -> "spatial frequency", NDI `stimulusRecipe.m`), through a
%       name table; a v1 name missing from the table carries the curve.
%     [parameter names map by table] ("38 yes"): v1 settings names (e.g.
%       `prestimulus_time`) become v2 method parameter variables through the
%       same name table; the round trip maps back; a v1 name missing from the
%       table carries the document.
%
%   THE STIMULUS ROWS are NDI-matlab's own (V2 line, locked head a2ab2d1,
%   +ndi/+migrate/+internal/stimulusRecipe.m periodicRows and gratingRecipe.m,
%   which write the v2 stimulus `method` of a NewStim periodicstim): the v1
%   NewStim field name and the variable that method gives it. Two of NDI's rows
%   are NOT here:
%     sPhaseShift  NDI's method writes it in DEGREES, converted from v1's
%                  radians; a condition copies the v1 value, so the same name
%                  would hold a different unit. Not listed: a curve dealing
%                  sPhaseShift is carried.
%     randState    a seed (NCIT:C64220), never a tuning property.
%
%   THE SETTINGS ROWS are the settings the tuning and response writers write
%   (NDI-matlab locked `main` +ndi/+calc/+stimulus/tuningcurve.m
%   input_parameters, +ndi/+app/+stimulus/tuning_response.m's response
%   parameters; NDIcalc-vis-matlab 00e3e0f ndi.calc.vis.speed_tuning
%   min_xi / max_xi). No v2 name was decided for them, so each keeps the
%   variable the migration already wrote (the v1 name, '_' as ' '; a nested
%   setting joined by '.', jParameterList): the table pins those names and is
%   what the round trip maps back through. A nested `selection` holds its
%   three fields; a `selection` array is one text entry. The corpora's
%   tuningcurve_calc documents also hold `input_parameters.depends_on`
%   {name, value} (every one of the 84 in 20211116 and the 34,606 in Soph,
%   measured 2026-10-27 by a MATLAB scratch run of this branch): an earlier
%   writer's copy of its input edge, kept under the same labels.
%
%   [term picks batch 3] (Jess Haley, 2026-11-09, did-schema
%   did_v2_go_forward_class_audit.md): three settings take registered terms:
%     independent_parameter  'Independent Variable', NCIT:C191277
%     best_algorithm         'Algorithm', NCIT:C16275 (the value, e.g.
%                            empirical_maximum, is text)
%     selection              'selection criterion', OBI:0001755 (a
%                            `selection` array, one text entry; a nested
%                            `selection`'s three fields keep their names,
%                            which the decision does not cover)
%   `independent_label` keeps its row: the decision says it is not written
%   and the round trip rebuilds it, which is not built yet (see the DID-matlab
%   PR for [term picks batch 3]).
%
%   TWO ROWS NAME REGISTERED TERMS (Jess Haley, 2026-11-03, "Ok" to Claude's
%   answers on docs/V2_PLAN.md G96; did-schema term registry rows):
%     angle          'Direction', NCIT:C42677: the 0-360 direction of motion
%                    (NDI's stimulus method writes 'orientation'; a tuning
%                    `angle` runs 0-360, so it is a direction)
%     spiketrain_dt  'bin width', EMPTY:0000308: the step at which spike times
%                    are binned into a train
%   The names resolve to their nodes through the registry
%   (did2.convert.registeredTerm by name).
%
%   See also did2.convert.tuningStimids, did2.convert.resolveResponseParameters.

arguments
    direction (1,:) char {mustBeMember(direction, {'v1', 'v2', 'table'})}
    name = ''
end

T = table_();
out = '';
found = false;
switch direction
    case 'table'
        out = T;
        found = true;
    case 'v2'
        ix = find(strcmp(T(:, 1), char(name)), 1);
        if ~isempty(ix)
            out = T{ix, 2};
            found = true;
        end
    case 'v1'
        ix = find(strcmpi(T(:, 2), char(name)), 1);
        if ~isempty(ix)
            out = T{ix, 1};
            found = true;
        end
end
end

function T = table_()
persistent cached
if ~isempty(cached)
    T = cached;
    return;
end
stimulus = { ...
    'angle',          'Direction'; ...
    'sFrequency',     'spatial frequency'; ...
    'tFrequency',     'temporal frequency'; ...
    'contrast',       'contrast'; ...
    'imageType',      'image type'; ...
    'animType',       'animation type'; ...
    'flickerType',    'flicker type'; ...
    'chromhigh',      'high colour'; ...
    'chromlow',       'low colour'; ...
    'distance',       'viewing distance'; ...
    'barWidth',       'bar width'; ...
    'rect',           'stimulus rectangle'; ...
    'nCycles',        'cycle count'; ...
    'background',     'background'; ...
    'backdrop',       'backdrop'; ...
    'barColor',       'bar colour'; ...
    'nSmoothPixels',  'smoothing width'; ...
    'fixedDur',       'fixed duration'; ...
    'windowShape',    'window shape'; ...
    'loops',          'loop count'; ...
    'lineoffset',     'line offset'; ...
    'linenumber',     'line number'; ...
    'stimnum',        'stimulus number'};
settings = { ...
    'independent_label',          'independent label'; ...
    'independent_parameter',      'Independent Variable'; ...
    'best_algorithm',             'Algorithm'; ...
    'selection',                  'selection criterion'; ...
    'selection.property',         'selection.property'; ...
    'selection.operation',        'selection.operation'; ...
    'selection.value',            'selection.value'; ...
    'depends_on',                 'depends on'; ...
    'depends_on.name',            'depends on.name'; ...
    'depends_on.value',           'depends on.value'; ...
    'min_xi',                     'min xi'; ...
    'max_xi',                     'max xi'; ...
    'temporalfreqfunc',           'temporalfreqfunc'; ...
    'prestimulus_time',           'prestimulus time'; ...
    'prestimulus_normalization',  'prestimulus normalization'; ...
    'isspike',                    'isspike'; ...
    'spiketrain_dt',              'bin width'};
T = [stimulus; settings];
cached = T;
end
