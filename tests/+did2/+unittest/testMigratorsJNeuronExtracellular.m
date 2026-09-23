function tests = testMigratorsJNeuronExtracellular
%TESTMIGRATORSJNEURONEXTRACELLULAR The mean-waveform fold: `neuron_extracellular`
%   -> a `voltage_observation` of the derived unit carrying the 21x32 waveform
%   INLINE over a time axis and a channel axis, plus the `count_assertion` that
%   gives `cluster_index` a queryable home, and the guards that stop the fold
%   asserting a shape it cannot justify.
%
%   STATUS: NEVER RUN LOCALLY. `command -v matlab octave` exits 1 in the
%   container this was written in, so every assertion below is UNEXECUTED here.
%   CI is the first execution. Treat a green run as the evidence, not this file.
%
%   The grain-B fold itself (derived subject + derived_from relation + the sort
%   quality) is covered by testMigratorsJ.m's
%   testNeuronExtracellularMintsDerivedSubject, and the `app` -> `software` fold
%   by testMigratorsJAppFold.m. This file covers only what landed 2026-08-17.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST, AND WHAT IS NOT SIGNED
%   ---------------------------------------------------------------------
%   DID-schema V_eta_data_body_model_plan.md, TEAM-SIGN-OFF [data_body] /
%   2026-08-14: the axis entry, time as an ordinary axis, `datum_type` on the
%   statement, and -- the rule these tests turn on -- axes live with the thing
%   whose extent they describe:
%
%       storage_mode inline -> subject_statement.axes populated, NO bodies
%       storage_mode body   -> each sampled_body.axes populated, statement EMPTY
%
%   The team's investigation note (V_eta_go_forward_class_audit.md,
%   "`neuron_extracellular` -- the sixth confirm-sheet row, NOT confirmed")
%   sketched a `sampled_body` with the two axes. The migrator emits an INLINE
%   statement instead and its header says why in full: a `sampled_body` is
%   bytes, and 0 of 21 real documents carry a `file` or `files` block while
%   NDI's own schema for the class declares `"file": [ ]`. A body here would
%   describe a 21x32 array of nothing and all 672 numbers would still be
%   dropped. testNoSampledBodyIsEmitted pins the deviation so it cannot be
%   reversed silently; NOTHING HERE IS SIGNED, and the row is still unconfirmed.
%
%   ---------------------------------------------------------------------
%   PROVENANCE OF THE FIXTURE -- MEASURED, AND HONEST ABOUT WHAT IS SYNTHETIC
%   ---------------------------------------------------------------------
%   Read off the unpacked corpus, not from any DID-side schema:
%
%     DENOMINATOR: 1220 json file(s) in corpus 20211116; 21 of class
%                  `neuron_extracellular`; 21 readable, 0 skipped
%       21/21  blocks = app, base, depends_on, document_class,
%              neuron_extracellular -- and NO `file`, NO `files`
%       21/21  mean_waveform 21x32 (all 21 DISTINCT, range -316.7018..259.4120)
%       21/21  waveform_sample_times 21 entries; ONE distinct vector overall
%       21/21  number_of_samples_per_channel == 21 == size(mean_waveform,1)
%       21/21  number_of_channels           == 32 == size(mean_waveform,2)
%       21/21  cluster_index 1..21 all distinct; quality_number in {1,4};
%              quality_label in {'multi','single'}
%       21/21  element_id POPULATED, spike_clusters_id DECLARED AND EMPTY
%       21/21  app = JRCLUST 4.0.2 "Edward" (b16dc6a), MACA64 / MATLAB 24.2
%
%   THE REAL EXTENTS ARE USED, NOT SHRUNK ONES: 21x32 and a 21-entry time base,
%   so the axis arithmetic is exercised at its real size.
%
%   THE TIME VECTOR IS THE REAL ONE, VERBATIM. That is load-bearing for
%   testTheTimeAxisIsRegularWithTheMeasuredOriginAndSpacing:
%
%     21 entries, distinct diffs [5e-05], origin -0.00025 s, spacing 5e-05 s,
%     and max |t(i) - (origin + i*spacing)| = 1.08e-19  -- REGULAR, but only to
%     within a rounding of the double, which is why the migrator decides with a
%     tolerance rather than with ==. A fixture written as `(-5:15)'*5e-05` would
%     make the test pass for the wrong reason.
%
%   THE WAVEFORM VALUES ARE SYNTHETIC AND DELIBERATELY SO, which is the one
%   place this fixture departs from the corpus. The property under test is the
%   LINEARISATION ORDER of a two-axis inline value, and 672 real doubles cannot
%   demonstrate it -- column-major and row-major are indistinguishable in
%   unstructured numbers. `reshape(1:672, 21, 32)` is the only fixture that can
%   tell them apart. The SHAPE, the TIME BASE, the field set and the empty
%   `spike_clusters_id` edge are all real; only the numbers filling the shape
%   are not.
%
%   FIELD NAMES ARE THE POST-`universalRenames` SPELLINGS (`app_name`,
%   `app_version`), because that is what a migrator is handed on the real
%   pipeline and these tests call the migrator directly. jSoftwareFromApp
%   accepts both spellings, so this choice cannot mask a rename bug -- and
%   testMigratorsJAppFold.m drives the whole pipeline for the case where it
%   could.

