function bodies = tuningcurve_calc(preBody)
%TUNINGCURVE_CALC Brainstorm-J migrator: the ndi.calc.stimulus.tuningcurve
%   calculator OUTPUT document -> the CONCRETE V_eta leaf `tuningcurve_calc`
%   (⊂ [tuning_curve_calculation, tuning_curve]; the raw case per issue #67)
%   + a session anchor + minted `software` and `runtime_environment` entities.
%
%   In V_eta, `tuningcurve_calc` is the raw case: its marker superclass IS
%   `tuning_curve` (not a thin subclass of it), so the composite value block
%   and the marker block are the same. The fold otherwise mirrors the five
%   fitted per-family leaves.
%
%   Single-doc: a tuningcurve_calc IS-A stimulus_tuningcurve (v1 superclass) and
%   so carries the inherited `element_id` -- the NDI writer sets it from the
%   consumed stimulus_response_scalar (ndi.app.stimulus.tuning_response.tuning_curve).
%   element_id -> subject_id; the tuning-curve result fields sit on the inherited
%   `stimulus_tuningcurve` block (sourceBlock) and are reshaped to V_eta's
%   tuning_curve.value shape.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'tuningcurve_calc', ...
    {'tuning_curve_calculation', 'tuning_curve'}, ...
    'tuning_curve', ...
    'stimulus tuning curve', ...
    'ndi.calc.stimulus.tuningcurve', 'stimulus_tuningcurve');
end
