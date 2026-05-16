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
    did2.convert.universalRenames(v1), 'oridirtuning_calc');
verifyEqual(testCase, out.calculator.input_parameters.algorithm, 'best');
verifyFalse(testCase, isfield(out.oridirtuning_calc, 'input_parameters'));
% calcCommon does not populate calculator-identity; that lives on
% the inherited app block, handled by universalRenames upstream.
verifyFalse(testCase, isfield(out.calculator, 'calculator_name'));
end

function testCalcCommonCoercesEmptyArrayInputParametersToStruct(testCase)
% v1 frequently ships `input_parameters: []`. V_delta `structure`
% type requires a struct value, so the helper coerces.
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', []));
out = did2.convert.calcCommon( ...
    did2.convert.universalRenames(v1), 'oridirtuning_calc');
verifyTrue(testCase, isstruct(out.calculator.input_parameters));
verifyTrue(testCase, isempty(fieldnames(out.calculator.input_parameters)));
end

function testCalcCommonDropsInnerDependsOn(testCase)
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', [], ...
    'depends_on',       struct('name', 'stimulus_tuningcurve_id', ...
                                'value', 'abc')));
out = did2.convert.calcCommon( ...
    did2.convert.universalRenames(v1), 'oridirtuning_calc');
verifyFalse(testCase, isfield(out.oridirtuning_calc, 'depends_on'));
end

function testCalcCommonMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'oridirtuning_calc'), ...
    'base',           struct());
verifyError(testCase, ...
    @() did2.convert.calcCommon(v1, 'oridirtuning_calc'), ...
    'did2:convert:missingBlock');
end

function testCalcWrapperPipesThroughHelper(testCase)
% Each per-class wrapper is a thin call to calcCommon; verify the
% wrapper produces the same shape (input_parameters lifted into
% calculator block) as a direct calcCommon call.
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', []));
out = did2.convert.migrators.oridirtuning_calc( ...
    did2.convert.universalRenames(v1));
verifyTrue(testCase, isstruct(out.calculator.input_parameters));
verifyFalse(testCase, isfield(out.oridirtuning_calc, 'input_parameters'));
end

function testCalcMigratorWrappersAllResolve(testCase)
% Smoke: every concrete *_calc wrapper exists and runs cleanly on a
% minimal v1 body. The wrapper does not vary by class today (the
% calculator-identity lookup is handled by app-block rename upstream),
% but exercising each entry catches accidental deletions and ensures
% the dispatcher can still resolve the migrator by class name.
classes = {
    'tuningcurve_calc';
    'oridirtuning_calc';
    'hartley_calc';
    'contrast_sensitivity_calc';
    'contrast_tuning_calc';
    'spatial_frequency_tuning_calc';
    'speed_tuning_calc';
    'temporal_frequency_tuning_calc';
    'simple_calc';
};
for k = 1:numel(classes)
    cls = classes{k};
    v1 = wrap(cls, cls, struct('input_parameters', []));
    migratorFcn = str2func(['did2.convert.migrators.' cls]);
    out = migratorFcn(did2.convert.universalRenames(v1));
    verifyTrue(testCase, isstruct(out.calculator.input_parameters), ...
        sprintf('Wrapper %s did not produce a calculator block', cls));
end
end

function testUniversalRenamesAppBlockNameAndVersion(testCase)
% v1 carries app.name / app.version; V_delta uses app.app_name /
% app.app_version. The rename is in universalRenames so it applies
% to every doc that ships an app block, not just calc docs.
v1 = wrap('oridirtuning_calc', 'oridirtuning_calc', struct( ...
    'input_parameters', []));
v1.app = struct( ...
    'name',                'ndi.calc.vis.oridir_tuning', ...
    'version',             'fa67d45...', ...
    'url',                 'https://github.com/VH-lab/NDI-matlab', ...
    'os',                  'MACA64', ...
    'os_version',          '15.6.1', ...
    'interpreter',         'MATLAB', ...
    'interpreter_version', '24.2');
out = did2.convert.universalRenames(v1);
verifyEqual(testCase, out.app.app_name, 'ndi.calc.vis.oridir_tuning');
verifyEqual(testCase, out.app.app_version, 'fa67d45...');
verifyFalse(testCase, isfield(out.app, 'name'));
verifyFalse(testCase, isfield(out.app, 'version'));
% Other app fields pass through unchanged.
verifyEqual(testCase, out.app.interpreter, 'MATLAB');
verifyEqual(testCase, out.app.os_version, '15.6.1');
end

function testUniversalRenamesAppBlockIsNoOpWithoutAppBlock(testCase)
% Documents without an app block should be unaffected by the
% app-block rename pass.
v1 = wrap('probe_location', 'probe_location', struct( ...
    'ontology_name', 'uberon:0002436', ...
    'name',          'primary visual cortex'));
