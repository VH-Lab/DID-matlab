function tests = testTuningCurveLevels
%TESTTUNINGCURVELEVELS The LEVEL defects in the shared tuning reshape, and the
%   flat raw curve's control fields.
%
%   `+migrators_j/private/jTuningCurveValue.m` is shared by 12 migrators (the 5 v1
%   tuning result classes, their 5 `*_calc` wrappers, `stimulus_tuningcurve` and
%   `tuningcurve_calc` -- every `jCalculation(..., 'tuning_curve', ...)` call site).
%   Two of its reads went to a level the writers do not populate:
%
%     A  controlBlock read control_mean / control_stddev / control_stderr off the
%        BLOCK. All five writers put every control field INSIDE `tuning_curve`, and
%        two of them (spatial_frequency, temporal_frequency) write two more names
%        -- control_mean_stddev, control_mean_stderr -- that the read never mentioned.
%     B  response_units was read off the BLOCK. That is correct for the FLAT raw
%        stimulus_tuningcurve and wrong for all five fitted composites, which spell
%        it `properties.response_units`.
%     C  the FLAT raw stimulus_tuningcurve spells its control fields
%        control_response_mean / _stddev / _stderr / control_individual_responses_real
%        / _imaginary, and NOT ONE of those five matched any of the six names
%        controlBlock searched -- so that shape contributed an EMPTY control block and
%        the data was dropped. Defect A's repair fixed the LEVEL for the composites and
%        left this untouched, deliberately and in writing; this is the follow-up.
%        THREE of the five now land (see the DEFECT C section below); the two
%        `control_individual_responses_*` do NOT, on evidence, and the tests say so.
%
%   ***** UNVERIFIED: THESE TESTS HAVE NEVER BEEN EXECUTED. *****
%   Written 2026-08-12 in a container with NO MATLAB (`command -v matlab octave`
%   exits 1). test-migrators-quick.yml is the first thing with an opinion. This
%   project's own record says a test written from the same premise as the code
%   cannot catch the code, so treat the first CI run as the first real evidence.
%
%   EACH TEST BELOW STATES WHETHER IT FAILS AGAINST THE PRE-REPAIR CODE, and how
%   that was established is stated here rather than implied: the old and new helper
%   bodies were transcribed and run over these exact fixture shapes OUTSIDE MATLAB.
%   That is a SIMULATION of two ~8-line functions, not an execution of the migrator,
%   and it is quoted as such -- it is reproducible evidence for the direction of the
%   change, not proof the MATLAB runs. It did earn its keep: it caught this file
%   asserting a control-field total of 16 where the table sums to 15.
%   Result of that simulation, per family (expected / found by OLD / found by NEW):
%       contrast_tuning               2  0  2      FAILS against old
%       orientation_direction_tuning  1  1  1      passes against old (the control case)
%       spatial_frequency_tuning      5  0  5      FAILS against old
%       speed_tuning                  2  0  2      FAILS against old
%       temporal_frequency_tuning     5  0  5      FAILS against old
%   -> 14 of 15 asserted control fields are absent under the old code; response_units
%      is the numeric [] under the old code in all five, where 'Hz' and '' are asserted.
%
%   DEFECT C was established the same way, and the same caveat applies: the pre- and
%   post-repair `controlBlock` bodies were transcribed and run over the exact fixtures
%   below, OUTSIDE MATLAB. Its result, quoting the run:
%       DENOMINATOR: 5 fixture shape(s) driven through BOTH helper bodies;
%                    2 helper function(s) transcribed (getf, controlBlock);
%                    0 MATLAB processes run
%       fixture                            OLD keys                      NEW keys
%       flat raw, control data present     (none)   control_mean,control_stddev,control_stderr
%       flat raw, control data absent      (none)                        (none)
%       composite spatial_frequency        (5 names)                     the same 5
%       composite contrast                 (2 names)                     the same 2
%       composite orientation_direction    control_individual            control_individual
%       composite fixtures whose OLD and NEW output DIFFER: 0
%   -> the two DEFECT C presence tests FAIL against the pre-repair code (it emits an
%      empty struct for this shape). Of the three guard tests, two PASS against it and
%      must keep passing; the third
%      (testFlatRawCurveKeepsItsUnmappedControlNamesOutOfTheBlockEntirely) FAILS on its
%      DENOMINATOR line only -- see its own header for why that line had to be added.
%      No composite output moves.
%
%   ---------------------------------------------------------------------
%   EVERY FIXTURE IS BUILT FROM THE WRITER, AND THE WRITER IS NOT NDI-matlab
%   ---------------------------------------------------------------------
%   CORRECTED 2026-08-12: THIS SAID "None of the five result classes ships an
%   NDI-matlab template writer" AND "EXACTLY ONE construction site". BOTH ARE FALSE
%   FOR orientation_direction_tuning, and the positive evidence is on NDI origin/main
%   (42c94e5) -- it ships BOTH a template and a first-party writer:
%
%       $ git ls-files | grep -i orientation_direction_tuning
%         src/ndi/ndi_common/database_documents/stimulus/vision/oridir/
%             orientation_direction_tuning.json
%         src/ndi/ndi_common/schema_documents/stimulus/vision/oridir/
%             orientation_direction_tuning_schema.json          (+ a _schema.json_old)
%       $ git show origin/main:src/ndi/+ndi/+app/oridirtuning.m | grep -n ...
%         182:   'control_individual', vlt.data.cellarray2mat(control_ind_real));
%         205:   oriprops = ndi.document('orientation_direction_tuning', ...
%
%   THE FIXTURES SURVIVE THIS INTACT, which is why the file is corrected rather than
%   rebuilt: oridirtuning.m:176-182 emits `tuning_curve` with exactly
%   direction / mean / stddev / stderr / individual / raw_individual /
%   control_individual -- 7 for 7 against oridirCurve() below, a writer nobody had
%   consulted agreeing field-for-field with the mock-corpus reading. It matters anyway,
%   because the ground-truth rule is that where template and WRITER disagree the WRITER
%   wins, and an unconsulted first-party writer is exactly the thing that rule is about.
%
%   For the other FOUR the original statement stands: no NDI-matlab template, and the
%   producing repo is VH-Lab/NDIcalc-vis-matlab at 65718ed (HEAD == origin/HEAD,
%   153 tracked .m files). Construction sites, one per class:
%
%       contrast_tuning               +ndi/+calc/+vis/contrast_tuning.m:274
%       orientation_direction_tuning  +ndi/+calc/+vis/oridir_tuning.m:257
%       spatial_frequency_tuning      +ndi/+calc/+vis/spatial_frequency_tuning.m:292
%       speed_tuning                  +ndi/+calc/+vis/speed_tuning.m:351
%       temporal_frequency_tuning     +ndi/+calc/+vis/temporal_frequency_tuning.m:295
%
%   THE FIVE ARE NOT UNIFORM, and the fixtures below differ exactly as the writers
%   differ -- a uniform fixture would be a guess wearing five hats. Measured over
%   the writer's own mock corpus (+ndi/+calc/+vis/mock/, mock.N.json, compare files
%   excluded), which is the same source the sibling fixture in testMigratorsJ.m was
%   read off:
%
%       DENOMINATOR: 64 mock document(s) carrying the class block, 5 families.
%                    control_* at BLOCK level: 0 of 64.
%       contrast_tuning        9/9   control_stddev, control_stderr
%       orientation_direction  7/7   control_individual
%       spatial_frequency     22/22  control_mean, control_stddev, control_stderr,
%                                    control_mean_stddev, control_mean_stderr
%       speed_tuning          18/18  control_stddev, control_stderr
%       temporal_frequency     8/8   the same five as spatial_frequency
%
%   Writer lines: contrast_tuning.m:237-238, oridir_tuning.m:232,
%   spatial_frequency_tuning.m:258-262, speed_tuning.m:276-277,
%   temporal_frequency_tuning.m:261-265 -- each inside its `tuning_curve = struct(...)`.
%
%   ORIENTATION/DIRECTION IS THE ONE FAMILY DEFECT A DOES NOT REACH, and this file
%   says so rather than quietly asserting five identical things. Its only control
%   field is `control_individual`, which the old read already took from the
%   `tuning_curve` level. It is exercised here as the control case: it must keep
%   working, and it is the reason the honest denominator for A is 4 of 5, not 5.
%
%   response_units, all five, identically -- contrast_tuning.m:213,
%   oridir_tuning.m:207, spatial_frequency_tuning.m:234, speed_tuning.m:245,
%   temporal_frequency_tuning.m:237:
%       properties.response_units = tuning_doc.document_properties. ...
%                                       stimulus_tuningcurve.response_units;
%   and 64/64 mock documents carry `properties.response_units = []`, because the
%   upstream field is declared in NDI-matlab +ndi/+app/+stimulus/tuning_response.m's
%   emptystruct at :405 and NEVER ASSIGNED in that file. So the honest fixture value
%   is the EMPTY MATRIX, not a plausible-looking 'spikes/s'.
%
%   ---------------------------------------------------------------------
%   PORTED TO did-schema #88 (2026-10-21)
%   ---------------------------------------------------------------------
%   These tests were filtered with "V_eta rework in progress (DID-schema PR #68)"
%   since the restructure. #88's tuning shape is the SIGNED one
%   (V_eta_tuning_model_plan.md: the 2026-09-21 restructure, the #73 amendment of
%   2026-09-23 and the audit-2 amendment of 2026-09-29), and the migrators now
%   build it through +migrators_j/private/jTuningCurve.m (jTuningCurveValue.m is
%   no longer called). The DEFECTS these tests pin are unchanged -- which LEVEL a
%   field is read from, and which names are never invented -- so the tests are
%   kept and only the destination spellings move:
%       control_response.control_mean/_stddev/_stderr/_individual
%                                 -> value.control.mean/stddev/stderr/individual
%       response_units (char, blank '')
%                                 -> value.response_unit, a TERM, ABSENT when the
%                                    source gives none (did2.build never writes a
%                                    blank for an optional field)
%       independent_values        -> the leaf's data.covariates(1).quantity.value
%                                    (along data.dimensions(1); data.keys(1) before
%                                    data_body AMENDMENT 6)
%       control_mean_stddev / control_mean_stderr
%                                 -> NO #88 slot (value.control declares only
%                                    mean/stddev/stderr/individual): see
%                                    testTheTwoPreviouslyUnnamedControlFieldsSurvive
%   Per-trial matrices take the stimulus dimension FIRST on #88 (audit 2, D3), so
%   a v1 trials x stimuli `control_individual` arrives transposed.
%   FIXTURES: +migrators_j/private/jCalculation.m passes a source with no
%   operating system (no `app.os`) through untouched, so a fixture with no `app`
%   block would make every assertion here vacuous. Each fixture therefore carries
%   the `app` block ndi.app.newdocument stamps -- the same update testMigratorsJ
%   made for #88 (calcAppJ). How a source with NO app block folds (Jess Haley,
%   2026-10-21, [calculation-os-optional]) is not what this file tests.
%
%   Run with:  results = runtests('did2.unittest.testTuningCurveLevels');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== fixtures (from the WRITER) ==========================

