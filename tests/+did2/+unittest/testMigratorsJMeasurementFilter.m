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

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
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
names = cellfun(@(d) did2.unittest.helpers.classKey(d), out.migrated, ...
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
% The epoch extent sizes each level's time key on did-schema #88 (a sampled
% body requires keys). With no epoch string the pyraview is anchored "during
% the session" and folds in pass 1, as the PRED corpus document does once its
% epoch exists.
b.epochclocktimes = struct('clocktype', 'dev_local_time', 't0_t1', [0 10]);
if nargin > 0 && ~isempty(filterBlock)
    b.filter = filterBlock;
end
end

function blk = predFilterBlock()
% filterData.m:32,47-53 (the 'high' branch), which is also the shape of the
% only real corpus document read for this family
% (PRED/41269628e2d51bf1_40a0cb9f87794ccb.json) -- LESS its `sampleFrequency`
% (2026-10-26). [small unread settings] (2) (Jess Haley, 2026-10-26) makes it
% a method parameter; on a schema whose sampled_body still declares filter_id
% (the frequency_filter path) it has no home and the document is carried as
% v1, so the fold tests use the block without it. writerFilterBlock is verbatim.
blk = struct('label', 'high', 'type', 'high', 'algorithm', 'chebyshev_1', ...
    'parameters', struct('order', 4, ...
        'filterFrequency', 300, 'passBandRipple', 0.8, ...
        'stopbandAttentuation', NaN));
end

function blk = writerFilterBlock()
% VERBATIM from filterData.m:32,47-53, sampleFrequency included
blk = predFilterBlock();
blk.parameters.sampleFrequency = 20000;
end

function tf = loadedSchemaTakesFilterId()
% the frequency_filter path: the loaded sampled_body still declares filter_id
txt = fileread(fullfile(did2.schema.cache.shared().schemaPath, 'sampled_body.json'));
tf = contains(txt, '"filter_id"');
end

function verifyPyraviewCarried(testCase, out, detailPart)
% one document, the v1 pyraview, with a `carried_as_v1` note naming DETAILPART
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1, 'one document: the v1 source');
verifyEqual(testCase, classNames(out), {'pyraview'});
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
verifyTrue(testCase, contains(notes.carried_as_v1.distinct_details{1}, detailPart), ...
    notes.carried_as_v1.distinct_details{1});
% the v1 source, not the superclass reshape: +migrators/filter.m renames
% `type` -> `filter_type` before pyraview runs, and a carry used to come out
% renamed and unrecorded as a passthrough (stamped did_v2 under its tombstone)
verifyEqual(testCase, numel(out.passthrough), 1, 'recorded as a pass-1 passthrough');
f = out.migrated{1}.get('filter');
verifyTrue(testCase, isfield(f, 'type') && ~isfield(f, 'filter_type'), ...
    'the carried pyraview is the superclass-reshaped body, not the v1 source');
% stamped did_v1 in pass 1, so nothing downstream reads it against V_eta
verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), 'did_v1');
end

function testACarriedPyraviewIsValidatedNowhereAgainstVEta(testCase)
% NDI e2e run 40275711411: 9 PRED tests failed with `Property block "filter"
% carries undeclared field "type"` -- a carried pyraview (the v1 source, with
% `filter.type`) was validated against the V_eta `filter` tombstone. A carried
% document is v1 end to end ([passthrough stays v1: how], [generic stage is
% lossless], Jess Haley): stamped 'did_v1' by pass 1, not validated by it (with
% Validate ON), and refused by no V_eta validation after it.
blk = predFilterBlock();
blk.label = 'my high-pass';            % carries the pyraview whole as v1
out = did2.convert.v1_to_v2(pyraviewBody(blk), 'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine, 'a carried document is never quarantined by V_eta');
assertEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};
verifyEqual(testCase, char(d.get('document_class.schema_version')), 'did_v1');
f = d.get('filter');
verifyTrue(testCase, isfield(f, 'type'), 'filter.type is kept');
% and a later reader validating it does not read it against V_eta
verifyWarningFree(testCase, @() did2.schema.cache.shared().validateDocument(d));
d.validate();   % no error: a did_v1 body is not validated against V_eta
end

% ===================== FAMILY 1: subjectmeasurement ========================

