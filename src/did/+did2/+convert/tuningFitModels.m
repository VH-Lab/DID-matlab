function models = tuningFitModels(family, stem)
%TUNINGFITMODELS The tuning fits' models: term, coefficient symbols, equation
%   and constraints, one row per v1 fit the NDIcalc-vis-matlab writers store.
%
%   MODELS = did2.convert.tuningFitModels() returns every row; with FAMILY
%   ('oridir', 'contrast', 'sf', 'tf'), the rows of that family; with STEM too
%   (the v1 field prefix or block name without 'fit_', any case:
%   'double_gaussian', 'naka_rushton_RBN', 'dog', 'movshon_c', ...), the one row
%   for that fit, or an empty struct when there is none. The migrator
%   (+migrators_j/private/jTuningCurve.m, jContrastSensitivityValue.m) and the
%   round trip (+roundtrip/private/fitBlocks.m, csfBlock.m) both read this
%   table, so a fit is named and read back by one rule.
%
%   Decided by Jess Haley, 2026-11-11, did-schema
%   docs/plans/did_v2_go_forward_class_audit.md [tuning fit coefficients named
%   by symbol]: a migrated tuning fit names each coefficient (and each
%   constraint) by its symbol in the writer's equation, not by position, names
%   its model by one registered term, and fills `equation` with the writer's
%   formula in those symbols. The symbols are in STORED order (the order of the
%   v1 vector); the equations are the empty-ontology definitions (V2 2abb68c,
%   src/ontology/empty-edit.owl).
%
%   Each row: family, stem, node, name (the model term), symbols (cellstr, in
%   stored order), equation (char; '' for an interpolation), constraints (n x 2
%   cell {symbol, value}: what tells this v1 fit apart from the other fits of
%   the same model), leadingZero (true when the writer prepends a constant 0
%   that is not a coefficient).
%
%     contrast  naka_rushton_RB / _RBN / _RBNS: EMPTY:0000416 "Naka-Rushton
%               function", [Rm c50 n s]; RB is n = 1 and s = 1, RBN s = 1
%               ([Naka-Rushton is one function]). The writer stores [Rm c50],
%               [Rm c50 n] and [Rm c50 n s].
%     oridir    double_gaussian: EMPTY:0000441 "double Gaussian direction
%               tuning function", [Rsp Rp Op sig Rn], the order
%               +vis/+oridir/+index/oridir_fitindexes.m stores after reordering
%               the fitter's [Rsp Rp Rn Op sig]; Op is the preferred direction.
%     sf, tf    dog: EMPTY:0000442 "difference of Gaussians function",
%               [a1 b1 a2 b2]. The TF writer stores 5 values, a leading
%               constant 0 first (temporal_frequency_analysis.m:
%               `dog_par = [0 dog_par]`, "to comply with old dog"): not a
%               coefficient, not written, restored by the round trip
%               (leadingZero). SF stores the 4.
%               movshon, movshon_c: EMPTY:0000443 "Movshon 2005 frequency
%               tuning function", [k fc fh B C] (vis.frequency.movshon2005_func);
%               one model, `movshon` with the constraint C = 0 (it stores
%               [k fc fh B]), `movshon_c` with none.
%               gausslog: EMPTY:0000444 "log-Gaussian function", [a b c d].
%               spline: EMPTY:0000445 "cubic spline interpolation", no
%               coefficients and no equation.
%   The speed (Priebe) fits have no model term yet and are not here
%   ([tuning fit coefficients named by symbol], "Not covered").

persistent cached
if isempty(cached)
    cached = buildRows();
end
models = cached;
if nargin >= 1 && ~isempty(family)
    models = models(arrayfun(@(m) any(strcmp(m.family, family)), models));
end
if nargin >= 2
    models = models(strcmpi({models.stem}, strtrim(char(stem))));
end
end

function rows = buildRows()
NR = {'EMPTY:0000416', 'Naka-Rushton function', {'Rm', 'c50', 'n', 's'}, ...
    'R(c) = Rm c^n / (c^(n s) + c50^(n s))'};
DG = {'EMPTY:0000441', 'double Gaussian direction tuning function', ...
    {'Rsp', 'Rp', 'Op', 'sig', 'Rn'}, ...
    ['R(theta) = Rsp + Rp exp(-angdiff(Op - theta)^2 / (2 sig^2)) ' ...
     '+ Rn exp(-angdiff(180 + Op - theta)^2 / (2 sig^2))']};
DOG = {'EMPTY:0000442', 'difference of Gaussians function', ...
    {'a1', 'b1', 'a2', 'b2'}, 'R(x) = a1 exp(-x^2 / (2 b1^2)) - a2 exp(-x^2 / (2 b2^2))'};
MV = {'EMPTY:0000443', 'Movshon 2005 frequency tuning function', ...
    {'k', 'fc', 'fh', 'B', 'C'}, 'R(f) = k exp(-(f/fc)^2) / (1 + (fh/f)^B) + C'};
LG = {'EMPTY:0000444', 'log-Gaussian function', {'a', 'b', 'c', 'd'}, ...
    'R(x) = a + b exp(-(log10 x - log10 c)^2 / (2 d^2))'};
SP = {'EMPTY:0000445', 'cubic spline interpolation', {}, ''};
none = cell(0, 2);
spec = { ...
    {'contrast'}, 'naka_rushton_RB',   NR,  {'n', 1; 's', 1}, false; ...
    {'contrast'}, 'naka_rushton_RBN',  NR,  {'s', 1},         false; ...
    {'contrast'}, 'naka_rushton_RBNS', NR,  none,             false; ...
    {'oridir'},   'double_gaussian',   DG,  none,             false; ...
    {'sf'},       'dog',               DOG, none,             false; ...
    {'tf'},       'dog',               DOG, none,             true; ...
    {'sf', 'tf'}, 'movshon',           MV,  {'C', 0},         false; ...
    {'sf', 'tf'}, 'movshon_c',         MV,  none,             false; ...
    {'sf', 'tf'}, 'gausslog',          LG,  none,             false; ...
    {'sf', 'tf'}, 'spline',            SP,  none,             false};
rows = struct('family', {}, 'stem', {}, 'node', {}, 'name', {}, 'symbols', {}, ...
    'equation', {}, 'constraints', {}, 'leadingZero', {});
for k = 1:size(spec, 1)
    m = spec{k, 3};
    rows(end+1) = struct('family', {spec{k, 1}}, 'stem', spec{k, 2}, ...
        'node', m{1}, 'name', m{2}, 'symbols', {m{3}}, 'equation', m{4}, ...
        'constraints', {spec{k, 4}}, 'leadingZero', spec{k, 5}); %#ok<AGROW>
end
end
