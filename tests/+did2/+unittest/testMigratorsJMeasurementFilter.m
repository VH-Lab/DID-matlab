function tests = testMigratorsJMeasurementFilter
%TESTMIGRATORSJMEASUREMENTFILTER Two signed Brainstorm-J families, end to end.
%
%   TargetVersion 'V_eta'. Covers the two families signed off in
%   did-schema/schemas/:
%
%   FAMILY 1 -- subject measurement
%     TEAM-SIGN-OFF [subject measurement], jess 2026-08-06
%     (V_eta_go_forward_class_audit.md §4): `subjectmeasurement` routes through
%     the EXISTING `measurement` fold with NO new class -- subject_id carries
%     over, `measurement` becomes the statement's `variable`, `value` becomes the
%     value, and `datestamp` becomes the TIME ANCHOR (time_reference_1 ->
%     absolute_reference), NOT a field.
%
%   FAMILY 2 -- frequency_filter
%     TEAM-SIGN-OFF [frequency_filter], jess 2026-07-30
%     (V_eta_frequency_filter_model_plan.md): the v1 `filter` superclass block on
%     `pyraview` becomes a REFERENCED `frequency_filter` document -- band edges,
%     typed `gain` fields, no sample_rate.
%
%   THE FIXTURES ARE BUILT FROM THE WRITERS, NOT FROM A DID-SIDE SCHEMA, which is
%   the standing ground-truth rule. Every field name and value below is copied
%   from NDI origin/main:
%
%     subjectmeasurement   +ndi/+test/+daq/build_intan_flat_exp.m:62-66 and the
%                          three +unittest/+session builders, identically:
%                            'subjectmeasurement.measurement','age',
%                            'subjectmeasurement.value',30,
%                            'subjectmeasurement.datestamp',
%                                '2017-03-17T19:53:57.066Z'
%     filter               +ndi/+gui/+app/+pyraview/filterData.m:49-53
%                            algorithm 'chebyshev_1', type 'high',
%                            parameters struct('sampleFrequency', sr, 'order', 4,
%                              'filterFrequency', 300, 'passBandRipple', 0.8,
%                              'stopbandAttentuation', NaN)
%                          -- note the capital B in passBandRipple and the
%                          MISSPELLED stopbandAttentuation. Both are the writer's
%                          spellings; the template's own documentation disagrees,
%                          and the writer wins.
%
%   Most tests run with Validate=false so they assert the TRANSFORM without
%   needing a V_eta schema cache at the runner working directory; two
%   (testSubjectMeasurementFoldValidates, testPyraviewFilterFoldValidates) turn
%   validation ON, because a fold and a schema agreeing is not something the
%   transform assertions can show.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJMeasurementFilter');

tests = functiontests(localfunctions);
end

% ===================== shared plumbing =====================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function v = depValue(b, name)
% Read an edge off a RAW BODY STRUCT, accepting BOTH spellings. A depends_on
% entry is spelled `value` on a body a migrator built and `document_id` once
% universalRenames has normalised it (universalRenames.m:372-380), and both
% shapes are live. Precedence copied from +did2/+validate/references.m:176-179.
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    if ~strcmp(b.depends_on(k).name, name); continue; end
    if isfield(b.depends_on(k), 'document_id') && ~isempty(b.depends_on(k).document_id)
        v = char(b.depends_on(k).document_id);
    elseif isfield(b.depends_on(k), 'value') && ~isempty(b.depends_on(k).value)
        v = char(b.depends_on(k).value);
    end
    return;
end
end

function names = classNames(out)
names = cellfun(@(d) d.get('document_class.class_name'), out.migrated, ...
    'UniformOutput', false);
end

function doc = docOfClass(testCase, out, className)
names = classNames(out);
idx = find(strcmp(names, className), 1);
% ASSERT, not verify: a verify would carry on and index with [], turning a
% legible "no such class was emitted" into MATLAB:badsubscript.
assertNotEmpty(testCase, idx, sprintf('no %s in output {%s}', ...
    className, strjoin(names, ', ')));
doc = out.migrated{idx};
end

