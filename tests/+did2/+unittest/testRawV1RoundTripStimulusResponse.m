function tests = testRawV1RoundTripStimulusResponse
%TESTRAWV1ROUNDTRIPSTIMULUSRESPONSE The stimulus-response family read as raw
%   v1, and its round trip: stimulus_response_scalar and
%   stimulus_response_scalar_parameters_basic.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [migration reliability
%   practices] (a) (a round trip per class, did2.convert.roundtrip.check), and
%   [renames carry is temporary] (what universalRenames would discard is still
%   carried, carry-049). The test of the round trip is [lossless means round
%   trip].
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   stimulus_response_scalar.json, stimulus_response.json,
%   stimulus_response_scalar_parameters_basic.json,
%   stimulus_response_scalar_parameters.json, base.json) in the shapes the ONE
%   writer at that commit gives them, and pass through jsonencode/jsondecode as
%   a corpus delivers them. The writer is
%   +ndi/+app/+stimulus/tuning_response.m (compute_stimulus_response_scalar;
%   +ndi/+mock/+fun/stimulus_response.m calls it):
%     response    ndi.document('stimulus_response_scalar', ...) + newdocument:
%                 the template merge (ndi.document.readblankdefinition) gives
%                 depends_on the five names SORTED (element_id, stimulator_id,
%                 stimulus_control_id, stimulus_presentation_id,
%                 stimulus_response_scalar_parameters_id), all five then set;
%                 base.name ''; stimulus_response.{stimulator_epochid,
%                 element_epochid} both set; response_type 'mean' | 'F<n>';
%                 responses five parallel lists (a scalar for one reading)
%     parameters  var2struct of the six knobs (temporalfreqfunc
%                 'ndi.fun.stimulustemporalfrequency', freq_response 0/1/2,
%                 prestimulus_time [], prestimulus_normalization [], isspike
%                 1 for a spike train, spiketrain_dt 0.001); no depends_on; the
%                 empty `stimulus_response_scalar_parameters` block
%   These are the shapes of all 10,124 responses and 11,440 parameters
%   documents of the corpora (20211116 and Soph; census of the corpus zips,
%   2026-10-27).
%
%   Since [response links: epoch rebuilt, control as input] (Jess Haley,
%   2026-10-27) a writer-shaped response (its stimulator epoch the element's,
%   its control an input) is NOT carried: in pass 1 it waits for its epoch
%   (handed on, the epoch gate), and once epochMint stamps the epoch it
%   converts and round trips with nothing lost. Until then every one was
%   carried (carry-050).
%
%   WHAT V2 DOES NOT KEEP is listed per fixture as KNOWN FINDINGS: open
%   questions for the team, not rules made here. Each fixture's lost paths
%   must be EXACTLY its listed findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the known findings ===============================

function f = knownFindings()
% {fixture, path, why}. Open questions, reported to the team; nothing here is
% decided.
P = 'stimulus_response_scalar_parameters_basic.';
f = { ...
    'parameters as a method, no converted user', [P 'freq_response'], ...
        ['freq_response is not a method parameter: the batch pass only checks ' ...
        'it against the harmonic of the converted responses using the method. ' ...
        'Every writer-shaped response is carried (carry-050), so on real data ' ...
        'no response is converted and the value is kept nowhere']; ...
    'converted response, its epoch not given', 'stimulus_response.element_epochid', ...
        ['the anchor names the epoch entity epochMint mints; the string is ' ...
        'on that entity, not on the documents the migrator emits']; ...
    'converted response, its epoch not given', 'stimulus_response.stimulator_epochid', ...
        'rebuilt from the element epoch string ([response links: epoch rebuilt, control as input]): as above'};
% (prestimulus_normalization [] is no longer a finding: the round trip counts
% it equal to the 0 the method states, Decided by Jess Haley, 2026-10-27
% [empty prestimulus normalization is zero])
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

function testEveryKnownFindingNamesAFixtureThatIsRun(testCase)
f = knownFindings();
names = {'parameters as a method, no converted user', ...
    'converted response, its epoch not given'};
