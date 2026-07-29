function tests = testFixtureCorpus
%TESTFIXTURECORPUS Fast validating fixture corpus -- the edit-loop counterpart to
%   the ~2-hour full corpus test (did2.unittest.testCorpus*). It runs a SMALL set
%   of self-contained v1 fixtures through the FULL V_eta migration pipeline WITH
%   schema validation ON (Validate=true), then asserts the two corpus gates:
%   0 quarantine and 0 orphan depends_on edges. It catches the errors the full
%   corpus catches -- wrong shapes, reviving a dead class, dangling references,
%   sample_time-style inconsistencies -- in seconds instead of hours.
%
%   Requires the assembled V_eta schema on DID_SCHEMA_PATH (the CI workflow
%   test-fixtures.yml assembles it by copying did-schema V_eta stable+draft, same
%   as the full corpus workflow). Skips validation gracefully if absent.
%
%   Fixtures are SELF-CONTAINED (every referenced id is minted in the same batch),
%   so a clean run is 0 orphans by construction. Add a fixture per migrator here as
%   coverage grows -- keep them self-contained (include any subject/element a doc
%   references, or use a no-dependency variant).
%
%   Run with:  results = runtests('did2.unittest.testFixtureCorpus');

tests = functiontests(localfunctions);
end

function fixtures = v1Fixtures()
% A self-contained set of representative v1 documents -- one (or a small batch)
% per migrator, so a change to any covered migrator is caught by this fast gate
% instead of only the ~2h corpus. SELF-CONTAINED: every id a doc depends_on is
% minted in the same batch (base.session_id is a plain field, NOT an orphan-checked
% depends_on edge, so a session doc is not required). Shapes are lifted from the
% migrator unit tests (did2.unittest.testMigratorsJ), which are known-good migrator
% INPUTS -- but those run Validate=false, so this corpus is the first to put them
% through full V_eta schema validation + the 0-quarantine / 0-orphan gates.
fixtures = [ ...
    { subjectGroupDoc(), metadataEditorDoc() }, ...
    manipulationBatch(), ...
    observationBatch(), ...
    zooBatch(), ...
    gapBatch(), ...
    ];
end