function testSubjectMeasurementFoldsToObservationPlusAbsoluteReference(testCase)
% THE SIGNED FOLD, end to end. 1 -> 2: a typed observation plus the wall-clock
% instant as its own document.
out = runJ(subjectMeasurementBody());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);

obs = docOfClass(testCase, out, 'observation+time');
ref = docOfClass(testCase, out, 'absolute_time_reference');

% subject_id CARRIES OVER, and the source id is PRESERVED (dissolving a
% referenced document without keeping its id is the 11,448-orphan mistake).
verifyEqual(testCase, depValue(obs.toStruct(), 'entity_id'), 'sub_42');
verifyEqual(testCase, obs.get('base.id'), 'sm_1');

% `measurement` becomes the statement's variable. Free text, so no CURIE.
verifyEqual(testCase, obs.get('statement.variable.name'), 'age');
v = obs.get('statement.variable');   % #88: no CURIE is invented for 'age'
verifyTrue(testCase, ~isfield(v, 'node') || isempty(v.node));

% `value` becomes the value. NO UNIT is asserted -- the class carries none.
% THE BLOCK NAME IS THE LEAF STEM, so [time dtype] moved it too: the class is
% `time_observation` and the block it carries is `time`. These two lines read
% `duration.` and were the ONE thing the class-name sweep missed -- `get` on a
% block that does not exist THROWS, so the test errored rather than failing an
% assertion, and the runner reported it as Failed AND Incomplete.
verifyEqual(testCase, obs.get('time.value.source_value'), 30);
verifyFalse(testCase, isfield(obs.get('time.value'), 'source_unit') ...
    && ~isempty(obs.get('time.value').source_unit), 'no unit is stated, so none is written');

% the observation points at the instant document, not at a session anchor
verifyEqual(testCase, depValue(obs.toStruct(), 'time_reference_id'), ...
    ref.get('base.id'));
end

function testDatestampBecomesTheInstantNotAField(testCase)
% The correction the team caught: "Why does it say datestamp? Shouldn't that be
% a time reference?" `measurement` has NO datestamp field, so a plain field
% mapping would have DROPPED the measurement time. Assert it survives, in the
% right place, and that it did not leak onto the observation.
out = runJ(subjectMeasurementBody());
ref = docOfClass(testCase, out, 'absolute_time_reference');

% INVERTED for #65 increment 2 (V_eta_time_reference_model_plan.md:468,
% TEAM-SIGN-OFF [time_reference] 2026-08-08). The flat `start_utc` /
% `source_start` / `end_utc` fields this block used to assert NO LONGER EXIST:
% CHANGE 1 makes the ANCHOR a nested cell and the EXTENT a separate `duration`,
% so an approximate anchor and an exact span stop contaminating each other. The
% assertions are re-pointed at the same FACTS in their new homes -- this is not
% a rename, the old paths are gone.
%
% canonical UTC instant + the string exactly as the source wrote it
verifyEqual(testCase, ref.get('absolute_time_reference.value.start.utc'), ...
    '2017-03-17T19:53:57.066Z');
verifyEqual(testCase, ref.get('absolute_time_reference.value.start.source_value'), ...
    '2017-03-17T19:53:57.066Z');
% a measurement is a POINT: an absent `duration` IS the point-in-time case
verifyFalse(testCase, isfield(ref.get('absolute_time_reference.value'), 'duration'));
% a millisecond stamp is not an approximation. CHANGE 2 deleted the value-level
% flag and deprecated the root `is_approximate`, so the one precision fact that
% remains real lives on the ANCHOR cell.
verifyEqual(testCase, ref.get('absolute_time_reference.value.start.approximate'), false);

% base.datestamp is the RECORD-CREATION stamp and is a DIFFERENT FACT -- the
% tombstone says so ("SHADOWS base.datestamp"). It must not be confused with the
% measurement instant on either document.
obs = docOfClass(testCase, out, 'observation+time');
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
verifyFalse(testCase, any(strcmp(names, 'absolute_time_reference')));
anchor = docOfClass(testCase, out, 'relative_time_reference');
obs = docOfClass(testCase, out, 'observation+time');
verifyEqual(testCase, depValue(obs.toStruct(), 'time_reference_id'), ...
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
ref = docOfClass(testCase, out, 'absolute_time_reference');
verifyEqual(testCase, ref.get('absolute_time_reference.value.start.source_value'), ...
    '17-Mar-2017 19:53:57');
verifyFalse(testCase, isfield(ref.get('absolute_time_reference.value.start'), 'utc'));
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
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), ...
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
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), ...
    'subjectmeasurement');
