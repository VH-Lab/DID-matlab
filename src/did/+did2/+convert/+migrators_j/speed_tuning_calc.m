function bodies = speed_tuning_calc(preBody)
%SPEED_TUNING_CALC Brainstorm-J migrator -> speed_tuning_calculation (did-schema #88).
%   Brainstorm-J migrator: the ndi.calc.vis.speed calculator
%   OUTPUT document -> the CONCRETE V_eta leaf `speedtuning_calc`
%   (⊂ [tuning_curve_calculation, speed_tuning]) + a session anchor + minted
%   `software` and `runtime_environment` entities.
%
%   V_eta emits `speedtuning_calc` (no interior underscore) per Lepsky et al.
%   2026. speed_tuning has TWO independent variables (temporal + spatial
%   frequency), first-class via independent_variables[] cardinality.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved. See
%   did2.convert.migrators_j.private.jCalculation.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]). NDIcalc-vis-matlab's ndi.calc.vis.speed_tuning
%   writes the class as `speedtuning_calc` (its template calc/speedtuning_calc.json
%   and its stored self-test output mock/speed_tuning/mock.N.json);
%   rawV1Classes' one table maps that spelling to this migrator. The renamed
%   path never did (universalRenames maps only the contrast spellings), so
%   before the switch a writer's document passed through unconverted. The
%   document is read exactly as v1 wrote it: identity through jRawBody, the
%   `app` block in either spelling (did2.convert.v1read.readApp), and every
%   other field accounted for (jCalculation 'AccountForEveryField': a field the
%   fold reads nowhere carries the document whole as v1, carry-056). A carry is
%   the untouched v1 source. did2.convert.roundtrip.speedtuning_calc rebuilds
%   the v1 document; testRawV1RoundTripSpike compares the two on the writer's
%   output.
arguments
    preBody (1,1) struct
end
body = jRawBody(preBody, 'speed_tuning_calc');
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