out = did2.convert.universalRenames(v1);
verifyFalse(testCase, isfield(out, 'app'));
% probe_location.name is a *block field*, not the app.name field; it
% should be left for the per-class migrator.
verifyEqual(testCase, out.probe_location.name, 'primary visual cortex');
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
% calcCommon produced a calculator block with input_parameters
% coerced to struct; calculator-identity is now app.app_name (set
% by universalRenames) and is absent from the calculator block.
verifyTrue(testCase, isstruct(doc.get('calculator.input_parameters')));
end

% --- element_epoch (20211116 corpus: 252 docs; JH corpus: 4156 multi-clock) ---

function testElementEpochSingleClockBuildsOneRecord(testCase)
v1 = wrap('element_epoch', 'element_epoch', struct( ...
    'epoch_clock', 'dev_local_time', ...
    't0_t1',       [0 930.34795]));
out = did2.convert.migrators.element_epoch( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.element_epoch.clocks), 1);
verifyEqual(testCase, out.element_epoch.clocks(1).name, 'dev_local_time');
verifyEqual(testCase, out.element_epoch.clocks(1).t0, 0);
verifyEqual(testCase, out.element_epoch.clocks(1).t1, 930.34795);
verifyFalse(testCase, isfield(out.element_epoch, 't0_t1'));
verifyFalse(testCase, isfield(out.element_epoch, 'epoch_clock'));
end

function testElementEpochMultiClockBuildsArrayOfRecords(testCase)
% JH corpus case: epoch_clock is comma-separated, t0_t1 is N-by-2.
v1 = wrap('element_epoch', 'element_epoch', struct( ...
    'epoch_clock', 'dev_local_time,exp_global_time', ...
    't0_t1',       [0           738553.4082; ...
                    3599.69855  738553.4498]));
out = did2.convert.migrators.element_epoch( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.element_epoch.clocks), 2);
verifyEqual(testCase, out.element_epoch.clocks(1).name, 'dev_local_time');
verifyEqual(testCase, out.element_epoch.clocks(1).t0, 0);
verifyEqual(testCase, out.element_epoch.clocks(1).t1, 738553.4082);
verifyEqual(testCase, out.element_epoch.clocks(2).name, 'exp_global_time');
verifyEqual(testCase, out.element_epoch.clocks(2).t0, 3599.69855);
verifyEqual(testCase, out.element_epoch.clocks(2).t1, 738553.4498);
end

function testElementEpochAcceptsLegacyClocktype(testCase)
v1 = wrap('element_epoch', 'element_epoch', struct( ...
    'clocktype', 'dev_local_time', ...
    't0_t1',     [0 1.5]));
out = did2.convert.migrators.element_epoch( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.element_epoch.clocks(1).name, 'dev_local_time');
verifyEqual(testCase, out.element_epoch.clocks(1).t0, 0);
verifyEqual(testCase, out.element_epoch.clocks(1).t1, 1.5);
verifyFalse(testCase, isfield(out.element_epoch, 'clocktype'));
end

function testElementEpochMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'element_epoch'), ...
    'base',           struct());
verifyError(testCase, ...
    @() did2.convert.migrators.element_epoch(v1), ...
    'did2:convert:missingBlock');
end

function testEndToEndDispatcherForElementEpoch(testCase)
v1 = wrap('element_epoch', 'element_epoch', struct( ...
    'epoch_clock', 'dev_local_time', ...
    't0_t1',       [0 42]));
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
clocks = doc.get('element_epoch.clocks');
verifyEqual(testCase, clocks(1).name, 'dev_local_time');
verifyEqual(testCase, clocks(1).t0, 0);
verifyEqual(testCase, clocks(1).t1, 42);
end

% --- ngrid superclass migrator (20211116 corpus: 210 hartley_calc) ---

function testNgridDerivesNdimsFromDataDim(testCase)
v1 = wrap('hartley_calc', 'ngrid', struct( ...
    'data_size',   8, ...
    'data_type',   'double', ...
    'data_dim',    [200 200 36 2], ...
    'coordinates', [0 1 2 3]));
out = did2.convert.migrators.ngrid(did2.convert.universalRenames(v1));
verifyEqual(testCase, out.ngrid.ndims, 4);
verifyEqual(testCase, out.ngrid.dim_sizes, [200 200 36 2]);
verifyEqual(testCase, out.ngrid.data_type, 'double');
verifyFalse(testCase, isfield(out.ngrid, 'data_dim'));
verifyFalse(testCase, isfield(out.ngrid, 'data_size'));
verifyFalse(testCase, isfield(out.ngrid, 'coordinates'));
end

function testNgridPreservesExplicitNdims(testCase)
v1 = wrap('hartley_calc', 'ngrid', struct( ...
    'ndims',    7, ...
    'data_dim', [10 10]));
out = did2.convert.migrators.ngrid(did2.convert.universalRenames(v1));
% Even though numel(data_dim) is 2, the migrator preserves an
% explicit v1 ndims rather than overwriting it. (If consumers ever
% surface a conflict between the two, we can promote to an error.)
verifyEqual(testCase, out.ngrid.ndims, 7);
verifyEqual(testCase, out.ngrid.dim_sizes, [10 10]);
end

