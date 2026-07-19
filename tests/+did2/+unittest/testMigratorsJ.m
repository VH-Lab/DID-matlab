function tests = testMigratorsJ
%TESTMIGRATORSJ Brainstorm-J split/fold migrator tests (TargetVersion 'V_eta').
%
%   Exercises the did_v1 -> V_eta migrators routed by did2.convert.v1_to_v2
%   when TargetVersion == 'V_eta'. Covers:
%     - subject_group      -> bare `subject` (v3.0.0; no is_group/is_biological)
%     - treatment_transfer -> term_manipulation + provenance directed_relation
%                             + session anchor (1 -> 3, D4)
%     - ontology_table_row -> per-column assertions/observations (1 -> N), and
%                             the per-table map for the C. elegans encounter
%                             (worm obs + shared time_reference + patch relation)
%     - treatment          -> temperature_/dose_/term_manipulation by structure,
%                             + a site term_observation for a located site (D3)
%     - treatment_drug     -> dose_manipulation (mixture -> dose composite)
%     - virus_injection    -> dose_manipulation (virus + dilution)
%     - probe_location     -> term_observation about the probe-subject (D5)
%     - ontology_label     -> term_observation about the labeled subject (D5)
%     - image_stack        -> body-backed image_observation + sampled_body (§C.4)
%   D10/D11 are decided (parameters on subject_statement; per-table subject
%   maps; multi-party events bind via a shared time_reference). Tables are moved
%   off the naive per-column seed onto their maps one at a time (see Contents.m).
%
%   Runs with Validate=false so they assert the TRANSFORM (routing + field
%   placement) without a V_eta schema cache at the runner working directory.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJ');

tests = functiontests(localfunctions);
end

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v = depVal(doc, name)
v = '';
deps = doc.get('depends_on');
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(deps(k).name, name)
        v = deps(k).value;
        return;
    end
end
end

% ===================== subject_group -> bare subject ===================

function testSubjectGroupBecomesBareSubject(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'aa_11', 'session_id', 'aa_99', ...
    'name', 'cohortA', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortA', 'description', 'the treated cohort');
out = runJ(v1);

verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'subject');
verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_eta');
verifyEqual(testCase, doc.get('subject.local_identifier'), 'cohortA');
% bare identity: is_group / is_biological must NOT be present in V_eta
sub = doc.get('subject');
verifyFalse(testCase, isfield(sub, 'is_group'));
verifyFalse(testCase, isfield(sub, 'is_biological'));
end

function testSubjectGroupEmptyNameFallsBackToId(testCase)
% local_identifier is REQUIRED on a V_eta subject; a subject_group with no
% group_name must still be nameable -- it falls back to the document id.
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'grp_noname', 'session_id', 'aa_99', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', '', 'description', '');
out = runJ(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject.local_identifier'), 'grp_noname');
end

function testSubjectCarryForwardFillsLocalId(testCase)
% A plain v1 subject with an empty/missing local_identifier is filled from the
% document id (the required-handle carry-forward path).
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'sub_bare', 'session_id', 'sess_09', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', '', 'description', '');
out = runJ(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'subject');
verifyEqual(testCase, doc.get('subject.local_identifier'), 'sub_bare');
end

function testSubjectCarryForwardPreservesLocalId(testCase)
% A v1 subject that already has a handle keeps it (fallback only fires when empty).
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'sub_named', 'session_id', 'sess_09', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', 'mouse_42@lab', 'description', '');
out = runJ(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject.local_identifier'), 'mouse_42@lab');
end

function testSubjectGroupMintsMemberRelations(testCase)
% A subject_group carrying member links (subject_id_1..N) becomes the bare
% subject PLUS one member_of directed_relation per member (child = member,
% parent = the group), so the membership is preserved rather than dropped.
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id_1', 'subject_id_2', 'subject_id_3'}, ...
    'value', {'m_1', 'm_2', 'm_3'});
v1.base = struct('id', 'grp_1', 'session_id', 'aa_99', ...
    'name', 'cohortB', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortB', 'description', '');
out = runJ(v1);

% 1 subject + 3 member_of relations
verifyEqual(testCase, numel(out.migrated), 4);
sub = firstOfClassJ(out.migrated, 'subject');
verifyEqual(testCase, sub.get('base.id'), 'grp_1');   % group id preserved
verifyEqual(testCase, out.summary.by_class.directed_relation, 3);
% each relation is member --member_of--> group
children = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation')
        verifyEqual(testCase, d.get('directed_relation.relation').name, 'member_of');
        verifyEqual(testCase, depVal(d, 'parent'), 'grp_1');   % the group
        children{end+1} = depVal(d, 'child'); %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(children), {'m_1', 'm_2', 'm_3'});
end

% ============ openminds_subject -> term_assertion (decompose) ==========

function testOpenmindsSubjectBecomesTermAssertion(testCase)
% Brainstorm J does not store the openMINDS bundle: each openMINDS entity about
% a subject (Species / Strain / Sex) decomposes into one term_assertion on that
% subject. The entity type names the variable; the ontology id is the value.
v1 = struct();
v1.document_class = struct('class_name', 'openminds_subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id', 'openminds'}, 'value', {'subj_007', ''});
v1.base = struct('id', 'om_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239', 'synonym', 'C. elegans'));
out = runJ(v1);

verifyEqual(testCase, numel(out.migrated), 1);
a = out.migrated{1};
verifyEqual(testCase, a.get('document_class.class_name'), 'term_assertion');
% the entity type -> the asserted variable; the ontology id + label -> the value
verifyEqual(testCase, a.get('subject_statement.variable').name, 'species');
verifyEqual(testCase, a.get('term_assertion.value').node, 'NCBITaxon:6239');
verifyEqual(testCase, a.get('term_assertion.value').name, 'Caenorhabditis elegans');
verifyEqual(testCase, depVal(a, 'subject_id'), 'subj_007');
% an assertion is timeless: it is a subject_assertion, not an interaction
supers = a.get('document_class.superclasses');
verifyEqual(testCase, supers(1).class_name, 'subject_assertion');
end

function testOpenmindsGeneticStrainTypeVariableIsDeCamelCased(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'openminds_subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'om_2', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/GeneticStrainType', ...
    'fields', struct('name', 'knockout', 'ontologyIdentifier', 'X:1'));
out = runJ(v1);
a = out.migrated{1};
verifyEqual(testCase, a.get('subject_statement.variable').name, 'genetic strain type');
verifyEqual(testCase, a.get('term_assertion.value').node, 'X:1');
end

% ============ element -> subject (+ kind assertions + lineage) =========