tests = functiontests(localfunctions);
end

% ===================== the shape ===========================================

function testTheFoldEmitsSevenBodiesOnARealShapedDocument(testCase)
% 1 -> 7: the derived subject, the derived_from relation, the shared session
% anchor, the cluster-index assertion, the waveform observation, the quality
% observation and the software entity. All 21 real documents carry a waveform,
% a cluster index, a quality number AND an app block, so 7 is the real arity.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
names = classNames(out);
verifyEqual(testCase, numel(out), 7, ...
    sprintf('expected 7 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyEqual(testCase, sum(strcmp(names, 'subject')), 1);
verifyEqual(testCase, sum(strcmp(names, 'directed_relation')), 1);
verifyEqual(testCase, sum(strcmp(names, 'session_relative_reference')), 1);
verifyEqual(testCase, sum(strcmp(names, 'count_assertion')), 1);
verifyEqual(testCase, sum(strcmp(names, 'voltage_observation')), 1);
verifyEqual(testCase, sum(strcmp(names, 'score_observation')), 1);
verifyEqual(testCase, sum(strcmp(names, 'software')), 1);
end

function testNoSampledBodyIsEmitted(testCase)
% THE DEVIATION, PINNED. The investigation note proposed a `sampled_body` with
% two axes. A sampled_body is BYTES -- `data_body` declares filename / format /
% compression / content_hash and a `body_data` file, and no value slot anywhere
% -- and these documents have none: 0 of 21 carry a `file` or `files` block and
% NDI's schema for the class declares `"file": [ ]`. A body here would describe
% a 21x32 array of nothing and drop all 672 numbers, which is the 4,563-document
% image_stack husk arrived at from the other side.
%
% DO NOT "FIX" THIS TEST BY DELETING IT. If the team rules the other way, the
% inline value has to go somewhere first.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'sampled_body')));
verifyFalse(testCase, any(strcmp(names, 'opaque_body')));
for k = 1:numel(out)
    verifyFalse(testCase, isfield(out{k}, 'sampled_body'));
    verifyFalse(testCase, isfield(out{k}, 'data_body'));
end
end