% and no orphan anchor is left behind pointing at a fold that did not happen
verifyFalse(testCase, any(strcmp(classNames(out), 'absolute_time_reference')));
verifyFalse(testCase, any(strcmp(classNames(out), 'relative_time_reference')));
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
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), ...
    'subjectmeasurement');
end

function testWholeWordQuantitiesStillFold(testCase)
% The other side of the same rule: narrowing must not break the real cases.
cases = { 'weight', 'observation+mass'; ...
          'body mass', 'observation+mass'; ...
          'temperature', 'observation+temperature'; ...
          'body length', 'observation+length'; ...
          'age', 'observation+time' };
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
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), ...
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
verifyEqual(testCase, names, {'absolute_time_reference', 'observation+time'});
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
obs = docOfClass(testCase, out, 'observation+mass');
verifyEqual(testCase, obs.get('mass.value.source_value'), 22.5);
verifyFalse(testCase, isfield(obs.get('mass.value'), 'source_unit') ...
    && ~isempty(obs.get('mass.value').source_unit));
verifyEqual(testCase, obs.get('statement.variable.node'), 'PATO:0000128');
% `measurement` keeps the ORDINAL session anchor -- only subjectmeasurement has
% an instant to anchor to.
verifyTrue(testCase, any(strcmp(classNames(out), 'relative_time_reference')));
verifyFalse(testCase, any(strcmp(classNames(out), 'absolute_time_reference')));
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
% #88: a bound term; 'Hz' is the registry's om:hertz 'hertz' (jSourceUnit)
verifyEqual(testCase, ff.get('frequency_filter.passband.low.source_unit').node, 'om:hertz');
verifyEqual(testCase, ff.get('frequency_filter.passband.low.source_unit').name, 'hertz');
verifyFalse(testCase, isfield(ff.get('frequency_filter.passband'), 'high'));

% TYPED gain field, not a coefficients bag: `b` and `a` ARE the filter
% coefficients, so that word is taken. cheby1's Rp is in decibels.
verifyEqual(testCase, ff.get('frequency_filter.passband_ripple.decibels'), 0.8);
% 'dB' is the registry's om:decibel 'decibel' (jSourceUnit)
verifyEqual(testCase, ff.get('frequency_filter.passband_ripple.source_unit').node, 'om:decibel');
verifyEqual(testCase, ff.get('frequency_filter.passband_ripple.source_unit').name, 'decibel');
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
names = cellfun(@(b) did2.unittest.helpers.classKey(b), bodies, 'UniformOutput', false);
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
verifyEqual(testCase, ff.get('frequency_filter.stopband_attenuation.source_unit').node, 'om:decibel');
verifyEqual(testCase, ff.get('frequency_filter.stopband_attenuation.source_unit').name, 'decibel');
% chebyshev_2 has no passband ripple -- the NaN must not have been carried
verifyFalse(testCase, isfield(ff.get('frequency_filter'), 'passband_ripple'));
end

function testLabelEqualToTypeIsNotDuplicated(testCase)
% `label` is the same fact as `band` in every real document (both "high"), so
% it is not written. (Until 2026-10-26 this also asserted that sampleFrequency
% was not carried; [small unread settings] (2) makes it a method parameter --
% testOnTheFrequencyFilterPathASampleFrequencyCarriesTheDocument and
% testAFilterIsAMethodOnceTheBodyTakesMethodId.)
out = runJ(pyraviewBody(predFilterBlock()));
ff = docOfClass(testCase, out, 'frequency_filter');
blk = ff.get('frequency_filter');
verifyFalse(testCase, isfield(blk, 'label'));
end

function testOnTheFrequencyFilterPathASampleFrequencyCarriesTheDocument(testCase)
% INVERTS what testSampleFrequencyAndLabelAreNotCarried asserted (the rate was
% dropped). [small unread settings] (2) (Jess Haley, 2026-10-26): the rate is a
% method parameter; frequency_filter has no sample rate, so on that path the
% pyraview is carried whole as v1.
assumeTrue(testCase, loadedSchemaTakesFilterId(), ...
    'the loaded sampled_body takes method_id: the rate has a home');