% ----- batch 4: the new-on-main NDI app outputs (ex-ledger gaps). kilosort_clusters
% and kiasort_clusters now DECOMPOSE (D-C, #9): each Kilosort/Kiasort run ->
% count_observation (id-preserved handle) + opaque_body (the external sorter output
% directory) + session anchor. ensemble stays PASSTHROUGH (class retained,
% in_progress) pending its grain decision. Each rides on a minted recording subject;
% element_epoch_id is left empty. Confirms both the decompositions and the passthrough
% validate (0 quarantine / 0 orphan).
function batch = gapBatch()
batch = [ fx_ensemble(), fx_kilosort_clusters(), fx_kiasort_clusters() ];
end

function batch = fx_kilosort_clusters()
sub = subjDoc('ks_sub', 'recSubKS');
d = struct();
d.document_class = struct('class_name','kilosort_clusters','class_version','1.0.0', ...
    'superclasses', [ struct('class_name','base','class_version','1.0.0'), ...
                      struct('class_name','app','class_version','1.0.0') ]);
d.depends_on = struct('name','element_id','value','ks_sub');
d.base = struct('id','ks_01','session_id','sess_09','name','ks','datestamp','2024-06-01T12:00:00.000Z');
d.app = struct('name','ndi.app.kilosort','version','1.0');
d.kilosort_clusters = struct('kilosort_directory','ks_out', ...
    'curated_output_MD5_checksum','d41d8cd98f00b204e9800998ecf8427e');
batch = { sub, d };
end

function batch = fx_kiasort_clusters()
sub = subjDoc('ka_sub', 'recSubKA');
d = struct();
d.document_class = struct('class_name','kiasort_clusters','class_version','1.0.0', ...
    'superclasses', [ struct('class_name','base','class_version','1.0.0'), ...
                      struct('class_name','app','class_version','1.0.0') ]);
d.depends_on = struct('name','element_id','value','ka_sub');
d.base = struct('id','ka_01','session_id','sess_09','name','ka','datestamp','2024-06-01T12:00:00.000Z');
d.app = struct('name','ndi.app.kiasort','version','1.0');
d.kiasort_clusters = struct('kiasort_directory','ka_out', ...
    'curated_output_MD5_checksum','d41d8cd98f00b204e9800998ecf8427e');
batch = { sub, d };
end

function batch = fx_ensemble()
sub = subjDoc('en_sub', 'recSubEN');
d = struct();
d.document_class = struct('class_name','ensemble','class_version','1.0.0', ...
    'superclasses', [ struct('class_name','base','class_version','1.0.0'), ...
                      struct('class_name','epochid','class_version','1.0.0'), ...
                      struct('class_name','app','class_version','1.0.0') ]);
d.depends_on = [ struct('name','element_id','value','en_sub'), ...
                 struct('name','element_epoch_id','value','') ];
d.base = struct('id','en_01','session_id','sess_09','name','ens','datestamp','2024-06-01T12:00:00.000Z');
d.epochid = struct('epochid','t00001');
d.app = struct('name','ndi.app.ensemble','version','1.0');
d.ensemble = struct('ensemble_name','ens1','value_type','rate', ...
    'value_description','firing rate','num_neurons',12,'clocktype','dev_local_time');
batch = { sub, d };
end

% ----- batch 3: the observation/analysis/entity/rename zoo. Shapes harvested
% verbatim from did2.unittest.testMigratorsJ (spot-checked against the source),
% each wrapped self-contained (a subjDoc minted for every depends_on id). Covers
% the spike/waveform body-backed folds, the inline quantity observations, the
% tuning decompositions, the dataset entities, and the in-place renames.
function batch = zooBatch()
batch = [ ...
    fx_spikewaves(), fx_spike_clusters(), fx_jrclust_clusters(), ...
    fx_binnedspikeratevm(), fx_pyraview(), fx_neuron_extracellular(), ...
    fx_vmspikefit(), fx_vmspikesummary(), fx_vmneuralresponseresiduals(), ...
    fx_fitcurve(), fx_simple_calc(), fx_contrast_tuning(), ...
    fx_orientation_direction_tuning(), fx_oridirtuning_calc(), ...
    fx_contrast_sensitivity_calc(), fx_speed_tuning(), ...
    fx_tuningcurve_calc(), fx_stimulus_tuningcurve_raw(), ...
    fx_spatial_frequency_tuning(), fx_probe_geometry(), fx_position_metadata(), ...
    fx_distance_metadata(), fx_electrode_offset_voltage(), fx_site2channelmap(), ...
    fx_spike_interface_sorting_outputs(), fx_dataset_remote(), ...
    fx_dataset_session_info(), fx_session_in_a_dataset(), fx_element_epoch(), ...
    fx_ontology_image(), fx_ontology_image_ndi(), ...
    fx_openminds_element(), fx_openminds_stimulus() ];
end

% ----- batch 2: term_manipulation+relation, body-backed sampled_body,
% term_assertion. Each rides on its own minted subject(s). Covers:
% treatment_transfer->term_manipulation (+ derived_from relation),
% virus_injection->dose_manipulation (+ site), ontology_label->term_observation,
% image_stack->image_observation + sampled_body, openminds_subject->term_assertion.
function batch = observationBatch()
recipient = subjDoc('om_rec_1', 'recipientR');
donor     = subjDoc('om_don_1', 'donorD');
animalV   = subjDoc('om_animal_v', 'animalV');
elemO     = subjDoc('om_elem_o', 'elementO');
animalI   = subjDoc('om_animal_i', 'animalI');
animalOm  = subjDoc('om_animal_s', 'animalS');

tt = struct();
tt.document_class = struct('class_name', 'treatment_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
tt.depends_on = [ ...
    struct('name', 'recipient_id', 'document_id', 'om_rec_1'), ...
    struct('name', 'donor_id',     'document_id', 'om_don_1')];
tt.base = struct('id', 'om_tt_01', 'session_id', 'sess_09', ...
    'name', 'graft', 'datestamp', '2024-06-01T12:00:00.000Z');
tt.treatment_transfer = struct('entity_ontologyNode', 'uberon:0000922', ...
    'entity_name', 'embryonic tissue', 'method_name', 'transplantation');

vi = struct();
vi.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
vi.depends_on = struct('name', {'subject_id'}, 'value', {'om_animal_v'});
vi.base = struct('id', 'om_vi_01', 'session_id', 'sess_09', ...
    'name', 'vi', 'datestamp', '2024-06-01T12:00:00.000Z');
vi.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'AAV-ChR2', 'dilution', 1000, ...
    'virusLocation_OntologyName', 'uberon:0002436', 'virusLocation_name', 'V1');

ol = struct();
ol.document_class = struct('class_name', 'ontology_label', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
ol.depends_on = struct('name', {'element_id'}, 'value', {'om_elem_o'});
ol.base = struct('id', 'om_ol_01', 'session_id', 'sess_09', ...
    'name', 'ol', 'datestamp', '2024-06-01T12:00:00.000Z');
ol.ontology_label = struct('ontology_name', 'Allen CCF v3', 'label_id', 12345, ...
    'label', 'primary visual cortex');

is = struct();
is.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
is.depends_on = struct('name', {'subject_id'}, 'value', {'om_animal_i'});
is.base = struct('id', 'om_is_01', 'session_id', 'sess_09', ...
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
is.image_stack = struct('format_ontology', 'edam:3382', ...
    'label', 'a two-photon stack', 'format', 'tiff');
is.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YXCZT', 'dimension_size', [512 512 1 1 10], ...
    'dimension_scale', [0.5 0.5 1 1 1], 'clocktype', 'dev_local_time', 'timestamp', 0);

om = struct();
om.document_class = struct('class_name', 'openminds_subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
om.depends_on = struct('name', {'subject_id'}, 'value', {'om_animal_s'});
om.base = struct('id', 'om_om_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
om.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239', 'synonym', 'C. elegans'));

batch = { recipient, donor, animalV, elemO, animalI, animalOm, tt, vi, ol, is, om };
end

% ----- shared minimal v1 subject (the in-batch anchor for observations) -----
function s = subjDoc(id, name)
s = struct();
s.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
s.depends_on = struct('name', {}, 'value', {});
s.base = struct('id', id, 'session_id', 'sess_09', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
s.subject = struct('local_identifier', name, 'description', '');
end

% ----- manipulation / observation proof batch (one shared animal + probe) -----
% Covers: treatment->temperature_manipulation, treatment_drug->dose_manipulation
% (+ site term_observation), probe_location->term_observation, element->subject
% (+ observes relation) -- exercising the manipulation leaf, dose, term_observation,
% session anchor, derived subject, and directed_relation patterns. Every doc rides
% on subjDoc('animal_1') or subjDoc('probe_1'), both minted here.
function batch = manipulationBatch()
animal = subjDoc('animal_1', 'animalA');
probe  = subjDoc('probe_1', 'probeA');

trt = struct();
trt.document_class = struct('class_name', 'treatment', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
trt.depends_on = struct('name', {'subject_id'}, 'value', {'animal_1'});
trt.base = struct('id', 'trt_01', 'session_id', 'sess_09', ...
    'name', 'trt', 'datestamp', '2024-06-01T12:00:00.000Z');
trt.treatment = struct('ontology_name', '', 'name', 'cold exposure', 'numeric_value', 4.0);

drug = struct();
drug.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
drug.depends_on = struct('name', {'subject_id'}, 'value', {'animal_1'});
drug.base = struct('id', 'drug_01', 'session_id', 'sess_09', ...
    'name', 'td', 'datestamp', '2024-06-01T12:00:00.000Z');
drug.treatment_drug = struct('mixture_table', 'chebi:28001,haloperidol,5', ...
    'location_ontologyNode', 'uberon:0002436', 'location_name', 'primary visual cortex');

ploc = struct();
ploc.document_class = struct('class_name', 'probe_location', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
ploc.depends_on = struct('name', {'probe_id'}, 'value', {'probe_1'});
ploc.base = struct('id', 'ploc_01', 'session_id', 'sess_09', ...
    'name', 'pl', 'datestamp', '2024-06-01T12:00:00.000Z');
ploc.probe_location = struct('ontology_name', 'uberon:0002436', 'name', 'primary visual cortex');

elem = struct();
elem.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
elem.depends_on = struct('name', {'subject_id'}, 'value', {'animal_1'});
elem.base = struct('id', 'elem_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
elem.element = struct('ndi_element_class', 'ndi.probe.timeseries', 'name', 'probeA', ...
    'reference', '1', 'type', 'n-trode', 'direct', 1);

batch = { animal, probe, trt, drug, ploc, elem };
end

function testFixturesMigrateCleanUnderValidation(testCase)
if isempty(getenv('DID_SCHEMA_PATH'))
    assumeFail(testCase, ...
        'DID_SCHEMA_PATH not set; run under test-fixtures.yml (assembled V_eta schema).');
end

bodies = v1Fixtures();

% the full V_eta corpus pipeline, validation ON
result = did2.convert.v1_to_v2(bodies, 'Validate', true, 'TargetVersion', 'V_eta');
result = did2.convert.resolveDeferredBaths(result, ...
    'Validate', true, 'TargetVersion', 'V_eta');
result = did2.convert.resolveDatasetEntities(result, ...
    'Validate', true, 'TargetVersion', 'V_eta');

% GATE 1: nothing quarantined
verifyEmpty(testCase, result.quarantine, ...
    'fixture(s) quarantined under schema validation');
verifyNotEmpty(testCase, result.migrated);

% GATE 2: no dangling references (self-contained fixtures -> 0 by construction)
refRep = did2.validate.references(result.migrated);
verifyEqual(testCase, refRep.orphan_count, 0, ...
    sprintf('%d orphan depends_on edge(s) of %d examined', ...
        refRep.orphan_count, refRep.edges_examined));
end

% ===================== fixtures (self-contained) =========================

function v1 = subjectGroupDoc()
% a group with NO members -> a bare subject (1 -> 1, no external references)
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'grp_01', 'session_id', 'sess_09', ...
    'name', 'cohortA', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortA', 'description', 'the treated cohort');
end

function v1 = metadataEditorDoc()
% the NDIMetaDataEditorApp metadata_structure -> dataset + person/org/funding/
% publication/web_resource entities + directed_relations. 1 -> N, ALL endpoints
% minted in-batch, so it is self-contained (no orphans).
v1 = struct();
v1.document_class = struct('class_name', 'metadata_editor', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'me_01', 'session_id', 'sess_10', ...
    'name', 'ds_meta', 'datestamp', '2024-06-01T12:00:00.000Z');
ms = struct();
ms.DatasetFullName = 'The Big Worm Dataset';
ms.DatasetShortName = 'BigWorm';
ms.VersionIdentifier = '1.0.0';
ms.Description = 'A dataset of worms.';
ms.License = 'CC-BY-4.0';
ms.ReleaseDate = '2024-01-15';
a1 = struct('givenName', 'Ada', 'familyName', 'Lovelace', ...
    'digitalIdentifier', struct('identifier', '0000-0001-2345-6789'), ...
    'contactInformation', struct('email', 'ada@example.org'), ...
    'affiliation', struct('memberOf', struct('fullName', 'Analytical Society')));
ms.Author = a1;
ms.Funding = struct('funder', 'NIH', 'awardTitle', 'BRAIN Initiative', ...
    'awardNumber', 'R01-12345');
ms.RelatedPublication = struct('Publication', 'On Worms', 'DOI', '10.1/worm');
ms.FullDocumentation = 'https://example.org/docs';
v1.metadata_editor = struct('metadata_structure', ms);
end

% ===================== batch 3 zoo fixtures (harvested) ==================

% ---- spikewaves (element_id + spike_extraction_parameters_id) --------------
function batch = fx_spikewaves()
sub  = subjDoc('sw_sub', 'animalSW');
sep  = subjDoc('sw_sep', 'sepSW');
d = struct();
d.document_class = struct('class_name','spikewaves','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','sw_sub'), ...
                 struct('name','spike_extraction_parameters_id','value','sw_sep') ];
d.base = struct('id','sw_01','session_id','sess_09','name','sw','datestamp','2024-06-01T12:00:00.000Z');
d.spikewaves = struct('extraction_name','thresh_5sd', ...
    'num_spikes',120,'samples_per_spike',32,'sample_rate',30000);
d.files = struct('file_list', {{'spikewaves.vsw','spiketimes.bin'}});
batch = { sub, sep, d };
end

% ---- spike_clusters (element_id + sorting_parameters_id) -------------------
function batch = fx_spike_clusters()
sub = subjDoc('sc_sub', 'animalSC');
sp  = subjDoc('sc_sp',  'sortparamsSC');
d = struct();
d.document_class = struct('class_name','spike_clusters','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','sc_sub'), ...
                 struct('name','sorting_parameters_id','value','sc_sp') ];
d.base = struct('id','sc_01','session_id','sess_09','name','sc','datestamp','2024-06-01T12:00:00.000Z');
d.spike_clusters = struct('num_clusters',5,'num_spikes',400);
d.files = struct('file_list', {{'clusters.bin'}});
batch = { sub, sp, d };
end

% ---- jrclust_clusters (superclasses base + app) ----------------------------
function batch = fx_jrclust_clusters()
sub = subjDoc('jc_sub', 'animalJC');
d = struct();
d.document_class = struct('class_name','jrclust_clusters','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
d.depends_on = struct('name','element_id','value','jc_sub');
d.base = struct('id','jc_01','session_id','sess_09','name','jc','datestamp','2024-06-01T12:00:00.000Z');
d.jrclust_clusters = struct('res_mat_md5_checksum','d41d8cd98f00b204e9800998ecf8427e');
d.files = struct('file_list', {{'clusters.mat'}});
batch = { sub, d };
end

% ---- binnedspikeratevm -----------------------------------------------------
function batch = fx_binnedspikeratevm()
sub = subjDoc('br_sub', 'animalBR');
d = struct();
d.document_class = struct('class_name','binnedspikeratevm','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','br_sub');
d.base = struct('id','br_01','session_id','sess_09','name','br','datestamp','2024-06-01T12:00:00.000Z');
d.binnedspikeratevm = struct('bin_size',0.05,'num_bins',600);
d.files = struct('file_list', {{'rate.bin'}});
batch = { sub, d };
end

% ---- pyraview (superclasses filter + base + epochid) -----------------------
function batch = fx_pyraview()
sub = subjDoc('pv_sub', 'animalPV');
d = struct();
d.document_class = struct('class_name','pyraview','class_version','1.0.0', ...
    'superclasses', [ struct('class_name','filter','class_version','1.0.0'), ...
                      struct('class_name','base','class_version','1.0.0'), ...
                      struct('class_name','epochid','class_version','1.0.0') ]);
d.depends_on = struct('name','element_id','value','pv_sub');
d.base = struct('id','pv_01','session_id','sess_09','name','pyr','datestamp','2024-06-01T12:00:00.000Z');
d.pyraview = struct('label','lfp','native_rate',1000, ...
    'native_start_time',0,'channels',4,'data_type','int16', ...
    'decimation_sampling_rates',[1000 500]);
d.files = struct('file_list', {{'level1.bin','level2.bin'}});
batch = { sub, d };
end

% ---- neuron_extracellular --------------------------------------------------
function batch = fx_neuron_extracellular()
sub = subjDoc('ne_sub', 'recSubNE');
d = struct();
d.document_class = struct('class_name','neuron_extracellular','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','ne_sub');
d.base = struct('id','ne_01','session_id','sess_09','name','ne','datestamp','2024-06-01T12:00:00.000Z');
d.neuron_extracellular = struct('cluster_index',7,'quality_number',3,'number_of_channels',4);
batch = { sub, d };
end

% ---- vmspikefit ------------------------------------------------------------
function batch = fx_vmspikefit()
sub = subjDoc('vf_sub', 'animalVF');
d = struct();
d.document_class = struct('class_name','vmspikefit','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','vf_sub');
d.base = struct('id','vf_01','session_id','sess_09','name','vf','datestamp','2024-06-01T12:00:00.000Z');
d.vmspikefit = struct('fit_function','exp2','r_squared',0.88);
batch = { sub, d };
end

% ---- vmspikesummary --------------------------------------------------------
function batch = fx_vmspikesummary()
sub = subjDoc('vs_sub', 'animalVS');
d = struct();
d.document_class = struct('class_name','vmspikesummary','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','vs_sub');
d.base = struct('id','vs_01','session_id','sess_09','name','vs','datestamp','2024-06-01T12:00:00.000Z');
d.vmspikesummary = struct('mean_vm',-62.5,'mean_firing_rate',8.3, ...
    'num_spikes',249,'recording_duration',30.0);
batch = { sub, d };
end

% ---- vmneuralresponseresiduals (element_id + vmspikefit_id) ----------------
function batch = fx_vmneuralresponseresiduals()
sub = subjDoc('rr_sub', 'animalRR');
vf  = subjDoc('rr_vf',  'vmspikefitRR');
d = struct();
d.document_class = struct('class_name','vmneuralresponseresiduals','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','rr_sub'), ...
                 struct('name','vmspikefit_id','value','rr_vf') ];
d.base = struct('id','rr_01','session_id','sess_09','name','rr','datestamp','2024-06-01T12:00:00.000Z');
d.vmneuralresponseresiduals = struct('mean_residual',1.7);
batch = { sub, vf, d };
end

% ---- fitcurve --------------------------------------------------------------
function batch = fx_fitcurve()
sub = subjDoc('fc_sub', 'animalFC');
d = struct();
d.document_class = struct('class_name','fitcurve','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','fc_sub');
d.base = struct('id','fc_01','session_id','sess_09','name','fc','datestamp','2024-06-01T12:00:00.000Z');
d.fitcurve = struct('fit_function','gaussian','goodness_of_fit',0.94);
batch = { sub, d };
end

% ---- simple_calc -----------------------------------------------------------
% Built from the NDI template + writer (+ndi/+calc/+example/simple.m): the block
% is {input_parameters, answer}, the only edge is document_id pointing at the
% INPUT document, and the parent is app. The previous fixture used
% result_value/result_units/element_id/calculator -- a shape from our own V_alpha
% snapshot that no real document has, which is why the migrator read nothing and
% the test still passed.
%
% simple_calc has no subject-bearing edge, so it DEFERS to the NDI second pass
% and passes through unchanged. This fixture's job is to prove the passthrough
% VALIDATES against the reshaped tombstone under Validate=true.
function batch = fx_simple_calc()
d = struct();
d.document_class = struct('class_name','simple_calc','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base','app'}, 'class_version', {'1.0.0','1.0.0'}));
d.depends_on = struct('name','document_id','value','');
d.base = struct('id','smc_01','session_id','sess_09','name','sm','datestamp','2024-06-01T12:00:00.000Z');
d.app = struct('name','ndi.calc.example.simple','version','1.0');
d.simple_calc = struct('input_parameters', struct('answer', 5), 'answer', 5);
batch = { d };
end

% ---- contrast_tuning (element_id + stimulus_tuningcurve_id) -----------------
function batch = fx_contrast_tuning()
sub = subjDoc('ct_sub', 'animalCT');
tc  = subjDoc('ct_tc',  'tuningcurveCT');
d = struct();
d.document_class = struct('class_name','contrast_tuning','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','ct_sub'), ...
                 struct('name','stimulus_tuningcurve_id','value','ct_tc') ];
d.base = struct('id','ct_01','session_id','sess_09','name','ct','datestamp','2024-06-01T12:00:00.000Z');
d.contrast_tuning = struct( ...
    'properties', struct('response_units','spikes/s','response_type','mean'), ...
    'tuning_curve', struct('contrast',[0 0.25 0.5 1],'mean',[2 5 9 12]));
batch = { sub, tc, d };
end

% ---- orientation_direction_tuning (element_id + stimulus_tuningcurve_id) ----
function batch = fx_orientation_direction_tuning()
sub = subjDoc('od_sub', 'animalOD');
tc  = subjDoc('od_tc',  'tuningcurveOD');
d = struct();
d.document_class = struct('class_name','orientation_direction_tuning','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','od_sub'), ...
                 struct('name','stimulus_tuningcurve_id','value','od_tc') ];
d.base = struct('id','od_01','session_id','sess_09','name','od','datestamp','2024-06-01T12:00:00.000Z');
d.orientation_direction_tuning = struct( ...
    'properties', struct('response_units','spikes/s'), ...
    'tuning_curve', struct('direction',[0 90 180 270],'mean',[10 2 9 3]));
batch = { sub, tc, d };
end

% ---- oridirtuning_calc (the CALCULATOR OUTPUT doc, un-deferred) -------------
% The ndi.calc.vis.oridir output document: superclasses base + the result composite
% + tuning_fit; its own block carries input_parameters; an app block records the
% program+version; depends_on the recording element + the raw stimulus_tuningcurve.
% Folds 1->1 (id-preserved) to orientation_direction_tuning_calculation, proving the
% calculator un-defers under schema validation with 0 orphan (subject + curve minted).
function batch = fx_oridirtuning_calc()
sub = subjDoc('ocx_sub', 'neuronOCX');
tc  = subjDoc('ocx_tc',  'tuningcurveOCX');   % the input curve (existence anchor)
d = struct();
d.document_class = struct('class_name','oridirtuning_calc','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base';'orientation_direction_tuning';'tuning_fit'}, ...
                           'class_version', {'1.0.0';'1.0.0';'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','ocx_sub'), ...
                 struct('name','stimulus_tuningcurve_id','value','ocx_tc') ];
d.base = struct('id','ocx_1','session_id','sess_09','name','oc','datestamp','2024-06-01T12:00:00.000Z');
d.app = struct('name','ndi.calc.vis.oridir','version','1.2','url','https://github.com/VH-Lab/NDI-matlab','os','Linux','os_version','22.04','interpreter','MATLAB','interpreter_version','24.2');
d.oridirtuning_calc = struct('input_parameters', struct('independent_variable','direction'));
d.orientation_direction_tuning = struct( ...
    'properties', struct('response_units','spikes/s'), ...
    'tuning_curve', struct('direction',[0 90 180 270],'mean',[10 2 9 3]), ...
    'vector', struct('orientation_preference',47.5));
batch = { sub, tc, d };
end

% ---- contrast_sensitivity_calc (the AGGREGATE calculator output, un-deferred) -
% base + calculator, a flat bag of sensitivity/gain matrices on its own block +
% inherited input_parameters; HAS element_id so it folds single-doc to
% contrast_sensitivity_calculation (a newly-authored composite). Proves the flat-bag
% calc un-defers under schema validation (subject + raw responses minted; 0 orphan).
function batch = fx_contrast_sensitivity_calc()
sub  = subjDoc('csx_sub', 'neuronCSX');
resp = subjDoc('csx_resp', 'responseCSX');   % raw responses (derived_from anchor)
d = struct();
d.document_class = struct('class_name','contrast_sensitivity_calc','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base';'calculator'}, 'class_version', {'1.0.0';'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','csx_sub'), ...
                 struct('name','stimulus_response_scalar_id','value','csx_resp') ];
