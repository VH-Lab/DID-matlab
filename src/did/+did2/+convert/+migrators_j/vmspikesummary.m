function bodies = vmspikesummary(preBody)
%VMSPIKESUMMARY Brainstorm-J migrator: did_v1 vmspikesummary -- DEFERRED to the
%   NDI second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to decompose the class into one inline scalar observation
%   per summary statistic, dispatching on four field names:
%
%       mean_vm            -> voltage_observation   (mV)
%       mean_firing_rate   -> frequency_observation (Hz)
%       num_spikes         -> count_observation
%       recording_duration -> duration_observation  (s)
%
%   NONE OF THE FOUR EXISTS. The real NDI class
%   (ndi_common/database_documents/apps/vhlab_voltage2firingrate/
%   vmspikesummary.json) is:
%
%       vmspikesummary: { mean_spikewave, sample_times, number_of_spikes,
%                         median_spikekink_vm, median_voltageofhalfmaximum,
%                         median_fullwidthhalfmaximum,
%                         median_presk_halfwidthmaximum,
%                         median_postsk_halfwidthmaximum, median_max_dvdt,
%                         median_kink_index, slope_criterion }
%       depends_on:     element_id, spike_extraction_id
%
%   This is not a summary of firing over a recording at all -- it is a MEAN SPIKE
%   WAVEFORM plus eight SPIKE-SHAPE medians. The old model described a different
%   document than the one that exists.
%
%   `num_spikes` vs the real `number_of_spikes` is the only near-miss, and even
%   correcting the name would not have worked: the real field is an ARRAY, and
%   the migrator required `isscalar` before emitting. Every one of the four reads
%   missed, so `bodies` came out empty and the function fell to its
%   carry-unchanged branch -- a PASSTHROUGH, which the unconverted-document
%   counter does see. That is why this class was merely wrong rather than
%   destructive, and it is also why it stayed hidden: an accidental passthrough
%   is indistinguishable from a deliberate deferral until someone reads the
%   template.
%
%   WHY NOT SIMPLY REMODEL IT. The spike-shape medians are real, meaningful
%   quantities (median_max_dvdt is a slew rate, median_fullwidthhalfmaximum a
%   duration), but every one is an ARRAY of undocumented extent -- per channel?
%   per epoch? -- and `slope_criterion` is typed string-or-number. Settling any
%   of that needs the writer, and THE APP HAS NONE: NDI ships this app's 5
%   templates and 5 schemas with zero .m files and never had any, and
%   NDIcalc-vis, NDIcalc-ephys, NDIcalc-marder, NDIcalc-birren and
%   vhlab-toolbox were all searched without finding one. `mean_spikewave` +
%   `sample_times` are additionally a waveform that wants a body.
%
%   The subject is fine: element_id resolves, because migrators_j.element
%   promotes every element to a subject WITH ITS ID PRESERVED (device-as-subject,
%   D2). The `spike_extraction_id` edge was undeclared by the old tombstone and
%   is now carried.
%
%   V_eta's tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py.
%
%   THE GUARD. A body carrying `mean_vm`, `mean_firing_rate`, `num_spikes` or
%   `recording_duration` is REJECTED BY NAME: those are DID-side inventions from
%   the V_alpha snapshot, so their presence means a fixture or a caller has been
%   built against our schema instead of the real document.
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'vmspikesummary');
if isfield(blk, 'mean_vm') || isfield(blk, 'mean_firing_rate') ...
        || isfield(blk, 'num_spikes') || isfield(blk, 'recording_duration')
    error('did2:convert:vmSpikeSummaryInventedShape', ...
        ['vmspikesummary body carries `mean_vm`/`mean_firing_rate`/' ...
         '`num_spikes`/`recording_duration`, which no did_v1 document has -- ' ...
         'the class holds a mean spike waveform (`mean_spikewave`, ' ...
         '`sample_times`, `number_of_spikes`) plus eight `median_*` ' ...
         'spike-shape metrics, all arrays. This shape can only come from the ' ...
         'V_alpha snapshot or a fixture built against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
