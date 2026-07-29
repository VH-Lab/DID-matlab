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
verifyEqual(testCase, a.get('term.value').node, 'NCBITaxon:6239');
verifyEqual(testCase, a.get('term.value').name, 'Caenorhabditis elegans');
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
verifyEqual(testCase, a.get('term.value').node, 'X:1');
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
verifyEqual(testCase, act.get('term.value').name, 'embryonic tissue');
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

function testOntologyTableRowPreservesSourceIdOnFirstBody(testCase)
% The row dissolves 1 -> N. Exactly ONE emitted body must keep the source id,
% otherwise anything pointing at the row (an ontologyImage names it via
% ontologyTableRow_id and follows it to reach its subject) is left pointing at
% an id that no longer exists. There is no old-id -> new-id map in the
% converter, so preservation is the only thing that can make such an edge
% resolve. Same lesson as the calculator fold (T10).
out = runJ(tableRow());
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_01')), 1, ...
    'exactly one emitted body must carry the source id');
verifyEqual(testCase, out.migrated{1}.get('base.id'), 'otr_01', ...
    'the first emitted body is the one that carries it');
% and the siblings must NOT collide with it or each other
verifyEqual(testCase, numel(unique(ids)), numel(ids), 'emitted ids must be unique');
end

function testEncounterMapPreservesSourceId(testCase)
% Same requirement on the per-table map path, which previously minted a fresh
% id for every body it emitted.
out = runJ(encounterRow());
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_enc')), 1);
verifyEqual(testCase, numel(unique(ids)), numel(ids));
end

function testPatchGeometryMapDoesNotDoubleStampSourceId(testCase)
% makePatchSubject ALREADY preserves the id deliberately (the encounter
% relation names that document as its parent). Stamping again would mint two
% documents sharing one id, so the preservation step must detect it and leave
% it alone.
out = runJ(patchGeometryRow());
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_patch')), 1, ...
    'the id must be carried exactly once, not stamped twice');
verifyEqual(testCase, numel(unique(ids)), numel(ids));
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
verifyEqual(testCase, term.get('term.value').name, 'Startle 95 dB');
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
verifyEqual(testCase, m.get('term.value').name, 'craniotomy');
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
verifyEqual(testCase, site.get('term.value').node, 'uberon:0002436');
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
verifyEqual(testCase, site.get('term.value').node, 'uberon:0002436');
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
verifyEqual(testCase, site.get('term.value').node, 'uberon:0002436');
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
verifyEqual(testCase, o.get('term.value').node, 'uberon:0002436');
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
verifyEqual(testCase, o.get('term.value').node, 'allen_ccf_v3:12345');
verifyEqual(testCase, o.get('term.value').name, 'primary visual cortex');
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
% the raster CELL: image now matches the single-`value` convention every other
% data_type follows -- ONE payload slot holding the pixels plus the descriptors
% needed to read them (dtype is not recoverable from a bare matrix, R6 dec. 4).
imageCell = obs.get('image.value');
verifyEqual(testCase, imageCell.dtype, 'uint16');
verifyEmpty(testCase, imageCell.pixels);          % storage_mode:body -> pixels in the body
verifyEqual(testCase, numel(imageCell.axes), 5);  % YXCZT, the full N-D calibration
verifyEqual(testCase, imageCell.axes(1).name, 'Y');
verifyEqual(testCase, imageCell.axes(1).length, 512);
verifyEqual(testCase, imageCell.axes(1).spacing, 0.5);
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
verifyEqual(testCase, locObs.get('term.value').name, 'CNS');
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
ms.VersionInnovation = 'first release';        % bucket 1 (dataset metadata) -> kept
ms.Keyword = {'worm', 'calcium imaging'};      % bucket 1 (repeatable) -> kept
ms.ExperimentalApproach = {'electrophysiology', 'behavior'};  % bucket 2 projection -> not stored
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
% dataset + 2 persons + 2 orgs (deduped) + 1 funding + 1 publication + 1 web_resource
% + 8 relations (has_author x2, affiliated_with x2, funded_by, issued_by, cites,
%   documented_by) = 16
verifyEqual(testCase, numel(out.migrated), 16);
verifyEqual(testCase, bc.dataset, 1);
verifyEqual(testCase, bc.person, 2);
verifyEqual(testCase, bc.organization, 2);   % Analytical Society (deduped) + NIH
verifyEqual(testCase, bc.funding, 1);
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
% openMINDS DatasetVersion fields with homes -> stored, not dropped
verifyEqual(testCase, ds.get('dataset.version_innovation'), 'first release');
kw = ds.get('dataset.keyword');
verifyEqual(testCase, sort(kw(:)'), {'calcium imaging', 'worm'});
% experimental_approach is a per-subject PROJECTION -> NOT populated on migration
% (the field stays for openMINDS import; the did_v1 blob's value is not stored)
dsb = ds.get('dataset');
verifyFalse(testCase, isfield(dsb, 'experimental_approach') ...
    && ~isempty(dsb.experimental_approach));
% documentation is NOT a dataset field -- it is a relation -> web_resource
verifyFalse(testCase, isfield(dsb, 'documentation'));
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
names = cellfun(@(o) o.get('organization.full_name'), orgs, 'UniformOutput', false);
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
% funding: title + award-number identifier; dataset -funded_by-> funding -issued_by-> NIH
award = firstOfClassJ(out.migrated, 'funding');
verifyEqual(testCase, award.get('funding.title'), 'BRAIN Initiative');
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
verifyEqual(testCase, org.get('organization.full_name'), 'ndicloud-lab');
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

function testDistanceMetadataReshapesFlatEndpoints(testCase)
% The v1 distance_metadata is FLAT (ontologyNode_A/_B, integerIDs_A/_B,
% ontologyStringValues_A/_B, ontologyNumericValues_A/_B empty by design, units).
% The J migrator reshapes it into the nested `endpoints` array the V_eta schema
% requires -- 1 -> 1. It does NOT emit a length_observation (no scalar distance in
% the metadata doc; the value is the linked element's timeseries -- deferred Part
% B) and does NOT mint an endpoint relation (the endpoint ids are pre-migration
% ids that dangle single-doc -- Part A reverted). See
% schemas/V_eta_distance_metadata_plan.md.
v1 = struct();
v1.document_class = struct('class_name', 'distance_metadata', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'dm_1', 'session_id', 'sess_09', ...
    'name', 'dm', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.distance_metadata = struct( ...
    'ontologyNode_A', 'animal_9',   'integerIDs_A', 1, ...
    'ontologyNumericValues_A', [],  'ontologyStringValues_A', 'uid_a1,uid_a2', ...
    'ontologyNode_B', 'patch_9',    'integerIDs_B', [2 3], ...
    'ontologyNumericValues_B', [],  'ontologyStringValues_B', 'uid_b1', ...
    'units', 'NCIT:C48367');

out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.className(), 'distance_metadata');

blk = doc.get('distance_metadata');
% two endpoint records, labelled A and B, in order
verifyEqual(testCase, numel(blk.endpoints), 2);
verifyEqual(testCase, blk.endpoints(1).label, 'A');
verifyEqual(testCase, blk.endpoints(2).label, 'B');
% the ontologyNode CURIE -> measurement.node; comma-split string ids -> array
verifyEqual(testCase, blk.endpoints(1).measurement.node, 'animal_9');
verifyEqual(testCase, blk.endpoints(2).measurement.node, 'patch_9');
verifyEqual(testCase, numel(blk.endpoints(1).string_ids), 2);
verifyEqual(testCase, blk.endpoints(2).integer_ids, [2 3]);
% units CURIE -> ontology_term node
verifyEqual(testCase, blk.units.node, 'NCIT:C48367');
% the flat per-endpoint fields are gone (strict schema: only endpoints + units)
verifyFalse(testCase, isfield(blk, 'ontologyNode_A'));
verifyFalse(testCase, isfield(blk, 'ontology_node_a'));
% NOT a length_observation and no endpoint relation minted (single-doc)
names = cellfun(@(d) d.className(), out.migrated, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'length_observation')));
verifyFalse(testCase, any(strcmp(names, 'directed_relation')));
end

function testPyraviewFoldsToObservationPlusSampledBody(testCase)
% #9 pattern-setter: pyraview (a multi-resolution signal pyramid) dissolves into a
% body-backed voltage_observation + a sampled_body (native signal) + a session
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
    'native_start_time', 0, 'channels', 4, 'data_type', 'int16', ...
    'decimation_sampling_rates', [1000 500]);
