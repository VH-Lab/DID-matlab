function bodies = jSpeedTuning(preBody, className)
%JSPEEDTUNING The raw-v1 fold of an NDIcalc-vis speed tuning result, shared by
%   the two classes that hold it: the calculator output `speedtuning_calc`
%   (+migrators_j/speed_tuning_calc.m) and its result block written alone,
%   `speed_tuning` (+migrators_j/speed_tuning.m).
%
%   BODIES = jSpeedTuning(PREBODY, CLASSNAME). PREBODY is the RAW v1 document
%   (did2.convert.rawV1Classes). CLASSNAME names the migrator in the error a
%   document with no base.id raises (jRawBody). The block read is
%   `speed_tuning` in both classes (NDIcalc-vis-matlab 00e3e0f:
%   vision/speed_tuning.json; calc/speedtuning_calc.json adds the calculator
%   and app blocks over it). A carry is the untouched v1 source.
%
%   See also did2.convert.migrators_j.speed_tuning_calc,
%            did2.convert.migrators_j.speed_tuning.

body = jRawBody(preBody, className);
collision = jResponseRenameCollisions(preBody, cell(0, 3));
if ~isempty(collision)
    % what universalRenames would have discarded: the renamed path carried such
    % a document before any migrator ran ([renames carry is temporary])
    % carry-register: carry-049 (the renamed path carried this collision)
    did2.convert.reportNote('carried_as_v1', classNameOf(preBody), char(body.base.id), ...
        ['[carry-049] universalRenames would discard: ' strjoin(collision, ', ')]);
    bodies = {preBody};
    return;
end
bodies = jCalculation(body, 'speed_tuning_calculation', 'speed', ...
    'speed_tuning', 'speed tuning', 'ndi.calc.vis.speed', ...
    'AccountForEveryField', true);
if isscalar(bodies) && isequaln(bodies{1}, body)
    bodies = {preBody};   % a carry is the untouched v1 source
    return;
end
% THE FIT BLOCKS MUST STAY TELLABLE APART. jTuningCurve names each model_fit
% entry by its field prefix, so the writer's three blocks `fit`,
% `fit_no_speed` and `fit_fullspeed` (all `Priebe_fit_*`) become three entries
% named 'Priebe fit', and which one is the free fit, which has the speed index
% fixed at 0 and which at 1 is kept only by their order. A V2 reader cannot
% tell them apart, and the v1 block names are not recoverable ([lossless means
% round trip]): the document is carried whole as v1 instead (carry-056: the
% block names have no home), until the team decides how the fits are told
% apart (e.g. by the fit's constraints, as [Naka-Rushton is one function] does
% for the contrast fits).
dup = duplicateFitModels(bodies{1});
if ~isempty(dup)
    % carry-register: carry-056 (the fit block names have no home)
    did2.convert.reportNote('carried_as_v1', classNameOf(preBody), char(body.base.id), ...
        sprintf('unplaced: [carry-056] %s (%d fit blocks become model_fit entries all named ''%s'')', ...
        strjoin(fitBlocksOf(body), ', '), dup{2}, dup{1}));
    bodies = {preBody};
end
end

function dup = duplicateFitModels(leaf)
%DUPLICATEFITMODELS {name, count} of a model name two or more model_fit
%   entries share, or {} when every entry's model is its own.
dup = {};
mf = {};
if isfield(leaf, 'tuning_curve') && isfield(leaf.tuning_curve, 'value') ...
        && isfield(leaf.tuning_curve.value, 'model_fit')
    mf = leaf.tuning_curve.value.model_fit;
end
if isstruct(mf); mf = num2cell(mf); end
names = {};
for k = 1:numel(mf)
    m = mf{k}.model;
    if iscell(m); m = m{1}; end
    names{end+1} = char(m.name); %#ok<AGROW>
end
[u, ~, j] = unique(names);
c = accumarray(j(:), 1);
if any(c > 1)
    i = find(c > 1, 1);
    dup = {u{i}, c(i)};
end
end

function c = fitBlocksOf(body)
c = {};
if ~isfield(body, 'speed_tuning') || ~isstruct(body.speed_tuning); return; end
fns = fieldnames(body.speed_tuning);
c = cellfun(@(f) ['speed_tuning.' f], fns(strcmp(fns, 'fit') | startsWith(fns, 'fit_')), ...
    'UniformOutput', false)';
end

function cn = classNameOf(b)
cn = char(did2.convert.v1read.readStamp(b).class_name);
end
