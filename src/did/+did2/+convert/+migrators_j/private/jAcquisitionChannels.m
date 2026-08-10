function body = jAcquisitionChannels(preBody, deviceName, channelSpec, label)
%JACQUISITIONCHANNELS One half of a v1 syncrule's device pair -> `acquisition_channels`.
%
%   BODY = jAcquisitionChannels(PREBODY, DEVICENAME, CHANNELSPEC, LABEL) returns
%   an `acquisition_channels` body, or [] when DEVICENAME is empty (no device =>
%   nothing to say; the caller must then NOT emit the edge).
%
%   ---------------------------------------------------------------------
%   WHAT THE SOURCE ACTUALLY CARRIES -- AND WHERE THE PLAN IS DESCRIBING
%   A DIFFERENT STRING
%   ---------------------------------------------------------------------
%   `V_eta_clock_alignment_cluster_plan.md` motivates this class with "The
%   devicestring decomposition", 'mydevice:ai27-28,45,88;di1-4'. That is
%   `ndi.daq.daqsystemstring`, which lives on an EPOCHPROBEMAP, not on a
%   syncrule. What a syncrule's `parameters` carries is the device name and the
%   channel ALREADY SPLIT APART, and never more than one channel per device:
%
%     git show origin/main:src/ndi/+ndi/+time/+syncrule/commonTriggersOverlappingEpochs.m
%       :36  parameters = struct('daqsystem1_name','', 'daqsystem2_name','', ...
%                'daqsystem_ch1','', 'daqsystem_ch2','', ...
%                'epochclocktype','dev_local_time', ...
%                'minEmbeddedFileOverlap', 1, 'errorOnFailure', true);
%       :29  % daqsystem_ch1 ('')  | The channel to read on daq system 1 (e.g., 'dep1')
%       :369 function [ch_type, ch_num] = parse_channel(ch_str)
%            % e.g. 'dep1' -> 'dep', 1
%            first_digit = find(isstrprop(ch_str, 'digit'), 1);
%            ch_type = ch_str(1:first_digit-1);
%            ch_num  = str2double(ch_str(first_digit:end));
%
%     git show origin/main:src/ndi/+ndi/+time/+syncrule/filefind.m
%       :32  parameters = struct('number_fullpath_matches', 1, ...
%                'syncfilename','syncfile.txt', ...
%                'daqsystem1','mydaq1','daqsystem2','mydaq2');   % names, NO channels
%
%   So NDI's own reader handles exactly ONE type + ONE number, and `filefind`
%   names devices with no channels at all. The parser below is a strict SUPERSET
%   of `parse_channel`: it reads 'dep1' the same way, and additionally accepts
%   the ranges/lists/semicolon groups that `ndi.daq.daqsystemstring` documents,
%   so that a devicestring stored in this slot degrades to the grouped
%   `channels[]` the plan specifies instead of to `str2double(...) == NaN`, which
%   is what NDI's own parse_channel would produce. Nothing in the corpus is known
%   to use that form -- it is accepted, not assumed.
%
%   ---------------------------------------------------------------------
%   `acquisition_system_id` IS DELIBERATELY NOT EMITTED
%   ---------------------------------------------------------------------
%   The edge is OPTIONAL in the schema and is documented there as "UNTYPED for
%   now: `acquisition_system` is #59's class and does not exist yet". Two facts
%   about that, both checked rather than repeated:
%
%     * the class DOES exist -- schemas/V_eta/stable/acquisition_system.json,
%       maturity stable, entity subclass. The schema comment is stale.
%     * it makes no difference here. What a syncrule stores is a device NAME
%       ('vhtaste_sync'), and `must_refer_to_document_class` needs a DOCUMENT
%       ID. Resolving name -> id needs the migrated-id graph, which a
%       single-document migrator does not have -- the same wall that defers
%       distance_metadata's endpoint relation and the ensemble's member_of.
%
%   Emitting the edge blank would put another 100%-empty edge into the census
%   for no gain, so the name is carried on `base.name` -- where it stays
%   string-matchable, exactly as v1 matched it -- and the edge is omitted until
%   the second pass can fill it.
%
%   Shared helper for the Brainstorm-J (+migrators_j) clock-alignment migrators.

body = [];
deviceName = char(deviceName);
channelSpec = char(channelSpec);
[specDevice, groups] = parseChannelSpec(channelSpec);
if isempty(deviceName)
    % A bare devicestring in the channel slot still names its device.
    deviceName = specDevice;
end
if isempty(deviceName)
    return;   % NO DEVICE => NO DOCUMENT
end

sessionId = '';
datestamp = '';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp');  datestamp  = preBody.base.datestamp;  end
end
if isempty(datestamp); datestamp = '2024-01-01T00:00:00.000Z'; end

channels = struct('type', {}, 'numbers', {});
for k = 1:numel(groups)
    channels(end+1) = struct( ...
        'type',    jOntologyTerm('', groups(k).type), ...
        'numbers', groups(k).numbers); %#ok<AGROW>
end

body = struct();
body.document_class = struct('class_name', 'acquisition_channels', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
% acquisition_system_id OMITTED -- see the header. An absent optional edge and a
% blank one are the same to a reader and very different to the census.
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', deviceName, 'datestamp', datestamp);
body.acquisition_channels = struct('channels', {channels});
end

% ===================== the channel-spec parser =============================

function [deviceName, groups] = parseChannelSpec(spec)
%PARSECHANNELSPEC 'dep1' -> one group {type 'dep', numbers 1}.
%   Also accepts the full ndi.daq.daqsystemstring form documented at
%   +ndi/+daq/daqsystemstring.m:15-19 -- 'DEVICENAME:CT####', ';' between
%   channel-TYPE GROUPS, '-' for a run and ',' between entries -- and the
%   '_t<threshold>' suffix that file strips before parsing numbers.
deviceName = '';
groups = struct('type', {}, 'numbers', {});
if isempty(spec)
    return;
end
spec(isspace(spec)) = [];
colon = find(spec == ':', 1);
if ~isempty(colon)
    deviceName = spec(1:colon-1);
    spec = spec(colon+1:end);
end
if isempty(spec)
    return;
end
segments = strsplit(spec, ';');
for s = 1:numel(segments)
    seg = segments{s};
    if isempty(seg); continue; end
    firstNumber = find(~isletter(seg), 1);
    if isempty(firstNumber)
        % A type with no channel numbers. Kept: the TYPE is still a fact.
        groups(end+1) = struct('type', seg, 'numbers', []); %#ok<AGROW>
        continue;
    end
    chType = seg(1:firstNumber-1);
    remainder = seg(firstNumber:end);
    tIdx = strfind(remainder, '_t');
    if ~isempty(tIdx)
        remainder = remainder(1:tIdx(1)-1);
    end
    groups(end+1) = struct('type', chType, ...
        'numbers', expandChannelList(remainder)); %#ok<AGROW>
end
end

function nums = expandChannelList(txt)
%EXPANDCHANNELLIST '27-28,45,88' -> [27 28 45 88].
nums = [];
if isempty(txt); return; end
parts = strsplit(txt, ',');
for k = 1:numel(parts)
    p = parts{k};
    if isempty(p); continue; end
    dash = find(p == '-', 1);
    if isempty(dash)
        v = str2double(p);
        if ~isnan(v); nums(end+1) = v; end %#ok<AGROW>
        continue;
    end
    lo = str2double(p(1:dash-1));
    hi = str2double(p(dash+1:end));
    if isnan(lo) || isnan(hi) || hi < lo; continue; end
    nums = [nums, lo:hi]; %#ok<AGROW>
end
end
