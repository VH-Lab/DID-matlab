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
%      empty struct for this shape); the two guard tests PASS against it and must keep
%      passing. No composite output moves.
%
%   ---------------------------------------------------------------------
%   EVERY FIXTURE IS BUILT FROM THE WRITER, AND THE WRITER IS NOT NDI-matlab
%   ---------------------------------------------------------------------
%   None of the five result classes ships an NDI-matlab template writer; the
%   producing repo is VH-Lab/NDIcalc-vis-matlab at 65718ed (HEAD == origin/HEAD,
%   153 tracked .m files). Each class has EXACTLY ONE construction site:
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
%   Run with:  results = runtests('did2.unittest.testTuningCurveLevels');

tests = functiontests(localfunctions);
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
tc.individual_responses_real      = [1.0 1.1 0.9; 5.1 4.9 5.0; 8.8 9.2 9.0; 12.2 11.8 12.0];
tc.individual_responses_imaginary = zeros(4, 3);
tc.stimulus_presentation_number   = [1 2 3; 4 5 6; 7 8 9; 10 11 12];
tc.control_stimid  = [];
tc.response_units  = [];
tc.control_response_mean   = [0.50 0.52 0.48 0.51];
tc.control_response_stddev = [0.02 0.03 0.02 0.04];
tc.control_response_stderr = [0.01 0.015 0.01 0.02];
tc.control_individual_responses_real = ...
    [0.5 0.6 0.4; 0.5 0.6 0.5; 0.4 0.5 0.5; 0.5 0.5 0.6];
tc.control_individual_responses_imaginary = ...
    [0.1 0.0 -0.1; 0 0 0; 0 0 0; 0 0 0];
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
body.stimulus_tuningcurve = tc;
end

% ===================== the family table ====================================

function fam = familyTable()
%FAMILYTABLE The five v1 tuning result classes and the control fields their writers
%   emit. This IS the denominator the tests below report: it is enumerated once, and
%   every test walks all of it rather than sampling.
fam = struct( ...
  'className', {'contrast_tuning', 'orientation_direction_tuning', ...
                'spatial_frequency_tuning', 'speed_tuning', 'temporal_frequency_tuning'}, ...
  'curve',     {@contrastCurve, @oridirCurve, @spatialCurve, @speedCurve, @temporalCurve}, ...
  'controls',  {{'control_stddev', 'control_stderr'}, ...
                {'control_individual'}, ...
                {'control_mean', 'control_stddev', 'control_stderr', ...
                 'control_mean_stddev', 'control_mean_stderr'}, ...
                {'control_stddev', 'control_stderr'}, ...
                {'control_mean', 'control_stddev', 'control_stderr', ...
                 'control_mean_stddev', 'control_mean_stderr'}});
end

% ===================== DEFECT A ============================================

function testControlFieldsAreReadFromTheTuningCurveLevel(testCase)
% DEFECT A, all five families in one sweep. Every control field the writer emits must
% arrive in `tuning_curve.value.control_response` WITH ITS VALUE -- the fixtures put
% them ONLY inside `tuning_curve`, exactly as all five writers do, so a read at BLOCK
% level finds nothing.
%
% FAILS AGAINST THE OLD CODE for four of the five, and for 14 of the 15 control
% fields this sweep asserts: the old controlBlock took control_mean / control_stddev /
% control_stderr from `block`, so those keys are simply absent from the emitted struct
% and isfield returns false. The fifth family, orientation_direction_tuning, PASSES
% against the old code too -- its only control field is control_individual, which was
% already read from `tc`. That asymmetry is the honest result and is written down
% rather than smoothed over: the denominator for defect A is 4 of 5, not 5 of 5.
fam = familyTable();
inspected = 0; fieldsChecked = 0;
for k = 1:numel(fam)
    % the handle is taken out of the struct BEFORE it is called: `fam(k).curve()`
    % parses as indexing, not invocation.
    mk = fam(k).curve;
    expectCurve = mk();
    v = foldedValue(fam(k).className, mk(), emptyUnitsProperties());
    inspected = inspected + 1;
    cr = v.control_response;
    assertTrue(testCase, isstruct(cr), ...
        sprintf('%s: control_response is not a struct', fam(k).className));
    for c = 1:numel(fam(k).controls)
        nm = fam(k).controls{c};
        fieldsChecked = fieldsChecked + 1;
        assertTrue(testCase, isfield(cr, nm), sprintf( ...
            ['%s: control_response is missing "%s". The writer puts it INSIDE ' ...
             'tuning_curve; a read at block level finds nothing there.'], ...
            fam(k).className, nm));
        verifyEqual(testCase, cr.(nm), expectCurve.(nm), sprintf( ...
            '%s: control_response.%s carries the wrong value', fam(k).className, nm), ...
            'AbsTol', 1e-12);
    end