function el = elementDoc(name, typ, ndiClass, direct, subjectId, underlyingId)
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
deps = struct('name', {'subject_id'}, 'value', {subjectId});
if ~isempty(underlyingId)
    deps(end+1) = struct('name', 'underlying_element_id', 'value', underlyingId);
end
el.depends_on = deps;
el.base = struct('id', 'el_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', ndiClass, 'name', name, ...
    'reference', '1', 'type', typ, 'direct', direct);
end

function testElementDerivedBecomesSubjectDerivedFrom(testCase)
% A derived element (direct=0 with an underlying element) -> a subject (id
% preserved) + kind assertions (nothing dropped) + a derived_from lineage edge.
out = runJ(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1'));
sub = firstOfClassJ(out.migrated, 'subject');
verifyEqual(testCase, sub.get('base.id'), 'el_1');                 % id preserved
verifyEqual(testCase, sub.get('subject.local_identifier'), 'unit3 (ref 1)');
% type + ndi_element_class preserved as term_assertions (no silent drop)
verifyEqual(testCase, out.summary.by_class.term_assertion, 2);
% lineage: derived_from the underlying element (safe computational lineage)
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'derived_from');
verifyEqual(testCase, depVal(rel, 'child'), 'el_1');
verifyEqual(testCase, depVal(rel, 'parent'), 'probe_1');
end

function testElementDirectDeviceObservesSpecimen(testCase)
% A direct device (direct=1, no underlying) observes the specimen -- the
% instrument-agent role, NOT part_of (a probe is not part of the animal).
out = runJ(elementDoc('probeA', 'n-trode', 'ndi.probe.timeseries', 1, 'subj_007', ''));
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'observes');
verifyEqual(testCase, depVal(rel, 'child'), 'el_1');
verifyEqual(testCase, depVal(rel, 'parent'), 'subj_007');   % the specimen
end

% ============ treatment_transfer -> term_manipulation + relation =======

function testTreatmentTransferBecomesTermManipulationPlusProvenance(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = [ ...
    struct('name', 'recipient_id', 'document_id', 'rec_001'), ...
    struct('name', 'donor_id',     'document_id', 'don_002')];
v1.base = struct('id', 'tt_01', 'session_id', 'sess_09', ...
    'name', 'graft', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_transfer = struct( ...
    'entity_ontologyNode', 'uberon:0000922', 'entity_name', 'embryonic tissue', ...
    'method_name', 'transplantation');
out = runJ(v1);

% 1 -> 3: the act, the provenance relation, the anchor.
verifyEqual(testCase, numel(out.migrated), 3);
verifyTrue(testCase, isfield(out.summary.by_class, 'term_manipulation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'directed_relation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));

act = out.migrated{1};
% recipient is the patient; the material term is the value AND the variable
verifyEqual(testCase, depVal(act, 'subject_id'), 'rec_001');
verifyEqual(testCase, act.get('subject_statement.variable').name, 'embryonic tissue');
verifyEqual(testCase, act.get('term_manipulation.value').name, 'embryonic tissue');
verifyEqual(testCase, act.get('subject_interaction.method').name, 'transplantation');

rel = out.migrated{2};
verifyEqual(testCase, depVal(rel, 'child'), 'rec_001');
verifyEqual(testCase, depVal(rel, 'parent'), 'don_002');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'derived_from');

anchor = out.migrated{3};
verifyEqual(testCase, anchor.get('session_relative_reference.relation'), 'during');
end

% ============ ontology_table_row -> assertions/observations (1 -> N) ====

function otr = tableRow()
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {'subject_id'}, 'value', {'subj_001'});
otr.base = struct('id', 'otr_01', 'session_id', 'sess_09', ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct( ...
    'variable_names', 'BodyWeight,StartleAmplitude,TrialType,SubjectLocalIdentifier', ...
    'names', 'body weight,acoustic startle maximum amplitude,trial type,subject local identifier', ...
    'ontology_nodes', 'EMPTY:1,EMPTY:2,EMPTY:3,EMPTY:4', ...
    'data', struct('BodyWeight', 24.3, 'StartleAmplitude', 38, ...
        'TrialType', 'Startle 95 dB', 'SubjectLocalIdentifier', 'rat_1'));
end

function testOntologyTableRowSplitsByShape(testCase)
out = runJ(tableRow());
% 3 kept columns (identity skipped) + 1 shared anchor
verifyEqual(testCase, numel(out.migrated), 4);
verifyTrue(testCase, isfield(out.summary.by_class, 'mass_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'intensity_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'term_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));
% identity column is skipped, not an observation
verifyFalse(testCase, isfield(out.summary.by_class, 'local_identifier'));
end

function testOntologyTableRowNumericColumn(testCase)
out = runJ(tableRow());
mass = out.migrated{1};   % BodyWeight -> mass_observation
verifyEqual(testCase, mass.get('document_class.class_name'), 'mass_observation');
% identity is on the spine variable (subject_statement), value on the mass leaf
verifyEqual(testCase, mass.get('subject_statement.variable').name, 'body weight');
verifyEqual(testCase, mass.get('mass.value').source_value, 24.3);
verifyEqual(testCase, mass.get('subject_statement.storage_mode'), 'inline');
% the spine: subject_id carried, shared time anchor wired on
verifyEqual(testCase, depVal(mass, 'subject_id'), 'subj_001');
verifyEqual(testCase, depVal(mass, 'time_reference_1'), out.migrated{4}.get('base.id'));
end

function testOntologyTableRowStringColumnIsTermObservation(testCase)
out = runJ(tableRow());
term = out.migrated{3};   % TrialType -> term_observation (string value)
verifyEqual(testCase, term.get('document_class.class_name'), 'term_observation');
verifyEqual(testCase, term.get('term_observation.value').name, 'Startle 95 dB');
end

function testOntologyTableRowAmplitudeIsIntensity(testCase)
out = runJ(tableRow());
amp = out.migrated{2};   % a.u. amplitude -> intensity_observation (J §7)
verifyEqual(testCase, amp.get('document_class.class_name'), 'intensity_observation');
verifyEqual(testCase, amp.get('intensity.value').source_value, 38);
end

% ===================== treatment -> manipulation leaves ================

function v1 = treatmentDoc(node, name, numeric, stringValue)
v1 = struct();
v1.document_class = struct('class_name', 'treatment', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'tr_01', 'session_id', 'sess_09', ...
    'name', 'trt', 'datestamp', '2024-06-01T12:00:00.000Z');
t = struct('ontology_name', node, 'name', name);
if ~isempty(numeric); t.numeric_value = numeric; end
if nargin >= 4 && ~isempty(stringValue); t.string_value = stringValue; end
v1.treatment = t;
end

function testTreatmentTemperatureIsTemperatureManipulation(testCase)
out = runJ(treatmentDoc('', 'cold exposure', 4.0, ''));
verifyEqual(testCase, numel(out.migrated), 2);   % manip + anchor
m = out.migrated{1};
verifyEqual(testCase, m.get('document_class.class_name'), 'temperature_manipulation');
verifyEqual(testCase, m.get('temperature.value').source_value, 4.0);
verifyEqual(testCase, m.get('subject_statement.variable').name, 'cold exposure');
verifyEqual(testCase, depVal(m, 'subject_id'), 'subj_007');
% shared session anchor wired on as the time_reference
verifyEqual(testCase, depVal(m, 'time_reference_1'), out.migrated{2}.get('base.id'));
end

function testTreatmentSubstanceIsDoseManipulation(testCase)
out = runJ(treatmentDoc('chebi:28001', 'haloperidol', 2.5, ''));
m = out.migrated{1};
verifyEqual(testCase, m.get('document_class.class_name'), 'dose_manipulation');
chem = m.get('dose.value').formulation.chemicals;
verifyEqual(testCase, chem(1).substance.name, 'haloperidol');
% the source numeric_value is carried as the dose amount (not dropped)
verifyEqual(testCase, chem(1).amount.source_value, 2.5);
% the substance is BOTH the spine identity and the dose chemical
verifyEqual(testCase, m.get('subject_statement.variable').node, 'chebi:28001');
end

function testTreatmentProcedureIsTermManipulation(testCase)
out = runJ(treatmentDoc('', 'craniotomy', [], ''));
m = out.migrated{1};
verifyEqual(testCase, m.get('document_class.class_name'), 'term_manipulation');
verifyEqual(testCase, m.get('term_manipulation.value').name, 'craniotomy');
end

function testTreatmentTargetLocationEmitsSiteObservation(testCase)
% Dab "Target Location" idiom: the site rides in string_value; strict J has no
% target_structure, so a located site becomes a term_observation (D3).
out = runJ(treatmentDoc('chebi:28001', 'muscimol Target Location', [], 'uberon:0002436'));
verifyEqual(testCase, numel(out.migrated), 3);   % dose manip + site obs + anchor
verifyTrue(testCase, isfield(out.summary.by_class, 'dose_manipulation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'term_observation'));
% " Target Location" stripped from the manipulation's spine variable
verifyEqual(testCase, out.migrated{1}.get('subject_statement.variable').name, 'muscimol');
site = out.migrated{2};
verifyEqual(testCase, site.get('document_class.class_name'), 'term_observation');
verifyEqual(testCase, site.get('term_observation.value').node, 'uberon:0002436');
end

% ===================== treatment_drug / virus_injection ================

function testTreatmentDrugBecomesDoseManipulation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'td_01', 'session_id', 'sess_09', ...
    'name', 'td', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_drug = struct('mixture_table', 'chebi:28001,haloperidol,5', ...
    'location_ontologyNode', 'uberon:0002436', 'location_name', 'primary visual cortex');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 3);   % dose + site obs + anchor
d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'dose_manipulation');
chem = d.get('dose.value').formulation.chemicals;
verifyEqual(testCase, chem(1).substance.name, 'haloperidol');
verifyEqual(testCase, chem(1).amount.source_value, 5);
verifyEqual(testCase, d.get('subject_statement.variable').name, 'haloperidol');
% the site node survives the universalRenames snake-casing (location_ontologyNode
% -> location_ontology_node)
site = out.migrated{2};
verifyEqual(testCase, site.get('document_class.class_name'), 'term_observation');
verifyEqual(testCase, site.get('term_observation.value').node, 'uberon:0002436');
end

function testVirusInjectionBecomesDoseManipulation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'vi_01', 'session_id', 'sess_09', ...
    'name', 'vi', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'AAV-ChR2', 'dilution', 1000, ...
    'virusLocation_OntologyName', 'uberon:0002436', 'virusLocation_name', 'V1');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 3);   % dose + site obs + anchor
d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'dose_manipulation');
chem = d.get('dose.value').formulation.chemicals;
verifyEqual(testCase, chem(1).substance.name, 'AAV-ChR2');
verifyEqual(testCase, chem(1).amount.source_value, 1000);
verifyEqual(testCase, d.get('subject_statement.variable').node, 'addgene:26973');
% site node survives snake-casing (virusLocation_OntologyName -> virus_location_ontology_name)
site = out.migrated{2};
verifyEqual(testCase, site.get('term_observation.value').node, 'uberon:0002436');
end

