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
%   contrast_sensitivity_calc.m; NDI writes `imageStack` and `ontologyLabel`,
%   and the migrators are +migrators_j/image_stack.m and ontology_label.m: the
%   names universalRenames gives those classes. THIS TABLE GOES when
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
%                         +migrators/element.m is never run for it (a class
%                         with a +migrators_j migrator skips it). Written by
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
%                         is called by the leaf on the raw block, and stays for
%                         the v1 `image` (not switched), which still runs
%                         renamed. Written by +setup/+conv/+haley/doImport.m
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
%                         stays for ontology_image (not switched). The old
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
%     ontologyLabel       superclass `base` only, no `app` block, no superclass
%                         migrator. Pass 1 hands it to NDI's second pass
%                         unchanged (or carries it, carry-064, with a carried
%                         stack); the raw passthrough keeps the v1 class name,
%                         block `ontologyLabel` and field `ontologyNode`. Every
%                         reader of a label by its class name accepts both
%                         spellings first (siblings first, did-schema
%                         CLAUDE.md): did2.convert.isOntologyLabelClass
%                         (did2.convert.foldGenericFiles) and NDI-matlab's
%                         ndi.migrate.internal.isOntologyLabelClass (#1076).
%                         Written by +setup/+conv/+haley/doImport.m and
%                         +babu/import.m. Round trips: testRawV1RoundTripImage.
%     NOT LISTED, and why:
%       simple_calc       a pass-1 passthrough for which no corpus holds a
%                         document; its raw passthrough (`app.name`, a
%                         `calculator` block) would meet the V_eta
%                         `simple_calc` class (`app_name`) under its own name
%                         and quarantine, where the renamed path's body
%                         validates. It stays on the renamed path until the
%                         open question on it (model it or retire it,
%                         V_eta_ground_truth_plan.md) is answered; its old
%                         +migrators wrapper is deleted (never reached).
%       image             no NDI writer at the locked main constructs it and no
%                         corpus holds one; its subject-less passthrough has no
%                         register row, and as raw v1 it would meet the
%                         renamed-shape `image` tombstone under its own name
%                         and quarantine. It stays on the renamed path.
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
    'ontologyLabel', ...
    };

% v1 name                     migrator (+migrators_j); TEMPORARY, see above
TABLE = { ...
    'contrasttuning_calc',      'contrast_tuning_calc'; ...
    'contrastsensitivity_calc', 'contrast_sensitivity_calc'; ...
    'imageStack',               'image_stack'; ...
    'speedtuning_calc',         'speed_tuning_calc'; ...
    'ontologyLabel',            'ontology_label'};

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
