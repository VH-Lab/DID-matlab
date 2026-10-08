function bodies = spatial_gene_expression_pyramid(preBody)
%SPATIAL_GENE_EXPRESSION_PYRAMID Brainstorm-J migrator: did_v1
%   spatialGeneExpressionPyramid -> V_eta spatial_gene_expression_pyramid
%   (⊂ [base, gene_expression, subject_observation]) + the shared session
%   anchor. Carries the observation direction: `variable` bound to
%   NCIT:C16608 "gene expression" per the DID-schema binding registry;
%   `subject_id` carried from v1 depends_on onto the inherited
%   subject_statement slot; `time_reference_1` pointing at a
%   session_relative_reference `during` anchor (the smallest legitimate
%   anchor for a static spatial-transcriptomics section -- see the
%   PROVISIONAL SHAPES block below); the pyramid's own block fields
%   (chip_serial, pipeline_version, bin geometry, byte_order, ...) and
%   the gene_expression mixin fields (assay, count_type, count_units)
%   carry through verbatim. base.id is preserved so a Cells / Tiles /
%   file_reference row's `spatial_gene_expression_pyramid_id` edge still
%   resolves.
%
%   Returns {pyramid, anchor}. 1 -> 2 fan-out.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [spatial_transcriptomics_family], Steve Van Hooser
%   2026-09-22 (did-schema/schemas/V_eta_go_forward_class_audit.md):
%   Corrected Option C from Waltham-Data-Science/DID-schema#70. Structural:
%   the pyramid becomes ⊂ [base, gene_expression, subject_observation]
%   (was ⊂ [base, geneExpression]), picking up variable /
%   method_parameters / sample_time / time_reference_# from the
%   subject_observation direction; the existing subject_id required-ness
%   moves from the class's own declaration to the inherited slot. The
%   `variable` binding was landed by the same DID-schema commit
%   (71298fd, schemas/V_eta/stable/binding_registry_meta.json) --
%   {node: "NCIT:C16608", name: "gene expression"} bound to
%   `spatial_gene_expression_pyramid`. Scope: DID-schema OPEN_WORK
%   #122 / #123. Row #124 (corpus proof) is DEFERRED -- none of the 6
%   target corpora holds this class.
%
%   ---------------------------------------------------------------------
%   PROVISIONAL SHAPES -- OPEN TEAM QUESTIONS, FLAGGED
%   ---------------------------------------------------------------------
%   Two decisions on this document are modelling, not transcription, and
%   are flagged for team review. This migrator ships the smallest
%   legitimate shape and pins the choice with the tests, so a team decision
%   the other way is a one-line change here plus a test update:
%
%     1. `time_reference_1` / `sample_time`. A static spatial-transcriptomics
%        section has no per-sample cadence (`sample_time.kind = 'point'`) and
%        no real-time acquisition timestamps. The subject_interaction schema
%        requires at least one `time_reference_#` (min_count 1,
%        did-schema/schemas/V_eta/stable/subject_interaction.json). The
%        smallest legitimate anchor is a `session_relative_reference` with
%        `relation: during` and no metric -- the same handle
%        jSessionAnchor already mints for treatment / location / label rows,
%        which have no DAQ epoch either. Adopted here provisionally. If the
%        team wants no time anchor at all (with a schema relaxation on
%        DID-schema), delete the anchor and the time_reference_1 edge.
%
%     2. `method` / `method_parameters`. The geneExpression mixin's assay /
%        count_type / count_units are semantically the assay method, but the
%        schema declares them as scalar char fields on the mixin, NOT as a
%        subject_interaction.method ontology_term. Whether to ALSO write a
%        `method` term (and if so, what CURIE -- OBI, EFO, NCIT?) is a
%        follow-up modelling call. Default here: pass the mixin fields
%        through unchanged, leave `subject_interaction.method` empty and
%        `subject_interaction.method_parameters` an empty struct.
%
%   Both flagged as OPEN_WORK #126 candidates (T8 binding follow-ons for
%   the family); the write-up is on the DID-matlab PR body for the team
%   to answer against.
%
%   ---------------------------------------------------------------------
%   THE HELPER QUESTION
%   ---------------------------------------------------------------------
%   The brief flagged a possible `jGeneExpressionObservation` helper
%   analogous to jCalculation. Held off for now: only ONE class in this
%   family carries the subject_observation direction (the pyramid), so
%   there is no duplication to extract. If a second subject_observation
%   -shaped source lands (a bulk RNA-seq class, say), the shape below
%   promotes cleanly to a helper by copying the three lines that set
%   subject_statement.variable / subject_interaction.sample_time /
%   subject_interaction.method_parameters and the anchor wiring; nothing
%   here would resist that extraction.

arguments
    preBody (1,1) struct
end

TV = 'V_eta';
CLASS = 'spatial_gene_expression_pyramid';

