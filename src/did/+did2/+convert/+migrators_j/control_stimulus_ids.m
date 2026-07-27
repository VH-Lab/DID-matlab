function v2Body = control_stimulus_ids(preBody)
%CONTROL_STIMULUS_IDS Brainstorm-J migrator: did_v1 control_stimulus_ids ->
%   `control_designation` (stimulus re-audit, V_eta_stimulus_model_plan.md). A DERIVED
%   annotation of WHICH presented stimuli are the control reference (computed by the
%   tuning_response app). It is NOT baked into the immutable stimulus body: it references
%   the presentation (the timed_sequence body-of-record; id-preserved through the 2nd-pass
%   decompose, so the ref resolves) and carries the derivation method; marked derived_from
%   the presentation (T10). Drops the v1 `app` mixin (software model, R1) and the `ids`
%   container word (T13). Routed only when TargetVersion == 'V_eta'.
arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'control_stimulus_ids') && isstruct(preBody.control_stimulus_ids)
    blk = preBody.control_stimulus_ids;
end
presId = depValue(preBody, 'stimulus_presentation_id');

v2Body = struct();
v2Body.document_class = struct('class_name', 'control_designation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');

deps = struct('name', {}, 'value', {});
if ~isempty(presId)
    % the presentation body-of-record (v1 stimulus_presentation id -> the 2nd-pass
    % timed_sequence, id-preserved) + provenance (this designation is derived from it).
    deps(end+1) = struct('name', 'timed_sequence_id', 'value', presId);
    deps(end+1) = struct('name', 'derived_from_1',    'value', presId);
end
v2Body.depends_on = deps;

v2Body.base = preBody.base;   % id preserved -> inbound references resolve

cd_ = struct('control_stimulus', [], 'method', struct());
if isfield(blk, 'control_stimulus_ids');       cd_.control_stimulus = blk.control_stimulus_ids; end
if isfield(blk, 'control_stimulus_id_method') && isstruct(blk.control_stimulus_id_method)
    cd_.method = blk.control_stimulus_id_method;
end
v2Body.control_designation = cd_;
end

% ---- helper ----
function v = depValue(preBody, name)
v = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value); v = char(d.value); return;
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id); return; end
        end
    end
end
end