for k = 1:size(f, 1)
    verifyTrue(testCase, any(strcmp(f{k, 1}, names)), f{k, 1});
end
end

% ===================== the switch ======================================

function testBothClassesAreSwitched(testCase)
names = did2.convert.rawV1Classes();
verifyTrue(testCase, any(strcmp(names, 'stimulus_response_scalar')));
verifyTrue(testCase, any(strcmp(names, 'stimulus_response_scalar_parameters_basic')));
r = runRaw({writerResponse('resp_1', 'mean', 3), writerParameters('par_0', 0)});
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, 2);
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

% ===================== writer-shaped responses: wait for their epoch ======

function testWriterShapedResponsesWaitForTheirEpochAndRoundTrip(testCase)
% pass 1 hands the writer's response on unconverted (the epoch gate: no epoch
% document yet), not carried; its round trip is the passthrough
cases = { ...
    'mean, six readings', writerResponse('resp_m', 'mean', 6); ...
    'F1, six readings', writerResponse('resp_f1', 'F1', 6); ...
    'F2, six readings', writerResponse('resp_f2', 'F2', 6); ...
    'mean, one reading (scalars)', writerResponse('resp_one', 'mean', 1)};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': handed on']);
    verifyFalse(testCase, isfield(out.summary.migration_notes, 'carried_as_v1'), ...
        [label ': not carried']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
end
end

function testAWriterShapedResponseOnItsEpochConvertsAndRoundTrips(testCase)
% the epoch stamped as epochMint stamps it: the writer's response converts,
% its control an input after the presentation, its stimulator epoch rebuilt
v1 = writerResponse('resp_w2', 'F1', 6);
stamped = v1;
stamped.depends_on(end+1) = struct('name', 'epoch_id', 'value', 'epochdoc_w2');
out = runRaw(stamped);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough);
epoch = did2.build.document('entity', ...
    struct('type', did2.convert.registeredTerm( ...
        did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch'), ...
        'local_identifier', 't00003'), ...
    'Id', 'epochdoc_w2', 'SessionId', v1.base.session_id, ...
    'CreationTimestamp', v1.base.datestamp, 'Validate', false);
r = did2.convert.roundtrip.check(v1, [out.migrated, {epoch}]);
verifyRoundTrip(testCase, r, 'writer-shaped response, on its epoch', {});
for p = {'stimulus_response.stimulator_epochid', 'depends_on(3).value'}
    verifyTrue(testCase, any(strcmp(p{1}, r.matched)), p{1});
end
end

% ===================== the fold: a response that states neither ===========

function testAConvertedResponseRoundTrips(testCase)
% no epoch string: the fold runs on the session anchor
v1 = convertibleResponse('resp_c1', 'F1', '');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted, not carried');
verifyEqual(testCase, numel(out.migrated), 3, 'calculation, anchor, software');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
verifyRoundTrip(testCase, r, 'converted response, session anchor', {});
accounted = [r.matched, r.not_set];
for p = {'base.id', 'base.session_id', 'base.datestamp', 'document_class.class_name', ...
        'depends_on(1).value', 'depends_on(2).value', 'depends_on(4).value', ...
        'depends_on(5).value', 'stimulus_response_scalar.response_type', ...
        'stimulus_response_scalar.responses.stimid', ...
        'stimulus_response_scalar.responses.response_real', ...
        'stimulus_response_scalar.responses.response_imaginary', ...
        'stimulus_response_scalar.responses.control_response_real', ...
        'stimulus_response_scalar.responses.control_response_imaginary'}
    verifyTrue(testCase, any(strcmp(p{1}, accounted)), sprintf('%s is not accounted for', p{1}));
end
end

function testAConvertedResponseOnItsEpochRoundTripsWithTheEpoch(testCase)
% the epoch gate opened as epochMint opens it (the `epoch_id` edge it stamps);
% the epoch entity is the one epochMint mints (an entity of type epoch whose
% local_identifier is the string). The v1 document compared is the source
% WITHOUT the stamped edge.
v1 = convertibleResponse('resp_c2', 'mean', 't00003');
stamped = v1;
stamped.depends_on(end+1) = struct('name', 'epoch_id', 'value', 'epochdoc_5f21b0');
out = runRaw(stamped);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough);
epoch = did2.build.document('entity', ...
    struct('type', did2.convert.registeredTerm( ...
        did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch'), ...
        'local_identifier', 't00003'), ...
    'Id', 'epochdoc_5f21b0', 'SessionId', v1.base.session_id, ...
    'CreationTimestamp', v1.base.datestamp, 'Validate', false);
r = did2.convert.roundtrip.check(v1, [out.migrated, {epoch}]);
verifyRoundTrip(testCase, r, 'converted response, with its epoch', {});
verifyTrue(testCase, any(strcmp('stimulus_response.element_epochid', r.matched)));
% without the epoch entity the string is not on the emitted documents
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r, 'converted response, its epoch not given', ...
    findingsFor('converted response, its epoch not given'));
