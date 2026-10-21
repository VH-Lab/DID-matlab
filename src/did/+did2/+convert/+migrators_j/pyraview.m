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

blk = getBlock(preBody, 'pyraview');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
obsId     = baseField(preBody, 'id', did.ido.unique_id());

label    = getCharField(blk, 'label');
dataType = getCharField(blk, 'data_type');
channels = getField(blk, 'channels');
t0       = numScalar(getField(blk, 'native_start_time'), 0.0);
nativeRt = numScalar(getField(blk, 'native_rate'), 0.0);

% ---- did-schema #88: the time anchor ---------------------------------------
% The pre-#73 `epoch_bounded_reference` (the epoch named by its STRING) is
% gone; on #88 an epoch-scoped time is a relative_time_reference onto the
% EPOCH ENTITY, whose id did2.convert.epochMint mints. So a pyraview carrying
% an epoch string PASSES THROUGH pass 1 (its v1 tombstone validates it), and
% epochMint stamps `epoch_id` and re-runs this migrator (the arming path, like
% syncrule_mapping): jEpochDocId then names the epoch and the fold happens. A
% pyraview with no epoch string is anchored "during the session".
epochStr = getCharField(getBlock(preBody, 'epochid'), 'epochid');
epochClk = getCharField(getBlock(preBody, 'epochclocktimes'), 'clocktype');
epochDocId = jEpochDocId(preBody);
if ~isempty(epochStr) && isempty(epochDocId)
    % DEFER (the stimulus_bath pattern): the #88 pyraview tombstone does not
    % declare the v1 `epochclocktimes` block, so the document cannot wait in
    % the batch as a passthrough. It waits in the quarantine instead, and
    % did2.convert.epochMint folds it once the epoch entity exists.
    error('did2:convert:needsEpochContext', ...
        ['pyraview "%s" names epoch "%s"; its time anchor is the epoch ' ...
         'entity epochMint mints, so it is deferred to that pass.'], ...
        char(preBody.base.id), epochStr);
end
epochSpan = numVec(getField(getBlock(preBody, 'epochclocktimes'), 't0_t1'));
epochDur  = NaN;
if numel(epochSpan) >= 2 && all(isfinite(epochSpan(1:2)))
    epochDur = double(epochSpan(2)) - double(epochSpan(1));
end
% every level's body needs its time key, whose extent is the epoch's duration
% times the level's rate; with no duration there is no key, and #88's
% sampled_body requires one: pass through rather than invent an extent
if ~isfinite(epochDur)
    bodies = {preBody};
    return;
end

filterDoc = jFrequencyFilter(preBody);
filterId = '';
if ~isempty(filterDoc)
    filterId = filterDoc.base.id;
end

if ~isempty(epochDocId)
    if isempty(epochClk); epochClk = 'dev_local_time'; end
    sec = struct('node', 'om:second-Time', 'name', 'second');
    anchor = did2.build.relativeTimeReference(epochDocId, 'Clock', epochClk, ...
        'Start', double(epochSpan(1)), 'StartSourceValue', double(epochSpan(1)), ...
        'StartSourceUnit', sec, 'StartApproximate', false, ...
        'Duration', epochDur, 'DurationSourceValue', epochDur, ...
        'DurationSourceUnit', sec, 'DurationApproximate', false, ...
        'SessionId', jSid(preBody), 'CreationTimestamp', jStamp(preBody), ...
        'Validate', false);
else
    anchor = jSessionAnchor(preBody, 'during');
end

% ---- the observation (the signal is in the per-level bodies) -----------------
[datumType, sourceDatumType] = jDatumType(dataType);
obs = jStatement(preBody, 'voltage_observation', subjectId, ...
    jLabel(firstNonEmpty(label, 'signal')), [], ...
    'DataBody', true, 'DatumType', datumType, 'SourceDatumType', sourceDatumType, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', obsId);

fileList = {};
if isfield(preBody, 'files') && isstruct(preBody.files) ...
        && isfield(preBody.files, 'file_list')
    fileList = preBody.files.file_list;
    if ~iscell(fileList); fileList = {fileList}; end
end
if isempty(fileList); fileList = {''}; end   % at least the native body
rates  = numVec(getField(blk, 'decimation_sampling_rates'));
starts = numVec(getField(blk, 'decimation_start_times'));
nChannels   = numScalar(channels, 0);
channelAxis = [];
if nChannels > 0
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
    if rate_k > 0
        n_k = round(epochDur * rate_k);
    end
    if n_k <= 0
        bodies = {preBody};   % a level with no extent: see above
        return;
    end
    timeAxis = jAxis(jOntologyTerm('', 'time'), n_k, ...
        'regular',     true, ...
        'source_unit', 's', ...
        'origin',      struct('value', t0_k, 'source_value', t0_k), ...
        'spacing',     struct('value', dt_k, 'source_value', dt_k));
    if isempty(channelAxis)
        keys = timeAxis;
    else
        keys = did2.build.list(timeAxis, channelAxis);
    end
    % DATUM ORDER 'C': a pyraview level file interleaves the channels within
    % each sample (the channel key varies fastest) -- a conservative reading
    % of the writer, recorded as a judgment call in the port report.
    o = jOpts(preBody, 'FilterId', filterId, 'DatumOrder', 'C');
    b = did2.build.sampledBody(obsId, keys, o{:});
    b.files = struct('file_list', {fileList(k)});
    bodies{end+1} = b; %#ok<AGROW>
end
bodies{end+1} = anchor;
if ~isempty(filterDoc)
    bodies{end+1} = filterDoc;
end
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
