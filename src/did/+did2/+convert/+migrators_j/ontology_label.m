function bodies = ontology_label(preBody)
%ONTOLOGY_LABEL Brainstorm-J migrator: did_v1 ontology_label -- DEFERRED to the
%   NDI second pass; the document is passed through UNCHANGED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS NOT A MIGRATION: THE LABEL WAS FINE, THE REFERENT WAS LOST
%   ---------------------------------------------------------------------
%   This class was previously assessed BENIGN because the migrator reads the right
%   property field. It does. THE DEPENDENCY IS THE BUG, and it was never checked.
%   The real NDI class (ndi_common/database_documents/data/ontologyLabel.json) is:
%
%       ontologyLabel: { ontologyNode }      -> ontology_label.ontology_node
%       depends_on:    document_id           <- mustbenotempty: 1
%
%   ONE property field, ONE dependency. The migrator asked for
%   {'element_id','subject_id','probe_id'} -- none of which the class has -- and
%   jStartInteraction ASSIGNS `body.depends_on = jCarrySubject(...)` rather than
%   extending it. So on every real document:
%
%       subject_id  came out EMPTY   (declared mustBeNonEmpty, enforced nowhere)
%       document_id was DISCARDED    (the only link to the labelled thing)
%
%   The term survived; what the term was about did not. That is roughly 7,000
%   documents asserting a label about nobody, and it validated cleanly at every
%   gate -- `did2.validate.silentLoss` was written to make exactly this visible.
%
%   The two extra property fields the migrator also reads -- `ontology_name` and
%   `label_id`, with `label` -- do not exist either. They came from the false
%   provenance line in the V_delta conversion doc, which has since been corrected.
%
%   WHY THIS CANNOT BE FIXED BY RENAMING THE EDGE. `document_id` points at the
%   document being labelled, which is NOT a subject -- typically an image stack.
%   Renaming it to subject_id would assert that an image stack is a subject. The
%   subject is one hop further on, through the migrated-id graph:
%
%       ontology_label --document_id--> imageStack --migrates-->
%           image_observation --subject_id--> subject
%
%   DECIDED TARGET for the second pass (which can see that graph): emit a
%   term_observation about the resolved subject, with `derived_from` pointing at
%   the migrated data statement. That keeps BOTH facts -- the term, and what it
%   was about -- and asserts nothing false. Until then the document is carried
%   through intact, so nothing is lost and no false claim is minted.
%
%   V_eta's tombstone declares the real shape so the passthrough validates -- see
%   build_v_eta.py.
%
%   THE GUARD. A body carrying `ontology_name`, `label_id` or `label` is REJECTED
%   BY NAME: those are DID-side inventions, so their presence means a fixture or a
%   caller has been built against our schema instead of the real document. (Note
%   the default +migrators/ontology_label, on the V_delta path, still reads those
%   names; this guard is on the V_eta path only.)
%
%   See V_eta_migrator_vocabulary_audit.md for the evidence.

arguments
    preBody (1,1) struct
end
blk = getBlock(preBody, 'ontology_label');
if isfield(blk, 'ontology_name') || isfield(blk, 'label_id') || isfield(blk, 'label')
    error('did2:convert:ontologyLabelInventedShape', ...
        ['ontology_label body carries `ontology_name`/`label_id`/`label`, ' ...
         'which no did_v1 document has -- the class has exactly one property ' ...
         'field, `ontology_node` (`ontologyNode` before universalRenames), and ' ...
         'one dependency, `document_id`. This shape can only come from the ' ...
         'V_alpha snapshot or a fixture built against it.']);
end
bodies = {preBody};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
