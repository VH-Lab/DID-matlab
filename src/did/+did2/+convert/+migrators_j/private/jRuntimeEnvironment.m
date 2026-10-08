function [rt, rtId] = jRuntimeEnvironment(execEnv, sessionId, datestamp)
%JRUNTIMEENVIRONMENT Mint a `runtime_environment` entity from an execEnv struct.
%
%   PR #68 makes `runtime_environment_id` a REQUIRED edge on `calculator`, and
%   the per-run os / interpreter facts move OUT of subject_interaction.
%   execution_environment (which previously carried them inline) and INTO a
%   standalone `runtime_environment` entity referenced by that edge. This helper
%   builds the entity body and returns its id for the caller's edge list.
%
%   Returns [] / '' when EXECENV carries no populated field: no facts, no entity
%   and no id -- the invented-empty pattern this repo counts. The caller then
%   omits the runtime_environment_id edge on the leaf; the calculator schema
%   marks the edge REQUIRED, so a hand-built test body with no `app` block will
%   quarantine, which is the honest outcome for a body that names no producer.
%
%   Fields mirror `runtime_environment.json` (os, os_version, interpreter,
%   interpreter_version). Absent fields are OMITTED from the emitted block
%   rather than emitted as '': the schema types each as `char` with blank_value
%   '', and absence validates while '' also validates -- but omitting keeps a
%   census read of "how many runs recorded os_version" honest.
arguments
    execEnv (1,1) struct
    sessionId (1,:) char
    datestamp (1,:) char
end
% The calculator schema (V_eta) declares `runtime_environment_id` as REQUIRED
% (min_count 1, mustBeNonEmpty true) on every calculator output, so this
% helper ALWAYS mints an entity for the caller to reference. When the source
% carries os/interpreter facts they land on the entity's fields; when it does
% not, the entity is a minimal one -- the FOUR fields are all mustBeNonEmpty
% false in runtime_environment.json, so absence is a legal "not stated".
% Minting a minimal one is the honest defect for a source that never recorded
% its runtime, not an invented fact; refusing to mint would strand every calc
% doc without an app block.
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end
rtId = did.ido.unique_id();
rtBlock = struct();
fields = {'os', 'os_version', 'interpreter', 'interpreter_version'};
for i = 1:numel(fields)
    nm = fields{i};
    if isfield(execEnv, nm) && ~isempty(execEnv.(nm))
        rtBlock.(nm) = execEnv.(nm);
    end
end
rt = struct();
rt.document_class = struct('class_name', 'runtime_environment', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rt.depends_on = struct('name', {}, 'value', {});
rt.base = struct('id', rtId, 'session_id', sessionId, ...
    'name', 'migrated_runtime_environment', 'datestamp', datestamp);
rt.runtime_environment = rtBlock;
end
