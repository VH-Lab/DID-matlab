% +migrators  Per-class did_v1 -> V2 migrator functions.
%
%   The one file left, element_epoch, is not dispatched by class: it splits
%   t0_t1 -> (t0, t1) on an `element_epoch` block, and
%   +migrators_j/element_epoch.m and oneepoch.m call it on the raw block.
%
%   The dispatcher no longer looks migrators up here. The rename pass
%   (universalRenames), the superclass pass and the `identity` fallback are
%   deleted ([migrators read raw v1]; [early migration pieces fixed] (1), Jess
%   Haley, 2026-10-26: "a class with no migrator is a recorded decision, not an
%   identity fallback"). The probe_location and treatment wrappers went
%   earlier. `ngrid` is deleted too: a standalone `ngrid` document is carried
%   whole as v1 by did2.convert.v1_to_v2 itself, carry-123 ([ngrid with no
%   statement carried], Jess Haley, 2026-10-29); a superclass `ngrid` block is
%   read by +migrators_j/+super/ngrid.m, called by its leaf's migrator.
%
%   The calculator-base wrappers are all deleted, with their shared helper
%   calcCommon: the tuning family's (tuningcurve_calc, oridirtuning_calc,
%   contrast_sensitivity_calc, contrast_tuning_calc,
%   spatial_frequency_tuning_calc, temporal_frequency_tuning_calc) and then
%   hartley_calc, speed_tuning_calc and simple_calc, with jrclust_clusters'
%   rename. Each class has a +migrators_j migrator, so the wrapper was never
%   reached; the classes read raw v1 (did2.convert.rawV1Classes; simple_calc
%   is not switched, see there; [early migration pieces fixed] (1), Jess
%   Haley, 2026-10-26).
%
%   The position_metadata, distance_metadata and stimulus_bath base migrators
%   are deleted too: each class has a +migrators_j migrator, which reads raw v1
%   (distance_metadata's reshaped the v1 spelling itself, where it used to hand
%   the renamed body to the base migrator; since [reshaped retire classes
%   carried], Jess Haley, 2026-10-29, it carries every document whole as v1).
%
%   The element, ontology_image and ontology_label base migrators are deleted
%   (2026-10-27): each class has a +migrators_j migrator that reads raw v1, and
%   no NDI template at the locked main names element, ontologyImage or
%   ontologyLabel as a superclass, so nothing reached them. element_epoch stays
%   (+migrators_j/element_epoch.m and oneepoch.m call it on the raw block).
%   The epochclocktimes and filter SUPERCLASS migrators are deleted (Decided by
%   Jess Haley, 2026-10-27 [unreached superclass migrators deleted], did-schema
%   V_eta_go_forward_class_audit.md): pyraview, the only class at the locked
%   NDI main that names either as a superclass, reads raw v1 since DID-matlab
%   PR #256 (did2.convert.rawV1Classes), so no superclass pass runs on it, and
%   no writer at that main constructs a leaf `epochclocktimes` or `filter`
%   document.
%
%   See did-schema's
%   did-schema's per-class conversion notes (deleted with did-schema #88) for the
%   per-class specifications.
