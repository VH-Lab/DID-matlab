function R = ingestedArchiveFiles(bodies, batch, varargin)
%INGESTEDARCHIVEFILES Rebuild the files a v1 `daqreader_mfdaq_epochdata_ingested`
%   attached, from the v2 documents of its epoch, in either shape.
%
%   R = did2.convert.roundtrip.ingestedArchiveFiles(BODIES, BATCH) takes BODIES,
%   the data bodies that carry one v1 ingested archive's files (a cell of
%   structs: the `opaque_body` documents did2.convert.resolveEpochProbemap
%   makes of it, or the `sampled_body` documents NDI-matlab's second pass
%   makes of those), and BATCH, the whole batch they are in (a cell of
%   structs, or the index private/batchContext makes of it). It returns what
%   the v1 archive's attached files were, rebuilt from those documents:
%   the v1 member names, the `channel_list.bin` rows, and the content of each
%   `evmktx_group<g>_seg.nbf_1`.
%
%   R = ...(BODIES, BATCH, 'ReadBody', FN) also reads the values the unpacked
%   event, marker and text channels hold: FN(BODY) returns the values of one
%   `sampled_body` (a numeric array shaped by its dimensions, or for a text
%   body a cellstr). Without it, R.evmktx is built from the documents only
%   (types, numbers, order) and its times and codes are 'not read'. The
%   default reader did2.convert.roundtrip.ingestedArchiveFiles('readBody', ...)
%   is not given here: the caller says where the bytes are (see READING
%   BODIES).
%
%   WHY. Decided by Jess Haley, 2026-11-17 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md):
%     [event channels are time-valued observations] the event, marker and
%       text channels of an ingested `evmktx_group<g>_seg.nbf_1` are
%       unpacked, one observation per channel, instrument the acquisition
%       system, the epoch's time reference: an event channel a `time` value
%       (seconds from the epoch start, in a sampled_body), a marker channel
%       a `label` value (one code per event) keyed to a `time` value of the
%       event times, a text channel a `text` value keyed the same way;
%     [several marker numbers are a second dimension] a marker channel whose
%       events carry several numbers has dimensions event x column;
%     [unpacked events file is removed] its opaque_body is removed once the
%       round trip rebuilds the file from the observations ("An archive
%       whose file the round trip cannot rebuild exactly is not unpacked");
%     [channel list rows get v2 homes] every `channel_list.bin` row gets a
%       home: event, marker and text rows their channels' observations,
%       "each recording its channel type and number as a condition (e.g.
%       "marker channel", EMPTY:0000377, count 1)"; a non-standard channel
%       name a text covariate along the channel dimension; "The file is
%       removed only when the round trip rebuilds it exactly";
%     [time channel is a per-channel covariate] a channel's link to its time
%       channel is a covariate along the channel dimension, variable "time
%       channel" (EMPTY:0000374), one unitless number per channel, NaN and
%       dangling values carried exactly;
%     [migrated body members renamed] "The round trip rebuilds NDI's names
%       from the body's channel type, group and segment number";
%     [non-specimen channel groups get their own owner] a digital,
%       auxiliary or analog-output group may be owned by another document
%       than the recording observation, so owners are read per body;
%     [channel name is an identifier] "a channel's v1 name is a covariate
%       along the channel dimension of its channel group's body, variable
%       NCIT:C25364 "Identifier", one text value per channel";
%   and by Jess Haley, 2026-11-18:
%     [event row defaults are notation] "an event or marker channel-list
%       row's offset, scale, time channel and sample rate, when they are
%       NDI's defaults, are notation ([spelling is notation]): not stored,
%       rebuilt by the round trip; a channel list whose event or marker rows
%       differ from the defaults ... is kept whole as v1";
%   and by Jess Haley, 2026-11-19 (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md):
%     [time channel row is notation] "a time channel's own `channel_list.bin`
%       row is rebuilt from its time group: number the time group's, sample
%       rate the group's, offset 0, scale 1, name the standard prefix and
%       number; the file is removed only when the rebuild matches exactly,
%       else it is kept whole as v1 and counted";
%     [text channel entries are a JSON array] "an unpacked text channel's
%       times are an uncompressed array of 64-bit floats ...; its entries are
%       one uncompressed UTF-8 JSON array of strings in the same order,
%       format EDAM format_3464 "JSON"";
%     [time group with several time channels split] "when an ingested
%       archive's one uneven time group file holds several time channels,
%       each time channel becomes its own keyed `time` value, and each
%       channel group keys to the time value of the time channel its rows' v1
%       `time_channel` names".
%   This function is that round trip's rebuild; the comparison with the v1
%   files is did2.convert.roundtrip.compareIngestedArchiveFiles. The document
%   inverse (did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested) reads
%   R.members, R.channel_list_state and R.evmktx for the v1 file list.
%
%   HOW EACH IS REBUILT. The rules are NDI-matlab's v1 writer at the locked
%   `main`: ndi.daq.reader.mfdaq/ingest_epochfiles (what is attached, under
%   which name, in which order) and ndi.file.type.mfdaq_epoch_channel/
%   create_properties (the rows: group = 1 + floor(number / per-group count),
%   with 400 for analog in, analog out and auxiliary in, 512 for digital,
%   100000 for event/marker/text and time; dataclass ephys, digital,
%   eventmarktext or time; rows by type in alphabetical order, event, marker
%   and text last together, each type by channel number).
%
%     member names   an opaque_body: its slot `<stem>#` (data_body.filename)
%                    and member body_data_<m-1> -> `<stem><m>`, as today.
%                    A sampled_body: `<prefix>_group<g>_seg.nbf_<m>` with the
%                    prefix of its channel type (the condition Channel,
%                    NCIT:C44170, by node; digital_out is written `di`, as the
%                    writer does), the group from its `filename` when it has
%                    one, else from its channel numbers by the writer's rule,
%                    and m the member's position (body_data_<m-1>; a member
%                    still named by NDI keeps its name). A body
%                    whose name cannot be rebuilt is listed in R.members with
%                    the reason, and gets no names.
%     channel_list.bin
%                    'carried' when a `channel_list.bin` body is among BODIES
%                    (today's shape: the file itself is kept). Otherwise
%                    'rebuilt' from the converted channel groups and the
%                    unpacked event channels, or 'not rebuilt' (why in
%                    R.channel_list_why). Per row:
%         name         the body's name covariate entry ([channel name is an
%                      identifier]: the `text` covariate along the channel
%                      dimension whose variable is NCIT:C25364 "Identifier",
%                      found by node) when it is not empty, else
%                      `<abbrev><number>`, the name NDI's readers give a
%                      channel (ndi.file.type.mfdaq_epoch_channel/
%                      create_properties keeps the reader's name and reads
%                      the number from it, ndi.fun.channelname2prefixnumber);
%                      NDI-matlab's second pass writes the covariate only on
%                      a group where some v1 name is not that form
%         type         the channel type (condition), as NDI spells it
%         time_channel the "time channel" covariate (EMPTY:0000374); NaN
%                      when the body has none (today's shape)
%         sample_rate  1 / the time covariate's spacing (the keyed time
%                      value's group: NaN, as a v1 row of an uneven group
%                      states its nominal rate, which v2 does not hold:
%                      listed in R.no_home)
%         offset, scale  the covariates AFO:AFQ_0000202 and NCIT:C70774
%                      (`source_value` / `source_numeric` when there: the v1
%                      scale, [scale carries the reader's unit])
%         number       the channel-number covariate (the channel-type term
%                      as variable, [ingested block terms confirmed], or the
%                      label "channel number" written before)
%         group, dataclass   the writer's rule above
%       An event, marker or text row: type and number from the observation's
%       channel-type condition; name `<abbrev><number>`. Its sample_rate,
%       offset, scale and time_channel are NOTATION ([event row defaults are
%       notation]): not stored, rebuilt as NDI's writer fills them
%       (ndi.daq.reader.mfdaq/ingest_epochfiles asks no event channel for a
%       sample rate, so NaN; underlying_datatype gives the polynomial [0 1],
%       so offset 0 and scale 1; time_channel NaN, as
%       ndi.vintage.ingestedChannelList rebuilds it) and listed in
%       R.notation. A list whose event or marker rows differ (CED Spike2
%       sets an event's time channel to its own number) does not compare
%       exactly, and NDI-matlab's second pass keeps it whole as v1.
%       A time row ([time channel row is notation]): one per whole number
%       T >= 0 that some group's "time channel" covariate names, as
%       NDI-matlab's readers rebuild it (ndi.vintage.ingestedChannelList):
%       name `t<T>`, type time, time_channel T (the decision names none;
%       every NDI reader that writes a time row points it at itself: Intan
%       `t1` 1, CED Spike2 `t<n>` n), sample rate that of the groups whose
%       every channel names T when they agree on one (else NaN: an unevenly
%       spaced group's time is keyed, so it has none), offset 0, scale 1,
%       number T, group and dataclass by the writer's rule; its
%       time_channel, offset and scale are listed in R.notation. A time
%       channel a group names that the v1 list does not hold (Intan's
%       auxiliary t2, VH-Lab/NDI-matlab#1249) is rebuilt too, so that list
%       does not compare exactly; NDI-matlab's second pass keeps it. The
%       rows here follow that rule: the sample rate rounded to a whole
%       number when within 1e-9 of one, NaN read back as JSON null accepted.
%     evmktx_group<g>_seg.nbf_1
%                    one entry per group of unpacked event channels (group by
%                    the writer's rule), the channels in row order. Each
%                    channel: channeltype 'event' | 'marker' | 'text', channel
%                    its number, T the event times plus the epoch's start
%                    (the first time reference's start, on the observation's
%                    first clock: v1 holds them on the epoch's clock), D the
%                    codes (event: ones, as NDI's expander returns; marker:
%                    the label value, event x column; text: the entries).
%                    Also DATA and DATA_DESCRIPTION, the vector NDI-compress
%                    writes into the file (ndi.compress.eventmarktext2vector,
%                    re-stated here so DID does not depend on NDI-compress).
%                    THE FILE ITSELF IS NOT WRITTEN: its bytes are
%                    ndi.compress.compress_eventmarktext's output, which lives
%                    in NDI-compress, not a DID-matlab requirement
%                    (requirements.txt), so the rebuild is compared on its
%                    content (compareIngestedArchiveFiles).
%     time segments  `ti_group<g>_seg.nbf_<m>` when no time body is among
%                    BODIES and a time row was rebuilt (the evenly spaced
%                    time NDI's second pass removes): m = 1 ..
%                    ceil(samples / chunk) of an analog group pointing at it.
%     a split time group  [time group with several time channels split]:
%                    the time values' sampled_bodies whose `filename` is the
%                    v1 group's `ti_group<g>_seg.nbf_#` and whose condition
%                    "time channel" (EMPTY:0000374) counts the time channel
%                    each holds (NDI-matlab's second pass,
%                    ndi.migrate.internal.ingestedArchiveBodies, writes one
%                    per time channel, each holding that column of the v1
%                    file). They are ONE v1 file series: its names
%                    `ti_group<g>_seg.nbf_<m>`, m = 1 .. the bodies' member
%                    count, are in R.time_segments (no document holds the v1
%                    file's location, so the document inverse rebuilds the
%                    name, not the location), and no split body gets member
%                    names of its own. R.split_time says, per group, which
%                    body is which column (the time channels in increasing
%                    number, the order NDI's writer lists them and so the v1
%                    file's columns) and, with 'ReadBody', the content of each
%                    segment: the columns side by side, chunk rows per
%                    segment, plus the epoch's start (the first start on the
%                    time references the group bodies' owners name: the
%                    bodies hold seconds from the epoch's start, v1 the
%                    epoch's clock). ReadBody(BODY) must return the body's
%                    values (n x 1); the bodies are compressed as NDI's ingest
%                    compresses time (ndi.compress.compress_time, in
%                    NDI-compress, not a DID-matlab requirement), so the
%                    caller who has NDI-compress reads them. THE FILE ITSELF
%                    IS NOT WRITTEN, as for the events file; it is compared
%                    on its content (compareIngestedArchiveFiles).
%
%   FINDING THE UNPACKED CHANNELS. The observations whose conditions hold a
%   channel-type condition of an event, marker or text channel (EMPTY:0000376,
%   EMPTY:0000377, EMPTY:0000410, or NCIT:C25704 written before [text channel
%   replaces NCIT Text]) with a count, and that name one of the time
%   references BODIES' owners name (the epoch's). A channel observation's
%   times are its own sampled_body (event) or the body of the `time` value
%   its body is keyed to (`key_id`; marker, text).
%
%   READING BODIES. [unpacked event bodies are uncompressed]: times and codes
%   are little-endian 64-bit floats. FN = @(b) did2.convert.roundtrip.
%   ingestedArchiveFiles('readBody', b, LOCATE) reads one: its members
%   body_data_0.. in order, each at LOCATE(file_info entry) (a local path, ''
%   when not here), concatenated and shaped by the dimensions (datum_order
%   'F' or empty: first dimension fastest; 'C': last); a body whose format
%   is EDAM:format_3464 "JSON" (a text channel's entries, [text channel
%   entries are a JSON array]) is read as one UTF-8 JSON array of strings,
%   a 1xN cell of character rows as NDI-compress's expander gives a text
%   channel's entries. 'readFloat64' reads the float64 bodies only (as
%   before).
%
%   R, the denominators first (Operating Rule 5):
%     documents_inspected  bodies given + batch documents indexed
%     bodies_given, group_bodies (sampled channel groups), event_observations
%     shape            'pass 1' (every body an opaque_body), 'second pass'
%     members          struct array {body_id, class_name, slot, names,
%                      file_index (each name's entry in files.file_info), why}
%     owners           struct array {body_id, owner_ids} (per body: the owner
%                      sets may differ, [non-specimen channel groups get their
%                      own owner])
%     channel_list_state, channel_list_why, channel_list (struct array of v1
%                      rows, NDI's field order)
%     no_home          struct array {row, field, value, why}: fields no
%                      decision gives a v2 home
%     notation         struct array {row, field, value, why}: the event,
%                      marker and text rows' fields rebuilt as NDI's
%                      defaults ([event row defaults are notation])
%     evmktx           struct array {name, group, carried (its opaque_body
%                      is still among BODIES), state ('rebuilt' | 'not read'
%                      | 'not rebuilt'), why, channeltype, channel, T, D,
%                      data, data_description}
%     time_segments    cellstr of rebuilt `ti_group…` names (the removed
%                      evenly spaced time, and the split time groups' files)
%     split_time       struct array {name (the series, `ti_group<g>_seg.nbf_#`),
%                      group, channels (time channels, column order),
%                      body_ids, value_ids (the time values owning them),
%                      segments (the v1 file names), state ('rebuilt' | 'not
%                      read' | 'not rebuilt'), why, t0, data (a cell, one
%                      matrix per segment: rows x channels)}
%     t0               the epoch start added back to event times (NaN: none)
%
%   See also did2.convert.roundtrip.compareIngestedArchiveFiles,
%            did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested.

if ischar(bodies) && strcmp(bodies, 'readFloat64')
    R = readFloat64(batch, varargin{:});
    return;
end
if ischar(bodies) && strcmp(bodies, 'readBody')
    R = readBody(batch, varargin{:});
    return;
end
opts = struct('ReadBody', []);
for k = 1:2:numel(varargin)
    if ~isfield(opts, varargin{k})
        error('did2:convert:roundtrip:badOption', 'Unknown option ''%s''.', varargin{k});
    end
    opts.(varargin{k}) = varargin{k + 1};
end
if isstruct(bodies); bodies = num2cell(bodies(:)'); end
ctx = batch;
if iscell(batch); ctx = indexOf(batch); end

R = struct('documents_inspected', numel(bodies) + numel(ctx.docs), ...
    'bodies_given', numel(bodies), 'group_bodies', 0, 'event_observations', 0, ...
    'shape', 'pass 1', ...
    'members', struct('body_id', {}, 'class_name', {}, 'slot', {}, 'names', {}, ...
        'file_index', {}, 'why', {}), ...
    'owners', struct('body_id', {}, 'owner_ids', {}), ...
    'channel_list_state', 'not rebuilt', 'channel_list_why', '', ...
    'channel_list', emptyRows(), ...
    'no_home', struct('row', {}, 'field', {}, 'value', {}, 'why', {}), ...
    'notation', struct('row', {}, 'field', {}, 'value', {}, 'why', {}), ...
    'evmktx', emptyEvmktx(), 'time_segments', {{}}, 'split_time', emptySplit(), 't0', NaN);

% the time-value bodies an uneven group is keyed to belong to the archive too
bodies = withKeyedTimeBodies(bodies, ctx);

groups = struct('row0', {}, 'n', {}, 'chunk', {}, 'tc', {}, 'sr', {}, 'dataclass', {});
rows = emptyRows();
hasChannelList = false;
hasTimeBody = false;
slots = {};
ownerIds = {};
splitBodies = struct('slot', {}, 'number', {}, 'body', {});   % [time group with several time channels split]
for k = 1:numel(bodies)
    b = bodies{k};
    cn = classOf(b);
    id = baseId(b);
    own = edgeList(b, 'owner_id');
    R.owners(end+1) = struct('body_id', id, 'owner_ids', {own});
    for o = own
        if ~any(strcmp(ownerIds, o{1})); ownerIds{end+1} = o{1}; end %#ok<AGROW>
    end
    slot = blockField(b, 'filename');
    slots{end+1} = slot; %#ok<AGROW>
    if strcmp(slot, 'channel_list.bin'); hasChannelList = true; end
    if ~isempty(regexp(slot, '^ti_group\d+_seg\.nbf_#$', 'once')); hasTimeBody = true; end
    if strcmp(cn, 'sampled_body'); R.shape = 'second pass'; end
    tcSplit = splitTimeChannel(b, cn, slot);
    if isfinite(tcSplit)
        % one column of a split time group: the group's files are rebuilt
        % once, below; this body gets no member names of its own
        splitBodies(end+1) = struct('slot', slot, 'number', tcSplit, 'body', b); %#ok<AGROW>
        R.members(end+1) = struct('body_id', id, 'class_name', cn, 'slot', slot, ...
            'names', {{}}, 'file_index', [], 'why', '');
        continue;
    end
    [names, why, info] = memberNames(b, cn, slot);
    [~, ~, fidx] = memberCount(b);
    R.members(end+1) = struct('body_id', id, 'class_name', cn, 'slot', slot, ...
        'names', {names}, 'file_index', fidx(1:numel(names)), 'why', why);
    if strcmp(cn, 'sampled_body') && ~isempty(info) && ~strcmp(info.prefix, 't')
        R.group_bodies = R.group_bodies + 1;
        [grows, g, nh] = groupRows(b, info);
        for h = 1:numel(nh)
            nh(h).row = nh(h).row + numel(rows);
        end
        R.no_home = [R.no_home, nh];
        g.row0 = numel(rows);
        rows = [rows, grows]; %#ok<AGROW>
        groups(end+1) = g; %#ok<AGROW>
    end
end

% ---- the unpacked event, marker and text channels ------------------------
refs = ownerTimeReferences(ownerIds, ctx);
chans = eventChannels(refs, ctx);
R.event_observations = numel(chans);
if ~isempty(chans); R.shape = 'second pass'; end
evRows = emptyRows();
for c = 1:numel(chans)
    evRows(end+1) = row(sprintf('%s%d', chans(c).abbrev, chans(c).number), chans(c).type, ...
        NaN, NaN, 0, 1, chans(c).number, writerGroup(chans(c).abbrev, chans(c).number), ...
        'eventmarktext'); %#ok<AGROW>
end

% ---- the time rows ([time channel row is notation]) -----------------------
tRows = emptyRows();
tcs = [];
for g = 1:numel(groups)
    v = groups(g).tc(isfinite(groups(g).tc));
    tcs = unique([tcs, v(:)']);
end
tcs = tcs(tcs >= 0 & tcs == round(tcs));
for t = tcs
    % [time channel row is notation]: the rate of the groups whose every
    % channel names T, when they agree (ndi.vintage.ingestedChannelList)
    rates = [];
    for g = 1:numel(groups)
        if ~isempty(groups(g).tc) && all(groups(g).tc == t) && isfinite(groups(g).sr)
            rates(end+1) = groups(g).sr; %#ok<AGROW>
        end
    end
    rates = unique(rates);
    sr = NaN;
    if isscalar(rates); sr = rates; end
    tRows(end+1) = row(sprintf('t%d', t), 'time', t, sr, 0, 1, t, writerGroup('t', t), 'time'); %#ok<AGROW>
end

% ---- channel_list.bin -----------------------------------------------------
if hasChannelList
    R.channel_list_state = 'carried';
    R.channel_list_why = 'its channel_list.bin body is kept (the file itself)';
elseif strcmp(R.shape, 'pass 1')
    R.channel_list_why = 'no channel_list.bin body, and no converted channel group or unpacked channel';
else
    all_ = [rows, tRows];
    nhOffset = numel(all_);
    order = writerOrder(all_);
    remap = zeros(1, numel(all_));
    remap(order) = 1:numel(order);
    for h = 1:numel(R.no_home)
        R.no_home(h).row = remap(R.no_home(h).row);
    end
    all_ = all_(order);
    for r = find(strcmp({all_.type}, 'time'))
        R.notation(end+1) = struct('row', r, 'field', 'time_channel, offset, scale', ...
            'value', [all_(r).time_channel 0 1], ...
            'why', ['[time channel row is notation] (Jess Haley, 2026-11-19): a time ' ...
            'channel''s own row, rebuilt from the groups that name it, not stored']); %#ok<AGROW>
    end
    evOrder = eventOrder(evRows);
    evRows = evRows(evOrder);
    chans = chans(evOrder);
    for e = 1:numel(evRows)
        R.notation(end+1) = struct('row', nhOffset + e, ...
            'field', 'sample_rate, offset, scale, time_channel', 'value', [NaN 0 1 NaN], ...
            'why', ['[event row defaults are notation] (Jess Haley, 2026-11-18): NDI''s ' ...
            'defaults for an event, marker or text row, rebuilt, not stored']);
    end
    R.channel_list = [all_, evRows];
    R.channel_list_state = 'rebuilt';
end
if isempty(evRows) || ~strcmp(R.channel_list_state, 'rebuilt')
    evOrder = eventOrder(evRows);
    chans = chans(evOrder);
end

% ---- evmktx_group<g>_seg.nbf_1 -------------------------------------------
if ~isempty(chans)
    gs = unique([chans.group]);
    for g = gs
        e = evmktxOf(chans([chans.group] == g), g, ctx, opts.ReadBody);
        e.carried = any(strcmp(slots, sprintf('evmktx_group%d_seg.nbf_#', g)));
        R.evmktx(end+1) = e;
    end
    R.t0 = chans(1).t0;
end

% ---- the split time groups ([time group with several time channels split])
splitSlots = {};
if ~isempty(splitBodies); splitSlots = unique({splitBodies.slot}, 'stable'); end
for i = 1:numel(splitSlots)
    sb = splitBodies(strcmp({splitBodies.slot}, splitSlots{i}));
    st = splitTimeOf(sb, ownerIds, ctx, opts.ReadBody);
    R.split_time(end+1) = st;
    R.time_segments = [R.time_segments, st.segments];
end

% ---- the evenly spaced time segments the second pass removed --------------
if ~hasTimeBody && strcmp(R.shape, 'second pass')
    for t = 1:numel(tRows)
        n = NaN; chunk = NaN;
        for g = 1:numel(groups)
            if all(groups(g).tc == tRows(t).number) && strcmp(groups(g).dataclass, 'ephys') ...
                    && isfinite(groups(g).n) && isfinite(groups(g).chunk) && groups(g).chunk > 0
                n = groups(g).n; chunk = groups(g).chunk;
                break;
            end
        end
        if ~isfinite(n); continue; end
        for m = 1:ceil(n / chunk)
            R.time_segments{end+1} = sprintf('ti_group%d_seg.nbf_%d', tRows(t).group, m);
        end
    end
end
end

% =========================================================================
% member names
% =========================================================================

function [names, why, info] = memberNames(b, cn, slot)
% the v1 names of a body's members, in member order
names = {};
why = '';
info = [];
[n, ndiNames] = memberCount(b);
switch cn
    case 'opaque_body'
        if isempty(slot)
            why = 'the opaque_body names no file slot';
            return;
        end
        for m = 1:n
            if endsWith(slot, '#')
                names{end+1} = sprintf('%s%d', slot(1:end-1), m); %#ok<AGROW>
            else
                names{end+1} = slot; %#ok<AGROW>
            end
        end
    case 'sampled_body'
        [info, why] = groupInfo(b, slot);
        if isempty(info); return; end
        for m = 1:n
            if ~isempty(ndiNames{m})
                names{end+1} = ndiNames{m}; %#ok<AGROW>   % a member still named by NDI
            else
                names{end+1} = sprintf('%s_group%d_seg.nbf_%d', info.filePrefix, info.group, m); %#ok<AGROW>
            end
        end
    otherwise
        why = sprintf('a %s carries no archive file', cn);
end
end

function [info, why] = groupInfo(b, slot)
% the channel type, file prefix and group of a sampled channel-group body
info = [];
why = '';
tok = regexp(slot, '^([a-z]+)_group(\d+)_seg\.nbf_#$', 'tokens', 'once');
ab = '';
for c = asCellOf(blockField(b, 'conditions'))
    t = getPath(c{1}, 'term');
    if isstruct(t)
        a = prefixOfNode(textOf(getPath(t, 'node')));
        if ~isempty(a); ab = a; break; end
    end
end
if isempty(ab) && ~isempty(tok)
    ab = tok{1};   % a body whose condition names no channel type: its file's prefix
end
if strcmp(ab, 't') || (~isempty(tok) && strcmp(tok{1}, 'ti'))
    % the keyed time value's body ([uneven time is a keyed time value])
    if isempty(tok)
        why = 'a time body without its file slot: its group is not stated';
        return;
    end
    info = struct('prefix', 't', 'filePrefix', 'ti', 'group', str2double(tok{2}), 'type', 'time');
    return;
end
if ~any(strcmp(ab, {'ai', 'ao', 'ax', 'di', 'do'}))
    why = 'the body names no channel group type (condition Channel, NCIT:C44170)';
    return;
end
fp = ab;
if strcmp(ab, 'do'); fp = 'di'; end   % ingest_epochfiles writes digital_out as di
nums = covariateValues(b, @(cv) isChannelNumber(cv, ab));
if ~isempty(tok)
    g = str2double(tok{2});
    if ~strcmp(tok{1}, fp)
        why = sprintf('its slot %s is not a %s file (channel type %s)', slot, fp, ab);
        return;
    end
elseif ~isempty(nums)
    g = unique(writerGroup(ab, nums));
    if ~isscalar(g)
        why = sprintf('its channel numbers fall in %d groups by the writer''s rule', numel(g));
        return;
    end
else
    why = 'neither its file slot nor its channel numbers state its group';
    return;
end
info = struct('prefix', ab, 'filePrefix', fp, 'group', g, 'type', typeOf(ab));
end

% =========================================================================
% channel-group rows
% =========================================================================

function [rows, g, nh] = groupRows(b, info)
rows = emptyRows();
nh = struct('row', {}, 'field', {}, 'value', {}, 'why', {});
ab = info.prefix;
nums = covariateValues(b, @(cv) isChannelNumber(cv, ab));
off = covariateValues(b, @(cv) strcmp(varNode(cv), 'AFO:AFQ_0000202'));
sc = covariateValues(b, @(cv) strcmp(varNode(cv), 'NCIT:C70774'), true);
tc = covariateValues(b, @(cv) strcmp(varNode(cv), 'EMPTY:0000374'));
names = covariateText(b);
[sr, n, chunk] = timeOf(b);
nch = numel(nums);
if isempty(tc); tc = NaN(1, nch); end
if isempty(off); off = NaN(1, nch); end
if isempty(sc); sc = NaN(1, nch); end
dc = 'ephys';
if any(strcmp(ab, {'di', 'do'})); dc = 'digital'; end
for r = 1:nch
    nm = sprintf('%s%d', ab, nums(r));
    if numel(names) >= r && ~isempty(names{r}); nm = names{r}; end
    rows(end+1) = row(nm, typeOf(ab), at(tc, r), sr, at(off, r), at(sc, r), nums(r), ...
        info.group, dc); %#ok<AGROW>
end
if ~isfinite(sr)
    for r = 1:nch
        nh(end+1) = struct('row', r, 'field', 'sample_rate', 'value', NaN, 'why', ...
            'the group''s time is a key to a time value (unevenly spaced): its nominal rate has no v2 home'); %#ok<AGROW>
    end
end
g = struct('row0', 0, 'n', n, 'chunk', chunk, 'tc', tc, 'sr', sr, 'dataclass', dc);
end

function [sr, n, chunk] = timeOf(b)
% 1/spacing of the time covariate (NaN when the time is a key), and the time
% dimension's n and chunk
sr = NaN; n = NaN; chunk = NaN;
for cv = asCellOf(blockField(b, 'covariates'))
    s = cv{1};
    if isTime(getPath(s, 'variable'))
        sp = getPath(s, 'spacing');
        if isstruct(sp); sp = getPath(sp, 'value'); end
        if isnumeric(sp) && isscalar(sp) && sp > 0
            sr = 1 / double(sp);
            % as ndi.vintage.ingestedChannelList: a rate within 1e-9 of a
            % whole number is that number
            if abs(sr - round(sr)) <= 1e-9 * abs(sr); sr = round(sr); end
        end
        break;
    end
end
for d = asCellOf(blockField(b, 'dimensions'))
    if isTime(getPath(d{1}, 'term'))
        v = getPath(d{1}, 'n'); if isnumeric(v) && ~isempty(v); n = double(v); end
        v = getPath(d{1}, 'chunk'); if isnumeric(v) && ~isempty(v); chunk = double(v); end
        break;
    end
end
end

function v = covariateValues(b, pick, preferSource)
% the numbers of the first covariate PICK accepts: `numeric`
% (`source_numeric`) or `count`. PREFERSOURCE reads the source value when
% there ([scale carries the reader's unit]: the v1 scale). A covariate in the
% old numeric shape (`quantity`, `matrix`, origin/spacing blocks) is the
% error 'did2:read:oldNumericShapeReMigrate' ([no migrated database is
% kept], Jess Haley, 2026-11-19).
if nargin < 3; preferSource = false; end
v = [];
for cv = asCellOf(blockField(b, 'covariates'))
    s = cv{1};
    if ~pick(s); continue; end
    old = did2.read.oldNumericForm(s);
    if ~isempty(old)
        did2.read.refuseOldNumericShape('An ingested channel group''s covariate', old);
    end
    cands = {};
    if preferSource
        cands = {getPath(s, 'source_numeric')};
    end
    cands = [cands, {getPath(s, 'numeric'), getPath(s, 'count')}]; %#ok<AGROW>
    for c = 1:numel(cands)
        x = cands{c};
        if iscell(x) && ~isempty(x)
            y = NaN(1, numel(x));
            for i = 1:numel(x)
                if isnumeric(x{i}) && isscalar(x{i}); y(i) = double(x{i}); end
            end
            x = y;
        end
        if isnumeric(x) && ~isempty(x)
            v = double(reshape(x, 1, []));
            return;
        end
    end
end
end

function t = covariateText(b)
% the name covariate ([channel name is an identifier]): the `text` covariate
% along the channel dimension (1) whose variable is NCIT:C25364 "Identifier",
% by node
t = {};
for cv = asCellOf(blockField(b, 'covariates'))
    s = cv{1};
    if ~strcmp(varNode(s), 'NCIT:C25364'); continue; end
    x = getPath(s, 'text');
    if ~isempty(x) && isequal(double(getPath(s, 'along')), 1)
        if ischar(x); x = {x}; end
        t = cellfun(@char, reshape(x, 1, []), 'UniformOutput', false);
        return;
    end
end
end

function tf = isChannelNumber(cv, ab)
% [ingested block terms confirmed]: the channel-number covariate's variable is
% the group's channel-type term; NDI wrote the label "channel number" before
v = getPath(cv, 'variable');
tf = strcmp(textOf(getPath(v, 'node')), nodeOfPrefix(ab)) ...
    || (isempty(textOf(getPath(v, 'node'))) && strcmpi(textOf(getPath(v, 'name')), 'channel number'));
end

% =========================================================================
% the unpacked event, marker and text channels
% =========================================================================

function refs = ownerTimeReferences(ownerIds, ctx)
% the time references the owners name, in order (the epoch's clocks first)
refs = {};
for i = 1:numel(ownerIds)
    o = docOf(ctx, ownerIds{i});
    for t = edgeList(o, 'time_reference_id')
        if ~any(strcmp(refs, t{1})); refs{end+1} = t{1}; end %#ok<AGROW>
    end
end
end

function chans = eventChannels(refs, ctx)
chans = struct('obs', {}, 'abbrev', {}, 'type', {}, 'number', {}, 'group', {}, 't0', {});
seen = {};
for r = 1:numel(refs)
    for k = referrers(ctx, refs{r})
        o = ctx.docs{k};
        if ~strcmp(classOf(o), 'observation'); continue; end
        id = baseId(o);
        if any(strcmp(seen, id)); continue; end
        [ab, num] = eventCondition(o);
        if isempty(ab); continue; end
        seen{end+1} = id; %#ok<AGROW>
        chans(end+1) = struct('obs', o, 'abbrev', ab, 'type', typeOf(ab), 'number', num, ...
            'group', writerGroup(ab, num), 't0', firstStart(o, ctx)); %#ok<AGROW>
    end
end
end

function [ab, num] = eventCondition(o)
ab = ''; num = NaN;
cs = getPath(o, 'conditions');
if isempty(cs)
    for f = fieldnames(o)'
        x = o.(f{1});
        if isstruct(x) && isscalar(x) && isfield(x, 'conditions')
            cs = x.conditions;
            break;
        end
    end
end
for c = asCellOf(cs)
    a = prefixOfNode(textOf(getPath(getPath(c{1}, 'variable'), 'node')));
    if ~any(strcmp(a, {'e', 'mk', 'tx'})); continue; end
    old = did2.read.oldNumericForm(c{1});
    if ~isempty(old)
        did2.read.refuseOldNumericShape('An event channel''s number', old);
    end
    n = getPath(c{1}, 'count');
    if isempty(n); n = getPath(c{1}, 'numeric'); end
    if isnumeric(n) && isscalar(n)
        ab = a; num = double(n);
        return;
    end
end
end

function t0 = firstStart(o, ctx)
t0 = NaN;
for t = edgeList(o, 'time_reference_id')
    ref = docOf(ctx, t{1});
    v = getPath(getPath(getPath(getPath(ref, 'relative_time_reference'), 'value'), 'start'), 'seconds');
    if isnumeric(v) && isscalar(v)
        t0 = double(v);
        return;
    end
end
end

function e = evmktxOf(chans, g, ctx, readBody)
e = emptyEvmktx();
e(1).name = sprintf('evmktx_group%d_seg.nbf_1', g);
e.group = g;
e.carried = false;
e.state = 'rebuilt';
e.why = '';
e.channeltype = {chans.type};
e.channel = [chans.number];
e.T = cell(1, numel(chans));
e.D = cell(1, numel(chans));
if isempty(readBody)
    e.state = 'not read';
    e.why = 'no body reader given (ReadBody): types, numbers and order only';
    return;
end
for c = 1:numel(chans)
    o = chans(c).obs;
    own = bodyOwnedBy(ctx, baseId(o));
    if isempty(own)
        vid = edgeList(o, 'value_id');
        if ~isempty(vid); own = bodyOwnedBy(ctx, vid{1}); end
    end
    if isempty(own)
        e.state = 'not rebuilt';
        e.why = sprintf('the %s channel %d observation owns no sampled_body', chans(c).type, chans(c).number);
        return;
    end
    try
        switch chans(c).type
            case 'event'
                t = double(readBody(own));
                e.D{c} = ones(numel(t), 1);
            otherwise
                keys = edgeList(own, 'key_id');
                tb = [];
                if ~isempty(keys); tb = bodyOwnedBy(ctx, keys{1}); end
                if isempty(tb)
                    e.state = 'not rebuilt';
                    e.why = sprintf('the %s channel %d''s body is keyed to no time value body', ...
                        chans(c).type, chans(c).number);
                    return;
                end
                t = double(readBody(tb));
                d = readBody(own);
                if strcmp(chans(c).type, 'marker')
                    d = double(d);
                    if isvector(d); d = d(:); end
                else
                    % a text channel's entries, as NDI-compress's expander
                    % gives them: a 1xN cell of character rows
                    if ischar(d); d = {d}; end
                    d = cellfun(@(x) reshape(char(x), 1, []), reshape(d, 1, []), ...
                        'UniformOutput', false);
                end
                e.D{c} = d;
        end
    catch err
        e.state = 'not rebuilt';
        e.why = sprintf('reading the %s channel %d: %s', chans(c).type, chans(c).number, err.message);
        return;
    end
    if ~isfinite(chans(c).t0)
        e.state = 'not rebuilt';
        e.why = sprintf('the %s channel %d observation names no time reference start', ...
            chans(c).type, chans(c).number);
        return;
    end
    e.T{c} = t(:) + chans(c).t0;
end
[e.data, e.data_description] = eventmarktext2vector(e.channeltype, e.channel, e.T, e.D);
end

function [data, dd] = eventmarktext2vector(channeltype, channel, T, D)
% NDI-compress +ndi/+compress/eventmarktext2vector.m, re-stated: what
% compress_eventmarktext writes into the file
dd = zeros(1, 4);
data = [];
for i = 1:numel(channeltype)
    switch channeltype{i}
        case {'e', 'event'}
            dd(i, :) = [1 channel(i) 0 numel(T{i})];
            data = cat(1, data, T{i}(:));
        case {'mk', 'marker'}
            dd(i, :) = [2 channel(i) 2 numel(T{i})];
            data = cat(1, data, T{i}(:));
            data = cat(1, data, D{i}(:));
        case {'tx', 'text'}
            dd(i, :) = [3 channel(i) 3 numel(T{i})];
            data = cat(1, data, T{i}(:));
            for j = 1:numel(D{i})
                data = cat(1, data, numel(D{i}{j}));
                data = cat(1, data, double(D{i}{j}(:)));
            end
    end
end
end

% =========================================================================
% a split time group ([time group with several time channels split])
% =========================================================================

function tc = splitTimeChannel(b, cn, slot)
% the time channel a split time group's body holds: a sampled_body of a time
% group's slot whose condition "time channel" (EMPTY:0000374) has a count;
% NaN for any other body
tc = NaN;
if ~strcmp(cn, 'sampled_body') || isempty(regexp(slot, '^ti_group\d+_seg\.nbf_#$', 'once'))
    return;
end
for c = asCellOf(blockField(b, 'conditions'))
    if ~strcmp(textOf(getPath(getPath(c{1}, 'variable'), 'node')), 'EMPTY:0000374'); continue; end
    n = getPath(c{1}, 'count');
    if isempty(n); n = getPath(c{1}, 'numeric'); end
    if isnumeric(n) && isscalar(n) && isfinite(n)
        tc = double(n);
        return;
    end
end
end

function st = splitTimeOf(sb, ownerIds, ctx, readBody)
% one split time group: its columns in time-channel order, its v1 file
% names, and (READBODY) the content of each segment
[~, o] = sort([sb.number]);
sb = sb(o);
slot = sb(1).slot;
g = str2double(regexp(slot, '^ti_group(\d+)_seg', 'tokens', 'once'));
st = emptySplit();
st(1).name = slot;
st.group = g;
st.channels = [sb.number];
st.body_ids = arrayfun(@(x) baseId(x.body), sb, 'UniformOutput', false);
st.value_ids = arrayfun(@(x) strjoin(edgeList(x.body, 'owner_id'), ' '), sb, 'UniformOutput', false);
st.segments = {};
st.state = 'rebuilt';
st.why = '';
st.t0 = NaN;
st.data = {};
counts = arrayfun(@(x) memberCount(x.body), sb);
ns = NaN(1, numel(sb)); chunks = NaN(1, numel(sb));
for k = 1:numel(sb)
    [~, ns(k), chunks(k)] = timeOf(sb(k).body);
end
if numel(unique(st.channels)) ~= numel(st.channels)
    st.state = 'not rebuilt';
    st.why = sprintf('two bodies of %s hold the same time channel', slot);
    return;
end
if any(counts ~= counts(1)) || ~isequaln(ns, repmat(ns(1), size(ns))) ...
        || ~isequaln(chunks, repmat(chunks(1), size(chunks)))
    st.state = 'not rebuilt';
    st.why = sprintf(['the time channels of %s differ in their members (%s), samples or ' ...
        'chunk: one v1 file holds them side by side'], slot, mat2str(counts));
    return;
end
st.segments = arrayfun(@(m) sprintf('ti_group%d_seg.nbf_%d', g, m), 1:counts(1), ...
    'UniformOutput', false);
if isempty(readBody)
    st.state = 'not read';
    st.why = 'no body reader given (ReadBody): the columns and names only';
    return;
end
% the epoch's start: the first start on the time references the archive's
% bodies' owners name (the recording observations; a time value names none)
for i = 1:numel(ownerIds)
    st.t0 = firstStart(docOf(ctx, ownerIds{i}), ctx);
    if isfinite(st.t0); break; end
end
if ~isfinite(st.t0)
    st.state = 'not rebuilt';
    st.why = 'no owner of the archive''s bodies names a time reference with a start';
    return;
end
n = ns(1); chunk = chunks(1);
if ~isfinite(n) || ~isfinite(chunk) || chunk <= 0
    st.state = 'not rebuilt';
    st.why = sprintf('the time dimension of %s states no samples or chunk', slot);
    return;
end
cols = NaN(n, numel(sb));
for k = 1:numel(sb)
    try
        v = double(readBody(sb(k).body));
    catch err
        st.state = 'not rebuilt';
        st.why = sprintf('reading time channel t%d: %s', sb(k).number, err.message);
        return;
    end
    if numel(v) ~= n
        st.state = 'not rebuilt';
        st.why = sprintf('time channel t%d holds %d value(s), its time dimension %d', ...
            sb(k).number, numel(v), n);
        return;
    end
    cols(:, k) = v(:);
end
cols = cols + st.t0;
for m = 1:counts(1)
    r = ((m - 1) * chunk + 1):min(m * chunk, n);
    st.data{m} = cols(r, :);
end
end

function s = emptySplit()
s = struct('name', {}, 'group', {}, 'channels', {}, 'body_ids', {}, 'value_ids', {}, ...
    'segments', {}, 'state', {}, 'why', {}, 't0', {}, 'data', {});
end

function bodies = withKeyedTimeBodies(bodies, ctx)
have = cellfun(@baseId, bodies, 'UniformOutput', false);
n = numel(bodies);
for k = 1:n
    for v = edgeList(bodies{k}, 'key_id')
        tb = bodyOwnedBy(ctx, v{1});
        if ~isempty(tb) && ~any(strcmp(have, baseId(tb)))
            bodies{end+1} = tb; %#ok<AGROW>
            have{end+1} = baseId(tb); %#ok<AGROW>
        end
    end
end
end

function b = bodyOwnedBy(ctx, ownerId)
b = [];
for k = referrers(ctx, ownerId)
    d = ctx.docs{k};
    if strcmp(classOf(d), 'sampled_body') && any(strcmp(edgeList(d, 'owner_id'), ownerId))
        b = d;
        return;
    end
end
end

% =========================================================================
% the writer's rules (NDI-matlab, the locked `main`)
% =========================================================================

function g = writerGroup(ab, number)
% ndi.file.type.mfdaq_epoch_channel/create_properties: 1 + floor(number / N)
switch ab
    case {'ai', 'ao', 'ax'}, N = 400;
    case {'di', 'do'},       N = 512;
    otherwise,               N = 100000;   % event/marker/text, time
end
g = 1 + floor(double(number) / N);
end

function order = writerOrder(rows)
% create_properties: types in alphabetical order, each by channel number
types = {rows.type};
[~, ~, ti] = unique(types);
nums = [rows.number];
[~, order] = sortrows([ti(:), nums(:), (1:numel(rows))']);
order = order(:)';
end

function order = eventOrder(rows)
% create_properties: event, marker and text together, by channel number; a
% tie by type in alphabetical order (the rows are sorted by type first)
if isempty(rows); order = []; return; end
[~, ~, ti] = unique({rows.type});
[~, order] = sortrows([[rows.number]', ti(:), (1:numel(rows))']);
order = order(:)';
end

function t = typeOf(ab)
T = {'ai', 'analog_in'; 'ao', 'analog_out'; 'ax', 'auxiliary_in'; 'di', 'digital_in'; ...
    'do', 'digital_out'; 'e', 'event'; 'mk', 'marker'; 'tx', 'text'; 't', 'time'};
t = T{strcmp(T(:, 1), ab), 2};
end

function [prefixes, nodes] = channelTypeNodes()
% did2.convert.channelType's table (the test checks they agree), with the
% node a text channel had before [text channel replaces NCIT Text]
prefixes = {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx', 'tx'};
nodes = {'EMPTY:0000370', 'EMPTY:0000371', 'EMPTY:0000372', 'EMPTY:0000373', ...
    'EMPTY:0000374', 'EMPTY:0000375', 'EMPTY:0000376', 'EMPTY:0000377', ...
    'NCIT:C52095', 'EMPTY:0000410', 'NCIT:C25704'};
end

function ab = prefixOfNode(node)
[p, n] = channelTypeNodes();
ab = '';
i = find(strcmp(n, node), 1);
if ~isempty(i); ab = p{i}; end
end

function node = nodeOfPrefix(ab)
[p, n] = channelTypeNodes();
node = n{find(strcmp(p, ab), 1)};
end

% =========================================================================
% reading a body's bytes
% =========================================================================

function v = readFloat64(b, locate)
% members body_data_0.. at LOCATE(entry), little-endian float64, shaped
if nargin < 2 || isempty(locate); locate = @defaultLocate; end
infos = asCellOf(getPath(getPath(b, 'files'), 'file_info'));
names = cellfun(@(f) textOf(getPath(f, 'name')), infos, 'UniformOutput', false);
v = [];
for m = 1:numel(infos)
    i = find(strcmp(names, sprintf('body_data_%d', m - 1)), 1);
    if isempty(i)
        error('did2:convert:roundtrip:noMember', 'The body has no member body_data_%d.', m - 1);
    end
    p = locate(infos{i});
    if isempty(p)
        error('did2:convert:roundtrip:notHere', 'Member body_data_%d is not on this computer.', m - 1);
    end
    fid = fopen(p, 'r', 'ieee-le');
    x = fread(fid, Inf, 'float64');
    fclose(fid);
    v = [v; x]; %#ok<AGROW>
end
dims = [];
for d = asCellOf(blockField(b, 'dimensions'))
    n = getPath(d{1}, 'n');
    if isnumeric(n) && isscalar(n); dims(end+1) = double(n); end %#ok<AGROW>
end
if numel(dims) >= 2 && prod(dims) == numel(v)
    if strcmpi(blockField(b, 'datum_order'), 'C')
        v = permute(reshape(v, fliplr(dims)), numel(dims):-1:1);
    else
        v = reshape(v, dims);
    end
end
end

function v = readBody(b, locate)
% a JSON body (a text channel's entries) as a 1xN cell of character rows;
% any other, readFloat64
if nargin < 2 || isempty(locate); locate = @defaultLocate; end
fmt = getPath(blockField(b, 'format'), 'node');
if ~strcmp(textOf(fmt), 'EDAM:format_3464')
    v = readFloat64(b, locate);
    return;
end
infos = asCellOf(getPath(getPath(b, 'files'), 'file_info'));
names = cellfun(@(f) textOf(getPath(f, 'name')), infos, 'UniformOutput', false);
i = find(strcmp(names, 'body_data_0'), 1);
if isempty(i)
    error('did2:convert:roundtrip:noMember', 'The body has no member body_data_0.');
end
p = locate(infos{i});
if isempty(p)
    error('did2:convert:roundtrip:notHere', 'Member body_data_0 is not on this computer.');
end
fid = fopen(p, 'r');
bytes = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);
x = jsondecode(native2unicode(reshape(bytes, 1, []), 'UTF-8'));
if ischar(x); x = {x}; elseif isempty(x) && ~iscell(x); x = {}; end
if ~iscell(x) || ~all(cellfun(@ischar, x))
    error('did2:convert:roundtrip:notText', 'The body does not hold a JSON array of strings.');
end
v = cellfun(@(e) reshape(e, 1, []), reshape(x, 1, []), 'UniformOutput', false);
end

function p = defaultLocate(fi)
p = '';
for L = asCellOf(getPath(fi, 'locations'))
    loc = textOf(getPath(L{1}, 'location'));
    if ~isempty(loc) && exist(loc, 'file') == 2
        p = loc;
        return;
    end
end
end

% =========================================================================
% small readers (kept here so the rebuild runs on plain structs)
% =========================================================================

function rows = emptyRows()
rows = struct('name', {}, 'type', {}, 'time_channel', {}, 'sample_rate', {}, ...
    'offset', {}, 'scale', {}, 'number', {}, 'group', {}, 'dataclass', {});
end

function r = row(name, type, tc, sr, off, sc, num, g, dc)
r = struct('name', name, 'type', type, 'time_channel', tc, 'sample_rate', sr, ...
    'offset', off, 'scale', sc, 'number', num, 'group', g, 'dataclass', dc);
end

function e = emptyEvmktx()
e = struct('name', {}, 'group', {}, 'carried', {}, 'state', {}, 'why', {}, 'channeltype', {}, ...
    'channel', {}, 'T', {}, 'D', {}, 'data', {}, 'data_description', {});
end

function x = at(v, r)
x = NaN;
if numel(v) >= r; x = v(r); end
end

function [n, ndiNames, fileIndex] = memberCount(b)
% the members in segment order: body_data_<k> is segment k+1; a member still
% named by NDI (`<p>_group<g>_seg.nbf_<n>`, which NDI-matlab's readers also
% read) is segment n and keeps its name (NDINAMES, '' for body_data_<k>);
% FILEINDEX, each one's position in files.file_info
infos = asCellOf(getPath(getPath(b, 'files'), 'file_info'));
pos = []; nm = {}; idx = [];
for i = 1:numel(infos)
    f = textOf(getPath(infos{i}, 'name'));
    k = regexp(f, '^body_data_(\d+)$', 'tokens', 'once');
    t = regexp(f, '^[a-z]+_group\d+_seg\.nbf_(\d+)$', 'tokens', 'once');
    if ~isempty(k)
        pos(end+1) = str2double(k{1}) + 1; nm{end+1} = ''; idx(end+1) = i; %#ok<AGROW>
    elseif ~isempty(t)
        pos(end+1) = str2double(t{1}); nm{end+1} = f; idx(end+1) = i; %#ok<AGROW>
    end
end
[~, o] = sort(pos);
ndiNames = nm(o);
fileIndex = idx(o);
n = numel(o);
end

function v = blockField(b, name)
% a body field, from `data_body` or `data` (where did2.build puts it)
v = [];
for blk = {'data_body', 'data', 'opaque_body', 'sampled_body'}
    x = getPath(getPath(b, blk{1}), name);
    if ~isempty(x); v = x; break; end
end
if ischar(v) || isstring(v); v = char(v); end
if isempty(v) && any(strcmp(name, {'filename', 'datum_order'})); v = ''; end
end

function tf = isTime(t)
tf = isstruct(t) && (strcmp(textOf(getPath(t, 'node')), 'om:Time') ...
    || strcmpi(textOf(getPath(t, 'name')), 'time'));
end

function n = varNode(cv)
n = textOf(getPath(getPath(cv, 'variable'), 'node'));
end

function v = getPath(s, f)
v = [];
if iscell(s) && ~isempty(s); s = s{1}; end
if isstruct(s) && ~isempty(s) && isfield(s, f)
    v = s(1).(f);
end
end

function s = textOf(x)
s = '';
if ischar(x); s = x; elseif isstring(x) && isscalar(x); s = char(x); end
end

function c = asCellOf(x)
if iscell(x); c = reshape(x, 1, []);
elseif isstruct(x); c = num2cell(reshape(x, 1, []));
else; c = {};
end
end

function c = classOf(b)
c = textOf(getPath(getPath(b, 'document_class'), 'class_name'));
end

function id = baseId(b)
id = textOf(getPath(getPath(b, 'base'), 'id'));
end

function ids = edgeList(b, name)
ids = {};
deps = asCellOf(getPath(b, 'depends_on'));
for k = 1:numel(deps)
    d = deps{k};
    if ~strcmp(textOf(getPath(d, 'name')), name); continue; end
    v = getPath(d, 'value');
    if isempty(v); v = getPath(d, 'document_id'); end
    if iscell(v)
        for j = 1:numel(v)
            if ~isempty(v{j}); ids{end+1} = char(v{j}); end %#ok<AGROW>
        end
    elseif ~isempty(v)
        ids{end+1} = char(v); %#ok<AGROW>
    end
end
end

function ctx = indexOf(docs)
ctx = struct('docs', {docs}, 'byId', containers.Map('KeyType', 'char', 'ValueType', 'double'), ...
    'referrers', containers.Map('KeyType', 'char', 'ValueType', 'any'));
for k = 1:numel(docs)
    id = baseId(docs{k});
    if ~isempty(id) && ~isKey(ctx.byId, id); ctx.byId(id) = k; end
    deps = asCellOf(getPath(docs{k}, 'depends_on'));
    for j = 1:numel(deps)
        nm = textOf(getPath(deps{j}, 'name'));
        if strcmp(nm, 'session_id'); continue; end
        for t = edgeList(struct('depends_on', deps{j}), nm)
            if isKey(ctx.referrers, t{1})
                ctx.referrers(t{1}) = [ctx.referrers(t{1}), k];
            else
                ctx.referrers(t{1}) = k;
            end
        end
    end
end
end

function d = docOf(ctx, id)
d = [];
if ~isempty(id) && isKey(ctx.byId, id); d = ctx.docs{ctx.byId(id)}; end
end

function idx = referrers(ctx, id)
idx = [];
if ~isempty(id) && isKey(ctx.referrers, id); idx = unique(ctx.referrers(id)); end
idx = reshape(idx, 1, []);
end