end

% ===================== the parameters document ===========================

function testWriterShapedParametersPassThroughAndRoundTrip(testCase)
for h = 0:2
    v1 = writerParameters(sprintf('par_%d', h), h);
    out = runRaw(v1);
    label = sprintf('parameters, freq_response %d', h);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
    verifyEqual(testCase, out.migrated{1}.get('document_class.schema_version'), 'did_v2', label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
end
end

function testParametersBecomeAMethodAndRoundTrip(testCase)
% the batch pass turns each parameters document into a `method` (id kept)
v1 = writerParameters('par_1', 1);
out = runFold(testCase, {writerResponse('resp_w', 'F1', 6, 'par_1'), v1});
m = bodyWithId(out, 'par_1');
verifyEqual(testCase, classNameOfBody(m), 'method');
r = did2.convert.roundtrip.check(v1, {m});
verifyRoundTrip(testCase, r, 'parameters as a method, no converted user', ...
    findingsFor('parameters as a method, no converted user'));

% with a converted response using it, freq_response is its harmonic
out = runFold(testCase, {convertibleResponse('resp_c3', 'F1', '', 'par_1'), v1});
m = bodyWithId(out, 'par_1');
calc = bodyWithId(out, 'resp_c3');
r = did2.convert.roundtrip.check(v1, {m, calc});
verifyRoundTrip(testCase, r, 'parameters as a method, with its response', {});
verifyTrue(testCase, any(strcmp([ ...
    'stimulus_response_scalar_parameters_basic.freq_response'], r.matched)));
end

function testANamedParametersDocumentKeepsItsNameOnTheMethod(testCase)
% [v1 name goes to the class's own name field] (Decided by Jess Haley,
% 2026-10-27, did-schema V_eta_go_forward_class_audit.md): a non-empty v1
% base.name is written to `method.name`, and the round trip rebuilds base.name
% from it (the writer sets none; this is a hand-named document)
v1 = writerParameters('par_n', 1);
v1.base.name = 'my response settings';
out = runFold(testCase, {convertibleResponse('resp_cn', 'F1', '', 'par_n'), v1});
m = bodyWithId(out, 'par_n');
assertEqual(testCase, classNameOfBody(m), 'method');
verifyEqual(testCase, char(m.method.name), 'my response settings');
calc = bodyWithId(out, 'resp_cn');
r = did2.convert.roundtrip.check(v1, {m, calc});
verifyRoundTrip(testCase, r, 'named parameters as a method', {});
verifyTrue(testCase, any(strcmp('base.name', r.matched)), 'base.name is rebuilt');
end

% ===================== the round trip can fail ===========================

function testAChangedResponseValueIsReportedLost(testCase)
v1 = convertibleResponse('resp_c4', 'F2', '');
out = runRaw(v1);
v1b = v1;
v1b.stimulus_response_scalar.responses.response_real(2) = 99;
r = did2.convert.roundtrip.check(v1b, out.migrated);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'stimulus_response_scalar.responses.response_real'});
end

