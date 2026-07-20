function bodies = spike_interface_sorting_outputs(preBody)
%SPIKE_INTERFACE_SORTING_OUTPUTS Brainstorm-J migrator: did_v1
%   spike_interface_sorting_outputs -> a count_observation (how many units the
%   sorter found) + the session anchor. 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   spike_interface_sorting_outputs is a spike-sorting RESULT tied to a recording
%   subject via element_id (device-as-subject, D2). #9 analysis-tier fold: the one
%   piece of subject-relevant quantity here is num_units -- the cardinality of the
%   sorted-unit set. That folds to a single INLINE count_observation on the
%   recording subject:
%
%       count_observation  the discoverable spine handle: subject_id (carried from
%                          element_id), a shared session-relative time anchor,
%                          variable = 'number of sorted units', storage_mode
%                          'inline'. count.value is the count composite (a plain
%                          scalar N, unit-free), NOT a body-backed series -- there
%                          is exactly one number, not one datum per unit.
%       session_relative_reference   the 'during' anchor.
%
%   NOTE (grain deferral): this migrator does NOT mint one derived `subject` per
%   sorted unit. That grain-B minting -- turning each unit into its own subject --
%   is neuron_extracellular's job (each neuron_extracellular doc -> a derived
%   subject) / the NDI second pass's, not this run-summary doc's. Here we only
%   report the COUNT. Likewise the sorter provenance (sorter_name /
%   sorter_parameters -> a method + derived_from) is deferred; sorter_name and
%   sample_rate are dropped by this pass rather than mis-folded onto the subject.
%   A doc with num_units absent or zero carries unchanged (discovery fallback):
%   there is no unit to count, so no observation is emitted.
arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'spike_interface_sorting_outputs') ...
        && isstruct(preBody.spike_interface_sorting_outputs)
    blk = preBody.spike_interface_sorting_outputs;
end

numUnits = 0;
if isfield(blk, 'num_units') && isnumeric(blk.num_units) ...
        && isscalar(blk.num_units) && isfinite(blk.num_units)
    numUnits = double(blk.num_units);
end

if numUnits <= 0
    bodies = {preBody};   % nothing to count -> carry unchanged (discovery fallback)
    return;
end

% ---- the session-relative time anchor ('during') ----------------------------
anchor = jSessionAnchor(preBody, 'during');

% ---- the inline count_observation (number of sorted units) ------------------
obs = jStartInteraction(preBody, 'count_observation', 'subject_observation', ...
    {'count'}, jOntologyTerm('', 'number of sorted units'), ...
    {'element_id', 'subject_id'});
obs.subject_statement.storage_mode = 'inline';
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.count = struct('value', struct('value', round(numUnits), ...
    'unit', jOntologyTerm('', ''), 'approximate', false));

bodies = {obs, anchor};
end
