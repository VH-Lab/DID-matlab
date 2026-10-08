function obs = jComputedScalar(preBody, anchorId, sourceId, leaf, mixin, variableName, methodName, valueBlock)
%JCOMPUTEDSCALAR Mint a COMPUTED interpretable-scalar observation (D-C analysis
%   tier, Model A). An analysis output (a tuning fit's OSI, orientation
%   preference, ANOVA p, ...) is a computed property OF THE NEURON (grain A):
%
%     <leaf>  a <mixin>_observation on the same subject as its source; subject_id
%             carried from element_id, time_reference_1 -> the shared anchor.
%     subject_interaction.method = the algorithm ontology term -- this is what
%             MARKS the value computed rather than directly measured.
%     depends_on derived_from_1 -> sourceId: the subject_statement leaf this value
%             was computed from (the raw tuning-curve observation). Statement ->
%             statement provenance (the inverse of directed_relation's entity ->
%             entity), per the derived_from_# schema slot.
%     <mixin>.value = valueBlock (the composite the caller built for `mixin`;
%             angle -> a measurement cell, score -> a score cell).
%
%   No new subject and no directed_relation are minted (grain A): a tuning result
%   is a property of the neuron, not a new entity. Shared helper for the
%   Brainstorm-J (+migrators_j) analysis-tier decomposition migrators.
obs = jStartInteraction(preBody, leaf, 'subject_observation', {mixin}, ...
    jOntologyTerm('', variableName), {'element_id', 'subject_id'}, true);
obs.subject_interaction.method = jOntologyTerm('', methodName);   % marks it computed
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchorId);
obs.depends_on(end+1) = struct('name', 'derived_from_1', 'value', sourceId);
obs.(mixin) = struct('value', valueBlock);
end
