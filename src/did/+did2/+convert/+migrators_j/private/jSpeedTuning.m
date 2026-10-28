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
% THE FIT BLOCKS MUST STAY TELLABLE APART. The writer's three blocks `fit`,
% `fit_no_speed` and `fit_fullspeed` (all `Priebe_fit_*`) are ONE function
% (Decided by Jess Haley, 2026-10-27 [Priebe fits are one function], did-schema
% V_eta_go_forward_class_audit.md; NDIcalc-vis-matlab 00e3e0f: vis.speed.fit,
% fit_nospeed and fit_fullspeed all fit vis.speed.tuningfunc), so each is a
% model_fit entry of model 'Priebe fit', told apart by its constraints
% (jTuningCurve: `fit_no_speed` holds parameter 3, the speed index xi, at 0;
% `fit_fullspeed` at 1; `fit` holds none). Two entries of one model AND the
% same constraints (a fit block of another name) still cannot be told apart,
% and the document is carried whole as v1 (carry-056: the block names have no
% home).
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
    key = char(m.name);
    if isfield(mf{k}, 'constraints') && ~isempty(mf{k}.constraints)
        c = mf{k}.constraints;
        if isstruct(c); c = num2cell(c); end
        for j = 1:numel(c)
            v = c{j}.variable;
            if iscell(v); v = v{1}; end
            key = sprintf('%s | %s = %.17g', key, char(v.name), double(c{j}.value));
        end
    end
    names{end+1} = key; %#ok<AGROW>
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
