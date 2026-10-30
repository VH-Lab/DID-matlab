function [names, migrators] = rawV1Classes(v1Name)
%RAWV1CLASSES The v1 classes whose migrator reads the RAW v1 document.
%
%   NAMES = did2.convert.rawV1Classes() is a cellstr of v1 class names (the
%   v1 spelling, document_class.class_name exactly as v1 writes it).
%   did2.convert.v1_to_v2 hands a document of one of these classes to its
%   +migrators_j migrator UNCHANGED: no did2.convert.universalRenames, no
%   superclass migrators. Every other class runs exactly as before.
%
%   [NAMES, MIGRATORS] = did2.convert.rawV1Classes() also returns, for each
%   name, the +migrators_j migrator that converts it (the same name, except
%   in the table below).
%
%   MIGRATOR = did2.convert.rawV1Classes(V1NAME) is the +migrators_j migrator
%   for the v1 class V1NAME: its row in the table below, else V1NAME itself.
%
%   THE ONE TABLE OF v1 NAME -> MIGRATOR NAME. Some v1 classes are spelled
%   differently from the migrator files that convert them: NDIcalc-vis-matlab
%   writes `contrasttuning_calc` and `contrastsensitivity_calc`, and the
%   migrators are +migrators_j/contrast_tuning_calc.m and
%   contrast_sensitivity_calc.m; NDI writes `imageStack`, `ontologyLabel` and
%   `ontologyTableRow`, and the migrators are +migrators_j/image_stack.m,
%   ontology_label.m and ontology_table_row.m: the names universalRenames gives
%   those classes. THIS TABLE GOES when
%   universalRenames is deleted and the migrator files are renamed to the v1
%   names ([migrators read raw v1]); it is the only place the two spellings are
%   joined for a switched class. A row may name a class not (yet) in the list
%   below: it is read only for a listed class, or for one a caller passes in
%   v1_to_v2's 'RawV1Classes' option.
%
%   WHY. Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): a migrator reads v1 exactly as v1 defines
%   it (the NDI template and writer at the locked `main`), writes V2 only
%   through the builder, and accounts for every v1 field; the shared reads are
%   helpers (did2.convert.v1read.*), not a pass that rewrites the document.
%   Migrators switch ONE AT A TIME, each with a check that every v1 field is
%   accounted for; universalRenames is deleted once the last one has switched.
%   The check is the round trip of [migration reliability practices] (a):
%   did2.convert.roundtrip.check.
%
%   ADDING A CLASS HERE requires, in the same commit:
%     - its migrator +migrators_j/<class>.m reads the raw v1 shape (the
%       did2.convert.v1read helpers for depends_on / base / app / stamp);
%     - its inverse +roundtrip/<class>.m, and a round-trip test on the NDI
%       writer shape (tests/+did2/+unittest/testRawV1RoundTrip.m);
%     - the class has no superclass migrator whose work the raw migrator now
%       has to do itself (+migrators/<superclass>.m, +migrators_j/+super/).
%   testRawV1RoundTrip checks the first two for every name listed.
%
%   THE LIST, and why each is here:
%     subject        first family switched (phase 2 of docs/V2_PLAN.md in
%     subject_group  did-schema): two classes, superclass `base` only, no
%                    `app` block, no superclass migrator, and NDI writers
%                    small enough to state every field (ndi.subject,
%                    +NDIMaker/subjectMaker; +babu/import for subject_group).
%     treatment           the treatment family: four classes, superclass
%     treatment_drug      `base` only, no `app` block, no superclass migrator,
%     treatment_transfer  sharing jTreatmentBodies / jTreatmentAnchor; written
%     virus_injection     by +NDIMaker/treatmentMaker (all four),
%                         table2treatment, +haley and +dabrowska (treatment).
%                         Round trips: testRawV1RoundTripTreatment, which
%                         lists what V2 does not keep as known findings.
%     element             superclass `base` only, no `app` block; the old
%                         +migrators/element.m, never run for it (a class
%                         with a +migrators_j migrator skips it), is deleted. Written by
%                         ndi.element/newdocument. Round trips:
%                         testRawV1RoundTripElement.
%     element_epoch       superclasses `base` and `epochid` (no migrator for
%                         either); pass 1 makes the acquisition_epoch carrier
%                         the batch passes dissolve. Written by
%                         ndi.element/addepoch. Round trips:
%                         testRawV1RoundTripElementEpoch (the pass-1 carrier).
%     tuningcurve_calc               the tuning family: six calculator
%     contrasttuning_calc            outputs, superclasses `calculator`
%     oridirtuning_calc              (`base` + `app`) and a result class
%     spatial_frequency_tuning_calc  (stimulus_tuningcurve,
%     temporal_frequency_tuning_calc contrast_tuning,
%     contrastsensitivity_calc       orientation_direction_tuning,
%                         spatial_frequency_tuning, temporal_frequency_tuning;
%                         none for contrastsensitivity_calc), none of which
%                         has a superclass migrator; the old +migrators/<calc>
%                         wrappers (calcCommon) were never reached for them
%                         and are deleted. The `app` block is read through
%                         did2.convert.v1read.readApp. Written by
%                         ndi.calc.stimulus.tuningcurve (NDI-matlab) and
%                         ndi.calc.vis.* (NDIcalc-vis-matlab). Round trips:
%                         testRawV1RoundTripTuning.
%     stimulus_response_scalar  the stimulus-response family: superclasses
%     stimulus_response_scalar_parameters_basic  `base` + `stimulus_response`
%                         / `stimulus_response_scalar_parameters` (no migrator
%                         for any of them), no `app` block. Written by
%                         ndi.app.stimulus.tuning_response (the only writer at
%                         the locked main). The parameters document stays a
%                         pass-1 passthrough that resolveResponseParameters
%                         turns into a `method`. Round trips:
%                         testRawV1RoundTripStimulusResponse.
%     daqreader_mfdaq_epochdata_ingested    the ingested-epoch / sync family:
%     epochfiles_ingested                   superclasses `base` (+ `epochid`,
%     syncrule_mapping                      + daqreader_epochdata_ingested for
%     daqmetadatareader_epochdata_ingested  the mfdaq cache), no `app` block,
%                         no superclass migrator. Pass 1: the mfdaq cache
%                         de-encodes to daqreader_epochdata_ingested; the
%                         manifest passes through; the mapping and the stimulus
%                         file are carried (carry-036, carry-046) for
%                         epochMint and NDI's second pass. Written by
%                         +daq/+reader/mfdaq.m, +file/navigator.m,
%                         +time/syncgraph.m, +daq/metadatareader.m. Round
%                         trips: testRawV1RoundTripIngested.
%     imageStack          the imaging family: superclasses `base` +
%                         `imageStack_parameters`, no `app` block. The
%                         superclass migrator (+super/image_stack_parameters)
%                         is called by the leaf on the raw block (and on a
%                         raw v1 `image`'s, which the leaf converts too).
%                         Written by +setup/+conv/+haley/doImport.m
%                         and +babu/import.m. Round trips:
%                         testRawV1RoundTripImage.
%     daqsystem           the acquisition-system family: superclass `base`
%     filenavigator       (+ `daqreader` for daqreader_ndr), no `app` block,
%     daqreader           no superclass migrator (none exists for `base` or
%     daqreader_ndr       `daqreader`; +migrators_j/daqreader.m is the
%     daqmetadatareader   concrete migrator daqreader_ndr hands on to). The
%     syncrule            v1 names are the migrator names. What a migrator
%     syncgraph           does not read carries the document
%     probe_location      (private/jRawAccount). Written by +daq/system.m,
%                         +file/navigator.m, +daq/reader.m, +daq/+reader/
%                         +mfdaq/ndr.m, +daq/metadatareader.m, +time/
%                         syncrule.m, +time/syncgraph.m and the probe-location
%                         writers. Round trips: testRawV1RoundTripDaq.
%     neuron_extracellular  the spike-sorting / calculation family:
%     jrclust_clusters      superclasses `base` + `app` (neuron,
%     hartley_calc          jrclust), `calculator` + hartley_reverse_correlation
%     speedtuning_calc      + reverse_correlation + ngrid (hartley_calc), and
%                         `calculator` + speed_tuning (speedtuning_calc). The
%                         only superclass migrator any of them met is
%                         +migrators_j/+super/ngrid.m (a guard, no reshape),
%                         which hartley_calc now calls on the raw block; it
%                         stays for ontologyImage (which calls it too). The old
%                         +migrators wrappers (hartley_calc, speed_tuning_calc,
%                         simple_calc: calcCommon; jrclust_clusters) were never
%                         reached and are deleted with calcCommon. NDIcalc-vis
%                         writes `speedtuning_calc`, which universalRenames
%                         never mapped to the speed_tuning_calc migrator (the
%                         renamed path passes it through unconverted); the
%                         table below joins the two. Written by
%                         +ndi/+fun/+probe/+import/+jrclust/probe.m,
%                         +kilosort/probe.m, +kiasort/probe.m,
%                         +ndi/+app/spikesorter.m (neuron), jrclust/probe.m
%                         (jrclust_clusters), ndi.calc.vis.hartley and
%                         ndi.calc.vis.speed_tuning (NDIcalc-vis-matlab). Round
%                         trips: testRawV1RoundTripSpike.
%     probe_geometry      the probe family: superclass `base` only, no `app`
%     site2channelmap     block, no superclass migrator; the v1 names are the
%     electrode_offset_voltage  migrator names. probe_geometry converts (a
%                         writer document always carries, carry-001: fromStruct
%                         writes shank_id); site2channelmap passes through for
%                         the NDI second pass (its raw shape is the renamed one
%                         but for the `value` edge key); electrode_offset_voltage
%                         converts. What a migrator does not read carries the
%                         document (private/jRawAccount; [fields outside the
%                         template are malformed], carry-100). Written by
%                         +ndi/+fun/+probe/+geometry/fromStruct.m and
%                         +ndi/+setup/+conv/+marder/makeVoltageOffsets.m. Round
%                         trips: testRawV1RoundTripProbe.
%     spike_extraction_parameters  the spike-sorting parameters family:
%     spike_extraction_parameters_modification  superclasses `base` + `app`,
%     sorting_parameters  no superclass migrator. The three settings
%     kilosort_clusters   documents fold to a `method` (jMethodParameters;
%     kiasort_clusters    every block field a bound parameter or the bag, as
%     SpikeInterfaceSortingOutputs  before); a writer document always carries
%                         (carry-002/003/004: ndi.app/newdocument writes the
%                         run's os and interpreter). The cluster documents
%                         fold to a calculation and its opaque_body
%                         (jSorterOutput). SpikeInterfaceSortingOutputs (no
%                         writer at the locked main, no corpus document; the
%                         template alone fixes its shape) passes through under
%                         its v1 name, which V_eta keeps no class for, as a raw
%                         imageStack passthrough does; the table below joins it
%                         to its migrator. Written by ndi.app.spikeextractor,
%                         ndi.app.spikesorter and +ndi/+fun/+probe/+import/
%                         +kilosort/probe.m, +kiasort/probe.m. Round trips:
%                         testRawV1RoundTripSpikeParameters.
%     session               the session / dataset / presentation family:
%     session_in_a_dataset  superclass `base` (+ `epochid` and the writer's
%     dataset_remote        `app` for stimulus_presentation), no superclass
%     metadata_editor       migrator. The v1 names are the migrator names.
%     stimulus_presentation What a migrator does not read carries the
%                         document (private/jRawAccount). The presentation is
%                         carried untouched for NDI's second pass (carry-045),
%                         which reads it from the v1 input, so what NDI
%                         receives is unchanged. Written by +session/dir.m,
%                         +ndi/dataset.m, +cloud/+internal/
%                         createRemoteDatasetDoc.m, +metadata_ds_core/
%                         saveEditor2Doc.m, +app/+stimulus/decoder.m. Round
%                         trips: testRawV1RoundTripSession.
%     daqreader_epochdata_ingested        the ingested-epoch passthroughs: no
%     daqreader_image_epochdata_ingested  `app` block, snake_case blocks, so
%     vmneuralresponseresiduals           the raw passthrough is the renamed
%     vmspikesummary                      one but for the `value` edge key and
%                         validates against the same V_eta class. No superclass
%                         migrator (none exists for `epochid` or
%                         `daqreader_epochdata_ingested`). The mfdaq migrator
%                         still delegates to daqreader_epochdata_ingested, which
%                         skips the raw read for it. The two vm classes have no
%                         writer at the locked main and no corpus document (the
%                         template alone fixes their shape). Written by
%                         +ndi/+daq/reader.m and +daq/+reader/image.m. Round
%                         trips: testRawV1RoundTripIngestedEpochs.
%     cellTypeLabels      the spatial-transcriptomics family: pure pass-1
%     geneExpression      passthroughs, superclass `base` (+ `geneExpression`
%     geneList            for the pyramid), no `app` block, no superclass
%     geneListMapping     migrator. The raw passthrough keeps v1's camelCase
%     spatialGeneExpressionCells    class name, under which V_eta keeps no
%     spatialGeneExpressionPyramid  class (counted, not validated), as a raw
%     spatialGeneExpressionTiles    imageStack passthrough is; NDI's last step
%                         stores the v1 source on both paths. No DID batch
%                         pass or NDI second-pass step reads them. The table
%                         below joins each v1 name to its snake_case migrator.
%                         geneExpression (only a superclass block in NDI's
%                         writers) and geneListMapping have no writer at the
%                         locked main; no corpus holds any of the seven.
%                         Written by +ndi/+fun/+doc/+gene/makeCellTypeLabels.m,
%                         makeGeneList.m, makeCells.m, makePyramid.m. Round
%                         trips: testRawV1RoundTripGene.
%     measurement         the measurement family: superclass `base` (+
%     subjectmeasurement  `epochid` for stimulus_parameter), no `app` block, no
%     stimulus_parameter  superclass migrator. measurement reads v1's
%                         `ontologyName`; one with no V2 statement (a date, an
%                         untyped number, text), which passed through as a V2
%                         `measurement` (`retire`) whose renamed field its raw
%                         passthrough would not match, is carried as v1 at
%                         once (no register row yet), the end state NDI's last
%                         step gave it. subjectmeasurement (no writer outside
%                         NDI's tests) and stimulus_parameter are snake_case
%                         and read as before. Written by +ndi/+setup/+NDIMaker/
%                         treatmentMaker.m and +ndi/+setup/+conv/+marder/
%                         temptable2stimulusparameters.m. Round trips:
%                         testRawV1RoundTripMeasurement.
%     stimulus_tuningcurve          the NDI apps' own tuning results:
%     orientation_direction_tuning  superclass `base` (+ the writer's `app`
%                         block), no superclass migrator; the same result block
%                         as tuningcurve_calc / oridirtuning_calc, read the same
%                         way (jRawBody; jCalculation 'AccountForEveryField').
%                         Written by ndi.app.stimulus.tuning_response and
%                         ndi.app.oridirtuning. Round trips:
%                         testRawV1RoundTripTuningResults.
%     contrast_tuning            the NDIcalc-vis result blocks written
%     spatial_frequency_tuning   alone: superclass `base` only, no `app`
%     temporal_frequency_tuning  block, no superclass migrator; the same
%     speed_tuning               result block as contrasttuning_calc /
%                         spatial_frequency_tuning_calc /
%                         temporal_frequency_tuning_calc / speedtuning_calc,
%                         read the same way (jRawBody; jCalculation
%                         'AccountForEveryField'; speed_tuning through
%                         private/jSpeedTuning, shared with speed_tuning_calc).
%                         The v1 names are the migrator names. NDI-matlab's
%                         locked main holds no template for them: the
%                         templates are NDIcalc-vis-matlab's at 00e3e0f
%                         (vision/<class>.json), the commit the tuning
%                         family's fixtures are taken from. Written by the
%                         calculators' calculate_*_indexes (ndi.calc.vis.
%                         contrast_tuning, spatial_frequency_tuning,
%                         temporal_frequency_tuning, speed_tuning), whose
%                         document calculate() adds to the *_calc output; no
%                         corpus holds one. Round trips:
%                         testRawV1RoundTripTuningBlocks.
%     demoNDI             the demo classes: superclasses `base` (+ `mock`,
%     demoNDIMock         `demoNDI`), no `app` block, no superclass migrator;
%     binaryseries_parameters  jDemoFold reads either block spelling and the
%                         table below joins the v1 names to demo_ndi /
%                         demo_ndi_mock. binaryseries_parameters (no writer at
%                         the locked main, no corpus document; the template
%                         fixes its shape) is snake_case and read as before;
%                         since 2026-10-29 it is carried whole as v1
%                         ([binaryseries parameters carried], Jess Haley).
%                         Written by +ndi/+calc/+example/simple.m (demoNDIMock).
%                         Round trips: testRawV1RoundTripDemo.
%     ontologyLabel       superclass `base` only, no `app` block, no superclass
%                         migrator. Pass 1 hands it to NDI's second pass
%                         unchanged (or carries it, carry-064, with a carried
%                         stack; a field or edge outside its template carries
%                         it, carry-100, [ontologyLabel row split], Jess
%                         Haley, 2026-10-27, private/jRawAccount); the raw
%                         passthrough keeps the v1 class name,
%                         block `ontologyLabel` and field `ontologyNode`. Every
%                         reader of a label by its class name accepts both
%                         spellings first (siblings first, did-schema
%                         CLAUDE.md): did2.convert.isOntologyLabelClass
%                         (did2.convert.foldGenericFiles) and NDI-matlab's
%                         ndi.migrate.internal.isOntologyLabelClass (#1076).
%                         Written by +setup/+conv/+haley/doImport.m and
%                         +babu/import.m. Round trips: testRawV1RoundTripImage.
%     oneepoch            superclass `element_epoch` (whose superclass
%                         migrator, +migrators/element_epoch.m, the raw
%                         migrator now calls on the raw block itself, as
%                         +migrators_j/element_epoch.m does). Written by
%                         ndi.element addepoch with EPOCHIDS. Round trips:
%                         testRawV1RoundTripOneEpoch.
%     ontologyImage       superclasses `base` + `ngrid` (whose guard,
%                         +migrators_j/+super/ngrid.m, the raw migrator calls
%                         on the raw block). The writer's documents (they state
%                         `ontologyNodes`) pass through unchanged under the v1
%                         class name, which V_eta keeps no class for (counted,
%                         not validated); the table below joins it to
%                         ontology_image. Written by +ndi/+setup/+NDIMaker/
%                         imageDocMaker.m. Round trips:
%                         testRawV1RoundTripOntologyImage.
%     pyraview            superclasses epochclocktimes (+ epochid, base) and
%                         data/filter, whose superclass migrators the renamed
%                         path ran (+migrators/epochclocktimes, filter; both
%                         deleted 2026-10-27, [unreached superclass migrators
%                         deleted]); the
%                         migrator and private/jFrequencyFilter read either
%                         spelling, so the raw read needs neither. A pyraview
%                         naming an epoch defers in pass 1, and
%                         did2.convert.epochMint re-runs it from the
%                         quarantine's original body (the raw v1 document)
%                         with an `epoch_id` edge stamped, which the raw read
%                         allows; the epoch step's in-batch re-run sees only a
%                         carry (the untouched v1 source). Written by
%                         +ndi/+gui/+app/+pyraview/makePyraviewDoc.m. Round
%                         trips: testRawV1RoundTripPyraview.
%     fileReference          the external-file records and the lightsheet
%     lightsheetZarrPyramid  pyramids: superclass `base` only, no `app` block,
%     lightsheetZarrLevel    no superclass migrator; the table below joins each
%                         v1 name to its snake_case migrator. fileReference
%                         passes through pass 1 unchanged under its v1 class
%                         name; did2.convert.foldGenericFiles, the one reader of
%                         it by class name, accepts both spellings
%                         (did2.convert.isFileReferenceClass), and NDI-matlab's
%                         second pass compares neither name (src/ndi/+ndi/
%                         +migrate at origin/V2 675742f). The pyramid and level
%                         migrators read their block in either spelling, so the
%                         conversion is unchanged; what they do not read
%                         carries the document (private/jRawAccount,
%                         carry-100). Written by +ndi/+fun/+doc/+lightsheet/
%                         makeSourceFile.m, +gene/makeSourceFile.m and
%                         +lightsheet/makePyramid.m. Round trips:
%                         testRawV1RoundTripLightsheet.
%     simple_calc, spikewaves, spike_clusters, binnedspikeratevm  ALWAYS
%                         CARRIED whole as v1 under a needs-home register row
%                         (Decided by Jess Haley, 2026-10-27 [simple_calc
%                         carries as needs home], [unbuilt spike classes carry
%                         as needs home]): read raw so that the carry is the
%                         untouched v1 source. A carried document is not
%                         validated against V_eta, so the `app.name` spelling
%                         that kept them on the renamed path no longer
%                         quarantines. Their dependents carry (carry-064).
%                         Inverse: the passthrough one (never reached for a
%                         carry: did2.convert.roundtrip.check reads a carry as
%                         the v1 document itself).
%     control_stimulus_ids  superclass `base` (+ the writer's `app` block), no
%                         superclass migrator. ALWAYS CARRIED whole as v1
%                         (carry-152, [control records carried in pass 1],
%                         Jess Haley, 2026-10-30), a handed-on class in
%                         v1_to_v2 carryDependents, so its responses do not
%                         carry. Read raw so that the carry is the untouched v1
%                         source (`app.name`, edge key `value`), which is what
%                         NDI's second pass reads anyway: it takes the record
%                         from the ORIGINAL v1 bodies ([second pass reads
%                         control stimuli from v1], NDI-matlab #1082,
%                         ndi.migrate.internal.controlRecordsByPresentation). A
%                         carried document is not validated against V_eta, so
%                         the tombstone's `app_name` no longer quarantines it.
%                         Written by +ndi/+app/+stimulus/tuning_response.m.
%                         Inverse: the passthrough one (a carry is read as the
%                         v1 document itself). Round trips:
%                         testMigratorsJStimulusModel
%                         (testAControlRecordReadRawRoundTrips).
%     image               superclasses `base` + `imageStack_parameters`, no
%                         `app` block; +migrators_j/image.m hands it to
%                         image_stack.m, which reads it raw as it reads
%                         `imageStack` (the superclass migrator's refusals
%                         called on the raw block; what universalRenames would
%                         have discarded carries, carry-049). The `image`
%                         tombstone that kept it on the renamed path was
%                         deleted with did-schema's other did_v1 tombstones
%                         (2026-10-28, [carried v1 validates against NDI
%                         templates]): a subject-less raw passthrough is
%                         counted as a class V_eta keeps no schema for, as a
%                         raw `imageStack` passthrough is. No NDI writer at the
%                         locked main constructs it and no corpus holds one;
%                         the template (data/image.json) fixes its shape.
%                         Round trips: testRawV1RoundTripImage ([image raw
%                         round trip and single-read keys], Jess Haley,
%                         2026-10-30: the label back from the observation's
%                         notes, `format` 'tiff' from EDAM:format_3591).
%     dataset_session_info  superclass `base` only, no `app` block, no
%                         superclass migrator. Writes no V2 document ([fit
%                         classes kept; session list rebuilt], Jess Haley,
%                         2026-10-27): v1_to_v2 carryUnrebuiltSessionLists,
%                         which reads the v1 input, carries a list the batch's
%                         memberships do not rebuild (carry-118); a field
%                         outside the template carries it (private/
%                         jRawAccount, carry-100). Written by NDI's older
%                         +dataset/dir.m (template dataset_session_info.json).
%                         Inverse: the passthrough one, or nothing for a list
%                         that rebuilt. Round trips:
%                         testRawV1RoundTripSessionList.
%     fitcurve            superclass `base` only, no `app` block, no
%                         superclass migrator; a `calculation` with value kind
%                         `model_fit` (private/jModelFit), as before. The
%                         template states no subject, so a template-shaped fit
%                         is carried (carry-136); one that names an
%                         `element_id` or `subject_id` (read, though outside
%                         the template) converts. What the fold does not read
%                         carries the document (private/jRawAccount,
%                         carry-100). No writer at the locked main, no corpus
%                         document. Round trips: testRawV1RoundTripFit.
%     vmspikefit          superclasses `base` + `epochid` + `app`, no
%                         superclass migrator; the same fold as fitcurve
%                         (private/jModelFit), carried with no subject
%                         (carry-137). The `app` block is read in either
%                         spelling (jSoftwareFromApp). What the fold does not
%                         read carries the document (private/jRawAccount,
%                         carry-100). The vhlab_voltage2firingrate writer is
%                         in no repository we hold; no corpus document. Round
%                         trips: testRawV1RoundTripFit.
%     vmspikefilteringparameters  superclasses `base` + `epochid` + `app`, no
%                         superclass migrator; folds to a `method`
%                         (jMethodParameters) as before. The raw block's
%                         `rm60Hz` goes to the bag as `filter.rm60_hz`, the
%                         spelling the renamed path gave it; a non-empty
%                         `spiketimes` is carried (carry-143), the run's os or
%                         interpreter carries it (carry-005). What the fold
%                         does not read carries the document (private/
%                         jRawAccount, carry-100). The writer is in no
%                         repository we hold; no corpus document. Round trips:
%                         testRawV1RoundTripVmSpikeFiltering.
%     ontologyTableRow    superclass `base` only, no `app` block, no
%                         superclass migrator. ALWAYS CARRIED whole as v1
%                         (carry-026, [table rows carried as v1], Jess Haley,
%                         2026-10-30); read raw so that the carry is the
%                         untouched v1 source, which NDI's second pass counts
%                         under either class name (ndi.migrate.internal.
%                         ontologyRowsCarried). The table below joins it to
%                         ontology_table_row, which reads its block in either
%                         spelling. A body that names the snake_case class
%                         `ontology_table_row` (no NDI writer makes one) still
%                         runs renamed. Written by +ndi/+setup/+NDIMaker/
%                         tableDocMaker.m. Inverse: the passthrough one.
%                         Round trips: testRawV1RoundTripOntologyTableRow.
%     openminds           superclass `base` only, no `app` block, no
%                         superclass migrator. A guarded passthrough for
%                         did2.convert.resolveOpenmindsCitations and NDI's
%                         strainAssembly, which read the class name, the
%                         `openminds` block and either edge key (`value` raw,
%                         `document_id` renamed), so what they receive is
%                         unchanged but for v1's edge key; it validates
%                         against the same V_eta class. A field, block or edge
%                         outside the template (edges: `openminds_<n>`)
%                         carries it (private/jRawAccount, carry-100). Written
%                         by ndi.database.fun.openMINDSobj2ndi_document. Round
%                         trips: testRawV1RoundTripOpenminds.
%     openminds_subject   superclasses `base` + `openminds`, no `app` block, no
%                         superclass migrator; one term assertion about the
%                         subject, as before, or carried (carry-116, carry-117).
%                         Its `openminds_<n>` edges are not written to the
%                         assertion; they are accounted for because NDI's
%                         subjectStrainAssembly reads them from the v1 input.
%                         What the migrator does not read carries the document
%                         (private/jRawAccount, carry-100). Written by
%                         ndi.database.fun.openMINDSobj2ndi_document. Round
%                         trips: testRawV1RoundTripOpenminds.
%     openminds_element   superclasses `base` + `openminds`, no `app` block, no
%                         superclass migrator; one term assertion about the
%                         element, as before, or carried (carry-128, carry-146).
%                         What the migrator does not read carries the document
%                         (private/jRawAccount, carry-100), an `openminds_<n>`
%                         edge naming a child among it (the assertion keeps
%                         none and no later pass reads one for this class).
%                         Written by ndi.database.fun.openMINDSobj2ndi_document.
%                         Round trips: testRawV1RoundTripOpenminds.
%     openminds_stimulus  superclasses `base` + `epochid` + `openminds`, no
%                         `app` block, no superclass migrator. A passthrough
%                         for NDI's second pass, which reads it from the v1
%                         input (ndi.migrate.internal.sliceTetanus) and by
%                         class name from the migrated set; it validates
%                         against the same V_eta class. The invented
%                         `stimulus_id` edge still quarantines first. What the
%                         passthrough does not keep in its template carries it
%                         (private/jRawAccount, carry-100). Written by
%                         +setup/+NDIMaker/stimulusDocMaker.m and
%                         +setup/+stimulus/+vhlab/add_stimulus_approach.m.
%                         Round trips: testRawV1RoundTripOpenminds.
%     NOT LISTED: every other v1 class, which v1_to_v2 still hands to
%                         universalRenames: every +migrators_j migrator is
%                         listed above, so these are the classes with no
%                         +migrators_j migrator (the +migrators identity
%                         fallback), and a body that names a class by a
%                         spelling no writer uses (a snake_case
%                         `ontology_table_row`, `image_stack`, ...).
%                         universalRenames cannot be deleted while any of them
%                         does ([migrators read raw v1]).
%
%   See also did2.convert.v1_to_v2, did2.convert.roundtrip.check.

names = {'subject', 'subject_group', 'treatment', 'treatment_drug', ...
    'treatment_transfer', 'virus_injection', 'element', 'element_epoch', ...
    'tuningcurve_calc', 'contrasttuning_calc', 'oridirtuning_calc', ...
    'spatial_frequency_tuning_calc', 'temporal_frequency_tuning_calc', ...
    'contrastsensitivity_calc', 'stimulus_response_scalar', ...
    'stimulus_response_scalar_parameters_basic', ...
    'daqreader_mfdaq_epochdata_ingested', ...
    'epochfiles_ingested', ...
    'syncrule_mapping', ...
    'daqmetadatareader_epochdata_ingested', ...
    'imageStack', ...
    'daqsystem', ...
    'filenavigator', ...
    'daqreader', ...
    'daqreader_ndr', ...
    'daqmetadatareader', ...
    'syncrule', ...
    'syncgraph', ...
    'probe_location', ...
    'neuron_extracellular', ...
    'jrclust_clusters', ...
    'hartley_calc', ...
    'speedtuning_calc', ...
    'stimulus_bath', ...
    'position_metadata', ...
    'distance_metadata', ...
    'probe_geometry', ...
    'site2channelmap', ...
    'electrode_offset_voltage', ...
    'spike_extraction_parameters', ...
    'spike_extraction_parameters_modification', ...
    'sorting_parameters', ...
    'kilosort_clusters', ...
    'kiasort_clusters', ...
    'SpikeInterfaceSortingOutputs', ...
    'daqreader_epochdata_ingested', ...
    'daqreader_image_epochdata_ingested', ...
    'vmneuralresponseresiduals', ...
    'vmspikesummary', ...
    'cellTypeLabels', ...
    'geneExpression', ...
    'geneList', ...
    'geneListMapping', ...
    'spatialGeneExpressionCells', ...
    'spatialGeneExpressionPyramid', ...
    'spatialGeneExpressionTiles', ...
    'measurement', ...
    'subjectmeasurement', ...
    'stimulus_parameter', ...
    'stimulus_tuningcurve', ...
    'orientation_direction_tuning', ...
    'contrast_tuning', ...
    'spatial_frequency_tuning', ...
    'temporal_frequency_tuning', ...
    'speed_tuning', ...
    'demoNDI', ...
    'demoNDIMock', ...
    'binaryseries_parameters', ...
    'oneepoch', ...
    'ontologyImage', ...
    'session', ...
    'session_in_a_dataset', ...
    'dataset_remote', ...
    'metadata_editor', ...
    'stimulus_presentation', ...
    'ontologyLabel', ...
    'pyraview', ...
    'fileReference', ...
    'lightsheetZarrPyramid', ...
    'lightsheetZarrLevel', ...
    'simple_calc', ...
    'spikewaves', ...
    'spike_clusters', ...
    'binnedspikeratevm', ...
    'control_stimulus_ids', ...
    'image', ...
    'dataset_session_info', ...
    'fitcurve', ...
    'vmspikefit', ...
    'vmspikefilteringparameters', ...
    'ontologyTableRow', ...
    'openminds', ...
    'openminds_subject', ...
    'openminds_element', ...
    'openminds_stimulus', ...
    };

% v1 name                     migrator (+migrators_j); TEMPORARY, see above
TABLE = { ...
    'contrasttuning_calc',      'contrast_tuning_calc'; ...
    'contrastsensitivity_calc', 'contrast_sensitivity_calc'; ...
    'imageStack',               'image_stack'; ...
    'speedtuning_calc',         'speed_tuning_calc'; ...
    'ontologyLabel',            'ontology_label'; ...
    'SpikeInterfaceSortingOutputs', 'spike_interface_sorting_outputs'; ...
    'cellTypeLabels',           'cell_type_labels'; ...
    'geneExpression',           'gene_expression'; ...
    'geneList',                 'gene_list'; ...
    'geneListMapping',          'gene_list_mapping'; ...
    'spatialGeneExpressionCells',   'spatial_gene_expression_cells'; ...
    'spatialGeneExpressionPyramid', 'spatial_gene_expression_pyramid'; ...
    'spatialGeneExpressionTiles',   'spatial_gene_expression_tiles'; ...
    'demoNDI',                  'demo_ndi'; ...
    'demoNDIMock',              'demo_ndi_mock'; ...
    'ontologyImage',            'ontology_image'; ...
    'fileReference',            'file_reference'; ...
    'lightsheetZarrPyramid',    'lightsheet_zarr_pyramid'; ...
    'lightsheetZarrLevel',      'lightsheet_zarr_level'; ...
    'ontologyTableRow',         'ontology_table_row'};

if nargin >= 1
    names = migratorOf(char(v1Name), TABLE);
    return;
end
migrators = cellfun(@(n) migratorOf(n, TABLE), names, 'UniformOutput', false);
end

function m = migratorOf(v1Name, table)
hit = strcmp(table(:, 1), v1Name);
if any(hit)
    m = table{find(hit, 1), 2};
else
    m = v1Name;
end
end