function testAFieldOutsideTheTemplateIsReportedLost(testCase)
% the fold reads the template's fields only; one more is dropped, and the
% round trip names it (behaviour unchanged: the renamed path dropped it too)
v1 = convertibleResponse('resp_c5', 'mean', '');
v1.stimulus_response_scalar.peak_latency = 0.12;
out = runRaw(v1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp('stimulus_response_scalar.peak_latency', {r.lost.path})));
end

function testADroppedCalculationIsUnplaced(testCase)
v1 = convertibleResponse('resp_c6', 'mean', '');
out = runRaw(v1);
kept = {};
for k = 1:numel(out.migrated)
    if ~strcmp(out.migrated{k}.className(), 'calculation')
        kept{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
r = did2.convert.roundtrip.check(v1, kept);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

function testAnExtraDocumentIsUnplaced(testCase)
v1 = convertibleResponse('resp_c7', 'mean', '');
out = runRaw(v1);
other = runRaw(convertibleResponse('resp_c8', 'F1', '')).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, other(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

function testAChangedKnobIsReportedLost(testCase)
v1 = writerParameters('par_2', 2);
out = runFold(testCase, {v1});
m = bodyWithId(out, 'par_2');
v1b = v1;
v1b.stimulus_response_scalar_parameters_basic.spiketrain_dt = 0.002;
r = did2.convert.roundtrip.check(v1b, {m});
verifyTrue(testCase, any(strcmp( ...
    'stimulus_response_scalar_parameters_basic.spiketrain_dt', {r.lost.path})));
end

% ===================== what universalRenames would discard ===============

function testADependencyVersionIsCarriedOnBothPaths(testCase)
% the older {name, value, version} entry: the renamed path discarded
% `version` and carried the document (carry-049); the raw path carries it too
v1 = convertibleResponse('resp_v', 'F1', '');
deps = num2cell(v1.depends_on);
for k = 1:numel(deps)
    deps{k}.version = '';
end
deps{1}.version = 2;
v1.depends_on = [deps{:}];
v1 = jsondecode(jsonencode(v1));
raw = runRaw(v1);
old = runRenamed(v1);
verifyEqual(testCase, numel(raw.passthrough), 1, 'raw: carried');
verifyEqual(testCase, numel(old.passthrough), 1, 'renamed: carried');
d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-100] '), d);
emitted = raw.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
end

function testAConflictingKnobSpellingIsCarriedOnBothPaths(testCase)
v1 = writerParameters('par_c', 1);
v1.stimulus_response_scalar_parameters_basic.freqResponse = 2;
raw = runRaw(v1);
old = runRenamed(v1);
verifyEqual(testCase, numel(raw.passthrough), 1);
verifyEqual(testCase, numel(old.passthrough), 1);
verifyEqual(testCase, raw.migrated{1}.get('document_class.schema_version'), 'did_v1');
verifyEqual(testCase, old.migrated{1}.get('document_class.schema_version'), 'did_v1');
end

% ===================== the switch changes no outcome ======================

function testTheSwitchChangesNoOutcome(testCase)
% "keep behaviour identical": a converted document is the one the renamed
% path converted (ids are deterministic, practice (b)); a carry is carried on
% both paths, the raw one the untouched v1 source; the parameters passthrough
% is the same document on both paths, before and after the batch pass
fixtures = {writerResponse('resp_m', 'mean', 6), writerResponse('resp_one', 'F1', 1), ...
    convertibleResponse('resp_c1', 'F1', ''), convertibleResponse('resp_c9', 'mean', '', ''), ...
    writerParameters('par_0', 0), writerParameters('par_2', 2)};
for k = 1:numel(fixtures)
    v1 = fixtures{k};
    raw = runRaw(v1);
    old = runRenamed(v1);
    label = sprintf('fixture %d (%s %s)', k, v1.document_class.class_name, v1.base.id);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), [label ': passed through on one path only']);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    if ~isempty(raw.passthrough) && strcmp(raw.migrated{1}.get('document_class.schema_version'), 'did_v1')
        verifyEqual(testCase, old.migrated{1}.get('document_class.schema_version'), 'did_v1', label);
        continue;   % both carry; the raw carry is the v1 source (tested above)
    end
    if ~isempty(raw.passthrough) && strcmp(classNameOfBody(raw.migrated{1}.toStruct()), ...
            'stimulus_response_scalar')
        % handed on (the epoch gate) on both paths: the raw one keeps v1's
        % `value` edge key where the renamed one had `document_id`, and
        % states the same edges
        a = raw.migrated{1}.toStruct();
        b = old.migrated{1}.toStruct();
        verifyEqual(testCase, edgeMap(a), edgeMap(b), label);
        verifyTrue(testCase, isequaln(rmfield(a, 'depends_on'), rmfield(b, 'depends_on')), label);
        continue;
    end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        a = raw.migrated{j}.toStruct();
        b = old.migrated{j}.toStruct();
        verifyTrue(testCase, isequaln(a, b), sprintf('%s, document %d: raw %s; renamed %s', ...
            label, j, jsonencode(a), jsonencode(b)));
    end