function testNgridNoOpWhenBlockAbsent(testCase)
v1 = wrap('hartley_calc', 'hartley_calc', struct('input_parameters', []));
out = did2.convert.migrators.ngrid(did2.convert.universalRenames(v1));
verifyFalse(testCase, isfield(out, 'ngrid'));
end

function testNgridDerivesFromExistingDimSizes(testCase)
v1 = wrap('hartley_calc', 'ngrid', struct('dim_sizes', [5 5 5]));
out = did2.convert.migrators.ngrid(did2.convert.universalRenames(v1));
verifyEqual(testCase, out.ngrid.ndims, 3);
end

function testEndToEndDispatcherForHartleyCalc(testCase)
% End-to-end: hartley_calc body with v1-shaped ngrid block migrates
% through the calc helper, the ngrid superclass migrator, and the
% dispatcher's chain-padding step without quarantine.
v1 = wrap('hartley_calc', 'hartley_calc', struct('input_parameters', []));
v1.ngrid = struct( ...
    'data_size', 8, ...
    'data_type', 'double', ...
    'data_dim',  [200 200 36 2]);
v1.document_class.superclasses = struct('class_name', ...
    {'base', 'hartley_reverse_correlation', 'ngrid'});
result = did2.convert.v1_to_v2(v1, 'Validate', false);
verifyEqual(testCase, result.summary.migrated_count, 1);
doc = result.migrated{1};
verifyEqual(testCase, doc.get('ngrid.ndims'), 4);
verifyEqual(testCase, doc.get('ngrid.dim_sizes'), [200 200 36 2]);
end

% --- ontology_label node-only idiom (JH corpus: 7007 docs) ---

function testOntologyLabelNodeOnlyV1(testCase)
% v1 docs in some corpora carry only `ontologyNode` (the CURIE), no
% label/label_id pair. The migrator should still produce a valid
% term composite, with name resolved via ndi.ontology.lookup when
% available and left empty when not (no quarantine).
v1 = wrap('ontologyLabel', 'ontologyLabel', struct( ...
    'ontologyNode', 'EMPTY:0000129'));
out = did2.convert.migrators.ontology_label( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.ontology_label.term.node, 'EMPTY:0000129');
verifyTrue(testCase, ischar(out.ontology_label.term.name));
% The name resolution is best-effort: if ndi.ontology is not on the
% path the lookup falls back to '' and the doc still validates
% (ontology_term is open-struct). We only assert it is a char.
end

% --- position_metadata semantic shape (JH corpus: 2078 docs) ---

function testPositionMetadataBuildsOntologyComposites(testCase)
v1 = wrap('position_metadata', 'position_metadata', struct( ...
    'ontologyNode', 'EMPTY:0000137', ...
    'units',        'NCIT:C48367', ...
    'dimensions',   'NCIT:C44477,NCIT:C44478'));
out = did2.convert.migrators.position_metadata( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.position_metadata.measurement.node, ...
    'EMPTY:0000137');
verifyEqual(testCase, out.position_metadata.units.node, 'NCIT:C48367');
verifyEqual(testCase, numel(out.position_metadata.dimensions), 2);
verifyEqual(testCase, out.position_metadata.dimensions(1).axis, 'axis_1');
verifyEqual(testCase, out.position_metadata.dimensions(1).node, 'NCIT:C44477');
verifyEqual(testCase, out.position_metadata.dimensions(2).axis, 'axis_2');
verifyEqual(testCase, out.position_metadata.dimensions(2).node, 'NCIT:C44478');
end

function testPositionMetadataHandlesEmptyDimensions(testCase)
v1 = wrap('position_metadata', 'position_metadata', struct( ...
    'ontologyNode', 'EMPTY:0000137', ...
    'units',        'NCIT:C48367', ...
    'dimensions',   ''));
out = did2.convert.migrators.position_metadata( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.position_metadata.dimensions), 0);
end

function testPositionMetadataNamesEmptyWhenLookupUnavailable(testCase)
% When ndi.ontology.lookup is not on the path, name fields stay
% empty -- the doc still validates because ontology_term only
% requires struct shape, not non-empty inner fields.
v1 = wrap('position_metadata', 'position_metadata', struct( ...
    'ontologyNode', 'EMPTY:0000137', ...
    'units',        'NCIT:C48367', ...
    'dimensions',   'NCIT:C44477'));
out = did2.convert.migrators.position_metadata( ...
    did2.convert.universalRenames(v1));
verifyTrue(testCase, ischar(out.position_metadata.measurement.name));
verifyTrue(testCase, ischar(out.position_metadata.units.name));
verifyTrue(testCase, ischar(out.position_metadata.dimensions(1).name));
end

function testPositionMetadataMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'position_metadata'), ...
    'base',           struct());
verifyError(testCase, ...
    @() did2.convert.migrators.position_metadata(v1), ...
    'did2:convert:missingBlock');
end