body.files = struct('file_list', {{'level1.bin', 'level2.bin'}});

out = did2.convert.migrators_j.pyraview(body);
verifyClass(testCase, out, 'cell');
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'voltage_observation')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));
% ONE sampled_body per stored level (2 here) -> 1 obs + 2 bodies + 1 anchor
sbods = out(strcmp(names, 'sampled_body'));
verifyEqual(testCase, numel(sbods), 2);

obs = out{find(strcmp(names, 'voltage_observation'), 1)};
verifyEqual(testCase, obs.base.id, 'pv_1');
verifyEqual(testCase, obs.subject_statement.storage_mode, 'body');
verifyEqual(testCase, obs.subject_statement.variable.name, 'lfp');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_7');
% every level body shares the statement (the observation) and owns one file;
% levels are told apart by dt (native 1/1000 vs decimated 1/500)
for j = 1:numel(sbods)
    verifyEqual(testCase, depValue(sbods{j}, 'statement'), 'pv_1');
    verifyEqual(testCase, sbods{j}.sampled_body.datum.dtype, 'int16');
    verifyEqual(testCase, numel(sbods{j}.files.file_list), 1);
end
dts = sort(cellfun(@(b) b.sampled_body.sample_time.dt.source_value, sbods));
verifyEqual(testCase, dts, [1e-3 2e-3], 'AbsTol', 1e-9);
end

function testSpikewavesFoldsToObservationPlusSampledBody(testCase)
% #9 (direct-subject binary fold, pyraview-twin): spikewaves -> a body-backed
% voltage_observation + a sampled_body (one datum per spike) + anchor. 1->3.
body = struct();
body.document_class = struct('class_name', 'spikewaves', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_5'), ...
                    struct('name', 'spike_extraction_parameters_id', 'value', 'sep_1')];
body.base = struct('id', 'sw_1', 'session_id', 'sess_09', ...
    'name', 'sw', 'datestamp', '2024-06-01T12:00:00.000Z');
body.spikewaves = struct('extraction_name', 'thresh_5sd', ...
    'num_spikes', 120, 'samples_per_spike', 32, 'sample_rate', 30000);
body.files = struct('file_list', {{'spikewaves.vsw', 'spiketimes.bin'}});

out = did2.convert.migrators_j.spikewaves(body);
verifyClass(testCase, out, 'cell');
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'voltage_observation')));
verifyTrue(testCase, any(strcmp(names, 'sampled_body')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));

obs  = out{find(strcmp(names, 'voltage_observation'), 1)};
sbod = out{find(strcmp(names, 'sampled_body'), 1)};
verifyEqual(testCase, obs.base.id, 'sw_1');
verifyEqual(testCase, obs.subject_statement.storage_mode, 'body');
verifyEqual(testCase, obs.subject_statement.variable.name, 'thresh_5sd');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_5');
verifyEqual(testCase, depValue(sbod, 'statement'), 'sw_1');
% one datum per spike: n = num_spikes, datum shape = samples_per_spike
verifyEqual(testCase, sbod.sampled_body.sample_time.n, 120);
verifyEqual(testCase, sbod.sampled_body.datum.shape, 32);
verifyEqual(testCase, numel(sbod.files.file_list), 2);
end

function testBinnedSpikeRateFoldsToObservationPlusSampledBody(testCase)
% #9 (direct-subject regular timeseries): binnedspikeratevm -> frequency_observation
% + a sampled_body (one scalar rate per bin; regular, dt = bin_size) + anchor.
body = struct();
body.document_class = struct('class_name', 'binnedspikeratevm', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_3'});
body.base = struct('id', 'br_1', 'session_id', 'sess_09', ...
    'name', 'br', 'datestamp', '2024-06-01T12:00:00.000Z');
body.binnedspikeratevm = struct('bin_size', 0.05, 'num_bins', 600);
body.files = struct('file_list', {{'rate.bin'}});

out = did2.convert.migrators_j.binnedspikeratevm(body);
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'frequency_observation')));
sbod = out{find(strcmp(names, 'sampled_body'), 1)};
verifyEqual(testCase, depValue(sbod, 'statement'), 'br_1');
verifyEqual(testCase, sbod.sampled_body.datum.kind, 'scalar');
verifyEqual(testCase, sbod.sampled_body.sample_time.n, 600);
% bin_size (raw seconds) -> a duration composite dt
verifyEqual(testCase, sbod.sampled_body.sample_time.dt.source_value, 0.05, 'AbsTol', 1e-12);
end

function testVmspikesummaryDecomposesToInlineScalarObservations(testCase)
% #9 scalar-decomposition pattern: vmspikesummary -> one INLINE quantity
% observation per summary scalar (voltage/frequency/count/duration) + a shared
% anchor. 1 -> (N+1). Values are inline (storage_mode 'inline').
body = struct();
body.document_class = struct('class_name', 'vmspikesummary', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_2'});
body.base = struct('id', 'vs_1', 'session_id', 'sess_09', ...
    'name', 'vs', 'datestamp', '2024-06-01T12:00:00.000Z');
body.vmspikesummary = struct('mean_vm', -62.5, 'mean_firing_rate', 8.3, ...
    'num_spikes', 249, 'recording_duration', 30.0);

out = did2.convert.migrators_j.vmspikesummary(body);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
% 4 scalar observations + 1 anchor
verifyEqual(testCase, numel(out), 5);
for want = {'voltage_observation', 'frequency_observation', 'count_observation', ...
        'duration_observation', 'session_relative_reference'}
    verifyTrue(testCase, any(strcmp(names, want{1})), want{1});
end
volt = out{find(strcmp(names, 'voltage_observation'), 1)};
verifyEqual(testCase, volt.subject_statement.storage_mode, 'inline');
verifyEqual(testCase, depValue(volt, 'subject_id'), 'sub_2');
verifyEqual(testCase, volt.voltage.value.source_value, -62.5, 'AbsTol', 1e-9);
freq = out{find(strcmp(names, 'frequency_observation'), 1)};
verifyEqual(testCase, freq.frequency.value.source_value, 8.3, 'AbsTol', 1e-9);
end

function testContrastTuningFoldsToCalculationLeaf(testCase)
% Calculator composite-leaf model (Lepsky et al.): contrast_tuning -> the leaf
% contrast_tuning_calculation (id-preserved) + a session anchor. 1 -> 2. The result
% is kept verbatim as the composite value; base.id + depends_on preserved; the raw
% stimulus_tuningcurve becomes derived_from_1. Supersedes the grain-A decomposition.
body = struct();
body.document_class = struct('class_name', 'contrast_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'ct_1', 'session_id', 'sess_09', 'name', 'ct', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.contrast_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s', 'response_type', 'mean'), ...
    'tuning_curve', struct('contrast', [0 0.25 0.5 1], 'mean', [2 5 9 12]));