% ===================== probe_location / ontology_label =================

function testProbeLocationBecomesTermObservation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'probe_location', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_42'});
v1.base = struct('id', 'pl_01', 'session_id', 'sess_09', ...
    'name', 'pl', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_location = struct('ontology_name', 'uberon:0002436', 'name', 'primary visual cortex');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % obs + anchor
o = out.migrated{1};
verifyEqual(testCase, o.get('document_class.class_name'), 'term_observation');
verifyEqual(testCase, o.get('term_observation.value').node, 'uberon:0002436');
% the probe is the subject (device-as-subject, D2)
verifyEqual(testCase, depVal(o, 'subject_id'), 'probe_42');
end

function testOntologyLabelBecomesTermObservation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'ontology_label', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'ol_01', 'session_id', 'sess_09', ...
    'name', 'ol', 'datestamp', '2024-06-01T12:00:00.000Z');
% idiom 1: three coordinated fields -> a composed CURIE
v1.ontology_label = struct('ontology_name', 'Allen CCF v3', 'label_id', 12345, ...
    'label', 'primary visual cortex');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % obs + anchor
o = out.migrated{1};
verifyEqual(testCase, o.get('document_class.class_name'), 'term_observation');
verifyEqual(testCase, o.get('term_observation.value').node, 'allen_ccf_v3:12345');
verifyEqual(testCase, o.get('term_observation.value').name, 'primary visual cortex');
verifyEqual(testCase, depVal(o, 'subject_id'), 'elem_9');
end

% ===================== image_stack -> body-backed observation ==========

function testImageStackBecomesBodyBackedObservation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'is_01', 'session_id', 'sess_09', ...
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'edam:3382', ...
    'label', 'a two-photon stack', 'format', 'tiff');
v1.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YXCZT', 'dimension_size', [512 512 1 1 10], ...
    'dimension_scale', [0.5 0.5 1 1 1], 'clocktype', 'dev_local_time', 'timestamp', 0);
