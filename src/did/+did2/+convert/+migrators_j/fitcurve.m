function bodies = fitcurve(preBody)
%FITCURVE Brainstorm-J migrator: did_v1 fitcurve -> a `calculation` with
%   value kind `model_fit` (private/jModelFit) + the shared session anchor
%   (+ software and run documents).
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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-30; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (data/fitcurve.json + base.json at the locked
%   NDI-matlab `main`, 441530d; NO WRITER at that `main` and no corpus
%   document, so the template alone fixes its shape). Its block and edges are
%   snake_case already, so the raw read changes nothing the fold writes. The
%   fold reads the template's block fields (and `fit_sse_perpoint`, which
%   jModelFit reads for either fit class), the template's edge
%   `fit_example_data_id`, and the edges jModelFit reads beside it
%   (`fit_input_id`, and the subject `element_id` / `subject_id`, outside the
%   template but read: a document that states one converts, as before). What
%   the renamed path would have discarded is carried, carry-049, as before; a
%   block, base field or edge no part of this fold reads (dropped without a
%   word on the renamed path) carries the document whole as v1
%   (private/jRawAccount, jRawCarry; [fields outside the template are
%   malformed], carry-100). A carry is the untouched v1 source.
%   did2.convert.roundtrip.fitcurve rebuilds the v1 document;
%   testRawV1RoundTripFit compares the two.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above).
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'fitcurve', {{'fit_name', 'fit_equation', 'fit_parameters', 'fit_parameter_names', ...
        'fit_independent_variable_names', 'fit_dependent_variable_names', 'fit_sse', ...
        'fit_sse_perpoint', 'fit_constraints', 'fit_data'}}), ...
    {'^fit_example_data_id$', '^fit_input_id$', '^element_id$', '^subject_id$'});
if jRawCarry('fitcurve', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

% did-schema #88: a model_fit_calculation (jModelFit; #73 review item 68).
% The pre-#73 fold kept only the residual, as a score observation.
bodies = jModelFit(preBody, getBlock(preBody, 'fitcurve'), {'fit_example_data_id', 'fit_input_id'});
if isscalar(bodies) && isequaln(bodies{1}, preBody)
    bodies = {src};   % a carry is the untouched v1 source
end
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
