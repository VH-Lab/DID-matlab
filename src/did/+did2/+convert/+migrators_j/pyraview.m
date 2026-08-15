function bodies = pyraview(preBody)
%PYRAVIEW Brainstorm-J migrator: did_v1 pyraview -> a body-backed
%   voltage_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THIS HEADER SAID `dataseries_observation` IN THREE PLACES UNTIL 2026-08-13
%   AND THE CODE HAS EMITTED `voltage_observation` THROUGHOUT. Team, 2026-08-13:
%   "There is no dataseries_observation anymore. Voltage is correct." The CODE
%   was right; the header named a class that does not exist:
%
%     DENOMINATOR: 248 json file(s) under DID-schema schemas/V_eta/
%       dataseries_observation    NOT IN THE BUILT SET
%       imageseries_observation   NOT IN THE BUILT SET
%       timeseries_observation    NOT IN THE BUILT SET
%       voltage_observation       stable/voltage_observation.json  (stable)
%
%   The three series-observation classes were phase-8 DELETED -- abstract and
%   unminted in J, so no document can be an instance of one. A reader trusting
%   the old title would have gone looking for a schema that was removed, and
%   `confirm_sheet.py` rendered the mismatch to the team as an open question
%   about which of the two was intended. It was never a question about the
%   model; it was a docstring outliving a deletion.
%   pyraview is a multi-resolution PYRAMID view of a sampled signal (level1..10.bin
%   decimation levels + native_rate/channels/data_type), tied to a subject via
%   element_id. In J it dissolves into the data_body model (2.D), exactly like the
%   image_stack fold:
%
%       voltage_observation the discoverable spine handle: subject_id, a shared
%                           time anchor, a placeholder subject_statement.variable
%                           (the signal `label`), and storage_mode 'body' (the
%                           cadence lives in the body, D1).
%       sampled_body        the NATIVE-resolution signal: datum (kind/dtype/shape)
%                           + sample_time (t0 = native_start_time, dt = 1/native_rate)
%                           + the carried bytes; statement -> the observation.
%       session_relative_reference   the ordinal 'during' anchor (a pyraview has no
%                           DAQ epoch -- the honest fallback the treatment/image
%                           folds use).
%
%   1 -> (2 + N): the observation, ONE sampled_body per stored resolution level
%   (all sharing the statement -- the multi-body stream sampled_body was designed
%   for; levels told apart by sample_time.dt), and the anchor. Each level keeps its
%   own bytes (a pyramid is a precomputed performance cache, not a disposable
%   thumbnail), so nothing is dropped.
%
%   ---------------------------------------------------------------------
%   + THE `filter` BLOCK, WHICH THIS FOLD USED TO DISCARD ENTIRELY
%   ---------------------------------------------------------------------
%   `pyraview` declares `data/filter.json` as a superclass, and it is the ONLY
%   class in NDI that does (git grep for the definition path on origin/main
%   returns filter.json itself and pyraview.json, nothing else). Until now this
%   migrator built every output body from scratch and never read that block, so
%   the filter specification was dropped on the floor -- silently, because a
%   dropped superclass block is invisible to every Phase-1 counter.
%
%   It is NOT incidental metadata. The real PRED document is a 4th-order
%   Chebyshev-I high-pass at 300 Hz: 300-Hz-high-passed voltage is a DIFFERENT
%   QUANTITY from raw voltage, so the filter is part of what the stored numbers
%   mean (V_eta_frequency_filter_model_plan.md, signed 2026-07-30).
%
%   So the fold now also emits ONE `frequency_filter` document and points every
%   level body at it via `sampled_body.filter_id` (declared optional there,
%   must_refer_to_document_class frequency_filter). The filter rides on the
%   BODIES rather than the observation because that is where the schema puts the
%   edge, and because it describes the samples. When the block names no
%   representable filter -- an all-pass, or a vocabulary v1 has never used --
%   `jFrequencyFilter` returns nothing and no `filter_id` is written, so the
%   output is exactly what it was before.
%
%   NOTE ON MATURITY, RE-DERIVED 2026-08-13 RATHER THAN CARRIED FORWARD. This
%   read "dataseries_observation and the *_body classes are `draft`", and half
%   of it was wrong in each direction -- it named a class that no longer exists,
%   and it grouped the observation with the bodies when they now differ:
%
%       voltage_observation   stable      frequency_filter         stable
%       sampled_body          DRAFT       epoch_bounded_reference  stable
%       opaque_body           DRAFT
%
%   So the only draft classes this fold touches are the two data bodies. That is
%   the pattern-setter for the #9 analysis-tier folds (mint observation + attach
%   sampled_body), and pyraview stays in the schema until this is corpus-proven.

