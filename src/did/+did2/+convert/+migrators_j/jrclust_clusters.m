function bodies = jrclust_clusters(preBody)
%JRCLUST_CLUSTERS Brainstorm-J migrator: did_v1 jrclust_clusters -> a body-backed
%   `calculation` with value kind `label` (the per-spike cluster assignments) +
%   an opaque_body + the session anchor (+ software and run documents).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   jrclust_clusters is a JRCLUST spike-sorting RESULT on an extracellular
%   recording: the cluster label of each spike (assignments held in the attached
%   JRCLUST output file), tied to a subject via element_id. #9 analysis-tier fold
%   (pattern 1, body-backed series): the label series is a per-spike integer, so it
%   folds to a count_observation whose value stream is the assignment series:
%
%       count_observation  the discoverable spine handle: subject_id, a shared time
%                          anchor, variable = 'spike cluster assignment',
%                          storage_mode 'body'.
%       sampled_body       one datum per spike (the cluster index); NO axes and no
%                          sample_time -- the length is unknown (this class has no
%                          num_spikes/num_clusters metadata and the count lives in
%                          the payload, which a migrator does not read); + the bytes;
%                          statement -> the observation. The *_res.mat MD5 checksum
%                          is carried into the body summary note.
%       session_relative_reference   the 'during' anchor.
%
%   1 -> 3 (1 -> 4 when the source carries an `app` block; see below).
%   NOTE: the individual sorted UNITS are the separate neuron_extracellular
%   docs (each -> a derived subject, grain B); this doc is the run's label series,
%   not the units.
%
%   ---------------------------------------------------------------------
%   THE `app` BLOCK WAS BEING DROPPED ON THE FLOOR (repaired here)
%   ---------------------------------------------------------------------
%   STATUS OF THIS REPAIR: NOT RUN. There is no MATLAB in the environment it was
%   written in. The gate is tests/+did2/+unittest/testMigratorsJAppFold.m, unrun.
%
%   `jrclust_clusters` declares the `app` superclass on NDI origin/main --
%   read from the template, not from memory:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/apps/jrclust/jrclust_clusters.json
%         superclasses: [ base.json, app.json ]
%
%   This migrator BUILDS NEW BODIES, so the source block had no successor in
%   {count_observation, sampled_body, session_relative_reference} and every
%   app.name / app.version / app.url was discarded. No counter saw it:
%   silentLoss counts empty edges, vacuous fields and fragments, and a source
%   block with no successor is none of the three.
%
%   R1 (TEAM-SIGN-OFF [software], did-schema/schemas/V_eta_tenet_audit.md) says
%   what it becomes: a `software` ENTITY referenced by `software_id`, with the
%   per-run os/interpreter in `execution_environment`. BOTH SLOTS ARE DECLARED
%   ON THE TARGET -- checked in did-schema/schemas/V_eta/stable/
%   subject_interaction.json (depends_on `software_id`, must_refer_to_document_class
%   `software`; field `execution_environment`), which count_observation reaches
%   via subject_observation -> subject_interaction. Nothing is invented.
%
%   RequireSession is TRUE: base.session_id is mustBeNonEmpty and v1_to_v2
%   quarantines the SOURCE when a body it produced fails. It removes nothing --
%   the observation, the body and the anchor all take the same session_id, so a
%   sessionless document already fails on those three; the guard only makes it
%   impossible for the new body to be the cause.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'jrclust_clusters');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', did2.convert.migrationTime());
obsId     = baseField(preBody, 'id', did.ido.unique_id());

% did-schema #88: built through did2.build. The cluster assignment is a
% `count` observation of the recording element; its value is the JRCLUST
% results file, an opaque_body (a binary file, not a sampled array: #88's
% sampled_body requires keys and this file states none). `data_body` IS true
% (did-schema data_body AMENDMENT 5, rule `value_inline_or_body`: no inline
% value, so the value is in data bodies) and no `data_type` is given (Jess
% Haley, 2026-10-21: an opaque_body's `format` term is its encoding). See
% jSorterOutput.
anchor = jSessionAnchor(preBody, 'during');
[software, swId, execEnv] = jSoftwareFromApp(preBody, 'RequireSession', true);
% a calculation names the run's operating system and interpreter
% (operating_system_id / interpreter_id), as jCalculation does
[runDocs, osId, interpreterId] = jRunEntities(preBody, execEnv);
if isempty(swId)
    % a calculation requires its calculator (`software_id`, rule
    % require_inherited); with no v1 `app` block it is the sorter by name, as
    % jCalculation does for a calculator with no app block
    [software, swId] = jSoftware('jrclust', '', '', jSid(preBody), jStamp(preBody), ...
        'RequireSession', true);
end
swOpt = {'OperatingSystemId', osId, 'InterpreterId', interpreterId};
if ~isempty(swId); swOpt = [swOpt, {'SoftwareId', swId}]; end
% 2026-10-21: a CALCULATION with the `label` value kind (TEAM-SIGN-OFF
% [spike-sorter output] 2026-09-29), about the sorted electrode; its input
% edges are added by did2.convert.resolveEpochProbemap ([sorter input], Jess
% Haley 2026-10-21). [sorter keys] says "keys [spike]" applies where the bytes
% are an array; NDI's writer (+ndi/+fun/+probe/+import/+jrclust/probe.m)
% attaches NO file to this document -- only res_mat_MD5_checksum of an
% external jrclust_res.mat -- so there is no array here to key, and no spike
% count to size a key with. The body stays an opaque_body; raised, not decided.
obs = jStatement(preBody, 'calculation', subjectId, ...
    jLabel('spike cluster assignment'), [], 'DataBody', true, ...
    'TimeReferenceIds', {anchor.base.id}, swOpt{:}, 'Id', obsId, 'ValueKind', 'label');
md5 = jGetCharAny(blk, {'res_mat_md5_checksum', 'res_mat_MD5_checksum'});
o = jOpts(preBody);
if ~isempty(md5)
    o = jOpts(preBody, 'Description', sprintf('JRCLUST results (res_mat_MD5_checksum: %s)', md5));
end
body = did2.build.opaqueBody(obs.base.id, did2.build.formatTerm('EDAM:format_2333'), o{:});
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end
bodies = [{obs, body, anchor}, software, runDocs];
end

% ===================== small helpers =======================================

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(block, name)
v = [];
if isfield(block, name); v = block.(name); end
end

function v = charField(x, default)
v = default;
if ~isempty(x) && (ischar(x) || isstring(x)); v = char(x); end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            end
            return;
        end
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end
