function bodies = neuron_extracellular(preBody)
%NEURON_EXTRACELLULAR Brainstorm-J migrator: did_v1 neuron_extracellular -> a
%   DERIVED SUBJECT (the sorted unit) + a derived_from relation + a quality
%   observation (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   A neuron_extracellular is a spike-sorted unit on an extracellular recording,
%   tied to that recording's subject via element_id. #9 analysis-tier "grain B"
%   fold: a sorted cluster is not an observation OF the recording -- it is a
%   DERIVED entity in its own right, so it becomes a `subject` linked back to the
%   recording by a `derived_from` `directed_relation`:
%
%       subject            the sorted unit (bare identity; local_identifier
%                          'unit_<cluster_index>'; id fresh).
%       directed_relation  derived_from: the unit (child) <- the recording subject
%                          (parent). ro:0001000.
%       score_observation  the sort quality_number, as a scalar observation OF the
%                          unit (inline).
%       session_relative_reference   the 'during' anchor for the quality obs.
%
%   1 -> 4. DEFERRED: the inline `mean_waveform` matrix (needs a body-serialization
%   decision -- a sampled_body carries files, not an inline matrix) and a
%   term_assertion of the unit's cell-type kind (subject_defining). Both follow-ups.

arguments
    preBody (1,1) struct
end

blk = getBlock(preBody, 'neuron_extracellular');
recordingSubjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));

clusterIndex = getField(blk, 'cluster_index');
unitName = 'unit';
if isnumeric(clusterIndex) && isscalar(clusterIndex)
    unitName = sprintf('unit_%d', round(clusterIndex));
end

neuronId = did.ido.unique_id();
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');

% ---- the derived subject: the sorted unit ----------------------------------
neuron = struct();
neuron.document_class = struct('class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
neuron.depends_on = struct('name', {}, 'value', {});
neuron.base = struct('id', neuronId, 'session_id', sessionId, ...
    'name', unitName, 'datestamp', datestamp);
neuron.subject = struct('local_identifier', unitName, 'description', ...
    'spike-sorted extracellular unit (derived)');

% ---- the provenance relation: unit derived_from the recording subject -------
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', neuronId), ...
    struct('name', 'parent', 'value', recordingSubjectId)];
rel.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'derived_from', 'datestamp', datestamp);
rel.directed_relation = struct('relation', otTerm('ro:0001000', 'derived_from'));

% ---- the shared session anchor ('during') for the quality observation -------
anchorId = did.ido.unique_id();
anchor = struct();
anchor.document_class = classBlock('session_relative_reference', {'time_reference'});
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

bodies = {neuron, rel, anchor};

% ---- the sort quality as a score_observation OF the unit (inline) -----------
quality = getField(blk, 'quality_number');
if isnumeric(quality) && isscalar(quality)
    qobs = struct();
    qobs.document_class = classBlock('score_observation', {'subject_observation', 'score'});
    qobs.depends_on = [ ...
        struct('name', 'subject_id',       'value', neuronId), ...
        struct('name', 'time_reference_1', 'value', anchorId)];
    qobs.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
        'name', 'migrated_sort_quality', 'datestamp', datestamp);
    qobs.subject_statement = struct('variable', otTerm('', 'spike sort quality'), ...
        'storage_mode', 'inline');
    qobs.subject_interaction = struct('method', otTerm('', ''), ...
        'sample_time', struct('kind', 'point'));
    qobs.subject_observation = struct();
    qobs.score = struct('value', struct('value', double(quality), ...
        'scale', otTerm('', ''), 'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false));
    bodies{end+1} = qobs;
end
end

% ===================== small helpers =======================================

function dc = classBlock(name, supers)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', 'V_eta');
end

function t = otTerm(node, name)
t = struct('node', char(node), 'name', char(name));
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(block, name)
v = [];
if isfield(block, name); v = block.(name); end
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