arguments
    preBody (1,1) struct
end

TV  = 'V_eta';
blk = getBlock(preBody, 'pyraview');

subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
sessionId = baseField(preBody, 'session_id', '');
datestamp = baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z');
obsId     = baseField(preBody, 'id', did.ido.unique_id());

label    = getCharField(blk, 'label');
dataType = getCharField(blk, 'data_type');
channels = getField(blk, 'channels');
t0       = numScalar(getField(blk, 'native_start_time'), 0.0);
nativeRt = numScalar(getField(blk, 'native_rate'), 0.0);
% NO top-level `dt`. It was computed here and never read: the per-level loop
% below derives `dt_k` from `rate_k`, which starts at `nativeRt` and is
% overridden by `decimation_sampling_rates(k)` when the level has its own rate.
% So nothing was lost -- but a dead variable named `dt` sitting beside a live
% `dt_k` is an invitation to "simplify" the loop into using it, which would
% silently give every decimated level the NATIVE sample interval. Removed rather
% than left as a trap. (GitHub code scanning 167/168 flagged it; verified by
% reading the loop, not assumed.)

anchorId = did.ido.unique_id();

% ---- the frequency_filter split off the inherited `filter` block ------------
% [] when the block is absent, describes an all-pass ('none'), or uses a
% vocabulary this model cannot represent. In that case no document is emitted
% and no filter_id edge is written -- never a guessed design.
filterDoc = jFrequencyFilter(preBody);
filterId = '';
if ~isempty(filterDoc)
    filterId = filterDoc.base.id;
end

