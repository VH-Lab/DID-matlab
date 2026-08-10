function bodies = stimulus_response_scalar_parameters_basic(preBody)
%STIMULUS_RESPONSE_SCALAR_PARAMETERS_BASIC Brainstorm-J migrator: DEFERRED
%   guarded passthrough. The signed model folds this class INLINE into
%   `subject_interaction.method_parameters` on the response leaf; pass 1 cannot,
%   and must not delete the documents in the meantime. Routed from
%   did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THE DISPOSITION (V_eta_stimulus_response_model_plan.md, TEAM-SIGN-OFF
%   [stimulus response], 2026-08-08):
%
%       stimulus_response_scalar_parameters_basic  FOLD -> method_parameters
%                                                  (inline); id dropped
%
%   WHY THIS FILE DOES NOTHING, DELIBERATELY
%   ----------------------------------------
%   The fold is a JOIN. These six fields belong on the response document, and a
%   single-document migrator cannot put them there: it sees the parameters
%   document alone, with no way to find which responses point at it. The plan's
%   BUILD section says so in its own words -- "one migrator plus one resolver
%   pass" -- and names the mechanism (did2.convert.resolveDeferredBaths resolves
%   deferred documents against the migrated batch with no live session).
%
%   Doing it from this side would mean minting the inline block onto a document
%   nobody reads and then deleting it, or deleting the document here and losing
%   the fields entirely. Both are worse than waiting.
%
%   THE DOCUMENTS MUST SURVIVE PASS 1, NOT MERELY "MAY"
%   ---------------------------------------------------
%   migrators_j.stimulus_response_scalar re-homes the v1
%   `stimulus_response_scalar_parameters_id` edge onto the leaf's
%   `subject_interaction.method_parameters_id`, so the reference is preserved
%   until the resolver inlines it. If this migrator dropped or dissolved the
%   parameters documents, every one of those edges would dangle and the corpus
%   0-orphan gate would go red. Passing through keeps the reference resolvable
%   AND keeps the six field values intact for the resolver to read.
%
%   Only after the resolver lands may these documents be deleted, and only behind
%   the verify-before-delete gate the plan requires (the same gate the ensemble
%   fold got). The grep gate is already run: the ids have no archived referent
%   outside NDI's own cascade-delete helper (stimulusResponse.m:371).
%
%   THE TOMBSTONE IS ALREADY CORRECT, SO THE PASSTHROUGH VALIDATES
%   --------------------------------------------------------------
%   V_eta's stimulus_response_scalar_parameters_basic tombstone declares the six
%   real fields and NO depends_on. That matters: it used to declare a REQUIRED,
%   INVENTED `stimulus_response_scalar_id` (NDI has the edge the other way, on the
%   response, at tuning_response.m:323), which made every one of these documents
%   the largest single instance of the invented-empty-edge pattern -- 11,440
%   documents, 100% empty. That repair has landed schema-side; this migrator must
%   not re-introduce the edge, and does not.
%
%   NDI ground truth for the six fields, from the writer
%   (`git show origin/main:src/ndi/+ndi/+app/+stimulus/tuning_response.m`):
%
%       :172  temporalfreqfunc          = 'ndi.fun.stimulustemporalfrequency'
%       :173  freq_response             = []      (then 0/1/2 per document, :202/:260)
%       :174  prestimulus_time          = []
%       :175  prestimulus_normalization = []
%       :176  isspike                   = 0 ...
%       :179-182   ... and = 1 when the timeseries element's type is 'spikes'
%       :177  spiketrain_dt             = 0.001
%       :276-281 the document is built from exactly those six, via
%                vlt.data.var2struct, and ONLY when the dedup search finds no match
%
%   `freq_response` is the HARMONIC NUMBER (0/1/2), not a boolean -- the response
%   leaf takes it from `response_type` instead, which the writer derives from it
%   two lines earlier, so the harmonic does not depend on this document surviving.
%
%   Counted as `unconverted` by v1_to_v2, which is correct and intended: an
%   unconverted count on a class that is SUPPOSED to convert is the signal that
%   the resolver has not landed.

arguments
    preBody (1,1) struct
end
bodies = {preBody};
end
