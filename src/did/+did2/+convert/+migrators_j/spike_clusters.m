function bodies = spike_clusters(preBody)
%SPIKE_CLUSTERS Brainstorm-J migrator: did_v1 spike_clusters -- CARRIED whole as
%   v1 under a needs-home register row (the document is returned UNCHANGED).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to emit a body-backed count_observation whose sampled_body
%   declared n = num_spikes. `num_spikes` DOES NOT EXIST. The real NDI class
%   (ndi_common/database_documents/apps/spikesorter/spike_clusters.json, and its
%   matching schema_documents entry) is:
%
%       spike_clusters: { epoch_info, clusterinfo, waveform_sample_times }
%       depends_on:     sorting_parameters_id, element_id,
%                       extraction_parameters_id, spikewaves_doc_id
%       files:          spike_cluster.bin
%
%   NOT ONE of the three property fields was read, and the field that WAS read is
%   not in the class. Because `num_spikes` never matched, the default of 0 always
%   applied, so every document produced a sampled_body declaring ZERO SAMPLES --
%   a well-formed, cleanly-validating claim that the sorter assigned no spikes.
%   That is a fabricated measurement, and neither Phase 1 counter can see it: the
%   body is not empty (n is the number 0, not a blank), and output WAS produced,
%   so it is not an unconverted document either.
%
%   The count that observation wanted is recoverable only by reading
%   spike_cluster.bin, and a single-document migrator carries files without
%   reading their bytes (the pyraview precedent). So it cannot be produced here at
%   all -- not with a different field name, not with a fallback.
%
%   The subject is fine: element_id resolves, because migrators_j.element promotes
%   every element to a subject WITH ITS ID PRESERVED (device-as-subject, D2). The
%   deferral is about the payload, not the subject.
%
%   The document is therefore carried through intact for the NDI second pass,
%   which can read file bytes and see the migrated-id graph. V_eta's
%   `spike_clusters` tombstone declares the real shape so the passthrough
%   validates -- see build_v_eta.py (deleted 2026-10-21).
%
%   THE GUARD. A body carrying `num_spikes` or `num_clusters` is REJECTED BY NAME:
%   those are DID-side inventions from the V_alpha snapshot, so their presence
%   means a fixture or a caller has been built against our schema instead of the
%   real document -- the precise mistake being corrected here.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'spike_clusters');
if isfield(blk, 'num_spikes') || isfield(blk, 'num_clusters')
    error('did2:convert:spikeClustersInventedShape', ...
        ['spike_clusters body carries `num_spikes`/`num_clusters`, which no ' ...
         'did_v1 document has -- the real fields are `epoch_info`, ' ...
         '`clusterinfo` and `waveform_sample_times`, and the spike count lives ' ...
         'only inside spike_cluster.bin. This shape can only come from the ' ...
         'V_alpha snapshot or a fixture built against it.']);
end
% [unbuilt spike classes carry as needs home] (Decided by Jess Haley,
% 2026-10-27, did-schema V_eta_go_forward_class_audit.md): v1 `spikewaves`,
% `spike_clusters` and `binnedspikeratevm` are carried whole as v1 through the
% carry path, each citing a needs-home register row, rather than passed through
% unchanged on the old path; their dependents carry under [dependents of a
% carried document carry] (v1_to_v2 carryDependents, carry-064). The class reads
% raw v1 (did2.convert.rawV1Classes), so the carry is the untouched v1 source.
% The register row is carry-102 (did-schema V_eta_carry_register.json).
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
% carry-register: carry-102
did2.convert.reportNote('carried_as_v1', 'spike_clusters', id, ...
    ['[carry-102] awaiting_home: spike_clusters has no V2 home yet ' ...
    '([unbuilt spike classes carry as needs home])']);
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
