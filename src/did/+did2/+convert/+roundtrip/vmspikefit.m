function [v1, spec] = vmspikefit(bodies)
%VMSPIKEFIT Rebuild a v1 `vmspikefit` from the model-fit calculation
%   did2.convert.migrators_j.vmspikefit converted it to.
%
%   [V1, SPEC] = did2.convert.roundtrip.vmspikefit(BODIES). BODIES is what
%   private/jModelFit emitted (the `calculation`, its session anchor, the
%   software and run entities); private/modelFitInverse says what is rebuilt
%   and what is not. The edges are the template's `fit_input_id` and the
%   subject as `element_id`; the `app` block comes back from the software and
%   run entities (private/calcParts). The template's `epochid.epochid` is not
%   kept (the calculation is anchored to the session) and is reported. A fit
%   with no subject is carried whole as v1 (carry-137) and never reaches this
%   inverse (did2.convert.roundtrip.check compares the carry itself).
%
%   The class reads raw v1 (did2.convert.rawV1Classes, [migrators read raw
%   v1], Jess Haley, 2026-10-26).
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.vmspikefit.

arguments
    bodies cell
end

[v1, spec] = modelFitInverse(bodies, 'vmspikefit', {'fit_input_id'}, 1, ...
    {'fit_name', 'fit_equation', 'fit_parameters', 'fit_parameter_names', ...
    'fit_sse', 'fit_sse_perpoint', 'fit_constraints'});
end