out = runJ(pyraviewBody(writerFilterBlock()));
verifyPyraviewCarried(testCase, out, 'sampleFrequency');
end

function testALabelThatDiffersFromItsTypeCarriesTheDocument(testCase)
% [small unread settings] (2): `label` is left unwritten only when it equals
% `type`; otherwise the pyraview is carried whole as v1.
blk = predFilterBlock();
blk.label = 'my high-pass';
out = runJ(pyraviewBody(blk));
verifyPyraviewCarried(testCase, out, 'filter.label');
end

function testAFractionalOrderCarriesTheDocument(testCase)
% [small unread settings] (2): `order` is an integer field; a fractional one
% was dropped, and now carries the pyraview whole as v1.
blk = predFilterBlock();
blk.parameters.order = 4.5;
out = runJ(pyraviewBody(blk));
verifyPyraviewCarried(testCase, out, 'order');
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
    verifyEqual(testCase, depValue(s, 'owner_id'), 'pv_1');   % #88: owner_id
end
% exactly one filter document, not one per level
verifyEqual(testCase, sum(strcmp(names, 'frequency_filter')), 1);
end

function testAFilterIsAMethodOnceTheBodyTakesMethodId(testCase)
% Jess Haley 2026-10-22 [filters are methods] (N1a): frequency_filter is
% deleted; the filter is a `method` document (term the design; parameters the
% band, the passband edges in Hz, the order as a count, ripple / attenuation
% in dB) and a body's filter_id becomes method_id. The migrator follows the
% LOADED schema, so this runs on a copy of it whose sampled_body declares
% method_id (the did-schema change that lands after this one).
src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
f = fullfile(tmp, 'sampled_body.json');
txt = fileread(f);
if ~contains(txt, '"filter_id"')
    assumeFail(testCase, 'the loaded sampled_body declares no filter_id to rename');
end
txt = strrep(txt, '"name": "filter_id"', '"name": "method_id"');
txt = strrep(txt, '"must_refer_to_document_class": "frequency_filter"', ...
    '"must_refer_to_document_class": "method"');
fid = fopen(f, 'w'); fwrite(fid, txt); fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));

out = runJ(pyraviewBody(writerFilterBlock()));
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
verifyEqual(testCase, sum(strcmp(names, 'frequency_filter')), 0, 'no frequency_filter');
verifyEqual(testCase, sum(strcmp(names, 'method')), 1, 'one method document');
m = out.migrated{strcmp(names, 'method')}.toStruct();
verifyEqual(testCase, m.method.term.node, 'EMPTY:0000387');
verifyEqual(testCase, m.method.term.name, 'Chebyshev type I filter');
p = m.method.parameters;
vars = arrayfun(@(x) char(x.variable.name), p, 'UniformOutput', false);
% registry terms (V_eta_frequency_filter_model_plan.md [filter terms from
% Wikidata], [passband edges paired])
band = p(strcmp(vars, 'filter band'));
verifyEqual(testCase, band.variable.node, 'EMPTY:0000389');
verifyEqual(testCase, band.term.node, 'wikidata:Q262754');
verifyEqual(testCase, band.term.name, 'high-pass filter');
low = p(strcmp(vars, 'passband low edge'));
verifyEqual(testCase, low.variable.node, 'EMPTY:0000390');
verifyEqual(testCase, low.quantity.value, 300);
verifyEqual(testCase, lower(char(low.unit.name)), 'hertz');
verifyFalse(testCase, any(strcmp(vars, 'passband high edge')), 'a high-pass is open above');
verifyEqual(testCase, p(strcmp(vars, 'filter order')).count, 4);
verifyEqual(testCase, p(strcmp(vars, 'filter order')).variable.node, 'EMPTY:0000394');
verifyEqual(testCase, p(strcmp(vars, 'passband ripple')).quantity.value, 0.8);
verifyEqual(testCase, p(strcmp(vars, 'passband ripple')).variable.node, 'EMPTY:0000395');
verifyFalse(testCase, any(strcmp(vars, 'stopband attenuation')), 'NaN is absent');
% the design's sample frequency, a parameter in hertz ([small unread settings]
% (2), Jess Haley, 2026-10-26)
sf = p(strcmp(vars, 'sample frequency'));
assertNumElements(testCase, sf, 1);
verifyEqual(testCase, sf.quantity.value, 20000);
verifyEqual(testCase, sf.unit.node, 'om:hertz');
bodies = out.migrated(strcmp(names, 'sampled_body'));
verifyEqual(testCase, numel(bodies), 2);
for k = 1:numel(bodies)
    sb = bodies{k}.toStruct();
    verifyEqual(testCase, depValue(sb, 'method_id'), m.base.id);
    verifyEmpty(testCase, depValue(sb, 'filter_id'));