end
% after the batch pass: the same method from either path
p = writerParameters('par_1', 1);
r = convertibleResponse('resp_c3', 'F1', '', 'par_1');
a = did2.convert.resolveResponseParameters(runRaw({r, p}), 'Validate', false, 'TargetVersion', 'did_v2');
b = did2.convert.resolveResponseParameters(runRenamed({r, p}), 'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, numel(a.migrated), numel(b.migrated));
for j = 1:min(numel(a.migrated), numel(b.migrated))
    verifyTrue(testCase, isequaln(a.migrated{j}.toStruct(), b.migrated{j}.toStruct()), ...
        sprintf('after the batch pass, document %d differs', j));
end
verifyEqual(testCase, a.response_parameters_fold, b.response_parameters_fold);
end

function testAnUnreadableResponseIsCarriedOnBothPaths(testCase)
% a response the fold cannot read (an unknown response_type) is carried whole
% as v1, kind malformed, on both paths (Decided by Jess Haley, 2026-10-27
% [unreadable responses are malformed]; it was handed back unconverted with
% no note before)
v1 = convertibleResponse('resp_p', 'peak', '');
raw = runRaw(v1);
old = runRenamed(v1);
verifyEqual(testCase, numel(raw.passthrough), 1);
verifyEqual(testCase, numel(old.passthrough), 1);
verifyEqual(testCase, raw.migrated{1}.get('document_class.schema_version'), 'did_v1');
verifyEqual(testCase, old.migrated{1}.get('document_class.schema_version'), 'did_v1');
d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-100] malformed: '), d);
r = did2.convert.roundtrip.check(v1, raw.migrated);
verifyTrue(testCase, r.carried);
verifyRoundTrip(testCase, r, 'unreadable response', {});
end

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end

function out = runRenamed(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2', ...
    'RawV1Classes', {});
end

function out = runFold(testCase, bodies)
out = runRaw(bodies);
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
out = did2.convert.resolveResponseParameters(out, 'Validate', false, 'TargetVersion', 'did_v2');
end

function b = bodyWithId(out, id)
b = struct();
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), id)
        b = out.migrated{k}.toStruct();
        return;
    end
end
end

function name = classNameOfBody(b)
name = '';
if isfield(b, 'document_class') && isfield(b.document_class, 'class_name')
    name = char(b.document_class.class_name);
end
end

function m = edgeMap(b)
% name -> id, whichever key holds it
m = struct();
if ~isfield(b, 'depends_on'); return; end
d = b.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    e = d{k};
    v = '';
    for key = {'document_id', 'value', 'id'}
        if isfield(e, key{1}) && ~isempty(e.(key{1}))
            v = char(e.(key{1}));
            break;
        end
    end
    m.(matlab.lang.makeValidName(char(e.name))) = v;
end
end

