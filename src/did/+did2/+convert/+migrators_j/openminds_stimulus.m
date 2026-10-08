function bodies = openminds_stimulus(preBody)
%OPENMINDS_STIMULUS Brainstorm-J migrator: did_v1 openminds_stimulus -- DEFERRED to
%   the NDI second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NO LONGER A TERM_ASSERTION
%   ---------------------------------------------------------------------
%   This migrator used to emit one `term_assertion` per document, mirroring its
%   openminds_subject sibling. Every one of the ~635 documents in the corpora came
%   out with an EMPTY `subject_id`, and even correcting that would still have been
%   the wrong shape. Both faults have the same root: the document is not a
%   statement about a subject.
%
%   1. THE REFERENT WAS READ UNDER A NAME THAT DOES NOT EXIST. The old code asked
%      jCarrySubject for `stimulus_id` / `element_id` / `subject_id`. NDI names
%      this edge `stimulus_element_id`, in all three places that could settle it:
%
%        database_documents/metadata/openminds_stimulus.json   stimulus_element_id
%        schema_documents/.../openminds_stimulus_schema.json   { "mustbenotempty": 1 }
%        +ndi/+database/+fun/openMINDSobj2ndi_document.m:58
%                                    dependency_name = 'stimulus_element_id';
%
%      universalRenames normalises a depends_on entry's SHAPE (id/value ->
%      document_id) and never its NAME, so nothing repaired it downstream and
%      jCarrySubject returned ''. `+did2/+validate/references.m:90` skips empty
%      edges, so all 635 validated clean -- the invented-empty-edge pattern.
%
%   2. THE ASSERTION TIER IS TIMELESS, AND THIS FACT IS NOT. Both NDI writers
%      build the same three-part fact -- an approach term, a stimulator, and an
%      EPOCH:
%
%        +setup/+NDIMaker/stimulusDocMaker.m:407-412
%           openMINDSobj2ndi_document(new_approach, session.id, 'stimulus',
%                                     stimulator_id, 'epochid.epochid', epoch_id)
%        +setup/+stimulus/+vhlab/add_stimulus_approach.m:59-65   the same, on probe_id
%
%      `subject_assertion` declares no fields and no edges, and `time_reference_#`
%      lives on `subject_interaction` -- the OTHER branch of the statement tier. So
%      an assertion cannot carry an epoch. The old migrator dropped it outright,
%      and asserted, timelessly, that the STIMULATOR is-a spatial-frequency-tuning.
%      The same stimulator serves a different approach in the next epoch, which is
%      exactly why v1 scoped the document to one.
%
%   ---------------------------------------------------------------------
%   WHERE THESE DOCUMENTS GO
%   ---------------------------------------------------------------------
%   To `interaction_purpose` -- the purpose of what was done in that epoch with
%   that stimulator -- via the NDI SECOND PASS. `interaction_purpose.interaction_id_#`
%   points at interactions, while the source names an epoch and a device; resolving
%   which interactions happened in epoch E with stimulator P needs the migrated
%   graph, which a single-document migrator cannot see. Pass 1 therefore emits
%   NOTHING and carries the document intact.
%
%   Correcting the dependency name alone would have produced 635 well-formed
%   statements that were still the wrong tier and still epoch-less -- a silent loss
%   that validates. That is why this is a re-target and not a rename.
%
%   All 635 are one type: the `openminds_stimulus` count and the
%   `StimulationApproach` count are both 635 in the corpus histogram, so there is
%   no mixed population needing a split.
%
%   THE GUARD. A body carrying a `stimulus_id` dependency is REJECTED BY NAME: no
%   did_v1 document has that edge, so its presence means a fixture or a caller was
%   built against the DID-side schema instead of the real document. Same guard
%   shape as binnedspikeratevm's `num_bins`/`bin_size`.
%
%   See V_eta_go_forward_class_audit.md ("RESOLVED -- the 635 approach documents
%   go to interaction_purpose") and V_eta_openminds_family_record.md Part 7.

arguments
    preBody (1,1) struct
end

if hasDependencyNamed(preBody, 'stimulus_id')
    error('did2:convert:openmindsStimulusInventedEdge', ...
        ['openminds_stimulus body carries a `stimulus_id` dependency, which no ' ...
         'did_v1 document has -- NDI''s template, schema and writer all name the ' ...
         'edge `stimulus_element_id`. This shape can only come from the V_alpha/' ...
         'V_zeta snapshot or a fixture built against it.']);
end

bodies = {preBody};
end

% ===================== small helpers =======================================

function tf = hasDependencyNamed(bodyStruct, name)
tf = false;
if ~isfield(bodyStruct, 'depends_on') || ~isstruct(bodyStruct.depends_on); return; end
for k = 1:numel(bodyStruct.depends_on)
    d = bodyStruct.depends_on(k);
    if isfield(d, 'name') && strcmp(d.name, name); tf = true; return; end
end
end
