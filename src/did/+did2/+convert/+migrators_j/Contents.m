% +migrators_j  did_v1 -> V_eta (Brainstorm J) split/fold migrators.
%
%   Routed by did2.convert.v1_to_v2 ONLY when TargetVersion == 'V_eta'.
%   The dispatcher applies the universal renames first, then -- for a class
%   that has a file here -- runs this migrator instead of the default
%   +migrators/<class> one. A migrator may return a single body OR a cell /
%   struct array of several bodies (1 -> N fan-out).
%
%   V_eta (did-schema/schemas/V_eta, after did-schema #88) models it as:
%     - ONE `entity` class with a bound `type` (organism, device, cell, group,
%       session, dataset, ...). A v1 subject, element or subject_group becomes
%       an entity with its id preserved; a group's members point at it by
%       `member_of` directed_relations.
%     - Statements by composition: a statement's class is its DIRECTION
%       (`observation`, `assertion`, `manipulation`, `calculation`) and its
%       value kind (`mass`, `term`, `dose`, `formulation`, ...) is a mixin in
%       `superclasses`; it points at its entity by `entity_id`. The only named
%       statement classes are the eight vision calculators. A joined name such
%       as `term_observation` is NOT a class (did2.convert.statementKind reads
%       one on old-vintage input; tests/+did2/+unittest/testNoOldLeafNames.m
%       keeps code from writing one).
%     - A substance manipulation takes value kind `dose` or `formulation`
%       (with `chemical` / `formulation` documents); a physical one a quantity
%       kind such as `temperature`; a payload-free act `term`. NO
%       injection/bath/pharmacological family, NO escape hatch.
%     - Relationships are `directed_relation` / `undirected_relation` documents.
%     - Locus is Path S: an attributed anatomical part is its own entity +
%       a part_of directed_relation (minted, deduplicated per animal, by the
%       NDI second pass ndi.migrate -- it needs the corpus-wide subject graph).
%
%   NAMES IN THE NARRATIVE BELOW. Most of it was written in 2026-07/08 against
%   the pre-#88 schema, and some entries still use that era's names: `subject`
%   (now an `entity`), `subject_statement` / `subject_interaction` and
%   `subject_id` (now the direction class and its `entity_id` edge), and
%   joined leaf names such as `term_observation` (now `observation` with value
%   kind `term`). The roster at the bottom is generated from each migrator's
%   H1 summary and uses the current names; read it for what a migrator emits.
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
%     subject_group      - 1 -> 1+N. -> an `entity` of type group (id
%                          preserved) + one member_of directed_relation per
%                          member.
%     treatment_transfer - 1 -> 1. Always carried whole as v1 (needs mapping,
%                          for the Babu reimport): [treatment transfer stays
%                          v1], Jess Haley, 2026-10-27.
%     ontology_table_row - 1 -> 1. Every row carried whole as v1 with a
%                          `needs_mapping` note (carry-026): a row does not
%                          state which entity each column is about, so the
%                          generic stage resolves no subject and fans out no
%                          statements ([table rows carried as v1], Jess Haley,
%                          2026-10-30).
%     treatment          - 1 -> N. A term that states its number's kind ->
%                          a `manipulation` of that value kind; a ChEBI
%                          substance -> a `dose` or `formulation` (immersion)
%                          by its recorded location, with its chemical and
%                          formulation documents; a merely-located site -> an
%                          `observation` (value kind `term`). + shared anchor.
%                          Anything routed by label words is carried whole as
%                          v1 with a `needs_mapping` note ([one correct
%                          reading], Jess Haley, 2026-10-26).
%     treatment_drug     - 1 -> N. -> a `manipulation` with value kind `dose`
%                          (or `formulation` for an immersion, decided by the
%                          recorded location; the mixture_table -> chemical
%                          and formulation documents; primary drug is the
%                          spine variable) + optional site `observation` (value
%                          kind `term`).
%     virus_injection    - 1 -> N. -> a `manipulation` (value kind `dose` or
%                          `formulation`, as treatment_drug; virus is the spine
%                          variable + first chemical; dilution -> concentration;
%                          diluent -> a second chemical) + optional site obs.
%     probe_location     - 1 -> 2. -> an `observation` with value kind `term`
%                          about the probe's entity (a device, D2/D5): variable = a spatial
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
%   SINCE 2026-10-27 simple_calc, spike_clusters, spikewaves and
%   binnedspikeratevm are CARRIED whole as v1 under a needs-home register row
%   instead (Jess Haley, [simple_calc carries as needs home], [unbuilt spike
%   classes carry as needs home]); the reasons below are why no home exists.
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
%   THE SPIKE PROCESSING PARAMETERS FAMILY -> ONE `method` class.
%   Four did_v1 settings classes fold to the ONE generic `method` document
%   (`method_parameters` until did-schema #88; TEAM-SIGN-OFF 2026-08-09,
%   V_eta_method_parameters_plan.md), built by private/jMethodParameters. Each
%   is 1 -> 1 with base.id PRESERVED and the v1 base.name carried as the
%   method's `name` field -- the id because three
%   templates point at it (spikewaves.extraction_parameters_id,
%   spike_clusters.sorting_parameters_id/.extraction_parameters_id,
%   spike_extraction_parameters_modification.extraction_parameters_id), the name
%   because two apps look a protocol up by
%   ndi.query('base.name','exact_string',...) at spikeextractor.m:372 and
%   spikesorter.m:373. The v1 `app` block becomes a `software` entity + a
%   software_id edge (R1), so a fold emits 2 bodies when one is minted.
%   Settings become `parameters` entries (did2.build.parameter); the rest of
%   the block becomes further entries (jParameterList), not a separate bag.
%     spike_extraction_parameters
%                        - the global protocol; no v1 dependencies, so no scope
%                          edges. 15 fields -> 4 bound entries (refractory
%                          period, waveform window start + duration, threshold)
%                          + the rest of the block as further entries.
%     spike_extraction_parameters_modification
%                        - the same 15 fields (v1 stores a FULL copy, never a
%                          diff) + element_id -> entity_id and
%                          extraction_parameters_id -> parent_id (LINEAGE
%                          only -- precedence comes from the scope). Its epoch
%                          scope is the WRITER's, not the template's
%                          (spikeextractor.m:310 sets epochid.epochid on a class
%                          declaring only base + app): an `epoch_id` edge when
%                          the minted `epoch` document is known, else an
%                          `epochid` text parameter (#60).
%     sorting_parameters - no bound variables by decision (all six fields are in
%                          the plan's bag list by name), so every non-empty field
%                          of the block becomes a parameter entry labelled by
%                          its v1 name.
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
%     image_stack        - 1 -> 3. -> a body-backed `observation` with value
%                          kind `intensity` (a mask or label map, read from
%                          label words, is carried as v1)
%                          + a sampled_body holding the carried pixel frames
%                          (its dimensions and covariates from the source's
%                          dimension order) + shared anchor (§C.4). The
%                          element_epoch/ingested quartet the V_zeta fold minted
%                          collapses into the one sampled_body; NDI-side imaging
%                          element/daqreader infra is left to the NDI second pass
%                          (D2). 7,007 docs in JH.
%                          The source `document_id` (the ontologyTableRow) is
%                          NOT carried: did-schema #88 dropped the
%                          `ontology_table_row_id` edge (#73 item 42), so the
%                          row is the NDI second pass's to resolve (see the
%                          comment in image_stack.m). The subject-less haley
%                          E. coli sites take the guarded passthrough.
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
%                            dataset -has_author-> person (order = position),
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
%                          not resolve. SINCE 2026-10-26 the assembly fields
%                          (is_linked, session_creator, inputs, session_reference)
%                          are the relation's method or dropped as copies, else
%                          the document is carried (private/jMembershipBodies;
%                          [session opener inputs], [linked session reference
%                          follows the ingested rule], Jess Haley, 2026-10-27).
%     subjectmeasurement - 1 -> 2 (fold) / 1 -> 1 (guarded passthrough).
%                          TEAM-SIGN-OFF [subject measurement], jess 2026-08-06.
%                          Routes through the EXISTING `measurement` fold (shared
%                          private/jMeasurementFold + jQuantityLeaf) with NO new
%                          class: the v1 subject_id edge becomes the
%                          `observation`'s entity_id, `measurement` becomes its
%                          `variable`, `value` becomes the typed value, and
%                          `datestamp` becomes the TIME ANCHOR -- an
%                          `absolute_time_reference` document
%                          (private/jAbsoluteReference), NOT a field; with no
%                          readable datestamp, the session anchor. `measurement`
%                          has no datestamp field at all, so a plain field mapping
%                          would have dropped the measurement time. Signed WITH a
%                          known gap: `value` carries no unit, so the value kind should
%                          come from the D9 registry -- which ships no dimensional
%                          rows yet, so jQuantityLeaf is the pass-1 stand-in and
%                          anything it cannot type PASSES THROUGH.
%                          THE FIRST EMITTER OF `absolute_reference` (now
%                          `absolute_time_reference`).
%     pyraview           - (extended) the inherited `filter` superclass block now
%                          splits off ONE `method` document
%                          (private/jFrequencyFilter), referenced by every level
%                          body's optional `sampled_body.method_id`. It used to be
%                          discarded outright. It was a `frequency_filter` named by
%                          `filter_id` (TEAM-SIGN-OFF [frequency_filter], jess
%                          2026-07-30) until Jess Haley 2026-10-22 [filters are
%                          methods]; a schema still declaring filter_id is
%                          did2:convert:schemaTooOld. An all-pass ('none') emits
%                          nothing. The source field is v1's `type` (pyraview
%                          reads raw v1; the +migrators/filter.m superclass
%                          migrator that renamed it to `filter_type` is deleted,
%                          [unreached superclass migrators deleted], 2026-10-27).
%     binaryseries_parameters
%                        - CARRIED whole as v1, needs_mapping, since 2026-10-29
%                          ([binaryseries parameters carried], Jess Haley: "each
%                          dataset says which data body it describes"; no
%                          register row yet). What follows is the passthrough
%                          it replaced:
%                          1 -> 1 GUARDED PASSTHROUGH, placeholder-normalising.
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
%   the WRITER in DID-schema (by tools/build_v_eta.py, which did-schema deleted
%   on 2026-10-21; the classes are now schemas/V_eta/stable/generic_file.json
%   and valid_interval.json, disposition `retire` in index.json), so the
%   identity fallback carries the document and the tombstone lets it validate.
%   (generic_file is since folded by the batch pass did2.convert.foldGenericFiles.)
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
%   `subject_statement.variable`). [2026-10-23: in did-schema #88's names, an
%   `observation` with value kind `logical`, the semantic in its `variable`;
%   `relative_reference.relative_to` is now relative_time_reference's
%   `referent_id` edge.] That work is a BATCH pass, not a migrator,
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
%     ontology_image     - -> an `observation` about the imaged entity + a
%                          sampled_body for the image raster (D5). Built for the
%                          legacy shape (see the roster entry); the current NDI
%                          shape still passes through.
%
%   Classes with no did_v1 -> V_eta split fall through to the default
%   +migrators/<class> (1 -> 1) migrator, gaining only the schema_version tag.
%
%   SOFTWARE (TEAM-SIGN-OFF [software], jess 2026-08-06): the did_v1 `app` mixin
%   is replaced by a `software` ENTITY referenced by a `software_id` edge. The
%   per-run os/interpreter was `execution_environment` on the interaction; since
%   did-schema #88 each is its own `software` entity on a calculation's optional
%   `operating_system_id` / `interpreter_id` edge (private/jRunEntities). The fold
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
%   split, so the base (+migrators) superclass migrator kept running under V_eta; a
%   V_eta class needing different superclass-block handling puts a file in
%   +super/ and the dispatcher prefers it. It may NOT live in +migrators_j
%   itself: half the names here (element, subject, image, measurement,
%   filenavigator, pyraview, ...) are also superclass names somewhere in the
%   v1 zoo, and a concrete migrator returns a CELL of bodies where the
%   superclass pass is contracted to return one struct. A superclass override
%   must return exactly one body.
%     +super/ngrid.m   carries the did_v1 ngrid block VERBATIM (data_size,
%                      data_type, data_dim, coordinates). The base one
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
%   95 migrator(s).
%
%     binaryseries_parameters
%         Brainstorm-J migrator: did_v1 binaryseries_parameters -- CARRIED whole as
%         v1, needs_mapping (the document is returned UNCHANGED).
%     binnedspikeratevm
%         Brainstorm-J migrator: did_v1 binnedspikeratevm -- CARRIED whole as v1 under
%         a needs-home register row (the document is returned UNCHANGED).
%     cell_type_labels
%         Brainstorm-J migrator: did_v1 cellTypeLabels -> V_eta cell_type_labels, an
%         id-preserving 1:1 passthrough. ⊂ base in V_eta; block fields (label,
%         label_name, taxonomy_level, n_cells, n_categories, n_unlabeled,
%         assignment_method, is_unsupervised) carry through verbatim --
%         `is_unsupervised` is LOAD-BEARING per the class's own .md doc (a k-means
%         clustering with no ground-truth reference is modelled the same as a
%         supervised classifier's output; only this flag distinguishes them) and any
%         coercion here would silently rewrite the distinction. depends_on
%         (cells_document_id required; reference_document_id optional) is carried
%         as-is. base.id is preserved.
%     contrast_sensitivity_calc
%         Brainstorm-J migrator: the ndi.calc.vis.contrast_sensitivity calculator
%         OUTPUT document -> the named calculation contrast_sensitivity_calculation
%         (id-preserved) + a session anchor + its software / run entities. Single-doc
%         fold: element_id (subject_id as fallback) -> entity_id; the result fields on
%         the contrast_sensitivity_calc block -> value (jContrastSensitivityValue: one
%         model_fit entry per RB / RBN / RBNS Naka-Rushton variant,
%         interpolated_values, significance, response_type), the spatial frequencies
%         the dimension and covariate; inherited input_parameters ->
%         method.parameters; `app` -> software / operating system / interpreter.
%     contrast_tuning
%         Brainstorm-J migrator -> contrast_tuning_calculation (did-schema #88).
%         Brainstorm-J migrator: did_v1 contrast_tuning (raw NDIcalc-vis result class)
%         -> the CONCRETE V_eta leaf `contrasttuning_calc` (⊂
%         [tuning_curve_calculation, contrast_tuning]) + a session anchor + minted
%         `software` and `runtime_environment` entities.
%     contrast_tuning_calc
%         Brainstorm-J migrator -> contrast_tuning_calculation (did-schema #88).
%         Brainstorm-J migrator: the ndi.calc.vis.contrast calculator OUTPUT document
%         -> the CONCRETE V_eta leaf `contrasttuning_calc` (⊂
%         [tuning_curve_calculation, contrast_tuning]) + a session anchor + minted
%         `software` and `runtime_environment` entities.
%     control_stimulus_ids
%         Brainstorm-J migrator: did_v1 control_stimulus_ids -> NO V2 DOCUMENT.
%         CARRIED whole as v1 with a note citing carry-152 since 2026-10-30 ([control
%         records carried in pass 1], Jess Haley); before that (passed through for
%         NDI's second pass, which folds it into the presentation's `control
%         condition` covariate; [control as covariate], Jess Haley 2026-10-22).
%         HISTORY: `control_designation` (V_eta_stimulus_model_plan.md, TEAM-SIGN-OFF
%         [stimulus] 2026-08-08). A DERIVED annotation of WHICH presented trials are
%         the control reference, computed by the tuning_response app. It is NOT baked
%         into the immutable stimulus body: it REFERENCES the presentation (the
%         body-of-record, then `timed_sequence`, `item` since did-schema c12d778,
%         2026-10-04; id-preserved through the second-pass decompose, so the edge
%         resolves either way) and carries the derivation method; marked derived_from
%         the presentation (T10). Drops the v1 `app` mixin (software model, R1) and
%         the `ids` container word (T13).
%     daqmetadatareader
%         Brainstorm-J migrator: did_v1 daqmetadatareader ->
%         `acquisition_metadata_reader` (+ the `software` entity for the
%         implementation class). 1 -> 2, or 1 -> 1, or a guarded passthrough.
%     daqmetadatareader_epochdata_ingested
%         Brainstorm-J migrator: the per-epoch metadata archive. On did-schema #88
%         this PASSES THROUGH: #73 review item 61 retired `acquisition_metadata_file`,
%         and the decided target, an `opaque_body` owned by the epoch's stimulator
%         manipulation, is built by the batch pass did2.convert.resolveEpochProbemap
%         (mkMetadataArchiveBodies).
%     daqreader
%         Brainstorm-J migrator: did_v1 daqreader folds to an `acquisition_reader` + a
%         `software` entity. 1 -> 2, base.id PRESERVED ON THE READER.
%     daqreader_epochdata_ingested
%         Brainstorm-J migrator: lift the epoch's clock extents out of `epochtable`
%         into `relative_time_reference` documents.
%     daqreader_image_epochdata_ingested
%         Brainstorm-J migrator: the camera's ingested epoch. Lifts the inherited
%         epoch clock extents; the image fold is BLOCKED and the document is
%         preserved.
%     daqreader_mfdaq_epochdata_ingested
%         Chunk-b/c de-encode: the mfdaq ingested cache dissolves into the generic
%         daqreader_epochdata_ingested.
%     daqreader_ndr
%         Chunk-c de-encode: daqreader_ndr folds into an acquisition_reader. The
%         reader subtype ('ndr') was encoded in the CLASS NAME, but it is already
%         discriminated by ndi_daqreader_class, so the distinguishing fields de-encode
%         onto the generic daqreader: ndr_reader_string -> daqreader.reader_string,
%         and ndi_daqreader_ndr_class dropped (redundant). `file_extension` is NOT
%         carried -- see the block at the copy site below for why, and do not restore
%         it from this line. The daqreader superclass chain is rebuilt by
%         ensureClassBlocks after this.
%     daqsystem
%         Brainstorm-J migrator: did_v1 daqsystem -> `acquisition_system`
%         (configuration off `base`) + a `software` entity for its own implementation
%         class. 1 -> 2, or 1 -> 1 when there is no class name. base.id AND base.name
%         PRESERVED on the acquisition_system.
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
%         -> 1 demo collapse signed by the team on 2026-08-06 (recorded then in
%         did-schema `tools/build_v_eta.py`, deleted 2026-10-21; the class is now
%         `schemas/V_eta/stable/demo.json`); the fold itself is in private/jDemoFold.
%     demo_ndi_mock
%         Brainstorm-J migrator: did_v1 `demoNDIMock` -> the V_eta `demo` class, 1 ->
%         1 with base.id PRESERVED, the INHERITED `demoNDI.value` carried and
%         `is_mock` TRUE. The other half of the 3 -> 1 demo collapse signed by the
%         team on 2026-08-06 (recorded then in did-schema `tools/build_v_eta.py`,
%         deleted 2026-10-21; the class is now `schemas/V_eta/stable/demo.json`); the
%         fold itself is in private/jDemoFold.
%     distance_metadata
%         Brainstorm-J migrator: carry a v1 distance_metadata whole as v1. 1 -> 1.
%     electrode_offset_voltage
%         Brainstorm-J migrator: did_v1 electrode_offset_voltage -> an `observation`
%         with value kind `voltage` about the probe's entity, qualified by the
%         temperature it was measured at (a condition), + the session anchor. 1 -> 2.
%     element
%         Brainstorm-J migrator: did_v1 element -> an `entity` (+ kind assertions +
%         the raw-recording observation + a lineage relation). V_eta retires the
%         recording-side `element` class: any identifiable thing -- an organism, a
%         device/probe, a derived signal or sorted unit -- is an `entity` with a
%         `type` (a device for a probe, a cell or group for a sorted unit, a group for
%         an ensemble; anything else carried: elementEntityType, decided 2026-10-26,
%         below). The element document therefore becomes an `entity` with its id
%         PRESERVED, so the ~50 classes that reference it (`element_id` /
%         `underlying_element_id` / `stimulator_id`) keep resolving -- now to an
%         entity.
%     element_epoch
%         Brainstorm-J migrator: element_epoch -> acquisition_epoch.
%     epochfiles_ingested
%         Brainstorm-J migrator: DELIBERATE GUARDED PASSTHROUGH.
%     file_reference
%         Brainstorm-J migrator: did_v1 fileReference -> V_eta file_reference, an
%         id-preserving 1:1 passthrough. ⊂ base in V_eta; NOT folded to `generic_file`
%         -- the two classes coexist BY DESIGN per the file_reference .md doc:
%         `generic_file` HOLDS bytes, while `file_reference` RECORDS the identity of
%         an external file that lives somewhere else (original_path, format_ontology,
%         date_created, date_updated, file_size, checksum, checksum_algorithm). This
%         migrator is DELIBERATELY NOT routed through +did2.+convert.foldGenericFiles;
%         universalRenames has already snake_cased the block field names that were
%         camelCase in NDI (originalPath -> original_path, formatOntology ->
%         format_ontology, dateCreated -> date_created, dateUpdated -> date_updated,
%         fileSize -> file_size, checksumAlgorithm -> checksum_algorithm), which is
%         exactly the V_eta schema's spelling. The optional `document_id` edge
%         (pointing at the document this file is a reference to) carries through
%         as-is. base.id is preserved.
%     filenavigator
%         Brainstorm-J migrator: did_v1 filenavigator -> epoch_file_pattern (+ the
%         `software` entity for the implementation class). 1 -> 1 or 1 -> 2.
%     fitcurve
%         Brainstorm-J migrator: did_v1 fitcurve -> a `calculation` with value kind
%         `model_fit` (private/jModelFit) + the shared session anchor (+ software and
%         run documents).
%     gene_expression
%         Brainstorm-J migrator: did_v1 geneExpression -> V_eta gene_expression, an
%         id-preserving 1:1 passthrough. ⊂ base in V_eta; a SHAPE MIXIN, not itself an
%         observation -- assay / count_type / count_units describe how counts were
%         produced, not what they measure, and the observation-ness lives on the
%         concrete pyramid class that binds `variable = NCIT:C16608 "gene expression"`
%         (see spatial_gene_expression_pyramid.m). Block fields carry through
%         verbatim; base.id is preserved.
%     gene_list
%         Brainstorm-J migrator: did_v1 geneList -> a standalone `term` document, its
%         `genes.tsv` kept unchanged as the term's opaque_body. 1 -> 2.
%     gene_list_mapping
%         Brainstorm-J migrator: did_v1 geneListMapping -> V_eta gene_list_mapping, an
%         id-preserving 1:1 passthrough. ⊂ base in V_eta; the two gene_list_id_a /
%         gene_list_id_b edges are both required and carry through, and the block
%         fields (label, mapping_type, method, symmetric, n_pairs, n_genes_mapped_a,
%         n_genes_mapped_b, has_score) carry through verbatim. `mapping_type` and
%         `symmetric` are LOAD-BEARING per the class's own .md doc: alias-vs-ortholog
%         is not collapsible to a bare `directed_relation` (the two answer different
%         questions -- symbol drift vs. species mapping), and this migrator makes no
%         attempt to normalise or infer either. base.id is preserved.
%     hartley_calc
%         Brainstorm-J migrator: the ndi.calc.vis.hartley reverse-correlation OUTPUT
%         document -> the named calculator class `receptive_field_calculation` + the
%         `receptive_field` result composite, id- and depends_on-PRESERVED, plus the
%         response volume in TWO `sampled_body` documents (one per plane) and the
%         windowed spike train as a THIRD, input-side body.
%     image
%         Brainstorm-J migrator: did_v1 `image` -> through image_stack: a body-backed
%         `observation` with value kind `intensity` (a mask: a `calculation` with
%         value kind `logical` or `label`) + a sampled_body (+ the shared session
%         anchor). 1 -> 3.
%     image_stack
%         Brainstorm-J migrator: did_v1 image_stack -> a body-backed `observation`
%         with value kind `intensity` (a mask or label map is carried as v1) + a
%         sampled_body (+ the shared session anchor).
%     jrclust_clusters
%         Brainstorm-J migrator: did_v1 jrclust_clusters -> a body-backed
%         `calculation` with value kind `label` (the per-spike cluster assignments) +
%         an opaque_body + the session anchor (+ software and run documents).
%     kiasort_clusters
%         Brainstorm-J migrator: did_v1 kiasort_clusters -> the D-C analysis-tier
%         shape (a `calculation` with value kind `label` + opaque_body + session
%         anchor, + software and run documents).
%     kilosort_clusters
%         Brainstorm-J migrator: did_v1 kilosort_clusters -> the D-C analysis-tier
%         shape (a `calculation` with value kind `label` + opaque_body + session
%         anchor, + software and run documents).
%     lightsheet_zarr_level
%         Brainstorm-J migrator: did_v1 lightsheetZarrLevel -> a `sampled_body` of the
%         pyramid's observation; a FILE-LESS one when the level holds no bytes
%         ([compression block and empty levels], Jess Haley, 2026-10-26), where it
%         emitted NOTHING before.
%     lightsheet_zarr_pyramid
%         Brainstorm-J migrator: did_v1 lightsheetZarrPyramid -> an `observation` of
%         intensity (the lightsheet volume) of its subject, id PRESERVED, plus the
%         `software` entity that built it (and its version); it carries the
%         `source_file_id` join a batch pass follows to make the source's
%         fileReference (OME-Zarr store or TIFF folder) the observation's unheld body.
%     measurement
%         Brainstorm-J migrator: did_v1 measurement -> a typed `observation` (value
%         kind: the measured quantity, or `term`) (+ the shared session anchor), for
%         the rows that can be typed honestly; everything else is carried through for
%         the second pass.
%     metadata_editor
%         Brainstorm-J migrator: did_v1 metadata_editor -> a structured `dataset`
%         entity + the person / organization / funding / publication / web_resource
%         entities it references + the `directed_relation`s that connect them. Strict
%         J stops storing dataset metadata as one opaque `metadata_structure` blob
%         (the NDIMetaDataEditorApp serialization) and instead decomposes it into
%         first-class, queryable entities, exactly as the subject side stopped storing
%         openMINDS bundles.
%     neuron_extracellular
%         Brainstorm-J migrator: did_v1 neuron_extracellular -> CALCULATIONS about the
%         sorted unit's own entity (+ the shared session anchor, the software and its
%         run); no entity of its own.
%     oneepoch
%         Brainstorm-J migrator: carry a v1 oneepoch whole as v1. 1 -> 1.
%     ontology_image
%         Brainstorm-J migrator: did_v1 ontology_image, dispatched ON SHAPE. The
%         current NDI shape (`ontology_nodes` + an `ontologyTableRow_id` edge + the
%         `ngrid` raster) is a GUARDED PASSTHROUGH deferred to the NDI second pass: a
%         table row is not a subject, so pass 1 cannot fill a statement's `entity_id`
%         edge without minting the husk the image_stack guard exists to stop. The
%         legacy `ontology_name` + `ontology_region` shape (which the correction below
%         shows has never existed in NDI) would migrate 1 -> 2 to an `observation`
%         with value kind `term` about the element's entity + a session anchor (with
%         an `ngrid` raster, 1 -> 3: an `observation` with value kind `intensity` + a
%         sampled_body + the anchor). Any third shape ERRORS rather than emitting. The
%         raster and the provenance edge are deferred with the passthrough (#47).
%     ontology_label
%         Brainstorm-J migrator: did_v1 ontology_label -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%     ontology_table_row
%         Brainstorm-J migrator: did_v1 ontology_table_row -> the v1 row, carried
%         whole (1 -> 1).
%     openminds
%         Brainstorm-J migrator: did_v1 `openminds` -- a GUARDED PASSTHROUGH.
%     openminds_element
%         Brainstorm-J migrator: did_v1 openminds_element -> an `assertion` with value
%         kind `term`.
%     openminds_stimulus
%         Brainstorm-J migrator: did_v1 openminds_stimulus -- DEFERRED to the NDI
%         second pass; the document is passed through UNCHANGED.
%     openminds_subject
%         Brainstorm-J migrator: did_v1 openminds_subject -> an `assertion` with value
%         kind `term`.
%     oridirtuning_calc
%         Brainstorm-J migrator -> orientation_direction_tuning_calculation
%         (did-schema #88). Brainstorm-J migrator: the ndi.calc.vis.oridir calculator
%         OUTPUT document -> the CONCRETE V_eta leaf `oridirtuning_calc` (⊂
%         [tuning_curve_calculation, orientation_direction_tuning]) + a session anchor
%         + minted `software` and `runtime_environment` entities.
%     orientation_direction_tuning
%         Brainstorm-J migrator -> orientation_direction_tuning_calculation
%         (did-schema #88). Brainstorm-J migrator: did_v1 orientation_direction_tuning
%         (raw NDI-matlab result class) -> the CONCRETE V_eta leaf `oridirtuning_calc`
%         (⊂ [tuning_curve_calculation, orientation_direction_tuning]) + a session
%         anchor + minted `software` and `runtime_environment` entities.
%     position_metadata
%         Brainstorm-J migrator: did_v1 position_metadata -> carried whole as v1,
%         until its position element is mapped. 1 -> 1.
%     probe_geometry
%         Brainstorm-J migrator: did_v1 probe_geometry -> one `observation` with value
%         kind `length` PER SPATIAL AXIS about the probe's entity, each linked to the
%         probe's one `coordinate_system`, plus that coordinate system, the session
%         anchor and an optional probe-model `assertion` with value kind `term`.
%     probe_location
%         Brainstorm-J migrator: did_v1 probe_location -> an `observation` with value
%         kind `term`, + the session anchor.
%     pyraview
%         Brainstorm-J migrator: did_v1 pyraview -> a body-backed `observation` with
%         value kind `voltage` + one sampled_body per level file (+ the shared session
%         anchor, + a frequency filter document when the source names one).
%     session
%         Brainstorm-J migrator: `reference` -> `local_identifier`, and drop the three
%         V_zeta inventions. 1 -> 1, base.id PRESERVED, except where `session_id` is
%         an edge: there base.id becomes the session id.
%     session_in_a_dataset
%         Brainstorm-J migrator: did_v1 session_in_a_dataset -> the session<->dataset
%         membership as a first-class relation. Now that `session` is an `entity`, a
%         session belonging to a dataset is a `directed_relation` (session -part_of->
%         dataset), not a bookkeeping record.
%     simple_calc
%         Brainstorm-J migrator: did_v1 simple_calc -- CARRIED whole as v1 under a
%         needs-home register row (the document is returned UNCHANGED).
%     site2channelmap
%         Brainstorm-J migrator: did_v1 site2channelmap -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%     sorting_parameters
%         Brainstorm-J migrator: did_v1 sorting_parameters -> ONE `method` document
%         (`method_parameters` before did-schema #88) (+ the `software` entity its v1
%         `app` block names).
%     spatial_frequency_tuning
%         Brainstorm-J migrator -> spatial_frequency_tuning_calculation (did-schema
%         #88). Brainstorm-J migrator: did_v1 spatial_frequency_tuning (raw
%         NDIcalc-vis result class) -> the CONCRETE V_eta leaf
%         `spatial_frequency_tuning_calc` (⊂ [tuning_curve_calculation,
%         spatial_frequency_tuning]) + a session anchor + minted `software` and
%         `runtime_environment` entities.
%     spatial_frequency_tuning_calc
%         Brainstorm-J migrator -> spatial_frequency_tuning_calculation (did-schema
%         #88). Brainstorm-J migrator: the ndi.calc.vis.spatialfrequency calculator
%         OUTPUT document -> the CONCRETE V_eta leaf `spatial_frequency_tuning_calc`
%         (⊂ [tuning_curve_calculation, spatial_frequency_tuning]) + a session anchor
%         + minted `software` and `runtime_environment` entities.
%     spatial_gene_expression_cells
%         Brainstorm-J migrator: did_v1 spatialGeneExpressionCells -> V_eta
%         spatial_gene_expression_cells, an id-preserving 1:1 passthrough. The class
%         is ⊂ base in V_eta; the block fields (segmentation_method, contour geometry,
%         data types, ...) and the depends_on edges
%         (spatial_gene_expression_pyramid_id, subject_id, source_file_id) carry
%         through as-is -- universalRenames has already snake_cased both the block key
%         and its immediate fields, and ensureClassBlocks rebuilds
%         document_class.superclasses from the V_eta chain. base.id is preserved so a
%         dependent labeling row's cells_document_id edge (mustBeNonEmpty: true) still
%         resolves.
%     spatial_gene_expression_pyramid
%         Brainstorm-J migrator: did_v1 spatialGeneExpressionPyramid -> V_eta
%         spatial_gene_expression_pyramid, PASSED THROUGH. did-schema #88 restates the
%         class as its v1 shape (base + gene_expression, with the v1 `subject_id` /
%         `geneList_id` edges), so the document validates under its own class and
%         nothing is reshaped: no statement, no bound `variable` (the "Gene
%         Expression" binding belongs to the #70 reshape, which #88 does not carry),
%         no session anchor. base.id is preserved so a Cells / Tiles / file_reference
%         row's `spatial_gene_expression_pyramid_id` edge still resolves.
%     spatial_gene_expression_tiles
%         Brainstorm-J migrator: did_v1 spatialGeneExpressionTiles -> V_eta
%         spatial_gene_expression_tiles, an id-preserving 1:1 passthrough. The class
%         is ⊂ base in V_eta; block fields (bin_size, dimension_*, data_type_*, tile
%         geometry) and the depends_on edges (spatial_gene_expression_pyramid_id
%         required; subject_id optional -- the pyramid dep carries it; source_file_id
%         optional) carry through as-is. universalRenames has snake_cased the block
%         key and its immediate fields; ensureClassBlocks rebuilds the superclass
%         chain. base.id is preserved.
%     speed_tuning
%         Brainstorm-J migrator -> speed_tuning_calculation (did-schema #88).
%         Brainstorm-J migrator: did_v1 speed_tuning (raw NDIcalc-vis result class) ->
%         the CONCRETE V_eta leaf `speedtuning_calc` (⊂ [tuning_curve_calculation,
%         speed_tuning]) + a session anchor + minted `software` and
%         `runtime_environment` entities.
%     speed_tuning_calc
%         Brainstorm-J migrator -> speed_tuning_calculation (did-schema #88).
%         Brainstorm-J migrator: the ndi.calc.vis.speed calculator OUTPUT document ->
%         the CONCRETE V_eta leaf `speedtuning_calc` (⊂ [tuning_curve_calculation,
%         speed_tuning]) + a session anchor + minted `software` and
%         `runtime_environment` entities.
%     spike_clusters
%         Brainstorm-J migrator: did_v1 spike_clusters -- CARRIED whole as v1 under a
%         needs-home register row (the document is returned UNCHANGED).
%     spike_extraction_parameters
%         Brainstorm-J migrator: did_v1 spike_extraction_parameters -> ONE `method`
%         document (`method_parameters` before did-schema #88) (+ the `software`
%         entity its v1 `app` block names).
%     spike_extraction_parameters_modification
%         Brainstorm-J migrator: did_v1 spike_extraction_parameters_modification -> a
%         SECOND `method` document (`method_parameters` before did-schema #88) (+ the
%         `software` entity its v1 `app` block names).
%     spike_interface_sorting_outputs
%         Brainstorm-J migrator: did_v1 spike_interface_sorting_outputs -- DEFERRED to
%         the NDI second pass; the document is passed through UNCHANGED.
%     spikewaves
%         Brainstorm-J migrator: did_v1 spikewaves -- CARRIED whole as v1 under a
%         needs-home register row (the document is returned UNCHANGED).
%     stimulus_bath
%         Deferred: stimulus_bath migrates to a formulation-valued manipulation in the
%         NDI layer / the coarse resolveDeferredBaths pass.
%     stimulus_parameter
%         Brainstorm-J migrator: did_v1 stimulus_parameter -- carried whole as v1
%         (since 2026-10-29, [one folder, final classes only]; see the end of the
%         function). Until then it was a PASSTHROUGH that normalised the template's
%         own untypeable placeholder; the history below explains that repair, which a
%         carried document no longer needs (it is not read against V2). A non-empty
%         char or a non-numeric `value` still errors.
%     stimulus_presentation
%         Brainstorm-J migrator: did_v1 stimulus_presentation -- the decomposition is
%         DONE BY THE NDI SECOND PASS; pass 1 is a GUARDED PASSTHROUGH that carries
%         the document intact.
%     stimulus_response_scalar
%         Brainstorm-J migrator: did_v1 stimulus_response_scalar -> a `calculation`
%         whose value kind is `harmonic_component` (id PRESERVED), + its time anchor +
%         the calculator's software entity. Routed from did2.convert.v1_to_v2 only
%         when TargetVersion == 'V_eta'.
%     stimulus_response_scalar_parameters_basic
%         Brainstorm-J migrator: a guarded passthrough in pass 1. The batch pass
%         did2.convert.resolveResponseParameters then replaces each document with ONE
%         standalone `method` document (id PRESERVED) shared by every response whose
%         `method_id` names it (Decided by Jess Haley, 2026-10-21, "b"). Routed from
%         did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%     stimulus_tuningcurve
%         Brainstorm-J migrator: a raw ndi.app.stimulus.tuning_response tuning curve
%         (the pre-calculator-framework stimulus_tuningcurve document) -> the CONCRETE
%         V_eta leaf `tuningcurve_calc` (⊂ [tuning_curve_calculation, tuning_curve];
%         the raw case per issue #67) + a session anchor + minted `software` and
%         `runtime_environment` entities.
%     subject
%         Brainstorm-J migrator: a v1 subject -> one `entity` of type `organism`, id
%         preserved, carrying `name`, `local_identifier` and `notes` (v1
%         `description`). A v1 subject's handle was optional; one that states none is
%         carried whole as v1 (carry-033).
%     subject_group
%         Brainstorm-J migrator: did_v1 subject_group -> an `entity` of type `Group`,
%         id preserved (+ one member_of directed_relation per member).
%     subjectmeasurement
%         Brainstorm-J migrator: did_v1 subjectmeasurement -> a typed `observation`
%         (value kind: the measured quantity, or `term`) + an
%         `absolute_time_reference` carrying the measurement instant. Routed from
%         did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%     syncgraph
%         Brainstorm-J migrator: did_v1 `syncgraph` -> `clock_alignment_policy`.
%     syncrule
%         Brainstorm-J migrator: did_v1 `syncrule` -> `clock_alignment_configuration`.
%     syncrule_mapping
%         Brainstorm-J migrator: did_v1 `syncrule_mapping` -> `clock_alignment`.
%     temporal_frequency_tuning
%         Brainstorm-J migrator -> temporal_frequency_tuning_calculation (did-schema
%         #88). Brainstorm-J migrator: did_v1 temporal_frequency_tuning (raw
%         NDIcalc-vis result class) -> the CONCRETE V_eta leaf
%         `temporal_frequency_tuning_calc` (⊂ [tuning_curve_calculation,
%         temporal_frequency_tuning]) + a session anchor + minted `software` and
%         `runtime_environment` entities.
%     temporal_frequency_tuning_calc
%         Brainstorm-J migrator -> temporal_frequency_tuning_calculation (did-schema
%         #88). Brainstorm-J migrator: the ndi.calc.vis.temporalfrequency calculator
%         OUTPUT document -> the CONCRETE V_eta leaf `temporal_frequency_tuning_calc`
%         (⊂ [tuning_curve_calculation, temporal_frequency_tuning]) + a session anchor
%         + minted `software` and `runtime_environment` entities.
%     treatment
%         Brainstorm-J migrator: did_v1 treatment -> a `manipulation` whose value kind
%         is the one the treatment's term states for its number, or a dose / immersion
%         for a ChEBI substance (+ an optional site `observation` with value kind
%         `term` + the shared session anchor); otherwise the v1 document carried
%         whole.
%     treatment_drug
%         Brainstorm-J migrator: did_v1 treatment_drug -> an immersion (`manipulation`
%         valued by its formulation) or a `manipulation` with value kind `dose`,
%         decided by the recorded location.
%     treatment_transfer
%         Brainstorm-J migrator: did_v1 treatment_transfer -- always CARRIED whole as
%         v1 under a needs-mapping register row (the document is returned UNCHANGED).
%     tuningcurve_calc
%         Brainstorm-J migrator: the ndi.calc.stimulus.tuningcurve calculator OUTPUT
%         document -> the CONCRETE V_eta leaf `tuningcurve_calc` (⊂
%         [tuning_curve_calculation, tuning_curve]; the raw case per issue #67) + a
%         session anchor + minted `software` and `runtime_environment` entities.
%     virus_injection
%         Brainstorm-J migrator: did_v1 virus_injection -> a dose or an immersion,
%         decided by the recorded location.
%     vmneuralresponseresiduals
%         Brainstorm-J migrator: did_v1 vmneuralresponseresiduals -- DEFERRED to the
%         NDI second pass; the document is passed through UNCHANGED.
%     vmspikefilteringparameters
%         Brainstorm-J migrator: did_v1 vmspikefilteringparameters -> ONE `method`
%         document (`method_parameters` before did-schema #88) (+ the `software`
%         entity its v1 `app` block names) -- GUARDED, because this class mixes OUTPUT
%         DATA into a configuration document.
%     vmspikefit
%         Brainstorm-J migrator: did_v1 vmspikefit -> a `calculation` with value kind
%         `model_fit` (private/jModelFit) + the shared session anchor (+ software and
%         run documents).
%     vmspikesummary
%         Brainstorm-J migrator: did_v1 vmspikesummary -- DEFERRED to the NDI second
%         pass; the document is passed through UNCHANGED.
%
%   ====================== END GENERATED ROSTER ======================
