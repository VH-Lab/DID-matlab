function bodies = probe_geometry(preBody)
%PROBE_GEOMETRY Brainstorm-J migrator: did_v1 probe_geometry -> a
%   length_observation (the probe's channel geometry) about the probe-subject,
%   plus the session anchor; optionally a probe-type term_assertion. 1 -> 2 (or 3).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The
%   probe IS a `subject` (device-as-subject, D2), carried from the source
%   `probe_id` dependency. The channel geometry is emitted as a length_observation
%   whose INLINE value is the channel_positions matrix FLATTENED column-major into
%   a length-N array via jMeasureArray(channel_positions(:)', position_units):
%   spine variable jOntologyTerm('', 'channel geometry'), a 'during' session anchor
%   supplying the time_reference_1 edge.
%
%   DEFERRED: flattening the N-by-D coordinate matrix into a 1-D length array
%   LOSES the per-channel (x, y[, z]) structure -- the length_observation records
%   the geometry's magnitudes but not which coordinate belongs to which channel.
%   The structured per-channel coordinate map (a spatial position composite with
%   an explicit channel axis) awaits a richer geometry representation, reserved
%   for the NDI second pass. num_channels is likewise recoverable but not stored
%   here (it is numel(channel_positions)/D once the map is reconstructed).
%
%   When probe_type is non-empty it is additionally emitted as a timeless
%   `term_assertion` about the same probe-subject (variable 'probe type', value =
%   the probe_type as an ontology_term), making the split 1 -> 3. A doc with an
%   empty channel_positions carries unchanged (discovery fallback).
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'probe_geometry') && isstruct(preBody.probe_geometry)
    blk = preBody.probe_geometry;
end
positions = [];
if isfield(blk, 'channel_positions') && isnumeric(blk.channel_positions)
    positions = double(blk.channel_positions);
end
units = jGetChar(blk, 'position_units');
probeType = jGetChar(blk, 'probe_type');

if isempty(positions)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

subjectSrc = {'probe_id', 'element_id', 'subject_id'};
obs = jStartInteraction(preBody, 'length_observation', 'subject_observation', ...
    {'length'}, jOntologyTerm('', 'channel geometry'), subjectSrc);
anchor = jSessionAnchor(preBody, 'during');
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.length = struct('value', jMeasureArray(positions(:)', units));   % flattened, see DEFERRED

if isempty(probeType)
    bodies = {obs, anchor};
    return;
end

% Optional probe-type assertion: a timeless subject_assertion leaf (no
% interaction), a secondary sibling body so it mints a fresh base id.
assertion = struct();
assertion.document_class = struct('class_name', 'term_assertion', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_assertion', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
assertion.depends_on = jCarrySubject(preBody, subjectSrc);
if isfield(preBody, 'base') && isstruct(preBody.base)
    assertion.base = preBody.base;
    assertion.base.id = did.ido.unique_id();
end
assertion.subject_statement = struct('variable', jOntologyTerm('', 'probe type'), ...
    'storage_mode', 'inline');
assertion.term_assertion = struct('value', jOntologyTerm('', probeType));

bodies = {obs, assertion, anchor};
end