end
% DENOMINATOR, asserted rather than printed, so a fixture silently dropping out of
% the sweep fails instead of shrinking the evidence.
verifyEqual(testCase, inspected, 5, 'the sweep must cover all five families');
verifyEqual(testCase, fieldsChecked, 15, ...
    ['15 = 2 (contrast) + 1 (oridir) + 5 (spatial) + 2 (speed) + 5 (temporal); ' ...
     'a different total means the family table was edited without its evidence']);
end

function testTheTwoPreviouslyUnnamedControlFieldsSurvive(testCase)
% DEFECT A, the half that is not a level bug: control_mean_stddev and
% control_mean_stderr appear in NO name list the old read searched, at any level, so
% they were dropped for the two families that emit them (spatial_frequency 22/22 and
% temporal_frequency 8/8 of the writer's mocks).
%
% FAILS AGAINST THE OLD CODE: both fields are absent from the emitted struct.
pairs = {'spatial_frequency_tuning', @spatialCurve; ...
         'temporal_frequency_tuning', @temporalCurve};
verifyEqual(testCase, size(pairs, 1), 2, ...
    'exactly two of the five families emit the mean_* control scalars');
for k = 1:size(pairs, 1)
    mk = pairs{k, 2};
    v = foldedValue(pairs{k, 1}, mk(), emptyUnitsProperties());
    cr = v.control_response;
    assertTrue(testCase, isfield(cr, 'control_mean_stddev'), sprintf( ...
        '%s: control_mean_stddev was dropped -- it is in no name list', pairs{k, 1}));
    assertTrue(testCase, isfield(cr, 'control_mean_stderr'), sprintf( ...
        '%s: control_mean_stderr was dropped -- it is in no name list', pairs{k, 1}));
    verifyEqual(testCase, cr.control_mean_stddev, 0.022, 'AbsTol', 1e-12);
    verifyEqual(testCase, cr.control_mean_stderr, 0.011, 'AbsTol', 1e-12);
end
end

function testControlBlockInventsNothing(testCase)
% The guard half of DEFECT A. A family whose writer emits two control fields must
% yield EXACTLY those two -- a name list applied blindly would mint empty
% control_mean / control_mean_stddev / control_mean_stderr slots on contrast and
% speed documents, which is the invented-empty-field pattern this repo already has a
% census for. PASSES against the old code as well; it exists so the repair cannot
% overshoot, not to catch the old defect.
v = foldedValue('contrast_tuning', contrastCurve(), emptyUnitsProperties());
got = sort(fieldnames(v.control_response));
verifyEqual(testCase, got, sort({'control_stddev'; 'control_stderr'}), ...
    'contrast_tuning emits two control fields; anything else was invented');
v = foldedValue('orientation_direction_tuning', oridirCurve(), emptyUnitsProperties());
verifyEqual(testCase, fieldnames(v.control_response), {'control_individual'}, ...
    'orientation_direction_tuning emits exactly one control field');
end

function testNestedControlFieldsAcceptTheCamelCaseSpelling(testCase)
% The repo's standing rule for a NESTED read (CLAUDE.md; universalRenames.m:32-37
% snake_cases only the IMMEDIATE field names of a property block and leaves nested
% struct values alone, so a camelCase nested key reaches the migrator unrenamed).
%
% FAILS AGAINST THE OLD CODE: it searched one spelling, at the wrong level.
tc = struct('temporal_frequency', [1; 2; 4; 8], 'mean', [1; 5; 9; 3]);
tc.controlMean       = [0.5; 0.5; 0.5; 0.5];
tc.controlMeanStddev = 0.022;
v = foldedValue('temporal_frequency_tuning', tc, emptyUnitsProperties());
cr = v.control_response;
assertTrue(testCase, isfield(cr, 'control_mean'), ...
    'the camelCase nested spelling controlMean was not recognised');
