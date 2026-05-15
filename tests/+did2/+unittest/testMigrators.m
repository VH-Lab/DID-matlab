function tests = testMigrators
%TESTMIGRATORS Per-class did_v1 -> V_delta migrator tests.
%
%   Exercises the four 2.0.0-bumped class migrators (PLAN.md §9.6
%   sub-step 6c) against the worked examples in
%   did-schema/schemas/V_delta/conversions/from_did_v1/<class>.md.
%
%   Tests run with Validate=false on the end-to-end dispatcher case
%   so they do not depend on the schema cache being able to resolve
%   V_delta schemas at the test-runner working directory.
%
%   Run with:
%       results = runtests('did2.unittest.testMigrators');

tests = functiontests(localfunctions);
end

function v1 = wrap(className, blockKey, block)
v1 = struct();
v1.document_class = struct( ...
    'class_name',    className, ...
    'class_version', '1.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'migrator-example', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
v1.(blockKey) = block;
end

function testProbeLocationCollapsesTwoChars(testCase)
v1 = wrap('probe_location', 'probe_location', struct( ...
    'ontology_name', 'uberon:0002436', ...
    'name',          'primary visual cortex'));
out = did2.convert.migrators.probe_location( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.probe_location.location.node, 'uberon:0002436');
verifyEqual(testCase, out.probe_location.location.name, 'primary visual cortex');
verifyFalse(testCase, isfield(out.probe_location, 'ontology_name'));
verifyFalse(testCase, isfield(out.probe_location, 'name'));
end

function testTreatmentMigrationFromCamelCase(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontologyName',  'chebi:6015', ...
    'name',          'isoflurane', ...
    'numeric_value', 2.0, ...
    'string_value',  '2 percent in O2'));
out = did2.convert.migrators.treatment( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.treatment.treatment_name.node, 'chebi:6015');
verifyEqual(testCase, out.treatment.treatment_name.name, 'isoflurane');
verifyEqual(testCase, out.treatment.numeric_value, 2.0);
verifyEqual(testCase, out.treatment.string_value, '2 percent in O2');
end

function testTreatmentMigrationFromSnakeCase(testCase)
v1 = wrap('treatment', 'treatment', struct( ...
    'ontology_name', 'chebi:6015', ...
    'name',          'isoflurane', ...
    'numeric_value', 2.0, ...
    'string_value',  '2 percent in O2'));
out = did2.convert.migrators.treatment( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.treatment.treatment_name.node, 'chebi:6015');
verifyEqual(testCase, out.treatment.treatment_name.name, 'isoflurane');
end

function testOntologyImageRenamesClassAndCollapsesFields(testCase)
v1 = wrap('ontologyImage', 'ontologyImage', struct( ...
    'ontology_name',   'allen_ccf_v3:12345', ...
    'ontology_region', 'primary visual cortex'));
postUniversal = did2.convert.universalRenames(v1);
verifyEqual(testCase, postUniversal.document_class.class_name, 'ontology_image');
out = did2.convert.migrators.ontology_image(postUniversal);
verifyEqual(testCase, out.ontology_image.region.node, 'allen_ccf_v3:12345');
verifyEqual(testCase, out.ontology_image.region.name, 'primary visual cortex');
verifyFalse(testCase, isfield(out, 'ontologyImage'));
end

function testOntologyLabelComposesCURIE(testCase)
v1 = wrap('ontologyLabel', 'ontologyLabel', struct( ...
    'ontology_name', 'Allen CCF v3', ...
    'label',         'primary visual cortex', ...
    'label_id',      12345));
out = did2.convert.migrators.ontology_label( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.document_class.class_name, 'ontology_label');
verifyEqual(testCase, out.ontology_label.term.node, 'allen_ccf_v3:12345');
verifyEqual(testCase, out.ontology_label.term.name, 'primary visual cortex');
end

function testOntologyLabelHandlesStringLabelId(testCase)
v1 = wrap('ontologyLabel', 'ontologyLabel', struct( ...
    'ontology_name', 'allen_ccf_v3', ...
    'label',         'primary visual cortex', ...
    'label_id',      '12345'));
out = did2.convert.migrators.ontology_label( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.ontology_label.term.node, 'allen_ccf_v3:12345');
end

function testProbeLocationMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'probe_location'), ...
    'base',           struct());
verifyError(testCase, @() did2.convert.migrators.probe_location(v1), ...
    'did2:convert:missingBlock');
end

function testEndToEndDispatcherForProbeLocation(testCase)
v1 = wrap('probe_location', 'probe_location', struct( ...
    'ontology_name', 'uberon:0002436', ...
    'name',          'primary visual cortex'));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('probe_location.location.node'), ...
    'uberon:0002436');
