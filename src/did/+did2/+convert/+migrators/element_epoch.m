function v2Body = element_epoch(preBody)
%ELEMENT_EPOCH Migrate a did_v1 element_epoch body to V_delta.
%
%   V_delta represents element_epoch timing as a single `clocks`
%   field of array-of-records shape:
%
%       element_epoch.clocks(i).name   - clock identifier (char)
%       element_epoch.clocks(i).t0     - start time   (double)
%       element_epoch.clocks(i).t1     - stop time    (double)
%
%   did_v1 had two equivalent shapes:
%
%   Single-clock (common in PRED, 20211116, B corpora):
%       epoch_clock = 'dev_local_time'
%       t0_t1       = [0  930.34795]
%
%   Multi-clock (seen in the JH corpus):
%       epoch_clock = 'dev_local_time,exp_global_time'
%       t0_t1       = [0           738553.4082;
%                      3599.69855  738553.4498]
%
%   This migrator handles both. epoch_clock is comma-split into N
%   names; t0_t1 is parsed as either an N-by-2 array or a 2-vector
%   (which is the degenerate N=1 case).
%
%   A legacy `clocktype` v1 spelling (matching the epochclocktimes
%   superclass naming) is also accepted defensively and renamed.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'element_epoch') ...
        || ~isstruct(v2Body.element_epoch)
    error('did2:convert:missingBlock', ...
        'element_epoch body is missing the element_epoch property block.');
end

block = v2Body.element_epoch;

if isfield(block, 'clocktype') && ~isfield(block, 'epoch_clock')
    block.epoch_clock = char(block.clocktype);
    block = rmfield(block, 'clocktype');
elseif isfield(block, 'clocktype')
    block = rmfield(block, 'clocktype');
end

names = parseClockNames(block);
pairs = parseT0T1Matrix(block, numel(names));

clocks = buildClockRecords(names, pairs);

newBlock = struct();
newBlock.clocks = clocks;
v2Body.element_epoch = newBlock;
end

function names = parseClockNames(block)
if isfield(block, 'epoch_clock')
    raw = char(block.epoch_clock);
else
    raw = 'dev_local_time';
end
if isempty(raw)
    names = {'dev_local_time'};
    return;
end
parts = strsplit(raw, ',');
names = cell(1, numel(parts));
for k = 1:numel(parts)
    names{k} = strtrim(parts{k});
end
end

function pairs = parseT0T1Matrix(block, nClocks)
% Always returns an N-by-2 numeric matrix. Padded with zeros if the
% v1 doc had fewer rows than the clock-name count (defensive).
if ~isfield(block, 't0_t1')
    pairs = zeros(nClocks, 2);
    return;
end
raw = block.t0_t1;
if isnumeric(raw) && isvector(raw) && numel(raw) == 2
    pairs = double(reshape(raw, 1, 2));
elseif isnumeric(raw) && size(raw, 2) == 2
    pairs = double(raw);
elseif isnumeric(raw) && size(raw, 1) == 2 && size(raw, 2) >= 1
    % v1 occasionally ships the transpose; accept it.
    pairs = double(raw');
else
    pairs = zeros(nClocks, 2);
    if isnumeric(raw) && numel(raw) >= 1
        pairs(1, 1) = double(raw(1));
        if numel(raw) >= 2
            pairs(1, 2) = double(raw(2));
        end
    end
end
if size(pairs, 1) < nClocks
    pad = zeros(nClocks - size(pairs, 1), 2);
    pairs = [pairs; pad];
elseif size(pairs, 1) > nClocks
    pairs = pairs(1:nClocks, :);
end
end

function clocks = buildClockRecords(names, pairs)
% Build a 1xN struct array with fields {name, t0, t1}.
n = numel(names);
clocks = struct('name', cell(1, n), 't0', cell(1, n), 't1', cell(1, n));
for k = 1:n
    clocks(k).name = names{k};
    clocks(k).t0 = pairs(k, 1);
    clocks(k).t1 = pairs(k, 2);
end
end
