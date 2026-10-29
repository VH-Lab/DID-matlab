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

function testTheUnreachedSuperclassMigratorsAreGone(testCase)
% Decided by Jess Haley, 2026-10-27 [unreached superclass migrators deleted]
% (did-schema V_eta_go_forward_class_audit.md): pyraview, the only class at the
% locked NDI main that names `epochclocktimes` or `filter` as a superclass,
% reads raw v1 (did2.convert.rawV1Classes), so no superclass pass reaches them,
% and they are deleted. pyraview reads both blocks itself.
for cls = {'epochclocktimes', 'filter'}
    verifyEmpty(testCase, which(['did2.convert.migrators.' cls{1}]), ...
        sprintf('+migrators/%s.m is back', cls{1}));
end
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'pyraview')), ...
    'pyraview no longer reads raw v1, so the superclass pass would reach it again');
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

% --- ngrid base migrator: a standalone ngrid is carried whole as v1 ---
% INVERTED 2026-10-29. [ngrid with no statement carried] (Decided by Jess
% Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "an
% ontologyImage `ngrid` whose only edge is its table row, and a standalone
% `ngrid`, are carried whole as v1 `needs_mapping`". The base migrator runs
% only as the concrete migrator of a standalone `ngrid` (a superclass block
% gets +migrators_j/+super/ngrid.m), and it no longer reshapes the block or
% drops `data_size` / `coordinates` (did-schema #227): it returns the body
% unchanged and notes the carry. The fixtures are ngrid documents now (they
% were hartley_calc bodies, from when this ran as the superclass pass).

function testNgridKeepsAllFourV1FieldsAndIsCarried(testCase)
% INVERTED 2026-10-29 from testNgridDerivesNdimsFromDataDim (which asserted
% the reshape to ndims / dim_sizes and the drop of data_size and coordinates)
v1 = wrap('ngrid', 'ngrid', struct( ...
    'data_size',   8, ...
    'data_type',   'double', ...
    'data_dim',    [200 200 36 2], ...
    'coordinates', [0 1 2 3]));
pre = did2.convert.universalRenames(v1);
did2.convert.reportNote('reset');
out = did2.convert.migrators.ngrid(pre);
verifyEqual(testCase, out, pre, 'the body is returned unchanged');
verifyEqual(testCase, out.ngrid.data_size, 8);
verifyEqual(testCase, out.ngrid.data_dim, [200 200 36 2]);
verifyEqual(testCase, out.ngrid.coordinates, [0 1 2 3]);
verifyFalse(testCase, isfield(out.ngrid, 'ndims'));
verifyFalse(testCase, isfield(out.ngrid, 'dim_sizes'));
verifyEqual(testCase, did2.convert.reportNote('pending', 'carried_as_v1'), 1, ...
    'the carry is noted');
did2.convert.reportNote('reset');
end

function testNgridWithExplicitNdimsIsReturnedUnchanged(testCase)
% INVERTED 2026-10-29 from testNgridPreservesExplicitNdims: nothing is derived
% or overwritten; the body is carried as it came
v1 = wrap('ngrid', 'ngrid', struct( ...
    'ndims',    7, ...
    'data_dim', [10 10]));
pre = did2.convert.universalRenames(v1);
out = did2.convert.migrators.ngrid(pre);
did2.convert.reportNote('reset');
verifyEqual(testCase, out, pre);
end

function testNgridNoOpWhenBlockAbsent(testCase)
v1 = wrap('hartley_calc', 'hartley_calc', struct('input_parameters', []));
out = did2.convert.migrators.ngrid(did2.convert.universalRenames(v1));
did2.convert.reportNote('reset');
verifyFalse(testCase, isfield(out, 'ngrid'));
end

function testNgridWithDimSizesIsReturnedUnchanged(testCase)
% INVERTED 2026-10-29 from testNgridDerivesFromExistingDimSizes: no ndims is
% derived
v1 = wrap('ngrid', 'ngrid', struct('dim_sizes', [5 5 5]));
pre = did2.convert.universalRenames(v1);
out = did2.convert.migrators.ngrid(pre);
did2.convert.reportNote('reset');
verifyEqual(testCase, out, pre);
verifyFalse(testCase, isfield(out.ngrid, 'ndims'));
end

function testAStandaloneNgridIsCarriedThroughTheDispatcher(testCase)
% [ngrid with no statement carried] end to end: one document, the v1 source,
% recorded as a pass-1 passthrough, noted carried_as_v1 needs_mapping, and
% every v1 field kept (did-schema #227: data_size and coordinates were lost)
v1 = wrap('ngrid', 'ngrid', struct( ...
    'data_size', 1, 'data_type', 'uint8', 'data_dim', [4 3], ...
    'coordinates', [1; 2; 3; 4; 1; 2; 3]));
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, numel(out.passthrough), 1, 'recorded as a pass-1 passthrough');
doc = out.migrated{1};
verifyEqual(testCase, doc.get('ngrid.data_size'), 1);
verifyEqual(testCase, doc.get('ngrid.data_dim'), [4 3]);
verifyEqual(testCase, doc.get('ngrid.coordinates'), [1; 2; 3; 4; 1; 2; 3]);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'carried_as_v1'));
verifyEqual(testCase, notes.carried_as_v1.count, 1);
verifyTrue(testCase, startsWith(notes.carried_as_v1.distinct_details{1}, 'needs_mapping: '));
end

% --- element, ontology_image, ontology_label base migrators ---

function testTheUnreachedBaseMigratorsAreGone(testCase)
% [early migration pieces fixed] (1) (Jess Haley, 2026-10-26): one migrator
% per class. +migrators/element.m, ontology_image.m and ontology_label.m were
% reached by nothing: each class has a +migrators_j migrator (which v1_to_v2
% runs instead of the +migrators one), and no NDI template at the locked main
% (3cb19a8) names element, ontologyImage or ontologyLabel as a superclass, so
% the superclass pass never met them either. They are deleted. Their behaviour
% is tested where it now lives: testRawV1RoundTripElement,
% testRawV1RoundTripOntologyImage and testRawV1RoundTripImage (ontologyLabel).
for cls = {'element', 'ontology_image', 'ontology_label'}
    verifyEmpty(testCase, which(['did2.convert.migrators.' cls{1}]), ...
        sprintf('+migrators/%s.m is back', cls{1}));
    verifyNotEmpty(testCase, which(['did2.convert.migrators_j.' cls{1}]), ...
        sprintf('+migrators_j/%s.m is missing', cls{1}));
end
end

% --- position_metadata, distance_metadata, stimulus_bath ---
% Their +migrators base migrators are deleted ([early migration pieces fixed]
% (1)): never reached (each class has a +migrators_j migrator), or reached only
% through distance_metadata's own, which now reshapes the raw v1 spelling. The
% classes read raw v1 (did2.convert.rawV1Classes); their round trips are
% testRawV1RoundTripBath and testRawV1RoundTripPosition.