function testTheWaveformIsAnObservationOfTheUNITNotOfTheRecording(testCase)
% The whole point of the grain-B fold: a sorted unit is its own subject. The
% waveform is the unit's, not the electrode's. `element_id` IS a subject edge
% (+migrators_j/element.m promotes elements to subjects, ids PRESERVED), so the
% recording subject is a real id and the test can tell the two apart.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
neuron = pick(out, 'subject');
wobs   = pick(out, 'voltage_observation');
verifyEqual(testCase, depValueOf(wobs, 'subject_id'), neuron.base.id);
verifyNotEqual(testCase, depValueOf(wobs, 'subject_id'), 'rec_sub_1');
verifyEqual(testCase, depValueOf(wobs, 'time_reference_1'), ...
    pick(out, 'session_relative_reference').base.id, ...
    'the waveform shares the one session anchor, it does not mint a second');
end

function testTheSourceIdIsNotReusedByAnyEmittedBody(testCase)
% This migrator DISSOLVES rather than folding 1->1: it mints a fresh subject, so
% no emitted body may claim the source id. (The calculator rule is the opposite
% and is asserted the opposite way in testMigratorsJHartleyCalc.m -- these two
% must not drift into each other.)
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
for k = 1:numel(out)
    verifyNotEqual(testCase, out{k}.base.id, 'ne_1');
end
end

% ===================== the axes ============================================

function testTheAxesAreBothPresentAndInSourceDimensionOrder(testCase)
% axes[k] IS array dimension k, so a positional list has no partial mode: both
% or neither (the pyraview lesson, where a one-entry list did not mean "one of
% the dimensions" but ASSERTED that dimension 1 was channels).
%
% The order is POSITIVE EVIDENCE, not the arithmetic that 21 ~= 32: NDI's schema
% says "(NumSamples x NumChannels)", pyraview.m:722-723 reads it as `% N x C`,
% and kilosort/probe.m:546-547 writes the two counts from size(...,1)/size(...,2)
% in that order.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = pick(out, 'voltage_observation').subject_statement.axes;
verifyEqual(testCase, numel(ax), 2);
verifyEqual(testCase, [ax.n], [21 32]);
verifyEqual(testCase, arrayfun(@(a) a.variable.name, ax, 'UniformOutput', false), ...
    {'time', 'channel'});
end

function testTheTimeAxisIsRegularWithTheMeasuredOriginAndSpacing(testCase)
% MEASURED, NOT ASSUMED, and re-derived per document by the migrator. The real
% vector has one distinct diff (5e-05), origin -0.00025 s and spacing 5e-05 s
% (20 kHz), and reconstructs to within 1.08e-19 -- regular, but only to within a
% rounding of the double, so the migrator decides with a tolerance.
%
% `unit` is left BLANK and `source_unit` carries 's'. The unit is EVIDENCED:
% kilosort/probe.m:538 builds the vector as samples over a rate, and the V_eta
% tombstone's own documentation says "(seconds, in the element's local clock)".
% Leaving the bound term blank is the pyraview.m:414 precedent and stages no
% ontology term.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = pick(out, 'voltage_observation').subject_statement.axes;
verifyTrue(testCase, ax(1).regular);
verifyEqual(testCase, ax(1).origin.value,         -0.00025, 'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).origin.source_value,  -0.00025, 'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).spacing.value,         5e-05,   'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).spacing.source_value,  5e-05,   'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).source_unit, 's');
verifyEmpty(testCase, ax(1).unit.node);
verifyEmpty(testCase, ax(1).unit.name);
verifyEmpty(testCase, fieldnames(ax(1).values), ...
    'a regular axis stores no coordinates -- origin+spacing generate them');
end

