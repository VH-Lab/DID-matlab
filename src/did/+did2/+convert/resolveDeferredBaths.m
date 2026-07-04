function result = resolveDeferredBaths(result, options)
%RESOLVEDEFERREDBATHS Coarse, DID-only resolution of deferred stimulus_baths.
%
%   RESULT = did2.convert.resolveDeferredBaths(RESULT) takes the struct
%   returned by did2.convert.v1_to_v2 and resolves the stimulus_bath documents
%   it deferred with did2:convert:needsSessionContext, using ONLY the migrated
%   batch already in hand -- no live NDI session. For each deferred
%   stimulus_bath it:
%
%     - resolves subject_id by following stimulus_element_id to the migrated
%       `element` document in the batch (up the underlying_element_id chain),
%       and
%     - attaches a session_relative_reference('during') time anchor -- the same
%       ordinal fallback the treatment / ontology_table_row migrators use --
%       rather than a precise epoch_bounded_reference.
%
%   It then folds the assembled `bath` (+ anchor) back through v1_to_v2 at the
%   same TargetVersion (they short-circuit as already-target -> pad + validate)
%   and moves the resolved documents from `quarantine` into `migrated`. The
%   bath preserves the source stimulus_bath's base.id, so inbound references
%   resolve to it.
%
%   This is the COARSE resolver for callers without a live session (e.g. corpus
%   discovery). The PRECISE version -- an epoch_bounded_reference on the
%   stimulator's epoch -- is ndi.migrate.local's second pass
%   (ndi.migrate.internal.stimulusBathToBath), which has the element epoch
%   graph. Only one runs per flow: NDI uses the precise path; standalone /
%   corpus callers use this. A stimulus_bath whose element is not in the batch
%   stays quarantined with its original deferral reason.
%
%   Options (name-value):
%     Validate      (1,1 logical, default true) - forwarded to the v1_to_v2
%                   re-validation of the assembled bodies.
%     SchemaCache   ([] or a did2.schema.cache handle, default []) - forwarded.
%     TargetVersion (1,:) char, default 'V_zeta') - the migration target the
%                   assembled bodies are tagged with (Brainstorm I).
%
%   See also: did2.convert.v1_to_v2, did2.convert.migrators_i.stimulus_bath,
%   ndi.migrate.internal.stimulusBathToBath.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_zeta'
end

if ~isfield(result, 'quarantine') || isempty(result.quarantine)
    return;
end

byElement = indexElements(result.migrated);

q = result.quarantine;
keep = true(1, numel(q));
assembled = {};
for k = 1:numel(q)
    if ~isDeferredBath(q(k))
        continue;
    end
    try
        v1Body = jsondecode(q(k).original_body);
        stimulatorId = dependencyValue(v1Body, 'stimulus_element_id');
        subjectId = subjectOfElement(byElement, stimulatorId);   % errors if none
        [bathBody, anchorBody] = makeBath(v1Body, subjectId, options.TargetVersion);
        assembled = [assembled, {anchorBody, bathBody}]; %#ok<AGROW>
        keep(k) = false;   % resolved -> drop the original deferral
    catch
        % element not in batch (or unresolvable): leave it quarantined with
        % its original needsSessionContext reason.
    end
end

if isempty(assembled)
    return;
end

sub = did2.convert.v1_to_v2(assembled, ...
    'Validate', options.Validate, ...
    'SchemaCache', options.SchemaCache, ...
    'TargetVersion', options.TargetVersion, ...
    'Verbose', false);

result.migrated = [result.migrated, sub.migrated];
result.quarantine = [q(keep), sub.quarantine];
result.summary = recountSummary(result);
end

% ===================== element -> subject index ============================

function byElement = indexElements(migrated)
%INDEXELEMENTS Map every migrated element's base.id -> its did2.document.
byElement = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(migrated)
    doc = migrated{k};
    try
        if strcmp(doc.className(), 'element')
            id = char(doc.get('base.id'));
            if ~isempty(id)
                byElement(id) = doc;
            end
        end
    catch
        % skip docs whose class/id cannot be read
    end
end
end

function subjectId = subjectOfElement(byElement, elementId)
%SUBJECTOFELEMENT Follow underlying_element_id up the chain to a subject_id.
visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
cur = char(elementId);
while ~isempty(cur) && ~isKey(visited, cur)
    visited(cur) = true;
    if ~isKey(byElement, cur)
        break;
    end
    doc = byElement(cur);
    deps = docDeps(doc);
    sid = depFrom(deps, 'subject_id');
    if ~isempty(sid)
        subjectId = sid;
        return;
    end
    cur = depFrom(deps, 'underlying_element_id');
end
error('did2:convert:noSubjectForElement', ...
    'Could not resolve a subject_id for element "%s" in the batch.', ...
    char(elementId));
end

% ===================== bath assembly (coarse) ==============================

