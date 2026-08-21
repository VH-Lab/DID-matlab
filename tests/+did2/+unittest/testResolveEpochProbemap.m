function tests = testResolveEpochProbemap
%TESTRESOLVEEPOCHPROBEMAP The #66 increment-1 epochprobemap OBSERVATION fold.
%
%   STATUS: WRITTEN 2026-08-21, NEVER EXECUTED HERE. This container has no MATLAB
%   -- `command -v matlab octave octave-cli` prints nothing -- so not one line
%   below has been run; the quick gate (test-migrators-quick.yml) is the first
%   thing that will have an opinion about it.
%
%   WHAT IS UNDER TEST: did2.convert.resolveEpochProbemap decomposes an ingested
%   epoch's serialized `epochprobemap` into one epoch-scoped
%   `<modality>_observation` per probe row, anchored to the minted `epoch`
%   document via a shared 'during' relative_reference, and RETIRES #30's coarse
%   session-scoped observation for a probe when EXACTLY ONE such observation
%   names it.
%
%   THE FIXTURES ARE BUILT FROM THE WRITER, never from a DID-side schema (the
%   ground-truth rule): the probemap string is the exact tab-delimited shape NDI
%   origin/main +ndi/+epoch/epochprobemap_daqsystem.serialize() emits, and the
%   element / subject / ingested / session bodies reproduce the NDI templates the
%   recording-observation and epoch-mint tests already drive. Shapes are copied
%   from testEpochProbemapMeasurement.m so the two cannot drift.
%
%   THE CHAIN IS THE REAL ONE: v1_to_v2 -> epochMint -> resolveSessionAnchors ->
%   resolveEpochProbemap, in the order the corpus harness composes it. epochMint
%   mints the `epoch` documents this pass anchors to; resolveSessionAnchors folds
%   the #30 observations' session anchors first, exactly as in production.

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function [out, rep] = decompose(v1)
%DECOMPOSE Pass 1, then the batch chain up to and including this pass. Validation
%   is ON from resolveSessionAnchors onward so the minted observations and
%   anchors are checked against the real V_eta schema.
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.resolveSessionAnchors(out, 'Validate', true, ...
    'TargetVersion', 'V_eta');
[out, rep] = did2.convert.resolveEpochProbemap(out, 'Validate', true, ...
    'TargetVersion', 'V_eta');
end

% ===================== the headline decomposition =====================

function testTwoObservationsMintedOneRowRefusedAndTheHash30ObsRetired(testCase)
% The primary scenario, all in one batch:
%   row 1  tet/1/n-trode/L   -> voltage_observation, subject_id = specimen,
%                              instrument_id = the element-subject 'el_1'
%                              (RESOLVED via local_identifier 'tet (ref 1)'),
%                              and it RETIRES the #30 obs that names el_1.
%   row 2  tet/2/n-trode/L   -> voltage_observation, subject_id = specimen,
%                              instrument_id OMITTED (no 'tet (ref 2)' subject).
%   row 3  tet/3/n-trode/x   -> subjectstring 'x@lab' resolves to no subject:
%                              REFUSED, no observation.
subj = subjectBody('specimen_1', 'sess_1', 'L');
el   = elementBody('el_1', 'sess_1', 'tet', '1', 'n-trode', 1, 'specimen_1');
ing  = ingestedWithRows('ing_1', 'sess_1', 't00001', { ...
    {'tet', '1', 'n-trode', 'L'}, ...
    {'tet', '2', 'n-trode', 'L'}, ...
    {'tet', '3', 'n-trode', 'x@lab'}});
[out, rep] = decompose({sessionBody('sd_1', 'sess_1', 'ref'), subj, el, ing});

% --- the report -----------------------------------------------------------
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.epochfiles_ingested_seen, 1);
verifyEqual(testCase, rep.refused_no_epoch, 0);
verifyEqual(testCase, rep.probe_rows_total, 3);
verifyEqual(testCase, rep.rows_no_subjectstring, 0);
verifyEqual(testCase, rep.refused_no_subject, 1);
verifyEqual(testCase, rep.rows_unresolved_modality, 0);
verifyEqual(testCase, rep.rows_stimulator, 0);
verifyEqual(testCase, rep.observations_emitted, 2);
verifyEqual(testCase, rep.instrument_resolved, 1);
verifyEqual(testCase, rep.instrument_omitted, 1);
verifyEqual(testCase, rep.epoch_anchors_minted, 1);
verifyEqual(testCase, rep.session30_observations_retired, 1);
verifyEqual(testCase, rep.retire_skipped_ambiguous, 0);
verifyEqual(testCase, rep.fold_quarantined, 0);

