function tests = testMigratorsJNeuronExtracellular
%TESTMIGRATORSJNEURONEXTRACELLULAR The mean-waveform fold: `neuron_extracellular`
%   -> a calculation (value kind voltage) about the derived unit carrying the
%   21x32 waveform INLINE over a time key and a channel key, the label
%   calculations for `cluster_index` and `quality_label`, and the guards that
%   stop the fold asserting a shape it cannot justify.
%
%   2026-10-21: every statement about the unit is a CALCULATION with input_id ->
%   the sorting output (did-schema #73 review item 48, signed
%   [spatial_transcriptomics_family]); the tests below were inverted to it.
%
%   2026-10-27, Decided by Jess Haley (did-schema
%   V_eta_go_forward_class_audit.md), the tests below inverted again:
%   [neuron uses the sorted unit's cell] (no entity and no derived_from of its
%   own: every calculation is about the element it names), [every v1 id
%   survives] (the waveform calculation, else the first calculation, keeps the
%   v1 id), [sample times equal within one rounding step] (start + step within
%   one rounding step, else carried as malformed).
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

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the shape ===========================================

function testTheFoldEmitsSevenBodiesOnARealShapedDocument(testCase)
% INVERTED 2026-10-21 for #73 review item 48 (signed [spatial_transcriptomics_family]):
% every statement about the unit is a CALCULATION. INVERTED AGAIN 2026-10-27
% ([neuron uses the sorted unit's cell], Jess Haley): no unit entity and no
% derived_from. A real-shaped document yields TEN bodies (the name is kept for
% history): the anchor, two label calculations (cluster_index,
% quality_label), the waveform and the quality score; the app's software with
% its version, and the run's OS and interpreter (the interpreter with its
% version; the fixture's OS version is empty).
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
names = classNames(out);
verifyEqual(testCase, numel(out), 10, ...
    sprintf('expected 10 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyEqual(testCase, sum(strcmp(names, 'cell')), 0, 'no entity of its own');
verifyEqual(testCase, sum(strcmp(names, 'directed_relation')), 0, 'no derived_from of its own');
verifyEqual(testCase, sum(strcmp(names, 'relative_time_reference')), 1);
verifyEqual(testCase, sum(strcmp(names, 'calculation+label')), 2);
verifyEqual(testCase, sum(strcmp(names, 'calculation+voltage')), 1);
verifyEqual(testCase, sum(strcmp(names, 'calculation+score')), 1);
verifyEqual(testCase, sum(strcmp(names, 'software')), 3);         % app, OS, interpreter
verifyEqual(testCase, sum(strcmp(names, 'assertion+text')), 2);   % software versions
verifyFalse(testCase, any(strncmp(names, 'observation', 11)), ...
    'no statement about the unit is an observation any more (item 48)');
verifyFalse(testCase, any(strncmp(names, 'assertion+count', 15)), ...
    'cluster_index is a label, not a count (item 48)');
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

function testTheWaveformIsAboutTheSortedUnitsOwnEntity(testCase)
% [neuron uses the sorted unit's cell] (Decided by Jess Haley, 2026-10-27): the
% statements point at the entity of the sorted-unit element the neuron came
% from (its element_id, rec_sub_1, whose id migrators_j.element preserves).
% INVERTS testTheWaveformIsAnObservationOfTheUNITNotOfTheRecording, which
% required a second, minted unit entity.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
wobs   = pick(out, 'calculation+voltage');
verifyEqual(testCase, depValueOf(wobs, 'entity_id'), 'rec_sub_1');
verifyEqual(testCase, depValueOf(wobs, 'time_reference_id'), ...
    pick(out, 'relative_time_reference').base.id, ...
    'the waveform shares the one session anchor, it does not mint a second');
end


function testTheWaveformCalculationKeepsTheSourceId(testCase)
% [every v1 id survives] (Decided by Jess Haley, 2026-10-27): "a
% `neuron_extracellular`'s id becomes its waveform calculation's id". INVERTS
% testTheSourceIdIsNotReusedByAnyEmittedBody. Exactly one body holds it.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ids = cellfun(@(b) char(b.base.id), out, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'ne_1')), 1);
verifyEqual(testCase, pick(out, 'calculation+voltage').base.id, 'ne_1');
% with no waveform, the first calculation (the cluster index) keeps it
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'mean_waveform', 'waveform_sample_times', ...
     'number_of_samples_per_channel', 'number_of_channels'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyEqual(testCase, labelCalc(out, 'cluster identifier').base.id, 'ne_1');
end

% ===================== the axes ============================================

function testTheAxesAreBothPresentAndInSourceDimensionOrder(testCase)
% UPDATED for #88: the axes are the statement's data.keys; data_body
% AMENDMENT 6: its data.dimensions, each with a covariate along it.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = did2.unittest.helpers.axesOf(pick(out, 'calculation+voltage'));
verifyEqual(testCase, numel(ax), 2);
verifyEqual(testCase, [ax.n], [21 32]);
verifyEqual(testCase, arrayfun(@(a) lower(a.term.name), ax, 'UniformOutput', false), ...
    {'time', 'channel'});   % the registry's label (NCIT:C44170 'Channel', did-schema 34a15e2 [channel types])
% the mechanical port of a key: the covariate along a dimension names the
% same term as the dimension. The channel dimension is bare since 2026-10-22
% (its 1..N only repeated the positions; Jess Haley, 6.2a and "yes" to 1..n).
verifyEqual(testCase, ax(1).cov.variable.name, 'time');
verifyEqual(testCase, [ax.nCov], [1 0]);
end


function testTheTimeAxisIsRegularWithTheMeasuredOriginAndSpacing(testCase)
% UPDATED for #88: the time key's source unit is the registry term for 's'
% (om:second-Time, 'second'); no canonical unit is stated.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = did2.unittest.helpers.axesOf(pick(out, 'calculation+voltage'));
verifyNotEmpty(testCase, ax(1).cov.origin, 'regular: origin + spacing (AMENDMENT 6 removed `regular`)');
verifyEqual(testCase, ax(1).cov.origin.value,         -0.00025, 'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).cov.origin.source_value,  -0.00025, 'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).cov.spacing.value,         5e-05,   'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).cov.spacing.source_value,  5e-05,   'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).cov.source_unit.name, 'second');
verifyFalse(testCase, isfield(ax(1).cov, 'quantity') && ~isempty(ax(1).cov.quantity), ...
    'a regular covariate stores no coordinates -- origin+spacing generate them');
end


function testAnIrregularTimebaseIsCarriedAsMalformed(testCase)
% [sample times equal within one rounding step] (Decided by Jess Haley,
% 2026-10-27): "If a v1 neuron's times are really unevenly spaced, so start +
% step misses by more than that, the neuron is carried as malformed". INVERTS
% testTheTimebaseIsCarriedAsValuesWhenItIsNotRegular (the values arm).
v1 = neuronExtracellularV1();
jitter = [0; 0; 0.0004; zeros(18, 1)];       % one sample displaced
v1.neuron_extracellular.waveform_sample_times = realTimebase() + jitter;
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.neuron_extracellular(v1);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'returned unchanged');
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
d = notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-113] malformed: '), d);
end