function b = subjectMeasurementBody()
% The did_v1 shape, from NDI origin/main:
%   ndi_common/database_documents/subjectmeasurement.json
%     depends_on: [subject_id]; {measurement, value, datestamp}
% ONE dependency, THREE fields. No units field, no ontology field.
b = struct();
b.document_class = struct('class_name', 'subjectmeasurement', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
b.depends_on = struct('name', {'subject_id'}, 'value', {'sub_42'});
b.base = struct('id', 'sm_1', 'session_id', 'sess_09', ...
    'name', 'Animal statistics', 'datestamp', '2024-06-01T12:00:00.000Z');
b.subjectmeasurement = struct('measurement', 'age', 'value', 30, ...
    'datestamp', '2017-03-17T19:53:57.066Z');
end

function b = pyraviewBody(filterBlock)
% pyraview with its `filter` superclass block. The pyraview block itself is the
% same fixture the existing suite uses; only the filter block is new.
b = struct();
b.document_class = struct('class_name', 'pyraview', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'filter',  'class_version', '1.0.0'), ...
                      struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
b.depends_on = struct('name', {'element_id'}, 'value', {'sub_7'});
b.base = struct('id', 'pv_1', 'session_id', 'sess_09', ...
    'name', 'pyr', 'datestamp', '2024-06-01T12:00:00.000Z');
b.pyraview = struct('label', 'high', 'native_rate', 20000, ...
    'native_start_time', 0, 'channels', 4, 'data_type', 'double', ...
    'decimation_sampling_rates', [20000 200]);
b.files = struct('file_list', {{'level1.bin', 'level2.bin'}});
if nargin > 0 && ~isempty(filterBlock)
    b.filter = filterBlock;
end
end

function blk = predFilterBlock()
% VERBATIM from filterData.m:32,47-53 (the 'high' branch), which is also the
% shape of the only real corpus document read for this family
% (PRED/41269628e2d51bf1_40a0cb9f87794ccb.json).
blk = struct('label', 'high', 'type', 'high', 'algorithm', 'chebyshev_1', ...
    'parameters', struct('sampleFrequency', 20000, 'order', 4, ...
        'filterFrequency', 300, 'passBandRipple', 0.8, ...
        'stopbandAttentuation', NaN));
end

% ===================== FAMILY 1: subjectmeasurement ========================

function testSubjectMeasurementFoldsToObservationPlusAbsoluteReference(testCase)
% THE SIGNED FOLD, end to end. 1 -> 2: a typed observation plus the wall-clock
% instant as its own document.
out = runJ(subjectMeasurementBody());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);

obs = docOfClass(testCase, out, 'time_observation');
ref = docOfClass(testCase, out, 'absolute_reference');

% subject_id CARRIES OVER, and the source id is PRESERVED (dissolving a
% referenced document without keeping its id is the 11,448-orphan mistake).
verifyEqual(testCase, depValue(obs.toStruct(), 'subject_id'), 'sub_42');
verifyEqual(testCase, obs.get('base.id'), 'sm_1');

% `measurement` becomes the statement's variable. Free text, so no CURIE.
verifyEqual(testCase, obs.get('subject_statement.variable.name'), 'age');
verifyEqual(testCase, obs.get('subject_statement.variable.node'), '');

% `value` becomes the value. NO UNIT is asserted -- the class carries none.
verifyEqual(testCase, obs.get('duration.value.source_value'), 30);
verifyEqual(testCase, obs.get('duration.value.source_unit'), '');

% the observation points at the instant document, not at a session anchor
verifyEqual(testCase, depValue(obs.toStruct(), 'time_reference_1'), ...
    ref.get('base.id'));
end

function testDatestampBecomesTheInstantNotAField(testCase)
% The correction the team caught: "Why does it say datestamp? Shouldn't that be
% a time reference?" `measurement` has NO datestamp field, so a plain field
% mapping would have DROPPED the measurement time. Assert it survives, in the
% right place, and that it did not leak onto the observation.
out = runJ(subjectMeasurementBody());
ref = docOfClass(testCase, out, 'absolute_reference');

