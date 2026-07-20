function bodies = site2channelmap(preBody)
%SITE2CHANNELMAP Brainstorm-J migrator: did_v1 site2channelmap -> a
%   count_observation (how many recording sites the probe has) + the session
%   anchor. 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   site2channelmap is the probe's site->channel wiring map, tied to the probe via
%   probe_id (device-as-subject, D2). The one subject-relevant quantity is
%   num_sites -- the cardinality of the recording-site set -- so it folds to a
%   single INLINE count_observation on the probe-subject:
%
%       count_observation  subject_id (carried from probe_id), a shared session
%                          anchor, variable = 'number of recording sites',
%                          storage_mode 'inline'; count.value is the count
%                          composite (a plain scalar N, unit-free).
%       session_relative_reference   the 'during' anchor.
%
%   DEFERRED: the actual site_to_channel MAP (which site wires to which channel)
%   is device-configuration, not a subject observation -- re-expressing it as a
%   structured channel map is an instrument-layer / NDI second-pass job, not a
%   subject-side fold. A doc with num_sites absent or zero carries unchanged.
arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'site2channelmap') && isstruct(preBody.site2channelmap)
    blk = preBody.site2channelmap;
end

numSites = 0;
if isfield(blk, 'num_sites') && isnumeric(blk.num_sites) ...
        && isscalar(blk.num_sites) && isfinite(blk.num_sites)
    numSites = double(blk.num_sites);
end

if numSites <= 0
    bodies = {preBody};   % nothing to count -> carry unchanged (discovery fallback)
    return;
end

anchor = jSessionAnchor(preBody, 'during');
obs = jStartInteraction(preBody, 'count_observation', 'subject_observation', ...
    {'count'}, jOntologyTerm('', 'number of recording sites'), ...
    {'probe_id', 'element_id', 'subject_id'});
obs.subject_statement.storage_mode = 'inline';
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.count = struct('value', struct('value', round(numSites), ...
    'unit', jOntologyTerm('', ''), 'approximate', false));

bodies = {obs, anchor};
end
