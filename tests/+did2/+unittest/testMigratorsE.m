function tests = testMigratorsE
%TESTMIGRATORSE Brainstorm-E split migrator tests (TargetVersion 'V_epsilon').
%
%   Exercises the did_v1 -> V_epsilon split migrators routed by
%   did2.convert.v1_to_v2 when TargetVersion == 'V_epsilon':
%     - treatment            -> manipulation tiers (1 -> 1 branch dispatch)
%     - ontology_table_row   -> observation tiers (1 -> N)
%   against the worked examples in did-schema/schemas/V_epsilon/
%   conversions/from_did_v1/{treatment,ontology_table_row}.md.
%
%   Like testMigrators, these run with Validate=false so they assert the
%   TRANSFORM (routing + field placement) without depending on a V_epsilon
%   schema cache at the test-runner working directory. Corpus-level
%   validation is the discovery-mode CI job (#3).
%
%   Run with:
%       results = runtests('did2.unittest.testMigratorsE');

tests = functiontests(localfunctions);
end

function v1 = wrap(className, blockKey, block)
v1 = struct();
v1.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'document_id', {'aabb1122ccdd3344_aabb1122ccdd3344'});
v1.base = struct('id', 'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'migrator-e-example', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.(blockKey) = block;
end

function out = runE(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_epsilon');
end

% ===================== treatment -> manipulation =======================

function testThermalTreatmentBecomesTemperatureManipulation(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'ndic:0000nnnn', 'name', 'focal cortical cooling', ...
    'numeric_value', 12.0, 'string_value', 'Peltier'));
out = runE(v1);
% 1 -> 2: the manipulation plus its session_relative_reference anchor.
verifyEqual(testCase, numel(out.migrated), 2);
doc = out.migrated{1};
verifyTrue(testCase, isfield(out.summary.by_class, 'temperature_manipulation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));
val = doc.get('scalar_temperature.value');
verifyEqual(testCase, val.celsius, 12.0);
ap = doc.get('scalar_manipulation.applied_property');
verifyEqual(testCase, ap.name, 'focal cortical cooling');
% the anchor is an ordinal 'during' session reference
anchor = out.migrated{2};
verifyEqual(testCase, anchor.get('session_relative_reference.relation'), 'during');
end

function testDrugTreatmentBecomesInjection(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', [], 'string_value', ''));
out = runE(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % injection + session anchor
verifyTrue(testCase, isfield(out.summary.by_class, 'injection'));
end

function testEnvironmentalTreatmentBecomesEnvironmentalManipulation(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'ncit:0000nnnn', 'name', 'dark rearing', ...
    'numeric_value', [], 'string_value', 'reared in darkness'));
out = runE(v1);
verifyTrue(testCase, isfield(out.summary.by_class, 'environmental_manipulation'));
doc = out.migrated{1};
factor = doc.get('environmental_manipulation.factor');
verifyEqual(testCase, factor.name, 'dark rearing');
end

function testDabTargetLocationRoutesStringValueToTargetStructure(testCase)
% Dab edge case: string_value is a UBERON CURIE, name ends "Target Location".
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'empty:0000074', ...
    'name', 'Optogenetic Tetanus Stimulation Target Location', ...
    'numeric_value', [], 'string_value', 'uberon:0001930'));
out = runE(v1);
verifyTrue(testCase, isfield(out.summary.by_class, 'procedural_manipulation'));
doc = out.migrated{1};
ts = doc.get('procedural_manipulation.target_structure');
verifyFalse(testCase, isempty(ts));
end

function testNotAManipulationIsQuarantined(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', '', 'name', 'Date of birth', ...
    'numeric_value', [], 'string_value', '2024-01-01'));
out = runE(v1);
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
out = runE(v1);
% 2 rows -> 2 observations + 1 shared session anchor.
verifyEqual(testCase, numel(out.migrated), 3);
verifyTrue(testCase, isfield(out.summary.by_class, 'body_weight_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'developmental_stage_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'session_relative_reference'));
end

function testTableRowScalarValueLandsTyped(testCase)
rows = {struct('ontology_name', 'schema:weight', 'name', 'weight', ...
        'value', 22.5, 'unit', 'g')};
v1 = wrap('ontology_table_row', 'ontology_table_row', struct('rows', {rows}));
out = runE(v1);
doc = out.migrated{1};
val = doc.get('scalar_mass.value');
verifyEqual(testCase, val.source_value, 22.5);
end

function testTableRowGeneratesUniqueIdsPerRow(testCase)
rows = {struct('ontology_name', 'schema:weight', 'name', 'weight', 'value', 22.5, 'unit', 'g'), ...
        struct('ontology_name', 'schema:weight', 'name', 'weight', 'value', 23.0, 'unit', 'g')};
v1 = wrap('ontology_table_row', 'ontology_table_row', struct('rows', {rows}));
out = runE(v1);
id1 = out.migrated{1}.get('base.id');
id2 = out.migrated{2}.get('base.id');
verifyNotEqual(testCase, id1, id2);
end

function testTableRowCharFieldLayoutSplitsByColumn(testCase)
% The real v1 layout: parallel char fields + a data struct keyed by
% variable_names (one document = one row; each column = one observation).
block = struct( ...
    'names', 'weight,life cycle stage', ...
    'variable_names', 'weight,stage', ...
    'ontology_nodes', 'schema:weight,uberon:0000105', ...
    'data', struct('weight', 22.5, 'stage', 'fbdv:00005336'));
v1 = wrap('ontology_table_row', 'ontology_table_row', block);
out = runE(v1);
% 2 columns -> 2 observations + 1 shared session anchor.
verifyEqual(testCase, numel(out.migrated), 3);
verifyTrue(testCase, isfield(out.summary.by_class, 'body_weight_observation'));
verifyTrue(testCase, isfield(out.summary.by_class, 'developmental_stage_observation'));
end

function testTableRowCharFieldEmptyValuesSkipped(testCase)
% Columns with no usable value (missing key / NaN) are skipped, not
% turned into empty observations.
block = struct( ...
    'names', 'weight,missing', ...
    'variable_names', 'weight,missing', ...
    'ontology_nodes', 'schema:weight,schema:missing', ...
    'data', struct('weight', 22.5, 'missing', nan));
v1 = wrap('ontology_table_row', 'ontology_table_row', block);
out = runE(v1);
% only the weight column survives -> 1 observation + 1 anchor.
verifyEqual(testCase, numel(out.migrated), 2);
verifyTrue(testCase, isfield(out.summary.by_class, 'body_weight_observation'));
end

% ===================== context-dependent deferral =====================

function testStimulusBathDefersToNdiLayer(testCase)
% stimulus_bath is migrated to a `bath` in the NDI layer (it needs the
% stimulator element for its subject + epoch anchor), so the per-document
% converter defers it with a clear reason rather than emitting a partial.
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', ''));
out = runE(v1);
verifyEqual(testCase, numel(out.migrated), 0);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyTrue(testCase, contains(out.quarantine(1).reason, 'NDI layer'));
end

function testAlreadyEpsilonBodyShortCircuits(testCase)
% A body already tagged schema_version 'V_epsilon' (e.g. emitted by an NDI
% context assembler) short-circuits the migration loop and is just
% padded/validated, not re-migrated. This is what lets ndi.migrate.local
% feed assembled bath/time-reference bodies back through v1_to_v2.
v1 = wrap('mock', 'mock', struct());
v1.document_class.schema_version = 'V_epsilon';
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_epsilon');
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, numel(out.quarantine), 0);
end