out = runJ(v1);
% 1 -> 3: image_observation + sampled_body + anchor
verifyEqual(testCase, numel(out.migrated), 3);
verifyTrue(testCase, isfield(out.summary.by_class, 'image_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'sampled_body'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));
obs = out.migrated{1};
verifyEqual(testCase, obs.get('document_class.class_name'), 'image_observation');
% the source `label` is NOT carried -- it is the definition of the modality
% ontology term (on variable), reconstructable as a projection, so base.name is
% a short generic name rather than the prose label.
verifyEqual(testCase, obs.get('base.name'), 'migrated_image');
% the value lives in the body: storage_mode: body on the statement
verifyEqual(testCase, obs.get('subject_statement.storage_mode'), 'body');
verifyEqual(testCase, depVal(obs, 'subject_id'), 'subj_007');
% frames in the sampled_body; cadence n = T*Z = 10*1
sb = out.migrated{2};
verifyEqual(testCase, sb.get('document_class.class_name'), 'sampled_body');
verifyEqual(testCase, sb.get('sampled_body.sample_time').n, 10);
% the body belongs to the image_observation statement
verifyEqual(testCase, depVal(sb, 'statement'), obs.get('base.id'));
end

% ============ ontology_table_row per-table map: C. elegans encounter ====

function otr = encounterRow()
P = 'CElegansBehavioralAssay_';
keys = {'SubjectDocumentIdentifier', [P 'EncounterIdentifier'], ...
    'BacterialPatchDocumentIdentifier', [P 'EncounterOnsetTime'], ...
    [P 'EncounterOffsetTime'], [P 'DecelerationUponEncounter'], ...
    [P 'MinimumVelocityDuringEncounter'], [P 'PeakVelocityBeforeEncounterOnset'], ...
    [P 'MinimumVelocityAfterEncounterOffset'], [P 'PosteriorProbabilityOfExploitation'], ...
    [P 'PosteriorProbabilityOfSensing'], [P 'RelativeDensityOfEncounteredBacteria'], ...
    [P 'RelativeDensityOfCultivationBacteria']};
data = struct();
data.SubjectDocumentIdentifier = 'worm_1';
data.([P 'EncounterIdentifier']) = 5;
data.BacterialPatchDocumentIdentifier = 'patch_1';
data.([P 'EncounterOnsetTime']) = 1249.72;
data.([P 'EncounterOffsetTime']) = 1265.39;
data.([P 'DecelerationUponEncounter']) = 3.15;
data.([P 'MinimumVelocityDuringEncounter']) = 130.4;
data.([P 'PeakVelocityBeforeEncounterOnset']) = 196.3;
data.([P 'MinimumVelocityAfterEncounterOffset']) = 130.4;
data.([P 'PosteriorProbabilityOfExploitation']) = 1.99e-5;
data.([P 'PosteriorProbabilityOfSensing']) = 7.5e-4;
data.([P 'RelativeDensityOfEncounteredBacteria']) = 0.557;
data.([P 'RelativeDensityOfCultivationBacteria']) = 2.238;
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {}, 'value', {});
otr.base = struct('id', 'otr_enc', 'session_id', 'sess_1', ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function d = firstOfClassJ(migrated, className)
d = [];
for k = 1:numel(migrated)
    if strcmp(migrated{k}.get('document_class.class_name'), className)
        d = migrated{k}; return;
    end
end
end

function testEncounterTableMap(testCase)
out = runJ(encounterRow());
% 8 worm observations + 1 relation + 1 shared time_reference
verifyEqual(testCase, numel(out.migrated), 10);
bc = out.summary.by_class;
verifyTrue(testCase, isfield(bc, 'velocity_observation'));
verifyTrue(testCase, isfield(bc, 'acceleration_observation'));
verifyTrue(testCase, isfield(bc, 'score_observation'));
verifyTrue(testCase, isfield(bc, 'concentration_observation'));
verifyTrue(testCase, isfield(bc, 'directed_relation'));
verifyTrue(testCase, isfield(bc, 'session_bounded_reference'));
% onset/offset are the window (not observations); encounter # is derived (dropped)
verifyFalse(testCase, isfield(bc, 'duration_observation'));
verifyFalse(testCase, isfield(bc, 'count_observation'));
verifyEqual(testCase, bc.velocity_observation, 3);
% a measurement is about the worm and shares the encounter window
tref = firstOfClassJ(out.migrated, 'session_bounded_reference');
vel = firstOfClassJ(out.migrated, 'velocity_observation');
verifyEqual(testCase, depVal(vel, 'subject_id'), 'worm_1');
verifyEqual(testCase, depVal(vel, 'time_reference_1'), tref.get('base.id'));
% the relation is the encounter record: worm --encountered--> patch, same window
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyEqual(testCase, depVal(rel, 'child'), 'worm_1');
verifyEqual(testCase, depVal(rel, 'parent'), 'patch_1');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'encountered');
verifyEqual(testCase, depVal(rel, 'time_reference_1'), tref.get('base.id'));
% the window carries onset/offset
verifyEqual(testCase, tref.get('session_bounded_reference.start').source_value, 1249.72);
end

% ==== ontology_table_row per-table map: C. elegans bacterial patch ======

function otr = patchGeometryRow()
keys = {'BacterialPlateIdentifier', 'BacterialPatchIdentifier', ...
    'BacterialOD600TargetAtSeeding', 'BacterialPatchVolume', ...
    'BacterialPatchCenter_XCoordinate', 'BacterialPatchCenter_YCoordinate', ...
    'BacterialPatchRadius', 'BacterialPatchCircularity'};
data = struct();
data.BacterialPlateIdentifier = '0061';
data.BacterialPatchIdentifier = '0017';
data.BacterialOD600TargetAtSeeding = 0.05;
data.BacterialPatchVolume = 0.5;
data.BacterialPatchCenter_XCoordinate = 806.3578700078308;
data.BacterialPatchCenter_YCoordinate = 684.8410336726703;
data.BacterialPatchRadius = 28.512513907289925;
data.BacterialPatchCircularity = 0.9847680561323107;
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {}, 'value', {});
otr.base = struct('id', 'otr_patch', 'session_id', 'sess_1', ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function testPatchGeometryTableMap(testCase)
out = runJ(patchGeometryRow());
% 1 subject + 6 geometry observations + 1 shared session anchor
verifyEqual(testCase, numel(out.migrated), 8);
bc = out.summary.by_class;
% the patch is declared as a bare subject
verifyTrue(testCase, isfield(bc, 'subject'));
verifyEqual(testCase, bc.subject, 1);
% geometry -> observations (OD600, volume, radius + centre X/Y, circularity)
verifyEqual(testCase, bc.concentration_observation, 1);
verifyEqual(testCase, bc.volume_observation, 1);
verifyEqual(testCase, bc.length_observation, 3);   % radius + centre X + centre Y
verifyEqual(testCase, bc.score_observation, 1);
verifyTrue(testCase, isfield(bc, 'session_relative_reference'));
% identity columns are not measurements
verifyFalse(testCase, isfield(bc, 'count_observation'));
% the minted subject PRESERVES the source document id (the encounter table's
% directed_relation parent points at it) and names the patch
sub = firstOfClassJ(out.migrated, 'subject');
verifyEqual(testCase, sub.get('base.id'), 'otr_patch');
verifyEqual(testCase, sub.get('subject.local_identifier'), '0017');
% every geometry observation is about that patch and shares the anchor
anchor = firstOfClassJ(out.migrated, 'session_relative_reference');
od = firstOfClassJ(out.migrated, 'concentration_observation');
verifyEqual(testCase, depVal(od, 'subject_id'), 'otr_patch');
verifyEqual(testCase, depVal(od, 'time_reference_1'), anchor.get('base.id'));
end

% ============ deferred stimulus_bath -> dose_manipulation (V_eta) =======

function testDeferredBathBecomesDoseManipulation(testCase)
% A stimulus_bath defers per-document (needsSessionContext). At V_eta the
% resolveDeferredBaths pass must assemble a strict-J `dose_manipulation` (D8
% retired the `bath`/`pharmacological_manipulation` family), NOT a `bath`:
% subject_id from the stimulator element, a session_relative anchor, the primary
% chemical as the spine variable, and the mixture as the dose formulation.
subjId = 'aabb1122ccdd3344_5500000000000001';
stimId = 'aabb1122ccdd3344_5500000000000002';

elem = struct();
elem.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
elem.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
elem.base = struct('id', stimId, 'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'stimulator', 'datestamp', '2024-06-01T12:00:00.000Z');
elem.element = struct('ndi_element_class', 'ndi.element', 'name', 'stim', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);

bath = struct();
bath.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
bath.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
bath.base = struct('id', 'aabb1122ccdd3344_5500000000000004', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'bath', 'datestamp', '2024-06-01T12:00:00.000Z');
bath.epochid = struct('epochid', 'epoch_t00001');
bath.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');

out = did2.convert.v1_to_v2({jsonencode(elem), jsonencode(bath)}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, any(arrayfun(@(q) strcmp(q.class_name, 'stimulus_bath'), ...
    out.quarantine)), 'stimulus_bath was not deferred');

out = did2.convert.resolveDeferredBaths(out, 'Validate', false, ...
    'TargetVersion', 'V_eta');

% strict J: a dose_manipulation, and NEVER the retired `bath` class
verifyTrue(testCase, isfield(out.summary.by_class, 'dose_manipulation'), ...
    'no dose_manipulation produced');
verifyFalse(testCase, isfield(out.summary.by_class, 'bath'), ...
    'retired `bath` class must not be emitted at V_eta');
for k = 1:numel(out.quarantine)
    verifyEmpty(testCase, regexp(out.quarantine(k).reason, ...
        'needsSessionContext|NDI layer|class "bath"', 'once'), ...
        sprintf('bath left unresolved: %s', out.quarantine(k).reason));
end

dose = firstOfClassJ(out.migrated, 'dose_manipulation');
verifyNotEmpty(testCase, dose);
verifyEqual(testCase, depVal(dose, 'subject_id'), subjId);
verifyNotEmpty(testCase, depVal(dose, 'time_reference_1'));
% the primary chemical is the spine identity and seeds the dose formulation
verifyEqual(testCase, dose.get('subject_statement.variable').name, 'muscimol');
chems = dose.get('dose.value').formulation.chemicals;
verifyEqual(testCase, chems(1).substance.name, 'muscimol');
% the anchor is an ordinal session_relative_reference
anchor = firstOfClassJ(out.migrated, 'session_relative_reference');
verifyNotEmpty(testCase, anchor);
verifyEqual(testCase, anchor.get('session_relative_reference.relation'), 'during');
% the bath location is carried as a term_observation (not dropped)
locObs = firstOfClassJ(out.migrated, 'term_observation');
verifyNotEmpty(testCase, locObs);
verifyEqual(testCase, locObs.get('term_observation.value').name, 'CNS');
verifyEqual(testCase, depVal(locObs, 'subject_id'), subjId);
end

% ============ metadata_editor -> dataset + entities + relations =========

function ds = allOfClassJ(migrated, className)
ds = {};
for k = 1:numel(migrated)
    if strcmp(migrated{k}.get('document_class.class_name'), className)
        ds{end+1} = migrated{k}; %#ok<AGROW>
    end
end
end

function v1 = metadataEditorDoc()
% A representative metadata_editor: the NDIMetaDataEditorApp `metadata_structure`
% blob (built by metadata_ds_core.convertDatasetInfoToDocument). Nested field
% names are PascalCase and are LEFT UNTOUCHED by universalRenames (only immediate
% block-field names are snake-cased), so the migrator reads them as-is.
v1 = struct();
v1.document_class = struct('class_name', 'metadata_editor', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'me_01', 'session_id', 'sess_09', ...
    'name', 'ds_meta', 'datestamp', '2024-06-01T12:00:00.000Z');
ms = struct();
ms.DatasetFullName = 'The Big Worm Dataset';
ms.DatasetShortName = 'BigWorm';
ms.VersionIdentifier = '1.0.0';
ms.Description = 'A dataset of worms.';
ms.License = 'CC-BY-4.0';
ms.ReleaseDate = '2024-01-15';
ms.VersionInnovation = 'first release';        % bucket 3 (GUI/prose) -> dropped
% two authors, both affiliated to the SAME organization (dedup to one org)
a1 = struct('givenName', 'Ada', 'familyName', 'Lovelace', ...
    'digitalIdentifier', struct('identifier', '0000-0001-2345-6789'), ...
    'contactInformation', struct('email', 'ada@example.org'), ...
    'affiliation', struct('memberOf', struct('fullName', 'Analytical Society')), ...
    'authorRole', 'Custodian');
a2 = struct('givenName', 'Alan', 'familyName', 'Turing', ...
    'digitalIdentifier', struct('identifier', ''), ...
    'contactInformation', struct('email', ''), ...
    'affiliation', struct('memberOf', struct('fullName', 'Analytical Society')), ...
    'authorRole', '');
ms.Author = [a1 a2];
ms.Funding = struct('funder', 'NIH', 'awardTitle', 'BRAIN Initiative', ...
    'awardNumber', 'R01-12345');
ms.RelatedPublication = struct('Publication', 'On Worms', 'DOI', '10.1/worm', ...
    'PMID', '123', 'PMCID', 'PMC9');
ms.FullDocumentation = 'https://example.org/docs';
% bucket 2 (projections off subject statements) -> dropped
ms.TechniquesEmployed = 'patch clamp';
ms.Subjects = struct('SubjectName', 'worm_1', 'BiologicalSexList', 'male');
v1.metadata_editor = struct('metadata_structure', ms);
end

function testMetadataEditorDecomposes(testCase)
out = runJ(metadataEditorDoc());
bc = out.summary.by_class;
% dataset + 2 persons + 2 orgs (deduped) + 1 award + 1 publication + 1 web_resource
% + 8 relations (has_author x2, affiliated_with x2, funded_by, issued_by, cites,
%   documented_by) = 16
verifyEqual(testCase, numel(out.migrated), 16);
verifyEqual(testCase, bc.dataset, 1);
verifyEqual(testCase, bc.person, 2);
verifyEqual(testCase, bc.organization, 2);   % Analytical Society (deduped) + NIH
verifyEqual(testCase, bc.award, 1);
verifyEqual(testCase, bc.publication, 1);
verifyEqual(testCase, bc.web_resource, 1);
verifyEqual(testCase, bc.directed_relation, 8);
% projections and GUI prose are NOT persisted as classes
verifyFalse(testCase, isfield(bc, 'subject'));
verifyFalse(testCase, isfield(bc, 'term_assertion'));
end

function testMetadataEditorDatasetEntity(testCase)
out = runJ(metadataEditorDoc());
ds = firstOfClassJ(out.migrated, 'dataset');
% keyed on the DATASET id (base.session_id), not the metadata_editor doc's base.id
verifyEqual(testCase, ds.get('base.id'), 'sess_09');
verifyEqual(testCase, ds.get('dataset.full_name'), 'The Big Worm Dataset');
verifyEqual(testCase, ds.get('dataset.short_name'), 'BigWorm');
verifyEqual(testCase, ds.get('dataset.version'), '1.0.0');
verifyEqual(testCase, ds.get('dataset.license'), 'CC-BY-4.0');
verifyEqual(testCase, ds.get('dataset.release_date'), '2024-01-15');
% documentation is NOT a dataset field -- it is a relation -> web_resource
verifyFalse(testCase, isfield(ds.get('dataset'), 'documentation'));
end

function testMetadataEditorAuthorsAndOrcid(testCase)
out = runJ(metadataEditorDoc());
persons = allOfClassJ(out.migrated, 'person');
verifyEqual(testCase, numel(persons), 2);
% the first author carries given/family/email and an ORCID global_identifier
ada = personByFamily(persons, 'Lovelace');
verifyEqual(testCase, ada.get('person.given_name'), 'Ada');
verifyEqual(testCase, ada.get('person.email'), 'ada@example.org');
gid = ada.get('entity.global_identifier');
verifyEqual(testCase, gid(1).scheme, 'ORCID');
verifyEqual(testCase, gid(1).value, '0000-0001-2345-6789');
% the second author had no ORCID -> empty global_identifier
alan = personByFamily(persons, 'Turing');
verifyEmpty(testCase, alan.get('entity.global_identifier'));
% has_author edges: dataset -> each person, carrying the author position
ds = firstOfClassJ(out.migrated, 'dataset');
seqs = [];
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(d.get('directed_relation.relation').name, 'has_author')
        verifyEqual(testCase, depVal(d, 'child'), ds.get('base.id'));
        seqs(end+1) = d.get('directed_relation.sequence'); %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(seqs), [1 2]);
end

function p = personByFamily(persons, family)
p = [];
for k = 1:numel(persons)
    if strcmp(persons{k}.get('person.family_name'), family); p = persons{k}; return; end
end
end

function testMetadataEditorOrgDedupAndAffiliation(testCase)
out = runJ(metadataEditorDoc());
% both authors share one org: exactly one 'Analytical Society' organization
orgs = allOfClassJ(out.migrated, 'organization');
names = cellfun(@(o) o.get('organization.name'), orgs, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'Analytical Society')), 1);
verifyEqual(testCase, sum(strcmp(names, 'NIH')), 1);
% both affiliated_with edges point at the single shared org id
society = orgs{strcmp(names, 'Analytical Society')};
affParents = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(d.get('directed_relation.relation').name, 'affiliated_with')
        affParents{end+1} = depVal(d, 'parent'); %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(affParents), 2);
