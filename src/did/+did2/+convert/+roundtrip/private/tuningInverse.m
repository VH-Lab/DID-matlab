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
%   Only the order of the inputs is kept in V2, not their v1 names. Decided
%   by Jess Haley, 2026-10-27 [input names rebuild from the input class]
%   (did-schema V_eta_go_forward_class_audit.md): each single-input name is
%   rebuilt from the class of the document the input points at
%   (did2.convert.inputEdgeNames, from the batch index), the writer's name
%   when that document is not in the batch. The migrator carries a document
%   whose names do not rebuild ([carry-100] malformed).
%
%   THE OTHER 2026-10-27 DECISIONS read back here (Jess Haley):
%     [tuning fits use curve fitting now]   calcParts 'Tuning': the method's
%                 own parameters ('function', 'response transform') are not
%                 v1 settings; the rest are named back by the table
%                 ([parameter names map by table]);
%     [absolute-value fits are a second calculation]  the second calculation
%                 (calcParts' ABSLEAF) is the SF / TF `abs` block, rebuilt by
%                 tuningBlock;
%     [tuning log in notes]   tuningcurve_calc.log is the statement's notes;
%     [varied properties are conditions by V2 name]   tuningcurve_calc's
%                 stim_property_list is the conditions, named back by the
%                 table;
%     [tuning stimids rebuild]   rawCurveBlock rebuilds stimid and
%                 stimulus_presentation_number (did2.convert.tuningStimids).

[v1, leaf, ins, spec, absLeaf] = calcParts(bodies, leafClass, v1Class, methodName, ...
    'Tuning', true);
if isempty(leaf)
    return;
end
switch family
    case 'stimulus'
        own = struct();
        if isfield(v1, v1Class); own = v1.(v1Class); end
        responseId = '';
        if ~isempty(ins); responseId = ins{1}; end
        [blk, bad] = rawCurveBlock(leaf, own, responseId);
    case 'csf'
        [blk, bad] = csfBlock(leaf);
    otherwise
        [blk, bad] = tuningBlock(leaf, family);
end
spec.unplaced = [spec.unplaced, bad];
if ~isempty(absLeaf)
    if any(strcmp(family, {'sf', 'tf'}))
        [ab, bad] = tuningBlock(absLeaf, family);
        spec.unplaced = [spec.unplaced, cellfun(@(x) ['abs: ' x], bad, ...
            'UniformOutput', false)];
        blk.abs = ab;
    else
        spec.unplaced{end+1} = sprintf('an absolute-value calculation has no place in a %s', v1Class);
    end
end
if strcmp(family, 'oridir')
    % [hotelling spellings are one field] (Jess Haley, 2026-10-27): the
    % template's `hotelling2test` and the writer's `Hotelling2Test` are one
    % field; the round trip writes back the spelling v1 used
    spec.spellings = struct('paths', {{[resultBlock '.vector.Hotelling2Test'], ...
        [resultBlock '.vector.hotelling2test']}}, ...
        'why', '[hotelling spellings are one field] (Jess Haley, 2026-10-27)');
end
if strcmp(family, 'stimulus')
    % [tuning log in notes], [varied properties are conditions by V2 name]
    % (Jess Haley, 2026-10-27): the calculator's own block
    [extraOwn, bad] = curveOwnBlock(leaf);
    spec.unplaced = [spec.unplaced, bad];
    if ~isempty(fieldnames(extraOwn)) && ~strcmp(v1Class, resultBlock)
        own = struct();
        if isfield(v1, v1Class); own = v1.(v1Class); end
        fns = fieldnames(extraOwn);
        for k = 1:numel(fns)
            own.(fns{k}) = extraOwn.(fns{k});
        end
        v1.(v1Class) = own;
    elseif ~isempty(fieldnames(extraOwn))
        spec.unplaced{end+1} = sprintf('notes or conditions have no place in a %s', v1Class);
    end
end
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
    rebuiltNames = did2.convert.inputEdgeNames(ins, {inputs});
    for k = 1:numel(ins)
        if isempty(rebuiltNames{k})
            spec.unplaced{end+1} = sprintf('input_id %s has no v1 edge name', ins{k}); %#ok<AGROW>
            continue;
        end
        names{end+1} = rebuiltNames{k}; %#ok<AGROW>
        values{end+1} = ins{k}; %#ok<AGROW>
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

function [own, bad] = curveOwnBlock(leaf)
%CURVEOWNBLOCK tuningcurve_calc's `log` (the statement's notes) and
%   `stim_property_list` (its conditions, named back through
%   did2.convert.tuningNames), as the writer stores them and jsondecode reads
%   them: names a cell column, values a column (one name: a 1 x 1 cell and a
%   scalar).
own = struct();
bad = {};
notes = getIn(leaf, 'statement', 'notes');
if (ischar(notes) || isstring(notes)) && ~isempty(char(notes))
    own.log = char(notes);
end
conds = asCell(getIn(leaf, 'statement', 'conditions'));
if isempty(conds)
    return;
end
names = cell(numel(conds), 1);
values = zeros(numel(conds), 1);
for k = 1:numel(conds)
    [~, v2] = termParts(getIn(conds{k}, 'variable'));
    [v1Name, found] = did2.convert.tuningNames('v1', v2);
    q = numberOf(getIn(conds{k}, 'quantity', 'value'));
    if ~found || isempty(q)
        bad{end+1} = sprintf('condition "%s" is not a tuning property', v2); %#ok<AGROW>
        continue;
    end
    names{k} = v1Name;
    values(k) = q;
end
own.stim_property_list = struct('names', {names}, 'values', values);
end