function testEightRoundingStepsIsTheLimit(testCase)
% [sample times within eight rounding steps] (Decided by Jess Haley,
% 2026-10-27; amends one step): the real time base reconstructs to one rounding
% step (one ulp of 0.00075 s: 1.08e-19) and folds; one time moved by four
% more steps still folds; moved by twelve, the neuron is carried
t = realTimebase();
step = eps(max(abs(t)));
v1 = neuronExtracellularV1();
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyGreaterThan(testCase, numel(out), 1, 'the real time base folds');
t2 = t;
t2(8) = t2(8) + 4 * step;
v1.neuron_extracellular.waveform_sample_times = t2;
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyGreaterThan(testCase, numel(out), 1, 'four steps off: folds');
t3 = t;
t3(8) = t3(8) + 12 * step;
v1.neuron_extracellular.waveform_sample_times = t3;
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'twelve steps off: carried');
end

function testANeuronWithNoElementIsCarried(testCase)
% [neuron uses the sorted unit's cell]: with no element_id there is no sorted
% unit's entity to point at, and none is minted; the neuron is carried
v1 = neuronExtracellularV1();
v1.depends_on(1).value = '';
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'returned unchanged');
end


function testTheChannelAxisIsABareDimension(testCase)
% INVERTED 2026-10-22 (was testTheChannelAxisIsAnIndexAxisWithNoUnit: origin
% 1, spacing 1). The document names no channel, so its channel covariate only
% repeated the dimension's positions as 1..N, and such a covariate is not
% written (Jess Haley 2026-10-22 [covariate rules named] 6.2a, and "yes" to
% 1..n). The dimension stays, n 32; the time covariate stays.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = did2.unittest.helpers.axesOf(pick(out, 'calculation+voltage'));
verifyEqual(testCase, lower(ax(2).term.name), 'channel');   % the registry's label (NCIT:C44170 'Channel', did-schema 34a15e2 [channel types])
verifyEqual(testCase, ax(2).n, 32);
verifyEqual(testCase, ax(2).nCov, 0, 'no covariate along the channel dimension');
verifyEqual(testCase, ax(1).nCov, 1, 'the time covariate is kept');
end