function verifyRoundTrip(testCase, r, label, expectedLost)
verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
lost = reshape(sort({r.lost.path}), 1, []);
verifyEqual(testCase, lost, reshape(sort(expectedLost), 1, []), ...
    sprintf('%s: lost paths are not the listed findings; lost: %s', label, describeLost(r)));
verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end

function s = describeLost(r)
parts = cell(1, numel(r.lost));
for k = 1:numel(r.lost)
    parts{k} = sprintf('%s (v1 %s, rebuilt %s)', r.lost(k).path, ...
        show(r.lost(k).v1), show(r.lost(k).rebuilt));
end
s = strjoin(parts, '; ');
if isempty(s); s = '(none)'; end
end

function s = show(v)
try
    s = jsonencode(v);
catch
    s = class(v);
end
end

function v1 = writerResponse(id, responseType, nReadings, paramId)
% tuning_response.m compute_stimulus_response_scalar: the template merge,
% then set_dependency_value for all five edges, both epoch strings
if nargin < 4; paramId = 'par_x'; end
tpl = loadTemplate('stimulus_response_scalar');
srTpl = loadTemplate('stimulus_response');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
deps = [reshape(tpl.depends_on, [], 1); reshape(srTpl.depends_on, [], 1)];
[~, ix] = unique({deps.name});   % ndi.document.readblankdefinition
deps = reshape(deps(ix), 1, []);
values = struct('element_id', 'el_unit_1', 'stimulator_id', 'el_stim_1', ...
    'stimulus_control_id', 'ctl_1', 'stimulus_presentation_id', 'pres_1', ...
    'stimulus_response_scalar_parameters_id', paramId);
for k = 1:numel(deps)
    deps(k).value = values.(deps(k).name);
end
v1.depends_on = deps;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.stimulus_response = srTpl.stimulus_response;
v1.stimulus_response.stimulator_epochid = 't00003';
v1.stimulus_response.element_epochid = 't00003';
v1.stimulus_response_scalar = tpl.stimulus_response_scalar;
v1.stimulus_response_scalar.response_type = responseType;
stimid = repmat(1:3, 1, ceil(nReadings / 3));
stimid = stimid(1:nReadings);
r = struct();
r.stimid = stimid;
r.response_real = 2.5 + (1:nReadings) * 1.25;
r.response_imaginary = zeros(1, nReadings);
if ~strcmp(responseType, 'mean')
    r.response_imaginary = -0.5 + (1:nReadings) * 0.25;
end
r.control_response_real = repmat(0.75, 1, nReadings);
r.control_response_imaginary = zeros(1, nReadings);
v1.stimulus_response_scalar.responses = r;
v1 = jsondecode(jsonencode(v1));
end

function v1 = convertibleResponse(id, responseType, elementEpoch, paramId)
% the writer shape on another epoch string (the stimulator's the same: it is
% rebuilt from the element's, [response links: epoch rebuilt, control as
% input], Jess Haley, 2026-10-27) and no control (the template blank)
if nargin < 4; paramId = 'par_x'; end
v1 = writerResponse(id, responseType, 6, paramId);
v1.stimulus_response.stimulator_epochid = elementEpoch;
v1.stimulus_response.element_epochid = elementEpoch;
v1.depends_on(strcmp({v1.depends_on.name}, 'stimulus_control_id')).value = '';
v1 = jsondecode(jsonencode(v1));
end

function v1 = writerParameters(id, freqResponse)
% tuning_response.m: var2struct of the six knobs, a spike train's isspike 1
tpl = loadTemplate('stimulus_response_scalar_parameters_basic');
parentTpl = loadTemplate('stimulus_response_scalar_parameters');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.stimulus_response_scalar_parameters = parentTpl.stimulus_response_scalar_parameters;
v1.stimulus_response_scalar_parameters_basic = struct( ...
    'temporalfreqfunc', 'ndi.fun.stimulustemporalfrequency', ...
    'freq_response', freqResponse, 'prestimulus_time', [], ...
    'prestimulus_normalization', [], 'isspike', 1, 'spiketrain_dt', 0.001);
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