verifyEqual(testCase, unique(affParents), {society.get('base.id')});
end

function testMetadataEditorFundingPublicationDocumentation(testCase)
out = runJ(metadataEditorDoc());
ds = firstOfClassJ(out.migrated, 'dataset');
% award: title + award-number identifier; dataset -funded_by-> award -issued_by-> NIH
award = firstOfClassJ(out.migrated, 'award');
verifyEqual(testCase, award.get('award.title'), 'BRAIN Initiative');
agid = award.get('entity.global_identifier');
verifyEqual(testCase, agid(1).scheme, 'AwardNumber');
verifyEqual(testCase, agid(1).value, 'R01-12345');
funded = relByName(out.migrated, 'funded_by');
verifyEqual(testCase, depVal(funded, 'child'), ds.get('base.id'));
verifyEqual(testCase, depVal(funded, 'parent'), award.get('base.id'));
issued = relByName(out.migrated, 'issued_by');
verifyEqual(testCase, depVal(issued, 'child'), award.get('base.id'));
% publication: title + DOI/PMID/PMCID identifiers; dataset -cites-> publication
pub = firstOfClassJ(out.migrated, 'publication');
verifyEqual(testCase, pub.get('publication.title'), 'On Worms');
pgid = pub.get('entity.global_identifier');
schemes = {pgid.scheme};
verifyTrue(testCase, all(ismember({'DOI', 'PMID', 'PMCID'}, schemes)));
cites = relByName(out.migrated, 'cites');
verifyEqual(testCase, depVal(cites, 'parent'), pub.get('base.id'));
% web_resource: the documentation IRI is a resource referenced by a relation
wr = firstOfClassJ(out.migrated, 'web_resource');
wgid = wr.get('entity.global_identifier');
verifyEqual(testCase, wgid(1).scheme, 'URL');
verifyEqual(testCase, wgid(1).value, 'https://example.org/docs');
documented = relByName(out.migrated, 'documented_by');
verifyEqual(testCase, depVal(documented, 'child'), ds.get('base.id'));
verifyEqual(testCase, depVal(documented, 'parent'), wr.get('base.id'));
end