out = did2.convert.migrators_j.contrast_tuning(body);
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));   % not decomposed
leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'ct_1');                          % id preserved
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'sub_8');
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.calc.vis.contrast');
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'tc_1');
% the structured result kept verbatim as the composite value
verifyEqual(testCase, leaf.tuning_curve.value.response_mean, [2 5 9 12]);
verifyEqual(testCase, leaf.subject_statement.storage_mode, 'inline');
end

function testOrientationDirectionTuningFoldsToCalculationLeaf(testCase)
% Calculator composite-leaf model (Lepsky et al.): orientation_direction_tuning ->
% the subject_calculation LEAF orientation_direction_tuning_calculation
% (id-preserved) + a session anchor. 1 -> 2. The structured result is kept VERBATIM
% as the composite value; base.id + depends_on preserved so downstream refs resolve;
% the raw stimulus_tuningcurve becomes derived_from_1; the algorithm names the
% method. Supersedes the earlier grain-A decomposition into observations.
body = struct();
body.document_class = struct('class_name', 'orientation_direction_tuning', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_1'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'odt_1', 'session_id', 'sess_09', 'name', 'odt', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5, 'circular_variance', 0.3), ...
    'significance', struct('visual_response_anova_p', 0.002), ...
    'fit', struct('hwhh', 22.0));

out = did2.convert.migrators_j.orientation_direction_tuning(body);
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));
% NOT decomposed into observations any more (calculators are composite leafs now)
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));
verifyFalse(testCase, any(strcmp(names, 'angle_observation')));

leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'odt_1');                               % id preserved
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'neuron_1');           % neuron carried
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.calc.vis.oridir');
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'tc_1');           % provenance
verifyNotEmpty(testCase, depValue(leaf, 'time_reference_1'));              % session anchor
verifyEqual(testCase, leaf.subject_statement.storage_mode, 'inline');
% the structured result kept VERBATIM as the composite value
verifyEqual(testCase, leaf.tuning_curve.value.independent_values, [0 90 180 270]);
verifyEqual(testCase, leaf.tuning_curve.value.circular_statistics.orientation_preference, ...
    47.5, 'AbsTol', 1e-9);
end

function testOridirtuningCalcUndefersToLeaf(testCase)
% The ndi.calc.vis.oridir calculator OUTPUT document (oridirtuning_calc, currently a
% deferred passthrough) un-defers 1 -> 1, id-preserved, into the SAME leaf as its
% result sibling. This is where the calculator provenance actually lands:
% input_parameters -> method_parameters, the app block kept, the raw
% stimulus_tuningcurve -> derived_from_1, and the result composite verbatim.
body = struct();
body.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'orientation_direction_tuning'; 'tuning_fit'}, ...
                           'class_version', {'1.0.0'; '1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_9'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_9')];
body.base = struct('id', 'oc_1', 'session_id', 'sess_09', 'name', 'oc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.oridir', 'version', '1.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.oridirtuning_calc = struct('input_parameters', ...
    struct('independent_variable', 'direction'));
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5));

out = did2.convert.migrators_j.oridirtuning_calc(body);
verifyEqual(testCase, numel(out), 3);   % leaf + session anchor + software entity
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'oc_1');                                % id preserved
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'neuron_9');
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'tc_9');
% input_parameters -> method_parameters
verifyEqual(testCase, leaf.subject_interaction.method_parameters.independent_variable, ...
    'direction');
% app -> a software ENTITY referenced by software_id; per-run env on the interaction
sw = out{find(strcmp(names, 'software'), 1)};
verifyEqual(testCase, sw.software.name, 'ndi.calc.vis.oridir');
verifyEqual(testCase, sw.software.version, '1.2');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
verifyEqual(testCase, leaf.subject_interaction.execution_environment.interpreter, 'MATLAB');
% the result composite kept verbatim
verifyEqual(testCase, leaf.tuning_curve.value.circular_statistics.orientation_preference, ...
    47.5, 'AbsTol', 1e-9);
end

function testContrastSensitivityCalcUndefersToLeaf(testCase)
% The aggregate ndi.calc.vis.contrast_sensitivity output (a flat bag of matrices on
% its own block, NO result-composite superclass) un-defers 1 -> 1, id-preserved, into
% contrast_sensitivity_calculation (a newly-authored composite). It HAS element_id ->
% single-doc fold; the result fields move to the composite block (input_parameters
% stripped -> method_parameters); app kept; raw responses -> derived_from_1.
body = struct();
body.document_class = struct('class_name', 'contrast_sensitivity_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'calculator'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_cs'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_cs')];
body.base = struct('id', 'cs_1', 'session_id', 'sess_09', 'name', 'cs', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.contrast_sensitivity', 'version', '1.0', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.contrast_sensitivity_calc = struct('spatial_frequencies', [0.5 1 2 4], ...
    'sensitivity_rb', [10 20 15 5], 'empirical_c50_rb', [0.2 0.3 0.4 0.5], ...
    'parameters_rb', [12 0.25 2], ...
    'sensitivity_rbns', [9 18 14 4], 'parameters_rbns', [11 0.27 2.1], ...
    'fitless_interpolated_c50', [0.21 0.31 0.41 0.51], ...
    'visual_response_p_bonferroni', [0.01 0.02 0.03 0.04], ...
    'is_modulated_response', 1, 'response_type', 'mean', ...
    'input_parameters', struct('threshold', 1));

out = did2.convert.migrators_j.contrast_sensitivity_calc(body);
verifyEqual(testCase, numel(out), 3);   % leaf + session anchor + software entity
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'contrast_sensitivity_calculation')));
leaf = out{find(strcmp(names, 'contrast_sensitivity_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'cs_1');                                % id preserved
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'neuron_cs');          % element_id -> subject
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'resp_cs');
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.calc.vis.contrast_sensitivity');
% input_parameters -> method_parameters, and stripped from the composite block
verifyEqual(testCase, leaf.subject_interaction.method_parameters.threshold, 1);
verifyFalse(testCase, isfield(leaf.contrast_sensitivity, 'input_parameters'));
% the flat v1 bag is RESHAPED onto the `value` cell: RB/RBN/RBNS are Naka-Rushton fit
% VARIANTS, so each becomes one model_fit entry carrying its own coefficients and the
% per-spatial-frequency metrics derived from that fit (T11: the variant is no longer a
% field-name suffix). Absent variants produce no entry -- rbn is missing here.
csv = leaf.contrast_sensitivity.value;
verifyEqual(testCase, csv.spatial_frequencies, [0.5 1 2 4]);
verifyEqual(testCase, numel(csv.model_fit), 2);            % rb and rbns, not rbn
models = arrayfun(@(e) e.model.name, csv.model_fit, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(models, 'naka_rushton_rb')));
verifyTrue(testCase, any(strcmp(models, 'naka_rushton_rbns')));
verifyFalse(testCase, any(strcmp(models, 'naka_rushton_rbn')));
rb = csv.model_fit(strcmp(models, 'naka_rushton_rb'));
verifyEqual(testCase, rb.sensitivity, [10 20 15 5]);       % metric rides INSIDE its fit
verifyEqual(testCase, rb.empirical_c50, [0.2 0.3 0.4 0.5]);
verifyEqual(testCase, rb.coefficients, [12 0.25 2]);       % was parameters_rb (T13)
% fit-less and significance scalars stay TYPED sub-blocks, not a {name,value} bag
verifyEqual(testCase, csv.interpolated_values.c50, [0.21 0.31 0.41 0.51]);
verifyEqual(testCase, csv.significance.visual_response_p_bonferroni, [0.01 0.02 0.03 0.04]);
verifyTrue(testCase, csv.is_modulated_response);
verifyEqual(testCase, csv.response_type, 'mean');
% the old flat suffixed fields are gone from the composite
verifyFalse(testCase, isfield(leaf.contrast_sensitivity, 'sensitivity_rb'));
% app -> a software ENTITY referenced by software_id
sw = out{find(strcmp(names, 'software'), 1)};
verifyEqual(testCase, sw.software.name, 'ndi.calc.vis.contrast_sensitivity');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
end

