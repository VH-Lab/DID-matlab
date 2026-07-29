function bodies = spikewaves(preBody)
%SPIKEWAVES Brainstorm-J migrator: did_v1 spikewaves -- DEFERRED to the NDI
%   second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to emit a body-backed voltage_observation whose
%   sampled_body declared one datum per spike, shaped [samples_per_spike], with
%   n = num_spikes. NEITHER `num_spikes` NOR `samples_per_spike` EXISTS. The real
%   NDI class (ndi_common/database_documents/apps/spikeextractor/spikewaves.json)
%   has exactly ONE property field:
%
%       spikewaves:   { extraction_name }
%       depends_on:   element_id, extraction_parameters_id
%       files:        spikewaves.vsw, spiketimes.bin
%
%   `extraction_name` was read correctly -- 1 of the 3 names used. The other two
%   defaulted to 0, so every document produced a sampled_body declaring ZERO
%   SPIKES of ZERO SAMPLES EACH: a cleanly-validating description of an empty
%   extraction. Neither Phase 1 counter sees it (the values are the number 0, not
%   blanks, and output WAS produced).
%
%   Both counts live in the .vsw BINARY HEADER. A single-document migrator carries
%   files without reading their bytes (the pyraview precedent), so the shape of
%   this series is not knowable in pass 1 by any means -- the field names were
%   never the obstacle.
%
%   The subject is fine: element_id resolves, because migrators_j.element promotes
%   every element to a subject WITH ITS ID PRESERVED (device-as-subject, D2).
%
%   The document is carried through intact for the NDI second pass, which can read
%   the header. V_eta's `spikewaves` tombstone declares the real shape so the
%   passthrough validates -- see build_v_eta.py.
%
%   THE GUARD. A body carrying `num_spikes`, `samples_per_spike` or `sample_rate`
%   is REJECTED BY NAME: those are DID-side inventions from the V_alpha snapshot,
%   so their presence means a fixture or a caller has been built against our
%   schema instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'spikewaves');
if isfield(blk, 'num_spikes') || isfield(blk, 'samples_per_spike') ...
        || isfield(blk, 'sample_rate')
    error('did2:convert:spikewavesInventedShape', ...
        ['spikewaves body carries `num_spikes`/`samples_per_spike`/' ...
         '`sample_rate`, which no did_v1 document has -- the class has exactly ' ...
         'one property field, `extraction_name`, and both counts live in the ' ...
         'spikewaves.vsw binary header. This shape can only come from the ' ...
         'V_alpha snapshot or a fixture built against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
