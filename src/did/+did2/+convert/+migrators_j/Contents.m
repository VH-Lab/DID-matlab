% +migrators_j  did_v1 -> V_eta (Brainstorm J) split/fold migrators.
%
%   Routed by did2.convert.v1_to_v2 ONLY when TargetVersion == 'V_eta'.
%   The dispatcher applies the universal renames first, then -- for a class
%   that has a file here -- runs this migrator instead of the default
%   +migrators/<class> one. A migrator may return a single body OR a cell /
%   struct array of several bodies (1 -> N fan-out).
%
%   Brainstorm J (did-schema/schemas/V_eta) rebuilds the SUBJECT SIDE:
%     - `subject` is a BARE identity card (no is_group / is_biological); kind
%       is a term_assertion, group-ness is derived from member_of edges.
%     - `subject_statement` is restored and owns `variable` (+ storage_mode);
%       `subject_interaction` adds `method` + `sample_time`; the direction
%       classes are `subject_observation` / `subject_manipulation`.
%     - Leaves are named by DATA TYPE (mass_observation, ...), no scalar_
%       prefix, no scalar/dataseries split; the single term_observation for
%       every ontology-term value.
%     - Manipulations are data-type-named: dose_manipulation /
%       formulation_manipulation (dose/formulation/chemical composite values),
%       the <quantity>_manipulation tier, and term_manipulation for
%       payload-free acts. NO injection/bath/pharmacological family, NO escape
%       hatch.
%     - Relationships are `directed_relation` / `undirected_relation` documents.
%     - Locus is Path S: an attributed anatomical part is its own `subject` +
%       a part_of directed_relation (minted, deduplicated per animal, by the
%       NDI second pass ndi.migrate -- it needs the corpus-wide subject graph).
%
%   See the conversion specs under
%   did-schema/schemas/V_eta/conversions/from_did_v1/ and the authoritative
%   field-level mapping in did-schema/schemas/V_eta_migration_plan.md Part D.
%
%   Registered migrators:
%
%     subject_group      - 1 -> 1. -> bare `subject` (v3.0.0; no is_group).
%     treatment_transfer - 1 -> 3. -> term_manipulation (the act) + a
%                          provenance directed_relation (recipient <- donor,
%                          derived_from) + the shared session anchor (D4).
%     ontology_table_row - 1 -> N. Each column -> a subject_assertion leaf
%                          (timeless: term_/date_assertion) OR a
%                          subject_observation leaf (timed: <dim>_observation by
%                          value shape / term_observation for strings);
%                          identity columns skipped; a.u. numerics ->
%                          intensity_observation (J §7, no escape hatch, D8).
%                          + one shared session anchor. Dispatch seeded from the
%                          Dab (FPS/EPM) and JH (C. elegans) corpora.
%
%   PENDING (need MATLAB + discovery-mode iteration against the corpora, exactly
%   as the +migrators_i versions were seeded; these depend on the still-open
%   instrument-as-subject (D2) / Path-S handling):
%
%     treatment          - dispatch by structure: dose_manipulation (substance
%                          -> dose/formulation composite), temperature_manipulation
%                          (typed value), term_manipulation (payload-free
%                          procedure/regime). Route -> method; attributed site
%                          -> a Path S part-subject + part_of (NDI pass);
%                          merely-located site -> a term_observation value.
%                          + shared anchor. (Dab = 100% the Target-Location
%                          locus pattern; JH = food-restriction regime + time.)
%     probe_location     - -> term_observation about the probe (D5); needs the
%                          instrument-as-subject decision (D2).
%     ontology_label     - -> term_observation / term_assertion (D5).
%     treatment_drug     - -> dose_manipulation (drug on the chemical term;
%                          mixture -> formulation composite; route -> method).
%     virus_injection    - -> dose_manipulation / formulation_manipulation
%                          (virus on the chemical term; titer -> concentration).
%
%   Classes with no did_v1 -> V_eta split fall through to the default
%   +migrators/<class> (1 -> 1) migrator, gaining only the schema_version tag.
