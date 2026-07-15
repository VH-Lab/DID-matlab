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
%                          + one shared session anchor. NOTE: this is the naive
%                          per-column seed; the flat-table column-role model
%                          (D10) and per-column subject resolution (D11) are
%                          still OPEN, so a qualifier column (e.g. trial type) is
%                          knowingly mis-modelled as an observation until those
%                          resolve. See V_eta_migration_plan.md D10/D11.
%     treatment          - 1 -> 2/3. Dispatch by structure into strict-J leaves:
%                          temperature_manipulation (typed value),
%                          dose_manipulation (substance -> dose/formulation
%                          composite; the substance is the spine variable), or
%                          term_manipulation (payload-free procedure/regime; no
%                          escape hatch, D8). A merely-located site becomes a
%                          term_observation value (located-by-default, D3); an
%                          attributed site is promoted to a Path-S part-subject +
%                          part_of by the NDI second pass. + shared anchor.
%                          Not-a-manipulation / unresolved rows -> quarantine.
%     treatment_drug     - 1 -> 2/3. -> dose_manipulation (mixture_table ->
%                          dose.value.formulation.chemicals; primary drug is the
%                          spine variable) + optional site term_observation.
%     virus_injection    - 1 -> 2/3. -> dose_manipulation (virus is the spine
%                          variable + first chemical; dilution -> concentration;
%                          diluent -> a second chemical) + optional site obs.
%     probe_location     - 1 -> 2. -> term_observation about the probe-subject
%                          (device-as-subject, D2/D5): variable = a spatial
%                          relation, value = the atlas term. + anchor.
%     ontology_label     - 1 -> 2. -> term_observation about the labeled subject
%                          (D5): label term (either did_v1 idiom) as value. +
%                          anchor.
%     image_stack        - 1 -> 3. -> a body-backed image_observation
%                          (storage_mode: body; modality on the spine variable,
%                          geometry/format inline on the `image` mixin) + a
%                          sampled_body holding the carried pixel frames
%                          (datum + sample_time; `statement` -> the observation)
%                          + shared anchor (§C.4). The element_epoch/ingested
%                          quartet the V_zeta fold minted collapses into the one
%                          sampled_body; NDI-side imaging element/daqreader infra
%                          is left to the NDI second pass (D2). 7,007 docs in JH.
%     metadata_editor    - 1 -> N. Decompose the NDIMetaDataEditorApp
%                          `metadata_structure` blob into first-class entities +
%                          relations (the dataset-metadata analogue of retiring the
%                          openMINDS bundle on the subject side):
%                            Bucket 1 (identity) -> a `dataset` entity (id
%                            preserved; full_name/short_name/version/description/
%                            license/release_date) + `person` (one per Author;
%                            given/family/email, ORCID -> global_identifier),
%                            `organization` (author affiliations + funders,
%                            name-deduped), `award` (Funding; awardNumber ->
%                            global_identifier), `publication` (RelatedPublication;
%                            DOI/PMID/PMCID -> global_identifier), `web_resource`
%                            (FullDocumentation IRI -> global_identifier scheme
%                            URL). Relationships are `directed_relation`s:
%                            dataset -has_author-> person (sequence = position),
%                            person -affiliated_with-> organization,
%                            dataset -funded_by-> award -issued_by-> organization,
%                            dataset -cites-> publication,
%                            dataset -documented_by-> web_resource.
%                            Bucket 2 (Subjects/species/strain/sex, DataType,
%                            ExperimentalApproach, TechniquesEmployed) -> DROPPED:
%                            projections off the subjects' own term_assertions
%                            (D-D). Bucket 3 (editor GUI state / version prose) ->
%                            DROPPED. metadata_editor is KEPT as the source class.
%
%   PENDING (need discovery-mode iteration against the corpora and/or the still
%   -open flat-table decisions):
%
%     ontology_table_row - rewrite to the D10 column-role rule + chosen qualifier
%                          shape and D11 per-column subject resolution once those
%                          decisions land (the current split is the interim seed).
%     ontology_image     - -> term_observation about the imaged subject + an
%                          opaque_body/sampled_body for the image file (D5).
%
%   Classes with no did_v1 -> V_eta split fall through to the default
%   +migrators/<class> (1 -> 1) migrator, gaining only the schema_version tag.
%
%   Shared spine/composite helpers live in private/ (jStartInteraction,
%   jSessionAnchor, jCarrySubject, jDoseValue, jConcentration, jOntologyTerm,
%   jGetChar) so each migrator stays short; the older self-contained migrators
%   (subject_group, treatment_transfer, ontology_table_row) keep their own local
%   copies (local functions shadow the private ones, so there is no conflict).
