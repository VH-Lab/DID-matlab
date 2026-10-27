function [v1, spec] = speed_tuning(bodies)
%SPEED_TUNING Rebuild a v1 `speed_tuning` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.speed_tuning(BODIES). V1 is the
%   document in its v1 shape (NDIcalc-vis-matlab 00e3e0f,
%   vision/speed_tuning.json over NDI's base.json, as ndi.calc.vis.speed_tuning
%   calculate_speed_indexes writes it: the result block, then element_id and
%   stimulus_tuningcurve_id; no `app` block). BODIES holds the
%   `speed_tuning_calculation` (id preserved), the session anchor and the
%   software entity jCalculation mints for ndi.calc.vis.speed:
%
%     identity                     calcParts (no `app`: the minted software
%                                  entity writes none)
%     depends_on                   element_id (entity_id),
%                                  stimulus_tuningcurve_id (input_id)
%     speed_tuning                 speedBlock
%
%   as for speedtuning_calc (did2.convert.roundtrip.speedtuning_calc), whose
%   result block is this class. A document with more than one fit block is
%   carried (its fits would all be named 'Priebe fit'), so a converted one has
%   one: `fit`.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.speed_tuning.

arguments
    bodies cell
end

[v1, leaf, ins, spec] = calcParts(bodies, 'speed_tuning_calculation', 'speed_tuning', ...
    'ndi.calc.vis.speed');
if isempty(leaf)
    return;
end
[blk, bad] = speedBlock(leaf);
spec.unplaced = [spec.unplaced, bad];
% calcParts put the method parameters (none for this class) in the block of the
% class's own name, which is also the result block: keep both
own = v1.speed_tuning;
fns = fieldnames(blk);
for k = 1:numel(fns)
    own.(fns{k}) = blk.(fns{k});
end
v1.speed_tuning = own;
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
end