d.base = struct('id','csx_1','session_id','sess_09','name','cs','datestamp','2024-06-01T12:00:00.000Z');
d.app = struct('name','ndi.calc.vis.contrast_sensitivity','version','1.0','url','https://github.com/VH-Lab/NDI-matlab','os','Linux','os_version','22.04','interpreter','MATLAB','interpreter_version','24.2');
d.contrast_sensitivity_calc = struct('spatial_frequencies',[0.5 1 2 4], ...
    'sensitivity_rb',[10 20 15 5], 'response_type','mean', ...
    'input_parameters', struct('threshold',1));
batch = { sub, resp, d };
end

% ---- tuningcurve_calc (the CALCULATOR OUTPUT doc, un-deferred) --------------
% The ndi.calc.stimulus.tuningcurve output: IS-A stimulus_tuningcurve (v1 superclass),
% so it carries the inherited element_id (populated by the writer from the consumed
% stimulus_response_scalar). The tuning-curve result sits on the inherited
% stimulus_tuningcurve block; the calc block carries input_parameters; an app block
% records the program+version. Folds 1->1 (id-preserved) to
% stimulus_tuningcurve_calculation, proving the last vision calculator un-defers under
% schema validation with 0 orphan (subject via element_id; derived_from the responses).
function batch = fx_tuningcurve_calc()
sub  = subjDoc('tcx_sub',  'neuronTCX');
resp = subjDoc('tcx_resp', 'responseTCX');   % raw responses (derived_from anchor)
d = struct();
d.document_class = struct('class_name','tuningcurve_calc','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base';'stimulus_tuningcurve'}, ...
                           'class_version', {'1.0.0';'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','tcx_sub'), ...
                 struct('name','stimulus_response_scalar_id','value','tcx_resp') ];