function testTuningcurveCalcUndefersToLeaf(testCase)
% The ndi.calc.stimulus.tuningcurve calculator OUTPUT (tuningcurve_calc) un-defers
% 1 -> 1, id-preserved, into the stimulus_tuningcurve_calculation leaf. Contrary to
% an earlier belief, this doc HAS a populated element_id (tuningcurve_calc IS-A
% stimulus_tuningcurve, whose element_id the writer sets), so the fold is single-doc:
% element_id -> subject_id; the tuning-curve result sits on the inherited
% stimulus_tuningcurve block (kept verbatim); the calc block's input_parameters ->
% method_parameters; app kept; the raw stimulus_response_scalar -> derived_from_1.
body = struct();
body.document_class = struct('class_name', 'tuningcurve_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'stimulus_tuningcurve'}, ...
        'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_tc'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_tc')];
body.base = struct('id', 'tcc_1', 'session_id', 'sess_11', 'name', 'tc', ...
    'datestamp', '2024-07-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.stimulus.tuningcurve', 'version', '1.0', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', 'contrast', ...
    'independent_variable_value', [0 0.25 0.5 1], ...
    'response_mean', [1 4 8 11], 'response_units', 'Spikes/s');
body.tuningcurve_calc = struct('log', 'ok', ...
    'input_parameters', struct('best_algorithm', 'empirical_maximum'));

out = did2.convert.migrators_j.tuningcurve_calc(body);
verifyEqual(testCase, numel(out), 3);   % leaf + session anchor + software entity
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'tcc_1');                          % id preserved
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'neuron_tc');      % element_id -> subject
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'resp_tc');
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.calc.stimulus.tuningcurve');
% input_parameters (on the calc block) -> method_parameters
verifyEqual(testCase, leaf.subject_interaction.method_parameters.best_algorithm, 'empirical_maximum');
% the tuning-curve result kept verbatim as the composite value
verifyEqual(testCase, leaf.tuning_curve.value.response_mean, [1 4 8 11]);
% the independent-variable LABEL rides subject_statement.variable now (T11), not a
% carried curve field; the tuning_curve value holds the numeric curve only.
verifyEqual(testCase, leaf.document_class.class_name, 'tuning_curve_calculation');
% app -> a software ENTITY referenced by software_id; per-run env on the interaction
sw = out{find(strcmp(names, 'software'), 1)};
verifyEqual(testCase, sw.software.name, 'ndi.calc.stimulus.tuningcurve');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
verifyEqual(testCase, leaf.subject_interaction.execution_environment.os, 'Linux');
end

function testStimulusTuningcurveRawFoldsToCalculationLeaf(testCase)
% A raw ndi.app.stimulus.tuning_response tuning curve (pre-calculator-framework
% stimulus_tuningcurve) folds to the SAME leaf as tuningcurve_calc, so downstream
% stimulus_tuningcurve_id refs resolve to either. Single-doc: element_id -> subject_id;
% result kept verbatim; no calc input_parameters/app (method_parameters/app empty);
% raw stimulus_response_scalar -> derived_from_1.
body = struct();
body.document_class = struct('class_name', 'stimulus_tuningcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_rt'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_rt')];
body.base = struct('id', 'stc_1', 'session_id', 'sess_11', 'name', 'rawtc', ...
    'datestamp', '2024-07-01T12:00:00.000Z');
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', 'direction', ...
    'independent_variable_value', [0 90 180 270], ...
    'response_mean', [10 2 9 3], 'response_units', 'Spikes/s');

out = did2.convert.migrators_j.stimulus_tuningcurve(body);
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'stc_1');                          % id preserved
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'neuron_rt');      % element_id -> subject
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'resp_rt');
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.app.stimulus.tuning_response');
verifyEqual(testCase, leaf.tuning_curve.value.response_mean, [10 2 9 3]);
% no calculator provenance on a raw doc -> empty method_parameters, no software entity,
% no software_id edge (the app block is absent, so nothing to mint)
verifyTrue(testCase, isempty(fieldnames(leaf.subject_interaction.method_parameters)));
verifyEqual(testCase, numel(out), 2);   % leaf + anchor only; no software body
verifyTrue(testCase, isempty(depValue(leaf, 'software_id')));
end

function d = firstByVariable(migrated, varName)
d = [];
for k = 1:numel(migrated)
    m = migrated{k};
    if isfield(m, 'subject_statement') && isfield(m.subject_statement, 'variable') ...
            && strcmp(m.subject_statement.variable.name, varName)
        d = m; return;
    end
end
end

function testSpeedTuningFoldsToCalculationLeaf(testCase)
% Calculator composite-leaf model: speed_tuning -> the leaf speed_tuning_calculation
% (id-preserved) + a session anchor. 1 -> 2. The (SF, TF, mean) result is kept
% verbatim as the composite value. Supersedes the derived-speed-axis decomposition.
body = struct();
body.document_class = struct('class_name', 'speed_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_s'});
body.base = struct('id', 'sp_1', 'session_id', 'sess_09', 'name', 'sp', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.speed_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('spatial_frequency', [0.5 0.5 1], ...
        'temporal_frequency', [2 4 4], 'mean', [5 8 6]));

