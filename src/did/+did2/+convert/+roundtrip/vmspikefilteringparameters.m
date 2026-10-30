function [v1, spec] = vmspikefilteringparameters(bodies)
%VMSPIKEFILTERINGPARAMETERS Rebuild a v1 `vmspikefilteringparameters` from the
%   `method` did2.convert.migrators_j.vmspikefilteringparameters folded it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.vmspikefilteringparameters(BODIES).
%   BODIES is the `method` (base.id preserved) and the `software` entity its
%   v1 `app` block names (private/methodDocParts: base, app, the `element_id`
%   edge from `entity_id`). The block, in NDI's v1 shape
%   (apps/vhlab_voltage2firingrate/vmspikefilteringparameters.json at the
%   locked NDI-matlab `main`):
%     refract     the `refractory period` parameter
%     threshold   the `absolute voltage threshold` parameter: its
%                 `source_value` text when v1 stated text (the template's
%                 "0.030"), else the number
%     sampling_rate, new_sampling_rate, filter_algorithm,
%     filter_algorithm_parameters, rm60Hz
%                 the parameter bag (private/methodParameters; the `filter`
%                 group flattened; the bag's `rm60_hz`, the spelling the
%                 renamed path gave it, back to the template's `rm60Hz`)
%     spiketimes  not rebuilt: the migrator folds only a document whose
%                 `spiketimes` is empty (a non-empty one is carried whole as
%                 v1, carry-143, and never reaches this inverse)
%   and `epochid.epochid` from the parked epoch string
%   (private/parkedMethodBlocks). A document stating the run's os or
%   interpreter is carried (carry-005), as is one with a field outside the
%   template (carry-100); did2.convert.roundtrip.check compares a carry itself.
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.vmspikefilteringparameters.

arguments
    bodies cell
end

CLASS = 'vmspikefilteringparameters';
TEMPLATE = {'sampling_rate', 'new_sampling_rate', 'threshold', 'spiketimes', ...
    'filter_algorithm', 'filter_algorithm_parameters', 'rm60Hz', 'refract'};
[v1, entries, spec] = methodDocParts(bodies, CLASS, struct('entity_id', 'element_id'));
if isempty(fieldnames(v1))
    return;
end
blk = struct();
rest = {};
for k = 1:numel(entries)
    e = entries{k};
    [~, name] = termParts(getIn(e, 'variable'));
    switch lower(name)
        case 'refractory period'
            field = 'refract';
        case 'absolute voltage threshold'
            field = 'threshold';
        otherwise
            rest{end+1} = e; %#ok<AGROW>
            continue;
    end
    if isfield(blk, field)
        spec.unplaced{end+1} = sprintf('parameter "%s" is stated twice', name); %#ok<AGROW>
        continue;
    end
    [x, ok] = boundValue(e);
    if ~ok
        spec.unplaced{end+1} = sprintf('parameter "%s" states no number', name); %#ok<AGROW>
        continue;
    end
    blk.(field) = x;
end
[bag, bad] = methodParameters(rest);
spec.unplaced = [spec.unplaced, bad];
[bag, v1] = parkedMethodBlocks(bag, v1);
if isfield(bag, 'filter') && isstruct(bag.filter)
    f = bag.filter;
    bag = rmfield(bag, 'filter');
    fns = fieldnames(f);
    for k = 1:numel(fns)
        bag.(fns{k}) = f.(fns{k});
    end
end
if isfield(bag, 'rm60_hz') && ~isfield(bag, 'rm60Hz')
    bag.rm60Hz = bag.rm60_hz;
    bag = rmfield(bag, 'rm60_hz');
end
bag = templateSpelling(bag, TEMPLATE);
fns = fieldnames(bag);
for k = 1:numel(fns)
    if isfield(blk, fns{k})
        spec.unplaced{end+1} = sprintf('the bag restates %s', fns{k}); %#ok<AGROW>
    else
        blk.(fns{k}) = bag.(fns{k});
    end
end
v1.(CLASS) = blk;
end

function [x, ok] = boundValue(e)
%BOUNDVALUE A bound parameter's v1 value: the text v1 wrote (`source_value`)
%   when it is not just the number's own spelling (the migrator writes
%   sprintf('%.15g') for a number), else the number.
x = numberOf(getIn(e, 'quantity', 'value'));
ok = ~isempty(x);
if ~ok
    return;
end
src = getIn(e, 'quantity', 'source_value');
if (ischar(src) || (isstring(src) && isscalar(src))) && ~isempty(strtrim(char(src))) ...
        && ~strcmp(char(src), sprintf('%.15g', x))
    x = char(src);
end
end
