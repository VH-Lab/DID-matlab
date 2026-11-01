function bodies = pyraview(preBody)
%PYRAVIEW Brainstorm-J migrator: did_v1 pyraview -> a body-backed
%   `observation` with value kind `voltage` + one sampled_body per level file
%   (+ the shared session anchor, + a frequency filter document when the source
%   names one).
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
%   So the fold now also emits ONE `method` document for the filter and points
%   every level body at it via `sampled_body.method_id` (declared optional
%   there, must_refer_to_document_class method; it was `filter_id` to a
%   `frequency_filter` until Jess Haley 2026-10-22 [filters are methods]). A
%   loaded schema whose sampled_body still declares filter_id is an error,
%   did2:convert:schemaTooOld. The filter rides on the BODIES rather than the
%   observation because that is where the schema puts the edge, and because it
%   describes the samples. When the block is an all-pass, `jFrequencyFilter`
%   returns nothing and no `method_id` is written.
%   A block it cannot place whole (a vocabulary v1 has never used, a
%   fractional order, a `label` that differs from the `type`) carries the
%   document whole as v1 ([small unread settings] (2), Jess Haley,
%   2026-10-26).
%
%   NOTE ON MATURITY, RE-DERIVED 2026-08-13 RATHER THAN CARRIED FORWARD. This
%   read "dataseries_observation and the *_body classes are `draft`", and half
%   of it was wrong in each direction -- it named a class that no longer exists,
%   and it grouped the observation with the bodies when they now differ:
%
%       voltage_observation   stable      method                   stable
%       sampled_body          DRAFT       epoch_bounded_reference  stable
%       opaque_body           DRAFT
%
%   So the only draft classes this fold touches are the two data bodies. That is
%   the pattern-setter for the #9 analysis-tier folds (mint observation + attach
%   sampled_body), and pyraview stays in the schema until this is corpus-proven.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; [migrators read raw
%   v1], Jess Haley, 2026-10-26, did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it, with no universalRenames and no superclass
%   migrator run on it (+migrators/epochclocktimes and +migrators/filter, which
%   the renamed path ran, are deleted: [unreached superclass migrators
%   deleted], Jess Haley, 2026-10-27). Its
%   template is data/pyraview.json over epochclocktimes.json, epochid.json,
%   data/filter.json and base.json at the locked NDI-matlab `main`, 3cb19a8;
%   its writer is +ndi/+gui/+app/+pyraview/makePyraviewDoc.m (the `filter`
%   block from filterData.m). Every v1 field is accounted for (jRawAccount on
%   the templates):
%
%     base.id, session_id, datestamp     the observation's id and stamps
%     base.name                          not written (the writer leaves '')
%     depends_on element_id              the observation's entity_id
%     depends_on epoch_id                NOT v1: the edge did2.convert.epochMint
%                                        stamps on the raw source it re-runs
%                                        (resolveDeferredPyraviews), read by
%                                        jEpochDocId
%     epochid.epochid                    defers to epochMint, then names the epoch
%     epochclocktimes.clocktype, t0_t1   the anchor's clock, start and duration
%     pyraview.label                     the observation's variable
%     pyraview.dataType                  the observation's data type
%     pyraview.channels                  the channel dimension
%     pyraview.nativeRate,               a level's rate and start where the
%       nativeStartTime                  level lists give none; the rate also
%                                        sizes an all-pass's sampleFrequency
%     pyraview.decimationSamplingRates,  each level body's time covariate
%       decimationStartTimes
%     pyraview.decimationLevels          restated by the rates (the writer sets
%                                        rates = nativeRate ./ cumprod(levels))
%     filter.*                           private/jFrequencyFilter
%     files.file_list, file_info         one level body per file_list name,
%                                        carrying the file_info entry of that
%                                        name ([pyraview level keeps its file
%                                        info], Jess Haley, 2026-10-27)
%
%   The fields are read in either spelling (fieldByNormalisedName below), so a
%   body that did come through the deleted rename pass (universalRenames)
%   converts exactly as before; jRawAccount reads a V2-stamped body as already
%   accounted for. A field, block or edge outside the templates carries the
%   document whole as v1 (carry-100, [fields outside the template are
%   malformed]), and what universalRenames would have discarded carries it
%   (carry-100), BEFORE the epoch deferral, so a carry is always the untouched
%   v1 source and never a deferred, epoch-stamped copy. A carry or deferral is
%   the untouched v1 source. did2.convert.roundtrip.pyraview rebuilds the v1
%   document; testRawV1RoundTripPyraview compares the two.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above). SRC is the untouched source: every
% carry returns it.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'pyraview', {{'label', 'nativeRate', 'nativeStartTime', 'channels', 'dataType', ...
        'decimationLevels', 'decimationSamplingRates', 'decimationStartTimes'}}, ...
    'filter', {{'label', 'type', 'algorithm', 'parameters'}}, ...
    'epochclocktimes', {{'clocktype', 't0_t1'}}, ...
    'epochid', {{'epochid'}}, ...
    'files', {{'file_list', 'file_info'}}), {'^element_id$', '^epoch_id$'});