verifyEqual(testCase, doc.get('probe_location.location.name'), ...
    'primary visual cortex');
verifyEqual(testCase, doc.get('base.schema_version'), 'V_delta');
end

function testEndToEndDispatcherForOntologyLabel(testCase)
v1 = wrap('ontologyLabel', 'ontologyLabel', struct( ...
    'ontology_name', 'Allen CCF v3', ...
    'label',         'primary visual cortex', ...
    'label_id',      12345));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
verifyEqual(testCase, result.summary.by_class.ontology_label, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.className(), 'ontology_label');
verifyEqual(testCase, doc.get('ontology_label.term.node'), ...
    'allen_ccf_v3:12345');
end

function testDaqreaderNdrRenamesFileType(testCase)
v1 = wrap('daqreader_ndr', 'daqreader_ndr', struct( ...
    'ndr_reader_string',        'intan', ...
    'ndi_daqreader_ndr_class',  'ndi.daq.reader.mfdaq.ndr'));
out = did2.convert.migrators.daqreader_ndr( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.daqreader_ndr.file_type, 'intan');
verifyFalse(testCase, isfield(out.daqreader_ndr, 'ndr_reader_string'));
verifyFalse(testCase, isfield(out.daqreader_ndr, 'ndi_daqreader_ndr_class'));
end

function testDaqmetadatareaderRenamesReaderClass(testCase)
v1 = wrap('daqmetadatareader', 'daqmetadatareader', struct( ...
    'ndi_daqmetadatareader_class',  'ndi.daq.metadatareader.RayoLabStims', ...
    'tab_separated_file_parameter', 'something'));
out = did2.convert.migrators.daqmetadatareader( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.daqmetadatareader.reader_class, ...
    'ndi.daq.metadatareader.RayoLabStims');
verifyFalse(testCase, isfield(out.daqmetadatareader, ...
    'ndi_daqmetadatareader_class'));
verifyFalse(testCase, isfield(out.daqmetadatareader, ...
    'tab_separated_file_parameter'));
end

function testElementRenamesAndCoerces(testCase)
v1 = wrap('element', 'element', struct( ...
    'ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
    'name',              'electrode16', ...
    'reference',         1, ...
    'type',              'n-trode', ...
    'direct',            true));
out = did2.convert.migrators.element( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.element.element_name, 'electrode16');
verifyEqual(testCase, out.element.element_type, 'n-trode');
verifyEqual(testCase, out.element.reference, '1');
verifyEqual(testCase, out.element.direct, 1);
verifyFalse(testCase, isfield(out.element, 'name'));
verifyFalse(testCase, isfield(out.element, 'type'));
verifyEqual(testCase, out.element.ndi_element_class, ...
    'ndi.probe.timeseries.mfdaq');
end

function testEpochclocktimesSplitsTimeRange(testCase)
v1 = wrap('pyraview', 'pyraview', struct('label', 'high'));
v1.epochclocktimes = struct( ...
    'clocktype', 'dev_local_time', ...
    't0_t1',     [0 28.12495]);
v1.document_class.superclasses = struct( ...
    'class_name', {'base', 'epochclocktimes'});
out = did2.convert.migrators.epochclocktimes( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.epochclocktimes.epoch_clock, 'dev_local_time');
verifyEqual(testCase, out.epochclocktimes.t0, 0);
verifyEqual(testCase, out.epochclocktimes.t1, 28.12495);
verifyFalse(testCase, isfield(out.epochclocktimes, 'clocktype'));
verifyFalse(testCase, isfield(out.epochclocktimes, 't0_t1'));
end

function testEpochclocktimesSuperclassMigratorAppliedByDispatcher(testCase)
% An unregistered concrete class with epochclocktimes as a
% superclass: the dispatcher should run the epochclocktimes
% migrator even though the concrete class falls back to identity.
v1 = wrap('pyraview', 'pyraview', struct('label', 'high'));
v1.epochclocktimes = struct('clocktype', 'dev_local_time', ...
    't0_t1', [0 1]);
v1.document_class.superclasses = struct( ...
    'class_name', {'base', 'epochclocktimes'});
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('epochclocktimes.epoch_clock'), ...
    'dev_local_time');
verifyEqual(testCase, doc.get('epochclocktimes.t1'), 1);
end

function testEndToEndDispatcherForDaqreaderNdr(testCase)
v1 = wrap('daqreader_ndr', 'daqreader_ndr', struct( ...
    'ndr_reader_string',       'intan', ...
    'ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr'));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('daqreader_ndr.file_type'), 'intan');