end
end

function testFilterMethodTermsAreTheRegistryTerms(testCase)
% V_eta_frequency_filter_model_plan.md, Jess Haley 2026-10-22 [filter terms from
% Wikidata] and [passband edges paired]: every design, band value and parameter
% variable the filter method writes is the term registry's node and name.
% Same schema copy as testAFilterIsAMethodOnceTheBodyTakesMethodId.
src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
f = fullfile(tmp, 'sampled_body.json');
txt = fileread(f);
if ~contains(txt, '"filter_id"')
    assumeFail(testCase, 'the loaded sampled_body declares no filter_id to rename');
end
txt = strrep(txt, '"name": "filter_id"', '"name": "method_id"');
txt = strrep(txt, '"must_refer_to_document_class": "frequency_filter"', ...
    '"must_refer_to_document_class": "method"');
fid = fopen(f, 'w'); fwrite(fid, txt); fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));

designs = { ...
    'chebyshev_1', 'EMPTY:0000387', 'Chebyshev type I filter'; ...
    'chebyshev_2', 'EMPTY:0000388', 'Chebyshev type II filter'; ...
    'butterworth', 'wikidata:Q1018162', 'Butterworth filter'; ...
    'elliptic', 'wikidata:Q1051541', 'elliptic filter'; ...
    'bessel', 'wikidata:Q830123', 'Bessel filter'; ...
    'fir', 'wikidata:Q117785', 'Finite Impulse Response filter'};
for d = 1:size(designs, 1)
    blk = predFilterBlock();
    blk.algorithm = designs{d, 1};
    m = filterMethodOf(testCase, blk);
    verifyEqual(testCase, m.method.term.node, designs{d, 2}, designs{d, 1});
    verifyEqual(testCase, m.method.term.name, designs{d, 3}, designs{d, 1});
end

% band values, and the edge variables each band writes
bands = { ...
    'high', 300, 'wikidata:Q262754', 'high-pass filter', {'passband low edge'}; ...
    'low', 300, 'wikidata:Q918242', 'low-pass filter', {'passband high edge'}; ...
    'bandpass', [300 3000], 'wikidata:Q2718101', 'band-pass filter', ...
        {'passband low edge', 'passband high edge'}};
edgeNodes = struct('low', 'EMPTY:0000390', 'high', 'EMPTY:0000391');
for b = 1:size(bands, 1)
    blk = predFilterBlock();
    blk.type = bands{b, 1};
    blk.label = bands{b, 1};   % a label that differs from the type is carried
    blk.parameters.filterFrequency = bands{b, 2};
    blk.parameters.stopbandAttentuation = 40;
    m = filterMethodOf(testCase, blk);
    p = m.method.parameters;
    vars = arrayfun(@(x) char(x.variable.name), p, 'UniformOutput', false);
    band = p(strcmp(vars, 'filter band'));
    verifyEqual(testCase, band.variable.node, 'EMPTY:0000389', bands{b, 1});
    verifyEqual(testCase, band.term.node, bands{b, 3}, bands{b, 1});
    verifyEqual(testCase, band.term.name, bands{b, 4}, bands{b, 1});
    for e = bands{b, 5}
        edge = p(strcmp(vars, e{1}));
        assertEqual(testCase, numel(edge), 1, sprintf('%s: %s', bands{b, 1}, e{1}));
        side = strtok(strrep(e{1}, 'passband ', ''));
        verifyEqual(testCase, edge.variable.node, edgeNodes.(side), e{1});
        verifyEqual(testCase, edge.unit.node, 'om:hertz', e{1});
    end
    verifyEqual(testCase, p(strcmp(vars, 'filter order')).variable.node, 'EMPTY:0000394');
    % [units bound] (V_eta_data_body_model_plan.md): a parameter's canonical
    % unit is a registered term, om:decibel for ripple and attenuation
    rip = p(strcmp(vars, 'passband ripple'));
    verifyEqual(testCase, rip.variable.node, 'EMPTY:0000395');
    verifyEqual(testCase, rip.unit.node, 'om:decibel');
    verifyEqual(testCase, rip.unit.name, 'decibel');
    att = p(strcmp(vars, 'stopband attenuation'));
    verifyEqual(testCase, att.variable.node, 'EMPTY:0000396');
    verifyEqual(testCase, att.unit.node, 'om:decibel');
    verifyEqual(testCase, att.unit.name, 'decibel');
    verifyEqual(testCase, att.source_unit.node, 'om:decibel');
