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
% UPDATED for did-schema #88: the unit is an `entity` of type cell, and the
% app's software entity carries its version as a text_assertion, so a
% real-shaped document now yields EIGHT bodies (the name is kept for history).
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
names = classNames(out);
verifyEqual(testCase, numel(out), 8, ...
    sprintf('expected 8 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyEqual(testCase, sum(strcmp(names, 'cell')), 1);
verifyEqual(testCase, sum(strcmp(names, 'directed_relation')), 1);
verifyEqual(testCase, sum(strcmp(names, 'relative_time_reference')), 1);
verifyEqual(testCase, sum(strcmp(names, 'assertion+count')), 1);
verifyEqual(testCase, sum(strcmp(names, 'observation+voltage')), 1);
verifyEqual(testCase, sum(strcmp(names, 'observation+score')), 1);
verifyEqual(testCase, sum(strcmp(names, 'software')), 1);
verifyEqual(testCase, sum(strcmp(names, 'assertion+text')), 1);   % the software's version
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
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
neuron = pick(out, 'cell');
wobs   = pick(out, 'observation+voltage');
verifyEqual(testCase, depValueOf(wobs, 'entity_id'), neuron.base.id);
verifyNotEqual(testCase, depValueOf(wobs, 'entity_id'), 'rec_sub_1');
verifyEqual(testCase, depValueOf(wobs, 'time_reference_id'), ...
    pick(out, 'relative_time_reference').base.id, ...
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
% UPDATED for #88: the axes are the statement's data.keys.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = pick(out, 'observation+voltage').data.keys;
verifyEqual(testCase, numel(ax), 2);
verifyEqual(testCase, [ax.n], [21 32]);
verifyEqual(testCase, arrayfun(@(a) a.variable.name, ax, 'UniformOutput', false), ...
    {'time', 'channel'});
end


function testTheTimeAxisIsRegularWithTheMeasuredOriginAndSpacing(testCase)
% UPDATED for #88: the time key's source unit is the registry term for 's'
% (om:second-Time, 'second'); no canonical unit is stated.
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = pick(out, 'observation+voltage').data.keys;
verifyTrue(testCase, logical(ax(1).regular));
verifyEqual(testCase, ax(1).origin.value,         -0.00025, 'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).origin.source_value,  -0.00025, 'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).spacing.value,         5e-05,   'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).spacing.source_value,  5e-05,   'AbsTol', 1e-18);
verifyEqual(testCase, ax(1).source_unit.name, 'second');
verifyFalse(testCase, isfield(ax(1), 'quantity') && ~isempty(ax(1).quantity), ...
    'a regular key stores no coordinates -- origin+spacing generate them');
end


function testTheTimebaseIsCarriedAsValuesWhenItIsNotRegular(testCase)
v1 = neuronExtracellularV1();
jitter = [0; 0; 0.0004; zeros(18, 1)];       % one sample displaced
v1.neuron_extracellular.waveform_sample_times = realTimebase() + jitter;
out = did2.convert.migrators_j.neuron_extracellular(v1);
ax = pick(out, 'observation+voltage').data.keys;
verifyFalse(testCase, logical(ax(1).regular));
verifyEqual(testCase, ax(1).quantity.value(:), realTimebase() + jitter);
verifyFalse(testCase, isfield(ax(1), 'origin') && ~isempty(ax(1).origin), ...
    'an irregular key has no origin -- it has a quantity');
end


function testTheChannelAxisIsAnIndexAxisWithNoUnit(testCase)
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
ax = pick(out, 'observation+voltage').data.keys;
verifyEqual(testCase, ax(2).n, 32);
verifyTrue(testCase, logical(ax(2).regular));
verifyEqual(testCase, ax(2).origin.value, 1);
verifyEqual(testCase, ax(2).spacing.value, 1);
verifyTrue(testCase, ~isfield(ax(2), 'unit') || isempty(ax(2).unit));
verifyTrue(testCase, ~isfield(ax(2), 'source_unit') || isempty(ax(2).source_unit));
end


% ===================== the value ===========================================

function testAllSixHundredAndSeventyTwoValuesReachTheDocumentInColumnMajorOrder(testCase)
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
value = pick(out, 'observation+voltage').voltage.value;
verifyEqual(testCase, numel(value), 672, ...
    'DENOMINATOR: 21 time samples x 32 channels; a short array is a silent drop');
verifyEqual(testCase, [value.source_value], 1:672, ...
    'column-major -- reshape(values,[21 32]) must invert w(:)');
ax = pick(out, 'observation+voltage').data.keys;
verifyEqual(testCase, prod([ax.n]), numel(value));
end


function testTheValueStatesNoUnitAndInventsNoCanonicalNumber(testCase)
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
value = pick(out, 'observation+voltage').voltage.value;
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
w = pick(out, 'observation+voltage');
verifyFalse(testCase, isfield(w.value, 'data_body') && logical(w.value.data_body));
verifyEqual(testCase, w.value.data_type, 'float64');
verifyEqual(testCase, w.value.source_data_type, 'double');
verifyEqual(testCase, w.statement.variable.name, 'mean spike waveform');
end


function testTheWaveformStatementHasNoSampleTimeBlock(testCase)
% UPDATED for #88: time is an ordinary key; neither observation carries a
% sample_time block (the interaction block has none to carry).
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
verifyFalse(testCase, isfield(pick(out, 'observation+voltage').interaction, 'sample_time'));
verifyFalse(testCase, isfield(pick(out, 'observation+score').interaction, 'sample_time'));
end


% ===================== the guards ==========================================

function testAWaveformlessDocumentMintsNoObservation(testCase)
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'mean_waveform', 'waveform_sample_times'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'observation+voltage')));
verifyEqual(testCase, numel(out), 7, ...   % #88: + the software's version assertion
    sprintf('expected 7 bodies without the waveform, got %d: %s', ...
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
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, ...
    {'number_of_channels', 'number_of_samples_per_channel'});
out = did2.convert.migrators_j.neuron_extracellular(v1);
ax = pick(out, 'observation+voltage').data.keys;
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
out = did2.convert.migrators_j.neuron_extracellular(neuronExtracellularV1());
cidx = pick(out, 'assertion+count');
neuron = pick(out, 'cell');
verifyEqual(testCase, depValueOf(cidx, 'entity_id'), neuron.base.id);
verifyEqual(testCase, cidx.count.value.count, 7);
verifyFalse(testCase, isfield(cidx.count.value, 'unit') && ~isempty(cidx.count.value.unit), ...
    'a label counts nothing -- an invented unit here would read as a cardinality');
verifyEqual(testCase, cidx.statement.variable.name, ...
    'spike sorter cluster index');
verifyEqual(testCase, neuron.entity.local_identifier, 'unit_7');
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
verifyGreaterThanOrEqual(testCase, edges, 8, ...
    ['DENOMINATOR: 2 on the relation (child, parent), 1 on the ' ...
     'count_assertion, and 3 on each of the two observations ' ...
     '(entity_id, time_reference_id, software_id)']);
end


function testTheWaveformObservationCarriesTheAppBlock(testCase)
% The app becomes the software entity the waveform observation names.
% UPDATED for #88: an observation has no execution-environment slot (only a
% calculation names an operating system / interpreter), so app.os and
% app.interpreter are not carried on an observation -- recorded in the port
% report as a loss on non-calculation statements.
v1 = neuronExtracellularV1();
v1.neuron_extracellular = rmfield(v1.neuron_extracellular, 'quality_number');
out = did2.convert.migrators_j.neuron_extracellular(v1);
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'observation+score')));
sw   = pick(out, 'software');
wobs = pick(out, 'observation+voltage');
verifyEqual(testCase, depValueOf(wobs, 'software_id'), sw.base.id);
verifyEqual(testCase, sw.entity.name, 'JRCLUST');
verifyFalse(testCase, isfield(wobs.interaction, 'execution_environment'));
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
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
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