% INVERTED for #65 increment 2 (V_eta_time_reference_model_plan.md:468,
% TEAM-SIGN-OFF [time_reference] 2026-08-08). The flat `start_utc` /
% `source_start` / `end_utc` fields this block used to assert NO LONGER EXIST:
% CHANGE 1 makes the ANCHOR a nested cell and the EXTENT a separate `duration`,
% so an approximate anchor and an exact span stop contaminating each other. The
% assertions are re-pointed at the same FACTS in their new homes -- this is not
% a rename, the old paths are gone.
%
% canonical UTC instant + the string exactly as the source wrote it
verifyEqual(testCase, ref.get('absolute_reference.value.start.utc'), ...
    '2017-03-17T19:53:57.066Z');
verifyEqual(testCase, ref.get('absolute_reference.value.start.source_value'), ...
    '2017-03-17T19:53:57.066Z');
% a measurement is a POINT: an absent `duration` IS the point-in-time case
verifyFalse(testCase, isfield(ref.get('absolute_reference.value'), 'duration'));
% a millisecond stamp is not an approximation. CHANGE 2 deleted the value-level
% flag and deprecated the root `is_approximate`, so the one precision fact that
% remains real lives on the ANCHOR cell.
verifyEqual(testCase, ref.get('absolute_reference.value.start.approximate'), false);

% base.datestamp is the RECORD-CREATION stamp and is a DIFFERENT FACT -- the
% tombstone says so ("SHADOWS base.datestamp"). It must not be confused with the
% measurement instant on either document.
obs = docOfClass(testCase, out, 'time_observation');
% base.datestamp -> base.creation_timestamp (did-schema 72fa57f). The FIXTURE
% above still writes did_v1 `datestamp`, deliberately: these assertions are
% about the MIGRATED output, and the rename happens on the way out.
verifyEqual(testCase, obs.get('base.creation_timestamp'), ...
    '2024-06-01T12:00:00.000Z');
verifyEqual(testCase, ref.get('base.creation_timestamp'), ...
    '2024-06-01T12:00:00.000Z');

% and the v1 block is gone -- no `datestamp` field survives anywhere
s = obs.toStruct();
verifyFalse(testCase, isfield(s, 'subjectmeasurement'));
end

function testMissingDatestampFallsBackToSessionAnchor(testCase)
% NO TIMES => NO absolute_reference. But `subject_interaction` requires at least
% one time_reference (min_count 1), so the fold falls back to the ordinal
% session anchor every other J migrator uses -- the honest weaker claim, not a
% fabricated instant and not a missing edge.
b = subjectMeasurementBody();
b.subjectmeasurement.datestamp = '';
out = runJ(b);
verifyEmpty(testCase, out.quarantine);

names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'absolute_reference')));
anchor = docOfClass(testCase, out, 'session_relative_reference');
obs = docOfClass(testCase, out, 'time_observation');
verifyEqual(testCase, depValue(obs.toStruct(), 'time_reference_1'), ...
    anchor.get('base.id'));
end

function testUnparseableDatestampKeepsTheSourceString(testCase)
% A stamp this migration cannot normalise to UTC is still a time. The source
% string is kept verbatim and the canonical slot is LEFT ABSENT rather than
% filled with a guess -- converting an unlabelled local time is a guess, and
% `start.utc` is mustBeNonEmpty:false so an absent one validates.
% INVERTED for #65 increment 2: the paths are `value.start.source_value` and
% `value.start.utc`; `value.source_start` / `value.start_utc` no longer exist.
b = subjectMeasurementBody();
b.subjectmeasurement.datestamp = '17-Mar-2017 19:53:57';
out = runJ(b);
ref = docOfClass(testCase, out, 'absolute_reference');
verifyEqual(testCase, ref.get('absolute_reference.value.start.source_value'), ...
    '17-Mar-2017 19:53:57');
verifyFalse(testCase, isfield(ref.get('absolute_reference.value.start'), 'utc'));
end

function testNoSubjectPassesThrough(testCase)
% GUARD 1. An observation with an empty subject_id is an observation about
% NOBODY, and +did2/+validate/references.m:90 SKIPS empty edges -- so it would
% clear the reference gate AND the quarantine gate and only show up in the
% empty-required-edge census. That is the image_stack husk. Carry it instead.
b = subjectMeasurementBody();
b.depends_on = struct('name', {'subject_id'}, 'value', {''});
out = runJ(b);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'subjectmeasurement');
verifyEqual(testCase, out.migrated{1}.get('subjectmeasurement.measurement'), 'age');
end