% --- THE ROW PARTITION reconciles: probe_rows_total = emitted + refused +
%     unresolved. Single-modality rows, so observations == emitting rows.
refused = rep.rows_no_subjectstring + rep.refused_no_subject;
unresolved = rep.rows_unresolved_modality + rep.rows_stimulator;
verifyEqual(testCase, rep.probe_rows_total, ...
    rep.observations_emitted + refused + unresolved);

% --- exactly two migrated_probemap_observation documents ------------------
obs = bodiesNamed(out, 'migrated_probemap_observation');
verifyEqual(testCase, numel(obs), 2);

% both are voltage_observations of the specimen, anchored to the same epoch
% 'during' anchor.
anchorIds = {};
withInstrument = 0;
for i = 1:numel(obs)
    b = obs{i};
    verifyEqual(testCase, char(b.document_class.class_name), 'voltage_observation');
    verifyEqual(testCase, depVal(b, 'subject_id'), 'specimen_1');
    tr = depVal(b, 'time_reference_1');
    verifyNotEmpty(testCase, tr);
    anchorIds{end+1} = tr; %#ok<AGROW>
    inst = depVal(b, 'instrument_id');
    if ~isempty(inst)
        verifyEqual(testCase, inst, 'el_1');   % the RESOLVED probe-subject
        withInstrument = withInstrument + 1;
    end
end
verifyEqual(testCase, withInstrument, 1);
% one shared anchor across both observations
verifyEqual(testCase, numel(unique(anchorIds)), 1);

% --- the shared anchor is an epoch-scoped 'during' relative_reference ------
anchors = bodiesNamed(out, 'migrated_probemap_epoch_anchor');
verifyEqual(testCase, numel(anchors), 1);
a = anchors{1};
verifyEqual(testCase, char(a.document_class.class_name), 'relative_reference');
verifyEqual(testCase, a.base.id, anchorIds{1});
verifyEqual(testCase, char(a.relative_reference.value.relation.name), 'intervalDuring');
% its relative_to is the minted epoch document
epochs = bodiesOfClass(out, 'epoch');
verifyEqual(testCase, numel(epochs), 1);
verifyEqual(testCase, depVal(a, 'relative_to'), epochs{1}.base.id);

% --- the #30 observation for el_1 is RETIRED ------------------------------
% element.m emits a voltage_observation (base.name migrated_recording_observation)
% with instrument_id el_1; resolveEpochProbemap replaces it, so it is gone.
recObs = bodiesNamed(out, 'migrated_recording_observation');
for i = 1:numel(recObs)
    verifyNotEqual(testCase, depVal(recObs{i}, 'instrument_id'), 'el_1');
end
verifyEqual(testCase, numel(recObs), 0);   % el_1 was the only direct element
end

% ===================== retirement is conservative =====================

function testAPatchElementWithTwoHash30ObsIsNotRetired(testCase)
% A `patch` element emits TWO #30 observations (voltage + current), both with
% instrument_id el_2. >1 match is AMBIGUOUS, so the #30 observations are KEPT
% rather than risk stranding one -- counted retire_skipped_ambiguous.
subj = subjectBody('specimen_2', 'sess_2', 'L');
el   = elementBody('el_2', 'sess_2', 'pat', '1', 'patch', 1, 'specimen_2');
ing  = ingestedWithRows('ing_2', 'sess_2', 't00002', { ...
    {'pat', '1', 'patch', 'L'}});
[out, rep] = decompose({sessionBody('sd_2', 'sess_2', 'ref'), subj, el, ing});

% one patch row -> two observations (voltage + current)
verifyEqual(testCase, rep.observations_emitted, 2);
verifyEqual(testCase, rep.session30_observations_retired, 0);
verifyEqual(testCase, rep.retire_skipped_ambiguous, 1);
% the two #30 observations for el_2 SURVIVE
recObs = bodiesNamed(out, 'migrated_recording_observation');
verifyEqual(testCase, numel(recObs), 2);
end

% ===================== an unresolvable subject emits nothing ===========

function testAnUnresolvableSubjectstringEmitsNoObservation(testCase)
% subject_id is the ONE required edge; a row whose subjectstring matches no
% subject document emits NOTHING (never an empty required edge) and is counted.
el  = elementBody('el_3', 'sess_3', 'tet', '1', 'n-trode', 1, 'specimen_3');
ing = ingestedWithRows('ing_3', 'sess_3', 't00003', { ...
    {'tet', '1', 'n-trode', 'nobody@lab'}});