out = did2.convert.migrators_j.speed_tuning(body);
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));
leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'sp_1');
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'sub_s');
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.calc.vis.speed');
verifyEqual(testCase, leaf.tuning_curve.value.response_mean, [5 8 6]);
end

function v1 = ontologyImageVintageA()
% VINTAGE A (legacy, DID-schema V_alpha/V_beta ancestry): the region is two
% coordinated chars and `element_id` supplies the subject. Shape taken from
% schemas/V_alpha/ontologyImage.json, NOT from our own V_eta schema.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'oi_1', 'session_id', 'sess_09', 'name', 'oi', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_name', 'uberon:0002436', ...
    'ontology_region', 'primary visual cortex');
end

function v1 = ontologyImageVintageB()
% VINTAGE B (current NDI production): `ontology_nodes` is a comma-joined list
% of CURIEs and the only edge is `ontology_table_row_id` -- NOT a subject.
% Shape taken from NDI's ndi_common/database_documents/data/ontologyImage.json
% plus +ndi/+setup/+NDIMaker/imageDocMaker (which writes the PLURAL key).
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'ngrid'}, 'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'ontology_table_row_id'}, 'value', {'otr_3'});
v1.base = struct('id', 'oi_2', 'session_id', 'sess_09', 'name', 'oi', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_nodes', 'uberon:0000955,uberon:0002436');
v1.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', [1;2;3;4;1;2;3;4]);
end

function testOntologyImageVintageABecomesTermObservation(testCase)
% VINTAGE A is fully resolvable single-doc: term from the two coordinated
% chars, subject from element_id. 1 -> 2 (observation + session anchor).
out = did2.convert.migrators_j.ontology_image(ontologyImageVintageA());
verifyEqual(testCase, numel(out), 2);
o = out{1};
verifyEqual(testCase, o.document_class.class_name, 'term_observation');
verifyEqual(testCase, o.subject_statement.variable.name, 'imaged region');
verifyEqual(testCase, o.term.value.node, 'uberon:0002436');
verifyEqual(testCase, o.term.value.name, 'primary visual cortex');
verifyEqual(testCase, depValue(o, 'subject_id'), 'elem_9');
end

function testOntologyImageVintageBPassesThroughForSecondPass(testCase)
% VINTAGE B is DEFERRED: its only edge is a table row, not a subject, so the
% subject needs the migrated-id graph. The document must pass through INTACT
% (ngrid block and all) so the NDI second pass can decompose it -- and must
% NOT become a term_observation with an empty subject_id.
v1 = ontologyImageVintageB();
out = did2.convert.migrators_j.ontology_image(v1);
verifyEqual(testCase, numel(out), 1);
o = out{1};
verifyEqual(testCase, o.document_class.class_name, 'ontology_image');
verifyEqual(testCase, o.ontology_image.ontology_nodes, 'uberon:0000955,uberon:0002436');
% the raster block must survive for the second pass. NOTE: this calls the
% migrator directly, so `coordinates` is still present here -- in the real
% pipeline the ngrid SUPERCLASS migrator runs first and deletes it. That
% deletion is a known, separate data loss (see V_eta_ngrid_family_findings.md);
% this assertion only proves THIS migrator strips nothing.
verifyTrue(testCase, isfield(o, 'ngrid'));
verifyEqual(testCase, o.ngrid.coordinates, [1;2;3;4;1;2;3;4]);
% and no husk observation was minted
verifyFalse(testCase, isfield(o, 'subject_statement'));
end

function testOntologyImageRejectsVDeltaRegionShape(testCase)
% THE GUARD. `region` is the V_delta migrator's OUTPUT, not a did_v1 field.
% The previous implementation read it, so it matched only a fixture built to
% our own schema and silently emitted an empty observation about nobody.
% Reading it again must be loud, not silent.
v1 = ontologyImageVintageA();
v1.ontology_image = struct('region', ...
    struct('node', 'uberon:0002436', 'name', 'primary visual cortex'));
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ontologyImageVDeltaShape');
end

function testOntologyImageRejectsUnknownShape(testCase)
% A block matching no known vintage must quarantine rather than migrate to a
% content-free husk (an empty ontology_term still has fieldnames, so it
% satisfies mustBeNonEmpty, and an empty depends_on edge is skipped by
% did2.validate.references -- neither gate would have caught it).
v1 = ontologyImageVintageA();
v1.ontology_image = struct('something_else', 'x');
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ontologyImageUnknownShape');
end

function testElectrodeOffsetVoltageBecomesVoltageObservation(testCase)
% electrode_offset_voltage -> a voltage_observation whose INLINE value is the
% per-channel offsets (one measurement per channel) about the probe-subject +
% anchor. 1 -> 2.
v1 = struct();
v1.document_class = struct('class_name', 'electrode_offset_voltage', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_7'});
v1.base = struct('id', 'eo_1', 'session_id', 'sess_09', 'name', 'eo', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.electrode_offset_voltage = struct('offset_voltages', [0.5 -0.3 1.2 0.0], ...
    'voltage_units', 'mV');

out = did2.convert.migrators_j.electrode_offset_voltage(v1);
verifyEqual(testCase, numel(out), 2);
o = out{1};
verifyEqual(testCase, o.document_class.class_name, 'voltage_observation');
verifyEqual(testCase, o.subject_statement.storage_mode, 'inline');
verifyEqual(testCase, depValue(o, 'subject_id'), 'probe_7');
vals = o.voltage.value;
verifyEqual(testCase, numel(vals), 4);
verifyEqual(testCase, [vals.source_value], [0.5 -0.3 1.2 0.0], 'AbsTol', 1e-9);
verifyEqual(testCase, vals(1).source_unit, 'mV');
end

% (testDistanceMetadataBecomesLengthObservation removed: the J migrator no longer
% emits a length_observation -- the flat v1 doc carries no scalar distance, so it is
% reshaped into a validated distance_metadata passthrough instead. The value-bearing
% length_observation is deferred Part B, a second pass over the linked element's
% timeseries. See testDistanceMetadataReshapesFlatEndpoints and
% schemas/V_eta_distance_metadata_plan.md.)

function testOpenmindsElementBecomesTermAssertion(testCase)
% openminds_element mirrors openminds_subject, but the openMINDS entity is about
% an ELEMENT/DEVICE: the subject is carried from element_id (fallback subject_id).
% Each openMINDS controlled-term entity decomposes into one term_assertion on the
% element-subject: the entity type names the variable; the ontology id is the value.
body = struct();
body.document_class = struct('class_name', 'openminds_element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'element_id', 'openminds'}, 'value', {'elem_9', ''});
body.base = struct('id', 'ome_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239', 'synonym', 'C. elegans'));

out = did2.convert.migrators_j.openminds_element(body);
verifyEqual(testCase, numel(out), 1);
a = out{1};
verifyEqual(testCase, a.document_class.class_name, 'term_assertion');
verifyEqual(testCase, a.subject_statement.variable.name, 'species');
verifyEqual(testCase, a.term.value.node, 'NCBITaxon:6239');
verifyEqual(testCase, a.term.value.name, 'Caenorhabditis elegans');
verifyEqual(testCase, depValue(a, 'subject_id'), 'elem_9');
supers = a.document_class.superclasses;
verifyEqual(testCase, supers(1).class_name, 'subject_assertion');
end

function testOpenmindsStimulusBecomesTermAssertion(testCase)
% Same decomposition as openminds_subject, but the stimulus is the subject:
% the subject_id is carried from the stimulus_id dependency.
body = struct();
body.document_class = struct('class_name', 'openminds_stimulus', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'stimulus_id', 'openminds'}, 'value', {'stim_042', ''});
body.base = struct('id', 'om_s1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239', 'synonym', 'C. elegans'));

out = did2.convert.migrators_j.openminds_stimulus(body);
verifyEqual(testCase, out.document_class.class_name, 'term_assertion');
verifyEqual(testCase, out.document_class.superclasses(1).class_name, 'subject_assertion');
verifyEqual(testCase, out.subject_statement.variable.name, 'species');
verifyEqual(testCase, out.term.value.node, 'NCBITaxon:6239');
verifyEqual(testCase, out.term.value.name, 'Caenorhabditis elegans');
verifyEqual(testCase, depValue(out, 'subject_id'), 'stim_042');
end

function testJrclustClustersFoldsToCountObservation(testCase)
% #9 (pattern 1, body-backed): jrclust_clusters (per-spike JRCLUST cluster
% labels) -> count_observation + sampled_body (one datum per spike) + anchor.
% 1->3. No num_spikes metadata on this class, so sample_time.n == 0.
body = struct();
body.document_class = struct('class_name', 'jrclust_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_8'});
body.base = struct('id', 'jc_1', 'session_id', 'sess_09', ...
    'name', 'jc', 'datestamp', '2024-06-01T12:00:00.000Z');
