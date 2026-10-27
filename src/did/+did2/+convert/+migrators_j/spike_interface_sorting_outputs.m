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
%   build_v_eta.py (deleted 2026-10-21).
%
%   THE GUARD. A body carrying `num_units` or `sorter_parameters` is REJECTED BY
%   NAME: those are DID-side inventions from the V_alpha snapshot, so their
%   presence means a fixture or a caller has been built against our schema
%   instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 would write it (sorting/SpikeInterfaceSortingOutputs.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8). NO NDI WRITER AT THAT
%   `main` CONSTRUCTS ONE AND NO CORPUS HOLDS ONE: the template alone fixes its
%   shape (three snake_case fields, no edges, the zip in `files`), and pass 1
%   still hands the document back UNCHANGED. The raw passthrough keeps v1's
%   class name `SpikeInterfaceSortingOutputs`, under which V_eta keeps no class,
%   so v1_to_v2 counts it as a passthrough with no schema instead of
%   validating it against the `spike_interface_sorting_outputs` tombstone (a
%   `retire` class), as a raw `imageStack` passthrough is; NDI's last step
%   stores its v1 source, stamped did_v1, on both paths ([passthrough stays v1:
%   how]). The guard reads the block in either spelling. What the renamed path
%   would have discarded is carried, carry-049, as before; a field, block or
%   edge outside the template carries the document whole as v1
%   (private/jRawAccount, jRawCarry; [fields outside the template are malformed],
%   carry-100).
%   did2.convert.roundtrip.SpikeInterfaceSortingOutputs rebuilds the v1
%   document from the passthrough; testRawV1RoundTripSpikeParameters compares.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'SpikeInterfaceSortingOutputs');
if isempty(fieldnames(blk))
    blk = getBlock(preBody, 'spike_interface_sorting_outputs');
end
if isfield(blk, 'num_units') || isfield(blk, 'sorter_parameters')
    error('did2:convert:sortingOutputsInventedShape', ...
        ['spike_interface_sorting_outputs body carries `num_units`/' ...
         '`sorter_parameters`, which no did_v1 document has -- the real fields ' ...
         'are `sorter_name`, `sample_rate` and `unit`, the class declares NO ' ...
         'dependencies, and the unit count lives only inside ' ...
         'sorting.sioutputs.zip. This shape can only come from the V_alpha ' ...
         'snapshot or a fixture built against it.']);
end
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'SpikeInterfaceSortingOutputs', {{'sorter_name', 'sample_rate', 'unit'}}, ...
    'files', {{'file_list', 'file_info'}}), {});
jRawCarry('spike_interface_sorting_outputs', preBody, collision, unplaced, 'carry-100');
bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
