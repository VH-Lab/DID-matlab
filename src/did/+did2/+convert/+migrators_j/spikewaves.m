function bodies = spikewaves(preBody)
%SPIKEWAVES Brainstorm-J migrator: did_v1 spikewaves -- CARRIED whole as v1
%   under a needs-home register row (the document is returned UNCHANGED).
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
%   passthrough validates -- see build_v_eta.py (deleted 2026-10-21).
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
% [unbuilt spike classes carry as needs home] (Decided by Jess Haley,
% 2026-10-27, did-schema V_eta_go_forward_class_audit.md): v1 `spikewaves`,
% `spike_clusters` and `binnedspikeratevm` are carried whole as v1 through the
% carry path, each citing a needs-home register row, rather than passed through
% unchanged on the old path; their dependents carry under [dependents of a
% carried document carry] (v1_to_v2 carryDependents, carry-064). The class reads
% raw v1 (did2.convert.rawV1Classes), so the carry is the untouched v1 source.
% THE REGISTER ROW IS PENDING in did-schema: until it exists the note cites the
% placeholder PENDING_ROW, which names no row (tools/check_carry_citations.py
% lists this site as a reason with no row).
PENDING_ROW = 'carry-pending-spike-classes-needs-home';
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: none (needs-home row pending in did-schema; PENDING_ROW)
did2.convert.reportNote('carried_as_v1', 'spikewaves', id, ...
    ['[' PENDING_ROW '] awaiting_home: spikewaves has no V2 home yet ' ...
    '([unbuilt spike classes carry as needs home])']);
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