function testTheTimebaseIsCarriedAsValuesWhenItIsNotRegular(testCase)
% THE IRREGULAR ARM IS REAL, NOT DEAD CODE. Regularity is a property of the
% stored vector: hartley_calc's lag axis is the standing example of a vector
% that looks regular and is not reproducible from origin+spacing at the ulp
% (0 of 210 documents reproduce exactly). Here the fixture is bluntly irregular
% so the branch is unambiguous, and `values` must keep the stored doubles.
v1 = neuronExtracellularV1();
jitter = [0; 0; 0.0004; zeros(18, 1)];       % one sample displaced
v1.neuron_extracellular.waveform_sample_times = realTimebase() + jitter;
out = did2.convert.migrators_j.neuron_extracellular(v1);
ax = pick(out, 'voltage_observation').subject_statement.axes;
verifyFalse(testCase, ax(1).regular);
verifyEqual(testCase, ax(1).values.values,        realTimebase() + jitter);
verifyEqual(testCase, ax(1).values.source_values, realTimebase() + jitter);
verifyEmpty(testCase, fieldnames(ax(1).origin), ...
    'an irregular axis has no origin -- it has values');
verifyEmpty(testCase, fieldnames(ax(1).spacing));
end

function testTheChannelAxisIsAnIndexAxisWithNoUnit(testCase)
% The document records no channel IDENTITIES -- those live in `site2channelmap`
% and `probe_geometry` -- so 1..N is the only thing it actually says. The index
% convention (origin 1, spacing 1, no unit) is pyraview.m:370's and jNgridBody's.
% Naming these channels would be a guess recorded as a fact in a queryable field.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = pick(out, 'voltage_observation').subject_statement.axes;
verifyEqual(testCase, ax(2).n, 32);
verifyTrue(testCase, ax(2).regular);
verifyEqual(testCase, ax(2).origin.value, 1);
verifyEqual(testCase, ax(2).spacing.value, 1);
verifyEmpty(testCase, ax(2).unit.name);
verifyEmpty(testCase, ax(2).source_unit);
end

% ===================== the value ===========================================

function testAllSixHundredAndSeventyTwoValuesReachTheDocumentInColumnMajorOrder(testCase)
% THE DROP THIS FOLD EXISTS TO CLOSE: 672 numbers per document, 14,112 across
% the corpus, reaching no emitted document at all before 2026-08-17.
%
% The fixture is `reshape(1:672, 21, 32)` precisely so this assertion can tell
% column-major from row-major -- with real doubles the two are
% indistinguishable. The migrator flattens with `w(:)`, MATLAB's own
% linearisation, which matches the axis order (dimension 1 = time first), so
% reshape(values, [21 32]) is the inverse.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
value = pick(out, 'voltage_observation').voltage.value;
verifyEqual(testCase, numel(value), 672, ...
    'DENOMINATOR: 21 time samples x 32 channels; a short array is a silent drop');
verifyEqual(testCase, [value.source_value], 1:672, ...
    'column-major -- reshape(values,[21 32]) must invert w(:)');
% and the axis extents multiply out to exactly what the value holds (the signed
% "axis.n == the extent of the value it indexes" check, asserted here because
% nothing in pass 1 enforces it).
ax = pick(out, 'voltage_observation').subject_statement.axes;
verifyEqual(testCase, prod([ax.n]), numel(value));
end

function testTheValueStatesNoUnitAndInventsNoCanonicalNumber(testCase)
% The numbers are microvolt-SCALE, and NOTHING declares a unit: not the NDI
% template, not its schema documentation, and not any of the three writers
% (spikesorter.m:254, kilosort/probe.m:548, kiasort/probe.m:322 each assign a
% bare matrix). So `source_unit` is '' -- the honest "the source states no unit"
% -- and the canonical `volts` sub-field is NOT written, because there is no
% factor to convert by. Inferring microvolts from the magnitude would be a guess
% recorded as a fact in a queryable field.
%
% INVERT THIS TEST if the team rules on a unit; do not patch it, because a
% patched version would assert whatever the code then did.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
value = pick(out, 'voltage_observation').voltage.value;
verifyTrue(testCase, all(arrayfun(@(v) isempty(v.source_unit), value)));
verifyFalse(testCase, isfield(value, 'volts'), ...
    'no unit means no canonical value -- a 0.0 here would read as a measurement');
verifyTrue(testCase, all(~[value.approximate]));
end