% ===================== the value ===========================================

function testAllSixHundredAndSeventyTwoValuesReachTheDocumentInColumnMajorOrder(testCase)
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
value = pick(out, 'calculation+voltage').voltage.value;
verifyEqual(testCase, numel(value), 672, ...
    'DENOMINATOR: 21 time samples x 32 channels; a short array is a silent drop');
verifyEqual(testCase, [value.source_value], 1:672, ...
    'column-major -- reshape(values,[21 32]) must invert w(:)');
ax = did2.unittest.helpers.axesOf(pick(out, 'calculation+voltage'));
verifyEqual(testCase, prod([ax.n]), numel(value));
end


function testTheValueStatesNoUnitAndInventsNoCanonicalNumber(testCase)
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
value = pick(out, 'calculation+voltage').voltage.value;
verifyFalse(testCase, isfield(value, 'source_unit') && ...
    any(arrayfun(@(v) ~isempty(v.source_unit), value)));
verifyFalse(testCase, isfield(value, 'volts'), ...
    'no unit means no canonical value -- a 0.0 here would read as a measurement');
verifyTrue(testCase, all(~[value.approximate]));
end


function testTheStatementIsInlineAndCarriesTheEncoding(testCase)
% UPDATED for #88: the encoding is value.data_type / source_data_type, and an
% inline value is simply a value with no data_body flag.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
w = pick(out, 'calculation+voltage');
verifyFalse(testCase, isfield(w.value, 'data_body') && logical(w.value.data_body));
verifyEqual(testCase, w.value.data_type, 'float64');
verifyEqual(testCase, w.value.source_data_type, 'double');
verifyEqual(testCase, w.statement.variable.name, 'mean spike waveform');
end


function testTheWaveformStatementHasNoSampleTimeBlock(testCase)
% UPDATED for #88: time is an ordinary key; neither observation carries a
% sample_time block (the interaction block has none to carry).
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
verifyFalse(testCase, isfield(pick(out, 'calculation+voltage').interaction, 'sample_time'));
verifyFalse(testCase, isfield(pick(out, 'calculation+score').interaction, 'sample_time'));
end


% ===================== the guards ==========================================

function testAWaveformlessDocumentMintsNoObservation(testCase)
% (the counts go with the waveform: beside no waveform a 21 / 32 restates
% nothing and is carried as v1, testWithNoWaveformOnlyTheWritersCountsAreDropped)
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'mean_waveform', 'waveform_sample_times', ...
     'number_of_samples_per_channel', 'number_of_channels'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'calculation+voltage')));
verifyEqual(testCase, numel(out), 9, ...   % the 10 of the full fold, less the waveform
    sprintf('expected 9 bodies without the waveform, got %d: %s', ...
        numel(out), strjoin(names, ', ')));
end


function testACountThatDisagreesWithTheArrayShapeIsCarriedAsV1(testCase)
% INVERTED 2026-10-26 (was testACountThatDisagreesWithTheArrayShapeIsRefused,
% which asserted did2:convert:neuronWaveformShapeMismatch, a quarantine).
% `number_of_samples_per_channel` and `number_of_channels` are DROPPED as
% derivable -- the writer assigns them from size(...,1)/size(...,2) itself. But
% redundancy is a property of the DOCUMENT, not of the class: a count that
% disagrees with the matrix restates nothing, so the document is carried whole
% as v1 ([restated values checked], Jess Haley, 2026-10-26).
v1 = neuronExtracellularV1();
v1.neuron_extracellular.number_of_channels = 64;      % the matrix says 32
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.neuron_extracellular(v1);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'returned unchanged');
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
verifyTrue(testCase, contains(notes.carried_as_v1.distinct_details{1}, ...
    'number_of_channels'), notes.carried_as_v1.distinct_details{1});
