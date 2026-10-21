function bodies = fitcurve(preBody)
%FITCURVE Brainstorm-J migrator: did_v1 fitcurve -> a fit-residual
%   score_observation (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   fitcurve is a generic curve fit, tied to a subject via element_id. #9
%   analysis-tier fold (scalar pattern, pragmatic): the fit residual becomes a
%   score_observation of the subject, with the fit EQUATION carried as the
%   observation's method:
%
%       score_observation  variable = 'residual sum of squares', value =
%                          fit_sse, method = the fit_equation term. inline.
%       session_relative_reference   the 'during' anchor.
%
%   ---------------------------------------------------------------------
%   FIELD NAMES CORRECTED -- AND THE QUANTITY IS NOT WHAT IT CLAIMED
%   ---------------------------------------------------------------------
%   This migrator used to read `fit_function` and `goodness_of_fit`. NEITHER
%   NAME HAS EVER EXISTED on the NDI template: across NDI's entire history the
%   fitcurve template has carried fit_equation, fit_sse, fit_name, fit_data,
%   fit_parameters, fit_parameter_names, fit_constraints and the independent /
%   dependent variable-name lists -- 0 commits mention fit_function or
%   goodness_of_fit, against 7 for fit_equation and fit_sse. The names came from
%   DID-schema's own V_alpha snapshot (see V_eta_ground_truth_plan.md), so both
%   reads returned nothing on every real document and the fold emitted only a
%   bare session anchor.
%
%   `fit_function` -> `fit_equation` is a plain rename. THE OTHER HALF IS NOT.
%   The old code wrote its value into a `score` with scale_min 0, scale_max 1,
%   labelled "goodness of fit" -- i.e. a bounded score where HIGHER IS BETTER.
%   What the template actually has is `fit_sse`, a SUM OF SQUARED ERRORS:
%   unbounded, in the dependent variable's units squared, and LOWER IS BETTER.
%   Mapping one onto the other would have inverted the polarity of every
%   downstream comparison while looking like a tidy rename. So the value is
%   reported as what it is -- a residual -- and the false 0..1 scale is dropped
%   rather than left asserting a range SSE cannot honour.
%
%   r^2 is NOT recoverable here as a substitute: it needs the total sum of
%   squares. fitcurve does ship `fit_data`, so it could in principle be derived
%   for THIS class -- but vmspikefit has no data field at all, and deriving it
%   on one side only would leave two classes emitting the same variable name
%   for different quantities. Deliberately not done.
%
%   1 -> 2. DEFERRED (flagged): the fit_parameters structure itself is NOT yet
%   re-expressed -- per the plan a fit's parameters fold to a `method` / D10
%   parameters, a per-class decision. This captures the residual + which
%   equation; the parameter vector is a follow-up.

arguments
    preBody (1,1) struct
end

% did-schema #88: a model_fit_calculation (jModelFit; #73 review item 68).
% The pre-#73 fold kept only the residual, as a score observation.
bodies = jModelFit(preBody, getBlock(preBody, 'fitcurve'), {'fit_example_data_id', 'fit_input_id'});
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