function testUntypeableMeasurementPassesThrough(testCase)
% GUARD 4. `value` carries no unit, so the leaf has to come from the D9 registry
% -- which ships no dimensional rows. When nothing resolves the document is
% CARRIED, visibly, in summary.unconverted_by_class. Guessing a leaf is the
% error the whole ground-truth track exists to undo.
b = subjectMeasurementBody();
b.subjectmeasurement.measurement = 'coat color';
out = runJ(b);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'subjectmeasurement');
% and no orphan anchor is left behind pointing at a fold that did not happen
verifyFalse(testCase, any(strcmp(classNames(out), 'absolute_reference')));
verifyFalse(testCase, any(strcmp(classNames(out), 'session_relative_reference')));
end

function testVoltageIsNotTypedAsADuration(testCase)
% THE SUBSTRING HAZARD, made a test rather than a comment. The shared keyword
% table matches 'age', and `contains('voltage', 'age')` is TRUE -- so a naive
% match types a VOLTAGE measurement as a DURATION, silently, and it validates.
% `subjectmeasurement.measurement` is FREE TEXT (its tombstone says so), so this
% migrator asks jQuantityLeaf for whole-word matching. Word boundaries only ever
% NARROW: they can turn a typed leaf into a passthrough, never the reverse.
b = subjectMeasurementBody();
b.subjectmeasurement.measurement = 'voltage';
out = runJ(b);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'subjectmeasurement');
end

function testWholeWordQuantitiesStillFold(testCase)
% The other side of the same rule: narrowing must not break the real cases.
cases = { 'weight', 'mass_observation'; ...
          'body mass', 'mass_observation'; ...
          'temperature', 'temperature_observation'; ...
          'body length', 'length_observation'; ...
          'age', 'time_observation' };
for k = 1:size(cases, 1)
    b = subjectMeasurementBody();
    b.subjectmeasurement.measurement = cases{k, 1};
    out = runJ(b);
    names = classNames(out);
    verifyTrue(testCase, any(strcmp(names, cases{k, 2})), ...
        sprintf('"%s" should fold to %s, got {%s}', cases{k, 1}, ...
            cases{k, 2}, strjoin(names, ', ')));
end
end

function testNonScalarValuePassesThrough(testCase)
% GUARD 3. `value` is typed `matrix` with parameters [NaN,NaN], so a vector is
% permitted by the source. The quantity composites carry ONE number, so a vector
% has no honest cell -- and taking value(1) would silently discard the rest.
b = subjectMeasurementBody();
b.subjectmeasurement.value = [30 31];
out = runJ(b);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'subjectmeasurement');
end

function testRejectsTheMeasurementSiblingsShape(testCase)
% `ontology_name` / `numeric_value` / `string_value` are `measurement`'s fields,
% not this class's. A body carrying them is a fixture built from the wrong
% sibling (or from the V_alpha snapshot), and reading it as a subjectmeasurement
% would produce an empty document that validates. Fail loudly instead.
b = subjectMeasurementBody();
b.subjectmeasurement = struct('ontology_name', 'PATO:0000011', 'name', 'age', ...
    'numeric_value', 30, 'string_value', '');
out = runJ(b);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyTrue(testCase, contains(out.quarantine(1).reason, 'measurement'));
end

function testSubjectMeasurementFoldValidates(testCase)
% THE POINT OF THE FAMILY, asserted with validation ON rather than inferred from
% the transform tests above: the fold and the V_eta schemas have to agree. Both
% emitted classes are checked -- and `absolute_reference` has never had an
% emitter before, so this is the first time anything has validated one.
% runJ deliberately passes Validate=false, so this calls v1_to_v2 directly.
out = did2.convert.v1_to_v2(subjectMeasurementBody(), ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('subjectmeasurement quarantined under validation: %s', ...
        out.quarantine(1).reason));
end
names = sort(classNames(out));
verifyEqual(testCase, names, {'absolute_reference', 'time_observation'});
end

