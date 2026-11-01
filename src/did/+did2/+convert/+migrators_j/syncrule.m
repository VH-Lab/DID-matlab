function bodies = syncrule(preBody)
%SYNCRULE Brainstorm-J migrator: did_v1 `syncrule` -> `clock_alignment_configuration`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   1 -> 1 or 2:  the configuration and (when the source names an
%   implementation) one `software` entity.
%
%   THE RIGS (Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md [sync configuration links its rigs] and
%   [sync rule direction is recorded], amending [sync configuration] below):
%   the configuration links the two `acquisition_system` documents directly,
%   role-named -- `from_acquisition_system_id` is v1 daqsystem1,
%   `to_acquisition_system_id` is v1 daqsystem2 (a filefind rule maps
%   daqsystem1's clock to daqsystem2's, NDI +time/+syncrule/filefind.m
%   `apply`, so the pair is ORDERED) -- and a rule's trigger channels
%   (daqsystem_ch1 / daqsystem_ch2) are method parameters. A migrated sync
%   rule writes NO `acquisition_channels` documents. The two edges are
%   OPTIONAL on did-schema until NDI reads them (NDI-matlab
%   ndi.vintage.syncruleParameters reads both shapes); then did-schema removes
%   `acquisition_channels_id` from the class.
%
%   THE TRIGGER CHANNELS (Decided by Jess Haley, 2026-10-30, did-schema
%   V_eta_go_forward_class_audit.md [trigger channels named by their link]):
%   the two trigger channels are the method parameters labelled
%   'from trigger channel' (v1 daqsystem_ch1, the channel read on daqsystem1,
%   commonTriggersOverlappingEpochs.m:29, so it goes with
%   `from_acquisition_system_id`) and 'to trigger channel' (v1 daqsystem_ch2,
%   daqsystem2's, with `to_acquisition_system_id`), not the v1 names
%   'daqsystem ch1' / 'daqsystem ch2' written before. NDI-matlab
%   ndi.vintage.syncruleParameters reads both (NDI-matlab #1101), and
%   did2.convert.roundtrip.syncrule reads both back to daqsystem_ch1 / _ch2.
%
%   TEAM-SIGN-OFF [sync configuration], jess@walthamdatascience.com / 2026-08-08:
%     "syncrule -> `clock_alignment_configuration` (parameters DECLARED not
%      bagged, devices become `acquisition_channels_#` edges, EXACTLY 2 and
%      UNORDERED); syncgraph -> `clock_alignment_policy`, earning its existence
%      on membership; both preserve base.id, and syncrule_id_# is un-tightened
%      back to NDI's optional."
%
%   ---------------------------------------------------------------------
%   GROUND TRUTH -- THE TEMPLATE, THE SCHEMA, AND THE FOUR WRITERS
%   ---------------------------------------------------------------------
%     git show origin/main:src/ndi/ndi_common/database_documents/daq/syncrule.json
%        "syncrule": { "ndi_syncrule_class": "ndi.time.syncrule",
%                      "parameters": [] }
%        (no depends_on at all)
%     git show origin/main:src/ndi/ndi_common/schema_documents/daq/syncrule_schema.json
%        "depends_on": [ ],  ndi_syncrule_class (string), parameters (structure)
%     git show origin/main:src/ndi/+ndi/+time/syncrule.m:183-187
%        ndi.document('syncrule', 'syncrule.ndi_syncrule_class', class(obj), ...
%           'base.id', obj.id(), 'base.session_id', ndi.session.empty_id(), ...
%           'syncrule.parameters', obj.parameters);
%
%   `parameters` is declared as an untyped structure, so the TEMPLATE says
%   nothing about what is inside. The four WRITERS do, and each set is CLOSED --
%   validated field-by-field in `isvalidparameters` with explicit defaults:
%
%     filematch.m:25    number_fullpath_matches (2)
%     filefind.m:32     number_fullpath_matches (1), syncfilename,
%                       daqsystem1, daqsystem2
%     commonTriggersOverlappingEpochs.m:36
%                       daqsystem1_name, daqsystem2_name, daqsystem_ch1,
%                       daqsystem_ch2, epochclocktype, minEmbeddedFileOverlap,
%                       errorOnFailure
%     randomPulses.m:34 the same, minus minEmbeddedFileOverlap
%
%   That is why `parameters` is not migrated as a bag: it is the union of four
%   closed sets, so all of it is DECLARED and queryable. Two spellings differ
%   between rules for the same fact -- `daqsystem1_name` (ctoe, randomPulses) vs
%   `daqsystem1` (filefind) -- and both are read below.
%
%   `errorOnFailure` WAS DROPPED (repair 5 in the plan): throw-or-return-quietly
%   is runtime behaviour, not a fact about the experiment. [small unread
%   settings] (3) (Jess Haley, 2026-10-26): on the configuration arms every
%   parameter the migrator does not read (errorOnFailure, filefind's
%   daqsystem1/2 when no stamped system pair reads them, ...) becomes one more
%   method parameter (jParameterList's entry); one that cannot be written (a
%   number that is not finite) carries the rule whole as v1.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NO DEVICE PAIR => NO CONFIGURATION. PASS THE DOCUMENT THROUGH.
%   ---------------------------------------------------------------------
%   `acquisition_channels_#` is declared EXACTLY 2 (min_count 2, max_count 2 --
%   #63 landed, so this is checkable rather than prose), and
%   did2.validate.silentLoss counts the EDGES PRESENT against that range
%   (silentLoss.m:118-126, countFamily at :243). `filematch` names NO devices at
%   all -- its whole parameter set is `number_fullpath_matches` -- so a filematch
%   syncrule cannot produce two `acquisition_channels` documents, and converting
%   it would emit a configuration that violates its own declared cardinality
%   while validating clean (family violations are REPORT-ONLY today).
%
%   So a syncrule that does not name two devices is PASSED THROUGH, the shape
%   used for fitcurve / openminds_stimulus / probe_geometry. This is safe in a
%   way the image_stack passthrough was not: `syncrule` is NOT phase-8 deleted --
%   schemas/V_eta/stable/syncrule.json is present and stable -- so the carried
%   document has a schema to validate against, and its two declared fields
%   (`ndi_syncrule_class`, `parameters`) are exactly what the v1 body holds.
%   The passthrough is also VISIBLE: v1_to_v2 counts an identity return in
%   `unconverted_by_class`, so a corpus where the conversion silently stops
%   working shows up as a number rather than as nothing.
%
%   base.id IS PRESERVED ON BOTH BRANCHES, which is what makes the guard free:
%   `syncgraph`'s `syncrule_id_#` edges and `syncrule_mapping`'s `syncrule_id`
%   edge resolve whether this document converted or passed through, because
%   must_refer is DECLARATIVE (existence-only), not type-checked.
%
%   ---------------------------------------------------------------------
%   WHAT THIS DOES *NOT* PRESERVE, STATED PLAINLY
%   ---------------------------------------------------------------------
%   `ndi.time.syncrule`'s constructor rebuilds a live rule object from
%   `varargin{2}.document_properties.syncrule.parameters` (syncrule.m:21). On a
%   converted document that path is gone -- by design, it is what "parameters
%   DECLARED not bagged" means. That is an NDI-SIDE reader change, not something
%   a migrator can carry, and it is not a QUERY: `syncrule.parameters` is never
%   a `ndi.query` path anywhere on origin/main (checked; the only two hits in
%   .m files are the constructor read and the writer). The one live QUERY in
%   this cluster reads `syncrule_mapping`, which this build leaves untouched --
%   see syncrule_mapping.m.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI syncrule.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+time/syncrule.m newdocument writes it
%   for the four rules). Every v1 field and where it goes;
%   did2.convert.roundtrip.syncrule rebuilds the v1 document and
%   testRawV1RoundTripDaq compares the two:
%
%     base.id, session_id, datestamp  -> the clock_alignment_configuration's
%     base.name                       -> not written (the writer leaves '')
%     syncrule.ndi_syncrule_class     -> the software entity's name
%     syncrule.parameters.*           -> the method parameters (named), the
%                                        clock (epochclocktype), and, on the
%                                        resolved device-pair fold, the
%                                        from / to acquisition_system edges
%                                        (filefind daqsystem1/2; the channel
%                                        rules' daqsystem1_name/2_name). The
%                                        channel strings daqsystem_ch1/_ch2
%                                        are the method parameters 'from
%                                        trigger channel' / 'to trigger
%                                        channel' ([trigger channels named
%                                        by their link], 2026-10-30).
%   A rule that does not fold (any device-pair rule in pass 1, before its
%   systems are resolved) passes through unchanged, as before.
%
%   What the renamed path would have discarded is carried, carry-100, as
%   before; a field or edge no part of this migrator reads now carries the
%   document whole as v1 (private/jRawAccount, jRawCarry; carry-100, [fields outside the template
%   are malformed]).

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above). Every field inside `parameters` is
% accounted for below (read, or a method parameter, or carry-008). A body
% did2.convert.resolveClockAlignment hands back (stamped did_v2) was accounted
% for in pass 1; its transient `resolved_acquisition_system_id` stamps are
% read, never emitted.
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, ...
    struct('syncrule', {{'ndi_syncrule_class', 'parameters'}}), ...
    {'^resolved_acquisition_system_id$'});
