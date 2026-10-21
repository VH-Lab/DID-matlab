function bodies = spatial_gene_expression_pyramid(preBody)
%SPATIAL_GENE_EXPRESSION_PYRAMID Brainstorm-J migrator: did_v1
%   spatialGeneExpressionPyramid -> V_eta spatial_gene_expression_pyramid,
%   PASSED THROUGH. did-schema #88 restates the class as its v1 shape (base +
%   gene_expression, with the v1 `subject_id` / `geneList_id` edges), so the
%   document validates under its own class and nothing is reshaped: no
%   statement, no bound `variable` (the "Gene Expression" binding belongs to
%   the #70 reshape, which #88 does not carry), no session anchor. base.id is
%   preserved so a Cells / Tiles / file_reference row's
%   `spatial_gene_expression_pyramid_id` edge still resolves.
%
%   Returns {pyramid}. 1 -> 1. The reshape history follows below.
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

% did-schema #88 restates `spatial_gene_expression_pyramid` as its v1 shape
% (base + gene_expression, with the v1 `subject_id` / `geneList_id` edges):
% the statement reshape built on did-schema main (#70) is not part of #88. So
% the document PASSES THROUGH and validates under its own class; nothing is
% reshaped. Reported.
bodies = {preBody};
end

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