function r = relByName(migrated, relName)
r = [];
for k = 1:numel(migrated)
    d = migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(d.get('directed_relation.relation').name, relName)
        r = d; return;
    end
end
end

% ============ dataset containers -> entity + relations (D-F) ============

function v1 = datasetRemoteDoc()
v1 = struct();
v1.document_class = struct('class_name', 'dataset_remote', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'dr_01', 'session_id', 'dsid_1', ...
    'name', 'remote', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.dataset_remote = struct('dataset_id', 'd-12345', 'organization_id', 'ndicloud-lab');
end

function testDatasetRemoteDissolves(testCase)
% dataset_remote -> bare dataset (keyed on D.id()=base.session_id) + web_resource
% (cloud id on global_identifier) + stored_at + organization + hosted_by.
out = runJ(datasetRemoteDoc());
bc = out.summary.by_class;
verifyEqual(testCase, bc.dataset, 1);
verifyEqual(testCase, bc.web_resource, 1);
verifyEqual(testCase, bc.organization, 1);
verifyEqual(testCase, bc.directed_relation, 2);   % stored_at + hosted_by
% the dataset entity is keyed on the dataset id, not the source doc id
ds = firstOfClassJ(out.migrated, 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'dsid_1');
% the cloud id rides on the web_resource's global_identifier
wr = firstOfClassJ(out.migrated, 'web_resource');
wgid = wr.get('entity.global_identifier');
verifyEqual(testCase, wgid(1).scheme, 'NDICloud');
verifyEqual(testCase, wgid(1).value, 'd-12345');
% dataset -stored_at-> web_resource ; web_resource -hosted_by-> organization
stored = relByName(out.migrated, 'stored_at');
verifyEqual(testCase, depVal(stored, 'child'), 'dsid_1');
verifyEqual(testCase, depVal(stored, 'parent'), wr.get('base.id'));
hosted = relByName(out.migrated, 'hosted_by');
verifyEqual(testCase, depVal(hosted, 'child'), wr.get('base.id'));
org = firstOfClassJ(out.migrated, 'organization');
verifyEqual(testCase, org.get('organization.name'), 'ndicloud-lab');
verifyEqual(testCase, depVal(hosted, 'parent'), org.get('base.id'));
end

function v1 = sessionInADatasetDoc(memberSession)
v1 = struct();
v1.document_class = struct('class_name', 'session_in_a_dataset', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'sid_01', 'session_id', 'dsid_1', ...
    'name', 'sid', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session_in_a_dataset = struct('session_id', memberSession, ...
    'session_reference', 'exp_demo', 'is_linked', 0, ...
    'session_creator', 'ndi.session.dir', 'session_creator_input1', 'exp_demo', ...
    'session_creator_input2', '', 'session_creator_input3', '', ...
    'session_creator_input4', '', 'session_creator_input5', '', ...
    'session_creator_input6', '');
end

function testSessionInADatasetMembership(testCase)
% -> bare dataset (id = base.session_id) + session -part_of-> dataset.
out = runJ(sessionInADatasetDoc('member_sess_9'));
bc = out.summary.by_class;
verifyEqual(testCase, bc.dataset, 1);
verifyEqual(testCase, bc.directed_relation, 1);
ds = firstOfClassJ(out.migrated, 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'dsid_1');
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'part_of');
verifyEqual(testCase, depVal(rel, 'child'), 'member_sess_9');   % the member session
verifyEqual(testCase, depVal(rel, 'parent'), 'dsid_1');          % the dataset
% the edge is tagged so the post-pass can prune it if the session is absent
verifyEqual(testCase, rel.get('base.name'), 'migrated_session_membership');
end

function testDatasetSessionInfoAggregate(testCase)
% the legacy AGGREGATE form: a nested dataset_session_info struct array, one
% entry per member session -> bare dataset + one part_of per member.
v1 = struct();
v1.document_class = struct('class_name', 'dataset_session_info', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'dsi_01', 'session_id', 'dsid_1', ...
    'name', 'dsi', 'datestamp', '2024-06-01T12:00:00.000Z');
e1 = struct('session_id', 'member_a', 'is_linked', 0);
e2 = struct('session_id', 'member_b', 'is_linked', 1);
v1.dataset_session_info = struct('dataset_session_info', [e1 e2]);
out = runJ(v1);
verifyEqual(testCase, out.summary.by_class.dataset, 1);
verifyEqual(testCase, out.summary.by_class.directed_relation, 2);   % two members
children = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation')
        verifyEqual(testCase, d.get('directed_relation.relation').name, 'part_of');
        verifyEqual(testCase, depVal(d, 'parent'), 'dsid_1');
        children{end+1} = depVal(d, 'child'); %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(children), {'member_a', 'member_b'});