d.base = struct('id','tcx_1','session_id','sess_09','name','tc','datestamp','2024-06-01T12:00:00.000Z');
d.app = struct('name','ndi.calc.stimulus.tuningcurve','version','1.0','url','https://github.com/VH-Lab/NDI-matlab','os','Linux','os_version','22.04','interpreter','MATLAB','interpreter_version','24.2');
d.tuningcurve_calc = struct('log','ok', ...
    'input_parameters', struct('best_algorithm','empirical_maximum'));
d.stimulus_tuningcurve = struct( ...
    'independent_variable_label','contrast', ...
    'independent_variable_value',[0 0.25 0.5 1], ...
    'response_mean',[1 4 8 11], 'response_units','Spikes/s');
batch = { sub, resp, d };
end

% ---- stimulus_tuningcurve (raw pre-calculator app output, un-deferred) ------
% A raw ndi.app.stimulus.tuning_response tuning curve: base + a self-named result
% block, populated element_id, no calc input_parameters/app. Folds to the SAME leaf as
% tuningcurve_calc, proving downstream stimulus_tuningcurve_id refs resolve to either.
function batch = fx_stimulus_tuningcurve_raw()
sub  = subjDoc('rtx_sub',  'neuronRTX');
resp = subjDoc('rtx_resp', 'responseRTX');
d = struct();
d.document_class = struct('class_name','stimulus_tuningcurve','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','rtx_sub'), ...
                 struct('name','stimulus_response_scalar_id','value','rtx_resp') ];