verifyEqual(testCase, cr.control_mean, [0.5; 0.5; 0.5; 0.5], 'AbsTol', 1e-12);
assertTrue(testCase, isfield(cr, 'control_mean_stddev'), ...
    'the camelCase nested spelling controlMeanStddev was not recognised');
verifyEqual(testCase, cr.control_mean_stddev, 0.022, 'AbsTol', 1e-12);
end

% ===================== DEFECT B ============================================

function testResponseUnitsAreReadFromProperties(testCase)
% DEFECT B, all five families. The units live under `properties`, never on the block.
% A real char is used here so the test distinguishes "found the right level" from
% "guarded a bad type" -- the empty case is a separate test below, because the two
% failure modes are different and one of them is a type hazard.
%
% FAILS AGAINST THE OLD CODE for all five: the old read looked at block level, found
% nothing, and getf returned the numeric [] -- so v.response_units was [], not 'Hz'.
fam = familyTable();
props = struct('response_type', 'mean', 'response_units', 'Hz');
inspected = 0;
for k = 1:numel(fam)
    mk = fam(k).curve;
    v = foldedValue(fam(k).className, mk(), props);
    inspected = inspected + 1;
    verifyEqual(testCase, v.response_units, 'Hz', sprintf( ...
        ['%s: response_units must come from properties.response_units ' ...
         '(the writer sets it there and nowhere else)'], fam(k).className));
end
verifyEqual(testCase, inspected, 5, 'the sweep must cover all five families');
end

