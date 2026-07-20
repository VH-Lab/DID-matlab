function bodies = binnedspikeratevm(preBody)
%BINNEDSPIKERATEVM Brainstorm-J migrator: did_v1 binnedspikeratevm -> a body-backed
%   dataseries_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   binnedspikeratevm is a binned spike-rate time series (num_bins bins of
%   bin_size each), tied to a subject via element_id. #9 analysis-tier fold, the
%   same shape as the pyraview / spikewaves folds:
%
%       dataseries_observation  the discoverable spine handle: subject_id, a shared
%                           time anchor, variable = 'binned spike rate',
%                           storage_mode 'body'.
%       sampled_body        the rate series: datum kind 'scalar' (one rate per bin)
%                           + sample_time (regular: dt = bin_size, n = num_bins) +
%                           the carried bytes; statement -> the observation.
%       session_relative_reference   the ordinal 'during' anchor.
%
%   1 -> 3.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'binnedspikeratevm');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
obsId     = baseField(preBody, 'id', did.ido.unique_id());

numBins = numScalar(getField(blk, 'num_bins'), 0);
binSize = durationOf(getField(blk, 'bin_size'));

anchorId = did.ido.unique_id();
bodyId   = did.ido.unique_id();

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable, body-backed dataseries_observation -------------------
% a binned spike RATE is a frequency (Hz) -> the quantity-typed leaf
% frequency_observation (not the abstract/collapsed dataseries_observation branch).
% The rate value lives in the body.
obs = struct();
obs.document_class = classBlock('frequency_observation', {'subject_observation', 'frequency'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', obsId, 'session_id', sessionId, ...
    'name', 'migrated_binnedrate', 'datestamp', datestamp);
obs.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'binned spike rate'), ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
obs.frequency = struct();   % value is body-backed

% ---- the sampled_body holding the binned rate series ------------------------
body = struct();
body.document_class = classBlock('sampled_body', {'data_body'}, TV);
body.depends_on = struct('name', {'statement'}, 'value', {obsId});
body.base = struct('id', bodyId, 'session_id', sessionId, ...
    'name', 'migrated_binnedrate_body', 'datestamp', datestamp);
body.sampled_body = struct( ...
    'datum', struct('kind', 'scalar', 'dtype', '', 'unit', 'Hz', 'shape', []), ...
    'sample_time', struct('regular', true, ...
        't0', durationComposite(0), 'dt', binSize, 'n', numBins), ...
    'summary', struct('value', struct(), 'time', struct()));
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

function c = durationOf(x)
% v1 bin_size may arrive as a raw number of seconds or already a duration struct.
if isstruct(x) && isfield(x, 'source_value')
    c = x;
elseif isnumeric(x) && isscalar(x)
    c = durationComposite(x);
else
    c = durationComposite(0);
end
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

function v = numScalar(x, default)
v = default;
if ~isempty(x) && isnumeric(x) && isscalar(x); v = double(x); end
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