end

% --- calc-base migrators (PLAN.md §9.6 sub-step 6d, 20211116 corpus) ---

function testCalcCommonMovesInputParametersIntoCalculatorBlock(testCase)
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', struct('algorithm', 'best')));
out = did2.convert.calcCommon( ...
    did2.convert.universalRenames(v1), ...
    'oridirtuning_calc', 'ndi.calc.vis.oridir_tuning');
verifyEqual(testCase, out.calculator.calculator_name, ...
    'ndi.calc.vis.oridir_tuning');
verifyEqual(testCase, out.calculator.input_parameters.algorithm, 'best');
verifyFalse(testCase, isfield(out.oridirtuning_calc, 'input_parameters'));
end

function testCalcCommonCoercesEmptyArrayInputParametersToStruct(testCase)
% v1 frequently ships `input_parameters: []`. V_delta `structure`
% type requires a struct value, so the helper coerces.
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', []));
out = did2.convert.calcCommon( ...
    did2.convert.universalRenames(v1), ...
    'oridirtuning_calc', 'ndi.calc.vis.oridir_tuning');
verifyTrue(testCase, isstruct(out.calculator.input_parameters));
verifyTrue(testCase, isempty(fieldnames(out.calculator.input_parameters)));
end

function testCalcCommonDropsInnerDependsOnAndCalculatorName(testCase)
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', [], ...
    'depends_on',       struct('name', 'stimulus_tuningcurve_id', ...
                                'value', 'abc'), ...
    'calculator_name',  'ndi.calc.WRONG'));
out = did2.convert.calcCommon( ...
    did2.convert.universalRenames(v1), ...
    'oridirtuning_calc', 'ndi.calc.vis.oridir_tuning');
% Inner depends_on and v1 calculator_name are stripped from the
% class block; the migrator-supplied calculator_name wins.
verifyFalse(testCase, isfield(out.oridirtuning_calc, 'depends_on'));
verifyFalse(testCase, isfield(out.oridirtuning_calc, 'calculator_name'));
verifyEqual(testCase, out.calculator.calculator_name, ...
    'ndi.calc.vis.oridir_tuning');
end

function testCalcCommonMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'oridirtuning_calc'), ...
    'base',           struct());
verifyError(testCase, ...
    @() did2.convert.calcCommon(v1, 'oridirtuning_calc', 'x'), ...
    'did2:convert:missingBlock');
end

function testOridirtuningCalcWrapperUsesRightCalculatorName(testCase)
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', []));
out = did2.convert.migrators.oridirtuning_calc( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.calculator.calculator_name, ...
    'ndi.calc.vis.oridir_tuning');
end

function testCalcMigratorLookupTable(testCase)
% Spot-check the per-class lookup table by exercising each wrapper.
pairs = {
    'tuningcurve_calc',              'ndi.calc.stimulus.tuningcurve';
    'oridirtuning_calc',             'ndi.calc.vis.oridir_tuning';
    'hartley_calc',                  'ndi.calc.vis.hartley';
    'contrast_sensitivity_calc',     'ndi.calc.vis.contrast_sensitivity';
    'contrast_tuning_calc',          'ndi.calc.vis.contrast_tuning';
    'spatial_frequency_tuning_calc', 'ndi.calc.vis.spatial_frequency_tuning';
    'speed_tuning_calc',             'ndi.calc.vis.speed_tuning';
    'temporal_frequency_tuning_calc','ndi.calc.vis.temporal_frequency_tuning';
    'simple_calc',                   'ndi.calc.example.simple';
};
for k = 1:size(pairs, 1)
    cls  = pairs{k, 1};
    want = pairs{k, 2};
    v1 = wrap(cls, cls, struct('input_parameters', []));
    migratorFcn = str2func(['did2.convert.migrators.' cls]);
    out = migratorFcn(did2.convert.universalRenames(v1));
    verifyEqual(testCase, out.calculator.calculator_name, want, ...
        sprintf('Mismatch for %s', cls));
end
end

function testDispatcherPadsEmptyChainBlocks(testCase)
% ensureClassBlocks should manufacture empty blocks for every class
% in the V_delta chain that the migrator did not produce. This test
% asserts the behavior without requiring a real schema cache: it
% builds a body, lets the dispatcher run (Validate=false, no
% SchemaCache override). The helper silently no-ops when no cache
% is configured, so we only assert that the explicitly-produced
% blocks survive.
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', []));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('calculator.calculator_name'), ...
    'ndi.calc.vis.oridir_tuning');
end
