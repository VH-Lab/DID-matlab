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
%   table). A document with more than one fit block is carried (its fits would
%   all be named 'Priebe fit'), so a converted one has one: `fit`.
%
%   See also did2.convert.roundtrip.check, speedBlock.

[v1, leaf, ins, spec] = calcParts(bodies, 'speed_tuning_calculation', 'speedtuning_calc', ...
    'ndi.calc.vis.speed');
if isempty(leaf)
    return;
end
[blk, bad] = speedBlock(leaf);
spec.unplaced = [spec.unplaced, bad];
v1.speed_tuning = blk;
entity = edgeIds(leaf, 'entity_id');
names = {'element_id'};
values = {''};
if isscalar(entity)
    values = entity;
else
    spec.unplaced{end+1} = sprintf('%d entity_id edges', numel(entity));
end
if ~isempty(ins)
    names{end+1} = 'stimulus_tuningcurve_id';
    values{end+1} = ins{1};
end
for k = 2:numel(ins)
    spec.unplaced{end+1} = sprintf('input_id %s has no v1 edge name', ins{k});
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