% `filter.parameters` is open in the template, so jRawAccount cannot see a key
% there that jFrequencyFilter does not read; this does, against the list it
% reads with (private/jFilterParameterKeys). Such a key carries the document
% whole as v1, carry-100 (Decided by Jess Haley, 2026-10-27 [unknown filter
% parameter is malformed], did-schema V_eta_go_forward_class_audit.md).
unplaced = [unplaced, unreadFilterParameters(preBody)];
if jRawCarry('pyraview', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

blk = getBlock(preBody, 'pyraview');
subjectId = firstNonEmpty(dependencyValue(preBody, 'element_id'), ...
    dependencyValue(preBody, 'subject_id'));
obsId     = baseField(preBody, 'id', did.ido.unique_id());

label    = charOf(fieldByNormalisedName(blk, 'label'));
dataType = charOf(fieldByNormalisedName(blk, 'datatype'));
channels = fieldByNormalisedName(blk, 'channels');
t0       = numScalar(fieldByNormalisedName(blk, 'nativestarttime'), 0.0);
nativeRt = numScalar(fieldByNormalisedName(blk, 'nativerate'), 0.0);

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
if isempty(epochClk)
    epochClk = charOf(fieldByNormalisedName(getBlock(preBody, 'epochclocktimes'), 'epochclock'));
end
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
% Read the extent by its NORMALISED name: universalRenames' snake_case pass may
% respell `t0_t1` (digits next to underscores), and a missed spelling here
% passes the whole document through (corpus run 39555306048, PRED).
ect = getBlock(preBody, 'epochclocktimes');
epochSpan = numVec(fieldByNormalisedName(ect, 't0t1'));
if numel(epochSpan) < 2
    % universalRenames reshapes the v1 block to {epoch_clock, t0, t1}
    % (corpus run 39556010131, PRED): read the two ends separately.
    a = numVec(fieldByNormalisedName(ect, 't0'));
    b = numVec(fieldByNormalisedName(ect, 't1'));
    if isscalar(a) && isscalar(b)
        epochSpan = [a b];
    end
end
epochDur  = NaN;
if numel(epochSpan) >= 2 && all(isfinite(epochSpan(1:2)))
    epochDur = double(epochSpan(2)) - double(epochSpan(1));
end
% every level's body needs its time key, whose extent is the epoch's duration
% times the level's rate; with no duration there is no key, and #88's
% sampled_body requires one: pass through rather than invent an extent
if ~isfinite(epochDur)
    % A passthrough cannot validate on #88 (the tombstone lacks the v1
    % epochclocktimes block), so refuse with the reason instead.
    error('did2:convert:pyraviewNoExtent', ...
        ['pyraview "%s": no epoch extent to size its levels (epochclocktimes ' ...
         'fields: %s).'], char(preBody.base.id), ...
        strjoin(fieldnamesOf(getBlock(preBody, 'epochclocktimes')), ', '));