% ===================== subject_group -> subject =======================

function testSubjectGroupBecomesGroupSubject(testCase)
% subject_group folds into the subject tier as a subject flagged is_group.
v1 = wrap('subject_group', 'subject_group', struct());
out = runE(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyTrue(testCase, isfield(out.summary.by_class, 'subject'));
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject.is_group'), true);
verifyEqual(testCase, doc.get('subject.is_biological'), false);
end

function testSubjectGroupCarriesOptionalNameAndDescription(testCase)
% Newer subject_group docs may carry group_name / description; they map
% onto the subject block's local_identifier / description.
v1 = wrap('subject_group', 'subject_group', struct( ...
    'group_name', 'control', 'description', 'untreated cohort'));
out = runE(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('subject.local_identifier'), 'control');
verifyEqual(testCase, doc.get('subject.description'), 'untreated cohort');
end

% ===================== backward compatibility ==========================

function testDefaultTargetLeavesTreatmentUnchanged(testCase)
% With the default TargetVersion ('V_delta') the E split is NOT applied:
% treatment passes through the existing per-class migrator as a single
% treatment document. Guards the gated, backward-compatible design.
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'chebi:6015', 'name', 'isoflurane', ...
    'numeric_value', 2.0, 'string_value', '2 percent'));
out = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, numel(out.migrated), 1);
verifyTrue(testCase, isfield(out.summary.by_class, 'treatment'));
end
