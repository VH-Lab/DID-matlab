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
    ];
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