% NB: no subject document for specimen_3's local id, so the row cannot resolve.
[out, rep] = decompose({sessionBody('sd_3', 'sess_3', 'ref'), el, ing});
verifyEqual(testCase, rep.probe_rows_total, 1);
verifyEqual(testCase, rep.refused_no_subject, 1);
verifyEqual(testCase, rep.observations_emitted, 0);
verifyEmpty(testCase, bodiesNamed(out, 'migrated_probemap_observation'));
% nothing minted -> no epoch anchor either
verifyEqual(testCase, rep.epoch_anchors_minted, 0);
end

% ===================== an empty subjectstring column ===================

function testAnEmptySubjectstringIsCountedApart(testCase)
% An empty subjectstring column is a DIFFERENT refusal from a present-but-
% unresolvable one, and must not be summed with it.
subj = subjectBody('specimen_4', 'sess_4', 'L');
el   = elementBody('el_4', 'sess_4', 'tet', '1', 'n-trode', 1, 'specimen_4');
ing  = ingestedWithRows('ing_4', 'sess_4', 't00004', { ...
    {'tet', '1', 'n-trode', ''}, ...
    {'tet', '2', 'n-trode', 'L'}});
[~, rep] = decompose({sessionBody('sd_4', 'sess_4', 'ref'), subj, el, ing});
verifyEqual(testCase, rep.probe_rows_total, 2);
verifyEqual(testCase, rep.rows_no_subjectstring, 1);
verifyEqual(testCase, rep.refused_no_subject, 0);
verifyEqual(testCase, rep.observations_emitted, 1);
end

% ===================== modality rows resolve ==========================

function testModalityRowsResolveToTheRightObservationLeaf(testCase)
% One row per modality family that yields a single observation, all resolvable to
% the same specimen. Asserts localModality maps each type to the leaf
% jRecordingModality maps it to -- the pin that keeps the duplicated map honest.
%
% IMAGING IS DEFERRED, NOT EMITTED, IN INCREMENT 1. `image.value` is
% mustBeNonEmpty, and a probemap row carries no raster metadata, so a
% pure-reference image cell is all-blank and the #38 NonVacuousFields gate (armed
% by default) refuses it -- inventing a dtype to satisfy it is the guess R6/#30
% forbid. So the two-photon-imaging row is COUNTED (rows_image_deferred) and emits
% nothing; the other SIX rows emit. This is the pass recognising a modality it
% cannot honestly express yet, not a validation bug -- see resolveEpochProbemap's
% localModality IMAGE IS DEFERRED note. jRecordingObservation carries the same
% latent blank-image shape but never validates it (its tests run Validate=false).
subj = subjectBody('spec_m', 'sess_m', 'L');
ing  = ingestedWithRows('ing_m', 'sess_m', 't0m', { ...
    {'a', '', 'n-trode',              'L'}, ...   % voltage
    {'b', '', 'patch-i',              'L'}, ...   % current
    {'c', '', 'two-photon-imaging',   'L'}, ...   % image (DEFERRED, not emitted)
    {'d', '', 'spikes',               'L'}, ...   % time
    {'e', '', 'accelerometer',        'L'}, ...   % acceleration
    {'f', '', 'thermometer',          'L'}, ...   % temperature
    {'g', '', 'extracellular_electrode-4', 'L'}}); % voltage (electrode stem)
[out, rep] = decompose({sessionBody('sd_m', 'sess_m', 'ref'), subj, ing});
verifyEqual(testCase, rep.probe_rows_total, 7);
verifyEqual(testCase, rep.observations_emitted, 6);
verifyEqual(testCase, rep.rows_image_deferred, 1);
verifyEqual(testCase, rep.rows_unresolved_modality, 0);

got = sort(cellfun(@(b) char(b.document_class.class_name), ...
    bodiesNamed(out, 'migrated_probemap_observation'), 'UniformOutput', false));
want = sort({'voltage_observation', 'current_observation', ...
    'time_observation', 'acceleration_observation', 'temperature_observation', ...
    'voltage_observation'});
verifyEqual(testCase, got, want);
end

function testStimulatorAndUnresolvedRowsEmitNothing(testCase)
% A stimulator type is the OTHER direction (a manipulation, not an observation);
% an unmapped type is Guard A. Both emit nothing here, and are counted apart.
subj = subjectBody('spec_s', 'sess_s', 'L');
ing  = ingestedWithRows('ing_s', 'sess_s', 't0s', { ...
    {'stim', '', 'stimulator', 'L'}, ...
    {'lick', '', 'lick-spout', 'L'}});
[out, rep] = decompose({sessionBody('sd_s', 'sess_s', 'ref'), subj, ing});
verifyEqual(testCase, rep.probe_rows_total, 2);
verifyEqual(testCase, rep.rows_stimulator, 1);
verifyEqual(testCase, rep.rows_unresolved_modality, 1);
verifyEqual(testCase, rep.observations_emitted, 0);
verifyEmpty(testCase, bodiesNamed(out, 'migrated_probemap_observation'));
end

