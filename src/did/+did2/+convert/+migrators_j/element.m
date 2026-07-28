function v2Body = element(preBody)
%ELEMENT Brainstorm-J migrator: did_v1 element -> subject (+ kind assertions +
%   a lineage relation). Strict J retires the recording-side `element` class
%   (J:214, D2): any identifiable thing -- an organism, a device/probe, a derived
%   signal or sorted unit -- is a `subject`. The element document therefore
%   becomes a `subject` with its id PRESERVED, so the ~50 classes that reference
%   it (`element_id` / `underlying_element_id` / `stimulator_id`) keep resolving
%   -- now to a subject.
%
%   1 -> N:
%     - subject           the element itself (id preserved; name/reference ->
%                         local_identifier).
%     - term_assertion(s) its kind, nothing dropped: `type` -> variable
%                         "element type"; `ndi_element_class` -> variable "ndi
%                         element class" (the MATLAB reconstruction handle; kept
%                         so it is not lost -- reshaping it into a typed kind is a
%                         needs-NDI companion, the same disposition as the
%                         config-class `ndi_*_class` fields).
%     - directed_relation the specimen lineage:
%                         * a derived element (has `underlying_element_id`, or
%                           `direct` = 0) -> `derived_from` its underlying element
%                           (safe computational lineage);
%                         * a direct device (`direct` = 1) -> `observes` the
%                           specimen (the instrument-agent role, J's
%                           instrument_id->subject).
%                         `part_of` (the anatomical claim) is NOT emitted
%                         automatically: a sorted neuron is part of the specimen
%                         but a derived signal is not, and we cannot tell them
%                         apart from `type` without an ontology mapping -- so that
%                         promotion is left to curation rather than fabricated.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'element') && isstruct(preBody.element); block = preBody.element; end

elementId  = baseId(preBody);
name       = jGetChar(block, 'name');
reference  = jGetChar(block, 'reference');
type       = jGetChar(block, 'type');
ndiClass   = jGetChar(block, 'ndi_element_class');
isDirect   = isTruthy(getField(block, 'direct'));
specimenId   = depValue(preBody, 'subject_id');
underlyingId = depValue(preBody, 'underlying_element_id');

localId = name;
if ~isempty(reference); localId = strtrim(sprintf('%s (ref %s)', name, reference)); end
localId = jEnsureLocalId(localId, preBody);   % subject.local_identifier is REQUIRED

% --- the element as a bare subject (id preserved) ---------------------------
subjectDoc = struct();
subjectDoc.document_class = struct('class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
subjectDoc.depends_on = struct('name', {}, 'value', {});
if isfield(preBody, 'base') && isstruct(preBody.base); subjectDoc.base = preBody.base; end
subjectDoc.subject = struct('local_identifier', localId, 'description', '');

bodies = {subjectDoc};

% --- kind assertions (nothing dropped) --------------------------------------
if ~isempty(type)
    bodies{end+1} = kindAssertion(preBody, elementId, 'element type', type);
end
if ~isempty(ndiClass)
    bodies{end+1} = kindAssertion(preBody, elementId, 'ndi element class', ndiClass);
end

% --- the specimen / lineage relation ----------------------------------------
if ~isempty(underlyingId)
    bodies{end+1} = lineageRelation(preBody, elementId, underlyingId, 'derived_from');
elseif isDirect && ~isempty(specimenId)
    bodies{end+1} = lineageRelation(preBody, elementId, specimenId, 'observes');
elseif ~isempty(specimenId)
    bodies{end+1} = lineageRelation(preBody, elementId, specimenId, 'derived_from');
end

v2Body = bodies;
end

% ===================== builders ========================================

function a = kindAssertion(preBody, subjectId, variableName, valueName)
%KINDASSERTION A timeless term_assertion about the element-subject.
a = struct();
a.document_class = struct('class_name', 'term_assertion', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_assertion', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
a.depends_on = struct('name', 'subject_id', 'value', subjectId);
a.base = freshBase(preBody, 'migrated_element_kind');
a.subject_statement = struct('variable', jOntologyTerm('', variableName), ...
    'storage_mode', 'inline');
a.term = struct('value', jOntologyTerm('', valueName));
end

function rel = lineageRelation(preBody, childId, parentId, relationName)
%LINEAGERELATION child --relationName--> parent (both subjects post-retirement).
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', childId), ...
    struct('name', 'parent', 'value', parentId)];
rel.base = freshBase(preBody, 'migrated_element_lineage');
% `relation` (renamed from subject_relation) is abstract with no fields -> no block.
rel.directed_relation = struct('relation', jOntologyTerm('', relationName));
end

% ===================== small helpers ===================================

function id = baseId(preBody)
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = preBody.base.id;
end
end

function base = freshBase(preBody, name)
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end

function v = getField(block, name)
v = [];
if isstruct(block) && isfield(block, name); v = block.(name); end
end

function tf = isTruthy(v)
tf = false;
if islogical(v) && ~isempty(v); tf = v(1);
elseif isnumeric(v) && ~isempty(v); tf = v(1) ~= 0;
elseif ischar(v); tf = any(strcmpi(strtrim(v), {'1', 'true', 'yes'})); end
end

function v = depValue(preBody, name)
v = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value); v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
            return;
        end
    end
end
end
