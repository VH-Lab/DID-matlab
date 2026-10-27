function tests = testMigrators
%TESTMIGRATORS Per-class did_v1 -> V2 migrator tests.
%
%   Exercises the base class migrators against the worked examples of
%   did-schema's per-class conversion notes (deleted with did-schema #88).
%
%   Tests run with Validate=false on the end-to-end dispatcher case
%   so they do not depend on the schema cache being able to resolve
%   V2 schemas at the test-runner working directory.
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
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct( ...
    'id',         'aabb1122ccdd3344_1122334455667788', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       'migrator-example', ...
    'datestamp',  '2024-06-01T12:00:00.000Z');
v1.(blockKey) = block;
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

function testElementDirectLogicalCoercedToInteger(testCase)
% The PRED corpus (and writes in the larger public corpora) emits
% element.direct as a JSON boolean. After jsondecode that arrives
% as MATLAB `logical`, which V2's validator rejects with
% `Field "element.direct" must be integer.`. The element migrator
% canonicalises it to a numeric integer.
v1 = wrap('element', 'element', struct( ...
    'ndi_element_class', 'ndi.probe.timeseries.stimulator', ...
    'name',              'rayostim', ...
    'reference',         1, ...
    'type',              'stimulator', ...
    'direct',            true));
out = did2.convert.migrators.element( ...
    did2.convert.universalRenames(v1));
verifyTrue(testCase, isnumeric(out.element.direct));
verifyEqual(testCase, out.element.direct, 1);
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

% --- calc-base migrators (20211116 corpus) ---
% (calcCommon and the hartley_calc / speed_tuning_calc / simple_calc wrappers
% are deleted, never reached: testRawV1RoundTripSpike
% testTheOldSpikeWrappersAreGone; jCalculation's inner depends_on check is
% tested in testRawV1RoundTripTuning)

function testTheOldTuningWrappersAreGone(testCase)
% [early migration pieces fixed] (1) (Jess Haley, 2026-10-26): one migrator
% per class. The tuning family reads raw v1 through its +migrators_j migrator
% (did2.convert.rawV1Classes); the old +migrators/<class>.m wrappers were never
% reached for them (a class with a +migrators_j migrator skips its +migrators
% one, and no v1 class names these as a superclass) and are deleted.
for cls = {'tuningcurve_calc', 'oridirtuning_calc', 'contrast_sensitivity_calc', ...
        'contrast_tuning_calc', 'spatial_frequency_tuning_calc', ...
        'temporal_frequency_tuning_calc'}
    verifyEmpty(testCase, which(['did2.convert.migrators.' cls{1}]), ...
        sprintf('+migrators/%s.m is back', cls{1}));
    verifyNotEmpty(testCase, which(['did2.convert.migrators_j.' cls{1}]), ...
        sprintf('+migrators_j/%s.m is missing', cls{1}));
end
end

function testUniversalRenamesAppBlockNameAndVersion(testCase)
% v1 carries app.name / app.version; V2 uses app.app_name /
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
% Multi-clock case: epoch_clock is comma-separated, t0_t1 is the
% canonical 2-by-N (per NDI element_epoch_schema.json:
% "parameters":[2,NaN], "Each column is for a different epoch clock
% type"). This is what ndi.element.addepoch and oneepoch actually
% write.
v1 = wrap('element_epoch', 'element_epoch', struct( ...
    'epoch_clock', 'dev_local_time,exp_global_time', ...
    't0_t1',       [0           738553.4082; ...
                    3599.69855  738553.4498]));
out = did2.convert.migrators.element_epoch( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.element_epoch.clocks), 2);
verifyEqual(testCase, out.element_epoch.clocks(1).name, 'dev_local_time');
verifyEqual(testCase, out.element_epoch.clocks(1).t0, 0);
verifyEqual(testCase, out.element_epoch.clocks(1).t1, 3599.69855);
verifyEqual(testCase, out.element_epoch.clocks(2).name, 'exp_global_time');
verifyEqual(testCase, out.element_epoch.clocks(2).t0, 738553.4082);
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

function testElementEpochT0T1ThatDoesNotMatchItsClocksIsNotConverted(testCase)
% [small unread settings] (4) (Jess Haley, 2026-10-26): a t0_t1 whose column
% count is not the clock count (either direction), or that is missing or not
% numeric, is returned UNCHANGED with a `carried_as_v1` note; the zero-padding
% and truncation are gone ([no invented values]).
cases = { ...
    struct('epoch_clock', 'dev_local_time,exp_global_time', 't0_t1', [0; 930]), 'for 2 clock'; ...
    struct('epoch_clock', 'dev_local_time', 't0_t1', [0 1 2; 3 4 5]), '3 column'; ...
    struct('epoch_clock', 'dev_local_time'), 'missing'; ...
    struct('epoch_clock', 'dev_local_time', 't0_t1', 'abc'), 'not numeric'};
