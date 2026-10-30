function bodies = vmspikefit(preBody)
%VMSPIKEFIT Brainstorm-J migrator: did_v1 vmspikefit -> a `calculation` with
%   value kind `model_fit` (private/jModelFit) + the shared session anchor
%   (+ software and run documents).
%
%   ---------------------------------------------------------------------
%   FIELD NAMES CORRECTED -- AND THE QUANTITY IS NOT WHAT IT CLAIMED
%   ---------------------------------------------------------------------
%   This migrator used to read `fit_function` and `r_squared`. NEITHER NAME HAS
%   EVER EXISTED on the NDI template: across NDI's entire history the vmspikefit
%   template has carried fit_equation, fit_sse, fit_sse_perpoint, fit_name,
%   fit_parameters, fit_parameter_names and fit_constraints -- 0 commits mention
%   fit_function or r_squared, against 7 for fit_equation and fit_sse. The names
%   came from DID-schema's own V_alpha snapshot (V_eta_ground_truth_plan.md), so
%   both reads returned nothing on every real document and the fold emitted only
%   a bare session anchor.
%
%   `fit_function` -> `fit_equation` is a plain rename. THE OTHER HALF IS NOT.
%   The old code wrote r_squared into a `score` with scale_min 0, scale_max 1,
%   labelled "goodness of fit" -- and r^2 genuinely IS that: bounded, higher is
%   better. What the template actually has is `fit_sse`, a SUM OF SQUARED
%   ERRORS: unbounded, in the fitted variable's units squared, and LOWER IS
%   BETTER. Substituting one for the other would have inverted the polarity of
%   every downstream comparison while looking like a tidy rename. So the value
%   is reported as what it is, and the false 0..1 scale is dropped.
%
%   r^2 is NOT recoverable here: it needs the total sum of squares, and this
%   template ships no data field at all. (fitcurve does ship `fit_data`, so it
%   could be derived there -- deliberately not done, because deriving it on one
%   side only would leave two classes emitting the same variable name for
%   different quantities.)
%
%   `fit_sse_perpoint` is also available and is the figure that compares across
%   fits of different lengths. Carrying it as a second observation is a
%   modelling choice, not part of this repair -- left as a follow-up.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   vmspikefit is a Vm spike-shape fit, tied to a subject via element_id. #9
%   analysis-tier fold (scalar pattern, pragmatic, same shape as fitcurve):
%   fit_sse becomes a score_observation of the subject, with the fit EQUATION as
%   the observation's method. 1 -> 2.
%
%   DEFERRED (flagged): the fit_parameters structure and the vmspikefit_file (the
%   fit result bytes) are NOT re-expressed -- a fit's parameters fold to a `method`
%   / D10 parameters (+ possibly an opaque_body for the file), a per-class decision.
%
%   ---------------------------------------------------------------------
%   THE `app` BLOCK WAS BEING DROPPED ON THE FLOOR (partially repaired here)
%   ---------------------------------------------------------------------
%   STATUS OF THIS REPAIR: NOT RUN. There is no MATLAB in the environment it was
%   written in. The gate is tests/+did2/+unittest/testMigratorsJAppFold.m, unrun.
%
%   `vmspikefit` declares the `app` superclass on NDI origin/main -- read from
%   the template:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/vhlab_voltage2firingrate/vmspikefit.json
%         superclasses: [ base.json, epochid.json, app.json ]
%
%   This migrator builds new bodies, so the block had no successor and the
%   fitting program was discarded on every document. It matters more here than
%   elsewhere: this class's own field-name repair (above) turned on WHICH
%   program wrote the fit, and the answer was thrown away with the block.
%
%   R1 (TEAM-SIGN-OFF [software], V_eta_tenet_audit.md): a `software` ENTITY +
%   `software_id` + `execution_environment`. `score_observation` reaches both
%   through subject_observation -> subject_interaction (checked in
%   did-schema/schemas/V_eta/stable/subject_interaction.json), and the
%   session_relative_reference anchor reaches neither.
%
%   THE OBSERVATION IS CONDITIONAL -- it exists only when `fit_sse` is a numeric
%   scalar. A vmspikefit with no fit_sse emits only a bare anchor, and there is
%   nowhere typed to hang its software. No slot is invented for it; the residual
%   is REPORTED rather than closed by inventing an edge.
%
%   RequireSession is TRUE: base.session_id is mustBeNonEmpty and v1_to_v2
%   quarantines the SOURCE when a body it produced fails. It removes nothing --
%   the observation and the anchor take the same session_id.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-30; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (apps/vhlab_voltage2firingrate/vmspikefit.json +
%   base.json + epochid.json + app.json at the locked NDI-matlab `main`,
%   441530d; NO WRITER we hold and no corpus document, so the template alone
%   fixes its shape). Its block and edges are snake_case already and the `app`
%   block is read in either spelling (jSoftwareFromApp), so the raw read
%   changes nothing the fold writes. The fold reads the template's block
%   fields (and the fit fields jModelFit reads for either fit class), its
%   `epochid` and `app` blocks, its edges `fit_input_id` and `element_id`, and
%   `subject_id` beside them (outside the template, read as before). What the
%   renamed path would have discarded is carried, carry-049, as before; a
%   block, base field or edge no part of this fold reads, or an `app` field
%   outside NDI's app.json (dropped without a word on the renamed path),
%   carries the document whole as v1 (private/jRawAccount, jRawCarry; [fields
%   outside the template are malformed], carry-100). A carry is the untouched
%   v1 source. `epochid.epochid` is accounted for but not kept: the
%   calculation is anchored to the session, as before (a known finding of the
%   round trip). did2.convert.roundtrip.vmspikefit rebuilds the v1 document;
%   testRawV1RoundTripFit compares the two.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above).
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'vmspikefit', {{'fit_name', 'fit_equation', 'fit_parameters', 'fit_parameter_names', ...
        'fit_independent_variable_names', 'fit_dependent_variable_names', 'fit_sse', ...
        'fit_sse_perpoint', 'fit_constraints', 'fit_data'}}, ...
    'epochid', {{'epochid'}}, ...
    'app', {{'name', 'version', 'url', 'os', 'os_version', 'interpreter', 'interpreter_version'}}), ...
    {'^fit_input_id$', '^element_id$', '^subject_id$'});
if jRawCarry('vmspikefit', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

% did-schema #88: a model_fit_calculation (jModelFit; #73 review item 68).
% The pre-#73 fold kept only the residual, as a score observation.
bodies = jModelFit(preBody, getBlock(preBody, 'vmspikefit'), {'fit_input_id'});
if isscalar(bodies) && isequaln(bodies{1}, preBody)
    bodies = {src};   % a carry is the untouched v1 source
end
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