% ---------------------------------------------------------------------
% THE ANCHOR -- smallest legitimate time_reference_# (open question 1).
% ---------------------------------------------------------------------
anchor = jSessionAnchor(preBody, 'during');

% ---------------------------------------------------------------------
% THE PYRAMID BODY.
% ---------------------------------------------------------------------
pyramid = preBody;

% depends_on: carry every edge the v1 body had (gene_list_id required,
% source_file_id optional, plus any subject_id the v1 source declared)
% and add the new time_reference_1 edge to the anchor. Copying the v1
% depends_on first, THEN appending, preserves the source's own edge set
% and its ordering.
if ~isfield(pyramid, 'depends_on') || ~isstruct(pyramid.depends_on)
    pyramid.depends_on = struct('name', {}, 'value', {});
end

% Make sure subject_id is present -- required-via-inheritance on
% subject_statement (mustBeNonEmpty: true). If the v1 source carried it
% under a different edge name, jCarrySubject will hand its value back;
% otherwise the emitted `subject_id` entry stays empty (which is what
% RequiredDependencies quarantines on -- a loud failure, not a silent
% husk). Deliberately not invented.
if ~hasDep(pyramid, 'subject_id')
    subjDep = jCarrySubject(preBody, {'subject_id'});
    pyramid = appendDep(pyramid, subjDep.name, subjDep.value);
end

pyramid = appendDep(pyramid, 'time_reference_1', anchor.base.id);

% document_class: universalRenames has snake_cased the class name; the
% superclasses list is rebuilt by ensureClassBlocks against the V_eta
% schema chain, so nothing to do here. Stamp the schema_version anyway
% (v1_to_v2 also stamps it on the way out; done here too so tests that
% call the migrator directly see the tag).
if ~isfield(pyramid, 'document_class') || ~isstruct(pyramid.document_class)
    pyramid.document_class = struct();
end
pyramid.document_class.class_name = CLASS;
pyramid.document_class.schema_version = TV;

% base.id preserved: pyramid = preBody already copied it. No mutation.

% gene_expression mixin: keep whatever the v1 source had. When absent,
% ensureClassBlocks will pad an empty block; the schema's fields all
% default to empty char, so validation stays green either way.

% Own block: pyramid.spatial_gene_expression_pyramid already carries
% every property field via the preBody copy; no reshape needed.

% subject_statement (inherited): variable is REQUIRED and BOUND. This is
% the one place the migrator states a fact the source did not carry --
% but the fact is the class's identity (this document is a spatial gene
% expression pyramid), not a value invented for it, and the binding
% registry entry that made it callable was signed on the same commit
% that landed the schemas.
pyramid.subject_statement = struct( ...
    'variable',     jOntologyTerm('NCIT:C16608', 'gene expression'), ...
    'storage_mode', 'inline');

% subject_interaction (inherited): time_reference_# is carried on the
% depends_on above; the fields here are what remain on the block itself.
% `method` is OMITTED (not written empty) by design -- an empty
% ontology_term would trip did-schema's unminted-term ratchet (#70), and
% the pyramid's method decision is still open (see open question 2).
% Absence is a legal state per the schema (method.mustBeNonEmpty: false),
% and it is the honest one: this migrator has no method to report.
% method_parameters stays an empty struct; sample_time.kind = 'point' --
% the pyramid describes a single fixed moment (a captured section), not
% a cadence.
pyramid.subject_interaction = struct( ...
    'method_parameters', struct(), ...
    'sample_time',       struct('kind', 'point'));

% subject_observation (inherited): derived_from_# stays empty -- the
% pyramid is primary data, not a computation over another statement.
% Left as an empty struct so ensureClassBlocks does not re-add it under a
% wrong shape (it manufactures a bare struct(), which is what we want).
pyramid.subject_observation = struct();

bodies = {pyramid, anchor};
end

% ===================== helpers =============================================

function tf = hasDep(body, name)
tf = false;
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on); return; end
for k = 1:numel(body.depends_on)
    if isfield(body.depends_on(k), 'name') ...
            && strcmp(body.depends_on(k).name, name)
        tf = true; return;
    end
end
end

function body = appendDep(body, name, value)
% Append a (name, value) depends_on entry. Preserves the existing struct
% array shape -- if depends_on came in with `document_id` (the universal
% renames spelling), the new entry uses the same field so the array
% stays homogeneous.
entry = struct('name', name, 'value', value);
if isfield(body, 'depends_on') && isstruct(body.depends_on) ...
        && ~isempty(body.depends_on) ...
        && isfield(body.depends_on(1), 'document_id') ...
        && ~isfield(body.depends_on(1), 'value')
    entry = struct('name', name, 'document_id', value);
end
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    body.depends_on = entry;
else
    body.depends_on(end+1) = entry;
end
end