d.base = struct('id','rtx_1','session_id','sess_09','name','rawtc','datestamp','2024-06-01T12:00:00.000Z');
d.stimulus_tuningcurve = struct( ...
    'independent_variable_label','direction', ...
    'independent_variable_value',[0 90 180 270], ...
    'response_mean',[10 2 9 3], 'response_units','Spikes/s');
batch = { sub, resp, d };
end

% ---- speed_tuning (element_id only) ----------------------------------------
function batch = fx_speed_tuning()
sub = subjDoc('sp_sub', 'animalSP');
d = struct();
d.document_class = struct('class_name','speed_tuning','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','sp_sub');
d.base = struct('id','sp_01','session_id','sess_09','name','sp','datestamp','2024-06-01T12:00:00.000Z');
d.speed_tuning = struct( ...
    'properties', struct('response_units','spikes/s'), ...
    'tuning_curve', struct('spatial_frequency',[0.5 0.5 1], ...
        'temporal_frequency',[2 4 4],'mean',[5 8 6]));
batch = { sub, d };
end

% ---- spatial_frequency_tuning (element_id + stimulus_tuningcurve_id) --------
function batch = fx_spatial_frequency_tuning()
sub = subjDoc('sf_sub', 'neuronSF');
tc  = subjDoc('sf_tc',  'tuningcurveSF');
d = struct();
d.document_class = struct('class_name','spatial_frequency_tuning','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = [ struct('name','element_id','value','sf_sub'), ...
                 struct('name','stimulus_tuningcurve_id','value','sf_tc') ];
