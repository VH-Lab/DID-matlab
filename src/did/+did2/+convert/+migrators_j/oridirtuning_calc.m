function bodies = oridirtuning_calc(preBody)
%ORIDIRTUNING_CALC Brainstorm-J migrator: the ndi.calc.vis.oridir calculator
%   OUTPUT document -> the CONCRETE V_eta leaf `oridirtuning_calc`
%   (⊂ [tuning_curve_calculation, orientation_direction_tuning]) + a session
%   anchor + minted `software` and `runtime_environment` entities.
%
%   PR #68 (Waltham-Data-Science/DID-schema): the R2/R3 leaf collapse is
%   reversed. This migrator no longer emits the abstract
%   `tuning_curve_calculation` as the concrete class -- the concrete class is
%   `oridirtuning_calc` (v1 spelling per Lepsky et al. 2026 Fig. 4). The
%   composite value fields land on `tuning_curve.value`; the calc-family fields
%   (significance, model_fit) land on `tuning_curve_calculation`; the marker
%   `orientation_direction_tuning` has no new fields per its V_eta schema.
%
%   Fold is 1 -> 1 with base.id + depends_on preserved (downstream calc
%   references resolve) and the input document(s) consumed -> derived_from_#.
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'oridirtuning_calc', ...
    {'tuning_curve_calculation', 'orientation_direction_tuning'}, ...
    'tuning_curve', ...
    'orientation/direction tuning', ...
    'ndi.calc.vis.oridir', 'orientation_direction_tuning');
end