if jRawCarry('syncrule', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

block = struct();
if isfield(preBody, 'syncrule') && isstruct(preBody.syncrule)
    block = preBody.syncrule;
end
params = struct();
if isfield(block, 'parameters') && isstruct(block.parameters) && isscalar(block.parameters)
    params = block.parameters;
end

% `parameters` is an IMMEDIATE field of the `syncrule` block, so universalRenames
% snake_cases the key `parameters` itself but NOT what is inside it: every read
% below is one level down and therefore keeps its raw v1 casing. Read snake-first
% with a camelCase fallback (the standing +migrators_j rule).
name1 = jGetCharAny(params, {'daqsystem1_name', 'daqsystem1', 'daqsystem1Name'});
name2 = jGetCharAny(params, {'daqsystem2_name', 'daqsystem2', 'daqsystem2Name'});
ch1   = jGetCharAny(params, {'daqsystem_ch1', 'daqsystemCh1'});
ch2   = jGetCharAny(params, {'daqsystem_ch2', 'daqsystemCh2'});

% the device each end names: its daqsystem name, or the device half of a
% devicestring in the channel slot ('dev:ai1'). No `acquisition_channels`
% document is built: that class is retired (Jess Haley 2026-11-01, did-schema
% [probe wiring is a relation]; the rule's ends point at the systems).
channelsA = namedDevice(name1, ch1);
channelsB = namedDevice(name2, ch2);

% THE GUARD, AMENDED 2026-08-18 for the FILE-BASED rule. TEAM-SIGN-OFF
% [sync configuration amendment 1] (DID-schema V_eta_clock_alignment_cluster_
% plan.md): a rule that names NO device pair -- a `filematch` rule, whose whole
% parameter set is `number_fullpath_matches` -- is STILL a real alignment rule
% (its apply() returns an identity timemapping when two epochs share >=N
% filenames), so it becomes a `clock_alignment_configuration` with ZERO
% acquisition_channels and its criterion carried in the fields the schema
% already declares. `acquisition_channels_#` was relaxed to {0,2} in the same
% sign-off to make room for it.
%
% THREE CASES, and only the middle one is new:
%   * BOTH channels present  -> the device-pair configuration (unchanged).
%   * NEITHER present, but a file criterion IS  -> the channel-less
%     configuration (this amendment).
%   * exactly one present, or neither with no criterion  -> PASSTHROUGH. A
%     half-specified device pair would lose its one named device if flattened to
%     a channel-less config, and a rule with neither devices nor a criterion is
%     genuinely empty. `namedDevice` is NOT widened -- its refusal
%     stays correct (inventing an empty channel is the invented-empty-edge
%     pattern this repository has paid for six times).
haveBoth    = ~isempty(channelsA) && ~isempty(channelsB);
haveNeither = isempty(channelsA) && isempty(channelsB);
minPaths    = readNumber(params, {'number_fullpath_matches', 'numberFullpathMatches'});
isFileBased = ~isempty(minPaths);
% PASS 1 PASSES A DEVICE-PAIR RULE THROUGH (v1 form). The configuration
% names its two systems by `from_acquisition_system_id` /
% `to_acquisition_system_id` EDGES, and the v1 rule names them by NAME;
% resolving a name to the system's id needs the batch, which a single-document
% migrator does not have. The batch pass below supplies it. (Here
% namedDevice only tells a named device from none.)
%
% THE BATCH SEAM (did2.convert.resolveClockAlignment, the device-pair arm). A
% device-pair rule names its two systems by NAME: `filefind` as daqsystem1 /
% daqsystem2 (filefind.m:32), commonTriggersOverlappingEpochs and randomPulses
% as daqsystem1_name / daqsystem2_name with their trigger channels
% daqsystem_ch1 / daqsystem_ch2. The batch pass resolves each name, within the
% rule's own session, to exactly one migrated `acquisition_system` and STAMPS
% the two ids here, in order (daqsystem1's first), as transient
% `resolved_acquisition_system_id` deps, then re-runs this migrator. With
% exactly two stamps and both names under the spelling that rule's writer
% uses, the rule becomes the device-pair configuration: the first stamp is
% its `from_acquisition_system_id`, the second its `to_acquisition_system_id`
% ([sync configuration links its rigs], [sync rule direction is recorded]),
% and the channel strings are the method parameters 'from trigger channel' /
% 'to trigger channel' ([trigger channels named by their link]). The stamp
% is read and discarded: every edge below is set BY NAME. Without the stamp
% (pass 1, or a name the pass could not resolve to exactly one system) the
% rule passes through exactly as before.
resolved = stampedSystemIds(preBody);
nameKeys = systemNameKeys(jGetCharAny(block, {'ndi_syncrule_class', 'ndiSyncruleClass'}));
if numel(resolved) == 2 && ~isempty(nameKeys) ...
        && ~isempty(jGetChar(params, nameKeys{1})) && ~isempty(jGetChar(params, nameKeys{2}))
    if carryUnwritable(preBody, params, nameKeys)
        bodies = {src};
        return;
    end
    [cfg, software] = configuration(preBody, block, resolved, nameKeys);
    bodies = [{cfg}, software];
    return;
end

if ~(haveNeither && isFileBased)
    bodies = {src};
    return;
end

if carryUnwritable(preBody, params, {})
    bodies = {src};
    return;
end
[cfg, software] = configuration(preBody, block, {}, {});
bodies = [{cfg}, software];
end

function keys = systemNameKeys(implClass)
%SYSTEMNAMEKEYS The two parameters that name a rule's systems, as its writer
%   spells them ({} for a rule that names none). filefind.m:32 writes
%   daqsystem1 / daqsystem2; commonTriggersOverlappingEpochs.m:36 and
%   randomPulses.m:34 write daqsystem1_name / daqsystem2_name. Reading only the
%   writer's spelling keeps the round trip exact: the inverse names the two
%   systems back under the key the rule's class implies.
switch char(implClass)
    case 'ndi.time.syncrule.filefind'
        keys = {'daqsystem1', 'daqsystem2'};
    case {'ndi.time.syncrule.commonTriggersOverlappingEpochs', ...
            'ndi.time.syncrule.randomPulses'}
        keys = {'daqsystem1_name', 'daqsystem2_name'};
    otherwise
        keys = {};
end
end

function tf = carryUnwritable(preBody, params, nameKeys)
%CARRYUNWRITABLE True (with a `carried_as_v1` note) when an unread parameter
%   cannot be written as a method parameter ([small unread settings] (3), Jess
%   Haley, 2026-10-26).
[~, unwritable] = unreadParameters(params, nameKeys);
tf = ~isempty(unwritable);
if tf
    % carry-register: carry-008
    did2.convert.reportNote('carried_as_v1', 'syncrule', char(preBody.base.id), ...
        ['[carry-008] unplaced: ' strjoin(strcat('syncrule.parameters.', unwritable), ', ')]);
end
end

function [entries, unwritable] = unreadParameters(params, nameKeys)
%UNREADPARAMETERS The parameters configuration() does not read, as method
%   parameter entries (jParameterList: a number as `quantity`, text as `text`,
%   anything else JSON-encoded as `text`), and the names of those that cannot
%   be written: a number that is not finite (an entry's quantity is finite, and
%   JSON-encoding loses NaN / Inf). NAMEKEYS: the two parameters the
%   stamped-pair arm read as the system names (they are the from / to edges);
%   {} on the file-based arm. A channel string under the writer's spelling
%   (daqsystem_ch1 / _ch2) is read by configuration() as 'from trigger
%   channel' / 'to trigger channel' ([trigger channels named by their link],
%   Jess Haley, 2026-10-30); any other spelling stays a method parameter by
%   its own name, so the round trip rebuilds it as it was.
entries = [];
unwritable = {};
if ~isstruct(params) || ~isscalar(params)
    return;
end
read = {};
read = [read, consumedChar(params, {'syncfilename', 'syncFilename', 'sync_filename'})];
read = [read, consumedChar(params, {'epochclocktype', 'epochClockType', 'epoch_clock_type'})];
read = [read, consumedNumber(params, {'number_fullpath_matches', 'numberFullpathMatches'})];
read = [read, consumedNumber(params, {'minEmbeddedFileOverlap', 'min_embedded_file_overlap'})];
% the trigger channels, written by configuration() under the link they belong
% to ([trigger channels named by their link], Jess Haley, 2026-10-30)
for chKey = {'daqsystem_ch1', 'daqsystem_ch2'}
    if ~isempty(channelText(params, chKey{1}))
        read{end+1} = chKey{1}; %#ok<AGROW>
    end
end
read = [read, reshape(nameKeys, 1, [])];
rest = struct();
fns = fieldnames(params);
for k = 1:numel(fns)
    if any(strcmp(read, fns{k})); continue; end
    v = params.(fns{k});
    if (isnumeric(v) || islogical(v)) && ~isempty(v) && ~all(isfinite(double(v(:))))
        unwritable{end+1} = fns{k}; %#ok<AGROW>
        continue;
    end
    rest.(fns{k}) = v;
end
entries = jParameterList(rest);
end

function name = consumedChar(params, names)
% the field jGetCharAny reads for NAMES ({} when none)
name = {};
for k = 1:numel(names)
    if ~isempty(jGetChar(params, names{k}))
        name = names(k);
        return;
    end
end
end

function t = channelText(params, name)
%CHANNELTEXT A trigger channel string ('' when NAME is absent, empty or not
%   text). Text only: a channel that is not text stays a method parameter by
%   its own name (jParameterList), so the round trip rebuilds its type.
t = '';
if ~isstruct(params) || ~isscalar(params) || ~isfield(params, name)
    return;
end
v = params.(name);
if ischar(v) && (isrow(v) || isempty(v))
    t = v;
elseif isstring(v) && isscalar(v)
    t = char(v);
end
end

function name = consumedNumber(params, names)
% the field readNumber reads for NAMES ({} when none)
name = {};
for k = 1:numel(names)
    if ~isempty(readNumber(params, names(k)))
        name = names(k);
        return;
    end
end
end

function [cfg, software] = configuration(preBody, block, systemIds, nameKeys)
%CONFIGURATION The `clock_alignment_configuration` both folding branches emit.
%   One builder for the file-based (filematch) branch and the resolved
%   device-pair branch, so the two cannot drift: base.id preserved, the
%   declared parameters as inline `method.parameters`, the implementation
%   class as a `software` entity, and SYSTEMIDS (none, or daqsystem1's then
%   daqsystem2's) as the `from_acquisition_system_id` /
%   `to_acquisition_system_id` edges.
implClass = jGetCharAny(block, {'ndi_syncrule_class', 'ndiSyncruleClass'});
[software, swId] = jSyncSoftware(preBody, implClass);

% The rule's settings are its inline `method.parameters` (did-schema #88,
% V_eta_method_plan.md: one method shape; the three settings were their own
% fields before). A filefind rule carries two of them (number_fullpath_matches,
% syncfilename); its daqsystem1 / daqsystem2 NAMES are the from / to edges, not
% entries.
entries = {};
minPaths = readNumber(params0(block), {'number_fullpath_matches', 'numberFullpathMatches'});
if ~isempty(minPaths)
    entries{end+1} = did2.build.parameter(jLabel('minimum matching file paths'), ...
        'Count', minPaths);
end
syncFile = jGetCharAny(params0(block), {'syncfilename', 'syncFilename', 'sync_filename'});
if ~isempty(syncFile)
    entries{end+1} = did2.build.parameter(jLabel('sync file name'), 'Text', syncFile);
end
minOverlap = readNumber(params0(block), {'minEmbeddedFileOverlap', 'min_embedded_file_overlap'});
if ~isempty(minOverlap)
    entries{end+1} = did2.build.parameter( ...
        jLabel('minimum embedded file overlap'), 'Value', minOverlap);
end
% The trigger channels, named by the link each belongs to: v1 daqsystem_ch1 is
% the channel read on daqsystem1 (commonTriggersOverlappingEpochs.m:29), the
% `from_acquisition_system_id` system; daqsystem_ch2 goes with
% `to_acquisition_system_id`. Decided by Jess Haley, 2026-10-30, did-schema
% V_eta_go_forward_class_audit.md [trigger channels named by their link]:
% labels 'from trigger channel' / 'to trigger channel', not the v1 names.
for ch = {{'daqsystem_ch1', 'from trigger channel'}, {'daqsystem_ch2', 'to trigger channel'}}
    chText = channelText(params0(block), ch{1}{1});
    if ~isempty(chText)
        entries{end+1} = did2.build.parameter(jLabel(ch{1}{2}), 'Text', chText); %#ok<AGROW>
    end
end
% the parameters read nowhere above, written as method parameters too
% ([small unread settings] (3), Jess Haley, 2026-10-26)
unread = unreadParameters(params0(block), nameKeys);
if ~isempty(unread)
    entries{end+1} = unread;
end
params = [];
if ~isempty(entries)
    params = did2.build.list(entries{:});
end
f = struct();
clockName = jGetCharAny(params0(block), {'epochclocktype', 'epochClockType', 'epoch_clock_type'});
if ~isempty(clockName)
    f.clock = clockName;
end
if ~isempty(params)
    f.method = jMethod([], params);
end
edges = struct();
if ~isempty(swId); edges.software_id = swId; end
if ~isempty(systemIds)
    edges.from_acquisition_system_id = systemIds{1};
    edges.to_acquisition_system_id   = systemIds{2};
end
o = jOpts(preBody, 'Edges', edges, 'Id', char(preBody.base.id));
cfg = did2.build.document('clock_alignment_configuration', f, o{:});
end

function ids = stampedSystemIds(preBody)
%STAMPEDSYSTEMIDS The `resolved_acquisition_system_id` deps the batch pass stamps.
%   Read tolerantly, as jSessionDocId reads its stamp: a raw body spells the
%   target `value`, a body through universalRenames `document_id`, an
%   unconverted v1 body `id`. {} when there is no stamp (every pass-1 body).
ids = {};
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
deps = preBody.depends_on;
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), 'resolved_acquisition_system_id')
        continue;
    end
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            ids{end+1} = char(d.(f)); %#ok<AGROW>
            break;
        end
    end
end
end

function p = params0(block)
p = struct();
if isfield(block, 'parameters') && isstruct(block.parameters) && isscalar(block.parameters)
    p = block.parameters;
end
end

function v = readNumber(block, names)
%READNUMBER First finite scalar-numeric field among candidate names ([] if none).
v = [];
if ~isstruct(block); return; end
for k = 1:numel(names)
    if isfield(block, names{k})
        raw = block.(names{k});
        if isnumeric(raw) && isscalar(raw) && isfinite(raw)
            v = double(raw);
            return;
        end
    end
end
end


function name = namedDevice(deviceName, channelSpec)
%NAMEDDEVICE The device a sync rule's end names: DEVICENAME, or the device half
%   of a devicestring given in the channel slot ('intan1:ai1' -> 'intan1');
%   '' when neither names one (formerly jAcquisitionChannels, which built an
%   acquisition_channels body only to test this).
name = strtrim(char(deviceName));
if ~isempty(name)
    return;
end
spec = char(channelSpec);
spec(isspace(spec)) = [];
colon = find(spec == ':', 1);
if ~isempty(colon)
    name = spec(1:colon-1);
end
end
