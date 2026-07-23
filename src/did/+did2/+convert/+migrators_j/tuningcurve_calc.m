function bodies = tuningcurve_calc(preBody)
%TUNINGCURVE_CALC Brainstorm-J migrator: the ndi.calc.stimulus.tuningcurve calculator
%   OUTPUT document -> the subject_calculation LEAF stimulus_tuningcurve_calculation
%   (id-preserved) + a session anchor. Un-defers the last calculator in the vision
%   family (Lepsky et al., the calculator-motif paper): a calculator produces ONE
%   output document type, kept as a first-class composite LEAF -- `subject_calculation`
%   + the `stimulus_tuningcurve` result composite (the mean/stddev/stderr-per-condition
%   tuning curve), exactly as visual_grating_manipulation pairs subject_manipulation
%   with visual_grating.
%
%   Single-doc, contrary to an earlier (mistaken) belief that this doc lacked a
%   subject: a real tuningcurve_calc IS-A stimulus_tuningcurve (v1 superclass) and so
%   carries the inherited `element_id` -- the NDI writer sets it from the consumed
%   stimulus_response_scalar (ndi.app.stimulus.tuning_response.tuning_curve). Hence the
%   fold is 1 -> 1 with base.id preserved and depends_on carried (downstream calc
%   references resolve): element_id -> subject_id; the tuning-curve result fields sit on
%   the inherited `stimulus_tuningcurve` block (== the composite name, the default
%   sourceBlock) and are kept verbatim; the calc block's input_parameters ->
%   `subject_interaction.method_parameters`; the app block is kept; the raw
%   stimulus_response_scalar it was computed from -> `derived_from_1`.
%
%   Same leaf as its raw-app sibling migrators_j.stimulus_tuningcurve. See
%   schemas/V_eta_subject_calculation_plan.md and
%   did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'stimulus_tuningcurve_calculation', ...
    'stimulus_tuningcurve', 'stimulus tuning curve', ...
    'ndi.calc.stimulus.tuningcurve');
end