d.base = struct('id','sf_01','session_id','sess_09','name','sf','datestamp','2024-06-01T12:00:00.000Z');
d.spatial_frequency_tuning = struct( ...
    'properties', struct('response_units','spikes/s'), ...
    'tuning_curve', struct('spatial_frequency',[0.05 0.1 0.2 0.5],'mean',[2 8 5 1]), ...
    'significance', struct('visual_response_anova_p',0.01,'across_stimuli_anova_p',0.03), ...
    'fitless', struct('pref',0.12,'l50',0.06,'h50',0.28,'bandwidth',2.2, ...
        'low_pass_index',0.3,'high_pass_index',0.7), ...
    'fit_dog', struct('r2',0.95,'pref',0.13));
batch = { sub, tc, d };
end

% ---- probe_geometry (probe_id) ---------------------------------------------
function batch = fx_probe_geometry()
sub = subjDoc('pg_sub', 'probePG');
d = struct();
d.document_class = struct('class_name','probe_geometry','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name','probe_id','value','pg_sub');
d.base = struct('id','pg_01','session_id','sess_09','name','pg','datestamp','2024-06-01T12:00:00.000Z');
d.probe_geometry = struct('num_channels',2, ...
    'channel_positions',[0 0; 20 0], ...
    'position_units','um', ...
    'probe_type','linear');