end

% the filter: a `method` document named by each body's method_id (Jess Haley
% 2026-10-22 [filters are methods]); a schema still declaring filter_id is
% did2:convert:schemaTooOld, raised by jFrequencyFilter
filterRate = [];   % the stated native rate, for an all-pass's sampleFrequency
if nativeRt > 0; filterRate = nativeRt; end
[filterDoc, filterEdge, filterUnplaced] = jFrequencyFilter(preBody, filterRate);
if ~isempty(filterUnplaced)
    % [small unread settings] (2) (Jess Haley, 2026-10-26): a filter block this
    % cannot place whole carries the document whole as v1
    % carry-register: carry-006 carry-007 carry-042 carry-061 via
    % private/jFrequencyFilter.m. A pre-[filters are methods] schema is not a
    % carry: it errors there, did2:convert:schemaTooOld ([pipeline defects are
    % not carries])
    did2.convert.reportNote('carried_as_v1', 'pyraview', char(preBody.base.id), ...
        ['unplaced: ' strjoin(filterUnplaced, ', ')]);
    bodies = {src};   % the untouched source
    return;
end
filterOpt = {};
if ~isempty(filterDoc)
    assert(strcmp(filterEdge, 'method_id'), 'did2:convert:noFilterEdge', ...
        'jFrequencyFilter named edge "%s"; only method_id exists', filterEdge);
    filterOpt = {'MethodId', filterDoc.base.id};
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
obs = jStatement(preBody, 'observation', subjectId, ...
    jLabel(firstNonEmpty(label, 'signal')), [], ...
    'DataBody', true, 'DatumType', datumType, 'SourceDatumType', sourceDatumType, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', obsId, 'ValueKind', 'voltage');

fileList = {};
if isfield(preBody, 'files') && isstruct(preBody.files) ...
        && isfield(preBody.files, 'file_list')
    fileList = preBody.files.file_list;
    if ~iscell(fileList); fileList = {fileList}; end
end
if isempty(fileList); fileList = {''}; end   % at least the native body
fileInfo = {};   % the v1 files.file_info records, one cell each
if isfield(preBody, 'files') && isstruct(preBody.files) ...
        && isfield(preBody.files, 'file_info') && ~isempty(preBody.files.file_info)
    fileInfo = preBody.files.file_info;
    if isstruct(fileInfo); fileInfo = num2cell(fileInfo(:)'); end
    if ~iscell(fileInfo); fileInfo = {}; end
end
rates  = numVec(fieldByNormalisedName(blk, 'decimationsamplingrates'));
starts = numVec(fieldByNormalisedName(blk, 'decimationstarttimes'));
nChannels   = numScalar(channels, 0);
channelAxis = [];
if nChannels > 0
    % a BARE dimension: its 1..N numbering only repeated the positions (Jess
    % Haley 2026-10-22, 6.2a and "yes" to 1..N); channel number = position + 1
    channelAxis = jAxis(jOntologyTerm('', 'channel'), nChannels);
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
        % CEIL, not round: a decimated level holds one sample per bin, and the
        % last, partial bin is still written. PRED's coarsest level (0.0002 Hz
        % over 28.1 s) rounds to 0 samples, which passed the whole document
        % through (a judgment call, recorded in the port report).
        n_k = ceil(epochDur * rate_k - 1e-9);
    end
    if n_k <= 0
        error('did2:convert:pyraviewNoExtent', ...
            ['pyraview "%s": level %d of %d has no extent (rate %g Hz over ' ...
             '%g s; native rate %g; block fields: %s).'], char(preBody.base.id), ...
            k, numel(fileList), rate_k, epochDur, nativeRt, strjoin(fieldnamesOf(blk), ', '));
    end
    timeAxis = jAxis(jOntologyTerm('', 'time'), n_k, ...
        'source_unit', 's', ...
        'origin',      struct('value', t0_k, 'source_value', t0_k), ...
        'spacing',     struct('value', dt_k, 'source_value', dt_k));
    % time (and channel) dimensions, each with its positions as a covariate
    % along it (data_body AMENDMENT 6; the former keys)
    if isempty(channelAxis)
        [dims, covs] = jDimCov({timeAxis});
    else
        [dims, covs] = jDimCov({timeAxis, channelAxis});
    end
    % DATUM ORDER 'C': a pyraview level file interleaves the channels within
    % each sample (the channel dimension varies fastest) -- a conservative reading
    % of the writer, recorded as a judgment call in the port report.
    % DatumOrder only with more than one dimension (rule
    % datum_order_multidimensional: empty with one)
    orderOpt = {};
    if numel(dims) > 1; orderOpt = {'DatumOrder', 'C'}; end
    o = jOpts(preBody, filterOpt{:}, orderOpt{:});
    b = did2.build.sampledBody(obsId, dims, 'Covariates', covs, o{:});
    b.files = struct('file_list', {fileList(k)});
    % THE LEVEL KEEPS ITS FILE INFO (Decided by Jess Haley, 2026-10-27
    % [pyraview level keeps its file info], did-schema
    % V_eta_go_forward_class_audit.md): the v1 files.file_info entry whose
    % `name` is this level's file -- the uid, the database's handle on the
    % stored binary, its location and ingest flags -- rides on the level body
    % beside the name, unchanged. A level the writer attached nothing to (the
    % template lists level1..level10.bin; add_file is called once per
    % decimation step) has no entry and gets none.
    fi = levelFileInfo(fileInfo, fileList{k});
    if ~isempty(fi)
        b.files.file_info = fi;
    end
    bodies{end+1} = b; %#ok<AGROW>
end
bodies{end+1} = anchor;
if ~isempty(filterDoc)
    bodies{end+1} = filterDoc;
end
end

function fi = levelFileInfo(fileInfo, name)
% the file_info record whose `name` is NAME, [] when there is none
fi = [];
for j = 1:numel(fileInfo)
    e = fileInfo{j};
    if isstruct(e) && isscalar(e) && isfield(e, 'name') ...
            && strcmp(charOf(e.name), char(name))
        fi = e;
        return;
    end
end
end

function paths = unreadFilterParameters(body)
% `filter.parameters.<key>` for every key private/jFrequencyFilter does not
% read, whatever it holds ([unknown filter parameter is malformed]: "holds a key
% jFrequencyFilter does not read"). {} when the block has no parameters struct.
paths = {};
f = getBlock(body, 'filter');
if ~isfield(f, 'parameters') || ~isstruct(f.parameters) || ~isscalar(f.parameters)
    return;
end
[~, known] = jFilterParameterKeys();
fn = fieldnames(f.parameters);
for k = 1:numel(fn)
    if ~any(strcmp(fn{k}, known))
        paths{end+1} = ['filter.parameters.' fn{k}]; %#ok<AGROW>
    end
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

function v = fieldByNormalisedName(block, normalised)
% The field of BLOCK whose name, lower-cased with underscores removed, is
% NORMALISED; [] when there is none.
v = [];
if ~isstruct(block); return; end
fn = fieldnames(block);
for k = 1:numel(fn)
    if strcmp(lower(strrep(fn{k}, '_', '')), normalised)
        v = block.(fn{k});
        return;
    end
end
end

function c = charOf(x)
c = '';
if ischar(x); c = x; elseif isstring(x) && isscalar(x); c = char(x); end
end

function n = fieldnamesOf(s)
n = {};
if isstruct(s); n = fieldnames(s)'; end
end
