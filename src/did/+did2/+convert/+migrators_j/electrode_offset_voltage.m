function bodies = electrode_offset_voltage(preBody)
%ELECTRODE_OFFSET_VOLTAGE Brainstorm-J migrator: did_v1 electrode_offset_voltage
%   -> a voltage_observation (per-channel DC offsets) + the session anchor. 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The
%   per-channel offset voltages are a length-N inline value on the probe-subject
%   (device-as-subject, D2): one measurement composite per channel (positional
%   per-channel identity, series-as-cardinality -- the channels are not a
%   continuous axis, so no `parameters` qualifier). Units come from voltage_units.
%   A degenerate doc with no offsets carries unchanged (discovery fallback).
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'electrode_offset_voltage') && isstruct(preBody.electrode_offset_voltage)
    blk = preBody.electrode_offset_voltage;
end
offsets = [];
if isfield(blk, 'offset_voltages') && isnumeric(blk.offset_voltages)
    offsets = double(blk.offset_voltages(:)');
end

anchor = jSessionAnchor(preBody, 'during');
if isempty(offsets)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

obs = jStartInteraction(preBody, 'voltage_observation', 'subject_observation', ...
    {'voltage'}, jOntologyTerm('', 'electrode offset voltage'), ...
    {'probe_id', 'element_id', 'subject_id'});
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.voltage = struct('value', jMeasureArray(offsets, jGetChar(blk, 'voltage_units')));

bodies = {obs, anchor};
end