batch = { sub, d };
end

% ---- position_metadata (element_id) ----------------------------------------
function batch = fx_position_metadata()
sub = subjDoc('pm_sub', 'elemPM');
d = struct();
d.document_class = struct('class_name','position_metadata','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name','element_id','value','pm_sub');
d.base = struct('id','pm_01','session_id','sess_09','name','pm','datestamp','2024-06-01T12:00:00.000Z');
d.position_metadata = struct('ontology_node','EMPTY:0000200', ...
    'units','NCIT:C48367','dimensions','NCIT:C44477,NCIT:C44478');
batch = { sub, d };
end

% ---- distance_metadata (element_id) -- REAL FLAT v1 shape ------------------
% The writer emits FLAT per-endpoint fields (ontologyNode_A/_B, integerIDs_A/_B,
% ontologyStringValues_A/_B, ontologyNumericValues_A/_B empty by design, units),
% NOT a nested `endpoints` block. The migrator reshapes flat -> the nested
% `endpoints` array the schema requires; this fixture is the real shape so the
% reshape is exercised under validation (element_id -> the minted subject; the
% endpoint node ids are field values, not orphan-checked depends_on edges).
function batch = fx_distance_metadata()
sub = subjDoc('dm_sub', 'elemDM');
d = struct();
d.document_class = struct('class_name','distance_metadata','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name','element_id','value','dm_sub');
d.base = struct('id','dm_01','session_id','sess_09','name','dm','datestamp','2024-06-01T12:00:00.000Z');
d.distance_metadata = struct( ...
    'ontologyNode_A','dm_sub',       'integerIDs_A',1, ...
    'ontologyNumericValues_A',[],    'ontologyStringValues_A','uid_a1,uid_a2', ...
    'ontologyNode_B','patch_row_1',  'integerIDs_B',[2 3], ...
    'ontologyNumericValues_B',[],    'ontologyStringValues_B','uid_b1', ...
    'units','NCIT:C48367');
batch = { sub, d };
end

% ---- electrode_offset_voltage (probe_id) -----------------------------------
function batch = fx_electrode_offset_voltage()
sub = subjDoc('eo_sub', 'probeEO');
d = struct();
d.document_class = struct('class_name','electrode_offset_voltage','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name','probe_id','value','eo_sub');
d.base = struct('id','eo_01','session_id','sess_09','name','eo','datestamp','2024-06-01T12:00:00.000Z');
d.electrode_offset_voltage = struct('offset_voltages',[0.5 -0.3 1.2 0.0], ...
    'voltage_units','mV');
batch = { sub, d };
end

% ---- site2channelmap (probe_id) --------------------------------------------
function batch = fx_site2channelmap()
sub = subjDoc('s2c_sub', 'probeS2C');
d = struct();
d.document_class = struct('class_name','site2channelmap','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','probe_id','value','s2c_sub');
d.base = struct('id','s2c_01','session_id','sess_09','name','s2c','datestamp','2024-06-01T12:00:00.000Z');
d.site2channelmap = struct('num_sites',32, ...
    'site_to_channel', struct('site',1,'channel',5));
batch = { sub, d };
end