end

function testWithNoWaveformOnlyTheWritersCountsAreDropped(testCase)
% No waveform, so the counts restate nothing but the writers' own value for an
% empty one: 1 (kilosort / kiasort / jrclust probe.m, max(size(meanWf,k),1)),
% 0 (spikesorter.m, size of an empty mean shape) or absent. Those are dropped;
% any other count is carried whole as v1 ([lossless means round trip]).
v1 = neuronExtracellularV1();
v1.neuron_extracellular.mean_waveform = [];
v1.neuron_extracellular.waveform_sample_times = [];
v1.neuron_extracellular.number_of_samples_per_channel = 1;
v1.neuron_extracellular.number_of_channels = 1;
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyGreaterThan(testCase, numel(out), 1, 'the writers'' 1 folds');
v1.neuron_extracellular.number_of_channels = 32;
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'a 32 with no waveform is carried');
end

function testAFractionalCountIsCarriedAsV1(testCase)
% A count of 31.6 does not restate the 32 columns (it was rounded and dropped).
v1 = neuronExtracellularV1();
v1.neuron_extracellular.number_of_channels = 31.6;
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'returned unchanged');
end

function testAnAbsentCountIsNotAnErrorBecauseThereIsNothingToCheck(testCase)
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'number_of_channels', 'number_of_samples_per_channel'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
ax = did2.unittest.helpers.axesOf(pick(out, 'calculation+voltage'));
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
% INVERTED 2026-10-21 (#73 review item 48): `cluster_index` is a nominal
% LABEL, computed by the sort -- a calculation with the `label` value kind
% whose value is the index as a string, not a count.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
cidx = labelCalc(out, 'cluster identifier');
verifyEqual(testCase, depValueOf(cidx, 'entity_id'), 'rec_sub_1');
verifyEqual(testCase, cidx.label.value.name, '7');
end

function testTheClusterIndexVariableIsTheAfoClusterIdentifier(testCase)
% INVERTED 2026-10-29 from the label 'spike sorter cluster index' (a term with
% no node): Decided by Jess Haley, 2026-10-27 [afo prefix registered] (did-schema
% V_eta_go_forward_class_audit.md) -- the variable is AFO:AFR_0003339 "cluster
% identifier".
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
cidx = labelCalc(out, 'cluster identifier');
verifyEqual(testCase, char(cidx.statement.variable.node), 'AFO:AFR_0003339');
names = classNames(out);
for k = find(strcmp(names, 'calculation+label'))
    verifyNotEqual(testCase, out{k}.statement.variable.name, 'spike sorter cluster index');
end
end


function testTheQualityLabelIsALabelCalculationNotDropped(testCase)
% `quality_label` ('multi' / 'single' in the corpus) was dropped before item
% 48; it is now a label calculation about the unit.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
q = labelCalc(out, 'spike sort quality');
verifyEqual(testCase, q.label.value.name, 'multi');
verifyEqual(testCase, depValueOf(q, 'entity_id'), 'rec_sub_1');
end


function testEveryCalculationNamesItsSoftwareAndRun(testCase)
% A calculation requires its software (did-schema `calculation`
% require_inherited software_id) and names the run's OS and interpreter.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
names = classNames(out);
idx = find(strncmp(names, 'calculation+', 12));
verifyEqual(testCase, numel(idx), 4, 'DENOMINATOR: two labels, the waveform, the score');
swIds = cellfun(@(b) b.base.id, out(strcmp(names, 'software')), 'UniformOutput', false);
for k = idx
    c = out{k};
    verifyTrue(testCase, any(strcmp(depValueOf(c, 'software_id'), swIds)));
    verifyTrue(testCase, any(strcmp(depValueOf(c, 'operating_system_id'), swIds)));
    verifyTrue(testCase, any(strcmp(depValueOf(c, 'interpreter_id'), swIds)));
    verifyEqual(testCase, depValueOf(c, 'time_reference_id'), ...
        pick(out, 'relative_time_reference').base.id);
end
end


function testThePopulatedSortingOutputBecomesEveryCalculationsInput(testCase)
% Item 48: input_id -> the sorting output. Every NDI writer sets
% `spike_clusters_id` to it (spikesorter.m, kilosort/kiasort/jrclust probe.m),
% and the sorter documents keep their ids when they migrate.
v1 = neuronExtracellularV1();
v1.depends_on(2).value = 'sorter_out_1';
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
idx = find(strncmp(names, 'calculation+', 12));
verifyEqual(testCase, numel(idx), 4);
for k = idx
    verifyEqual(testCase, depValueOf(out{k}, 'input_id'), 'sorter_out_1');
end
end


function testAnEmptySortingOutputWritesNoInputEdge(testCase)
% EMPTY on all 21 corpus documents: then no input_id at all, never an empty one.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
for k = 1:numel(out)
    if ~isfield(out{k}, 'depends_on'); continue; end
    verifyFalse(testCase, any(strcmp({out{k}.depends_on.name}, 'input_id')));
end
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
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
edges = 0;
for k = 1:numel(out)
    if ~isfield(out{k}, 'depends_on'); continue; end
    d = out{k}.depends_on;
    for j = 1:numel(d)
        edges = edges + 1;
        verifyNotEmpty(testCase, depValueAt(d(j)), sprintf( ...
            'body %d (%s) declares edge `%s` with an empty value', ...
            k, out{k}.document_class.class_name, d(j).name));
    end
end
verifyGreaterThanOrEqual(testCase, edges, 20, ...
    ['DENOMINATOR: 5 on each of the four calculations (entity_id, ' ...
     'time_reference_id, software_id, operating_system_id, interpreter_id)']);
end


function testTheWaveformObservationCarriesTheAppBlock(testCase)
% The app becomes the software entity the waveform calculation names (the
% name is kept for history); as a calculation it also names the run's OS.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, 'quality_number');
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'calculation+score')));
wcalc = pick(out, 'calculation+voltage');
sws = out(strcmp(names, 'software'));
app = sws{cellfun(@(b) strcmp(b.entity.name, 'JRCLUST'), sws)};
verifyEqual(testCase, depValueOf(wcalc, 'software_id'), app.base.id);
os = sws{cellfun(@(b) strcmp(b.entity.name, 'MACA64'), sws)};
verifyEqual(testCase, depValueOf(wcalc, 'operating_system_id'), os.base.id);
end


