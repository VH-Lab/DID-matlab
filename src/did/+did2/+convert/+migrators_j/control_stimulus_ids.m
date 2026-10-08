function bodies = control_stimulus_ids(preBody)
%CONTROL_STIMULUS_IDS Brainstorm-J migrator: did_v1 control_stimulus_ids ->
%   `control_designation` (V_eta_stimulus_model_plan.md, TEAM-SIGN-OFF [stimulus]
%   2026-08-08). A DERIVED annotation of WHICH presented trials are the control
%   reference, computed by the tuning_response app. It is NOT baked into the
%   immutable stimulus body: it REFERENCES the presentation (the timed_sequence
%   body-of-record, id-preserved through the second-pass decompose, so the edge
%   resolves either way) and carries the derivation method; marked derived_from
%   the presentation (T10). Drops the v1 `app` mixin (software model, R1) and the
%   `ids` container word (T13).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   GROUND TRUTH -- NDI origin/main, template + schema + writer
%   ---------------------------------------------------------------------
%     ndi_common/database_documents/stimulus/control_stimulus_ids.json
%         depends_on: [ { "name": "stimulus_presentation_id", "value": [] } ]
%         control_stimulus_ids: { control_stimulus_ids: [],
%                                 control_stimulus_id_method: {} }
%     ndi_common/schema_documents/stimulus/control_stimulus_ids_schema.json
%         depends_on: [ { "name": "stimulus_presentation_id",
%                         "mustbenotempty": 1 } ]
%         superclasses: [ "base" ]
%     +ndi/+app/+stimulus/tuning_response.m:652-656
%         control_stim_ids_struct = struct('control_stimulus_ids', cs_ids(:), ...
%                                          'control_stimulus_id_method', control_stim_id_method);
%         cs_doc = ndi.document('control_stimulus_ids', 'control_stimulus_ids', ...
%                       control_stim_ids_struct) + ..._obj.newdocument();
%         cs_doc = cs_doc.set_dependency_value('stimulus_presentation_id', stim_doc.id());
%
%   Unlike its sibling stimulus_presentation, this class has NO invented edge:
%   `stimulus_presentation_id` is the name NDI uses and the name V_eta's
%   tombstone uses. The `+ ..._obj.newdocument()` term is what puts an `app`
%   block on a real document even though the template lists only `base` as a
%   superclass (ndi.app/newdocument fills app.name/version/url/os/...).
%
%   ---------------------------------------------------------------------
%   WHAT THE NUMBERS ACTUALLY ARE -- read from the writer, not from the name
%   ---------------------------------------------------------------------
%   `control_stimulus_ids` is NOT a list of "which stimuli are controls". It is
%   ONE ENTRY PER TRIAL, and each entry is an INDEX INTO THE TRIAL SEQUENCE
%   naming the control trial that trial should be compared against
%   (tuning_response.m:619-644):
%
%       stimids            = ...stimulus_presentation.presentation_order;
%       control_stim_indexes = find(stimids == controlstimid);   % TRIAL indices
%       cs_ids             = control_stim_indexes(reps);         % regular case
%       ... or the nearest-onset control trial per trial (irregular case)
%
%   When no control stimulus exists at all, the writer emits
%   `cs_ids = nan(size(stimids))` (:628) -- an ALL-NaN array is a normal, real
%   document, which is why `control_designation.control_stimulus` is declared
%   `mustNotHaveNaN: false`. Do not "clean" it.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NO PRESENTATION => NO DESIGNATION
%   ---------------------------------------------------------------------
%   Every number in this document is an index into a presentation. Without the
%   `stimulus_presentation_id` edge the emitted `control_designation` would carry
%   indices into nothing while validating clean -- a husk, the shape that made
%   image_stack's 4,563 subject-less observations and fitcurve's residuals
%   invisible. NDI's schema marks the edge `mustbenotempty` and the writer sets
%   it unconditionally at :656, so this should never fire on a real document;
%   it is carried rather than errored precisely because a missing edge is not
%   proof of a fabricated fixture the way an INVENTED edge name is. The document
%   passes through and shows up in `unconverted_by_class`.
%
%   ---------------------------------------------------------------------
%   DEFERRED, TRACKED
%   ---------------------------------------------------------------------
%   1. The signed model also has control_designation reference THE CONTROL
%      STIMULUS `data_type` DOCUMENT(S). Those documents are minted by the
%      second-pass decompose (see migrators_j/stimulus_presentation.m), so pass 1
%      cannot point at them. The information is not lost: `control_stimulus`
%      carries the trial indices and `timed_sequence_id` carries the
%      presentation, which is everything the second pass needs to resolve them.
%   2. `software_id` (T10 -- the plan records the designation as computed by the
%      tuning_response app) is NOT emitted: `control_designation` declares no
%      such dependency, and the plan's own naming pass drops the `app` straggler.
%      The private jSoftwareFromApp helper is ready if the schema ever gains it.
%   3. `derived_from_1` is the DOCUMENT naming an instance of the `derived_from_#`
%      FAMILY the schema declares (revision 3 of the signed plan). Its cardinality
%      is unexpressed until #63. The schema types the family
%      `must_refer_to_document_class: subject_interaction` while the antecedent
%      here is the presentation body; must_refer is DECLARATIVE (existence-only),
%      so this validates, but the typing is worth revisiting with #63.
%
%   See also: did2.convert.migrators_j.stimulus_presentation (the deferred
%   decompose this document's edges point into).

arguments
    preBody (1,1) struct
end

blk = struct();
if isfield(preBody, 'control_stimulus_ids') && isstruct(preBody.control_stimulus_ids)
    blk = preBody.control_stimulus_ids;
end
presId = depValue(preBody, 'stimulus_presentation_id');

% ---------------------------------------------------------------------------
% THE GUARD (see above): no presentation => the indices index nothing.
% ---------------------------------------------------------------------------
if isempty(presId)
    bodies = {preBody};
    return;
end

v2Body = struct();
v2Body.document_class = struct('class_name', 'control_designation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');

% The presentation body-of-record (the v1 stimulus_presentation id -> the
% second-pass timed_sequence, id-preserved) + provenance (T10: this designation
% was DERIVED from it). Both edges are emitted only with a real value, never as
% an empty placeholder -- an edge present with an empty value is skipped by
% +did2/+validate/references.m:90 and reads as a fact that was recorded.
deps = struct('name', {}, 'value', {});
deps(end+1) = struct('name', 'timed_sequence_id', 'value', presId);
deps(end+1) = struct('name', 'derived_from_1',    'value', presId);
v2Body.depends_on = deps;

v2Body.base = preBody.base;   % id preserved -> inbound references resolve

cd_ = struct('control_stimulus', [], 'method', struct());
if isfield(blk, 'control_stimulus_ids');       cd_.control_stimulus = blk.control_stimulus_ids; end
if isfield(blk, 'control_stimulus_id_method') && isstruct(blk.control_stimulus_id_method)
    cd_.method = blk.control_stimulus_id_method;
end
v2Body.control_designation = cd_;

bodies = {v2Body};
end

% ===================== small helpers =======================================

function v = depValue(preBody, name)
%DEPVALUE Read an edge, tolerant of all three key spellings the pipeline uses.
%   A depends_on entry is `value` on a body a migrator built, `document_id` once
%   universalRenames has normalised it, and raw `id` on an untouched v1 body.
%   Precedence copied from +did2/+validate/references.m.
v = '';
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
for k = 1:numel(preBody.depends_on)
    d = preBody.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'value', 'document_id', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            v = char(d.(key{1}));
            return;
        end
    end
end
end
