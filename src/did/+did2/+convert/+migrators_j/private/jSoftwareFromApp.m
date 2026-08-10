function [software, swId, execEnv] = jSoftwareFromApp(preBody)
%JSOFTWAREFROMAPP Fold a did_v1 `app` block into a `software` entity + the
%   per-run `execution_environment` (the R1 / TEAM-SIGN-OFF [software] model).
%
%   [SOFTWARE, SWID, EXECENV] = jSoftwareFromApp(PREBODY) reads PREBODY's `app`
%   block and returns the `software` entity body to emit alongside the caller's
%   document, its base.id (for a `software_id` edge on the statement), and the
%   `execution_environment` struct to place on `subject_interaction`.
%
%   Returns [] / '' / struct() when the app block carries no software name: no
%   identity means no entity and no edge. EXECENV may still be populated from a
%   nameless app block (the os/interpreter of the run is a fact about the run,
%   not about the software's identity).
%
%   ---------------------------------------------------------------------
%   THE FIELD NAMES ARE READ TOLERANTLY, AND THAT IS A REPAIR
%   ---------------------------------------------------------------------
%   NDI's app template (ndi_common/database_documents/app.json on origin/main)
%   declares exactly:
%
%       name, version, url, os, os_version, interpreter, interpreter_version
%
%   But did2.convert.universalRenames RENAMES two of them before any migrator
%   runs -- universalRenames.m:145-164, renameAppBlockFields():
%
%       app.name    -> app.app_name
%       app.version -> app.app_version
%
%   (V_delta's `app` class spells them with the `app_` prefix.) The previous
%   implementation of this fold lived as a local function inside jCalculation.m
%   and read `app.name` / `app.version` ONLY. On the real pipeline
%   (did2.convert.v1_to_v2, which calls universalRenames FIRST) that field does
%   not exist by the time the migrator sees the body, so `name` came back empty,
%   the function returned early, and NO software entity and NO software_id edge
%   were produced for any real document -- while `execution_environment` (whose
%   four fields are already snake_case and so are NOT renamed) was populated
%   normally. Half the fold, silently.
%
%   It was invisible because the tests that cover it call the migrator DIRECTLY
%   with a hand-built body (testMigratorsJ.m:1707 --
%   `did2.convert.migrators_j.oridirtuning_calc(body)`), so they never run
%   universalRenames and never see the renamed field. That is the CLAUDE.md
%   lesson "a test written from the same premise as the code cannot catch the
%   code", arriving through the harness rather than through the premise.
%
%   So both spellings are accepted, snake/prefixed form first: `app_name` then
%   `name`, `app_version` then `version`. This is the jGetCharAny convention
%   already used across +migrators_j for exactly this reason.
%
%   Shared helper for the Brainstorm-J (+migrators_j) migrators.
arguments
    preBody (1,1) struct
end

% `software` and `swId` are NOT pre-initialised: there is no early return in this
% function, so `[software, swId] = jSoftware(...)` at the end assigns both on
% every path, and initialising them here is dead. Flagged by GitHub code scanning
% (alerts 164/165) and confirmed by reading the control flow rather than assumed
% to be a false positive. `execEnv` IS pre-initialised, because the loop below
% only adds fields conditionally and it must be a struct either way.
execEnv = struct();

app = struct();
if isfield(preBody, 'app') && isstruct(preBody.app) && isscalar(preBody.app)
    app = preBody.app;
end

% Per-run environment: the actual os/interpreter this run used. NOT renamed by
% universalRenames (already snake_case), so one spelling each.
envFields = {'os', 'os_version', 'interpreter', 'interpreter_version'};
for i = 1:numel(envFields)
    v = jGetChar(app, envFields{i});
    if ~isempty(v)
        execEnv.(envFields{i}) = v;
    end
end

name    = jGetCharAny(app, {'app_name', 'name'});
version = jGetCharAny(app, {'app_version', 'version'});
url     = jGetCharAny(app, {'url', 'app_url'});

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    sessionId = jGetChar(preBody.base, 'session_id');
    datestamp = jGetChar(preBody.base, 'datestamp');
end

[software, swId] = jSoftware(name, version, url, sessionId, datestamp);
end
