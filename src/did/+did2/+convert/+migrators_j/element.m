function v2Body = element(preBody)
%ELEMENT Brainstorm-J migrator: did_v1 element -> subject (+ kind assertions +
%   the raw-recording observation + a lineage relation). Strict J retires the
%   recording-side `element` class
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
%     - <modality>_observation + sampled_body + session anchor
%                         THE RAW RECORDING (open item #30, SIGNED 2026-08-10).
%                         For a DIRECT recording element the signal itself is now
%                         a typed observation OF THE SPECIMEN taken WITH this
%                         element: subject_id = the specimen, instrument_id = this
%                         element-subject (T7), variable = the modality from
%                         `type`, value = a sampled_body. Assembled by
%                         jRecordingObservation; the type -> modality map and its
%                         denominator are in jRecordingModality. Before this, the
%                         raw signal migrated as loose device-attached pieces with
%                         no typed observation and no modality/units at all.
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
%
%   ---------------------------------------------------------------------
%   `observes` RETIRES -- BUT ONLY WHERE ITS REPLACEMENT IS PRESENT
%   ---------------------------------------------------------------------
%   The signed decision: "the loose `probe observes specimen` relation RETIRES in
%   favour of the `instrument_id` edge". It does, and it does so exactly where
%   that edge got written -- jRecordingObservation returns RETIREOBSERVES true
%   only when it emitted an observation carrying `instrument_id`. Where it did
%   not (a stimulator-class element, whose delivery is a manipulation and whose
%   instrument edge arrives with the stimulus model #31/#43; or an element type
%   Guard A could not resolve) the relation is KEPT, because dropping a link with
%   nothing standing in its place is data loss, not a retirement. Same shape as
%   the guarded passthroughs in fitcurve.m / openminds_stimulus.m.
%
%   NOTE FOR WHOEVER RUNS THE TEST SUITE NEXT:
%   tests/+did2/+unittest/testMigratorsJ.m carries
%   `testElementDirectDeviceObservesSpecimen`, which asserts the `observes`
%   relation for a direct 'n-trode' element. That type now resolves to a
%   voltage_observation, so the relation is gone and THAT TEST WILL FAIL. It
%   asserts the behaviour this decision retires, so it needs INVERTING, not
%   patching -- the same call as the three tests that had asserted the `epochid`
%   bug (CLAUDE.md: "A TEST WRITTEN FROM THE SAME PREMISE AS THE CODE CANNOT
%   CATCH THE CODE"). It is left alone here only because testMigratorsJ.m is
%   outside this change's file scope and is being edited concurrently.

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

% --- the raw recording as a typed observation of the specimen (#30) ----------
% Only for a DIRECT element: `direct` = 1 means the element feeds data straight
% through (element_schema.json: "Does this element directly feed data from an
% underlying element?"), and ndi.probe sets it to 1 by construction
% (+ndi/probe.m:47-50 fills inputs{6} = 1). A DERIVED element (direct = 0) is a
% computed signal or a sorted unit -- spike trains ride with the ensemble model
% and its NDI second pass, not here.
recordingBodies = {};
retireObserves = false;
unresolvedLabel = '';
if isDirect
    [recordingBodies, retireObserves, unresolvedLabel] = jRecordingObservation( ...
        preBody, elementId, specimenId, type, ndiClass);
end
if ~isempty(unresolvedLabel)
    % Guard A's queryable worklist entry, built from declared fields only --
    % see the jRecordingObservation header for why the signed
    % `modality_unresolved` flag has no schema home yet.
    bodies{end+1} = kindAssertion(preBody, elementId, 'modality unresolved', ...
        unresolvedLabel);
end

% --- the specimen / lineage relation ----------------------------------------
if ~isempty(underlyingId)
    bodies{end+1} = lineageRelation(preBody, elementId, underlyingId, 'derived_from');
elseif isDirect && ~isempty(specimenId)
    if ~retireObserves
        bodies{end+1} = lineageRelation(preBody, elementId, specimenId, 'observes');
    end
elseif ~isempty(specimenId)
    bodies{end+1} = lineageRelation(preBody, elementId, specimenId, 'derived_from');
end

v2Body = [bodies, recordingBodies];
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