% ---- spike_interface_sorting_outputs (element_id) --------------------------
function batch = fx_spike_interface_sorting_outputs()
sub = subjDoc('sis_sub', 'recSubSIS');
d = struct();
d.document_class = struct('class_name','spike_interface_sorting_outputs','class_version','1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
d.depends_on = struct('name','element_id','value','sis_sub');
d.base = struct('id','sis_01','session_id','sess_09','name','sis','datestamp','2024-06-01T12:00:00.000Z');
d.spike_interface_sorting_outputs = struct('sorter_name','kilosort', ...
    'num_units',12,'sample_rate',30000);
batch = { sub, d };
end

% ---- dataset_remote (no depends_on) ----------------------------------------
function batch = fx_dataset_remote()
d = struct();
d.document_class = struct('class_name','dataset_remote','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name', {}, 'value', {});
d.base = struct('id','dr_01','session_id','dr_dsid_1','name','remote','datestamp','2024-06-01T12:00:00.000Z');
d.dataset_remote = struct('dataset_id','d-12345','organization_id','ndicloud-lab');
batch = { d };
end

% ---- dataset_session_info (aggregate; no depends_on) -----------------------
function batch = fx_dataset_session_info()
d = struct();
d.document_class = struct('class_name','dataset_session_info','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name', {}, 'value', {});
d.base = struct('id','dsi_01','session_id','dsi_dsid_1','name','dsi','datestamp','2024-06-01T12:00:00.000Z');
e1 = struct('session_id','dsi_member_a','is_linked',0);
e2 = struct('session_id','dsi_member_b','is_linked',1);
d.dataset_session_info = struct('dataset_session_info', [e1 e2]);
batch = { d };
end

% ---- session_in_a_dataset (no depends_on) ----------------------------------
function batch = fx_session_in_a_dataset()
d = struct();
d.document_class = struct('class_name','session_in_a_dataset','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name', {}, 'value', {});
d.base = struct('id','sida_01','session_id','sida_dsid_1','name','sid','datestamp','2024-06-01T12:00:00.000Z');
d.session_in_a_dataset = struct('session_id','sida_member_9', ...
    'session_reference','exp_demo','is_linked',0, ...
    'session_creator','ndi.session.dir','session_creator_input1','exp_demo', ...
    'session_creator_input2','','session_creator_input3','', ...
    'session_creator_input4','','session_creator_input5','', ...
    'session_creator_input6','');
batch = { d };
end

% ---- element_epoch (element_id; superclasses base + epochid) ---------------
function batch = fx_element_epoch()
sub = subjDoc('ee_sub', 'elemEE');
d = struct();
d.document_class = struct('class_name','element_epoch','class_version','1.0.0', ...
    'superclasses', [ struct('class_name','base','class_version','1.0.0'), ...
                      struct('class_name','epochid','class_version','1.0.0') ]);
d.depends_on = struct('name','element_id','value','ee_sub');
d.base = struct('id','ee_01','session_id','sess_09','name','t00001','datestamp','2024-06-01T12:00:00.000Z');
d.epochid = struct('epochid','t00001');
d.element_epoch = struct('epoch_clock','dev_local_time','t0_t1',[0; 930.35]);
batch = { sub, d };
end

% ---- ontology_image, OLDER LAYOUT (ontology_name + element_id) --------------
% NDI redefined ontologyImage, so two incompatible layouts are both v1. This is
% the older one (schemas/V_alpha/ontologyImage.json): the region is two
% coordinated text fields and element_id names the subject. It MIGRATES to a
% term_observation.
%
% This fixture previously used `ontology_image.region`, which is not a v1 field
% at all -- it is what the V_delta migrator PRODUCES. The migrator was written
% to match that invented shape and so silently emitted an empty observation on
% every real document. The guard now rejects `region` by name, and this fixture
% carries the real field names.
function batch = fx_ontology_image()
sub = subjDoc('oi_sub', 'elemOI');
d = struct();
d.document_class = struct('class_name','ontology_image','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name','element_id','value','oi_sub');
d.base = struct('id','oi_01','session_id','sess_09','name','oi','datestamp','2024-06-01T12:00:00.000Z');
d.ontology_image = struct('ontology_name','uberon:0002436', ...
    'ontology_region','primary visual cortex');
batch = { sub, d };
end

% ---- ontology_image, CURRENT NDI LAYOUT (ontologyNodes + ngrid) -------------
% Written by +ndi/+setup/+NDIMaker/imageDocMaker: the terms are a comma-joined
% CURIE list, the raster rides an ngrid block, and the only edge is to an
% ontologyTableRow -- which is NOT a subject. The subject is reachable only
% through that table row, i.e. only with the migrated-id graph, so this layout
% is DEFERRED to the NDI second pass and passes through UNCHANGED.
%
% The point of this fixture is that the passthrough must VALIDATE: it exercises
% the reshaped ontology_image tombstone (ngrid superclass + ontology_nodes) under
% Validate=true. Without it nothing checks that the deferred document can
% actually land.
%
% The ontology_table_row_id edge is left EMPTY here to keep the fixture
% self-contained (empty edges are skipped by the orphan check). Whether the
% passthrough should carry a populated edge is an open question -- see the note
% in V_eta_ngrid_family_findings.md; ontology_table_row mints fresh ids per
% column, so a populated edge may not resolve.
function batch = fx_ontology_image_ndi()
d = struct();
d.document_class = struct('class_name','ontology_image','class_version','1.0.0', ...
    'superclasses', struct('class_name',{'base','ngrid'}, 'class_version',{'1.0.0','1.0.0'}));
d.depends_on = struct('name','ontology_table_row_id','value','');
d.base = struct('id','oi_02','session_id','sess_09','name','oi2','datestamp','2024-06-01T12:00:00.000Z');
d.ontology_image = struct('ontology_nodes','uberon:0000955,uberon:0002436');
d.ngrid = struct('data_size',8,'data_type','double','data_dim',[4 4], ...
    'coordinates',[1;2;3;4;1;2;3;4]);
batch = { d };
end

% ---- openminds_element (element_id + empty openminds dep) ------------------
function batch = fx_openminds_element()
sub = subjDoc('ome_sub', 'elemOME');
d = struct();
d.document_class = struct('class_name','openminds_element','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name', {'element_id','openminds'}, 'value', {'ome_sub',''});
d.base = struct('id','ome_01','session_id','sess_09','name','','datestamp','2024-06-01T12:00:00.000Z');
d.openminds = struct('openminds_type','https://openminds.om-i.org/types/Species', ...
    'matlab_type','openminds.controlledterms.Species', ...
    'fields', struct('name','Caenorhabditis elegans', ...
        'preferredOntologyIdentifier','NCBITaxon:6239','synonym','C. elegans'));
batch = { sub, d };
end

% ---- openminds_stimulus (stimulus_id + empty openminds dep) ----------------
function batch = fx_openminds_stimulus()
sub = subjDoc('oms_sub', 'stimOMS');
d = struct();
d.document_class = struct('class_name','openminds_stimulus','class_version','1.0.0', ...
    'superclasses', struct('class_name','base','class_version','1.0.0'));
d.depends_on = struct('name', {'stimulus_id','openminds'}, 'value', {'oms_sub',''});
d.base = struct('id','oms_01','session_id','sess_09','name','','datestamp','2024-06-01T12:00:00.000Z');
d.openminds = struct('openminds_type','https://openminds.om-i.org/types/Species', ...
    'matlab_type','openminds.controlledterms.Species', ...
    'fields', struct('name','Caenorhabditis elegans', ...
        'preferredOntologyIdentifier','NCBITaxon:6239','synonym','C. elegans'));
batch = { sub, d };
end