function testMeasurementSiblingIsUnchangedByTheExtraction(testCase)
% REGRESSION. The fold body moved into private/jMeasurementFold so this class and
% its `subjectmeasurement` sibling share ONE implementation. `measurement` must
% behave exactly as before: same leaf, same session anchor, same unit-free value.
v1 = struct();
v1.document_class = struct('class_name', 'measurement', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'sub_42'});
v1.base = struct('id', 'me_1', 'session_id', 'sess_09', ...
    'name', 'm', 'datestamp', '2024-06-01T12:00:00.000Z');
% NDI origin/main measurement.json: {ontologyName, name, numeric_value,
% string_value}; universalRenames snake_cases ontologyName -> ontology_name.
v1.measurement = struct('ontology_name', 'PATO:0000128', 'name', 'body weight', ...
    'numeric_value', 22.5, 'string_value', '');
out = runJ(v1);
obs = docOfClass(testCase, out, 'mass_observation');
verifyEqual(testCase, obs.get('mass.value.source_value'), 22.5);
verifyEqual(testCase, obs.get('mass.value.source_unit'), '');
verifyEqual(testCase, obs.get('subject_statement.variable.node'), 'PATO:0000128');
% `measurement` keeps the ORDINAL session anchor -- only subjectmeasurement has
% an instant to anchor to.
verifyTrue(testCase, any(strcmp(classNames(out), 'session_relative_reference')));
verifyFalse(testCase, any(strcmp(classNames(out), 'absolute_reference')));
end

% ===================== FAMILY 2: frequency_filter ==========================

function testFilterBlockBecomesAFrequencyFilterDocument(testCase)
% The v1 `filter` block used to be DISCARDED by the pyraview fold -- silently,
% because a dropped superclass block is invisible to every Phase-1 counter. It
% is not incidental metadata: 300-Hz-high-passed voltage is a different quantity
% from raw voltage.
out = runJ(pyraviewBody(predFilterBlock()));
verifyEmpty(testCase, out.quarantine);
ff = docOfClass(testCase, out, 'frequency_filter');

% type -> band; algorithm passes through the value_set unchanged. Both are
% staged with an empty `node`: there is no CURIE authority for filter design
% families in any repo in scope (NDIC.txt was moved out of NDI-matlab).
verifyEqual(testCase, ff.get('frequency_filter.band.name'), 'high_pass');
verifyEqual(testCase, ff.get('frequency_filter.algorithm.name'), 'chebyshev_1');
verifyEqual(testCase, ff.get('frequency_filter.order'), 4);

% BAND EDGES, NOT A CUTOFF. A high-pass has a LOW edge and no high edge -- an
% absent edge means open.
verifyEqual(testCase, ff.get('frequency_filter.passband.low.hertz'), 300);
verifyEqual(testCase, ff.get('frequency_filter.passband.low.source_unit'), 'Hz');
verifyFalse(testCase, isfield(ff.get('frequency_filter.passband'), 'high'));

% TYPED gain field, not a coefficients bag: `b` and `a` ARE the filter
% coefficients, so that word is taken. cheby1's Rp is in decibels.
verifyEqual(testCase, ff.get('frequency_filter.passband_ripple.decibels'), 0.8);
verifyEqual(testCase, ff.get('frequency_filter.passband_ripple.source_unit'), 'dB');
end

function testBandComesFromFilterTypeAfterTheSuperclassRename(testCase)
% THE PIPELINE TRAP, made a test. v1_to_v2 runs the SUPERCLASS migrators before
% the concrete one (v1_to_v2.m:154 then :162), and +migrators/filter.m:30-33
% renames `filter.type` -> `filter.filter_type`. Reading only `type` -- the name
% the NDI template AND the writer both use -- returns '' on every real document,
% the guard fires every time, and the fold emits nothing while LOOKING like a
% correct cautious guard.
%
% Driven through the FULL pipeline on purpose: a direct migrator call skips the
% superclass pass and would pass whichever spelling the code read.
out = runJ(pyraviewBody(predFilterBlock()));
ff = docOfClass(testCase, out, 'frequency_filter');
verifyEqual(testCase, ff.get('frequency_filter.band.name'), 'high_pass');