end

function testResolveDatasetEntitiesDedupAndPrune(testCase)
% The batch post-pass: a rich metadata_editor dataset and a bare dataset_remote
% stub share the dataset id -> deduped to ONE (rich wins); a membership edge to
% an absent linked session is pruned so it never orphans the corpus.
editor = metadataEditorDoc();                 % base.session_id = sess_09
editor.base.session_id = 'dsid_1';            % put it on the same dataset id
remote = datasetRemoteDoc();                  % base.session_id = dsid_1 (bare stub)
member = sessionInADatasetDoc('absent_sess'); % member session NOT in the batch
batch = {jsonencode(editor), jsonencode(remote), jsonencode(member)};
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
% before the pass: >1 dataset entity on the shared id, and a membership edge
verifyGreaterThan(testCase, out.summary.by_class.dataset, 1);
out = did2.convert.resolveDatasetEntities(out, 'Validate', false, 'TargetVersion', 'V_eta');
% after: exactly one dataset entity on dsid_1, and it is the RICH one
datasets = {};
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), 'dataset')
        datasets{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(datasets), 1);
verifyEqual(testCase, datasets{1}.get('base.id'), 'dsid_1');
verifyEqual(testCase, datasets{1}.get('dataset.full_name'), 'The Big Worm Dataset');
% the unresolvable membership edge was pruned
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(d.get('directed_relation.relation').name, 'part_of')
        verifyNotEqual(testCase, depVal(d, 'child'), 'absent_sess');
    end
end
end

% ============ regression: relations carry no stale subject_relation block =====