for k = 1:size(cases, 1)
    pre = did2.convert.universalRenames(wrap('element_epoch', 'element_epoch', cases{k, 1}));
    did2.convert.reportNote('reset');
    out = did2.convert.migrators.element_epoch(pre);
    notes = did2.convert.reportNote('collect');
    did2.convert.reportNote('reset');
    verifyTrue(testCase, isequaln(out, pre), sprintf('case %d: changed', k));
    verifyTrue(testCase, isfield(notes, 'carried_as_v1') && ...
        contains(notes.carried_as_v1.distinct_details{1}, cases{k, 2}), ...
        sprintf('case %d: no note naming "%s"', k, cases{k, 2}));
end
end

function testElementEpochNamingNoClockOrADifferentClocktypeIsNotConverted(testCase)
% [no invented values]: no `epoch_clock` is not read as 'dev_local_time'; and a
% legacy `clocktype` beside `epoch_clock` is dropped only when it restates it.
cases = { ...
    struct('t0_t1', [0 1]), 'epoch_clock (missing'; ...
    struct('epoch_clock', '', 't0_t1', [0 1]), 'epoch_clock (missing'; ...
    struct('epoch_clock', 'dev_local_time', 'clocktype', 'utc', 't0_t1', [0 1]), 'clocktype'};
for k = 1:size(cases, 1)
    pre = did2.convert.universalRenames(wrap('element_epoch', 'element_epoch', cases{k, 1}));
    did2.convert.reportNote('reset');
    out = did2.convert.migrators.element_epoch(pre);
    notes = did2.convert.reportNote('collect');
    did2.convert.reportNote('reset');
    verifyTrue(testCase, isequaln(out, pre), sprintf('case %d: changed', k));
    verifyTrue(testCase, isfield(notes, 'carried_as_v1') && ...
        contains(notes.carried_as_v1.distinct_details{1}, cases{k, 2}), ...
        sprintf('case %d: no note naming "%s"', k, cases{k, 2}));
end
% the same clock twice: the clocktype restates it and is dropped
pre = did2.convert.universalRenames(wrap('element_epoch', 'element_epoch', ...
    struct('epoch_clock', 'dev_local_time', 'clocktype', 'dev_local_time', 't0_t1', [0 1])));
out = did2.convert.migrators.element_epoch(pre);
verifyEqual(testCase, out.element_epoch.clocks(1).name, 'dev_local_time');
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

% --- distance_metadata A/B paired endpoints (JH corpus: 2078 docs) ---

function testDistanceMetadataBuildsTwoEndpointArray(testCase)
v1 = wrap('distance_metadata', 'distance_metadata', struct( ...
    'ontologyNode_A',          'EMPTY:0000096', ...
    'integerIDs_A',            1, ...
    'ontologyNumericValues_A', [], ...
    'ontologyStringValues_A',  'doc_a_1', ...
    'ontologyNode_B',          'EMPTY:0000134', ...
    'integerIDs_B',            [1 2 3], ...
    'ontologyNumericValues_B', [], ...
    'ontologyStringValues_B',  'doc_b_1,doc_b_2,doc_b_3', ...
    'units',                   'NCIT:C48367'));
out = did2.convert.migrators.distance_metadata( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.distance_metadata.endpoints), 2);
verifyEqual(testCase, out.distance_metadata.endpoints(1).label, 'A');
verifyEqual(testCase, out.distance_metadata.endpoints(1).measurement.node, ...
    'EMPTY:0000096');
verifyEqual(testCase, out.distance_metadata.endpoints(1).integer_ids, 1);
verifyEqual(testCase, out.distance_metadata.endpoints(1).string_ids, ...
    string({'doc_a_1'}));
verifyEqual(testCase, out.distance_metadata.endpoints(2).label, 'B');
verifyEqual(testCase, out.distance_metadata.endpoints(2).integer_ids, ...
    [1 2 3]);
verifyEqual(testCase, out.distance_metadata.endpoints(2).string_ids, ...
    string({'doc_b_1','doc_b_2','doc_b_3'}));
verifyEqual(testCase, out.distance_metadata.units.node, 'NCIT:C48367');
end

