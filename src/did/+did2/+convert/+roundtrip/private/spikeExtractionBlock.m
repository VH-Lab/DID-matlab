function [blk, v1, bad] = spikeExtractionBlock(entries, v1)
%SPIKEEXTRACTIONBLOCK The v1 spike-extraction settings block rebuilt from the
%   method parameters +migrators_j/private/jSpikeExtractionSettings wrote.
%
%   [BLK, V1, BAD] = spikeExtractionBlock(ENTRIES, V1). ENTRIES is the cell of
%   the method's parameter entries. The four bound variables come back as the
%   fields they were read from; every other entry is the bag
%   (private/methodParameters), whose `filter.*` group goes back to the top
%   level (jSpikeExtractionSettings grouped do_filter and filter_* there), and
%   whose parked `app` / `epochid` go back to V1 (private/parkedMethodBlocks).
%   BAD lists entries that cannot be placed.
%
%   See also did2.convert.roundtrip.spike_extraction_parameters.

BOUND = {'refractory period', 'waveform window start', 'waveform window duration', ...
    'standard-deviation threshold', 'absolute voltage threshold'};
blk = struct();
bad = {};
rest = {};
vals = cell(1, numel(BOUND));   % the number of each bound variable, {} when absent
for k = 1:numel(entries)
    e = entries{k};
    [~, name] = termParts(getIn(e, 'variable'));
    hit = find(strcmp(BOUND, name), 1);
    if isempty(hit)
        rest{end+1} = e; %#ok<AGROW>
        continue;
    end
    x = numberOf(getIn(e, 'quantity', 'value'));
    if isempty(x)
        bad{end+1} = sprintf('parameter "%s" states no number', name); %#ok<AGROW>
        continue;
    end
    if ~isempty(vals{hit})
        bad{end+1} = sprintf('parameter "%s" is stated twice', name); %#ok<AGROW>
    end
    vals{hit} = x;
end
[bag, more] = methodParameters(rest);
bad = [bad, more];
[bag, v1] = parkedMethodBlocks(bag, v1);
if isfield(bag, 'filter') && isstruct(bag.filter)
    f = bag.filter;
    bag = rmfield(bag, 'filter');
    fns = fieldnames(f);
    for k = 1:numel(fns)
        bag.(fns{k}) = f.(fns{k});
    end
end
if ~isempty(vals{1})
    blk.refractory_time = vals{1};
end
if ~isempty(vals{2})
    blk.spike_start_time = vals{2};
    if ~isempty(vals{3})
        blk.spike_end_time = vals{2} + vals{3};
    end
elseif ~isempty(vals{3})
    bad{end+1} = 'a waveform window duration with no start';
end
if ~isempty(vals{4})
    blk.threshold_method = 'standard_deviation';
    blk.threshold_parameter = vals{4};
end
if ~isempty(vals{5})
    if ~isempty(vals{4})
        bad{end+1} = 'two threshold parameters';
    end
    blk.threshold_method = 'absolute';
    blk.threshold_parameter = vals{5};
end
fns = fieldnames(bag);
for k = 1:numel(fns)
    if isfield(blk, fns{k})
        bad{end+1} = sprintf('the bag restates %s', fns{k}); %#ok<AGROW>
    else
        blk.(fns{k}) = bag.(fns{k});
    end
end
end