body.jrclust_clusters = struct('res_mat_md5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');
body.files = struct('file_list', {{'clusters.mat'}});

out = did2.convert.migrators_j.jrclust_clusters(body);
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
verifyTrue(testCase, any(strcmp(names, 'sampled_body')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));

obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.subject_statement.storage_mode, 'body');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_8');

sbod = out{find(strcmp(names, 'sampled_body'), 1)};
verifyEqual(testCase, depValue(sbod, 'statement'), obs.base.id);   % == 'jc_1'
verifyEqual(testCase, sbod.sampled_body.datum.kind, 'scalar');
verifyEqual(testCase, sbod.sampled_body.sample_time.n, 0);         % unknown length
verifyEqual(testCase, sbod.files.file_list{1}, 'clusters.mat');
end

function testKilosortClustersFoldsToCountObservationPlusOpaqueBody(testCase)
% #9 D-C (spike-sorting family, external-directory variant): kilosort_clusters (a
% Kilosort RUN referencing a session-relative output DIRECTORY + curated MD5) ->
% an id-preserved count_observation handle on the recording subject + an
% opaque_body (the directory) + a session anchor. 1->3. Sibling of
% jrclust_clusters, but the sorter output is an external dir (opaque_body), not
% attached bytes (sampled_body).
body = struct();
body.document_class = struct('class_name', 'kilosort_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_ks'});
body.base = struct('id', 'ks_1', 'session_id', 'sess_09', ...
    'name', 'ks', 'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.app.kilosort', 'version', '1.0');
body.kilosort_clusters = struct('kilosort_directory', 'ks_out/session1', ...
    'curated_output_MD5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');

out = did2.convert.migrators_j.kilosort_clusters(body);
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
verifyTrue(testCase, any(strcmp(names, 'opaque_body')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));

obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.base.id, 'ks_1');                            % id preserved
verifyEqual(testCase, obs.subject_statement.storage_mode, 'body');
verifyEqual(testCase, obs.subject_interaction.method.name, 'kilosort');% method = algorithm
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_ks');

ob = out{find(strcmp(names, 'opaque_body'), 1)};
verifyEqual(testCase, depValue(ob, 'statement'), 'ks_1');             % body -> the obs
verifyEqual(testCase, ob.opaque_body.filename, 'ks_out/session1');    % directory preserved
verifyTrue(testCase, contains(ob.opaque_body.description, 'd41d8cd9'));% MD5 noted
end

function testKiasortClustersFoldsToCountObservationPlusOpaqueBody(testCase)
% Sibling of kilosort: kiasort_clusters decomposes identically (method 'kiasort',
% kiasort_directory).
body = struct();
body.document_class = struct('class_name', 'kiasort_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_ka'});
body.base = struct('id', 'ka_1', 'session_id', 'sess_09', ...
    'name', 'ka', 'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.app.kiasort', 'version', '1.0');
body.kiasort_clusters = struct('kiasort_directory', 'ka_out/session1', ...
    'curated_output_MD5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');

out = did2.convert.migrators_j.kiasort_clusters(body);
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.base.id, 'ka_1');
verifyEqual(testCase, obs.subject_interaction.method.name, 'kiasort');
ob = out{find(strcmp(names, 'opaque_body'), 1)};
verifyEqual(testCase, ob.opaque_body.filename, 'ka_out/session1');
end

function testSpikeInterfaceSortingOutputsBecomesCountObservation(testCase)
% #9 fold: spike_interface_sorting_outputs -> one INLINE count_observation
% (num_units = the cardinality of the sorted-unit set) on the recording subject
% (carried from element_id) + a shared session anchor. 1 -> 2. Per-unit subjects
% are NOT minted here (neuron_extracellular's / the NDI second pass's job).
body = struct();
body.document_class = struct('class_name', 'spike_interface_sorting_outputs', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_4'});
body.base = struct('id', 'sis_1', 'session_id', 'sess_09', ...
    'name', 'sis', 'datestamp', '2024-06-01T12:00:00.000Z');
body.spike_interface_sorting_outputs = struct('sorter_name', 'kilosort', ...
    'num_units', 12, 'sample_rate', 30000);

out = did2.convert.migrators_j.spike_interface_sorting_outputs(body);
verifyClass(testCase, out, 'cell');
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));

obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.subject_statement.storage_mode, 'inline');
verifyEqual(testCase, obs.subject_statement.variable.name, 'number of sorted units');
verifyEqual(testCase, obs.count.value.value, 12);
verifyEqual(testCase, obs.count.value.approximate, false);
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_4');
anchor = out{find(strcmp(names, 'session_relative_reference'), 1)};
verifyEqual(testCase, depValue(obs, 'time_reference_1'), anchor.base.id);
verifyEqual(testCase, anchor.session_relative_reference.relation, 'during');
end