function testDistanceMetadataPreservesEmptyNumericValues(testCase)
v1 = wrap('distance_metadata', 'distance_metadata', struct( ...
    'ontologyNode_A',          'EMPTY:0000096', ...
    'integerIDs_A',            1, ...
    'ontologyNumericValues_A', [], ...
    'ontologyStringValues_A',  'doc_a_1', ...
    'ontologyNode_B',          'EMPTY:0000134', ...
    'integerIDs_B',            [1 2], ...
    'ontologyNumericValues_B', [], ...
    'ontologyStringValues_B',  'doc_b_1,doc_b_2', ...
    'units',                   'NCIT:C48367'));
out = did2.convert.migrators.distance_metadata( ...
    did2.convert.universalRenames(v1));
verifyTrue(testCase, isempty(out.distance_metadata.endpoints(1).numeric_values));
verifyTrue(testCase, isempty(out.distance_metadata.endpoints(2).numeric_values));
end

function testDistanceMetadataMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'distance_metadata'), ...
    'base',           struct());
verifyError(testCase, ...
    @() did2.convert.migrators.distance_metadata(v1), ...
    'did2:convert:missingBlock');
end

% --- stimulus_bath ontology + CSV mixture (Dab corpus: 1605 docs) ---

function testStimulusBathLocationRenamesOntologyNode(testCase)
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'NCIm:C0179246', ...
                       'name', 'Baths, Water, Laboratory'), ...
    'mixture_table', ''));
out = did2.convert.migrators.stimulus_bath( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.stimulus_bath.location.node, 'NCIm:C0179246');
verifyEqual(testCase, out.stimulus_bath.location.name, ...
    'Baths, Water, Laboratory');
end

function testStimulusBathParsesSingleMixtureRow(testCase)
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'NCIm:C0179246', ...
                       'name', 'Baths, Water, Laboratory'), ...
    'mixture_table', ['ontologyName,name,value,ontologyUnit,unitName' newline ...
                       'NCIm:C1098706,arginine-vasopressin,2e-07,OM:MolarVolumeUnit,Molar' newline]));
out = did2.convert.migrators.stimulus_bath( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.stimulus_bath.mixture), 1);
verifyEqual(testCase, out.stimulus_bath.mixture(1).chemical.node, ...
    'NCIm:C1098706');
verifyEqual(testCase, out.stimulus_bath.mixture(1).chemical.name, ...
    'arginine-vasopressin');
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.source_unit, 'Molar');
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.source_value, 2e-7);
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.molar, 2e-7);
end

function testStimulusBathScalesMicromolarToMolar(testCase)
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'NCIm:C0179246', 'name', 'water'), ...
    'mixture_table', ['ontologyName,name,value,ontologyUnit,unitName' newline ...
                       'CHEBI:1234,sample,5,OM:Micromolar,Micromolar']));
out = did2.convert.migrators.stimulus_bath( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.source_value, 5);
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.source_unit, ...
    'Micromolar');
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.molar, 5e-6, ...
    'AbsTol', 1e-15);
end

function testStimulusBathHandlesUnknownUnit(testCase)
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'NCIm:C0179246', 'name', 'water'), ...
    'mixture_table', ['ontologyName,name,value,ontologyUnit,unitName' newline ...
                       'CHEBI:1234,sample,42,OM:Weird,WeirdUnit']));
out = did2.convert.migrators.stimulus_bath( ...
    did2.convert.universalRenames(v1));
% Unknown unit: source preserved, no canonical populated.
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.source_value, 42);
verifyEqual(testCase, out.stimulus_bath.mixture(1).amount.source_unit, ...
    'WeirdUnit');
verifyFalse(testCase, isfield(out.stimulus_bath.mixture(1).amount, 'molar'));
verifyFalse(testCase, isfield(out.stimulus_bath.mixture(1).amount, 'grams_per_liter'));
end

function testStimulusBathEmptyMixtureTableIsZeroLengthArray(testCase)
v1 = wrap('stimulus_bath', 'stimulus_bath', struct( ...
    'location', struct('ontologyNode', 'NCIm:C0179246', 'name', 'water'), ...
    'mixture_table', ''));
out = did2.convert.migrators.stimulus_bath( ...
    did2.convert.universalRenames(v1));
verifyEqual(testCase, numel(out.stimulus_bath.mixture), 0);
end

function testStimulusBathMissingBlockErrors(testCase)
v1 = struct( ...
    'document_class', struct('class_name', 'stimulus_bath'), ...
    'base',           struct());
verifyError(testCase, ...
    @() did2.convert.migrators.stimulus_bath(v1), ...
    'did2:convert:missingBlock');
end
