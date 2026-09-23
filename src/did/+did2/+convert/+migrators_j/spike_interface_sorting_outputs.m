function bodies = spike_interface_sorting_outputs(preBody)
%SPIKE_INTERFACE_SORTING_OUTPUTS Brainstorm-J migrator: did_v1
%   spike_interface_sorting_outputs -- DEFERRED to the NDI second pass; the
%   document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to emit an inline count_observation of `num_units` about
%   the recording subject reached via element_id. BOTH HALVES ARE WRONG. The real
%   NDI class (ndi_common/database_documents/sorting/SpikeInterfaceSortingOutputs
%   .json) is:
%
%       SpikeInterfaceSortingOutputs: { sorter_name, sample_rate, unit }
%       depends_on:  []                      <- NO EDGES AT ALL
%       files:       sorting.sioutputs.zip
%
%     1. `num_units` does not exist. The unit count is inside the .zip, and a
%        single-document migrator carries files without reading their bytes (the
%        pyraview precedent), so no count is derivable in pass 1.
%
%     2. `element_id` does not exist either -- the class declares NO dependencies.
%        There is no subject to attach an observation to, and none can be found
%        from this document alone.
%
%   Because `num_units` never matched, the `numUnits <= 0` guard always fired and
%   every document was already carried through unconverted. That is the right
%   OUTCOME reached by accident, and it was indistinguishable from a deliberate
%   deferral -- which is why nobody noticed the class was modelled wrongly. Making
%   the deferral explicit is the change here.
%
%   Deferred WITH the document: sorter provenance (sorter_name -> a `software` /
%   method + derived_from) and the sample_rate/unit pair. Those are modelling
%   decisions that need the subject the second pass can find, not repairs.
%
%   V_eta's tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py.
%
%   THE GUARD. A body carrying `num_units` or `sorter_parameters` is REJECTED BY
%   NAME: those are DID-side inventions from the V_alpha snapshot, so their
%   presence means a fixture or a caller has been built against our schema
%   instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'spike_interface_sorting_outputs');
if isfield(blk, 'num_units') || isfield(blk, 'sorter_parameters')
    error('did2:convert:sortingOutputsInventedShape', ...
        ['spike_interface_sorting_outputs body carries `num_units`/' ...
         '`sorter_parameters`, which no did_v1 document has -- the real fields ' ...
         'are `sorter_name`, `sample_rate` and `unit`, the class declares NO ' ...
         'dependencies, and the unit count lives only inside ' ...
         'sorting.sioutputs.zip. This shape can only come from the V_alpha ' ...
         'snapshot or a fixture built against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