function testTheStatementIsInlineAndCarriesTheEncoding(testCase)
% The signed rule, and it is CHECKED rather than stylistic: inline => the axes
% are on the statement and there are no bodies. `datum_type` is read off the
% array's own class rather than defaulted (image_stack.m's
% `firstNonEmpty(dataType,'uint16')` is the defect not repeated), and the source
% spelling rides along because the map is not invertible.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
st = pick(out, 'voltage_observation').subject_statement;
verifyEqual(testCase, st.storage_mode, 'inline');
verifyEqual(testCase, st.datum_type, 'float64');
verifyEqual(testCase, st.source_datum_type, 'double');
verifyEqual(testCase, st.variable.name, 'mean spike waveform');
end

function testTheWaveformStatementHasNoSampleTimeBlock(testCase)
% Signed sec.2: time becomes an ordinary axis and both `sample_time` blocks
% retire. Writing the cadence into the axis AND into `sample_time` would store
% one fact twice -- the #69 shape the axis exists to remove.
%
% The score_observation still carries `kind: 'point'` and that is NOT an
% inconsistency: a scalar quality has no axis at all. Both are asserted so the
% difference is deliberate rather than accidental.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
verifyFalse(testCase, ...
    isfield(pick(out, 'voltage_observation').subject_interaction, 'sample_time'));
verifyEqual(testCase, ...
    pick(out, 'score_observation').subject_interaction.sample_time.kind, 'point');
end

% ===================== the guards ==========================================

function testAWaveformlessDocumentMintsNoObservation(testCase)
% A REAL, EXPECTED CASE, NOT A DEFECT: kilosort/probe.m:543-545 sets `meanWf`
% and `wst` to [] together when `waveform_source` is not 'templates'. An
% observation minted from nothing is a husk that validates clean, so nothing is
% minted -- and the other six bodies are unaffected.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'mean_waveform', 'waveform_sample_times'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'voltage_observation')));
verifyEqual(testCase, numel(out), 6, ...
    sprintf('expected 6 bodies without the waveform, got %d: %s', ...
        numel(out), strjoin(names, ', ')));
end

function testACountThatDisagreesWithTheArrayShapeIsRefused(testCase)
% `number_of_samples_per_channel` and `number_of_channels` are DROPPED as
% derivable -- the writer assigns them from size(...,1)/size(...,2) itself. But
% redundancy is a property of the DOCUMENT, not of the class: a disagreement
% means one of the two is wrong, and silently preferring the matrix would drop a
% real discrepancy. It holds on 21 of 21 real documents, so refusing costs
% nothing today and refuses an unknown writer tomorrow.
v1 = neuronExtracellularV1();
v1.neuron_extracellular.number_of_channels = 64;      % the matrix says 32
verifyError(testCase, ...
    @() did2.convert.migrators_j.neuron_extracellular(v1), ...
    'did2:convert:neuronWaveformShapeMismatch');
end

function testAnAbsentCountIsNotAnErrorBecauseThereIsNothingToCheck(testCase)
% The other half of the same rule, asserted so the guard is not read as
% "these fields are required". Absent or non-numeric means there is simply
% nothing to compare against; the axes come from the array either way.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'number_of_channels', 'number_of_samples_per_channel'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
ax = pick(out, 'voltage_observation').subject_statement.axes;
verifyEqual(testCase, [ax.n], [21 32]);
end

function testATimebaseOfTheWrongLengthIsRefused(testCase)
% The writer assigns the waveform and its times together, and they match in 21
% of 21 real documents. A disagreement means the time axis extent would have to
% be guessed -- and `n` is what the axis ASSERTS. Refuse rather than mislabel.
v1 = neuronExtracellularV1();
v1.neuron_extracellular.waveform_sample_times = realTimebase();
v1.neuron_extracellular.waveform_sample_times(end) = [];   % 20 times, 21 rows
verifyError(testCase, ...
    @() did2.convert.migrators_j.neuron_extracellular(v1), ...
    'did2:convert:neuronWaveformTimebaseMismatch');
