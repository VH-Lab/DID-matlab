function bodies = binnedspikeratevm(preBody)
%BINNEDSPIKERATEVM Brainstorm-J migrator: did_v1 binnedspikeratevm -- DEFERRED to
%   the NDI second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to emit a body-backed frequency_observation whose
%   sampled_body declared a REGULAR timeline of n = num_bins samples at
%   dt = bin_size, with unit 'Hz'. NEITHER `num_bins` NOR `bin_size` EXISTS. The
%   real NDI class
%   (ndi_common/database_documents/apps/vhlab_voltage2firingrate/
%   binnedspikeratevm.json) is:
%
%       binnedspikeratevm: { parameters: { binsize, vm_baseline_correction,
%                                          vm_baseline_correct_time,
%                                          vm_baseline_correct_func,
%                                          number_of_points },
%                            voltage_observations, firingrate_observations,
%                            stimids, timepoints, exactbintime }
%       depends_on:        vmspikefilteringparameters_id, element_id
%
%   The bin width is `parameters.binsize` -- nested, and spelled without the
%   underscore. So both reads failed, and every document produced a sampled_body
%   declaring a regular series of ZERO SAMPLES at dt = 0 seconds, labelled Hz. A
%   cleanly-validating description of nothing, invisible to both Phase 1 counters
%   (the values are numeric 0, not blanks, and output WAS produced).
%
%   TWO REASONS THIS CANNOT BE REPAIRED BY RENAMING, both traceable to a missing
%   writer:
%
%     1. NO WRITER EXISTS. NDI ships this app's 5 templates and 5 schemas under
%        ndi_common/.../apps/vhlab_voltage2firingrate/ but ZERO .m files, and
%        never had any. NDIcalc-vis, NDIcalc-ephys, NDIcalc-marder,
%        NDIcalc-birren and vhlab-toolbox were all searched: none has it. So the
%        encoding of the "string"-typed payload fields (voltage_observations,
%        firingrate_observations, stimids, timepoints, exactbintime) is
%        undocumented, and nothing can be unpacked from them.
%
%     2. THE UNIT IS A GUESS, AND AN EXPENSIVE ONE. The class is named for a
%        RATE, but binned spike data is just as commonly stored as spikes PER
%        BIN. At the template's binsize of 0.030 s those differ by a factor of
%        33. The old code hardcoded 'Hz'. With no writer, nothing in NDI settles
%        which it is, and a wrong unit is worse than a deferral because it
%        validates.
%
%   Also worth recording: the template's first dependency is
%   `vmspikefilteringparameters_id`, while the class's own NDI schema declares
%   `sorting_parameters_id` in that slot. Template and schema disagree, and there
%   is no writer to arbitrate, so V_eta's tombstone declares both as optional.
%
%   The document is carried through intact for the NDI second pass. V_eta's
%   tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py.
%
%   THE GUARD. A body carrying `num_bins` or `bin_size` is REJECTED BY NAME:
%   those are DID-side inventions from the V_alpha snapshot, so their presence
%   means a fixture or a caller has been built against our schema instead of the
%   real document. Note `bin_size` and the real `parameters.binsize` differ by
%   exactly one underscore and one nesting level -- the guard is on the flat,
%   underscored spelling only.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'binnedspikeratevm');
if isfield(blk, 'num_bins') || isfield(blk, 'bin_size')
    error('did2:convert:binnedSpikeRateInventedShape', ...
        ['binnedspikeratevm body carries `num_bins`/`bin_size`, which no ' ...
         'did_v1 document has -- the bin width is `parameters.binsize` ' ...
         '(nested, no underscore) and there is no bin count. This shape can ' ...
         'only come from the V_alpha snapshot or a fixture built against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