function body = tuningBody(className, tc, props)
%TUNINGBODY A did_v1 fitted-tuning result document, post-universalRenames.
%   `base` is the only superclass: the writers' templates declare no `app` on a bare
%   result document (the calculator's app block rides on the `*_calc` document), so
%   jSoftwareFromApp mints nothing and the fold is 1 -> 2.
body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id',              'value', 'elem_lvl_1'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'rawcurve_lvl_1')];
body.base = struct('id', 'lvl_doc_1', 'session_id', 'sess_lvl', 'name', 'lvl', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcApp('ndi.calc.vis.tuning');   % jCalculation needs app.os to fold
blk = struct();
blk.properties   = props;
blk.tuning_curve = tc;
blk.significance = struct('visual_response_anova_p', 0.002, ...
                          'across_stimuli_anova_p', 0.031);
body.(className) = blk;
end

function props = emptyUnitsProperties()
% The writers' real value: EMPTY, in 64/64 mock documents. Built by assignment
% rather than through struct(), which would silently drop the field.
props = struct('response_type', 'mean');
props.response_units = [];
end

function tc = contrastCurve()
% contrast_tuning.m:230-238. Two control fields, both inside `tuning_curve`.
tc = struct('contrast', [0.1; 0.2; 0.4; 0.8], ...
    'mean',   [1; 5; 9; 12], 'stddev', [0.1; 0.2; 0.3; 0.4], ...
    'stderr', [0.05; 0.1; 0.15; 0.2], ...
    'control_stddev', 0.02, 'control_stderr', 0.01);
tc.individual = [1.0 5.1 8.8 12.2; 1.1 4.9 9.2 11.8];
end

function tc = oridirCurve()
% oridir_tuning.m:225-232. The ONE family whose only control field is
% control_individual -- already read at the right level before this change.
tc = struct('direction', [0; 90; 180; 270], ...
    'mean',   [1; 5; 9; 3], 'stddev', [0.1; 0.2; 0.3; 0.4], ...
    'stderr', [0.05; 0.1; 0.15; 0.2]);
tc.individual        = [1.0 5.1 8.8 3.2; 1.1 4.9 9.2 2.8];
tc.raw_individual    = [1.0 5.1 8.8 3.2; 1.1 4.9 9.2 2.8];
tc.control_individual = [0.5 0.5 0.5 0.5; 0.4 0.4 0.4 0.4];
end

function tc = spatialCurve()
% spatial_frequency_tuning.m:251-262. All FIVE control fields.
tc = struct('spatial_frequency', [0.05; 0.1; 0.2; 0.4], ...
    'mean',   [1; 5; 9; 3], 'stddev', [0.1; 0.2; 0.3; 0.4], ...
    'stderr', [0.05; 0.1; 0.15; 0.2], ...
    'control_mean',        [0.5; 0.5; 0.5; 0.5], ...
    'control_stddev',      [0.02; 0.02; 0.02; 0.02], ...
    'control_stderr',      [0.01; 0.01; 0.01; 0.01], ...
    'control_mean_stddev', 0.022, ...
    'control_mean_stderr', 0.011);
tc.individual = [1.0 5.1 8.8 3.2; 1.1 4.9 9.2 2.8];
end

function tc = speedCurve()
% speed_tuning.m:269-277. Two control fields; the curve carries BOTH frequency axes.
tc = struct('spatial_frequency', [0.05; 0.1; 0.2; 0.4], ...
    'temporal_frequency', [1; 2; 4; 8], ...
    'mean',   [1; 5; 9; 3], 'stddev', [0.1; 0.2; 0.3; 0.4], ...
    'stderr', [0.05; 0.1; 0.15; 0.2], ...
    'control_stddev', 0.02, 'control_stderr', 0.01);
tc.individual = [1.0 5.1 8.8 3.2; 1.1 4.9 9.2 2.8];
end

function tc = temporalCurve()
% temporal_frequency_tuning.m:254-265. All FIVE control fields.
tc = struct('temporal_frequency', [1; 2; 4; 8], ...
    'mean',   [1; 5; 9; 3], 'stddev', [0.1; 0.2; 0.3; 0.4], ...
    'stderr', [0.05; 0.1; 0.15; 0.2], ...
    'control_mean',        [0.5; 0.5; 0.5; 0.5], ...
    'control_stddev',      [0.02; 0.02; 0.02; 0.02], ...
    'control_stderr',      [0.01; 0.01; 0.01; 0.01], ...
    'control_mean_stddev', 0.022, ...
    'control_mean_stderr', 0.011);
tc.individual = [1.0 5.1 8.8 3.2; 1.1 4.9 9.2 2.8];
end

function tc = flatRawCurve()
%FLATRAWCURVE The FLAT raw `stimulus_tuningcurve` result block, field for field from
%   its ONLY writer, NDI-matlab +ndi/+app/+stimulus/tuning_response.m. This is not the
%   composites' shape: there is no `tuning_curve` sub-struct and no `properties`.
%
%   Names from the emptystruct at :400-405; VALUES and SHAPES from the assignments,
%   because the two disagree for two of the fields and the declaration is the half that
%   lies:
%       :445-446   control_individual_responses_real/_imaginary = cell(1,num_points)
%       :464-467   filled per point from the stimulus_response_scalar responses
%       :478-483   control_response_mean/_stddev/_stderr assigned by (I) -> 1xN rows;
%                  :479-481 abs() them if complex, so the stored values are real
%       :493-494   the two cell arrays flattened to matrices (rows index sampled
%                  points, columns index trials)
%       :403,:405  control_stimid and response_units are DECLARED AND NEVER ASSIGNED
%                  anywhere in that file, so a real document carries [] for both.
%                  They are fixtured as [] for that reason, not as a convenience.
tc = struct();
tc.independent_variable_label = {'Contrast'};
tc.independent_variable_value = [0.1; 0.2; 0.4; 0.8];
tc.stimid                     = [1 2 3 4];
tc.response_mean              = [1 5 9 12];
tc.response_stddev            = [0.1 0.2 0.3 0.4];
tc.response_stderr            = [0.05 0.1 0.15 0.2];
% trials x points, as the writer stores them: vlt.data.cellarray2mat puts each
% point's trial vector in a COLUMN (CORRECTED 2026-10-21; this fixture was
% points x trials, which the comment above also said, and the writer does not do)
tc.individual_responses_real      = [1.0 1.1 0.9; 5.1 4.9 5.0; 8.8 9.2 9.0; 12.2 11.8 12.0].';
tc.individual_responses_imaginary = [0.1 0 0; 0 0.2 0; 0 0 0; 0 0 -0.1].';
tc.stimulus_presentation_number   = [1 2 3; 4 5 6; 7 8 9; 10 11 12];
tc.control_stimid  = [];
tc.response_units  = [];
tc.control_response_mean   = [0.50 0.52 0.48 0.51];
tc.control_response_stddev = [0.02 0.03 0.02 0.04];
tc.control_response_stderr = [0.01 0.015 0.01 0.02];
tc.control_individual_responses_real = ...
    [0.5 0.6 0.4; 0.5 0.6 0.5; 0.4 0.5 0.5; 0.5 0.5 0.6].';
tc.control_individual_responses_imaginary = ...
    [0.1 0.0 -0.1; 0 0 0; 0 0 0; 0 0 0].';
end

function tc = flatRawCurveWithNoControlData()
%FLATRAWCURVEWITHNOCONTROLDATA The same document with no control data recorded.
%   Every control name is still PRESENT and EMPTY, which is not a contrivance: all five
%   are declared by vlt.data.emptystruct at tuning_response.m:400-405 and the struct is
%   grown to 1x1 at :407, so any name the loop never assigns reaches the document as [].
%   This is the shape that makes the empty-guard load-bearing.
tc = flatRawCurve();
tc.control_response_mean   = [];
tc.control_response_stddev = [];
tc.control_response_stderr = [];
tc.control_individual_responses_real      = [];
tc.control_individual_responses_imaginary = [];
end

function body = flatRawBody(tc)
%FLATRAWBODY A did_v1 raw `stimulus_tuningcurve` document, post-universalRenames.
%   The writer mints the document at tuning_response.m:497 and sets a populated
%   element_id from the consumed stimulus_response_scalar at :499, which is why the fold
%   needs no NDI second pass.
body = struct();
body.document_class = struct('class_name', 'stimulus_tuningcurve', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', 'element_id', 'value', 'elem_flat_1');
body.base = struct('id', 'flat_doc_1', 'session_id', 'sess_flat', 'name', 'raw', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcApp('ndi.app.stimulus.tuning_response');   % jCalculation needs app.os to fold
% `stimid` and `stimulus_presentation_number` have no home on the calculation,
% so since [generic stage is lossless] / [partly placed is carried as v1] (Jess
% Haley, 2026-10-25) a curve stating them is carried whole as v1
% (testAWriterRawCurveIsCarriedWholeAsV1). These tests are of the fold, so the
% body they fold leaves the two out.
for f = {'stimid', 'stimulus_presentation_number'}
    if isfield(tc, f{1}); tc = rmfield(tc, f{1}); end
end
body.stimulus_tuningcurve = tc;
end

function body = writerRawBody(tc)
%WRITERRAWBODY flatRawBody with the block exactly as the writer wrote it.
body = flatRawBody(tc);
body.stimulus_tuningcurve = tc;
end

function testAWriterRawCurveIsCarriedWholeAsV1(testCase)
% [generic stage is lossless] / [partly placed is carried as v1] (Jess Haley,
% 2026-10-25): the writer's raw curve states `stimid` and
% `stimulus_presentation_number`, which the calculation does not write (they
% were reported `field_dropped`); it is carried whole as v1, one
% `carried_as_v1` note naming both. Empty fields (control_stimid,
% response_units: []) are not unplaced -- they state nothing.
body = writerRawBody(flatRawCurve());
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.stimulus_tuningcurve(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyEqual(testCase, numel(out), 1);
verifyTrue(testCase, isequaln(out{1}, body), 'returned unchanged');
d = notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, contains(d, 'stimulus_tuningcurve.stimid'), d);
verifyTrue(testCase, contains(d, 'stimulus_tuningcurve.stimulus_presentation_number'), d);
verifyFalse(testCase, contains(d, 'control_stimid'), d);
end

% ===================== the family table ====================================

function fam = familyTable()
%FAMILYTABLE The five v1 tuning result classes, the control fields their writers
%   emit, and where each lands on did-schema #88. This IS the denominator the tests
%   below report: it is enumerated once, and every test walks all of it rather than
%   sampling.
%
%   `controls` is {v1 name, #88 value.control field}. The two scalars
%   control_mean_stddev / control_mean_stderr (spatial and temporal frequency) are
%   NOT in this table: #88 declares no slot for them (see
%   testTheTwoPreviouslyUnnamedControlFieldsSurvive).
fam = struct( ...
  'className', {'contrast_tuning', 'orientation_direction_tuning', ...
                'spatial_frequency_tuning', 'speed_tuning', 'temporal_frequency_tuning'}, ...
  'curve',     {@contrastCurve, @oridirCurve, @spatialCurve, @speedCurve, @temporalCurve}, ...
  'controls',  {{'control_stddev', 'stddev'; 'control_stderr', 'stderr'}, ...
                {'control_individual', 'individual'}, ...
                {'control_mean', 'mean'; 'control_stddev', 'stddev'; ...
                 'control_stderr', 'stderr'}, ...
                {'control_stddev', 'stddev'; 'control_stderr', 'stderr'}, ...
                {'control_mean', 'mean'; 'control_stddev', 'stddev'; ...
                 'control_stderr', 'stderr'}});
end

% ===================== DEFECT A ============================================

function testControlFieldsAreReadFromTheTuningCurveLevel(testCase)
% DEFECT A, all five families in one sweep. Every control field the writer emits
% that #88 has a slot for must arrive in `tuning_curve.value.control` WITH ITS VALUE
% -- the fixtures put them ONLY inside `tuning_curve`, exactly as all five writers
% do, so a read at BLOCK level finds nothing.
%
% A per-trial matrix (control_individual) takes the stimulus dimension first on #88
% (audit 2, D3), so v1's trials x stimuli arrives TRANSPOSED; a vector or scalar is
% carried as written.
fam = familyTable();
inspected = 0; fieldsChecked = 0;
for k = 1:numel(fam)
    % the handle is taken out of the struct BEFORE it is called: `fam(k).curve()`
    % parses as indexing, not invocation.
    mk = fam(k).curve;
    expectCurve = mk();
    v = foldedValue(fam(k).className, mk(), emptyUnitsProperties());
    inspected = inspected + 1;
    assertTrue(testCase, isfield(v, 'control') && isstruct(v.control), ...
        sprintf('%s: value.control is missing or not a struct', fam(k).className));
    cr = v.control;
    for c = 1:size(fam(k).controls, 1)
        src = fam(k).controls{c, 1};
        dst = fam(k).controls{c, 2};
        fieldsChecked = fieldsChecked + 1;
        assertTrue(testCase, isfield(cr, dst), sprintf( ...
            ['%s: value.control is missing "%s" (v1 %s). The writer puts it INSIDE ' ...
             'tuning_curve; a read at block level finds nothing there.'], ...
            fam(k).className, dst, src));
        expected = expectCurve.(src);
        if ismatrix(expected) && ~isvector(expected)
            expected = expected.';
        end
        verifyEqual(testCase, cr.(dst), expected, sprintf( ...
            '%s: value.control.%s carries the wrong value', fam(k).className, dst), ...
            'AbsTol', 1e-12);
    end
end
% DENOMINATOR, asserted rather than printed, so a fixture silently dropping out of
% the sweep fails instead of shrinking the evidence.
verifyEqual(testCase, inspected, 5, 'the sweep must cover all five families');
verifyEqual(testCase, fieldsChecked, 11, ...
    ['11 = 2 (contrast) + 1 (oridir) + 3 (spatial) + 2 (speed) + 3 (temporal); ' ...
     'the 4 control_mean_stddev/_stderr fields have no #88 slot. A different ' ...
     'total means the family table was edited without its evidence']);
end

function testTheTwoPreviouslyUnnamedControlFieldsSurvive(testCase)
% RE-ARMED 2026-10-21. It was filtered because #88 had no slot for these two;
% Jess Haley decided ("b"): control_mean_stddev -> control.pooled.stddev and
% control_mean_stderr -> control.pooled.stderr. DEFECT A, the half that is not a
% level bug: the two names appear in no list the old read searched, at any level,
% so they were dropped for the two families that emit them (spatial_frequency
% 22/22 and temporal_frequency 8/8 of the writer's mocks).
pairs = {'spatial_frequency_tuning', @spatialCurve; ...
         'temporal_frequency_tuning', @temporalCurve};
verifyEqual(testCase, size(pairs, 1), 2, ...
    'exactly two of the five families emit the mean_* control scalars');
for k = 1:size(pairs, 1)
    mk = pairs{k, 2};
    v = foldedValue(pairs{k, 1}, mk(), emptyUnitsProperties());
    assertTrue(testCase, isfield(v, 'control') && isfield(v.control, 'pooled'), ...
        sprintf('%s: value.control.pooled is missing', pairs{k, 1}));
    p = v.control.pooled;
    verifyEqual(testCase, p.stddev, 0.022, 'AbsTol', 1e-12, ...
        sprintf('%s: control_mean_stddev -> control.pooled.stddev', pairs{k, 1}));
    verifyEqual(testCase, p.stderr, 0.011, 'AbsTol', 1e-12, ...
        sprintf('%s: control_mean_stderr -> control.pooled.stderr', pairs{k, 1}));
end
end

function testControlBlockInventsNothing(testCase)
% The guard half of DEFECT A. A family whose writer emits two control fields must
% yield EXACTLY those two -- a name list applied blindly would mint empty mean /
% individual slots on contrast and speed documents, which is the
% invented-empty-field pattern this repo already has a census for.
v = foldedValue('contrast_tuning', contrastCurve(), emptyUnitsProperties());
assertTrue(testCase, isfield(v, 'control'), 'contrast_tuning: value.control is missing');
got = sort(fieldnames(v.control));
verifyEqual(testCase, got, sort({'stddev'; 'stderr'}), ...
    'contrast_tuning emits two control fields; anything else was invented');
v = foldedValue('orientation_direction_tuning', oridirCurve(), emptyUnitsProperties());
assertTrue(testCase, isfield(v, 'control'), 'orientation_direction_tuning: value.control is missing');
verifyEqual(testCase, fieldnames(v.control), {'individual'}, ...
    'orientation_direction_tuning emits exactly one control field');
end

function testNestedControlFieldsAcceptTheCamelCaseSpelling(testCase)
% The repo's standing rule for a NESTED read (CLAUDE.md; universalRenames.m
% snake_cases only the IMMEDIATE field names of a property block and leaves nested
% struct values alone, so a camelCase nested key reaches the migrator unrenamed).
% controlMeanStddev lands in control.pooled.stddev (Jess Haley, 2026-10-21, "b").
tc = struct('temporal_frequency', [1; 2; 4; 8], 'mean', [1; 5; 9; 3]);
tc.controlMean       = [0.5; 0.5; 0.5; 0.5];
tc.controlMeanStddev = 0.022;
v = foldedValue('temporal_frequency_tuning', tc, emptyUnitsProperties());
assertTrue(testCase, isfield(v, 'control') && isfield(v.control, 'mean'), ...
    'the camelCase nested spelling controlMean was not recognised');
verifyEqual(testCase, v.control.mean, [0.5; 0.5; 0.5; 0.5], 'AbsTol', 1e-12);
verifyEqual(testCase, v.control.pooled.stddev, 0.022, 'AbsTol', 1e-12, ...
    'the camelCase nested spelling controlMeanStddev was not recognised');
end

function testCamelCaseNestedControlFieldIsNotAlsoReportedDropped(testCase)
% The camelCase read must also count as a READ: controlMean reaches value.control
% and is NOT listed among the dropped fields, while controlMeanStddev (no #88
% slot) is reported dropped under its own spelling.
tc = struct('temporal_frequency', [1; 2; 4; 8], 'mean', [1; 5; 9; 3]);
tc.controlMean       = [0.5; 0.5; 0.5; 0.5];
tc.controlMeanStddev = 0.022;
did2.convert.reportNote('reset');
foldedValue('temporal_frequency_tuning', tc, emptyUnitsProperties());
details = droppedDetails();
did2.convert.reportNote('reset');
verifyFalse(testCase, any(strcmp(details, ...
    'temporal_frequency_tuning.tuning_curve.controlMean')), ...
    'controlMean was read into value.control and must not also be reported dropped');
verifyFalse(testCase, any(strcmp(details, ...
    'temporal_frequency_tuning.tuning_curve.controlMeanStddev')), ...
    'controlMeanStddev is read into control.pooled.stddev, not dropped');
end

function testAnUnplacedFieldCarriesTheDocumentAsV1(testCase)
% INVERTS testDroppedFieldsReachTheMigrationReport, which asserted a FOLDED
% document with one `field_dropped` note per field #88 has no home for (SF/TF's
% v1 `abs` block). [generic stage is lossless] / [partly placed is carried as
% v1] (Jess Haley, 2026-10-25): such a document is not folded; it is carried
% whole as v1 with ONE `carried_as_v1` note naming the fields. A field the fold
% maps (control_mean -> value.control, control_mean_stddev -> control.pooled)
% is not named.
did2.convert.reportNote('reset');
body = tuningBody('spatial_frequency_tuning', spatialCurve(), emptyUnitsProperties());
body.spatial_frequency_tuning.abs = struct('preferred', 0.2);
out = did2.convert.migrators_j.spatial_frequency_tuning(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, body), 'carried whole, unchanged');
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
verifyFalse(testCase, isfield(notes, 'field_dropped'), 'nothing is dropped');
n = notes.carried_as_v1;
verifyEqual(testCase, n.count, 1);
verifyEqual(testCase, n.ids, {'lvl_doc_1'});
verifyTrue(testCase, isfield(n.by_class, 'spatial_frequency_tuning'));
d = n.distinct_details{1};
verifyTrue(testCase, contains(d, 'spatial_frequency_tuning.abs'), d);
for f = {'control_mean_stddev', 'control_mean_stderr', 'control_mean,'}
    verifyFalse(testCase, contains([d ','], ['tuning_curve.' f{1}]), ...
        sprintf('tuning_curve.%s is mapped, not unplaced', f{1}));
end
end

function d = droppedDetails()
% EXACT: every distinct unplaced field. Since [generic stage is lossless] (Jess
% Haley, 2026-10-25) an unplaced field carries the document as v1 with one
% `carried_as_v1` note listing the fields ('unplaced: a, b'); a `field_dropped`
% note is no longer written. Both are read, so a field named in either counts.
notes = did2.convert.reportNote('collect');
d = {};
if isfield(notes, 'field_dropped')
    d = notes.field_dropped.distinct_details;
end
if isfield(notes, 'carried_as_v1')
    for k = 1:numel(notes.carried_as_v1.distinct_details)
        t = regexprep(notes.carried_as_v1.distinct_details{k}, '^unplaced: ', '');
        d = [d, strsplit(t, ', ')]; %#ok<AGROW>
    end
end
end
end

% ===================== DEFECT B ============================================

function testResponseUnitsAreReadFromProperties(testCase)
% DEFECT B, all five families. The units live under `properties`, never on the block.
% A real unit is used here so the test distinguishes "found the right level" from
% "guarded a bad type" -- the empty case is a separate test below.
% UPDATED 2026-10-25: driven by a spelling the decisions do not name ('mV'),
% which is placed as the unit's own label. A RECOGNISED spelling ('Hz') is
% replaced by om:hertz and kept nowhere, so since [generic stage is lossless]
% (Jess Haley) that document is carried whole as v1 -- which also proves the
% read reached `properties`: the carry names properties.response_units.
fam = familyTable();
props = struct('response_type', 'mean', 'response_units', 'mV');
hz = struct('response_type', 'mean', 'response_units', 'Hz');
inspected = 0;
for k = 1:numel(fam)
    mk = fam(k).curve;
    v = foldedValue(fam(k).className, mk(), props);
    inspected = inspected + 1;
    assertTrue(testCase, isfield(v, 'response_unit'), sprintf( ...
        ['%s: value.response_unit is missing. It must come from ' ...
         'properties.response_units (the writer sets it there and nowhere else)'], ...
        fam(k).className));
    verifyTrue(testCase, isUnitNamed(v.response_unit, 'mV'), sprintf( ...
        '%s: value.response_unit is not the source label "mV"', fam(k).className));
    fn = str2func(['did2.convert.migrators_j.' fam(k).className]);
    did2.convert.reportNote('reset');
    body = tuningBody(fam(k).className, mk(), hz);
    out = fn(body);
    notes = did2.convert.reportNote('collect');
    did2.convert.reportNote('reset');
    verifyTrue(testCase, isscalar(out) && isequaln(out{1}, body), sprintf( ...
        '%s: a recognised spelling must carry the document whole as v1', fam(k).className));
    verifyTrue(testCase, contains(notes.carried_as_v1.distinct_details{1}, ...
        'properties.response_units'), fam(k).className);
end
verifyEqual(testCase, inspected, 5, 'the sweep must cover all five families');
end
verifyEqual(testCase, inspected, 5, 'the sweep must cover all five families');
end

function testEmptyUnitsBecomeTheSchemaBlankAndNotAnEmptyMatrix(testCase)
% DEFECT B's type hazard. The writer's REAL value is the empty matrix in 64/64 mock
% documents (response_units is declared in NDI-matlab tuning_response.m's emptystruct
% and never assigned). Passing that [] through into a typed slot is a typeMismatch.
% #88: `response_unit` is an optional TERM, and did2.build leaves an optional field
% OUT rather than writing a blank -- so the honest result is the field ABSENT, never
% a numeric [] and never an invented unit.
fam = familyTable();
for k = 1:numel(fam)
    mk = fam(k).curve;
    v = foldedValue(fam(k).className, mk(), emptyUnitsProperties());
    verifyFalse(testCase, isfield(v, 'response_unit'), sprintf( ...
        ['%s: value.response_unit is present although the source gives no unit. ' ...
         'An empty source value must leave the optional term out.'], fam(k).className));
    verifyFalse(testCase, isfield(v, 'response_units'), sprintf( ...
        '%s: the pre-#88 `response_units` spelling was emitted', fam(k).className));
end
end

function testFlatRawCurveStillReadsUnitsAtBlockLevel(testCase)
% THE REGRESSION GUARD, and the reason DEFECT B is a level FALLBACK and not a level
% MOVE. The flat raw stimulus_tuningcurve genuinely carries response_units at BLOCK
% level -- NDI-matlab +ndi/+app/+stimulus/tuning_response.m:405 declares it there and
% NDIcalc-vis +ndi/+calc/+vis/contrast_sensitivity.m:146 sets it to 'Hz' -- and that
% block has no `properties` sub-struct at all. Moving the read would have broken the
% one shape it was right for.
body = struct();
body.document_class = struct('class_name', 'stimulus_tuningcurve', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', 'element_id', 'value', 'elem_lvl_2');
body.base = struct('id', 'lvl_doc_2', 'session_id', 'sess_lvl', 'name', 'raw', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcApp('ndi.app.stimulus.tuning_response');   % jCalculation needs app.os to fold
% the flat block, tuning_response.m:400-405 -- no `properties`, no `tuning_curve`
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', {{'Contrast'}}, ...
    'independent_variable_value', [0.1; 0.2; 0.4; 0.8], ...
    'response_mean',   [1; 5; 9; 12], ...
    'response_stddev', [0.1; 0.2; 0.3; 0.4], ...
    'response_stderr', [0.05; 0.1; 0.15; 0.2], ...
    'response_units',  'mV');

% UPDATED 2026-10-25: a spelling the decisions do not name ('mV'), placed as the
% unit's label. A recognised one ('Spikes/s') is replaced by om:hertz and kept
% nowhere, so that document is carried whole as v1 ([generic stage is lossless],
% Jess Haley) -- testSpikeRateSpellingsCarryTheDocumentAsV1.
leaf = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve(body));
v = leaf.tuning_curve.value;
assertTrue(testCase, isfield(v, 'response_unit'), ...
    'the flat raw curve carries its units at BLOCK level and must keep resolving');
verifyTrue(testCase, isUnitNamed(v.response_unit, 'mV'), ...
    'value.response_unit is not the source label "mV"');
verifyTrue(testCase, isTerm(leaf.statement.variable, 'EMPTY:0000398', 'neural response'), ...
    'statement.variable is not EMPTY:0000398 "neural response"');
verifyEqual(testCase, keyValues(leaf), [0.1 0.2 0.4 0.8], 'AbsTol', 1e-12);
end

% ===================== DEFECT C ============================================

function testFlatRawCurveControlStatisticsReachTheControlBlock(testCase)
% DEFECT C, the half that has a destination. The flat raw curve's control statistics
% are spelled control_response_mean / _stddev / _stderr; #88's control block names
% them mean / stddev / stderr. Same statistic, same population, same per-point shape.
v = flatFoldedValue(flatRawCurve());
assertTrue(testCase, isfield(v, 'control') && isstruct(v.control), ...
    'value.control is missing or not a struct');
cr = v.control;
expected = {'mean',   [0.50 0.52 0.48 0.51]; ...
            'stddev', [0.02 0.03 0.02 0.04]; ...
            'stderr', [0.01 0.015 0.01 0.02]};
checked = 0;
for k = 1:size(expected, 1)
    nm = expected{k, 1};
    assertTrue(testCase, isfield(cr, nm), sprintf( ...
        ['the flat raw curve carries this as control_response_%s ' ...
         '(tuning_response.m:478-483); it must arrive as value.control.%s'], nm, nm));
    verifyEqual(testCase, cr.(nm), expected{k, 2}, ...
        sprintf('value.control.%s carries the wrong value', nm), 'AbsTol', 1e-12);
    checked = checked + 1;
end
% DENOMINATOR: the three control STATISTICS. The two per-trial halves
% (control_individual_responses_real / _imaginary) land together in
% control.individual (Jess Haley, 2026-10-21, "a1"), asserted in
% testFlatRawCurvePerTrialResponsesKeepBothHalves.
verifyEqual(testCase, checked, 3, ...
    'the three control statistics are checked');
end

function testFlatRawCurveControlBlockIsTheFourMappedNames(testCase)
% REWRITTEN 2026-10-21 (was ...IsExactlyTheThreeMappedNames). Jess Haley decided
% ("a1") that the per-trial response keeps BOTH halves NDI stores
% (tuning_response.m:465-472): control.individual is keys x trials x 2,
% [real, imaginary] last. So the control block is the three statistics PLUS
% individual -- and nothing else (control_stimid is never assigned).
v = flatFoldedValue(flatRawCurve());
assertTrue(testCase, isfield(v, 'control'), 'value.control is missing');
got = sort(fieldnames(v.control));
verifyEqual(testCase, got, sort({'individual'; 'mean'; 'stddev'; 'stderr'}), ...
    'the flat raw curve maps the three control statistics and control.individual');
end

function testFlatRawCurveWithNoControlDataInventsNothing(testCase)
% testControlBlockInventsNothing's idea, extended to the new aliases -- and it bites
% harder here than it ever did for the composites. vlt.data.emptystruct declares all
% five control names on EVERY raw curve (tuning_response.m:400-405), so a document that
% recorded no control data carries them PRESENT AND EMPTY. A name list applied without
% the empty-guard would mint blank slots on every one of those documents: the
% invented-empty-field pattern this repo keeps a corpus census for.
% #88: an empty control block is left OUT of the value entirely.
v = flatFoldedValue(flatRawCurveWithNoControlData());
if isfield(v, 'control')
    verifyTrue(testCase, isstruct(v.control), 'value.control must be a struct');
    verifyEmpty(testCase, fieldnames(v.control), ...
        ['a raw curve with no control data must yield NO control fields. ' ...
         'The five names are present-and-empty on every such document, and emitting ' ...
         'them would invent blank slots wholesale.']);
end
end

function testFlatRawCurvePerTrialResponsesKeepBothHalves(testCase)
% REWRITTEN 2026-10-21 (was ...KeepsItsUnmappedControlNamesOutOfTheBlockEntirely,
% which pinned the halves as UNMAPPED pending this decision). Jess Haley,
% 2026-10-21 ("a1"): `individual` and `control.individual` are keys x trials x 2,
% [real, imaginary] in the last dimension, whenever v1 carries the imaginary
% half. v1 stores trials x points (cellarray2mat), so each half is transposed.
tc = flatRawCurve();
v = flatFoldedValue(tc);
assertTrue(testCase, isfield(v, 'individual'), 'value.individual is missing');
verifyEqual(testCase, size(v.individual), [4 3 2], 'keys x trials x [real, imaginary]');
verifyEqual(testCase, v.individual(:, :, 1), tc.individual_responses_real.', 'AbsTol', 1e-12);
verifyEqual(testCase, v.individual(:, :, 2), tc.individual_responses_imaginary.', 'AbsTol', 1e-12);
assertTrue(testCase, isfield(v, 'control') && isfield(v.control, 'individual'), ...
    'value.control.individual is missing');
verifyEqual(testCase, size(v.control.individual), [4 3 2]);
verifyEqual(testCase, v.control.individual(:, :, 1), ...
    tc.control_individual_responses_real.', 'AbsTol', 1e-12);
verifyEqual(testCase, v.control.individual(:, :, 2), ...
    tc.control_individual_responses_imaginary.', 'AbsTol', 1e-12);
fns = fieldnames(v.control);
for k = 1:numel(fns)
    verifyEmpty(testCase, strfind(fns{k}, 'stimid'), sprintf( ...
        'value.control.%s: control_stimid is never assigned by the writer', fns{k}));
end
end

function testFlatRawCurveWithNoImaginaryHalfIsKeysByTrials(testCase)
% The other branch: no imaginary half carried -> keys x trials, unchanged.
tc = flatRawCurve();
tc = rmfield(tc, {'individual_responses_imaginary', 'control_individual_responses_imaginary'});
v = flatFoldedValue(tc);
verifyEqual(testCase, size(v.individual), [4 3]);
verifyEqual(testCase, v.individual, tc.individual_responses_real.', 'AbsTol', 1e-12);
verifyEqual(testCase, size(v.control.individual), [4 3]);
% mean / stddev / stderr unchanged by either branch
verifyEqual(testCase, v.mean, [1 5 9 12], 'AbsTol', 1e-12);
end

function testFlatRawCurveHalvesAcceptTheCamelCaseSpelling(testCase)
% The nested-read rule: camelCase spellings of both halves are read the same.
tc = flatRawCurve();
tc.individualResponsesReal = tc.individual_responses_real;
tc.individualResponsesImaginary = tc.individual_responses_imaginary;
tc.controlIndividualResponsesReal = tc.control_individual_responses_real;
tc.controlIndividualResponsesImaginary = tc.control_individual_responses_imaginary;
tc = rmfield(tc, {'individual_responses_real', 'individual_responses_imaginary', ...
    'control_individual_responses_real', 'control_individual_responses_imaginary'});
v = flatFoldedValue(tc);
verifyEqual(testCase, size(v.individual), [4 3 2]);
verifyEqual(testCase, size(v.control.individual), [4 3 2]);
end

function testFlatRawCurveControlRepairDoesNotDisturbTheEmpiricalCurve(testCase)
% The flat shape's other reads must be untouched by the alias list. Named separately
% from the control assertions because a regression here would otherwise be reported as
% a control-block failure and looked for in the wrong place.
leaf = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve(flatRawBody(flatRawCurve())));
v = leaf.tuning_curve.value;
verifyEqual(testCase, keyValues(leaf), [0.1 0.2 0.4 0.8], 'AbsTol', 1e-12);
verifyEqual(testCase, v.mean,   [1 5 9 12], 'AbsTol', 1e-12);
verifyEqual(testCase, v.stddev, [0.1 0.2 0.3 0.4], 'AbsTol', 1e-12);
verifyEqual(testCase, v.stderr, [0.05 0.1 0.15 0.2], 'AbsTol', 1e-12);
% response_units is declared and never assigned by this writer, so the honest value is
% NO unit -- the optional term left out, never a numeric [] (the DEFECT B type hazard,
% on the one shape whose LEVEL was always right).
verifyFalse(testCase, isfield(v, 'response_unit'), ...
    'response_unit must be absent when the writer leaves response_units []');
end

% ===================== [tuning grid] =======================================
% Jess Haley 2026-10-22 [tuning grid] (did-schema V_eta_data_body_model_plan.md,
% answer "4c"): a curve over several independent variables whose conditions
% form a FULL GRID has one dimension per variable, each with its covariate, and
% the response an array over them; otherwise ONE `stimulus condition` dimension
% with a covariate per variable (XCO:0000000 "experimental condition", [stimulus
% condition term]). No corpus holds such a curve (34,690 tuning
% curves, all over one variable), so these synthetic fixtures are the proof.

function tc = gridRawCurve(sf, tf)
%GRIDRAWCURVE A flat raw curve over spatial x temporal frequency, conditions in
%   the order given. Response k is 10*sf + tf (so a misplaced cell shows), the
%   trials are k + [0 0.1 0.2] (real) and k/100 (imaginary), and the control is
%   response/10.
sf = sf(:); tf = tf(:);
r = 10 * sf + tf;
tc = struct();
tc.independent_variable_label = {'spatial_frequency, temporal_frequency'};
tc.independent_variable_value = [sf tf];
tc.response_mean   = r.';
tc.response_stddev = (r / 2).';
tc.response_stderr = (r / 4).';
tc.individual_responses_real      = (r + [0 0.1 0.2]).';   % trials x points
tc.individual_responses_imaginary = repmat(r / 100, 1, 3).';
tc.control_response_mean   = (r / 10).';
tc.control_response_stddev = (r / 20).';
tc.control_response_stderr = (r / 40).';
tc.control_individual_responses_real = repmat(r / 10, 1, 3).';
% EMPTY: a recognised spelling ('spikes/s') is replaced and kept nowhere, so a
% curve stating one is carried as v1 since [generic stage is lossless]; these
% tests are about the grid
tc.response_units = [];
end

function testAFullGridCurveHasOneDimensionPerVariable(testCase)
% 2 spatial x 3 temporal frequencies, all 6 combinations once, in a shuffled
% order: two dimensions (n 2 and 3), each variable's levels a covariate along
% its own dimension, datum_order 'F', and every per-condition array reshaped
% so that cell (i, j) is the condition (sf_i, tf_j).
[S, T] = ndgrid([0.1 0.2], [1 2 4]);
order = [5 2 6 1 4 3];
sf = S(order); tf = T(order);
leaf = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve( ...
    flatRawBody(gridRawCurve(sf, tf))));
ax = did2.unittest.helpers.axesOf(leaf);
assertEqual(testCase, numel(ax), 2, 'one dimension per variable');
verifyEqual(testCase, {ax(1).term.name, ax(2).term.name}, ...
    {'spatial frequency', 'temporal frequency'}, 'each dimension''s term is its variable');
verifyEqual(testCase, [ax.n], [2 3]);
verifyEqual(testCase, ax(1).cov.variable.name, 'spatial frequency');
verifyEqual(testCase, reshape(ax(1).cov.quantity.value, 1, []), [0.1 0.2], 'AbsTol', 1e-12);
verifyEqual(testCase, ax(2).cov.variable.name, 'temporal frequency');
verifyEqual(testCase, reshape(ax(2).cov.quantity.value, 1, []), [1 2 4], 'AbsTol', 1e-12);
verifyEqual(testCase, [ax.nCov], [1 1], 'one covariate along each, nothing else');
verifyEqual(testCase, numel(leaf.data.covariates), 2);
verifyEqual(testCase, leaf.data.datum_order, 'F', 'the grid states its order');
v = leaf.tuning_curve.value;
expect = 10 * S + T;
verifyEqual(testCase, v.mean, expect, 'AbsTol', 1e-12, 'mean(i, j) is condition (sf_i, tf_j)');
verifyEqual(testCase, v.stddev, expect / 2, 'AbsTol', 1e-12);
verifyEqual(testCase, v.stderr, expect / 4, 'AbsTol', 1e-12);
verifyEqual(testCase, size(v.individual), [2 3 3 2], 'sf x tf x trials x [real, imaginary]');
verifyEqual(testCase, v.individual(:, :, 2, 1), expect + 0.1, 'AbsTol', 1e-12);
verifyEqual(testCase, v.individual(:, :, 3, 2), expect / 100, 'AbsTol', 1e-12);
verifyEqual(testCase, v.control.mean, expect / 10, 'AbsTol', 1e-12);
verifyEqual(testCase, v.control.stderr, expect / 40, 'AbsTol', 1e-12);
verifyEqual(testCase, size(v.control.individual), [2 3 3]);
verifyEqual(testCase, v.control.individual(:, :, 1), expect / 10, 'AbsTol', 1e-12);
end

function testACurveThatIsNotAFullGridHasOneStimulusConditionDimension(testCase)
% 5 of the 6 combinations: not a grid. ONE dimension of 5 conditions, its term
% XCO:0000000 "experimental condition" (Jess Haley 2026-10-22 [stimulus
% condition term]), with one covariate PER VARIABLE along it; the arrays keep their
% one condition axis, in the source's order. The joined 'a x b' label is gone.
[S, T] = ndgrid([0.1 0.2], [1 2 4]);
order = [5 2 6 1 4];
sf = S(order); tf = T(order);
leaf = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve( ...
    flatRawBody(gridRawCurve(sf, tf))));
ax = did2.unittest.helpers.axesOf(leaf);
assertEqual(testCase, numel(ax), 1);
verifyEqual(testCase, ax(1).term.name, 'experimental condition');
verifyEqual(testCase, ax(1).term.node, 'XCO:0000000');
verifyEqual(testCase, ax(1).n, 5);
verifyEqual(testCase, ax(1).nCov, 2, 'one covariate per variable along the one dimension');
covs = leaf.data.covariates;
verifyEqual(testCase, arrayfun(@(c) char(c.variable.name), covs, 'UniformOutput', false), ...
    {'spatial frequency', 'temporal frequency'});
verifyEqual(testCase, reshape(covs(1).quantity.value, 1, []), reshape(sf, 1, []), 'AbsTol', 1e-12);
verifyEqual(testCase, reshape(covs(2).quantity.value, 1, []), reshape(tf, 1, []), 'AbsTol', 1e-12);
verifyTrue(testCase, ~isfield(leaf.data, 'datum_order') || isempty(leaf.data.datum_order), ...
    'one dimension: no order to state');
v = leaf.tuning_curve.value;
verifyEqual(testCase, v.mean, reshape(10 * sf + tf, 1, []), 'AbsTol', 1e-12);
verifyEqual(testCase, size(v.individual), [5 3 2], 'conditions x trials x [real, imaginary]');
end

function testARepeatedConditionIsNotAGrid(testCase)
% 6 conditions, as many as a 2 x 3 grid holds, but one combination twice and
% one missing: the count alone must not make a grid.
[S, T] = ndgrid([0.1 0.2], [1 2 4]);
order = [1 2 3 4 5 5];
leaf = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve( ...
    flatRawBody(gridRawCurve(S(order), T(order)))));
ax = did2.unittest.helpers.axesOf(leaf);
assertEqual(testCase, numel(ax), 1);
verifyEqual(testCase, ax(1).term.node, 'XCO:0000000');
verifyEqual(testCase, ax(1).n, 6);
end

function testAFittedCurveOverAFullGridIsReshapedToo(testCase)
% The fitted composites take the same path: a speed_tuning curve whose 4
% conditions are the full 2 x 2 grid of its spatial and temporal frequencies.
tc = speedCurve();
tc.spatial_frequency = [0.1; 0.2; 0.1; 0.2];
tc.temporal_frequency = [1; 1; 2; 2];
tc = rmfield(tc, 'individual');
leaf = tuningLeaf(did2.convert.migrators_j.speed_tuning( ...
    tuningBody('speed_tuning', tc, emptyUnitsProperties())));
ax = did2.unittest.helpers.axesOf(leaf);
assertEqual(testCase, numel(ax), 2);
verifyEqual(testCase, {ax(1).term.name, ax(2).term.name}, {'spatial frequency', 'temporal frequency'});
verifyEqual(testCase, [ax.n], [2 2]);
verifyEqual(testCase, leaf.tuning_curve.value.mean, [1 9; 5 3], 'AbsTol', 1e-12);
verifyEqual(testCase, leaf.data.datum_order, 'F');
end

% ===================== THE RESPONSE VARIABLE ===============================
% did-schema V_eta_data_body_model_plan.md, Jess Haley 2026-10-22:
% [response variable] what a tuning response measures goes in the statement's
% `variable`, `response_unit` is the plain unit (om:hertz for a spike rate);
% [dF/F as variable] dF/F is the variable, the unit om:one; [response variable
% nodes] wikidata:Q71762818 "neural firing rate", EMPTY:0000397 "dF/F".
% Every family (the five fitted composites and the raw curve) is driven through
% its own migrator; the counts below are the denominators.

function testSpikeRateSpellingsCarryTheDocumentAsV1(testCase)
% INVERTS testSpikeRateSpellingsMakeTheVariableNeuralFiringRate (variable
% wikidata:Q71762818, unit om:hertz, the spelling kept nowhere). [generic stage
% is lossless] (Jess Haley, 2026-10-25, audit item 14): every recognised
% spelling now carries the document whole as v1, through all six migrators.
spellings = {'Hz', 'hz', 'Spikes/s', 'spikes/s', 'sp/s', 'SP/S', '1/s', ...
    'spikes/sec', 'Spikes per second', ' spikes/s '};
inspected = verifyCarriedForSpellings(testCase, spellings);
verifyEqual(testCase, inspected, 6 * numel(spellings), ...
    'every spelling through all six tuning migrators');
end

function testDffSpellingsCarryTheDocumentAsV1(testCase)
% INVERTS testDffSpellingsMakeTheVariableDff (variable EMPTY:0000397, unit
% om:one, the spelling kept nowhere); as above.
spellings = {'dF/F', 'df/f', 'DF/F', 'ΔF/F', 'deltaF/F', 'dff', 'dFF'};
inspected = verifyCarriedForSpellings(testCase, spellings);
verifyEqual(testCase, inspected, 6 * numel(spellings), ...
    'every spelling through all six tuning migrators');
end

function inspected = verifyCarriedForSpellings(testCase, spellings)
inspected = 0;
for j = 1:numel(spellings)
    [outs, bodies] = responseOutputs(spellings{j});
    for k = 1:numel(outs)
        inspected = inspected + 1;
        verifyTrue(testCase, isscalar(outs{k}) && isequaln(outs{k}{1}, bodies{k}), ...
            sprintf('%s, ''%s'': not carried whole as v1', ...
            bodies{k}.document_class.class_name, spellings{j}));
    end
end
end

function testEmptyUnitsMakeTheVariableNeuralResponse(testCase)
% The writers' real value is EMPTY (response_units is declared in NDI-matlab
% tuning_response.m's emptystruct and never assigned). INVERTED 2026-10-23
% (Jess Haley [unstated response variable]): the variable is the general term
% EMPTY:0000398 "neural response" -- not the calculator label this test used
% to expect, which is not what was measured -- and response_unit stays out.
inspected = 0;
for u = {[], '', '   ', "", 7}
    for leaf = responseLeaves(u{1})
        L = leaf{1};
        inspected = inspected + 1;
        verifyTrue(testCase, isTerm(L.statement.variable, 'EMPTY:0000398', ...
            'neural response'), sprintf( ...
            '%s: variable is not EMPTY:0000398 "neural response"', ...
            L.document_class.class_name));
        verifyFalse(testCase, isfield(L.tuning_curve.value, 'response_unit'), sprintf( ...
            '%s: response_unit written although the source gives none', ...
            L.document_class.class_name));
    end
end
verifyEqual(testCase, inspected, 6 * 5, 'five empty forms through all six migrators');
end

function testAnUnknownSpellingMakesTheVariableNeuralResponse(testCase)
% A spelling the decisions do not name ('mV', 'Spikes', 'a.u.') is not guessed
% at: INVERTED 2026-10-23 ([unstated response variable]) -- the variable is the
% general term EMPTY:0000398 "neural response", not the calculator label; the
% unit keeps the source's own label, as it did before (no unit is invented).
inspected = 0;
for u = {'mV', 'Spikes', 'a.u.', 'F/F0'}
    for leaf = responseLeaves(u{1})
        L = leaf{1};
        inspected = inspected + 1;
        verifyTrue(testCase, isTerm(L.statement.variable, 'EMPTY:0000398', ...
            'neural response'), sprintf( ...
            '%s, ''%s'': variable is not EMPTY:0000398 "neural response"', ...
            L.document_class.class_name, u{1}));
        verifyTrue(testCase, isUnitNamed(L.tuning_curve.value.response_unit, u{1}), ...
            sprintf('%s, ''%s'': the source spelling of the unit was lost', ...
            L.document_class.class_name, u{1}));
    end
end
verifyEqual(testCase, inspected, 6 * 4, 'four spellings through all six migrators');
end

function testTheResponseVariableIsCountedInTheReport(testCase)
% One 'tuning_response_variable' note per folded document, its DETAIL the
% outcome: the count is the denominator the migration report prints first.
% UPDATED 2026-10-25: a recognised spelling ('Spikes/s', 'dF/F') now carries
% the document whole as v1 ([generic stage is lossless], Jess Haley), so it
% folds nothing and leaves a `carried_as_v1` note instead.
did2.convert.reportNote('reset');
responseOutputs('Spikes/s');
responseOutputs('dF/F');
responseLeaves([]);
responseLeaves('mV');
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
assertTrue(testCase, isfield(notes, 'tuning_response_variable'), ...
    'no tuning_response_variable note was left');
n = notes.tuning_response_variable;
verifyEqual(testCase, n.count, 2 * 6, 'one note per folded document');
verifyEqual(testCase, notes.carried_as_v1.count, 2 * 6, 'one carry per recognised-spelling document');
expect = {'not stated', 'unrecognised: mV'};
for j = 1:numel(expect)
    hit = strcmp(n.distinct_details, expect{j});
    assertTrue(testCase, any(hit), sprintf('no ''%s'' note', expect{j}));
    verifyEqual(testCase, n.distinct_detail_counts(hit), 6, ...
        sprintf('''%s'': one note per migrator', expect{j}));
end
verifyEqual(testCase, sum(n.distinct_detail_counts), n.count, 'every note names its outcome');
end

function [outs, bodies] = responseOutputs(units)
%RESPONSEOUTPUTS The raw outputs of all six tuning migrators, and the bodies
%   they were given, for one source `response_units` value.
outs = {};
bodies = {};
fam = familyTable();
for k = 1:numel(fam)
    props = struct('response_type', 'mean');
    props.response_units = units;
    mk = fam(k).curve;
    fn = str2func(['did2.convert.migrators_j.' fam(k).className]);
    bodies{end+1} = tuningBody(fam(k).className, mk(), props); %#ok<AGROW>
    outs{end+1} = fn(bodies{end}); %#ok<AGROW>
end
tc = flatRawCurve();
tc.response_units = units;
bodies{end+1} = flatRawBody(tc);
outs{end+1} = did2.convert.migrators_j.stimulus_tuningcurve(bodies{end});
end

function leaves = responseLeaves(units)
%RESPONSELEAVES The emitted leaves of all six tuning migrators (the five fitted
%   families through `properties.response_units`, the raw curve through its
%   block-level `response_units`) for one source `response_units` value.
leaves = {};
fam = familyTable();
for k = 1:numel(fam)
    props = struct('response_type', 'mean');
    props.response_units = units;
    mk = fam(k).curve;
    fn = str2func(['did2.convert.migrators_j.' fam(k).className]);
    leaves{end+1} = tuningLeaf(fn(tuningBody(fam(k).className, mk(), props))); %#ok<AGROW>
end
tc = flatRawCurve();
tc.response_units = units;
leaves{end+1} = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve(flatRawBody(tc)));
end

function tf = isTerm(term, node, name)
%ISTERM True when TERM is exactly {NODE, NAME}.
tf = isstruct(term) && isfield(term, 'node') && isfield(term, 'name') ...
    && strcmp(char(term.node), node) && strcmp(char(term.name), name);
end

% ===================== helpers =============================================

function a = calcApp(name)
% The v1 `app` block ndi.app.newdocument stamps on every app/calculator document;
% values from a real Soph temporal_frequency_tuning_calc document (the same block
% testMigratorsJ's calcAppJ uses). jCalculation takes the operating system from
% `app.os`; without one the source passes through and nothing here is exercised.
a = struct('name', name, 'version', '3c482d1', ...
    'url', 'https://github.com/VH-Lab/NDIcalc-vis-matlab', 'os', 'MACA64', ...
    'os_version', '15.4.1', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
end

function v = flatFoldedValue(tc)
%FLATFOLDEDVALUE Run the raw curve's own migrator and return the tuning_curve `value`.
leaf = tuningLeaf(did2.convert.migrators_j.stimulus_tuningcurve(flatRawBody(tc)));
v = leaf.tuning_curve.value;
end

function v = foldedValue(className, tc, props)
%FOLDEDVALUE Run the class's own migrator and return the tuning_curve `value`.
%   Driven through the real migrator rather than the private helper on purpose: the
%   helper is in private/ and unreachable from here, and the contract that matters is
%   what the migrator emits.
fn = str2func(['did2.convert.migrators_j.' className]);
leaf = tuningLeaf(fn(tuningBody(className, tc, props)));
v = leaf.tuning_curve.value;
end

function leaf = tuningLeaf(out)
%TUNINGLEAF The emitted calculation leaf that carries a `tuning_curve` block.
%
%   did-schema #88: the leaf is the named calculation (contrast_tuning_calculation,
%   orientation_direction_tuning_calculation, ..., or tuning_curve_calculation for
%   the raw curve), each carrying the `tuning_curve` value block.
if ~iscell(out); out = {out}; end
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
for k = 1:numel(out)
    b = out{k};
    if isa(b, 'did2.document'); b = b.toStruct(); end
    if isstruct(b) && isfield(b, 'tuning_curve') && isstruct(b.tuning_curve) ...
            && isfield(b.tuning_curve, 'value')
        leaf = b;
        return;
    end
end
error('did2:test:noLeaf', ...
    'no tuning-curve calculation leaf was emitted (got: %s)', strjoin(names, ', '));
end

function x = keyValues(leaf)
%KEYVALUES The positions along the leaf's first dimension (the stimulus
%   dimension), as a row: the covariate along it (data_body AMENDMENT 6; the
%   first key's positions before).
x = [];
ax = did2.unittest.helpers.axesOf(leaf);
if isempty(ax) || isempty(ax(1).cov); return; end
k1 = ax(1).cov;
if isfield(k1, 'quantity') && isfield(k1.quantity, 'value')
    x = reshape(k1.quantity.value, 1, []);
end
end

function tf = isUnitNamed(term, name)
%ISUNITNAMED True when TERM is {node, name} naming NAME: the bare label, or the
%   registered term the name resolves to (did2.convert.registeredTerm, case-blind).
tf = isstruct(term) && isfield(term, 'name') && strcmpi(char(term.name), name);
if ~tf && isstruct(term) && isfield(term, 'node') && ~isempty(term.node)
    reg = did2.convert.registeredTerm('', name);
    tf = strcmp(char(reg.node), char(term.node));
end
end
