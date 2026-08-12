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
%   THE RESOLVER IS NO LONGER OWED. IT EXISTS, AND IT IS NAMED HERE (2026-08-12)
%   ---------------------------------------------------------------------------
%   The paragraph above reads as an argument for work still outstanding, and it
%   was true when it was written and is not now. It named
%   `did2.convert.resolveDeferredBaths` as the SHAPE the resolver would take,
%   which is what the plan says; it could not name the resolver, because there
%   was none. There is:
%
%       did2.convert.resolveResponseParameters
%
%   -- the second half of #61, and the half this file defers to. It reads the
%   referenced parameters document out of the migrated batch, writes the five
%   run knobs INLINE onto the leaf's `subject_interaction.method_parameters`,
%   and REMOVES `method_parameters_id`. It is wired into BOTH corpus harnesses
%   (+unittest/+helpers/runCorpusDiscovery.m and +unittest/testCorpusPRED.m) and
%   covered by +unittest/testResponseParametersFold.m.
%
%   The dates are the whole of why this header did not say so: this file was
%   last written at 1c8ab1e (2026-08-10 20:41) and the resolver landed at
%   70ca3f4 (2026-08-11 05:05) -- `git cat-file -e 1c8ab1e:<resolver path>`
%   reports the path absent at this file's own commit. A blocker dismantled in
%   a sibling file, never propagated back to the file that describes it.
%
%   NOTHING ABOUT THIS MIGRATOR CHANGES, and that is the point rather than a
%   caveat. Passing through is what the resolver REQUIRES of pass 1: it reads
%   the six values off this document and follows the leaf's
%   `method_parameters_id` edge to find it. Folding or deleting here would take
%   both away. The passthrough is the built design, not an unfinished one.
%
%   AND THE FOLD IS DORMANT ON REAL CORPORA -- WHICH IS A THIRD FACT, NOT A
%   CONTRADICTION OF THE SECOND. +migrators_j/stimulus_response_scalar.m carries
%   an EPOCH GATE, and on every did_v1 document it takes BRANCH 2 (an epoch
%   STRING but no epoch document): the response passes through unfolded, so no
%   leaf is emitted and `resolveResponseParameters` reports `leaves_seen = 0`
%   beside a non-zero `suppressed_responses_seen`. Branch 1 needs
%   `did2.convert.epochMint` to stamp `epoch_id` onto the pre-body, and
%   epochMint's production arming table (`defaultArmingMigrators`) carries ONE
%   entry today -- `daqmetadatareader_epochdata_ingested`. Adding a row for
%   `stimulus_response_scalar` is #60's build and epochMint's owner's call; it
%   is NOT this file's, and nothing here arms anything.
%
%   So a reader asking "why does the ledger say this class does not emit
%   `method_parameters`" has three separate answers and needs all three: the
%   decided target is an INLINE FIELD BLOCK on another document rather than a
%   class this migrator could ever emit; the emitter is a batch post-pass, not
%   a per-class migrator; and it is gated shut upstream.
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
