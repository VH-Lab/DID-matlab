function tests = testMigratorsI
%TESTMIGRATORSI Brainstorm-I split/fold migrator tests (TargetVersion 'V_zeta').
%
%   Exercises the did_v1 -> V_zeta migrators routed by did2.convert.v1_to_v2
%   when TargetVersion == 'V_zeta':
%     - treatment            -> manipulation tiers (1 -> 2 branch dispatch)
%     - ontology_table_row   -> shape-typed observations (1 -> N)
%     - treatment_drug / virus_injection -> injection
%     - treatment_transfer   -> biological_transfer
%     - subject_group        -> subject (is_group)
%     - stimulus_bath        -> deferred to the NDI layer
%   against the worked examples in did-schema/schemas/V_zeta/
%   conversions/from_did_v1/*.md.
%
%   The Brainstorm-I differences from the E tests: identity is OFF the class
%   -- it lands on the spine `subject_interaction.variable`, not on a family
%   `applied_property`/`procedure`/`factor` block; observation leaves are named
%   by DATA-TYPE (scalar_mass_observation, not body_weight_observation) with a
%   single concrete categorical_observation; and the pure-identity
%   procedural_/environmental_manipulation classes fold into
%   generic_manipulation.
%
%   Like testMigratorsE, these run with Validate=false so they assert the
%   TRANSFORM (routing + field placement) without depending on a V_zeta
%   schema cache at the test-runner working directory.
%
%   Run with:
%       results = runtests('did2.unittest.testMigratorsI');

tests = functiontests(localfunctions);
end

function v1 = wrap(className, blockKey, block)
v1 = struct();
v1.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'document_id', {'aabb1122ccdd3344_aabb1122ccdd3344'});
v1.base = struct('id', 'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'migrator-i-example', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.(blockKey) = block;
end

function out = runI(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_zeta');
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

% ===================== treatment -> manipulation =======================

function testThermalTreatmentBecomesTemperatureManipulation(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'ndic:0000nnnn', 'name', 'focal cortical cooling', ...
    'numeric_value', 12.0, 'string_value', 'Peltier'));
out = runI(v1);
% 1 -> 2: the manipulation plus its session_relative_reference anchor.
verifyEqual(testCase, numel(out.migrated), 2);
doc = out.migrated{1};
verifyTrue(testCase, isfield(out.summary.by_class, 'temperature_manipulation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));
val = doc.get('scalar_temperature.value');
verifyEqual(testCase, val.celsius, 12.0);
% Brainstorm I: identity is on the spine `variable`, NOT scalar_manipulation.
variable = doc.get('subject_interaction.variable');
verifyEqual(testCase, variable.name, 'focal cortical cooling');
anchor = out.migrated{2};
verifyEqual(testCase, anchor.get('session_relative_reference.relation'), 'during');
end

function testDrugTreatmentBecomesInjection(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', [], 'string_value', ''));
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % injection + session anchor
verifyTrue(testCase, isfield(out.summary.by_class, 'injection'));
end

function testEnvironmentalTreatmentBecomesGenericManipulation(testCase)
% Brainstorm I: an environmental regime has no structural class of its own;
% it folds into generic_manipulation with the regime named by `variable`.
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'ncit:0000nnnn', 'name', 'dark rearing', ...
    'numeric_value', [], 'string_value', 'reared in darkness'));
out = runI(v1);
verifyTrue(testCase, isfield(out.summary.by_class, 'generic_manipulation'));
doc = out.migrated{1};
variable = doc.get('subject_interaction.variable');
verifyEqual(testCase, variable.name, 'dark rearing');
verifyEqual(testCase, doc.get('manipulation.notes'), 'reared in darkness');
end

function testProceduralTreatmentBecomesGenericManipulation(testCase)
% A physical procedure also folds into generic_manipulation (no structure).
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'ncit:0000nnnn', 'name', 'craniotomy', ...
    'numeric_value', [], 'string_value', 'left hemisphere'));
out = runI(v1);
verifyTrue(testCase, isfield(out.summary.by_class, 'generic_manipulation'));
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject_interaction.variable').name, 'craniotomy');
end

function testDabTargetLocationRoutesStringValueToSpineTargetStructure(testCase)
% Dab edge case: string_value is a UBERON CURIE, name ends "Target Location".
% In I the locus lands on the spine target_structure (procedures ->
% generic_manipulation).
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'empty:0000074', ...
    'name', 'Optogenetic Tetanus Stimulation Target Location', ...
    'numeric_value', [], 'string_value', 'uberon:0001930'));
out = runI(v1);
verifyTrue(testCase, isfield(out.summary.by_class, 'generic_manipulation'));
doc = out.migrated{1};
ts = doc.get('subject_interaction.target_structure');
verifyFalse(testCase, isempty(ts));
end

function testNotAManipulationIsQuarantined(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', '', 'name', 'Date of birth', ...
    'numeric_value', [], 'string_value', '2024-01-01'));
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 0);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyTrue(testCase, contains(out.quarantine(1).reason, 'not a manipulation'));
end

% ===================== ontology_table_row -> observations (1->N) =======

function testTableRowFansOutToNObservations(testCase)
rows = {struct('ontology_name', 'schema:weight', 'name', 'weight', ...
        'value', 22.5, 'unit', 'g'), ...
        struct('ontology_name', 'uberon:0000105', 'name', 'life cycle stage', ...
        'value', 'fbdv:00005336')};
v1 = wrap('ontology_table_row', 'ontology_table_row', struct('rows', {rows}));
out = runI(v1);
% 2 rows -> 2 observations + 1 shared session anchor.
verifyEqual(testCase, numel(out.migrated), 3);
% shape-typed leaves, not property-named
verifyTrue(testCase, isfield(out.summary.by_class, 'scalar_mass_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'categorical_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));
end

function testTableRowScalarValueLandsTypedWithVariableIdentity(testCase)
rows = {struct('ontology_name', 'schema:weight', 'name', 'weight', ...
        'value', 22.5, 'unit', 'g')};
v1 = wrap('ontology_table_row', 'ontology_table_row', struct('rows', {rows}));
out = runI(v1);
doc = out.migrated{1};
val = doc.get('scalar_mass.value');
verifyEqual(testCase, val.source_value, 22.5);
% property identity is the spine variable, not the class name
verifyEqual(testCase, doc.get('subject_interaction.variable').name, 'weight');
end

function testTableRowCategoricalValueOnOwnBlock(testCase)
rows = {struct('ontology_name', 'uberon:0000105', 'name', 'life cycle stage', ...
        'value', 'fbdv:00005336')};
v1 = wrap('ontology_table_row', 'ontology_table_row', struct('rows', {rows}));
out = runI(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('categorical_observation.value').node, 'fbdv:00005336');
verifyEqual(testCase, doc.get('subject_interaction.variable').name, 'life cycle stage');
end

function testTableRowGeneratesUniqueIdsPerRow(testCase)
rows = {struct('ontology_name', 'schema:weight', 'name', 'weight', 'value', 22.5, 'unit', 'g'), ...
        struct('ontology_name', 'schema:weight', 'name', 'weight', 'value', 23.0, 'unit', 'g')};
v1 = wrap('ontology_table_row', 'ontology_table_row', struct('rows', {rows}));
out = runI(v1);
id1 = out.migrated{1}.get('base.id');
id2 = out.migrated{2}.get('base.id');
verifyNotEqual(testCase, id1, id2);
end

function testTableRowCharFieldLayoutSplitsByColumn(testCase)
block = struct( ...
    'names', 'weight,life cycle stage', ...
    'variable_names', 'weight,stage', ...
    'ontology_nodes', 'schema:weight,uberon:0000105', ...
    'data', struct('weight', 22.5, 'stage', 'fbdv:00005336'));
v1 = wrap('ontology_table_row', 'ontology_table_row', block);
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 3);
verifyTrue(testCase, isfield(out.summary.by_class, 'scalar_mass_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'categorical_observation'));
end

function testTableRowCharFieldEmptyValuesSkipped(testCase)
block = struct( ...
    'names', 'weight,missing', ...
    'variable_names', 'weight,missing', ...
    'ontology_nodes', 'schema:weight,schema:missing', ...
    'data', struct('weight', 22.5, 'missing', nan));
v1 = wrap('ontology_table_row', 'ontology_table_row', block);
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 2);
verifyTrue(testCase, isfield(out.summary.by_class, 'scalar_mass_observation'));
end

% ===================== context-dependent deferral =====================

function testStimulusBathDefersToNdiLayer(testCase)
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', ''));
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 0);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyTrue(testCase, contains(out.quarantine(1).reason, 'NDI layer'));
end

function testAlreadyZetaBodyShortCircuits(testCase)
% A body already tagged schema_version 'V_zeta' short-circuits the migration
% loop and is just padded/validated, not re-migrated.
v1 = wrap('mock', 'mock', struct());
v1.document_class.schema_version = 'V_zeta';
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_zeta');
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, numel(out.quarantine), 0);
end

% ===================== deprecated treatment family -> injection/transfer =

function testTreatmentDrugBecomesInjection(testCase)
v1 = wrap('treatment_drug', 'treatment_drug', struct( ...
    'location_ontologyNode', 'uberon:0000955', 'location_name', 'brain', ...
    'mixture_table', 'chebi:6904,muscimol,5,mg/ml'));
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % injection + session anchor
verifyTrue(testCase, isfield(out.summary.by_class, 'injection'));
doc = out.migrated{1};
verifyEqual(testCase, doc.get('injection.kind'), 'drug');
mix = doc.get('pharmacological_manipulation.mixture');
verifyEqual(testCase, mix(1).chemical.name, 'muscimol');
% the primary drug is also the spine identity
verifyEqual(testCase, doc.get('subject_interaction.variable').name, 'muscimol');
end

function testVirusInjectionBecomesVirusInjection(testCase)
v1 = wrap('virus_injection', 'virus_injection', struct( ...
    'virus_OntologyName', 'addgene:26973', 'virus_name', 'AAV9-CaMKII-GCaMP', ...
    'virusLocation_OntologyName', 'uberon:0001950', 'virusLocation_name', 'neocortex', ...
    'dilution', 0.5, 'diluent_OntologyName', '', 'diluent_name', 'saline'));
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 2);
verifyTrue(testCase, isfield(out.summary.by_class, 'injection'));
doc = out.migrated{1};
verifyEqual(testCase, doc.get('injection.kind'), 'virus');
mix = doc.get('pharmacological_manipulation.mixture');
verifyEqual(testCase, mix(1).chemical.name, 'AAV9-CaMKII-GCaMP');
verifyEqual(testCase, mix(1).amount.source_value, 0.5);
verifyEqual(testCase, doc.get('subject_interaction.variable').name, 'AAV9-CaMKII-GCaMP');
end

function testTreatmentTransferBecomesBiologicalTransfer(testCase)
% treatment_transfer carries recipient_id + donor_id (not subject_id).
v1 = struct();
v1.document_class = struct('class_name', 'treatment_transfer', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct( ...
    'name', {'recipient_id', 'donor_id'}, ...
    'value', {'aabb1122ccdd3344_1111111111111111', ...
              'aabb1122ccdd3344_2222222222222222'});
v1.base = struct('id', 'aabb1122ccdd3344_3333333333333333', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'transfer-example', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_transfer = struct('entity_name', 'donor retina', ...
    'entity_ontologyNode', 'uberon:0000966', ...
    'method_name', 'transplant', 'method_ontologyNode', 'ncit:C15282');
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 2);
verifyTrue(testCase, isfield(out.summary.by_class, 'biological_transfer'));
doc = out.migrated{1};
% Brainstorm I: the transferred material is the spine variable (no
% biological_transfer.entity); kind carries the coarse bucket.
verifyEqual(testCase, doc.get('subject_interaction.variable').name, 'donor retina');
verifyEqual(testCase, doc.get('biological_transfer.kind'), 'transplant');
% recipient -> subject_id; donor carried as donor_id
verifyEqual(testCase, depVal(doc, 'subject_id'), 'aabb1122ccdd3344_1111111111111111');
verifyEqual(testCase, depVal(doc, 'donor_id'), 'aabb1122ccdd3344_2222222222222222');
end

% ===================== subject_group -> subject =======================

function testSubjectGroupBecomesGroupSubject(testCase)
v1 = wrap('subject_group', 'subject_group', struct());
out = runI(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyTrue(testCase, isfield(out.summary.by_class, 'subject'));
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject.is_group'), true);
verifyEqual(testCase, doc.get('subject.is_biological'), false);
end

function testSubjectGroupCarriesOptionalNameAndDescription(testCase)
v1 = wrap('subject_group', 'subject_group', struct( ...
    'group_name', 'control', 'description', 'untreated cohort'));
out = runI(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject.local_identifier'), 'control');
verifyEqual(testCase, doc.get('subject.description'), 'untreated cohort');
end

% ===================== backward compatibility ==========================

function testDefaultTargetLeavesTreatmentUnchanged(testCase)
% With the default TargetVersion ('V_delta') the I split is NOT applied.
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent'));
out = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, numel(out.migrated), 1);
verifyTrue(testCase, isfield(out.summary.by_class, 'treatment'));
end
