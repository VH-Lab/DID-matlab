function [v1, spec] = fitcurve(bodies)
%FITCURVE Rebuild a v1 `fitcurve` from the model-fit calculation
%   did2.convert.migrators_j.fitcurve converted it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.fitcurve(BODIES). BODIES is what
%   private/jModelFit emitted (the `calculation`, its session anchor, the
%   software and run entities); private/modelFitInverse says what is rebuilt
%   and what is not. The edges are the template's `fit_example_data_id`, a
%   second input as `fit_input_id`, and the subject as `element_id`. A fit
%   with no subject is carried whole as v1 (carry-136) and never reaches this
%   inverse (did2.convert.roundtrip.check compares the carry itself).
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.fitcurve.

arguments
    bodies cell
end

[v1, spec] = modelFitInverse(bodies, 'fitcurve', ...
    {'fit_example_data_id', 'fit_input_id'}, 1, ...
    {'fit_name', 'fit_equation', 'fit_parameters', 'fit_parameter_names', ...
    'fit_independent_variable_names', 'fit_dependent_variable_names', 'fit_sse', ...
    'fit_constraints', 'fit_data'});
end
