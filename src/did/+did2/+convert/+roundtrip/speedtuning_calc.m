function [v1, spec] = speedtuning_calc(bodies)
%SPEEDTUNING_CALC Rebuild a v1 `speedtuning_calc` from what
%   did2.convert.migrators_j.speed_tuning_calc emitted when it CONVERTED it: the
%   `speed_tuning_calculation`, its session anchor, and the software entities
%   (calculator, operating system, interpreter) with their version assertions.
%
%   [V1, SPEC] = did2.convert.roundtrip.speedtuning_calc(BODIES). V1 is the
%   document in the shape NDIcalc-vis-matlab ndi.calc.vis.speed_tuning writes
%   it (its stored self-test output, mock/speed_tuning/mock.N.json:
%   calc/speedtuning_calc.json over vision/speed_tuning.json, calculator.json,
%   app.json, base.json):
%
%     identity, `app`, input_parameters   calcParts
%     depends_on                          element_id (entity_id),
%                                         stimulus_tuningcurve_id (input_id)
%     speedtuning_calc.depends_on         restates the top-level
%                                         stimulus_tuningcurve_id
%     speed_tuning                        speedBlock
%
%   The class is spelled as NDIcalc-vis writes it (`speedtuning_calc`); the
%   migrator is +migrators_j/speed_tuning_calc.m (did2.convert.rawV1Classes'
%   table). Its three fit blocks are rebuilt from the model_fit entries'
%   constraints (speedBlock; [Priebe fits are one function], Jess Haley,
%   2026-10-27).
%
%   See also did2.convert.roundtrip.check, speedBlock.

[v1, leaf, ins, spec] = calcParts(bodies, 'speed_tuning_calculation', 'speedtuning_calc', ...
    'ndi.calc.vis.speed', 'Tuning', true);
if isempty(leaf)
    return;
end
[blk, bad] = speedBlock(leaf);
spec.unplaced = [spec.unplaced, bad];
% [spelling is notation] (Jess Haley, 2026-10-26): a recognised response_units
% spelling comes back as its registered term's name (sameTermSpelling)
spec.same(end+1) = struct('path', 'speed_tuning.properties.response_units', ...
    'fn', @sameTermSpelling, 'why', ['equivalent spellings of one registered ' ...
    'term are the same thing ([spelling is notation], Jess Haley, 2026-10-26)']);
v1.speed_tuning = blk;
entity = edgeIds(leaf, 'entity_id');
names = {'element_id'};
values = {''};
if isscalar(entity)
    values = entity;
else
    spec.unplaced{end+1} = sprintf('%d entity_id edges', numel(entity));
end
% [input names rebuild from the input class] (Jess Haley, 2026-10-27)
rebuiltNames = did2.convert.inputEdgeNames(ins, {'stimulus_tuningcurve_id'});
for k = 1:numel(ins)
    if isempty(rebuiltNames{k})
        spec.unplaced{end+1} = sprintf('input_id %s has no v1 edge name', ins{k});
        continue;
    end
    names{end+1} = rebuiltNames{k}; %#ok<AGROW>
    values{end+1} = ins{k}; %#ok<AGROW>
end
v1.depends_on = struct('name', names, 'value', values);
% the calculator block's inner copy names the input only (the writer's
% speedtuning_calc.depends_on: stimulus_tuningcurve_id)
why = ['the calculator block''s inner depends_on copy restates a top-level ' ...
    'edge ([restated values checked], Jess Haley, 2026-10-26)'];
for k = 1:numel(names)
    spec.equivalents(end+1) = struct('path', sprintf('speedtuning_calc.depends_on(%d).name', k), ...
        'values', {names}, 'why', why);
    spec.equivalents(end+1) = struct('path', sprintf('speedtuning_calc.depends_on(%d).value', k), ...
        'values', {values}, 'why', why);
end
end