end
end

function m = filterMethodOf(testCase, blk)
out = runJ(pyraviewBody(blk));
verifyEmpty(testCase, out.quarantine);
names = classNames(out);
assertEqual(testCase, sum(strcmp(names, 'method')), 1, 'one method document');
m = out.migrated{strcmp(names, 'method')}.toStruct();
end

function testAllPassEmitsNoFilterAndNoEdge(testCase)
% filterData.m:34-42: an all-pass records type 'none' and algorithm 'none'. The
% model's `band` and `algorithm` are both mustBeNonEmpty with value_sets that
% have no 'none' member -- an all-pass is not a filter. Emit nothing, and leave
% the bodies exactly as they were before this change. 2026-10-26: label 'none'
% (the read-back path) and no sample frequency; the creation path's label
% 'all' and its rate carry the document (testTheWritersAllPassIsCarriedAsV1).
blk = struct('label', 'none', 'type', 'none', 'algorithm', 'none', ...
    'parameters', struct('sampleFrequency', NaN, 'order', NaN, ...
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

function testTheWritersAllPassIsCarriedAsV1(testCase)
% filterData.m:29-42 on the creation path: label 'all', type 'none', and the
% probe's rate. The label differs from the type and the rate has no method to
% hold it, so the pyraview is carried whole as v1 ([small unread settings]
% (2), Jess Haley, 2026-10-26).
blk = struct('label', 'all', 'type', 'none', 'algorithm', 'none', ...
    'parameters', struct('sampleFrequency', 20000, 'order', NaN, ...
        'filterFrequency', NaN, 'passBandRipple', NaN, ...
        'stopbandAttentuation', NaN));
out = runJ(pyraviewBody(blk));
verifyPyraviewCarried(testCase, out, 'filter.label');
end

function testUnknownVocabularyIsCarriedNotGuessed(testCase)
% INVERTED 2026-10-26 (was testUnknownVocabularyEmitsNothing, which dropped the
% filter). v1 has no spelling for a notch, and no design family outside the
% six in the value_set. An unrecognised value is still never guessed (mapping
% an unknown band onto band_pass would be a confident, wrong, cleanly-validating
% specification); the pyraview is carried whole as v1 instead of losing its
% filter ([generic stage is lossless], Jess Haley, 2026-10-25).
blk = predFilterBlock();
blk.type = 'notch';
blk.label = 'notch';
out = runJ(pyraviewBody(blk));
verifyPyraviewCarried(testCase, out, 'no mapping');

blk = predFilterBlock();
blk.algorithm = 'savitzky_golay';
out = runJ(pyraviewBody(blk));
verifyPyraviewCarried(testCase, out, 'no mapping');
end

function testPyraviewWithNoFilterBlockIsUnchanged(testCase)
% The pre-existing fold must be untouched when there is no filter block: the
% observation, one sampled_body per level, and the session anchor -- and no
% stray frequency_filter.
out = runJ(pyraviewBody());
names = classNames(out);
verifyTrue(testCase, any(strcmp(names, 'observation+voltage')));
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));
verifyEqual(testCase, sum(strcmp(names, 'sampled_body')), 2);
verifyFalse(testCase, any(strcmp(names, 'frequency_filter')));
end

function testBandPassNeedsTwoEdges(testCase)
% A band-pass carries both edges when the source gives a 2-element vector
% (filter.md: "two values for bandpass filters"), and asserts NEITHER when it
% gives one -- there is no way to know which end a single number is.
blk = predFilterBlock();
blk.type = 'bandpass';
blk.label = 'bandpass';
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
