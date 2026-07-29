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
%   build_v_eta.py.
%
%   THE GUARD. A body carrying `mean_residual` is REJECTED BY NAME: it is a
%   DID-side invention from the V_alpha snapshot, so its presence means a fixture
%   or a caller has been built against our schema instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

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
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