function testProbeGeometryBecomesLengthObservation(testCase)
% probe_geometry -> a length_observation whose INLINE value is the FLATTENED
% channel_positions matrix (one measurement per coordinate) about the
% probe-subject + anchor, plus a probe-type term_assertion. 1 -> 3.
v1 = struct();
v1.document_class = struct('class_name', 'probe_geometry', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_5'});
v1.base = struct('id', 'pg_1', 'session_id', 'sess_09', 'name', 'pg', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_geometry = struct('num_channels', 2, ...
    'channel_positions', [0 0; 20 0], ...
    'position_units', 'um', ...
    'probe_type', 'linear');

out = did2.convert.migrators_j.probe_geometry(v1);
obs = [];
for k = 1:numel(out)
    if strcmp(out{k}.document_class.class_name, 'length_observation')
        obs = out{k}; break;
    end
end
verifyNotEmpty(testCase, obs);
verifyEqual(testCase, obs.subject_statement.storage_mode, 'inline');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'probe_5');
vals = obs.length.value;
verifyEqual(testCase, numel(vals), numel(v1.probe_geometry.channel_positions));  % == 4
verifyEqual(testCase, vals(1).source_unit, 'um');
end

function testSite2ChannelMapBecomesCountObservation(testCase)
% site2channelmap -> one INLINE count_observation (num_sites) on the probe-subject
% + a session anchor. 1 -> 2. The site->channel wiring map itself is deferred
% (instrument-layer config, not a subject observation).
body = struct();
body.document_class = struct('class_name', 'site2channelmap', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'probe_id'}, 'value', {'probe_6'});
body.base = struct('id', 's2c_1', 'session_id', 'sess_09', ...
    'name', 's2c', 'datestamp', '2024-06-01T12:00:00.000Z');
body.site2channelmap = struct('num_sites', 32, ...
    'site_to_channel', struct('site', 1, 'channel', 5));

out = did2.convert.migrators_j.site2channelmap(body);
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));
obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.subject_statement.storage_mode, 'inline');
verifyEqual(testCase, obs.subject_statement.variable.name, 'number of recording sites');
verifyEqual(testCase, obs.count.value.value, 32);
verifyEqual(testCase, depValue(obs, 'subject_id'), 'probe_6');
end

function testPositionMetadataBecomesTermObservation(testCase)
% position_metadata carries only DESCRIPTIVE ontology fields -- the numeric
% coordinates live in the separate element/timeseries doc that element_id points
% at, NOT here. So it folds to a term_observation of the element-subject naming
% the measurement term (value = the ontologyNode CURIE), plus a session anchor.
% 1 -> 2. No values are invented.
body = struct();
body.document_class = struct('class_name', 'position_metadata', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'element_id'}, 'value', {'pos_elem_7'});
body.base = struct('id', 'pm_01', 'session_id', 'sess_09', ...
    'name', 'pm', 'datestamp', '2024-06-01T12:00:00.000Z');
body.position_metadata = struct('ontology_node', 'EMPTY:0000200', ...
    'units', 'NCIT:C48367', 'dimensions', 'NCIT:C44477,NCIT:C44478');

bodies = did2.convert.migrators_j.position_metadata(body);
verifyEqual(testCase, numel(bodies), 2);              % obs + anchor
obs = bodies{1};
verifyEqual(testCase, obs.document_class.class_name, 'term_observation');
verifyEqual(testCase, obs.term.value.node, 'EMPTY:0000200');
verifyEqual(testCase, obs.subject_statement.variable.name, 'position');
verifyEqual(testCase, depValue(obs, 'subject_id'), 'pos_elem_7');
anchor = bodies{2};
verifyEqual(testCase, anchor.document_class.class_name, 'session_relative_reference');
verifyEqual(testCase, anchor.session_relative_reference.relation, 'during');
end

function testSpatialFrequencyTuningFoldsToCalculationLeaf(testCase)
% Calculator composite-leaf model: spatial_frequency_tuning -> the leaf
% spatial_frequency_tuning_calculation (id-preserved) + a session anchor. 1 -> 2.
% The full result (tuning_curve / significance / fitless / fit_dog) is kept verbatim
% as the composite value; derived_from the raw stimulus_tuningcurve. Supersedes the
% grain-A scalar decomposition.
body = struct();
body.document_class = struct('class_name', 'spatial_frequency_tuning', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_2'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_2')];
body.base = struct('id', 'sf_1', 'session_id', 'sess_09', 'name', 'sf', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.spatial_frequency_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('spatial_frequency', [0.05 0.1 0.2 0.5], 'mean', [2 8 5 1]), ...
    'significance', struct('visual_response_anova_p', 0.01, 'across_stimuli_anova_p', 0.03), ...
    'fitless', struct('pref', 0.12, 'l50', 0.06, 'h50', 0.28, 'bandwidth', 2.2, ...
        'low_pass_index', 0.3, 'high_pass_index', 0.7), ...
    'fit_dog', struct('r2', 0.95, 'pref', 0.13));

out = did2.convert.migrators_j.spatial_frequency_tuning(body);
verifyEqual(testCase, numel(out), 2);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'tuning_curve_calculation')));
verifyFalse(testCase, any(strcmp(names, 'score_observation')));
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));
leaf = out{find(strcmp(names, 'tuning_curve_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'sf_1');
verifyEqual(testCase, depValue(leaf, 'subject_id'), 'neuron_2');
verifyEqual(testCase, depValue(leaf, 'derived_from_1'), 'tc_2');
verifyEqual(testCase, leaf.subject_interaction.method.name, 'ndi.calc.vis.spatialfrequency');
% the full result kept verbatim, incl. the fit block
verifyEqual(testCase, leaf.tuning_curve.value.interpolated_values.bandwidth, 2.2, 'AbsTol', 1e-9);
% fit_dog -> a model_fit ARRAY entry {model='dog', coefficients=<the fit block>}.
mf = leaf.tuning_curve.value.model_fit;
dogEntry = mf(arrayfun(@(e) strcmp(e.model.name, 'dog'), mf));
verifyEqual(testCase, dogEntry.coefficients.r2, 0.95, 'AbsTol', 1e-9);
end

function testNeuronExtracellularMintsDerivedSubject(testCase)
% #9 grain-B pattern: a sorted unit is a DERIVED subject, not an observation of the
% recording. neuron_extracellular -> subject + derived_from relation (unit <- the
% recording subject) + a score_observation of the unit + anchor. 1 -> 4.
body = struct();
body.document_class = struct('class_name', 'neuron_extracellular', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
body.base = struct('id', 'ne_1', 'session_id', 'sess_09', ...
    'name', 'ne', 'datestamp', '2024-06-01T12:00:00.000Z');
body.neuron_extracellular = struct('cluster_index', 7, 'quality_number', 3, ...
    'number_of_channels', 4);

out = did2.convert.migrators_j.neuron_extracellular(body);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 4);
verifyTrue(testCase, any(strcmp(names, 'subject')));
verifyTrue(testCase, any(strcmp(names, 'directed_relation')));
verifyTrue(testCase, any(strcmp(names, 'score_observation')));

neuron = out{find(strcmp(names, 'subject'), 1)};
verifyEqual(testCase, neuron.subject.local_identifier, 'unit_7');
rel = out{find(strcmp(names, 'directed_relation'), 1)};
% derived_from: unit (child) <- recording subject (parent)
verifyEqual(testCase, depValue(rel, 'child'), neuron.base.id);
verifyEqual(testCase, depValue(rel, 'parent'), 'rec_sub_1');
verifyEqual(testCase, rel.directed_relation.relation.name, 'derived_from');
% the quality observation is about the minted unit
qobs = out{find(strcmp(names, 'score_observation'), 1)};
verifyEqual(testCase, depValue(qobs, 'subject_id'), neuron.base.id);
verifyEqual(testCase, qobs.score.value.value, 3, 'AbsTol', 1e-9);
end

function testSpikeClustersFoldsToCountObservation(testCase)
% #9 (pattern 1, body-backed): spike_clusters (per-spike cluster labels) ->
% count_observation + sampled_body (one datum per spike) + anchor. 1->3.
body = struct();
body.document_class = struct('class_name', 'spike_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'sorting_parameters_id', 'value', 'sp_1')];
body.base = struct('id', 'sc_1', 'session_id', 'sess_09', ...
    'name', 'sc', 'datestamp', '2024-06-01T12:00:00.000Z');
body.spike_clusters = struct('num_clusters', 5, 'num_spikes', 400);
body.files = struct('file_list', {{'clusters.bin'}});

out = did2.convert.migrators_j.spike_clusters(body);
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.subject_statement.storage_mode, 'body');
sbod = out{find(strcmp(names, 'sampled_body'), 1)};
verifyEqual(testCase, depValue(sbod, 'statement'), 'sc_1');
verifyEqual(testCase, sbod.sampled_body.sample_time.n, 400);
end

function testFitcurveFoldsToGoodnessScore(testCase)
% #9 (scalar, pragmatic): fitcurve -> a goodness-of-fit score_observation (method =
% fit function). 1->2. fit_parameters deferred.
body = struct();
body.document_class = struct('class_name', 'fitcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_9'});
body.base = struct('id', 'fc_1', 'session_id', 'sess_09', 'name', 'fc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.fitcurve = struct('fit_function', 'gaussian', 'goodness_of_fit', 0.94);
out = did2.convert.migrators_j.fitcurve(body);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'score_observation')));
obs = out{find(strcmp(names, 'score_observation'), 1)};
verifyEqual(testCase, depValue(obs, 'subject_id'), 'sub_9');
verifyEqual(testCase, obs.score.value.value, 0.94, 'AbsTol', 1e-9);
verifyEqual(testCase, obs.subject_interaction.method.name, 'gaussian');
end