function testEmptyUnitsBecomeTheSchemaBlankAndNotAnEmptyMatrix(testCase)
% DEFECT B's type hazard, and the reason correcting the path alone is not the fix.
% The writer's REAL value is the empty matrix in 64/64 mock documents, because
% response_units is declared in NDI-matlab tuning_response.m's emptystruct (:405) and
% never assigned. V_eta types tuning_curve.value.response_units as `char`
% (blank_value ''), and did2.schema.cache/validateTypeShape raises
% did2:validation:typeMismatch for a numeric in a char field. So the emitted value
% must be char -- the schema's own blank -- never [].
%
% FAILS AGAINST THE OLD CODE: it emitted the numeric [] (ischar false) for every one
% of these documents, from the wrong level. The old value and the correct blank are
% BOTH "empty", which is exactly why this asserts the TYPE and not emptiness.
fam = familyTable();
for k = 1:numel(fam)
    mk = fam(k).curve;
    v = foldedValue(fam(k).className, mk(), emptyUnitsProperties());
    assertTrue(testCase, ischar(v.response_units), sprintf( ...
        ['%s: response_units is %s, not char. V_eta types the slot char and a ' ...
         'numeric there is a typeMismatch, so an absent/empty source value must ' ...
         'become the declared blank '''' rather than be passed through.'], ...
        fam(k).className, class(v.response_units)));
    verifyEqual(testCase, v.response_units, '', sprintf( ...
        '%s: the declared blank_value is the empty CHAR', fam(k).className));
end
end

function testFlatRawCurveStillReadsUnitsAtBlockLevel(testCase)
% THE REGRESSION GUARD, and the reason DEFECT B is a level FALLBACK and not a level
% MOVE. The flat raw stimulus_tuningcurve genuinely carries response_units at BLOCK
% level -- NDI-matlab +ndi/+app/+stimulus/tuning_response.m:405 declares it there and
% NDIcalc-vis +ndi/+calc/+vis/contrast_sensitivity.m:146 sets it to 'Hz' -- and that
% block has no `properties` sub-struct at all. Moving the read would have broken the
% one shape it was right for.
%
% PASSES against the old code too. It is here so the repair cannot regress it.
body = struct();
body.document_class = struct('class_name', 'stimulus_tuningcurve', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', 'element_id', 'value', 'elem_lvl_2');
body.base = struct('id', 'lvl_doc_2', 'session_id', 'sess_lvl', 'name', 'raw', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% the flat block, tuning_response.m:400-405 -- no `properties`, no `tuning_curve`
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', {{'Contrast'}}, ...
    'independent_variable_value', [0.1; 0.2; 0.4; 0.8], ...
    'response_mean',   [1; 5; 9; 12], ...
    'response_stddev', [0.1; 0.2; 0.3; 0.4], ...
    'response_stderr', [0.05; 0.1; 0.15; 0.2], ...
    'response_units',  'Spikes/s');

out = did2.convert.migrators_j.stimulus_tuningcurve(body);
v = tuningValue(out);
verifyEqual(testCase, v.response_units, 'Spikes/s', ...
    'the flat raw curve carries its units at BLOCK level and must keep resolving');
verifyEqual(testCase, v.independent_values, [0.1; 0.2; 0.4; 0.8], 'AbsTol', 1e-12);
end

% ===================== DEFECT C ============================================

function testFlatRawCurveControlStatisticsReachTheControlBlock(testCase)
% DEFECT C, the half that has a destination. The flat raw curve's control statistics
% are spelled control_response_mean / _stddev / _stderr; the V_eta control block's
% names are control_mean / _stddev / _stderr. Same statistic, same population, same
% per-point shape -- the flat spelling merely repeats the word `response` inside a slot
% already called `control_response`.
%
% FAILS AGAINST THE PRE-REPAIR CODE: none of the three flat names appeared in any name
% list controlBlock searched, at any level, so `control_response` came out as a struct
% with ZERO fields and all three vectors were dropped. The transcription run in the
% header reports `(none)` for this exact fixture.
v = flatFoldedValue(flatRawCurve());
cr = v.control_response;
assertTrue(testCase, isstruct(cr), 'control_response is not a struct');
expected = {'control_mean',   [0.50 0.52 0.48 0.51]; ...
            'control_stddev', [0.02 0.03 0.02 0.04]; ...
            'control_stderr', [0.01 0.015 0.01 0.02]};
checked = 0;
for k = 1:size(expected, 1)
    nm = expected{k, 1};
    assertTrue(testCase, isfield(cr, nm), sprintf( ...
        ['the flat raw curve carries this as control_response_%s ' ...
         '(tuning_response.m:478-483); it must arrive as control_response.%s'], ...
        strrep(nm, 'control_', ''), nm));
    verifyEqual(testCase, cr.(nm), expected{k, 2}, ...
        sprintf('control_response.%s carries the wrong value', nm), 'AbsTol', 1e-12);
    checked = checked + 1;
end
% DENOMINATOR, asserted rather than printed: 3 of the flat curve's 5 control names are
% mapped. If that becomes 5, this number must be changed deliberately and the two
% `control_individual_responses_*` rows argued for, not slipped in.
verifyEqual(testCase, checked, 3, ...
    '3 of the flat curve''s 5 control names have a V_eta destination');
end

function testFlatRawCurveControlBlockIsExactlyTheThreeMappedNames(testCase)
% DEFECT C's overshoot guard, and the record of the two names that are NOT mapped.
% `control_individual_responses_real` and `_imaginary` are the two halves of ONE complex
% quantity: NDI's only reader of them recombines them before using either
% (tuning_response.m:820-823, `real + sqrt(-1)*imag`, then abs() if complex). The
% composite slot `control_individual` holds the REAL-VALUED per-trial control matrix
% (DID-schema conversions/from_did_v1/orientation_direction_tuning.md:38 and
% speed_tuning.md:34), which is abs(real + i*imag) and NOT the real part -- so aliasing
% `_real` onto it would relabel a component as the whole, wrongly and silently, for
% exactly the modulated data the imaginary part exists for. Minting new
% `control_individual_real`/`_imaginary` keys instead would invent names no writer and
% no V_eta slot has: `tuning_curve.value.control_response` is declared in DID-schema
% schemas/V_eta/draft/tuning_curve.json with "fields": [] -- ZERO named sub-slots -- so
% a fabricated key is not schema-checked and would pass unnoticed. Hence: reported, not
% forced, and pinned here so the omission is a decision the suite defends.
%
% FAILS AGAINST THE PRE-REPAIR CODE, which emitted no keys at all for this shape.
v = flatFoldedValue(flatRawCurve());
got = sort(fieldnames(v.control_response));
verifyEqual(testCase, got, sort({'control_mean'; 'control_stddev'; 'control_stderr'}), ...
    ['the flat raw curve maps exactly three control names. control_individual, ' ...
     'control_mean_stddev and control_mean_stderr are COMPOSITE-only spellings and ' ...
     'must not be minted here; control_individual_responses_real/_imaginary are ' ...
     'deliberately unmapped and must not be invented under any name.']);
end

function testFlatRawCurveWithNoControlDataInventsNothing(testCase)
% testControlBlockInventsNothing's idea, extended to the new aliases -- and it bites
% harder here than it ever did for the composites. vlt.data.emptystruct declares all
% five control names on EVERY raw curve (tuning_response.m:400-405), so a document that
% recorded no control data carries them PRESENT AND EMPTY. A name list applied without
% the empty-guard would mint three blank slots on every one of those documents: the
% invented-empty-field pattern this repo keeps a corpus census for.
%
% PASSES against the pre-repair code as well (it minted nothing because it matched
% nothing). It exists so the repair cannot overshoot, not to catch the old defect.
v = flatFoldedValue(flatRawCurveWithNoControlData());
verifyTrue(testCase, isstruct(v.control_response), 'control_response must stay a struct');
verifyEmpty(testCase, fieldnames(v.control_response), ...
    ['a raw curve with no control data must yield a control block with NO fields. ' ...
     'The five names are present-and-empty on every such document, and emitting ' ...
     'them would invent blank slots wholesale.']);
end

function testFlatRawCurveKeepsItsUnmappedControlNamesOutOfTheBlockEntirely(testCase)
% The other direction of the same guard: `control_stimid` (tuning_response.m:403) is
% DECLARED AND NEVER ASSIGNED in the writer -- its only other mention, :304, is a
% name-value argument to vlt.neuro.stimulus.stimulus_response_scalar, a different
% function's parameter and not this field -- so it is [] in every document. Neither it
% nor the two `control_individual_responses_*` matrices may appear in the emitted block
% under any spelling. Asserted by SUBSTRING so a future alias cannot slip one in under a
% renamed key.
%
% PASSES against the pre-repair code. A guard, not a catch.
v = flatFoldedValue(flatRawCurve());
fns = fieldnames(v.control_response);
for k = 1:numel(fns)
    verifyEmpty(testCase, strfind(fns{k}, 'individual'), sprintf( ...
        ['control_response.%s: the real/imaginary per-trial control matrices are ' ...
         'deliberately unmapped (they are halves of one complex quantity) -- no key ' ...
         'may carry them'], fns{k}));
    verifyEmpty(testCase, strfind(fns{k}, 'stimid'), sprintf( ...
        'control_response.%s: control_stimid is never assigned by the writer', fns{k}));
end
end

function testFlatRawCurveControlRepairDoesNotDisturbTheEmpiricalCurve(testCase)
% The flat shape's other reads must be untouched by the alias list. Named separately
% from the control assertions because a regression here would otherwise be reported as
% a control-block failure and looked for in the wrong place.
%
% PASSES against the pre-repair code.
v = flatFoldedValue(flatRawCurve());
verifyEqual(testCase, v.independent_values, [0.1; 0.2; 0.4; 0.8], 'AbsTol', 1e-12);
verifyEqual(testCase, v.response_mean,   [1 5 9 12], 'AbsTol', 1e-12);
verifyEqual(testCase, v.response_stddev, [0.1 0.2 0.3 0.4], 'AbsTol', 1e-12);
verifyEqual(testCase, v.response_stderr, [0.05 0.1 0.15 0.2], 'AbsTol', 1e-12);
% response_units is declared and never assigned by this writer, so the honest value is
% the schema's blank CHAR and not the numeric [] -- the DEFECT B type hazard, on the
% one shape whose LEVEL was always right.
assertTrue(testCase, ischar(v.response_units), ...
    'response_units must be char even when the writer leaves it []');
verifyEqual(testCase, v.response_units, '');
end

% ===================== helpers =============================================

function v = flatFoldedValue(tc)
%FLATFOLDEDVALUE Run the raw curve's own migrator and return the tuning_curve `value`.
v = tuningValue(did2.convert.migrators_j.stimulus_tuningcurve(flatRawBody(tc)));
end

function v = foldedValue(className, tc, props)
%FOLDEDVALUE Run the class's own migrator and return the tuning_curve `value` cell.
%   Driven through the real migrator rather than the private helper on purpose: the
%   helper is in private/ and unreachable from here, and the contract that matters is
%   what the migrator emits.
fn = str2func(['did2.convert.migrators_j.' className]);
out = fn(tuningBody(className, tc, props));
v = tuningValue(out);
end

function v = tuningValue(out)
%TUNINGVALUE The `tuning_curve.value` cell off the emitted calculation leaf.
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
idx = find(strcmp(names, 'tuning_curve_calculation'), 1);
if isempty(idx)
    error('did2:test:noLeaf', ...
        'no tuning_curve_calculation leaf was emitted (got: %s)', strjoin(names, ', '));
end
v = out{idx}.tuning_curve.value;
end
