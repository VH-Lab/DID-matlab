function bodies = position_metadata(preBody)
%POSITION_METADATA Brainstorm-J migrator: did_v1 position_metadata ->
%   an `observation` with value kind `term` (WHAT kind of position was
%   recorded) about the element's entity + a session anchor. 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ============================ AMBIGUITY FLAG ============================
%   The V_eta position_metadata stub carries NO numeric value field, and the
%   position VALUES are genuinely absent from THIS document. Investigation of
%   the real did_v1 source (NDI-matlab +ndi/+setup/+conv/+haley/doImport.m,
%   Step 6) shows the numeric coordinates (xPosition,yPosition timeseries)
%   ride in a SEPARATE ndi.element.timeseries document -- the one `element_id`
%   points at -- NOT in the position_metadata body. The position_metadata body
%   holds only three DESCRIPTIVE ontology fields:
%       ontologyNode  (v1) -> measurement : WHAT kind of position (e.g. the
%                             C. elegans head/midpoint/tail body part CURIE)
%       units              -> units       : the value unit CURIE (e.g. pixels)
%       dimensions         -> dimensions  : per-axis coordinate-column CURIEs
%   There is NO values/coordinate array anywhere in this document.
%
%   Because there are NO numeric values to fold, emitting a length/position
%   leaf with a value would be INVENTING data. Per the honest-minimal rule we
%   take FOLD B: a single `term_observation` of the element-subject whose
%   spine variable is 'position' (the kind of measurement) and whose leaf
%   `value` is the measurement ontology_term (the v1 `ontologyNode` CURIE).
%   This records WHAT was measured about the subject without fabricating the
%   where. The element-subject is taken from the `element_id` dependency
%   (element dissolved to subject, D2; probe_location idiom).
%
%   DEFERRED / UNDER-SPECIFIED (NDI second pass): (a) the `units` term and the
%   per-axis `dimensions` descriptors are dropped here -- they annotate the
%   coordinate COLUMNS that live in the linked element/timeseries body, which
%   this subject-interaction fold does not carry; (b) the human-readable name
%   of the measurement CURIE is left '' (resolved via ndi.ontology.lookup at
%   the reconciliation pass); (c) binding the recorded position to its actual
%   numeric coordinate body is a Path-S / element-graph job. The class is
%   under-specified for any value-bearing leaf from this document alone.
%   =======================================================================
arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'position_metadata') && isstruct(preBody.position_metadata)
    blk = preBody.position_metadata;
end

% measurement CURIE: v1 `ontologyNode` (universalRenames -> ontology_node).
node = jGetChar(blk, 'ontology_node');
if isempty(node); node = jGetChar(blk, 'ontologyNode'); end

if isempty(node)
    bodies = {preBody};   % no measurement term to record -> carry unchanged
    return;               % (discovery fallback; never invent an observation)
end

% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): the observation has
% no place for the v1 `units` and `dimensions` (DEFERRED (a) above), so a
% document that states either is carried whole as v1 for the dataset's map.
unplaced = {};
for f = {'units', 'dimensions'}
    v = [];
    if isfield(blk, f{1}); v = blk.(f{1}); end
    if ~isempty(v) && ~(ischar(v) && isempty(strtrim(v)))
        unplaced{end+1} = ['position_metadata.' f{1}]; %#ok<AGROW>
    end
end
if ~isempty(unplaced)
    % carry-register: carry-053
    did2.convert.reportNote('carried_as_v1', 'position_metadata', ...
        char(preBody.base.id), ['[carry-053] unplaced: ' strjoin(unplaced, ', ')]);
    bodies = {preBody};
    return;
end

measurement = jOntologyTerm(node, '');       % name resolved in NDI 2nd pass
variable = jOntologyTerm('', 'position');    % the kind of measurement (spine "what")

anchor = jSessionAnchor(preBody, 'during');
obs = jStatement(preBody, 'observation', ...
    jSubjectOf(preBody, {'element_id', 'subject_id'}), variable, measurement, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', char(preBody.base.id), 'ValueKind', 'term');
bodies = {obs, anchor};
end