% and the direct call (no superclass pass, so the block still says `type`)
% resolves the same band -- both spellings are live, exactly as for depends_on.
bodies = did2.convert.migrators_j.pyraview(pyraviewBody(predFilterBlock()));
names = cellfun(@(b) b.document_class.class_name, bodies, 'UniformOutput', false);
idx = find(strcmp(names, 'frequency_filter'), 1);
assertNotEmpty(testCase, idx);
verifyEqual(testCase, bodies{idx}.frequency_filter.band.name, 'high_pass');
end

function testNaNParametersAreAbsentNotCarried(testCase)
% NaN is how NDI says "this parameter does not apply to this design" --
% Chebyshev-I has no stopband spec. An inapplicable parameter is ABSENT, never
% NaN (the rule already set for time references). `mustNotHaveNaN` is FALSE on
% these fields, so a carried NaN would have validated cleanly and silently.
out = runJ(pyraviewBody(predFilterBlock()));
ff = docOfClass(testCase, out, 'frequency_filter');
blk = ff.get('frequency_filter');
verifyFalse(testCase, isfield(blk, 'stopband_attenuation'));
% and nothing was invented for the band this design does not have
verifyFalse(testCase, isfield(blk, 'stopband'));
end

function testMisspelledStopbandAttenuationIsRead(testCase)
% `stopbandAttentuation` (an extra `tu`) is the spelling in the WRITER
% (filterData.m:41,53) and in the real data. filter.md and filter_schema.json
% both document the CORRECT spelling, which appears in no .m file on
% origin/main. A migrator reading the correct one gets nothing, silently.
blk = predFilterBlock();
blk.algorithm = 'chebyshev_2';
blk.parameters.passBandRipple = NaN;
blk.parameters.stopbandAttentuation = 40;
out = runJ(pyraviewBody(blk));
ff = docOfClass(testCase, out, 'frequency_filter');
verifyEqual(testCase, ff.get('frequency_filter.stopband_attenuation.decibels'), 40);
verifyEqual(testCase, ff.get('frequency_filter.stopband_attenuation.source_unit'), 'dB');
% chebyshev_2 has no passband ripple -- the NaN must not have been carried
verifyFalse(testCase, isfield(ff.get('frequency_filter'), 'passband_ripple'));
end

function testSampleFrequencyAndLabelAreNotCarried(testCase)
% NO sample_rate: the document is a SPECIFICATION ("4th-order Chebyshev-I
% high-pass at 300 Hz"), which is what lets it be shared across every recording
% that used it; the rate is already on the recording. And `label` is the same
% fact as `band` in every real document (both "high"), so it is not duplicated.
out = runJ(pyraviewBody(predFilterBlock()));
ff = docOfClass(testCase, out, 'frequency_filter');
blk = ff.get('frequency_filter');
verifyFalse(testCase, isfield(blk, 'sample_rate'));
verifyFalse(testCase, isfield(blk, 'sample_frequency'));
verifyFalse(testCase, isfield(blk, 'label'));
end

function testEveryLevelBodyPointsAtTheOneFilter(testCase)
% `filter_id` is declared on `sampled_body` (optional, must_refer
% frequency_filter), so the edge rides on the BODIES -- it describes the samples.
% filterData is called once per document (makePyraviewDoc.m:58/:108) and the
% decimation happens after it, so every level shares ONE filter document.
out = runJ(pyraviewBody(predFilterBlock()));
ff = docOfClass(testCase, out, 'frequency_filter');
names = classNames(out);
bodies = out.migrated(strcmp(names, 'sampled_body'));
verifyEqual(testCase, numel(bodies), 2);
for k = 1:numel(bodies)
    s = bodies{k}.toStruct();
    verifyEqual(testCase, depValue(s, 'filter_id'), ff.get('base.id'));
    % the statement edge is untouched by the addition
    verifyEqual(testCase, depValue(s, 'statement'), 'pv_1');
end
% exactly one filter document, not one per level
verifyEqual(testCase, sum(strcmp(names, 'frequency_filter')), 1);
end

function testAllPassEmitsNoFilterAndNoEdge(testCase)
% filterData.m:34-42: an all-pass records type 'none' and algorithm 'none'. The
% model's `band` and `algorithm` are both mustBeNonEmpty with value_sets that
% have no 'none' member -- an all-pass is not a filter. Emit nothing, and leave
% the bodies exactly as they were before this change.
blk = struct('label', 'all', 'type', 'none', 'algorithm', 'none', ...
    'parameters', struct('sampleFrequency', 20000, 'order', NaN, ...
        'filterFrequency', NaN, 'passBandRipple', NaN, ...
        'stopbandAttentuation', NaN));
out = runJ(pyraviewBody(blk));
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'frequency_filter')));
bodies = out.migrated(strcmp(names, 'sampled_body'));
verifyNotEmpty(testCase, bodies);
for k = 1:numel(bodies)
    verifyEmpty(testCase, depValue(bodies{k}.toStruct(), 'filter_id'));