function testVmspikefitFoldsToGoodnessScore(testCase)
body = struct();
body.document_class = struct('class_name', 'vmspikefit', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_a'});
body.base = struct('id', 'vf_1', 'session_id', 'sess_09', 'name', 'vf', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.vmspikefit = struct('fit_function', 'exp2', 'r_squared', 0.88);
out = did2.convert.migrators_j.vmspikefit(body);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
obs = out{find(strcmp(names, 'score_observation'), 1)};
verifyEqual(testCase, obs.score.value.value, 0.88, 'AbsTol', 1e-9);
end

function testSimpleCalcUnitMappedScalar(testCase)
% #9 (scalar): simple_calc -> a single inline observation typed by units.
body = struct();
body.document_class = struct('class_name', 'simple_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_b'});
body.base = struct('id', 'sm_1', 'session_id', 'sess_09', 'name', 'sm', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.simple_calc = struct('result_value', 12.5, 'result_units', 'Hz');
out = did2.convert.migrators_j.simple_calc(body);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'frequency_observation')));
obs = out{find(strcmp(names, 'frequency_observation'), 1)};
verifyEqual(testCase, obs.frequency.value.source_value, 12.5, 'AbsTol', 1e-9);
end

function testVmneuralresponseresidualsFold(testCase)
% #9 (scalar + provenance): vmneuralresponseresiduals -> voltage_observation
% (mean_residual) + derived_from relation to the vmspikefit + anchor. 1->3.
body = struct();
body.document_class = struct('class_name', 'vmneuralresponseresiduals', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_c'), ...
                    struct('name', 'vmspikefit_id', 'value', 'vf_9')];
body.base = struct('id', 'rr_1', 'session_id', 'sess_09', 'name', 'rr', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.vmneuralresponseresiduals = struct('mean_residual', 1.7);
out = did2.convert.migrators_j.vmneuralresponseresiduals(body);
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 3);
obs = out{find(strcmp(names, 'voltage_observation'), 1)};
verifyEqual(testCase, obs.voltage.value.source_value, 1.7, 'AbsTol', 1e-9);
rel = out{find(strcmp(names, 'directed_relation'), 1)};
verifyEqual(testCase, depValue(rel, 'child'), obs.base.id);
verifyEqual(testCase, depValue(rel, 'parent'), 'vf_9');
verifyEqual(testCase, rel.directed_relation.relation.name, 'derived_from');
end

function testSyncruleMappingEpochnodeToTimeReference(testCase)
% gov part 3: each epochnode_*'s bare epoch_clock + epoch_id are nested under a
% time_reference sub-structure (epoch_bounded_reference shape). 1 -> 1; cost,
% mapping, node metadata, and the deps (syncrule_id + epochid) carry through.
body = struct();
body.document_class = struct('class_name', 'syncrule_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'syncrule_id', 'value', 'sr_1'), ...
                    struct('name', 'epochid', 'value', 't00001') ];
body.base = struct('id', 'sm_1', 'session_id', 'sess_09', 'name', 'sm', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
nodeA = struct('epoch_clock', 'dev_local_time', 'epoch_id', 't00001', ...
    'epoch_session_id', 'sess_09', 'epochprobemap', struct('a', 1), ...
    'objectclass', 'ndi.time.syncrule.filematch');
nodeB = struct('epoch_clock', 'utc', 'epoch_id', 't00002', ...
    'epoch_session_id', 'sess_09', 'epochprobemap', struct(), 'objectclass', '');
body.syncrule_mapping = struct('cost', 1.0, 'mapping', [1 0; 0 1], ...
    'epochnode_a', nodeA, 'epochnode_b', nodeB);

out = did2.convert.migrators_j.syncrule_mapping(body);
verifyEqual(testCase, out.document_class.schema_version, 'V_eta');
% epoch_clock / epoch_id are no longer bare on the node -- they moved under
% time_reference (epoch_bounded_reference shape)
na = out.syncrule_mapping.epochnode_a;
verifyFalse(testCase, isfield(na, 'epoch_clock'));
verifyFalse(testCase, isfield(na, 'epoch_id'));
verifyEqual(testCase, na.time_reference.kind, 'epoch_bounded_reference');
verifyEqual(testCase, na.time_reference.epoch_clock, 'dev_local_time');
verifyEqual(testCase, na.time_reference.epoch_id, 't00001');
% node metadata retained
verifyEqual(testCase, na.epoch_session_id, 'sess_09');
verifyEqual(testCase, na.objectclass, 'ndi.time.syncrule.filematch');
verifyEqual(testCase, out.syncrule_mapping.epochnode_b.time_reference.epoch_clock, 'utc');
% cost / mapping / deps preserved
verifyEqual(testCase, out.syncrule_mapping.cost, 1.0);
verifyEqual(testCase, depValue(out, 'syncrule_id'), 'sr_1');
verifyEqual(testCase, depValue(out, 'epochid'), 't00001');
end

function v = depValue(b, name)
v = '';
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, name); v = b.depends_on(k).value; return; end
end
end