% ---- the session-relative time anchor ('during') ----------------------------
anchor = struct();
% PASS-1 HANDLE, NOT AN UNMIGRATED CLASS. The signed model retires this class in
% favour of `relative_reference`, but the same plan makes the change impossible
% here: `relative_to` is REQUIRED and is not fillable in pass 1 (this body holds
% base.session_id; the edge needs the session DOCUMENT's base.id). Emitting the
% new class with an empty required edge would be ~106k husks that validate clean.
% did2.convert.resolveSessionAnchors folds it in a batch pass, id PRESERVED. Full
% reasoning in +migrators_j/private/jSessionAnchor.m; the seam is pinned by
% tests/+did2/+unittest/testSessionAnchorEmitterContract.m.
anchor.document_class = classBlock('session_relative_reference', {'time_reference'}, TV);
anchor.depends_on = struct('name', {}, 'value', {});   % session rides on base
anchor.base = struct('id', anchorId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', datestamp);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', 'during');

% ---- the EPOCH HANDLE: identity + clock, for the batch passes ---------------
% WITHOUT THIS, PYRAVIEW'S EPOCH DISAPPEARS ENTIRELY. `pyraview` is EPOCH-SCOPED
% BY DECLARATION -- NDI's template declares superclasses
% ['epochclocktimes.json', 'filter.json'], and that mixin carries the `epochid`
% block. This migrator read NEITHER, so migration dropped the epoch dimension in
% two pieces: WHICH epoch (`epochid.epochid`) and its EXTENT + CLOCK
% (`epochclocktimes`). In the PRED corpus, pyraview is the ONLY document
% carrying an epoch id, so the whole corpus minted no epoch at all.
%
% `epoch_bounded_reference` is the right carrier and is NOT a new class: it
% already carries the `epochid` mixin AND is a `time_reference`, which is
% exactly the pass-1 HANDLE pattern this pipeline uses for anchors it cannot
% resolve yet (see the session anchor above, and
% did2.convert.resolveSessionAnchors). It is not in the persist set, and does
% not need to be -- a handle is consumed, not kept:
%
%     did2.convert.epochMint      reads `epochid.epochid` off migrated bodies
%                                 and mints one `epoch` per (session, id)
%     ndi.migrate.internal.epochAnchorFold
%                                 folds this handle into a `relative_reference`
%                                 anchored to that epoch, base.id PRESERVED
%
% THE EXTENT IS DELIBERATELY NOT CARRIED HERE. `epoch_bounded_reference` has no
% slot for an interval, and adding one to a class scheduled for deletion was
% considered and REJECTED (team, 2026-08-13). The extent belongs to the EPOCH --
% several documents can share one epoch and would each report the same interval
% -- so epochMint mints it off the epoch's own `time_reference_#`. That half is
% signed and NOT YET BUILT; this commit is the identity half it depends on.
%
% NO EPOCH ID => NO HANDLE. An epoch_bounded_reference with an empty epochid
% names no epoch and is a hollow document; `element_id` is REQUIRED on the class
% and is the same referent the observation uses.
epochStr = getCharField(getBlock(preBody, 'epochid'), 'epochid');
epochClk = getCharField(getBlock(preBody, 'epochclocktimes'), 'clocktype');
epochRefId = '';
if ~isempty(epochStr) && ~isempty(subjectId)
    epochRefId = did.ido.unique_id();
    epochRef = struct();
    epochRef.document_class = classBlock('epoch_bounded_reference', ...
        {'time_reference', 'epochid'}, TV);
    epochRef.depends_on = struct('name', {'element_id'}, 'value', {subjectId});
    epochRef.base = struct('id', epochRefId, 'session_id', sessionId, ...
        'name', 'migrated_epoch_anchor', 'datestamp', datestamp);
    epochRef.time_reference = struct('is_approximate', false);
    epochRef.epochid = struct('epochid', epochStr);
    % `epoch_clock` is mustBeNonEmpty. v1 records it in the epochclocktimes
    % block; NDI's own default for a device-local epoch clock is dev_local_time,
    % and PRED's document says exactly that.
    if isempty(epochClk)
        epochClk = 'dev_local_time';
    end
    epochRef.epoch_bounded_reference = struct('epoch_clock', epochClk);
    % THE EXTENT, in the shape relative_reference uses, so epochAnchorFold's
    % job is a COPY and not a translation (did-schema: the slot is a verbatim
    % deep copy of relative_reference.value). ANCHOR AND EXTENT ARE SEPARATE
    % FACTS -- start + duration, NOT start + end -- which is the signed time
    % model, so t1 is converted here rather than carried raw.
    %
    % NO TIMES => NO VALUE. A NaN or absent interval is a hollow reference,
    % the exact thing silentLoss and isFragment exist to catch, so the block
    % is attached only when both ends are real numbers.
    t0t1 = numVec(getField(getBlock(preBody, 'epochclocktimes'), 't0_t1'));
    if numel(t0t1) >= 2 && all(isfinite(t0t1(1:2)))
        % INSIDE the class block, not at the top level. V_eta puts a class's
        % fields in a property block named after the class, and
        % `epoch_bounded_reference` declares BOTH `epoch_clock` and `value`. A
        % top-level `value` is an undeclared property and quarantines the
        % document -- caught before it ever ran, but only because the fold that
        % consumes it had to be read to see whether it copies this through.
        epochRef.epoch_bounded_reference.value = struct( ...
            'relation', otTerm(''), ...
            'clock',    otTerm(epochClk), ...
            'start',    withSeconds(double(t0t1(1))), ...
            'duration', withSeconds(double(t0t1(2) - t0t1(1))));
    end
end

% ---- the discoverable, body-backed voltage_observation ----------------------
% A pyraview is a decimated view of a continuous recorded signal -> default to the
% voltage_observation quantity leaf (the abstract/collapsed dataseries_observation
% branch is not a valid concrete class). NOTE: the physical quantity is not carried
% on the doc; voltage is the dominant NDI case (ephys), but a non-voltage pyraview
% would need per-signal quantity typing (a discovery/second-pass refinement).
obs = struct();
obs.document_class = classBlock('voltage_observation', {'subject_observation', 'voltage'}, TV);
obs.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
% AND time_reference_2 -> THE EPOCH, when there is one. Without this edge the
% epoch reference emitted above is UNREACHABLE from the observation: the epoch
% identity and extent survive migration, but a reader holding the signal cannot
% get from it to "when did this happen, in the device clock". An emitted
% document nothing points at reads as finished work and is not.
%
% THE FAMILY IS LEGAL BY CONSTRUCTION, not by luck. The uniqueness rule
% (`referent_unique_by`, subject_interaction: time_reference_# discriminated by
% `value.clock`) says members of one family must differ by clock -- and these
% two do: the session anchor names no clock at all, the epoch reference names
% `dev_local_time`. Two members, two distinct clocks.
%
% This is the LINK, not the `epoch_id` edge. That edge is declared by exactly
% four V_eta classes and `voltage_observation` is not one of them, so wiring it
% needs a schema increment and belongs with the epoch family (#60).
if ~isempty(epochRefId)
    obs.depends_on(end+1) = ...
        struct('name', 'time_reference_2', 'value', epochRefId);
end
obs.base = struct('id', obsId, 'session_id', sessionId, ...
    'name', 'migrated_signal', 'datestamp', datestamp);
% storage_mode: body -> the value is in the sampled_body; the statement carries no
% sample_time (the body owns the cadence). variable = the signal label.
% `datum_type` LIVES ON THE STATEMENT (signed sec.5) -- the statement says what
% the values ARE, the body says how the bytes lay out. Normalised through
% jDatumType, which keeps the source spelling when the two differ because the
% map is not invertible ('bool' came from 'logical' OR 'ubit1').
[datumType, sourceDatumType] = jDatumType(dataType);
obs.subject_statement = struct( ...
    'variable', struct('node', '', 'name', firstNonEmpty(label, 'signal')), ...
    'datum_type', datumType, ...
    'source_datum_type', sourceDatumType, ...
    'storage_mode', 'body');
obs.subject_interaction = struct('method', otTerm(''));
obs.subject_observation = struct();
obs.voltage = struct();   % value is body-backed

% ---- one sampled_body per stored resolution level ---------------------------
% Each pyramid level is its own sampled_body, all sharing the statement (the
% observation) -- the multi-body-per-statement stream sampled_body was designed
% for ("append more bodies without rewriting the anchor"). Levels are told apart
% by sample_time.dt (the per-level sampling rate); level 1 is native. Each body
% owns one level_k.bin (files.file_list re-keys the bytes to the minting doc, as
% the image_stack fold does for its single body).
fileList = {};
if isfield(preBody, 'files') && isstruct(preBody.files) ...
        && isfield(preBody.files, 'file_list')
    fileList = preBody.files.file_list;
    if ~iscell(fileList); fileList = {fileList}; end
end
if isempty(fileList); fileList = {''}; end   % at least the native body

rates  = numVec(getField(blk, 'decimation_sampling_rates'));
starts = numVec(getField(blk, 'decimation_start_times'));

% THE PER-LEVEL SAMPLE COUNT, DERIVED -- v1 RECORDS NO LENGTH ANYWHERE. The
% writer's own document (NDI +gui/+app/+pyraview/makePyraviewDoc.m:155-163)
% stores label, nativeRate, nativeStartTime, channels, dataType,
% decimationLevels, decimationSamplingRates and decimationStartTimes. There is
% no sample count in the template, and a migrator does not read the attached
% bytes, so the extent is recoverable ONLY from the epoch interval and the
% level's rate.
%
% THE CONVENTION IS THE WRITER'S, NOT A GUESS. makePyraviewDoc:127-128 converts
% a duration to a sample range as `start_idx = round(offset*sr)+1; end_idx =
% round(offset_end*sr)`, i.e. a span of D seconds at rate sr yields round(D*sr)
% samples. Same arithmetic here.
%
% Read independently of the epoch-anchor block above: `t0t1` there is assigned
% inside `if ~isempty(epochStr) && ~isempty(subjectId)`, so it is not defined on
% every path that reaches this loop.
epochSpan = numVec(getField(getBlock(preBody, 'epochclocktimes'), 't0_t1'));
epochDur  = NaN;
if numel(epochSpan) >= 2 && all(isfinite(epochSpan(1:2)))
    epochDur = double(epochSpan(2)) - double(epochSpan(1));
end

% THE CHANNEL AXIS IS LOOP-INVARIANT AND IS BUILT ONCE. `channels` is a
% document-level field: every resolution level of the pyramid holds the same
% channel count, and only the TIME axis differs per level (its rate and start).
% It used to be rebuilt inside the loop and appended with `axesEntries(end+1)`,
% which GitHub code scanning 220 flagged as a grow-in-loop.
%
% THE PERFORMANCE CLAIM IS A FALSE POSITIVE and is recorded as one: the variable
% was reset to [] on every iteration and reached at most TWO elements, so it was
% bounded, not growing. This file has form both ways -- 218 was a false positive
% and is documented in place, 219 was real -- so the alert was read rather than
% assumed either way. Third alert, third separate answer.
%
% IT IS RESTRUCTURED ANYWAY, because the line the scanner pointed at sat on a
% real (if cheap) defect it did not report: a loop-invariant built N times. The
% growing assignment is gone as a side effect, so the alert clears on its merits
% instead of being suppressed.
nChannels   = numScalar(channels, 0);
channelAxis = [];
if nChannels > 0
    % An INDEX axis, the convention jNgridBody and image_stack's uncalibrated
    % arm both use: origin 1, spacing 1, no unit.
    channelAxis = jAxis(jOntologyTerm('', 'channel'), nChannels, ...
        'regular', true, ...
        'origin',  struct('value', 1, 'source_value', 1), ...
        'spacing', struct('value', 1, 'source_value', 1));
end

bodies = {obs};
for k = 1:numel(fileList)
    rate_k = nativeRt;
    if k <= numel(rates) && rates(k) > 0; rate_k = rates(k); end
    dt_k = 0.0;
    if rate_k > 0; dt_k = 1.0 / rate_k; end
    t0_k = t0;
    if k <= numel(starts); t0_k = starts(k); end

    n_k = 0;
    if isfinite(epochDur) && rate_k > 0
        n_k = round(epochDur * rate_k);
    end

    % `sample_time` IS LEFT BLANK AND THE AXES CARRY THE CADENCE. The field is
    % optional and is what step 5 of the build order retires outright; writing
    % t0/dt/n into it AND into axes(1) would store one fact twice, which is the
    % #69 shape this whole step exists to remove. Blank here means "this writer
    % has stopped using it", not "unknown".
    b = jSampledBody(obsId, sessionId, datestamp, 'migrated_signal_body', struct());

    % A CORRECTION TO WHAT THIS FILE SHIPPED IN ccfb1eb, WHICH WAS WRONG IN THE
    % WAY ITS OWN COMMIT MESSAGE PREDICTED. That commit emitted ONE axis entry,
    % `channel`, and argued the time dimension could stay in `sample_time`
    % meanwhile. The schema's axes field says `axes[k] IS array dimension k`, so
    % a one-entry list does not mean "here is one of the dimensions" -- it
    % ASSERTS that array dimension 1 is channels. It is not:
    % makePyraviewDoc.m:135 slices `data_central = data(start_idx:end_idx, :)`,
    % so dimension 1 is SAMPLES and dimension 2 is channels. The commit message
    % stated the hazard verbatim ("a partial list would claim dimension 1 is
    % channels") and then shipped it. A positional list has no partial mode.
    %
    % SO BOTH AXES OR NEITHER, and neither is the honest answer when the time
    % extent cannot be derived: an axes list that omits dimension 1 is not
    % incomplete, it is false, whereas an ABSENT list merely says nothing. The
    % channel count is then unhomed again -- a known, recorded loss (#45) --
    % rather than a wrong claim about layout.
    if n_k > 0
        timeAxis = jAxis(jOntologyTerm('', 'time'), n_k, ...
            'regular',     true, ...
            'source_unit', 's', ...
            'origin',      struct('value', t0_k, 'source_value', t0_k), ...
            'spacing',     struct('value', dt_k, 'source_value', dt_k));
        % Assigned in its own statement, NOT inside struct(...): a non-scalar
        % struct value passed to struct() distributes into a struct ARRAY of
        % bodies. Concatenation is safe only because jAxis gives every entry the
        % same field set in the same order -- that is what the helper is for.
        %
        % BRANCHED RATHER THAN `[timeAxis, channelAxis]` WITH AN EMPTY SECOND
        % OPERAND. That would rest on MATLAB dropping a 0x0 double when
        % concatenating it with a struct, which there is no MATLAB in this
        % container to confirm -- and a wrong guess there is a class error on the
        % no-channel path only, i.e. exactly the path least likely to be
        % fixtured. Two explicit arms cost one `if` and depend on nothing.
        if isempty(channelAxis)
            b.sampled_body.axes = timeAxis;
        else
            b.sampled_body.axes = [timeAxis, channelAxis];
        end
    end
    % this body owns exactly its level's file
    b.files = struct('file_list', {fileList(k)});
    % every level was produced by the SAME filter (filterData is called once per
    % document, makePyraviewDoc.m:58/:108, and the decimation happens after it),
    % so all the level bodies share one frequency_filter document. The edge is
    % appended only when there is a filter to point at -- never an empty edge.
    if ~isempty(filterId)
        b.depends_on(end+1) = struct('name', 'filter_id', 'value', filterId);
    end
    bodies{end+1} = b; %#ok<AGROW>
end
bodies{end+1} = anchor;
% The epoch handle rides alongside the session anchor rather than replacing it:
% they answer different questions ("during the session, approximately" vs "which
% epoch, in which clock"), and the session anchor is what the observation's
% time_reference_1 edge already points at. Emitted only when there is an epoch
% id to name -- see the guard above.
if ~isempty(epochRefId)
    bodies{end+1} = epochRef;
end
if ~isempty(filterDoc)
    bodies{end+1} = filterDoc;
end
end

% ===================== small helpers =======================================

function dc = classBlock(name, supers, tv)
sc = struct('class_name', {}, 'class_version', {});
for i = 1:numel(supers)
    sc(i) = struct('class_name', supers{i}, 'class_version', '1.0.0');
end
dc = struct('class_name', name, 'class_version', '1.0.0', ...
    'superclasses', sc, 'schema_version', tv);
end

function c = durationComposite(seconds)
c = struct('source_unit', 's', 'source_value', double(seconds), 'approximate', false);
end

function c = withSeconds(seconds)
%WITHSECONDS A `duration` composite WITH its canonical filled.
%   durationComposite/1 sets only the provenance triple (source_unit,
%   source_value, approximate) and leaves `seconds` -- the CANONICAL, and the
%   field a cross-document query actually reads -- to the schema blank. That is
%   fine where the source unit is the whole story; it is not fine for an epoch
%   extent, which exists to be compared. Set here rather than inside
%   durationComposite so the shared helper's other call sites keep their shape.
c = durationComposite(seconds);
c.seconds = double(seconds);
end

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(block, name)
v = [];
if isfield(block, name); v = block.(name); end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v = numScalar(x, default)
v = default;
if ~isempty(x) && isnumeric(x) && isscalar(x); v = double(x); end
end

function v = numVec(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); return; end
if ischar(x) || (isstring(x) && isscalar(x))
    parts = strsplit(char(x), {',', ' '});
    for k = 1:numel(parts)
        nn = str2double(parts{k});
        if ~isnan(nn); v(end+1) = nn; end %#ok<AGROW>
    end
end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            end
            return;
        end
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end