function [bathBody, anchorBody] = makeBath(v1Body, subjectId, targetVersion)
sessionId = baseField(v1Body, 'session_id', '');
datestamp = baseField(v1Body, 'datestamp', '');
bathId    = baseField(v1Body, 'id', did.ido.unique_id());
mixture   = parseMixture(v1Body);

% session_relative_reference('during'): the ordinal fallback anchor.
anchorId = did.ido.unique_id();
anchorBody = struct();
anchorBody.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
% Session identity rides on base.session_id; no redundant session_id edge
% (it only produced discovery-mode orphans). See V_zeta
% session_relative_reference (depends_on now empty).
anchorBody.depends_on = struct('name', {}, 'value', {});
anchorBody.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchorBody.time_reference = struct('is_approximate', true);
anchorBody.session_relative_reference = struct('relation', 'during');

bathBody = struct();
bathBody.document_class = struct('class_name', 'bath', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'pharmacological_manipulation', ...
        'class_version', '1.0.0'), ...
    'schema_version', targetVersion);
bathBody.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
bathBody.base = struct('id', bathId, 'session_id', sessionId, ...
    'name', 'migrated_bath', 'datestamp', datestamp);
if strcmp(targetVersion, 'V_zeta')
    bathBody.subject_interaction = struct( ...
        'method', struct('node', '', 'name', ''), ...
        'variable', primaryChemical(mixture), ...
        'target_structure', {struct('node', {}, 'name', {})});
    bathBody.manipulation = struct('notes', '');
end
bathBody.pharmacological_manipulation = struct('mixture', mixture);
bathBody.bath = struct('kind', 'drug', 'location', locationTerm(v1Body));
end

function variable = primaryChemical(mixture)
variable = struct('node', '', 'name', '');
if ~isempty(mixture) && isfield(mixture, 'chemical')
    variable = mixture(1).chemical;
end
end

function term = locationTerm(body)
term = struct('node', '', 'name', '');
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'location') ...
        && isstruct(body.stimulus_bath.location)
    loc = body.stimulus_bath.location;
    if isfield(loc, 'node');             term.node = loc.node;
    elseif isfield(loc, 'ontologyNode'); term.node = loc.ontologyNode; end
    if isfield(loc, 'name');             term.name = loc.name; end
end
end

function mixture = parseMixture(body)
mixture = struct('chemical', {}, 'amount', {});
if isfield(body, 'stimulus_bath') && isstruct(body.stimulus_bath) ...
        && isfield(body.stimulus_bath, 'mixture_table')
    raw = body.stimulus_bath.mixture_table;
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        lines = strsplit(char(raw), newline);
        for i = 1:numel(lines)
            cols = strsplit(strtrim(lines{i}), ',', 'CollapseDelimiters', false);
            if numel(cols) < 5 || isempty(strtrim(cols{1}))
                continue;
            end
            chemical = struct('node', strtrim(cols{1}), 'name', strtrim(cols{2}));
            amount = struct('source_value', str2double(cols{3}), ...
                'source_unit', strtrim(cols{5}), 'approximate', false);
            mixture(end+1) = struct('chemical', chemical, 'amount', amount); %#ok<AGROW>
        end
    end
end
if isempty(mixture)
    mixture(1) = struct( ...
        'chemical', struct('node', '', 'name', ''), ...
        'amount', struct('source_value', 0.0, 'source_unit', '', ...
            'approximate', false));
end
end

% ===================== small helpers =======================================

function tf = isDeferredBath(qEntry)
tf = false;
if isfield(qEntry, 'class_name') && strcmp(qEntry.class_name, 'stimulus_bath')
    tf = true;
    return;
end
if isfield(qEntry, 'reason') && ischar(qEntry.reason)
    tf = contains(qEntry.reason, 'needsSessionContext') ...
        || contains(qEntry.reason, 'NDI layer');
end
end

function deps = docDeps(doc)
deps = [];
try
    deps = doc.get('depends_on');
catch
end
end

function v = depFrom(deps, name)
v = '';
for k = 1:numel(deps)
    d = deps(k);
    if isfield(d, 'name') && strcmp(d.name, name)
        if isfield(d, 'value') && ~isempty(d.value); v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
        return;
    end
end
end

function v = dependencyValue(body, name)
v = '';
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    for k = 1:numel(body.depends_on)
        d = body.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value'); v = char(d.value);
            elseif isfield(d, 'document_id'); v = char(d.document_id); end
            return;
        end
    end
end
end

function v = baseField(body, name, default)
v = default;
if isfield(body, 'base') && isstruct(body.base) && isfield(body.base, name)
    v = body.base.(name);
end
end

function summary = recountSummary(result)
summary = result.summary;
summary.migrated_count = numel(result.migrated);
summary.quarantine_count = numel(result.quarantine);
byClass = struct();
for k = 1:numel(result.migrated)
    name = result.migrated{k}.className();
    fieldName = matlab.lang.makeValidName(name);
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end
