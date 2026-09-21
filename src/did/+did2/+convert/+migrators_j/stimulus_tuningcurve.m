function bodies = stimulus_tuningcurve(preBody)
%STIMULUS_TUNINGCURVE Brainstorm-J migrator: a raw ndi.app.stimulus.tuning_response
%   tuning curve (the pre-calculator-framework stimulus_tuningcurve document)
%   -> the CONCRETE V_eta leaf `tuningcurve_calc`
%   (⊂ [tuning_curve_calculation, tuning_curve]; the raw case per issue #67)
%   + a session anchor + minted `software` and `runtime_environment` entities.
%
%   V_eta preserves the v1 `stimulus_tuningcurve` shape under the `tuning_curve`
%   composite (self-describing raw curve). The raw v1 doc migrates 1 -> 1 to a
%   concrete `tuningcurve_calc` leaf whose marker superclass IS `tuning_curve`,
%   with the result fields reshaped into `tuning_curve.value` (independent
%   variables + mean/stddev/stderr/individual/control/... per the V_eta schema).
%
%   Single-doc: the writer sets a populated `element_id` (from the consumed
%   stimulus_response_scalar), so element_id -> subject_id. Same target as
%   migrators_j.tuningcurve_calc (calc sibling of this raw class).
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuningcurve_calc', ...
    {'tuning_curve_calculation', 'tuning_curve'}, ...
    'tuning_curve', ...
    'stimulus tuning curve', ...
    'ndi.app.stimulus.tuning_response', 'stimulus_tuningcurve');
end
