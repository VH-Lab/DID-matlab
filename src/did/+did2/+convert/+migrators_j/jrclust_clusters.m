function bodies = jrclust_clusters(preBody)
%JRCLUST_CLUSTERS Brainstorm-J migrator: did_v1 jrclust_clusters -> a body-backed
%   count_observation (the per-spike cluster assignments) + the session anchor.
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
%       sampled_body       one datum per spike (the cluster index); sample_time
%                          irregular, n = 0 (unknown length -- this class has no
%                          num_spikes/num_clusters metadata); + the carried bytes;
%                          statement -> the observation. The *_res.mat MD5 checksum
%                          is carried into the body summary note.
%       session_relative_reference   the 'during' anchor.
%
%   1 -> 3. NOTE: the individual sorted UNITS are the separate neuron_extracellular
%   docs (each -> a derived subject, grain B); this doc is the run's label series,
%   not the units.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'jrclust_clusters');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
obsId     = baseField(preBody, 'id', did.ido.unique_id());

% jrclust_clusters carries no num_spikes/num_clusters, so the label series length
% is unknown at migration time; n = 0 marks an unknown-length sample_time.
numSpikes = 0;

anchorId = did.ido.unique_id();

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the body-backed count_observation (cluster labels) ---------------------
obs = struct();
obs.document_class = classBlock('count_observation', {'subject_observation', 'count'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', obsId, 'session_id', sessionId, ...
    'name', 'migrated_jrclust_clusters', 'datestamp', datestamp);
obs.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'spike cluster assignment'), ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
obs.count = struct();   % value is body-backed

% ---- the sampled_body: one cluster index per spike --------------------------
body = jSampledBody(obsId, sessionId, datestamp, 'migrated_jrclust_clusters_body', ...
    struct('kind', 'scalar', 'dtype', '', 'unit', '', 'shape', []), ...
    struct('regular', false, ...
        't0', durationComposite(0), 'dt', durationComposite(0), 'n', numSpikes));
% carry the JRCLUST output bytes verbatim (this doc owns them now). The *_res.mat
% MD5 checksum is a regenerable file hash -- not re-expressed on the body.
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end

bodies = {obs, body, anchor};
end

% ===================== small helpers =======================================

function dc = classBlock(name, supers, tv)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', tv);
end

function c = durationComposite(seconds)
c = struct('source_unit', 's', 'source_value', double(seconds), 'approximate', false);
end

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