end

% ===================== cluster_index =======================================

function testTheClusterIndexGetsAQueryableHomeAndNotOnlyAName(testCase)
% Before this change `cluster_index` survived ONLY as text inside the derived
% subject's `local_identifier` ('unit_7') -- findable by a human, not by a query.
%
% THIS SHAPE IS A PROPOSAL, NOT A SIGNATURE (Operating Rule 4). A cluster index
% is a NOMINAL integer and V_eta has no nominal integer type; `count_assertion`
% is chosen on the in-tree precedent that jSorterOutput.m:87 models the per-spike
% cluster LABEL series as a `count_observation`, a shape the team confirmed for
% `jrclust_clusters` on 2026-08-17. `count.value.unit` is "what is counted" and
% a label counts nothing, so it is left BLANK -- that blank is the visible marker
% that this is not a cardinality. The migrator header lists the two rejected
% alternatives and the standing objection.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
cidx = pick(out, 'count_assertion');
neuron = pick(out, 'subject');
verifyEqual(testCase, depValueOf(cidx, 'subject_id'), neuron.base.id);
verifyEqual(testCase, cidx.count.value.value, 7);
verifyEmpty(testCase, cidx.count.value.unit.name, ...
    'a label counts nothing -- an invented unit here would read as a cardinality');
verifyEqual(testCase, cidx.subject_statement.variable.name, ...
    'spike sorter cluster index');
verifyEqual(testCase, cidx.subject_statement.storage_mode, 'inline');
% the name is still there too -- the assertion is an addition, not a move
verifyEqual(testCase, neuron.subject.local_identifier, 'unit_7');
end

% ===================== the edges ===========================================

function testSpikeClustersIdIsNeverCarriedOntoAnyEmittedBody(testCase)
% THE HAZARD, ASSERTED. `spike_clusters_id` is DECLARED AND EMPTY on all 21 real
% documents. `RequiredDependencies` is ARMED BY DEFAULT (+did2/+schema/cache.m:72)
% so a required edge nothing can fill QUARANTINES the document, and an optional
% empty one validates clean and is invisible -- the 7,233-document
% invented-empty-edge pattern. Neither is created: the edge is not carried at all.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
for k = 1:numel(out)
    if ~isfield(out{k}, 'depends_on'); continue; end
    for j = 1:numel(out{k}.depends_on)
        verifyNotEqual(testCase, out{k}.depends_on(j).name, 'spike_clusters_id');
    end
end
end

function testEveryEmittedEdgeIsNonEmpty(testCase)
% THE INVENTED-EMPTY-EDGE SWEEP, with its DENOMINATOR asserted first -- without
% that an empty `out` would make this vacuously true.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
edges = 0;
for k = 1:numel(out)
    if ~isfield(out{k}, 'depends_on'); continue; end
    d = out{k}.depends_on;
    for j = 1:numel(d)
        edges = edges + 1;
        verifyNotEmpty(testCase, d(j).value, sprintf( ...
            'body %d (%s) declares edge `%s` with an empty value', ...
            k, out{k}.document_class.class_name, d(j).name));
    end
end
verifyGreaterThanOrEqual(testCase, edges, 8, ...
    ['DENOMINATOR: 2 on the relation (child, parent), 1 on the ' ...
     'count_assertion, and 3 on each of the two observations ' ...
     '(subject_id, time_reference_1, software_id)']);
end

