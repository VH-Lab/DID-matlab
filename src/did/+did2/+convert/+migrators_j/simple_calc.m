function bodies = simple_calc(preBody)
%SIMPLE_CALC Brainstorm-J migrator: did_v1 simple_calc -- DEFERRED to the NDI
%   second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION
%   ---------------------------------------------------------------------
%   This migrator used to read `result_value` and `result_units` and emit one
%   inline quantity observation whose leaf was chosen from the units (Hz ->
%   frequency, V -> voltage, s -> duration, ...). NONE OF THAT SURVIVES CONTACT
%   WITH THE REAL CLASS. The NDI template
%   (ndi_common/database_documents/apps/calculations/simple_calc.json, written by
%   +ndi/+calc/+example/simple.m) is:
%
%       simple_calc:  { input_parameters: { answer: N }, answer: N }
%       depends_on:   document_id     <- the INPUT DOCUMENT, not a subject
%       superclasses: base, app       <- `calculator` is a V_delta invention
%
%   Three separate problems, only the first of which is a rename:
%
%     1. `result_value` -> `answer`. A plain rename.
%
%     2. `result_units` DOES NOT EXIST. The class carries no units field at all,
%        so the unit dispatch had nothing to dispatch on: every document fell to
%        the `otherwise` branch and became a score_observation with scale_min 0
%        and scale_max 0 -- a degenerate range on a value with no rubric.
%
%     3. THERE IS NO SUBJECT. The migrator looked for `element_id` / `subject_id`;
%        the writer sets exactly one edge, `document_id`, pointing at the document
%        the calculation was run ON. A subject is reachable only by following that
%        edge, which needs the migrated-id graph a single-document migrator cannot
%        see. Emitting an observation anyway would produce a statement about
%        nobody -- exactly the hollow document this whole effort exists to stop
%        (subject_statement.subject_id is declared mustBeNonEmpty and nothing
%        enforces it, so it would have passed every gate).
%
%   Because the read failed on BOTH fields, the isnumeric guard never passed and
%   this migrator has in fact been emitting only a bare session anchor: the
%   result was dropped and a stray time-reference document was all that landed.
%
%   So the document is carried through intact for the NDI second pass, the same
%   strategy stimulus_presentation and ontology_image use. V_eta's `simple_calc`
%   tombstone declares the real shape (base+app, document_id, answer,
%   input_parameters) so the passthrough validates -- see build_v_eta.py.
%
%   THE GUARD. A body carrying `result_value` or `result_units` is REJECTED BY
%   NAME: those are DID-side inventions from the V_alpha snapshot, so their
%   presence means a fixture or a caller has been built against our schema
%   instead of the real document -- the precise mistake being corrected here.
%
%   NOTE ON WORTH: `ndi.calc.example.simple` is a demonstration calculator whose
%   `answer` is copied verbatim from `input_parameters.answer`; it computes
%   nothing. Whether these documents deserve modelling at all, or should simply
%   retire, is an open question recorded in V_eta_ground_truth_plan.md rather
%   than decided here.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'simple_calc');
if isstruct(blk) && (isfield(blk, 'result_value') || isfield(blk, 'result_units'))
    error('did2:convert:simpleCalcInventedShape', ...
        ['simple_calc body carries `result_value`/`result_units`, which no did_v1 ' ...
         'document has -- the real fields are `answer` and `input_parameters`. ' ...
         'This shape can only come from the V_alpha snapshot or a fixture built ' ...
         'against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