function testDirectedRelationsHaveNoSubjectRelationBlock(testCase)
% subject_relation was renamed to `relation` (abstract, no fields) -> migrators
% must NOT emit a subject_relation property block, or the doc fails validation
% with "undeclared top-level block subject_relation" and quarantines (the JH
% 163k-orphan regression). Check the element + subject_group relation emitters.
outs = {runJ(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1')), ...
        runJ(subjectGroupWithMembers())};
for i = 1:numel(outs)
    for k = 1:numel(outs{i}.migrated)
        d = outs{i}.migrated{k};
        if strcmp(d.get('document_class.class_name'), 'directed_relation')
            verifyError(testCase, @() d.get('subject_relation'), ?MException, ...
                'a directed_relation still carries a subject_relation block');
            supers = d.get('document_class.superclasses');
            verifyEqual(testCase, supers(1).class_name, 'relation');
        end
    end
end
end

function v1 = subjectGroupWithMembers()
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id_1', 'subject_id_2'}, 'value', {'m_1', 'm_2'});
v1.base = struct('id', 'grp_9', 'session_id', 'aa_99', ...
    'name', 'cohortC', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortC', 'description', '');
end

function testDaqreaderNdrDeEncodesToDaqreader(testCase)
% Chunk c: daqreader_ndr de-encodes onto daqreader -- the ndr subtype fields move
% (ndr_reader_string -> reader_string, file_extension carried, ndi_daqreader_ndr_class
% dropped) and the daqreader_ndr block is removed. Tested on the migrator FUNCTION
% directly (the quick CI's V_zeta schema still has daqreader_ndr; under the V_eta
% corpus run daqreader_ndr is gone and the folded daqreader validates).
body = struct();
body.document_class = struct('class_name', 'daqreader_ndr', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',      'class_version', '1.0.0'), ...
                      struct('class_name', 'daqreader', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 'ndr_1', 'session_id', 'sess_09', ...
    'name', 'reader', 'datestamp', '2024-06-01T12:00:00.000Z');
body.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.mfdaq.ndr');
body.daqreader_ndr = struct('ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr', ...
    'ndr_reader_string', 'intan', 'file_extension', '.rhd');
out = did2.convert.migrators_j.daqreader_ndr(body);
verifyEqual(testCase, out.document_class.class_name, 'daqreader');
verifyEqual(testCase, out.daqreader.reader_string, 'intan');
verifyEqual(testCase, out.daqreader.file_extension, '.rhd');
verifyEqual(testCase, out.daqreader.ndi_daqreader_class, 'ndi.daq.reader.mfdaq.ndr');
% the subtype block is gone
verifyFalse(testCase, isfield(out, 'daqreader_ndr'));
end

function testMfdaqIngestedDeEncodesToDaqreaderEpochdataIngested(testCase)
% Chunk b/c: daqreader_mfdaq_epochdata_ingested de-encodes onto the generic
% daqreader_epochdata_ingested -- the mfdaq subtype `parameters` block moves onto
% the parent (kept), the mfdaq block is removed, and the stale inline `epochid`
% block is dropped (dep-only; the epoch link is the epochid dep). Tested on the
% migrator FUNCTION directly (the quick CI's V_zeta schema still has the class;
% under the V_eta corpus run the class is gone and the folded parent validates).
body = struct();
body.document_class = struct('class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'daqreader_epochdata_ingested', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'daqreader_id'}, 'value', {'dr_1'});
body.base = struct('id', 'mfdaq_1', 'session_id', 'sess_09', ...
    'name', 'ingested', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0, 10]));
body.daqreader_mfdaq_epochdata_ingested = struct('parameters', ...
    struct('sample_analog_segment', 1000000, 'sample_digital_segment', 1000000));
out = did2.convert.migrators_j.daqreader_mfdaq_epochdata_ingested(body);
verifyEqual(testCase, out.document_class.class_name, 'daqreader_epochdata_ingested');
% the mfdaq `parameters` de-encoded onto the parent, epochtable preserved
verifyEqual(testCase, out.daqreader_epochdata_ingested.parameters.sample_analog_segment, 1000000);
verifyTrue(testCase, isfield(out.daqreader_epochdata_ingested, 'epochtable'));
% the subtype block is gone; the stale inline epochid block is dropped (dep-only)
verifyFalse(testCase, isfield(out, 'daqreader_mfdaq_epochdata_ingested'));
verifyFalse(testCase, isfield(out, 'epochid'));
end

function testElementEpochRenamedToAcquisitionEpoch(testCase)
% Chunk e: element is retired, so element_epoch is renamed to acquisition_epoch.
% The V_eta migrator reuses the base clocks-block transform (epoch_clock/t0_t1 ->
% clocks array-of-records) and then renames the class and its property block.
body = struct();
body.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_1'});
body.base = struct('id', 'ee_1', 'session_id', 'sess_09', ...
    'name', 't00001', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0; 930.35]);
out = did2.convert.migrators_j.element_epoch(body);
verifyEqual(testCase, out.document_class.class_name, 'acquisition_epoch');
% the property block is renamed too, and the base clocks transform ran
verifyTrue(testCase, isfield(out, 'acquisition_epoch'));
verifyFalse(testCase, isfield(out, 'element_epoch'));
verifyEqual(testCase, out.acquisition_epoch.clocks(1).name, 'dev_local_time');
verifyEqual(testCase, out.acquisition_epoch.clocks(1).t0, 0);
verifyEqual(testCase, out.acquisition_epoch.clocks(1).t1, 930.35);
end

function testPyraviewFoldsToObservationPlusSampledBody(testCase)
% #9 pattern-setter: pyraview (a multi-resolution signal pyramid) dissolves into a
% body-backed dataseries_observation + a sampled_body (native signal) + a session
% anchor. 1->3. The decimated levels are dropped (regenerable cache).
body = struct();
body.document_class = struct('class_name', 'pyraview', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'filter',  'class_version', '1.0.0'), ...
                      struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_7'});
body.base = struct('id', 'pv_1', 'session_id', 'sess_09', ...
    'name', 'pyr', 'datestamp', '2024-06-01T12:00:00.000Z');
body.pyraview = struct('label', 'lfp', 'native_rate', 1000, ...
    'native_start_time', 0, 'channels', 4, 'data_type', 'int16');

out = did2.convert.migrators_j.pyraview(body);
verifyClass(testCase, out, 'cell');
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'dataseries_observation')));
verifyTrue(testCase, any(strcmp(names, 'sampled_body')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));

obs  = out{find(strcmp(names, 'dataseries_observation'), 1)};
sbod = out{find(strcmp(names, 'sampled_body'), 1)};
% the observation keeps the source id and is body-backed
verifyEqual(testCase, obs.base.id, 'pv_1');
verifyEqual(testCase, obs.subject_statement.storage_mode, 'body');
verifyEqual(testCase, obs.subject_statement.variable.name, 'lfp');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_7');
% the body carries the signal and points back at the observation
verifyEqual(testCase, depValue(sbod, 'statement'), 'pv_1');
verifyEqual(testCase, sbod.sampled_body.datum.dtype, 'int16');
verifyEqual(testCase, sbod.sampled_body.sample_time.dt.source_value, 1e-3);
end

function v = depValue(b, name)
v = '';
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, name); v = b.depends_on(k).value; return; end
end
end
