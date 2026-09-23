function bodies = syncrule(preBody)
%SYNCRULE Brainstorm-J migrator: did_v1 `syncrule` -> `clock_alignment_configuration`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   1 -> 3 or 4:  the configuration, its TWO `acquisition_channels` documents,
%   and (when the source names an implementation) one `software` entity.
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
%   `errorOnFailure` is DROPPED (repair 5 in the plan): throw-or-return-quietly
%   is runtime behaviour, not a fact about the experiment.
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

arguments
    preBody (1,1) struct
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

channelsA = jAcquisitionChannels(preBody, name1, ch1);
channelsB = jAcquisitionChannels(preBody, name2, ch2);

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
%     genuinely empty. `jAcquisitionChannels` is NOT widened -- its refusal
%     stays correct (inventing an empty channel is the invented-empty-edge
%     pattern this repository has paid for six times).
haveBoth    = ~isempty(channelsA) && ~isempty(channelsB);
haveNeither = isempty(channelsA) && isempty(channelsB);
minPaths    = readNumber(params, {'number_fullpath_matches', 'numberFullpathMatches'});
isFileBased = ~isempty(minPaths);
if ~haveBoth && ~(haveNeither && isFileBased)
    bodies = {preBody};      % half-specified pair, or no criterion at all
    return;
end

implClass = jGetCharAny(block, {'ndi_syncrule_class', 'ndiSyncruleClass'});
[software, swId] = jSyncSoftware(preBody, implClass);

cfg = struct();
cfg.document_class = struct('class_name', 'clock_alignment_configuration', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
deps = struct('name', {}, 'value', {});
if ~isempty(swId)
    deps(end+1) = struct('name', 'software_id', 'value', swId);
end
% DEVICE-PAIR RULE: EXACTLY 2 acquisition_channels, UNORDERED. `_#` and not
% from_/to_ because the rule is SYMMETRIC: commonTriggersOverlappingEpochs.m:
% 110-115 accepts the pair in either order and normalises 1/2 afterwards, and
% filefind.m:133-136 computes `forward`/`backward` and takes either. A FILE-BASED
% rule (haveNeither) carries ZERO channels -- amendment 1 -- so these edges and
% the two channel bodies are emitted ONLY when both channels exist.
if haveBoth
    deps(end+1) = struct('name', 'acquisition_channels_1', 'value', channelsA.base.id);
    deps(end+1) = struct('name', 'acquisition_channels_2', 'value', channelsB.base.id);
end
cfg.depends_on = deps;
% base PRESERVED verbatim, id and name included.
cfg.base = carryBase(preBody);

cfgBlock = struct();
clockName = jGetCharAny(params, {'epochclocktype', 'epochClockType', 'epoch_clock_type'});
if ~isempty(clockName)
    % STAGED with an empty node (#67/#70): the field is bound to did_clocktype,
    % whose four terms all carry `"node": ""` in the schema's own value_set --
    % no NDIC identifier can be assigned from any repository in scope. Omitted
    % entirely when the source has no clock, rather than emitted all-blank:
    % `clock` is optional, and an all-blank ontology_term is exactly the vacuous
    % value silentLoss:322 exists to name.
    cfgBlock.clock = jOntologyTerm('', clockName);
end
minPaths = readNumber(params, {'number_fullpath_matches', 'numberFullpathMatches'});
if ~isempty(minPaths)
    cfgBlock.minimum_matching_file_paths = minPaths;
end
syncFile = jGetCharAny(params, {'syncfilename', 'syncFilename', 'sync_filename'});
if ~isempty(syncFile)
    cfgBlock.sync_file_name = syncFile;
end
minOverlap = readNumber(params, {'minEmbeddedFileOverlap', 'min_embedded_file_overlap'});
if ~isempty(minOverlap)
    cfgBlock.minimum_embedded_file_overlap = minOverlap;
end
% errorOnFailure is deliberately NOT carried (repair 5).
cfg.clock_alignment_configuration = cfgBlock;

if haveBoth
    bodies = {cfg, channelsA, channelsB};
else
    bodies = {cfg};   % file-based rule: the channel-less configuration only
end
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== small helpers =======================================

function b = carryBase(preBody)
%CARRYBASE base PRESERVED -- id, session_id, name, datestamp.
%   `base.session_id` on a syncrule is ndi.session.empty_id()
%   ('0000000000000000_0000000000000000', syncrule.m:186) -- a real, non-empty
%   string meaning "applies in any session", so it satisfies base's REQUIRED
%   session_id without any invention.
b = struct('id', '', 'session_id', '', 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
if isfield(preBody, 'base') && isstruct(preBody.base)
    src = preBody.base;
    fn = {'id', 'session_id', 'name', 'datestamp'};
    for k = 1:numel(fn)
        if isfield(src, fn{k}) && ~isempty(src.(fn{k}))
            b.(fn{k}) = src.(fn{k});
        end
    end
end
if isempty(b.id); b.id = did.ido.unique_id(); end
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
