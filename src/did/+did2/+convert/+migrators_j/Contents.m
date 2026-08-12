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
%   WHERE THE COMPLETE LIST IS, AND WHY IT IS NOT THIS ONE. Everything from here
%   to the roster at the bottom is HAND-WRITTEN NARRATIVE -- rationale, team
%   sign-offs, corrections and their evidence -- and it has never been complete.
%   On 2026-08-12 it named 43 of the 81 migrators in this package; the other 38
%   had a file here and no entry anywhere in this comment. That mattered because
%   this file is read as FACT about the opposite: DID-schema/CLAUDE.md cites the
%   `projectvar` clause below to establish which classes deliberately have NO
%   migrator, so silence here read as a deliberate absence for 38 that were not.
%   The COMPLETE index is now the GENERATED ROSTER at the bottom of this file,
%   one entry per file, each taken from that migrator's own H1 summary.
%   `tools/check_migrator_roster.py` fails when a migrator is missing from it,
%   when the block differs from the generator, or when a migrator has no test.
%   READ THE ROSTER FOR "does X have a migrator"; read the narrative for WHY.
%
%   Registered migrators (a NARRATIVE SUBSET -- see above):
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
%     daqsystem          - 1 -> 2 -> `acquisition_system` (<- entity; base.id AND
%                          base.name PRESERVED -- the name is the probe->device
%                          join key, strcmpi'd at +ndi/+daq/system.m:229)
%                          + a `software` entity for its own implementation class.
%                          filenavigator_id -> epoch_file_pattern_id,
%                          daqreader_id -> reader_id, and the NUMBERED family
%                          daqmetadatareader_id_# -> acquisition_metadata_reader_#
%                          (re-indexed from 1, skipping the template's empty bare
%                          entry). TEAM-SIGN-OFF [daq configuration], jess
%                          2026-08-08.
%                          THE GUARD IS GONE (2026-08-12) AND THE FOLD IS LIVE.
%                          This entry read "PASSTHROUGH ON EVERY REAL DOCUMENT
%                          TODAY, BY DESIGN": `acquisition_system` declared no
%                          fields, so the source's `ndi_daqsystem_class` had no
%                          home -- and it is the object-reconstruction key, read
%                          through a CONSTRUCTED field name at
%                          +ndi/+database/+fun/ndi_document2ndi_object.m:38-42
%                          (reached from +ndi/session.m:167-169). jess named the
%                          home on 2026-08-12 (option A): acquisition_system
%                          gained a second software edge, `software_id`, and the
%                          class name now folds to a `software` entity exactly as
%                          filenavigator's and daqmetadatareader's do. Only a body
%                          with NO class name AND NO edges still passes through.
%                          1 -> 1 when there is no class name to fold.
%     image_stack        - 1 -> 3. -> a body-backed image_observation
%                          (storage_mode: body; modality on the spine variable,
%                          geometry/format inline on the `image` mixin) + a
%                          sampled_body holding the carried pixel frames
%                          (datum + sample_time; `statement` -> the observation)
%                          + shared anchor (§C.4). The element_epoch/ingested
%                          quartet the V_zeta fold minted collapses into the one
%                          sampled_body; NDI-side imaging element/daqreader infra
%                          is left to the NDI second pass (D2). 7,007 docs in JH.
%                          The source `document_id` is CARRIED as the
%                          observation's `ontology_table_row_id` (did-schema
%                          6cf31f2 minted the slot), CONDITIONALLY: haley
%                          behaviour has the edge, babu (import.m:474) does not,
%                          and an absent or blank one is OMITTED, never emitted
%                          empty. The subject-less haley E. coli sites keep it
%                          on the guarded passthrough instead.
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
%     binaryseries_parameters
%                        - 1 -> 1 GUARDED PASSTHROUGH, placeholder-normalising.
%                          TEAM-SIGN-OFF [misc singletons], jess 2026-08-09
%                          retires this class INTO THE data_body MODEL (time_type
%                          -> the time axis's datum_type, data_type -> the
%                          statement's, data_dim -> the axis count,
%                          samples_regular_intervals -> the axis `regular` flag).
%                          NONE of those slots exists: that is #45, blocked on
%                          #32, so the fold is NOT built and the document passes
%                          through. What this migrator does build is the thing
%                          the passthrough needed to be survivable at all: NDI's
%                          template supplies the CHAR '' for three fields its own
%                          schema types `integer`, and NO empty value validates
%                          (`''` is a typeMismatch, `[]` fails mustBeScalar), so
%                          the placeholder is DROPPED -- absence is how V_eta
%                          spells unset, and an absent optional field is the one
%                          spelling the validator passes. A NON-empty char is NOT
%                          parsed; it errors, because this class has NO WRITER
%                          anywhere in NDI (3 files mention it on origin/main,
%                          not one of them a .m) so nothing can say what encoding
%                          was meant. GUARD: `num_channels` / `sample_rate` are
%                          rejected by name -- they are what the pre-Phase-2b
%                          tombstone required and no NDI file has ever declared
%                          them.
%                          NOT A SPECIAL CASE: a sweep of all 91 NDI templates
%                          against the V_eta classes they map to found 33 fields
%                          whose template literal cannot validate against the
%                          declared type, over 20 classes; three of those classes
%                          have no migrator to overwrite the placeholder and so
%                          are exposed on the passthrough path -- this one,
%                          stimulus_parameter (`value`) and imageStack_parameters
%                          (`timestamp`). BOTH OF THOSE ARE NOW BUILT: see
%                          stimulus_parameter below and +super/
%                          image_stack_parameters at the bottom of this file.
%     stimulus_parameter - 1 -> 1 PASSTHROUGH, placeholder-normalising. The class
%                          itself is HELD for the stimulus model (#31) and this
%                          migrator folds nothing. NDI's template supplies the
%                          CHAR '' for `value`, which NDI's own schema types
%                          `double`; validateTypeShape runs unconditionally on a
%                          present field (cache.m:1229) and the numeric case
%                          demands isnumeric (:1383), so the placeholder
%                          quarantines while ABSENCE validates (:1212-1225). It
%                          is DROPPED, not coerced. A NON-empty char errors
%                          rather than being parsed: the writer assigns out of a
%                          table cell (temptable2stimulusparameters.m:44,56,63),
%                          so a char there means the source is not what we think
%                          it is. All three writer sites DO set `value`, so this
%                          is latent for the marder datasets -- repaired anyway,
%                          because ndi.document() fills any unset field from the
%                          template and the corpora are a SAMPLE. Gate:
%                          tests/+did2/+unittest/testTemplateLiteralTypeTraps.m.
%
%   DELIBERATELY WITHOUT A MIGRATOR: `projectvar`. TEAM-SIGN-OFF [misc
%   singletons] keeps it a DEPRECATED-tier passthrough until real documents exist
%   to model its untyped `data` field against, so it takes the identity fallback
%   on purpose. Its tombstone only reaches the validator because all six
%   workflows copy schemas/V_eta/deprecated/ into DID_SCHEMA_PATH. KNOWN, OPEN:
%   `data` is an arbitrary caller-supplied payload typed `string`, so a non-empty
%   NUMERIC one quarantines -- see testMiscSingletons.
%
%   ALSO DELIBERATELY WITHOUT A MIGRATOR: `generic_file` and `valid_interval`,
%   the last two did_v1 classes that STRANDED COMPLETELY -- they had no V_eta
%   schema AND no migrator, so a document of either was not migrated, not passed
%   through and not quarantined-and-kept. It was lost. Both are REAL PRODUCTION
%   classes: generic_file is written at two sites in +setup/+conv/+babu/import.m
%   (:526-531 plasmid, :575-580 LC-MS) and read by
%   +cloud/+download/downloadGenericFiles.m; valid_interval is written by
%   ndi.app.markgarbage (:93-96) and read BOTH by markgarbage itself (:130,:141)
%   and by the tuning pipeline (+app/+stimulus/tuning_response.m:253-256, which
%   uses it to choose which stretch of signal to analyse).
%   THE FIX IS A TOMBSTONE, NOT A MIGRATOR -- the `projectvar` shape, described
%   under "DELIBERATELY WITHOUT A MIGRATOR" just above. Both are restated from
%   the WRITER in DID-schema
%   tools/build_v_eta.py and marked `retire`, so the identity fallback carries
%   the document and the tombstone lets it validate.
%
%   CITATION CORRECTED 2026-08-12. This named "the vmspikefilteringparameters
%   shape", and that class has NOT been tombstone-only since 2026-08-10: it has
%   a migrator, and THIS FILE describes it at the `vmspikefilteringparameters`
%   entry ~230 lines above. The two halves of one file disagreed. The analogy
%   was already false when it was written, which is why it is corrected rather
%   than aged out -- positive evidence, not absence:
%
%     git log -1 --date=iso --format="%h %ad %s" \
%         -- +did2/+convert/+migrators_j/vmspikefilteringparameters.m
%        9dc8eea 2026-08-10 20:49:59  (the migrator lands)
%     git blame -L 364,364 +did2/+convert/+migrators_j/Contents.m
%        354481f4 2026-08-10 22:31:45  (this sentence is written)
%     git merge-base --is-ancestor 9dc8eea 354481f4   -> true
%
%   i.e. the migrator was already an ancestor, by 1h42m, of the commit that
%   cited the class as having none. Only the exemplar changed here; the claim
%   about generic_file and valid_interval is unaffected and stands.
%
%   `valid_interval` HAS NO PASS-1 MIGRATOR AND, AS OF 2026-08-12, NO ACTIVE
%   GO-FORWARD EMISSION EITHER -- it lives on its v1 tombstone until `axes[]`
%   lands. TEAM DECISION 2026-08-12: the model is ONE boolean-valued
%   `subject_statement` per source document carrying an ARRAY of booleans on a
%   TIME AXIS, and the team chose to WAIT for `axes[]` (DID-schema OPEN_WORK
%   #45 -> #32) rather than ship the 1->N one-statement-per-interval shape as
%   an interim. `did2.convert.resolveValidIntervals` is therefore DORMANT: it
%   runs as a census, counts `sources_seen`/`intervals_seen`, and appends
%   nothing. When it is re-armed the class it emits is `logical_observation`
%   (renamed from `validity_observation` on 2026-08-12: the 32 `*_observation`
%   data_types name a KIND OF VALUE, and the SEMANTIC belongs in
%   `subject_statement.variable`). That work is a BATCH pass, not a migrator,
%   because
%   `relative_reference.relative_to` is REQUIRED and names the `epoch` DOCUMENT
%   while the v1 anchor names an epoch by STRING -- the same wall
%   resolveSessionAnchors documents. The tombstone STAYS and the source document
%   is KEPT: the pass adds and never removes, and `sources_fully_decomposed`
%   measures the deletion gate rather than pre-empting it. This paragraph used
%   to end "its tier is a team call"; the team made it. What is still open is
%   the INHERITANCE sub-question -- loadvalidinterval falls back to
%   `underlying_element` (markgarbage.m:146-155), and whether V_eta re-derives
%   that at query time or materialises it is undecided; the pass forecloses
%   neither and reports `inheritance_candidates` so the decision has a size.
%
%   KNOWN, OPEN: valid_interval is the only one of NDI's 91 templates whose
%   property block is a JSON ARRAY and the writer APPENDS to it, so a
%   multi-interval document is under-specified by any scalar-block schema; the
%   meta-schema cannot express an array block. See
%   testStrandedSourceTombstones, which pins the invariant (never
%   clean-and-truncated) rather than guessing the outcome.
%
%   POST-PASS (batch-level, did2.convert.resolveDatasetEntities): dedups the
%   `dataset` entities that the containers each mint on the shared dataset id
%   (richest wins -> the metadata_editor dataset beats the bare stubs, so every
%   dataset ends with exactly one), and prunes the best-effort membership edges
%   whose member session is absent. Run after resolveDeferredBaths (see
%   runCorpusDiscovery). This clause used to end "the precise,
%   always-resolvable wiring is ndi.migrate's dataset-aware second pass" --
%   there is no such pass. ndi.migrate.local did not call this function at all
%   until 2026-08-10, so production kept the duplicates and the dangling edges
%   while every corpus run was green without them. It now runs THIS function as
%   V_eta second-pass step (4b) (wired 2026-08-10, NOT EXECUTED -- no MATLAB).
%   A precise, always-resolvable membership wiring using the live session graph
%   remains UNBUILT; the prune is still the honest best-effort in both paths.
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
%     +super/image_stack_parameters.m
%                      drops the template's `timestamp: []`. NDI's schema types
%                      it a scalar `double`, and [] is numeric (so it passes
%                      validateTypeShape) and then fails mustBeScalar
%                      (cache.m:1258) -- absence is the only spelling that gets
%                      through. A superclass migrator rather than a concrete one
%                      because imageStack_parameters IS a superclass: nothing
%                      constructs it standalone, both converters pass its BLOCK
%                      to ndi.document('imageStack', ...), and the superclass
%                      pass runs before image_stack.m so BOTH of that migrator's
%                      paths are covered at once. The exposed path is the
%                      subject-less GUARDED PASSTHROUGH, which is why the
%                      image_stack / image_stack_parameters tombstones must stay
%                      out of _DELETE_PHASE8. Non-scalar or char timestamps
%                      error rather than being truncated or parsed. Gate:
%                      tests/+did2/+unittest/testTemplateLiteralTypeTraps.m.
%
%   ===================== BEGIN GENERATED ROSTER =====================
%
%   One entry per file in this package, GENERATED from each migrator's own H1
%   summary paragraph by tools/check_migrator_roster.py. DO NOT HAND-EDIT: the
%   gate diffs this block against the generator and a hand edit fails it. To
%   change an entry, change that migrator's H1 and re-run with --write.
%
%   83 migrator(s).
%
%     binaryseries_parameters
%         Brainstorm-J migrator: did_v1 binaryseries_parameters -- a GUARDED
%         PASSTHROUGH that normalises the template's own placeholders.
%     binnedspikeratevm
%         Brainstorm-J migrator: did_v1 binnedspikeratevm -- DEFERRED to the NDI
%         second pass; the document is passed through UNCHANGED.
%     contrast_sensitivity_calc
%         Brainstorm-J migrator: the ndi.calc.vis.contrast_sensitivity calculator
%         OUTPUT document -> the subject_calculation LEAF
%         contrast_sensitivity_calculation (id-preserved) + a session anchor.
%         Un-defers the aggregate contrast-sensitivity calculation. This doc HAS
%         element_id (like every vision calculator, tuningcurve_calc included), so the
%         fold is single-doc: element_id -> subject_id; the result fields (sensitivity
%         / gain / c50 / p-value matrices) sit on the concrete
%         contrast_sensitivity_calc block, so it is passed as the sourceBlock (its
%         inherited input_parameters stripped -> method_parameters); app kept; the raw
%         responses (stimulus_response_scalar_id) -> derived_from_1.
%     contrast_tuning
%         Brainstorm-J migrator: did_v1 contrast_tuning -> the subject_calculation
%         LEAF `tuning_curve_calculation` + the `tuning_curve` result composite, with
%         the id preserved, + a session anchor. R2/R3 TUNING COLLAPSE: the v1
%         `contrast_tuning` result block is RESHAPED into the one tuning_curve value
%         (a model_fit ARRAY + typed significance / interpolated_values sub-blocks) by
%         private/jTuningCurveValue -- it is NOT carried verbatim; the fold is 1 -> 1
%         with base.id + depends_on preserved (so downstream calc references resolve)
%         and the input document(s) consumed -> derived_from_#. See
%         did2.convert.migrators_j.private.jCalculation.
%     contrast_tuning_calc
%         Brainstorm-J migrator: the ndi.calc.vis.contrast calculator OUTPUT document
%         -> the subject_calculation LEAF `tuning_curve_calculation` + the
%         `tuning_curve` result composite, with the id preserved, + a session anchor.
%         R2/R3 TUNING COLLAPSE: the v1 `contrast_tuning` result block is RESHAPED
%         into the one tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     control_stimulus_ids
%         Brainstorm-J migrator: did_v1 control_stimulus_ids -> `control_designation`
%         (V_eta_stimulus_model_plan.md, TEAM-SIGN-OFF [stimulus] 2026-08-08). A
%         DERIVED annotation of WHICH presented trials are the control reference,
%         computed by the tuning_response app. It is NOT baked into the immutable
%         stimulus body: it REFERENCES the presentation (the timed_sequence
%         body-of-record, id-preserved through the second-pass decompose, so the edge
%         resolves either way) and carries the derivation method; marked derived_from
%         the presentation (T10). Drops the v1 `app` mixin (software model, R1) and
%         the `ids` container word (T13).
%     daqmetadatareader
%         Brainstorm-J migrator: did_v1 daqmetadatareader ->
%         `acquisition_metadata_reader` (+ the `software` entity for the
%         implementation class). 1 -> 2, or 1 -> 1, or a guarded passthrough.
%     daqmetadatareader_epochdata_ingested
%         Brainstorm-J migrator: the per-epoch companion-spreadsheet bytes ->
%         `acquisition_metadata_file`.
%     daqreader
%         Brainstorm-J migrator: did_v1 daqreader DISSOLVES into a `software` entity.
%         1 -> 1, base.id PRESERVED.
%     daqreader_epochdata_ingested
%         Brainstorm-J migrator: lift the epoch's clock extents out of `epochtable`
%         into `relative_reference` documents.
%     daqreader_image_epochdata_ingested
%         Brainstorm-J migrator: the camera's ingested epoch. Lifts the inherited
%         epoch clock extents; the image fold is BLOCKED and the document is
%         preserved.
%     daqreader_mfdaq_epochdata_ingested
%         Chunk-b/c de-encode: the mfdaq ingested cache dissolves into the generic
%         daqreader_epochdata_ingested.
%     daqreader_ndr
%         Chunk-c de-encode: daqreader_ndr dissolves into daqreader. The reader
%         subtype ('ndr') was encoded in the CLASS NAME, but it is already
%         discriminated by ndi_daqreader_class, so the distinguishing fields de-encode
%         onto the generic daqreader: ndr_reader_string -> daqreader.reader_string,
%         and ndi_daqreader_ndr_class dropped (redundant). `file_extension` is NOT
%         carried -- see the block at the copy site below for why, and do not restore
%         it from this line. The daqreader superclass chain is rebuilt by
%         ensureClassBlocks after this.
%     daqsystem
%         Brainstorm-J migrator: did_v1 daqsystem -> `acquisition_system` (<- entity)
%         + a `software` entity for its own implementation class. 1 -> 2, or 1 -> 1
%         when there is no class name. base.id AND base.name PRESERVED on the
%         acquisition_system.
%     dataset_remote
%         Brainstorm-J migrator: did_v1 dataset_remote -> the remote copy as a
%         first-class relation. A dataset_remote records that a local dataset is
%         mirrored to a cloud location (its cloud `dataset_id` + remote
%         `organization_id`). In J that is not a bespoke class but the entity-layer
%         pattern used for every external reference: the remote copy IS a
%         `web_resource`, and the association is a `directed_relation` (exactly as
%         dataset documentation became dataset -documented_by-> web_resource).
%     dataset_session_info
%         Brainstorm-J migrator: did_v1 dataset_session_info -> the session<->dataset
%         membership as first-class relations. This is the legacy AGGREGATE form of
%         session_in_a_dataset: the `dataset_session_info` block holds a
%         `dataset_session_info` structure (scalar or array), one entry per member
%         session, each with the same fields (session_id, is_linked, session_creator,
%         session_creator_input1..6, session_reference). It dissolves exactly like
%         session_in_a_dataset — a bare dataset entity + one session -part_of->
%         dataset edge per member session (best-effort; dropped by
%         resolveDatasetEntities when a linked member session is not in the batch).
%         The assembly/reconstruction fields are dropped as NDI-internal handles.
%     demo_ndi
%         Brainstorm-J migrator: did_v1 `demoNDI` -> the V_eta `demo` class, 1 -> 1
%         with base.id PRESERVED, `value` carried and `is_mock` FALSE. Part of the 3
%         -> 1 demo collapse signed by the team on 2026-08-06 (did-schema
%         `tools/build_v_eta.py:1817-1867`); the fold itself is in private/jDemoFold.
%     demo_ndi_mock
%         Brainstorm-J migrator: did_v1 `demoNDIMock` -> the V_eta `demo` class, 1 ->
%         1 with base.id PRESERVED, the INHERITED `demoNDI.value` carried and
%         `is_mock` TRUE. The other half of the 3 -> 1 demo collapse signed by the
%         team on 2026-08-06 (did-schema `tools/build_v_eta.py:1817-1867`); the fold
%         itself is in private/jDemoFold.
%     distance_metadata
%         Brainstorm-J migrator: reshape a did_v1 distance_metadata into the validated
%         V_eta distance_metadata. 1 -> 1.
%     electrode_offset_voltage
%         Brainstorm-J migrator: did_v1 electrode_offset_voltage -> a
%         voltage_observation of the probe-subject, qualified by the temperature it
%         was measured at, + the session anchor. 1 -> 2.
%     element
%         Brainstorm-J migrator: did_v1 element -> subject (+ kind assertions + the
%         raw-recording observation + a lineage relation). Strict J retires the
%         recording-side `element` class (J:214, D2): any identifiable thing -- an
%         organism, a device/probe, a derived signal or sorted unit -- is a `subject`.
%         The element document therefore becomes a `subject` with its id PRESERVED, so
%         the ~50 classes that reference it (`element_id` / `underlying_element_id` /
%         `stimulator_id`) keep resolving -- now to a subject.
%     element_epoch
%         Brainstorm-J migrator: element_epoch -> acquisition_epoch.
%     epochfiles_ingested
%         Brainstorm-J migrator: DELIBERATE GUARDED PASSTHROUGH.
%     filenavigator
%         Brainstorm-J migrator: did_v1 filenavigator -> epoch_file_pattern (+ the
%         `software` entity for the implementation class). 1 -> 1 or 1 -> 2.
%     fitcurve
%         Brainstorm-J migrator: did_v1 fitcurve -> a fit-residual score_observation
%         (+ the shared session anchor).
%     image
%         Brainstorm-J migrator: did_v1 `image` -> a body-backed image_observation + a
%         sampled_body (+ the shared session anchor). 1 -> 3.
%     image_stack
%         Brainstorm-J migrator: did_v1 image_stack -> a body-backed image_observation
%         + a sampled_body (+ the shared session anchor).
%     jrclust_clusters
%         Brainstorm-J migrator: did_v1 jrclust_clusters -> a body-backed
%         count_observation (the per-spike cluster assignments) + the session anchor.
%     kiasort_clusters
%         Brainstorm-J migrator: did_v1 kiasort_clusters -> the D-C analysis-tier
%         shape (count_observation + opaque_body + session anchor).
%     kilosort_clusters
%         Brainstorm-J migrator: did_v1 kilosort_clusters -> the D-C analysis-tier
%         shape (count_observation + opaque_body + session anchor).
%     measurement
%         Brainstorm-J migrator: did_v1 measurement -> a typed subject_observation
%         leaf (+ the shared session anchor), for the rows that can be typed honestly;
%         everything else is carried through for the second pass.
%     metadata_editor
%         Brainstorm-J migrator: did_v1 metadata_editor -> a structured `dataset`
%         entity + the person / organization / funding / publication / web_resource
%         entities it references + the `directed_relation`s that connect them. Strict
%         J stops storing dataset metadata as one opaque `metadata_structure` blob
%         (the NDIMetaDataEditorApp serialization) and instead decomposes it into
%         first-class, queryable entities, exactly as the subject side stopped storing
%         openMINDS bundles.
%     neuron_extracellular
%         Brainstorm-J migrator: did_v1 neuron_extracellular -> a DERIVED SUBJECT (the
%         sorted unit) + a derived_from relation + a quality observation (+ the shared
%         session anchor).
%     oneepoch
%         Brainstorm-J migrator: keep the class, fold its inherited block.
%     ontology_image
%         Brainstorm-J migrator: did_v1 ontology_image, dispatched ON SHAPE. The
%         current NDI shape (`ontology_nodes` + an `ontologyTableRow_id` edge + the
%         `ngrid` raster) is a GUARDED PASSTHROUGH deferred to the NDI second pass: a
%         table row is not a subject, so pass 1 cannot fill
%         `subject_statement.subject_id` without minting the husk the image_stack
%         guard exists to stop. The legacy `ontology_name` + `ontology_region` shape
%         (which the correction below shows has never existed in NDI) would migrate 1
%         -> 2 to a term_observation about the element-subject + a session anchor. Any
%         third shape ERRORS rather than emitting. The raster and the provenance edge
%         are deferred with the passthrough (#47).
%     ontology_label
%         Brainstorm-J migrator: did_v1 ontology_label -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%     ontology_table_row
%         Brainstorm-J split migrator: did_v1 ontology_table_row -> the
%         subject_statement tier (1 -> N).
%     openminds
%         Brainstorm-J migrator: did_v1 `openminds` -- a GUARDED PASSTHROUGH.
%     openminds_element
%         Brainstorm-J migrator: did_v1 openminds_element -> term_assertion.
%     openminds_stimulus
%         Brainstorm-J migrator: did_v1 openminds_stimulus -- DEFERRED to the NDI
%         second pass; the document is passed through UNCHANGED.
%     openminds_subject
%         Brainstorm-J migrator: did_v1 openminds_subject -> term_assertion.
%     oridirtuning_calc
%         Brainstorm-J migrator: the ndi.calc.vis.oridir calculator OUTPUT document ->
%         the subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve`
%         result composite, with the id preserved, + a session anchor. R2/R3 TUNING
%         COLLAPSE: the v1 `orientation_direction_tuning` result block is RESHAPED
%         into the one tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     orientation_direction_tuning
%         Brainstorm-J migrator: did_v1 orientation_direction_tuning -> the
%         subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve`
%         result composite, with the id preserved, + a session anchor. R2/R3 TUNING
%         COLLAPSE: the v1 `orientation_direction_tuning` result block is RESHAPED
%         into the one tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     position_metadata
%         Brainstorm-J migrator: did_v1 position_metadata -> term_observation (WHAT
%         kind of position was recorded) about the element-subject + a session anchor.
%         1 -> 2.
%     probe_geometry
%         Brainstorm-J migrator: did_v1 probe_geometry -> one length_observation PER
%         SPATIAL AXIS about the probe-subject, plus the session anchor, plus an
%         optional probe-model term_assertion.
%     probe_location
%         Brainstorm-J migrator: did_v1 probe_location -> term_observation.
%     pyraview
%         Brainstorm-J migrator: did_v1 pyraview -> a body-backed
%         dataseries_observation + a sampled_body (+ the shared session anchor).
%     session_in_a_dataset
%         Brainstorm-J migrator: did_v1 session_in_a_dataset -> the session<->dataset
%         membership as a first-class relation. Now that `session` is an `entity`, a
%         session belonging to a dataset is a `directed_relation` (session -part_of->
%         dataset), not a bookkeeping record.
%     simple_calc
%         Brainstorm-J migrator: did_v1 simple_calc -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%     site2channelmap
%         Brainstorm-J migrator: did_v1 site2channelmap -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%     sorting_parameters
%         Brainstorm-J migrator: did_v1 sorting_parameters -> ONE `method_parameters`
%         document (+ the `software` entity its v1 `app` block names).
%     spatial_frequency_tuning
%         Brainstorm-J migrator: did_v1 spatial_frequency_tuning -> the
%         subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve`
%         result composite, with the id preserved, + a session anchor. R2/R3 TUNING
%         COLLAPSE: the v1 `spatial_frequency_tuning` result block is RESHAPED into
%         the one tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     spatial_frequency_tuning_calc
%         Brainstorm-J migrator: the ndi.calc.vis.spatialfrequency calculator OUTPUT
%         document -> the subject_calculation LEAF `tuning_curve_calculation` + the
%         `tuning_curve` result composite, with the id preserved, + a session anchor.
%         R2/R3 TUNING COLLAPSE: the v1 `spatial_frequency_tuning` result block is
%         RESHAPED into the one tuning_curve value (a model_fit ARRAY + typed
%         significance / interpolated_values sub-blocks) by private/jTuningCurveValue
%         -- it is NOT carried verbatim; the fold is 1 -> 1 with base.id + depends_on
%         preserved (so downstream calc references resolve) and the input document(s)
%         consumed -> derived_from_#. See
%         did2.convert.migrators_j.private.jCalculation.
%     speed_tuning
%         Brainstorm-J migrator: did_v1 speed_tuning -> the subject_calculation LEAF
%         `tuning_curve_calculation` + the `tuning_curve` result composite, with the
%         id preserved, + a session anchor. R2/R3 TUNING COLLAPSE: the v1
%         `speed_tuning` result block is RESHAPED into the one tuning_curve value (a
%         model_fit ARRAY + typed significance / interpolated_values sub-blocks) by
%         private/jTuningCurveValue -- it is NOT carried verbatim; the fold is 1 -> 1
%         with base.id + depends_on preserved (so downstream calc references resolve)
%         and the input document(s) consumed -> derived_from_#. See
%         did2.convert.migrators_j.private.jCalculation.
%     speed_tuning_calc
%         Brainstorm-J migrator: the ndi.calc.vis.speed calculator OUTPUT document ->
%         the subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve`
%         result composite, with the id preserved, + a session anchor. R2/R3 TUNING
%         COLLAPSE: the v1 `speed_tuning` result block is RESHAPED into the one
%         tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     spike_clusters
%         Brainstorm-J migrator: did_v1 spike_clusters -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%     spike_extraction_parameters
%         Brainstorm-J migrator: did_v1 spike_extraction_parameters -> ONE
%         `method_parameters` document (+ the `software` entity its v1 `app` block
%         names).
%     spike_extraction_parameters_modification
%         Brainstorm-J migrator: did_v1 spike_extraction_parameters_modification -> a
%         SECOND `method_parameters` document (+ the `software` entity its v1 `app`
%         block names).
%     spike_interface_sorting_outputs
%         Brainstorm-J migrator: did_v1 spike_interface_sorting_outputs -- DEFERRED to
%         the NDI second pass; the document is passed through UNCHANGED.
%     spikewaves
%         Brainstorm-J migrator: did_v1 spikewaves -- DEFERRED to the NDI second pass;
%         the document is passed through UNCHANGED.
%     stimulus_bath
%         Deferred: stimulus_bath migrates to a dose_manipulation in the NDI layer /
%         the coarse resolveDeferredBaths pass.
%     stimulus_parameter
%         Brainstorm-J migrator: did_v1 stimulus_parameter -- a PASSTHROUGH that
%         normalises the template's own untypeable placeholder.
%     stimulus_presentation
%         Brainstorm-J migrator: did_v1 stimulus_presentation -- the decomposition is
%         DEFERRED to the NDI second pass; pass 1 is a GUARDED PASSTHROUGH that
%         carries the document intact.
%     stimulus_response_scalar
%         Brainstorm-J migrator: did_v1 stimulus_response_scalar -> the
%         subject_calculation LEAF `harmonic_component_calculation` (id PRESERVED) +
%         the shared session anchor. Routed from did2.convert.v1_to_v2 only when
%         TargetVersion == 'V_eta'.
%     stimulus_response_scalar_parameters_basic
%         Brainstorm-J migrator: DEFERRED guarded passthrough. The signed model folds
%         this class INLINE into `subject_interaction.method_parameters` on the
%         response leaf; pass 1 cannot, and must not delete the documents in the
%         meantime. Routed from did2.convert.v1_to_v2 only when TargetVersion ==
%         'V_eta'.
%     stimulus_tuningcurve
%         Brainstorm-J migrator: a raw ndi.app.stimulus.tuning_response tuning curve
%         (the pre-calculator-framework stimulus_tuningcurve document) -> the
%         subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve`
%         result composite, with the id preserved, + a session anchor. R2/R3 TUNING
%         COLLAPSE: the v1 `stimulus_tuningcurve` result block is RESHAPED into the
%         one tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     subject
%         Brainstorm-J carry-forward for a v1 subject: guarantee a non-empty
%         local_identifier. V_eta makes subject.local_identifier REQUIRED (a subject
%         must be nameable); a v1 subject's handle was optional, so an empty or
%         missing one now needs filling. Fill it from the preserved document id.
%         Everything else is unchanged -- the body is already post-universalRenames
%         and ensureClassBlocks runs after this (exactly as the mechanical path did
%         before), so the only delta is the guaranteed handle.
%     subject_group
%         Brainstorm-J migrator: did_v1 subject_group -> bare subject (+ member_of
%         relations).
%     subjectmeasurement
%         Brainstorm-J migrator: did_v1 subjectmeasurement -> a typed
%         subject_observation leaf + an `absolute_reference` carrying the measurement
%         instant. Routed from did2.convert.v1_to_v2 only when TargetVersion ==
%         'V_eta'.
%     syncgraph
%         Brainstorm-J migrator: did_v1 `syncgraph` -> `clock_alignment_policy`.
%     syncrule
%         Brainstorm-J migrator: did_v1 `syncrule` -> `clock_alignment_configuration`.
%     syncrule_mapping
%         Brainstorm-J migrator: did_v1 `syncrule_mapping` -> `clock_alignment`.
%     temporal_frequency_tuning
%         Brainstorm-J migrator: did_v1 temporal_frequency_tuning -> the
%         subject_calculation LEAF `tuning_curve_calculation` + the `tuning_curve`
%         result composite, with the id preserved, + a session anchor. R2/R3 TUNING
%         COLLAPSE: the v1 `temporal_frequency_tuning` result block is RESHAPED into
%         the one tuning_curve value (a model_fit ARRAY + typed significance /
%         interpolated_values sub-blocks) by private/jTuningCurveValue -- it is NOT
%         carried verbatim; the fold is 1 -> 1 with base.id + depends_on preserved (so
%         downstream calc references resolve) and the input document(s) consumed ->
%         derived_from_#. See did2.convert.migrators_j.private.jCalculation.
%     temporal_frequency_tuning_calc
%         Brainstorm-J migrator: the ndi.calc.vis.temporalfrequency calculator OUTPUT
%         document -> the subject_calculation LEAF `tuning_curve_calculation` + the
%         `tuning_curve` result composite, with the id preserved, + a session anchor.
%         R2/R3 TUNING COLLAPSE: the v1 `temporal_frequency_tuning` result block is
%         RESHAPED into the one tuning_curve value (a model_fit ARRAY + typed
%         significance / interpolated_values sub-blocks) by private/jTuningCurveValue
%         -- it is NOT carried verbatim; the fold is 1 -> 1 with base.id + depends_on
%         preserved (so downstream calc references resolve) and the input document(s)
%         consumed -> derived_from_#. See
%         did2.convert.migrators_j.private.jCalculation.
%     treatment
%         Brainstorm-J split migrator: did_v1 treatment -> a data-type-named
%         subject_manipulation leaf (+ an optional site term_observation + the shared
%         session anchor).
%     treatment_drug
%         Brainstorm-J migrator: did_v1 treatment_drug -> dose_manipulation.
%     treatment_transfer
%         Brainstorm-J migrator: did_v1 treatment_transfer -> term_manipulation + a
%         provenance directed_relation.
%     tuningcurve_calc
%         Brainstorm-J migrator: the ndi.calc.stimulus.tuningcurve calculator OUTPUT
%         document -> the subject_calculation LEAF `tuning_curve_calculation` + the
%         `tuning_curve` result composite, with the id preserved, + a session anchor.
%         R2/R3 TUNING COLLAPSE: the v1 `stimulus_tuningcurve` result block is
%         RESHAPED into the one tuning_curve value (a model_fit ARRAY + typed
%         significance / interpolated_values sub-blocks) by private/jTuningCurveValue
%         -- it is NOT carried verbatim; the fold is 1 -> 1 with base.id + depends_on
%         preserved (so downstream calc references resolve) and the input document(s)
%         consumed -> derived_from_#. See
%         did2.convert.migrators_j.private.jCalculation.
%     virus_injection
%         Brainstorm-J migrator: did_v1 virus_injection -> dose_manipulation.
%     vmneuralresponseresiduals
%         Brainstorm-J migrator: did_v1 vmneuralresponseresiduals -- DEFERRED to the
%         NDI second pass; the document is passed through UNCHANGED.
%     vmspikefilteringparameters
%         Brainstorm-J migrator: did_v1 vmspikefilteringparameters -> ONE
%         `method_parameters` document (+ the `software` entity its v1 `app` block
%         names) -- GUARDED, because this class mixes OUTPUT DATA into a configuration
%         document.
%     vmspikefit
%         Brainstorm-J migrator: did_v1 vmspikefit -> a fit-residual score_observation
%         (+ the shared session anchor).
%     vmspikesummary
%         Brainstorm-J migrator: did_v1 vmspikesummary -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%
%   ====================== END GENERATED ROSTER ======================