% ===================== no epoch document ==============================

function testAnIngestedDocWithNoMintedEpochIsRefused(testCase)
% If no `epoch` document exists for the ingested epoch (e.g. no session document,
% so epochMint refused to mint one), the whole ingested document is refused and
% nothing is emitted -- the anchor's required `relative_to` would have nowhere to
% point.
subj = subjectBody('spec_n', 'sess_n', 'L');
el   = elementBody('el_n', 'sess_n', 'tet', '1', 'n-trode', 1, 'spec_n');
ing  = ingestedWithRows('ing_n', 'sess_n', 't0n', {{'tet', '1', 'n-trode', 'L'}});
% NO session document -> epochMint mints no epoch for (sess_n, t0n).
[out, rep] = decompose({subj, el, ing});
verifyEqual(testCase, rep.epochfiles_ingested_seen, 1);
verifyEqual(testCase, rep.refused_no_epoch, 1);
verifyEqual(testCase, rep.observations_emitted, 0);
verifyEmpty(testCase, bodiesNamed(out, 'migrated_probemap_observation'));
end

% ===================== fixtures, from the NDI writer ===================

function v1 = ingestedWithRows(docId, sessionId, epochId, rows)
%INGESTEDWITHROWS A did_v1 epochfiles_ingested whose epochprobemap serialises the
%   given rows, each {name, reference, type, subjectstring}. devicestring is a
%   constant filler -- this pass does not read it. Exact serialize() shape.
pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n');
for i = 1:numel(rows)
    r = rows{i};
    pm = [pm, sprintf('%s\t%s\t%s\tvhspike2:ai11-14\t%s\n', ...
        r{1}, r{2}, r{3}, r{4})]; %#ok<AGROW>
end
v1 = ingestedRaw(docId, sessionId, epochId, pm);
end

function v1 = ingestedRaw(docId, sessionId, epochId, probemapValue)
%INGESTEDRAW A did_v1 epochfiles_ingested. Block key set {epoch_id, epochprobemap,
%   files}, dependency {filenavigator_id}, exactly as corpus B's documents carry.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name',         'epochfiles_ingested', ...
    'property_list_name', 'epochfiles_ingested', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', 'nav_1');
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
blk = struct();
blk.epoch_id = epochId;
blk.files = {['epochid://' epochId]};
blk.epochprobemap = probemapValue;
v1.epochfiles_ingested = blk;
end

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 session document. base.id and base.session_id are DIFFERENT
%   strings, as ndi.document / ndi.session mint them.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/session.json', ...
    'validation',         '$NDISCHEMAPATH/session.json', ...
    'class_name',         'session', ...
    'property_list_name', 'session', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', reference);
end

function el = elementBody(docId, sessionId, name, reference, typ, direct, subjectId)
%ELEMENTBODY A did_v1 element. A DIRECT element drives jRecordingObservation to a
%   #30 recording observation of the SPECIMEN, with instrument_id = docId (the
%   element-subject, id preserved). Its subject local_identifier becomes
%   'name (ref reference)', which is the join key a probemap row reconstructs.
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
el.depends_on = struct('name', {'subject_id'}, 'value', {subjectId});
el.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
    'name', name, 'reference', reference, 'type', typ, 'direct', direct);
end

function v1 = subjectBody(docId, sessionId, localId)
%SUBJECTBODY A did_v1 subject carrying a local_identifier the subject migrator
%   preserves. The SPECIMEN a probemap subjectstring is joined against.
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', localId, 'description', '');
end

% ===================== helpers ============================================

function out = bodiesNamed(result, baseName)
%BODIESNAMED Migrated bodies (as structs) whose base.name == BASENAME.
out = {};
for k = 1:numel(result.migrated)
    b = result.migrated{k}.toStruct();
    if isfield(b, 'base') && isfield(b.base, 'name') ...
            && strcmp(char(b.base.name), baseName)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function out = bodiesOfClass(result, className)
%BODIESOFCLASS Migrated bodies (as structs) of document_class className.
out = {};
for k = 1:numel(result.migrated)
    b = result.migrated{k}.toStruct();
    if isfield(b, 'document_class') && isfield(b.document_class, 'class_name') ...
            && strcmp(char(b.document_class.class_name), className)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function v = depVal(b, name)
%DEPVAL Value of one depends_on entry on a body STRUCT, '' when absent/empty.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps); items = deps(:)';
elseif isstruct(deps); items = num2cell(deps(:)');
else; return; end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value); v = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); end
    return;
end
end
