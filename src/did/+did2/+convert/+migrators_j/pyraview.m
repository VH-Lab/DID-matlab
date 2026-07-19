function bodies = pyraview(preBody)
%PYRAVIEW Brainstorm-J migrator: did_v1 pyraview -> a body-backed
%   dataseries_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   pyraview is a multi-resolution PYRAMID view of a sampled signal (level1..10.bin
%   decimation levels + native_rate/channels/data_type), tied to a subject via
%   element_id. In J it dissolves into the data_body model (2.D), exactly like the
%   image_stack fold:
%
%       dataseries_observation  the discoverable spine handle: subject_id, a shared
%                           time anchor, a placeholder subject_statement.variable
%                           (the signal `label`), and storage_mode 'body' (the
%                           cadence lives in the body, D1).
%       sampled_body        the NATIVE-resolution signal: datum (kind/dtype/shape)
%                           + sample_time (t0 = native_start_time, dt = 1/native_rate)
%                           + the carried bytes; statement -> the observation.
%       session_relative_reference   the ordinal 'during' anchor (a pyraview has no
%                           DAQ epoch -- the honest fallback the treatment/image
%                           folds use).
%
%   1 -> 3. The decimated levels 2..10 and the decimation_* descriptors are DROPPED:
%   a pyramid is a regenerable rendering cache derived from the native signal, so
%   it is no information loss (keeps sampled_body lean, per the 2.D Option-1 design).
%
%   NOTE: dataseries_observation and the *_body classes are `draft` in V_eta. This
%   is the pattern-setter for the #9 analysis-tier folds (mint observation + attach
%   sampled_body). pyraview stays in the schema until this is corpus-proven.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'pyraview');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
obsId     = baseField(preBody, 'id', did.ido.unique_id());

label    = getCharField(blk, 'label');
dataType = getCharField(blk, 'data_type');
channels = getField(blk, 'channels');
t0       = numScalar(getField(blk, 'native_start_time'), 0.0);
nativeRt = numScalar(getField(blk, 'native_rate'), 0.0);
dt       = 0.0;
if nativeRt > 0; dt = 1.0 / nativeRt; end

anchorId = did.ido.unique_id();
bodyId   = did.ido.unique_id();

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});   % session rides on base
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the discoverable, body-backed dataseries_observation -------------------
obs = struct();
obs.document_class = classBlock('dataseries_observation', {'subject_observation'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
obs.base = struct('id', obsId, 'session_id', sessionId, ...
    'name', 'migrated_signal', 'datestamp', datestamp);
% storage_mode: body -> the value is in the sampled_body; the statement carries no
% sample_time (the body owns the cadence). variable = the signal label.
obs.subject_statement = struct( ...
    'variable', struct('node', '', 'name', firstNonEmpty(label, 'signal')), ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
% empty geometry block -- axes/channels/label are optional and the value detail
% lives on the body's datum/sample_time; ensureClassBlocks fills the defaults.
obs.dataseries_observation = struct();

% ---- the sampled_body holding the native-resolution signal ------------------
body = struct();
body.document_class = classBlock('sampled_body', {'data_body'}, TV);
body.depends_on = struct('name', {'statement'}, 'value', {obsId});
body.base = struct('id', bodyId, 'session_id', sessionId, ...
    'name', 'migrated_signal_body', 'datestamp', datestamp);
body.sampled_body = struct( ...
    'datum', struct('kind', 'array', 'dtype', dataType, 'unit', '', 'shape', channels), ...
    'sample_time', struct('regular', true, ...
        't0', durationComposite(t0), 'dt', durationComposite(dt), 'n', 0), ...
    'summary', struct('value', struct(), 'time', struct()));
% carry the native bytes over verbatim (universal renames leave file/files
% untouched; this doc owns the digital bytes now). The decimated pyramid levels
% are a regenerable cache and are not re-declared.
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

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
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