function testNoSoftwareEntityIsEmittedWhenNothingCanReferenceIt(testCase)
% An unreferenced `software` entity would be an orphan in the graph. With no
% calculation at all (no cluster index, quality or waveform) nothing names
% one, so none is minted.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'quality_number', 'quality_label', 'cluster_index', 'mean_waveform', 'waveform_sample_times', ...
     'number_of_samples_per_channel', 'number_of_channels'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
verifyFalse(testCase, any(strcmp(classNames(out), 'software')));
% [every v1 id survives] (Jess Haley, 2026-10-27): with no calculation no V2
% document can take the v1 id, so the neuron is carried whole as v1
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'carried unchanged');
end

function testAUnitWithNoAppBlockNamesNoSoftware(testCase)
% Decided by Jess Haley, 2026-10-22 [sorter software]: a sorted unit with no
% software record has no `software_id` -- not an invented "spike sorter"
% (which this migrator minted until then).
v1 = neuronExtracellularV1();
if isfield(v1, 'app'); v1 = rmfield(v1, 'app'); end
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'software')), 'no software entity is invented');
idx = find(strncmp(names, 'calculation+', 12));
verifyNotEmpty(testCase, idx, 'DENOMINATOR: the unit still has its calculations');
for k = idx
    verifyEmpty(testCase, depValueOf(out{k}, 'software_id'));
end
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
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
end

function b = labelCalc(out, variableName)
names = classNames(out);
idx = find(strcmp(names, 'calculation+label'));
for k = idx
    if strcmpi(out{k}.statement.variable.name, variableName); b = out{k}; return; end
end
error('testMigratorsJNeuronExtracellular:noSuchBody', ...
    'no calculation+label with variable `%s`', variableName);
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
        v = depValueAt(body.depends_on(k));
        return;
    end
end
end


function v = depValueAt(e)
% #88 builders write {name, document_id}; older bodies {name, value}
v = '';
if isfield(e, 'document_id') && ~isempty(e.document_id)
    v = e.document_id;
elseif isfield(e, 'value')
    v = e.value;
end
end
