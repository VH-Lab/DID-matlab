function [v1, spec] = tuningInverse(bodies, leafClass, v1Class, methodName, family, resultBlock, inputs)
%TUNINGINVERSE Rebuild a v1 tuning calculator document from what
%   did2.convert.migrators_j.private.jCalculation emitted when it CONVERTED it.
%
%   [V1, SPEC] = tuningInverse(BODIES, LEAFCLASS, V1CLASS, METHODNAME, FAMILY,
%   RESULTBLOCK, INPUTS): the calculation LEAFCLASS and its run entities
%   (calcParts) give the identity, `app` and input_parameters; the result
%   block RESULTBLOCK is rebuilt for FAMILY by tuningBlock ('oridir',
%   'contrast', 'sf', 'tf'), rawCurveBlock ('stimulus') or csfBlock ('csf',
%   RESULTBLOCK is the calculator's own block).
%
%   depends_on, in the writers' order: element_id (the calculation's
%   entity_id), then the input_id edges named by INPUTS:
%     'stimulus_tuningcurve_id'      one input (ndi.calc.vis.* tuning fits)
%     'stimulus_response_scalar_id'  one input (ndi.calc.stimulus.tuningcurve)
%     'csf'                          jCalculation's order [response,
%                                    contrast tunings..., presentation] as
%                                    ndi.calc.vis.contrast_sensitivity writes
%                                    them: stimulus_presentation_id,
%                                    stimulus_response_scalar_id,
%                                    contrasttuning_id_1..N
%   Only the order of the inputs is kept in V2, not their v1 names: a document
%   whose edges were not the writer's set is named wrongly here, and the round
%   trip reports it.

[v1, leaf, ins, spec] = calcParts(bodies, leafClass, v1Class, methodName);
if isempty(leaf)
    return;
end
switch family
    case 'stimulus'
        [blk, bad] = rawCurveBlock(leaf);
    case 'csf'
        [blk, bad] = csfBlock(leaf);
    otherwise
        [blk, bad] = tuningBlock(leaf, family);
end
spec.unplaced = [spec.unplaced, bad];
if isfield(v1, resultBlock)
    own = v1.(resultBlock);
    fns = fieldnames(blk);
    for k = 1:numel(fns)
        own.(fns{k}) = blk.(fns{k});
    end
    blk = own;
end
v1.(resultBlock) = blk;

entity = edgeIds(leaf, 'entity_id');
names = {'element_id'};
values = {''};
if isscalar(entity)
    values = entity;
else
    spec.unplaced{end+1} = sprintf('%d entity_id edges', numel(entity));
end
if strcmp(inputs, 'csf')
    if numel(ins) >= 2
        names = [names, {'stimulus_presentation_id', 'stimulus_response_scalar_id'}, ...
            arrayfun(@(k) sprintf('contrasttuning_id_%d', k), 1:numel(ins) - 2, ...
            'UniformOutput', false)];
        values = [values, ins(end), ins(1), ins(2:end - 1)];
    elseif ~isempty(ins)
        spec.unplaced{end+1} = 'one input_id: the response and the presentation are both written';
    end
else
    if ~isempty(ins)
        names{end+1} = inputs;
        values{end+1} = ins{1};
    end
    for k = 2:numel(ins)
        spec.unplaced{end+1} = sprintf('input_id %s has no v1 edge name', ins{k});
    end
end
v1.depends_on = struct('name', names, 'value', values);

% the inner copy of the edges in the calculator block: left unwritten only when
% each entry restated the top-level edge of its name ([restated values
% checked], Jess Haley, 2026-10-26; jCalculation innerDependsOnDiffers)
why = ['the calculator block''s inner depends_on copy restates a top-level ' ...
    'edge ([restated values checked], Jess Haley, 2026-10-26)'];
for k = 1:numel(names)
    spec.equivalents(end+1) = struct('path', sprintf('%s.depends_on(%d).name', v1Class, k), ...
        'values', {names}, 'why', why);
    spec.equivalents(end+1) = struct('path', sprintf('%s.depends_on(%d).value', v1Class, k), ...
        'values', {values}, 'why', why);
end
end
