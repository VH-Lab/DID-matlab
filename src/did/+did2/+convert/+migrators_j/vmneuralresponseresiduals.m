function bodies = vmneuralresponseresiduals(preBody)
%VMNEURALRESPONSERESIDUALS Brainstorm-J migrator: did_v1
%   vmneuralresponseresiduals -- DEFERRED to the NDI second pass; the document is
%   passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to emit an inline voltage_observation of `mean_residual`
%   in mV, plus a derived_from relation to a `vmspikefit_id`. NEITHER THE FIELD
%   NOR THE EDGE EXISTS. The real NDI class
%   (ndi_common/database_documents/apps/vhlab_voltage2firingrate/
%   vmneuralresponseresiduals.json) is:
%
%       vmneuralresponseresiduals: { element_epochid,
%                                    parameters: { number_traces,
%                                                  samples_per_trace, units },
%                                    column_labels: { first_column ...
%                                                     fifth_column },
%                                    goodness_of_fit, total_power,
%                                    residual_power }
%       depends_on:                element_id          <- the ONLY edge
%
%   THIS IS THE FRAGMENT FAILURE MODE, and it is the reason Phase 1 needed more
%   than one counter. `mean_residual` never matched, so the `isnumeric` guard
%   never passed, so the function fell out of its only branch having emitted
%   nothing but a bare session anchor: the payload was dropped and a stray
%   time-reference document was all that landed. No counter sees that. It is not
%   hollow (no blank required field was written) and it is not an unconverted
%   document (output WAS produced) -- it just quietly loses the class.
%
%   WHAT THE REAL FIELDS WOULD NEED, AND WHY NOT NOW. `total_power` and
%   `residual_power` are a genuine pair and their ratio is a real fit-quality
%   measure. But this app HAS NO WRITER anywhere -- NDI ships the templates and
%   schemas with zero .m files and never had any, and NDIcalc-vis, NDIcalc-ephys,
%   NDIcalc-marder, NDIcalc-birren and vhlab-toolbox were all searched without
%   finding one. So:
%     - `goodness_of_fit` is declared `["number", "string"]` with NO documented
%       range and NO documented polarity. Folding it into a score_observation
%       means inventing both. The fitcurve/vmspikefit repair in this same pass
%       caught exactly that trap going the other way (fit_sse is unbounded and
%       LOWER-is-better, so writing it as an r-squared would have inverted every
%       downstream comparison).
%     - the residual trace itself is a file whose column meanings are given by
%       `column_labels`, and a single-document migrator carries files without
%       reading their bytes (the pyraview precedent).
%
%   The subject is fine: element_id resolves, because migrators_j.element promotes
%   every element to a subject WITH ITS ID PRESERVED (device-as-subject, D2).
%
%   V_eta's tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py (deleted 2026-10-21).
%
%   THE GUARD. A body carrying `mean_residual` is REJECTED BY NAME: it is a
%   DID-side invention from the V_alpha snapshot, so its presence means a fixture
%   or a caller has been built against our schema instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 would write it (apps/vhlab_voltage2firingrate/vmneuralresponseresiduals.json +
%   base.json at the locked NDI-matlab `main`,
%   3cb19a8). NO NDI WRITER AT THAT `main` CONSTRUCTS ONE AND NO CORPUS HOLDS
%   ONE (the vhlab_voltage2firingrate writer is in no repository we hold): the
%   template alone fixes its shape. Its blocks are snake_case already and it
%   has no `app` block, so the raw passthrough is the renamed one but for v1's
%   `value` edge key, and it validates against the same V_eta class. What the
%   renamed path would have discarded is carried, carry-049, as before; a
%   field, block or edge outside the template (which the passthrough met as an
%   undeclared field) carries the document whole as v1 (private/jRawAccount,
%   jRawCarry; [fields outside the template are malformed], carry-100).
%   did2.convert.roundtrip.vmneuralresponseresiduals rebuilds the v1 document from the passthrough;
%   testRawV1RoundTripIngestedEpochs compares the two.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'vmneuralresponseresiduals');
if isfield(blk, 'mean_residual')
    error('did2:convert:vmResidualsInventedShape', ...
        ['vmneuralresponseresiduals body carries `mean_residual`, which no ' ...
         'did_v1 document has -- the real fit-quality fields are ' ...
         '`goodness_of_fit`, `total_power` and `residual_power`, and the class ' ...
         'has no vmspikefit_id edge. This shape can only come from the V_alpha ' ...
         'snapshot or a fixture built against it.']);
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'vmneuralresponseresiduals', {{'element_epochid', 'parameters', 'column_labels', ...
        'goodness_of_fit', 'total_power', 'residual_power'}}), ...
    {'^element_id$'});
if ~jRawCarry('vmneuralresponseresiduals', preBody, collision, unplaced, 'carry-100')
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's V2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. No carry register row
    % covers this reason yet (a question for the team).
    % carry-register: none (vmneuralresponseresiduals has no V2 home)
    did2.convert.reportNote('carried_as_v1', 'vmneuralresponseresiduals', jCarryId(preBody), ...
        'unplaced: vmneuralresponseresiduals has no V2 home ([passthrough stays v1])');
end
bodies = {preBody};   % the carry of the untouched v1 source
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
