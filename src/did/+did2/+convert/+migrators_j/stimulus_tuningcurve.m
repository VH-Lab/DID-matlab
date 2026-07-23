function bodies = stimulus_tuningcurve(preBody)
%STIMULUS_TUNINGCURVE Brainstorm-J migrator: a raw ndi.app.stimulus.tuning_response
%   tuning curve (the pre-calculator-framework stimulus_tuningcurve document) -> the
%   subject_calculation LEAF stimulus_tuningcurve_calculation (id-preserved) + a session
%   anchor. A stimulus_tuningcurve is a computed result (mean/stddev/stderr per stimulus
%   condition), so in the calculator-motif model (Lepsky et al.) it is a
%   `subject_calculation` paired with the `stimulus_tuningcurve` result composite -- the
%   same leaf its calculator-framework sibling migrators_j.tuningcurve_calc folds to, so
%   downstream calc references (stimulus_tuningcurve_id) resolve to either indifferently.
%
%   Single-doc: the writer sets a populated `element_id` (from the consumed
%   stimulus_response_scalar), so element_id -> subject_id. The result fields already sit
%   on the self-named `stimulus_tuningcurve` block (== the composite name, the default
%   sourceBlock) and are kept verbatim; there is no calculator input_parameters/app on a
%   raw doc (method_parameters/app come out empty); the raw stimulus_response_scalar ->
%   `derived_from_1`. The V_eta `stimulus_tuningcurve` class is the ABSTRACT data_type
%   composite (a superclass, never instantiated); the concrete migrated doc is the leaf.
%
%   See did2.convert.migrators_j.private.jCalculation.
arguments
    preBody (1,1) struct
end
bodies = jCalculation(preBody, 'stimulus_tuningcurve_calculation', ...
    'stimulus_tuningcurve', 'stimulus tuning curve', ...
    'ndi.app.stimulus.tuning_response');
end