function testTheWaveformObservationCarriesTheAppBlock(testCase)
% THE RESIDUAL THIS FOLD SHRINKS. `software_id` is declared once in the
% statement tier, on `subject_interaction`. Before the waveform fold the only
% carrier was the score_observation, so a unit with no `quality_number` had
% nowhere typed to put its software. The waveform observation is a second
% carrier, and this fixture withholds the quality number to prove it alone.
%
% The gap is NOT closed: a document with neither a quality number nor a waveform
% still has nowhere to put it, and no slot is invented for it --
% testNeuronExtracellularWithoutQualityStillHasNowhereToPutItsSoftware in
% testMigratorsJAppFold.m asserts that residual.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, 'quality_number');
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'score_observation')));
sw   = pick(out, 'software');
wobs = pick(out, 'voltage_observation');
verifyEqual(testCase, depValueOf(wobs, 'software_id'), sw.base.id);
verifyEqual(testCase, wobs.subject_interaction.execution_environment.os, 'MACA64');
verifyEqual(testCase, ...
    wobs.subject_interaction.execution_environment.interpreter_version, '24.2');
end

function testNoSoftwareEntityIsEmittedWhenNothingCanReferenceIt(testCase)
% An unreferenced `software` entity would record the program without recording
% what it produced -- and it would be an orphan in the graph. With neither
% observation there is no carrier, so no entity is minted.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'quality_number', 'mean_waveform', 'waveform_sample_times'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyFalse(testCase, any(strcmp(classNames(out), 'software')));
end

% ===================== the fixture =========================================

function v1 = neuronExtracellularV1()
%NEURONEXTRACELLULARV1 The shape of the 21 real documents in corpus 20211116.
%   See the header for the denominator and for exactly which part is synthetic.
v1 = struct();
v1.document_class = struct('class_name', 'neuron_extracellular', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0') ]);
% BOTH edges, with spike_clusters_id EMPTY -- exactly as all 21 carry it.
v1.depends_on = [ struct('name', 'element_id',        'value', 'rec_sub_1'), ...
                  struct('name', 'spike_clusters_id', 'value', '') ];
v1.base = struct('id', 'ne_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2025-09-11T12:47:39.664Z');
% post-universalRenames spelling; jSoftwareFromApp accepts both (see header).
v1.app = struct('app_name', 'JRCLUST', ...
    'app_version', '4.0.2 "Edward" (b16dc6a)', ...
    'url', 'https://github.com/JaneliaSciComp/JRCLUST', ...
    'os', 'MACA64', 'os_version', '', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.2');
v1.neuron_extracellular = struct( ...
    'number_of_samples_per_channel', 21, ...
    'number_of_channels', 32, ...
    'mean_waveform', reshape(1:672, 21, 32), ...
    'waveform_sample_times', realTimebase(), ...
    'cluster_index', 7, ...
    'quality_number', 4, ...
    'quality_label', 'multi');
end

function t = realTimebase()
%REALTIMEBASE The stored `waveform_sample_times`, VERBATIM.
%   ONE distinct vector across all 21 documents. Written out as literals rather
%   than as `(-5:15)'*5e-05`: the migrator's regularity test uses a tolerance
%   because the stored vector only reconstructs to 1.08e-19, and a generated
%   vector would make that test pass for the wrong reason.
t = [-0.00025; -0.0002; -0.00015; -0.0001; -5e-05; 0; 5e-05; 0.0001; ...
      0.00015;  0.0002;  0.00025;  0.0003;  0.00035; 0.0004; 0.00045; ...
      0.0005;   0.00055; 0.0006;   0.00065; 0.0007;  0.00075];
end

% ===================== small helpers =======================================

function names = classNames(out)
names = cellfun(@(b) b.document_class.class_name, out, 'UniformOutput', false);
end

function b = pick(out, className)
names = classNames(out);
idx = find(strcmp(names, className), 1);
if isempty(idx)
    error('testMigratorsJNeuronExtracellular:noSuchBody', ...
        'no `%s` among the emitted bodies: %s', className, strjoin(names, ', '));
end
b = out{idx};
end

function v = depValueOf(body, name)
v = '';
if ~isfield(body, 'depends_on'); return; end
for k = 1:numel(body.depends_on)
    if strcmp(body.depends_on(k).name, name)
        v = body.depends_on(k).value;
        return;
    end
end
end
