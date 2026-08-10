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
%     ontology_label     - 1 -> 1. DEFERRED passthrough. The label value was
%                          never the problem; the REFERENT was. The class has
%                          one property field (ontology_node) and one
%                          dependency, document_id -> the document being
%                          labelled. Reaching a subject means following that
%                          edge through the migrated-id graph, so the second
%                          pass does it. ~7,007 docs.
%
%   DEFERRED PASSTHROUGHS (1 -> 1). These migrators were reading field names no
%   did_v1 document has, so they emitted fabricated or fragmentary output. Each
%   now guards the invented shape by name and carries the document through
%   intact for the NDI second pass, which can read file bytes and see the
%   migrated-id graph. V_eta's tombstones declare the real did_v1 shape so the
%   passthrough validates. See V_eta_migrator_vocabulary_audit.md.
%     simple_calc              - no subject-bearing edge (only document_id).
%     spike_clusters           - the spike count is inside spike_cluster.bin.
%     spikewaves               - both counts are in the .vsw binary header.
%     spike_interface_sorting_outputs
%                              - declares NO dependencies at all, so there is no
%                                subject; the unit count is inside the .zip.
%     site2channelmap          - `map` only has meaning joined to the
%                                probe_geometry it references.
%     binnedspikeratevm        - no writer exists in any repository, so the
%                                payload encoding is undocumented and nothing
%                                says whether the values are rates or
%                                spikes-per-bin (33x apart at binsize 0.030).
%     vmneuralresponseresiduals
%                              - same missing writer; goodness_of_fit has no
%                                documented range or polarity.
%     vmspikesummary           - the real class is a mean spike WAVEFORM plus
%                                eight spike-shape medians, all arrays, not the
%                                four firing-summary scalars it was modelled on.
%                                Same missing writer, so array semantics and
%                                units are unsettleable.
%
%   THE SPIKE PROCESSING PARAMETERS FAMILY -> ONE method_parameters class.
%   Four did_v1 settings classes fold to the ONE generic `method_parameters`
%   document (TEAM-SIGN-OFF 2026-08-09, V_eta_method_parameters_plan.md). Each
%   is 1 -> 1 with base.id AND base.name PRESERVED -- the id because three
%   templates point at it (spikewaves.extraction_parameters_id,
%   spike_clusters.sorting_parameters_id/.extraction_parameters_id,
%   spike_extraction_parameters_modification.extraction_parameters_id), the name
%   because two apps look a protocol up by
%   ndi.query('base.name','exact_string',...) at spikeextractor.m:372 and
%   spikesorter.m:373. The v1 `app` block becomes a `software` entity + a
%   software_id edge (R1), so each fold emits 2 bodies. Settings become
%   `parameter[]` entries whose identity is a bound `variable` (no unit field,
%   no data_type field); the tail stays whole in `other`.
%     spike_extraction_parameters
%                        - the global protocol; no v1 dependencies, so no scope
%                          edges. 15 fields -> 4 bound entries (refractory
%                          period, waveform window start + duration, threshold)
%                          + the bag.
%     spike_extraction_parameters_modification
%                        - the same 15 fields (v1 stores a FULL copy, never a
%                          diff) + element_id -> subject_id and
%                          extraction_parameters_id -> derived_from_id (LINEAGE
%                          only -- precedence comes from the scope). Its epoch
%                          scope is the WRITER's, not the template's
%                          (spikeextractor.m:310 sets epochid.epochid on a class
%                          declaring only base + app) and is parked in
%                          other.epochid until the epoch pass can mint an
%                          `epoch` document to point at (#60).
%     sorting_parameters - no bound variables by decision (all six fields are in
%                          the plan's bag list by name), so the document carries
%                          an empty parameter list and a full `other`.
%     vmspikefilteringparameters
%                        - folds ONLY when `spiketimes` is empty. `spiketimes`
%                          is OUTPUT data sitting in a config class and has no
%                          decided home (and no writer exists to document its
%                          encoding), so a document that carries any is passed
%                          through UNCHANGED for the second pass rather than
%                          having a result folded into a settings bag or
%                          dropped. This REPLACES the former note that the class
%                          was "not migrated at all, deliberately".
%     filenavigator      - 1 -> 2 (or 1 -> 1). -> `epoch_file_pattern` (base.id
%                          PRESERVED -- daqsystem.filenavigator_id and
%                          epochfiles_ingested.filenavigator_id are both REQUIRED
%                          edges on NDI origin/main) + a `software` entity for the
%                          implementation class name. The two eval'd cell2str
%                          parameter strings are PARSED (never eval'd) into
%                          data_file_pattern / epoch_map_pattern lists;
%                          epochprobemap_class -> epoch_map_format, a plain char by
%                          decision (it is a content type, not software).
%                          Guarded passthrough when the block declares nothing.
%                          TEAM-SIGN-OFF [file navigation], jess 2026-08-06.
%                          EMBARGO LIFTED 2026-08-10: the two lists are declared
%                          "type": "string" in DID-schema now, so a multi-pattern
%                          navigator validates clean. (It read "BLOCKED FOR CORPUS
%                          USE" while the fields were "type": "char", which the
%                          validator's char branch rejects for a cellstr.)
%     daqreader          - 1 -> 1. DISSOLVES into a `software` entity, base.id
%                          PRESERVED (daqreader_id is a declared dependency on
%                          FOUR NDI templates: daqsystem + the three ingest
%                          classes). Its whole content is one MATLAB class name
%                          (+ndi/+daq/reader.m:264-267), which becomes the
%                          entity's name / local_identifier -- so the fold is a
%                          dissolution, not a rename. Guarded passthrough when
%                          there is no class name, or when a de-encoded
%                          `reader_string` is present (`software` has no slot for
%                          it and the signed decision KEEPS it).
%                          TEAM-SIGN-OFF [daq configuration], jess 2026-08-08.
%     daqmetadatareader  - 1 -> 2 (or 1 -> 1). -> `acquisition_metadata_reader`
%                          (base.id PRESERVED -- acquisition_metadata_file's
%                          REQUIRED acquisition_metadata_reader_id is filled from
%                          the source id) + a `software` entity for the
%                          implementation class name.
%                          tab_separated_file_parameter -> metadata_file_pattern
%                          (genuine: read back at +ndi/+daq/metadatareader.m:36).
%                          Emits NO `daqsystem_id` -- that edge was invented,
%                          REQUIRED and empty on 59 of 59 documents; NDI declares
%                          it the other way round. Guarded passthrough when the
%                          block declares neither field.
%                          TEAM-SIGN-OFF [daq configuration], jess 2026-08-08.
%     daqsystem          - 1 -> 1 -> `acquisition_system` (<- entity; base.id AND
%                          base.name PRESERVED -- the name is the probe->device
%                          join key, strcmpi'd at +ndi/+daq/system.m:229).
%                          filenavigator_id -> epoch_file_pattern_id,
%                          daqreader_id -> reader_id, and the NUMBERED family
%                          daqmetadatareader_id_# -> acquisition_metadata_reader_#
%                          (re-indexed from 1, skipping the template's empty bare
%                          entry). TEAM-SIGN-OFF [daq configuration], jess
%                          2026-08-08.
%                          PASSTHROUGH ON EVERY REAL DOCUMENT TODAY, BY DESIGN:
%                          `acquisition_system` declares no fields, so the
%                          source's `ndi_daqsystem_class` has no home -- and it is
%                          the object-reconstruction key, read through a
%                          CONSTRUCTED field name at
%                          +ndi/+database/+fun/ndi_document2ndi_object.m:38-42
%                          (reached from +ndi/session.m:167-169). Naming a second
%                          `software` edge on acquisition_system is a team call,
%                          so the fold stays guarded until it is taken.
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
%     dataset_remote     - 1 -> N. The remote copy as an entity relation:
%                          a bare `dataset` entity (keyed on the dataset id =
%                          base.session_id) + a `web_resource` (cloud id ->
%                          global_identifier scheme 'NDICloud') + dataset
%                          -stored_at-> web_resource + (if a remote org namespace)
%                          organization + web_resource -hosted_by-> organization.
%                          All endpoints minted here -> no orphan risk.
%     session_in_a_dataset / dataset_session_info
%                        - 1 -> N. session<->dataset membership as a relation now
%                          that `session` is an entity: a bare `dataset` entity +
%                          one `session -part_of-> dataset` per member session
%                          (dataset_session_info is the legacy aggregate: a nested
%                          struct array, one entry per session; session_in_a_dataset
%                          is the flat single-session form). The membership edge is
%                          BEST-EFFORT (tagged base.name = migrated_session_membership):
%                          a linked member session may not be in the batch, so
%                          resolveDatasetEntities drops the edge if the child does
%                          not resolve. The assembly/reconstruction fields
%                          (is_linked, session_creator, inputs, session_reference)
%                          are dropped as NDI-internal handles.
%     subjectmeasurement - 1 -> 2 (fold) / 1 -> 1 (guarded passthrough).
%                          TEAM-SIGN-OFF [subject measurement], jess 2026-08-06.
%                          Routes through the EXISTING `measurement` fold (shared
%                          private/jMeasurementFold + jQuantityLeaf) with NO new
%                          class: subject_id carries over, `measurement` becomes
%                          subject_statement.variable, `value` becomes the typed
%                          value, and `datestamp` becomes the TIME ANCHOR --
%                          time_reference_1 -> an `absolute_reference` document
%                          (private/jAbsoluteReference), NOT a field. `measurement`
%                          has no datestamp field at all, so a plain field mapping
%                          would have dropped the measurement time. Signed WITH a
%                          known gap: `value` carries no unit, so the leaf should
%                          come from the D9 registry -- which ships no dimensional
%                          rows yet, so jQuantityLeaf is the pass-1 stand-in and
%                          anything it cannot type PASSES THROUGH.
%                          THE FIRST EMITTER OF `absolute_reference`.
%     pyraview           - (extended) the inherited `filter` superclass block now
%                          splits off ONE `frequency_filter` document
%                          (private/jFrequencyFilter), referenced by every level
%                          body's optional `sampled_body.filter_id`. It used to be
%                          discarded outright. TEAM-SIGN-OFF [frequency_filter],
%                          jess 2026-07-30. Band edges, typed `gain` fields, NO
%                          sample_rate (the document is a SPECIFICATION, which is
%                          what makes it shareable). An all-pass ('none') emits
%                          nothing. NOTE the source field arrives as `filter_type`,
%                          not `type`: +migrators/filter.m renames it in the
%                          superclass pass that runs first.
%
%   POST-PASS (batch-level, did2.convert.resolveDatasetEntities): dedups the
%   `dataset` entities that the containers each mint on the shared dataset id
%   (richest wins -> the metadata_editor dataset beats the bare stubs, so every
%   dataset ends with exactly one), and prunes the best-effort membership edges
%   whose member session is absent. Run after resolveDeferredBaths (see
%   runCorpusDiscovery); the precise, always-resolvable wiring is ndi.migrate's
%   dataset-aware second pass.
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
%   SOFTWARE (TEAM-SIGN-OFF [software], jess 2026-08-06): the did_v1 `app` mixin
%   is replaced by a `software` ENTITY referenced by a `software_id` edge, with the
%   per-run os/interpreter in `execution_environment` on the interaction. The fold
%   lives in private/jSoftwareFromApp.m (+ private/jSoftware.m, which also serves
%   filenavigator's implementation-class entity) and is applied by jCalculation to
%   every calculator output, so the app block -- and the program's class name --
%   stops being copied onto the migrated document.
%
%   CONSOLIDATED 2026-08-10 (#25). There were THREE builders and only ONE wrote
%   the dedup key: private/jSyncSoftware.m (syncrule/syncgraph) and a local
%   softwareEntity() inside private/jMethodParameters.m both built their own
%   struct and both omitted `software.local_identifier`. Both now delegate --
%   jSoftwareFromApp is the one READER of an `app` block, jSoftware the one
%   BUILDER of a `software` body -- so every `software` document in the corpus
%   carries the handle. Two options were added to the shared helpers to make
%   that possible without changing any existing caller's output:
%   'RequireSession' (refuse to mint when base.session_id is empty, which is
%   mustBeNonEmpty on `base`) and jSoftwareFromApp's 4th output `appLeftover`
%   (hand the block back whole for a class with nowhere typed to put it). Both
%   default to the pre-existing behaviour.
%
%   DEDUP BY (name, version) IS THE NDI SECOND PASS, and it now exists:
%   ndi.migrate.internal.softwareDedup -- a whole-corpus merge with edge
%   retargeting, the shape of ndi.migrate.internal.pathSPromotion. Pass 1 still
%   mints one entity per consuming document (a single-document migrator cannot
%   see the batch) and records the key in software.local_identifier (name, or
%   name@version). The pass keys on (base.session_id, software.name,
%   software.version) rather than on that handle, so it does not depend on every
%   minter having written one -- and it REPAIRS the handle on each survivor.
%
%   Shared spine/composite helpers live in private/ (jStartInteraction,
%   jSessionAnchor, jCarrySubject, jDoseValue, jConcentration, jOntologyTerm,
%   jGetChar) so each migrator stays short; the older self-contained migrators
%   (subject_group, treatment_transfer, ontology_table_row) keep their own local
%   copies (local functions shadow the private ones, so there is no conflict).
%
%   SUPERCLASS OVERRIDES live in +super/ -- a SEPARATE subpackage, and the
%   separation is load-bearing. The dispatcher's superclass pass
%   (v1_to_v2.applySuperclassMigrators) was never bypassed by the migrators_j
%   split, so the V_delta superclass migrators kept running under V_eta; a
%   V_eta class needing different superclass-block handling puts a file in
%   +super/ and the dispatcher prefers it. It may NOT live in +migrators_j
%   itself: half the names here (element, subject, image, measurement,
%   filenavigator, pyraview, ...) are also superclass names somewhere in the
%   v1 zoo, and a concrete migrator returns a CELL of bodies where the
%   superclass pass is contracted to return one struct. A superclass override
%   must return exactly one body.
%     +super/ngrid.m   carries the did_v1 ngrid block VERBATIM (data_size,
%                      data_type, data_dim, coordinates). The V_delta one
%                      rmfield'd `coordinates` and `data_size` on every
%                      ontologyImage and hartley_calc document before the
%                      concrete J migrator ever saw them. #46/#47.
