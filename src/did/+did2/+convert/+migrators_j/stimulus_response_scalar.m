function bodies = stimulus_response_scalar(preBody)
%STIMULUS_RESPONSE_SCALAR Brainstorm-J migrator: did_v1 stimulus_response_scalar ->
%   the subject_calculation LEAF `harmonic_component_calculation` (id PRESERVED)
%   + the shared session anchor. Routed from did2.convert.v1_to_v2 only when
%   TargetVersion == 'V_eta'.
%
%   THE SIGNED MODEL (V_eta_stimulus_response_model_plan.md, TEAM-SIGN-OFF
%   [stimulus response], jess@walthamdatascience.com / 2026-08-08): four classes
%   collapse to TWO -- `harmonic_component` (an abstract data_type composite) plus
%   `harmonic_component_calculation` (its subject_calculation leaf). The sign-off
%   is WITH the three mapping revisions recorded at the bottom of that document;
%   where a revision cannot be built yet, this file says so and says why, rather
%   than silently building the superseded version.
%
%   ---------------------------------------------------------------------
%   GROUND TRUTH -- the WRITER, not a DID-side schema
%   ---------------------------------------------------------------------
%   One writer: NDI-matlab `+ndi/+app/+stimulus/tuning_response.m`,
%   `compute_stimulus_response_scalar`. On origin/main (verified with
%   `git show origin/main:src/ndi/+ndi/+app/+stimulus/tuning_response.m`):
%
%     :320-322  ndi.document('stimulus_response_scalar', ...
%                   'stimulus_response_scalar', stimulus_response_scalar_struct, ...
%                   'stimulus_response',        stimulus_response_struct)
%     :323-324  set_dependency_value('stimulus_response_scalar_parameters_id', param_doc{1}.id())
%     :325      set_dependency_value('element_id',               ndi_timeseries_obj.id())
%     :326      set_dependency_value('stimulus_presentation_id', stim_doc.id())
%     :327      set_dependency_value('stimulus_control_id',      control_doc.id())
%     :328      set_dependency_value('stimulator_id',            ndi_stim_obj.id())
%
%   ALL FIVE EDGES ARE SET ON EVERY DOCUMENT, unconditionally, in a straight
%   line with no branch between them. V_eta dropped `stimulator_id` and
%   `stimulus_control_id` entirely; this fold restores both.
%
%     :309-313  response_structure = struct('stimid', ..., ...
%                   'response_real', ..., 'response_imaginary', ..., ...
%                   'control_response_real', ..., 'control_response_imaginary', ...)
%     :315      stimulus_response_scalar_struct = struct('response_type', response_type, ...
%                   'responses', response_structure)
%     :262-266  if freq_response==0, response_type = 'mean';
%               else                 response_type = ['F' int2str(freq_response)]; end
%
%   That last pair is the whole of the harmonic mapping: `response_type` is a
%   TOTAL FUNCTION of `freq_response`, computed two lines before the document is
%   built, so the harmonic number is recoverable from the response document alone
%   and does NOT require reading the parameters document. 'mean' -> 0, 'F1' -> 1,
%   'F2' -> 2. (`freq_response_commands = [0 1 2]` at :202, so one recording
%   yields three documents, one per harmonic.)
%
%   ---------------------------------------------------------------------
%   MAPPING, AND WHERE IT DEPARTS FROM THE PLAN
%   ---------------------------------------------------------------------
%     element_id                    -> subject_id          (element -> subject; element.m
%                                                           promotes elements to subjects
%                                                           with ids PRESERVED)
%     stimulator_id                 -> instrument_id       T7. RECOVERS a dropped edge.
%     stimulus_presentation_id      -> derived_from_1
%     stimulus_control_id           -> derived_from_2      RECOVERS a dropped edge.
%     stimulus_response_scalar_parameters_id -> method_parameters_id   (see FOLD below)
%     response_type                 -> value.harmonic
%     responses.response_real       -> value.real
%     responses.response_imaginary  -> value.imaginary
%     responses.control_response_real       -> value.control_real
%     responses.control_response_imaginary  -> value.control_imaginary
%     responses.stimid              -> DEFERRED, recoverable (see below)
%     stimulus_response.element_epochid     -> DEFERRED (see below)
%     stimulus_response.stimulator_epochid  -> DROPPED (plan: it is a copy of the
%                                              presentation's own epochid, and the
%                                              presentation is derived_from_1)
%
%   NO NEW ORPHAN RISK FROM THE RESTORED EDGES. All five v1 edges are already on
%   the document today -- it currently passes through unmigrated -- and
%   +did2/+validate/references.m walks a body's depends_on regardless of what the
%   schema declares, so all five are already reference-checked and the corpora
%   report 0 orphans. Re-homing them under new names cannot dangle anything that
%   does not dangle already.
%
%   `derived_from_1`/`_2` are assigned FIXED, not packed sequentially. Revision 3
%   of the plan is explicit that a DOCUMENT names the instances of an
%   interchangeable family, so renumbering the control to `_1` when a presentation
%   edge happened to be absent would make two datasets disagree about what
%   `derived_from_1` means -- the drift test. Which member is the CONTROL is still
%   not recorded by the numbering; that is #52/#63, left open deliberately.
%
%   ---------------------------------------------------------------------
%   THE PARAMETERS FOLD IS DEFERRED, AND THE EDGE IS KEPT SO IT SURVIVES
%   ---------------------------------------------------------------------
%   The sign-off folds `stimulus_response_scalar_parameters_basic` INLINE into
%   `subject_interaction.method_parameters`. A single-document migrator cannot do
%   that: the six fields live on a different document and this pass cannot follow
%   `stimulus_response_scalar_parameters_id`. So pass 1 re-homes the edge onto
%   `subject_interaction.method_parameters_id`, which V_eta declares for exactly
%   this ("named, shared settings this run used"), and leaves the inline
%   `method_parameters` empty -- the schema's own rule is a statement carries the
%   inline field OR the edge, NEVER BOTH (team, 2026-08-09).
%
%   Consequences, all deliberate:
%     * nothing is lost and nothing is invented in pass 1;
%     * the parameters documents MUST keep passing through, or the edge dangles.
%       migrators_j.stimulus_response_scalar_parameters_basic is a guarded
%       passthrough for that reason;
%     * the resolver pass (which sees the migrated batch) inlines the six fields,
%       drops the edge, and only THEN may the 11,440 parameter documents be
%       deleted -- behind the verify-before-delete gate the plan requires.
%   The plan's own BUILD section says the same thing ("one migrator plus one
%   resolver pass"). The resolver is not built here; it is not a migrator and it
%   is out of this change's scope.
%
%   ---------------------------------------------------------------------
%   `responses.stimid`: DEFERRED, AND RECOVERABLE -- with the writer line
%   ---------------------------------------------------------------------
%   Revision 1 of the plan moves `stimid` from `conditions` to an `axes[]` entry,
%   because a per-reading array that positionally indexes the value is an axis and
%   `conditions` tightened to cardinality EXACTLY 1. THE V_ETA SCHEMA HAS NEITHER
%   HALF OF THAT YET: `subject_statement` declares {variable, conditions,
%   storage_mode} and no `axes`, and its `conditions` documentation still carries
%   the pre-amendment D10 sentence. Emitting `axes` would quarantine on
%   `undeclaredField`; emitting `conditions` would write, into 10,124 documents,
%   the exact shape the signed revision rejects.
%
%   So `stimid` is not carried, and that is safe because it is a VERBATIM COPY of
%   data on a document this leaf already points at. From the writer:
%
%     :237-239  stim_stim_onsetoffsetid = [ colvec([presentation_time.onset]) ...
%                   colvec([presentation_time.offset]) ...
%                   colvec(stim_doc.document_properties.stimulus_presentation.presentation_order) ]
%     :248-249  ts_stim_onsetoffsetid   = [ reshape(ts_epoch_t0_out, ...) ...
%                   stim_stim_onsetoffsetid(:,3) ]
%     :309      response_structure = struct('stimid', rowvec(ts_stim_onsetoffsetid(:,3)), ...)
%
%   Column 3 is `stimulus_presentation.presentation_order`, carried through both
%   assignments untouched and in order. `stim_doc` is the document set as
%   `stimulus_presentation_id` at :326 -- i.e. `derived_from_1` on this leaf -- and
%   V_eta's stimulus_presentation tombstone declares `presentation_order`. This is
%   the strain-vs-epoch test from CLAUDE.md answered on the epoch side: the value
%   is a join key into a document that always exists and is always referenced, not
%   content of this document. The axis lands with #45; until then a reader joins.
%
%   ---------------------------------------------------------------------
%   `element_epochid`: DEFERRED. The session anchor is the honest stand-in.
%   ---------------------------------------------------------------------
%   Revision 2 anchors it as a `relative_reference` with `relative_to` -> an
%   `epoch` document. `relative_reference` exists in V_eta and declares
%   `relative_to` mustBeNonEmpty -- and NOTHING IN THIS PIPELINE MINTS AN `epoch`
%   DOCUMENT (no migrator constructs one; the epoch model is #45/#67). All this
%   migrator has is the epoch NAME string, so a relative_reference here would
%   carry an empty required edge: a husk, which references.m skips and no gate
%   catches. Rule: a migrator that cannot do its job does not emit a hollow
%   document. It emits the same 'during' session anchor every other J calculation
%   fold emits, and the epoch string is left for the second pass. This is a REAL
%   deferral of a REAL fact -- unlike stimid, element_epochid comes from
%   `ts_epoch_timeref.epoch` (:317-318) and is not recoverable from another document.
%
%   ---------------------------------------------------------------------
%   THE GUARDS
%   ---------------------------------------------------------------------
%   Three, each returning the document UNCHANGED (the fitcurve / openminds_stimulus
%   / probe_geometry idiom) rather than emitting something hollow:
%     1. no `element_id`     -> no subject. `subject_statement.subject_id` is
%        mustBeNonEmpty, and an empty edge is skipped by references.m, so the
%        result would be a calculation about nobody -- the image_stack husk.
%     2. `response_type` not parseable as 'mean' | 'F<n>' -> the harmonic is
%        unknown, and `harmonic` is the field that makes this class this class.
%     3. `responses.response_real` absent or empty -> there is no value to carry.
%   A passed-through document still validates: V_eta keeps the
%   `stimulus_response_scalar` tombstone (stable tier), and that tombstone has
%   been corrected to NDI's own edge direction.
%
%   1 -> 2 (leaf + session anchor). See
%   did2.convert.migrators_j.private.jCalculation.

arguments
    preBody (1,1) struct
end

blk  = subBlock(preBody, 'stimulus_response_scalar');
resp = subBlock(blk, 'responses');

subjectId = depValue(preBody, 'element_id');
harmonic  = harmonicFromResponseType(charAny(blk, {'response_type', 'responseType'}));
realPart  = numAny(resp, {'response_real', 'responseReal'});

if isempty(subjectId) || isempty(harmonic) || isempty(realPart)
    bodies = {preBody};
    return;
end

% The composite VALUE. Built by assignment, not struct(...), so a cell-valued
% field (which jsondecode can produce for a ragged array) cannot silently turn
% the value into a struct ARRAY.
value = struct();
value.harmonic          = harmonic;
value.real              = realPart;
value.imaginary         = numAny(resp, {'response_imaginary', 'responseImaginary'});
value.control_real      = numAny(resp, {'control_response_real', 'controlResponseReal'});
value.control_imaginary = numAny(resp, {'control_response_imaginary', 'controlResponseImaginary'});

% The shared id-preserving calculation fold: leaf + 'during' session anchor. No
% `app` block on this class, so no software entity and no software_id (checked:
% the NDI template's superclasses are base + stimulus_response only).
%
% `variable` = 'stimulus response'. OPEN 1 and OPEN 2 of the plan are NOT closed:
% the quantity actually measured (firing rate, voltage) is not recorded on any
% document in this family -- only `isspike` on the parameters doc, which merely
% splits spike-derived from continuous -- so the underlying variable has to come
% from the migrated `element`, which is the resolver's walk. A blank term was
% rejected as the alternative: it is a vacuous required field, which the silentLoss
% census counts and which currently reads 0 on every corpus.
bodies = jCalculation(preBody, 'harmonic_component_calculation', 'harmonic_component', ...
    'stimulus response', 'ndi.app.stimulus.tuning_response', ...
    'stimulus_response_scalar', value);

leaf = bodies{1};
leaf.depends_on = setDep(leaf.depends_on, 'instrument_id', ...
    depValue(preBody, 'stimulator_id'));
leaf.depends_on = setDep(leaf.depends_on, 'derived_from_1', ...
    depValue(preBody, 'stimulus_presentation_id'));
leaf.depends_on = setDep(leaf.depends_on, 'derived_from_2', ...
    depValue(preBody, 'stimulus_control_id'));
leaf.depends_on = setDep(leaf.depends_on, 'method_parameters_id', ...
    depValue(preBody, 'stimulus_response_scalar_parameters_id'));
bodies{1} = leaf;
end

% ===================== helpers =============================================

function h = harmonicFromResponseType(rt)
%HARMONICFROMRESPONSETYPE 'mean' -> 0, 'F1' -> 1, 'F2' -> 2; [] when unparseable.
%   The inverse of tuning_response.m:262-266. Anything else returns [] and the
%   caller guards -- the v1 tombstone's field documentation claims 'peak' and
%   'frequency' are also possible, but that text came from DID-schema's own
%   V_alpha snapshot and the writer can emit only these two shapes. Guessing a
%   harmonic for a third shape is the failure this whole repair track exists for.
h = [];
if isempty(rt)
    return;
end
rt = strtrim(lower(char(rt)));
if strcmp(rt, 'mean')
    h = 0;
    return;
end
if numel(rt) >= 2 && rt(1) == 'f'
    tail = rt(2:end);
    if all(isstrprop(tail, 'digit'))
        h = str2double(tail);
    end
end
end

function b = subBlock(bodyStruct, name)
b = struct();
if isstruct(bodyStruct) && isscalar(bodyStruct) && isfield(bodyStruct, name) ...
        && isstruct(bodyStruct.(name)) && isscalar(bodyStruct.(name))
    b = bodyStruct.(name);
end
end

function s = charAny(block, names)
%CHARANY First present name, as char. Snake + camelCase fallback per the
%   standing migrator lesson: universalRenames snake-cases BLOCK-level fields but
%   not the sub-fields of a nested structure, so a nested read needs both.
s = '';
for k = 1:numel(names)
    if isfield(block, names{k})
        v = block.(names{k});
        if ischar(v)
            s = v; return;
        elseif isstring(v) && isscalar(v)
            s = char(v); return;
        end
    end
end
end

function v = numAny(block, names)
%NUMANY First present name, value as-is ([] when absent). Same snake/camel
%   fallback as charAny.
v = [];
for k = 1:numel(names)
    if isfield(block, names{k})
        v = block.(names{k});
        return;
    end
end
end

function v = depValue(bodyStruct, name)
%DEPVALUE Read an edge tolerantly. A depends_on entry is spelled `value` on a
%   body a migrator built and `document_id` once universalRenames has normalised
%   it (universalRenames.m renameDependsOnEntries), and both shapes are live.
%   Precedence copied from +did2/+validate/references.m.
v = '';
if ~isfield(bodyStruct, 'depends_on') || ~isstruct(bodyStruct.depends_on)
    return;
end
for k = 1:numel(bodyStruct.depends_on)
    d = bodyStruct.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name)
        continue;
    end
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    end
    return;
end
end

function deps = setDep(deps, name, value)
%SETDEP Set-or-replace an edge. A NO-OP for an empty value: an invented empty
%   required edge is the 26,406-document pattern in CLAUDE.md, and this migrator
%   restores four edges, so it is exactly the place to be careful.
if isempty(value)
    return;
end
for k = 1:numel(deps)
    if strcmp(deps(k).name, name)
        deps(k).value = value;
        return;
    end
end
deps(end+1) = struct('name', name, 'value', value);
end