end
end

function testUnknownVocabularyEmitsNothing(testCase)
% v1 has no spelling for a notch, and no design family outside the six in the
% value_set. An unrecognised value is a GUARD, not a guess: no document, no
% edge. (Compare: mapping an unknown band onto band_pass would have produced a
% confident, wrong, cleanly-validating specification.)
blk = predFilterBlock();
blk.type = 'notch';
out = runJ(pyraviewBody(blk));
verifyFalse(testCase, any(strcmp(classNames(out), 'frequency_filter')));

blk = predFilterBlock();
blk.algorithm = 'savitzky_golay';
out = runJ(pyraviewBody(blk));
verifyFalse(testCase, any(strcmp(classNames(out), 'frequency_filter')));
end

function testPyraviewWithNoFilterBlockIsUnchanged(testCase)
% The pre-existing fold must be untouched when there is no filter block: the
% observation, one sampled_body per level, and the session anchor -- and no
% stray frequency_filter.
out = runJ(pyraviewBody());
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'voltage_observation')));
verifyTrue(testCase, any(strcmp(names, 'session_relative_reference')));
verifyEqual(testCase, sum(strcmp(names, 'sampled_body')), 2);
verifyFalse(testCase, any(strcmp(names, 'frequency_filter')));
end

function testBandPassNeedsTwoEdges(testCase)
% A band-pass carries both edges when the source gives a 2-element vector
% (filter.md: "two values for bandpass filters"), and asserts NEITHER when it
% gives one -- there is no way to know which end a single number is.
blk = predFilterBlock();
blk.type = 'bandpass';
blk.parameters.filterFrequency = [300 3000];
out = runJ(pyraviewBody(blk));
ff = docOfClass(testCase, out, 'frequency_filter');
verifyEqual(testCase, ff.get('frequency_filter.band.name'), 'band_pass');
verifyEqual(testCase, ff.get('frequency_filter.passband.low.hertz'), 300);
verifyEqual(testCase, ff.get('frequency_filter.passband.high.hertz'), 3000);

blk.parameters.filterFrequency = 300;
out = runJ(pyraviewBody(blk));
ff = docOfClass(testCase, out, 'frequency_filter');
verifyFalse(testCase, isfield(ff.get('frequency_filter'), 'passband'));
end

function testLowPassPutsTheEdgeOnTheHighSide(testCase)
% The reverse of the high-pass case: a low-pass keeps everything BELOW the edge,
% so the number is the passband's HIGH edge and the low edge is open.
blk = predFilterBlock();
blk.type = 'low';
blk.label = 'low';
out = runJ(pyraviewBody(blk));
ff = docOfClass(testCase, out, 'frequency_filter');
verifyEqual(testCase, ff.get('frequency_filter.band.name'), 'low_pass');
verifyEqual(testCase, ff.get('frequency_filter.passband.high.hertz'), 300);
verifyFalse(testCase, isfield(ff.get('frequency_filter.passband'), 'low'));
end

function testPyraviewFilterFoldValidates(testCase)
% Validation ON: the emitted frequency_filter has to agree with
% schemas/V_eta/stable/frequency_filter.json, and the new filter_id edge has to
% be one the sampled_body schema declares. Nothing in the transform tests above
% can show either.
out = did2.convert.v1_to_v2(pyraviewBody(predFilterBlock()), ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('pyraview+filter quarantined under validation: %s', ...
        out.quarantine(1).reason));
end
verifyTrue(testCase, any(strcmp(classNames(out), 'frequency_filter')));
end
