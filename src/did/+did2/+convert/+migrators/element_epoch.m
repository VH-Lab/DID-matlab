function v2Body = element_epoch(preBody)
%ELEMENT_EPOCH Base migrator: did_v1 element_epoch body -> the class-preserving V2 shape.
%
%   V2 represents element_epoch timing as a single `clocks`
%   field of array-of-records shape:
%
%       element_epoch.clocks(i).name   - clock identifier (char)
%       element_epoch.clocks(i).t0     - start time   (double)
%       element_epoch.clocks(i).t1     - stop time    (double)
%
%   did_v1 storage convention is documented in NDI's
%   element_epoch_schema.json:
%
%       "type": "matrix",
%       "parameters": [2, NaN],
%       "Each column is for a different epoch clock type."
%
%   That is: a 2-by-N matrix where rows are [t0; t1] and columns are
%   clocks. ndi.element.addepoch and ndi.element.oneepoch both write
%   this shape (the numel==2 path in addepoch columnizes a single
%   clock to a 2-by-1 column vector, preserving the convention).
%
%   Single-clock (common in PRED, 20211116, B corpora):
%       epoch_clock = 'dev_local_time'
%       t0_t1       = [0; 930.34795]            (2-by-1, or [0 930.34795])
%
%   Multi-clock (e.g., the JH corpus, NDI mock):
%       epoch_clock = 'dev_local_time,exp_global_time'
%       t0_t1       = [0          738553.4082;
%                      3599.69855 738553.4498]   (2-by-N, columns=clocks)
%     -> clocks(1) = (dev_local_time, t0=0,           t1=3599.69855)
%        clocks(2) = (exp_global_time, t0=738553.4082, t1=738553.4498)
%
%   A length-2 row/column vector is treated as a degenerate single-clock
%   case. A genuine N-by-2 matrix (rows=clocks, with N>=3 so the shape
%   is unambiguous) is accepted as a defensive fallback in case any
%   pre-canonical corpus stored that transpose.
%
%   A legacy `clocktype` v1 spelling (matching the epochclocktimes
%   superclass naming) is also accepted defensively and renamed.
%
%   t0_t1 MUST MATCH THE CLOCKS ([small unread settings] (4), Jess Haley,
%   2026-10-26). A t0_t1 that is missing, not numeric, or whose column count
%   is not the clock count (either direction) is not converted: the body is
%   returned UNCHANGED with a `carried_as_v1` note, and the callers
%   (+migrators_j/element_epoch, +migrators_j/oneepoch) carry the document
%   whole as v1. Until 2026-10-26 the clocks were zero-padded (a start-0 /
%   end-0 clock the source never stated) or truncated (extents dropped);
%   both invented or lost values ([no invented values], Jess Haley,
%   2026-10-25).

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
why = t0t1Mismatch(block, numel(names));
if ~isempty(why)
    cn = 'element_epoch';
    if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
        cn = char(preBody.document_class.class_name);
    end
    id = '';
    if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
        id = char(preBody.base.id);
    end
    did2.convert.reportNote('carried_as_v1', cn, id, ['unplaced: element_epoch.t0_t1 (' why ')']);
    v2Body = preBody;   % unchanged: the callers carry it whole as v1
    return;
end
pairs = parseT0T1Matrix(block);

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

function why = t0t1Mismatch(block, nClocks)
%T0T1MISMATCH '' when t0_t1 states exactly one [t0, t1] per clock, else why not.
if ~isfield(block, 't0_t1')
    why = 'missing';
    return;
end
raw = block.t0_t1;
if ~isnumeric(raw) || isempty(raw)
    why = 'not numeric';
    return;
end
n = nColumns(raw);
if isnan(n)
    why = sprintf('a %dx%d matrix is not one [t0; t1] per clock', size(raw, 1), size(raw, 2));
elseif n ~= nClocks
    why = sprintf('%d column(s) for %d clock(s)', n, nClocks);
else
    why = '';
end
end

function n = nColumns(raw)
%NCOLUMNS How many clocks a numeric t0_t1 states, by the shapes parseT0T1Matrix
%   reads; NaN for any other shape.
if isvector(raw) && numel(raw) == 2
    n = 1;
elseif ismatrix(raw) && size(raw, 1) == 2 && size(raw, 2) >= 1
    n = size(raw, 2);
elseif ismatrix(raw) && size(raw, 2) == 2
    n = size(raw, 1);
else
    n = NaN;
end
end

function pairs = parseT0T1Matrix(block)
% Returns an N-by-2 numeric matrix where row k is clock k's [t0, t1],
% the format buildClockRecords consumes. Called only once t0t1Mismatch has
% found exactly one [t0, t1] per clock (no padding, no truncation).
%
% Canonical did_v1 storage is 2-by-N (rows = [t0; t1], columns =
% clocks) per NDI element_epoch_schema.json. A length-2 row/column
% vector is the degenerate single-clock case. A genuine N-by-2
% matrix (N >= 3) is accepted defensively in case any corpus stored
% the transpose; for N = 2 the canonical 2-by-N branch matches
% first, which is the unambiguous interpretation matching what
% ndi.element.addepoch / oneepoch actually write.
raw = block.t0_t1;
if isvector(raw) && numel(raw) == 2
    % Single-clock degenerate: [t0 t1] (row) or [t0; t1] (column).
    pairs = double(reshape(raw, 1, 2));
elseif size(raw, 1) == 2
    % Canonical 2-by-N: rows = [t0; t1], columns = clocks.
    pairs = double(raw.');
else
    % Defensive: N-by-2 (N >= 3) where each row is a clock's [t0 t1].
    pairs = double(raw);
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
