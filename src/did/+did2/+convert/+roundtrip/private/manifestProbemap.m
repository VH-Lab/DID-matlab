function [pm, why, epochString, deferred] = manifestProbemap(manifest, ctx)
%MANIFESTPROBEMAP The serialised v1 `epochprobemap` of an ingestion_manifest,
%   read back from the documents its probe map was decomposed into.
%
%   [PM, WHY, EPOCHSTRING] = manifestProbemap(MANIFEST, CTX). MANIFEST is an
%   `ingestion_manifest` (what did2.convert.resolveEpochProbemap renames a v1
%   `epochfiles_ingested` to once every probe-map row has a home); CTX is the
%   index of the final batch (batchContext). PM is the probe map as NDI's
%   epochprobemap_daqsystem.serialize writes it: the five-column header
%   `name<TAB>reference<TAB>type<TAB>devicestring<TAB>subjectstring`, then one
%   '\n'-terminated line per row. WHY lists, as text, what could not be read
%   ({} when all of it was). EPOCHSTRING is the epoch entity's
%   local_identifier (the v1 epoch_id).
%
%   WHERE EACH ROW IS. resolveEpochProbemap makes, per row, one statement (an
%   `observation` per recording entry, two for a `patch` / `sharp` row; a
%   `manipulation` for a stimulator row), all anchored to ONE "during the
%   epoch" relative_time_reference whose referent is the manifest's epoch, and
%   each naming its rig by `acquisition_system_id`; the row's channels are the
%   conditions of the probe's `connected to` (RO:0002170) directed_relation to
%   that rig, timed by the same anchor (Jess Haley 2026-11-01 [probe wiring is
%   a relation], [wiring relation term]). A batch migrated before that names
%   rig and channels through an `acquisition_channels` document; both shapes
%   are read. A probe the v1 map listed in several rows has ONE statement and
%   ONE relation per system holding all those rows' channels in row order
%   ([probe in several rows is one wiring], Jess Haley, 2026-11-03), so it
%   comes back as one row ('vhvis_spike2:mk1-3;e1-3;md1'), the probe and
%   channels NDI reads. A row is read back from its statement:
%
%     name, reference  the instrument_id entity's `name` and what follows it
%                      in its local_identifier
%                      (did2.convert.elementNameReferenceApart, [element name
%                      and reference stored apart]; the local_identifier alone
%                      for an entity migrated before it; the probe map writes
%                      the reference with int2str)
%     type             the instrument's `element type` assertion (the v1
%                      element.type, kept by +migrators_j/element.m), or,
%                      where the migrator wrote none, the type its device
%                      kind names (its Equipment Type assertion,
%                      did2.convert.elementTypeOfKind; [element type is a
%                      device kind term]); for a kind several types share
%                      whose statement resolveEpochProbemap dropped, the
%                      kind plus the row statement's own mode term
%                      (did2.convert.elementTypeOfKindAndMode; [recording
%                      mode terms]), or the kind's general type when the row
%                      carries no mode (a bare patch or sharp)
%     devicestring     the acquisition system's name, ':', the wiring
%                      relation's conditions ';'-joined (or the
%                      acquisition_channels' groups), each the v1 prefix of its
%                      channel type (did2.convert.channelType, by node) and its
%                      numbers, runs of two or more written 'a-b'
%     subjectstring    the entity_id entity's local_identifier
%
%   The statements of THIS manifest are those whose acquisition system reads
%   the manifest's files: its `epoch_file_pattern_id` is the manifest's (the
%   v1 filenavigator_id). Rows are in batch order, which is the order the pass
%   appended them in (the probe map's row order).
%
%   A ROW WITH NO STATEMENT ([stimulator manipulation dropped], Jess Haley,
%   2026-11-09, did-schema did_v2_standing_wiring_plan.md): a wiring relation
%   of the epoch (`connected to`, timed by its "during the epoch" anchor, its
%   parent a rig that reads the manifest's files) whose probe is the
%   instrument of no statement found here is a row too, rebuilt from the
%   wiring and the element: name, reference and type from the element as
%   above, devicestring from the rig and the relation's conditions, and
%   subjectstring the local_identifier of the entity the element is
%   `derived_from` (an element with no underlying element), else of the v1
%   subject the run's migration report carries for the element (carry-172,
%   did2.convert.carriedElementSubject: NDI-matlab's second pass holds there
%   the subject of a stimulator no statement names, [one-field carry in the
%   migration report], Jess Haley, 2026-11-19). With neither, for a device,
%   the subjectstring is DEFERRED to that second pass: [no observes
%   relation in v2] (Jess Haley, 2026-11-26) writes no `observes` relation,
%   so the batch does not hold a direct element's subject, and "its round
%   trip defers the element's v1 `subject_id` to the second pass". The row
%   is written with an empty subjectstring and listed in DEFERRED (a cellstr,
%   one text per row); the caller compares the map with
%   private/sameProbemapDeferredSubjects.
%   These rows follow the statements' rows: the round trip
%   compares a probe map's rows as an unordered set ([probe map rows compared
%   as a set], Jess Haley, 2026-11-09; private/sameProbemapSeveralRows), the
%   way NDI finds a probe's rows (ndi.probe.epochprobemapmatch: name,
%   reference, type).
%
%   NOT A ROW: A CHANNEL GROUP'S OWNER ([non-specimen channel groups get
%   their own owner], Jess Haley, 2026-11-17). resolveEpochProbemap gives a
%   digital, auxiliary or analog output channel group of an ingested archive
%   its own statement, timed by the same anchor and naming the same rig; its
%   variable is the group's channel-type term ("digital input channel", ...),
%   which no probe-map row's statement carries (a row's is its modality or
%   its stimulator type). Such a statement is no row and is skipped
%   (isChannelGroupOwner).
%
%   See also did2.convert.roundtrip.epochfiles_ingested,
%            did2.convert.roundtrip.syncrule_mapping,
%            did2.convert.resolveEpochProbemap.

pm = '';
why = {};
epochString = '';
deferred = {};
if isempty(ctx)
    why{end+1} = 'the probe map is read from the batch, and no batch was given';
    return;
end
nav = firstEdge(manifest, 'epoch_file_pattern_id');
epochId = firstEdge(manifest, 'epoch_id');
if isempty(nav) || isempty(epochId)
    why{end+1} = 'the manifest names no epoch_file_pattern_id or no epoch_id';
    return;
end
epoch = ctxDoc(ctx, epochId);
if isempty(epoch) || ~isEntityOfType(epoch, 'epoch')
    why{end+1} = sprintf('its epoch %s is not in the batch', epochId);
else
    epochString = fieldText(epoch.entity, 'local_identifier');
end

% the acquisition systems that read the manifest's files, and what their
% wiring names as its parent: the system, or its device entity (`device_id`;
% Jess Haley 2026-11-19 [acquisition system is a device entity], did-schema
% docs/plans/did_v2_standing_wiring_plan.md). Both shapes are read.
systems = {};
wiredTo = {};
for k = ctxReferrers(ctx, nav)
    b = ctx.docs{k};
    if did2.convert.isAcquisitionConfiguration(classNameOf(b)) ...
            && any(strcmp(edgeIds(b, 'epoch_file_pattern_id'), nav))
        systems{end+1} = char(b.base.id); %#ok<AGROW>
        wiredTo = [wiredTo, {char(b.base.id)}, edgeIds(b, 'device_id')]; %#ok<AGROW>
    end
end

prefixes = prefixTable();
% the statements anchored "during" the epoch through its rigs, and the wiring
% relations timed by those anchors (A ROW WITH NO STATEMENT)
found = zeros(1, 0);
wirings = zeros(1, 0);
for a = ctxReferrers(ctx, epochId)
    anchor = ctx.docs{a};
    if ~strcmp(classNameOf(anchor), 'relative_time_reference') ...
            || ~any(strcmp(edgeIds(anchor, 'referent_id'), epochId))
        continue;
    end
    for s = ctxReferrers(ctx, char(anchor.base.id))
        st = ctx.docs{s};
        if isWiring(st, char(anchor.base.id), wiredTo)
            wirings(end+1) = s; %#ok<AGROW>
            continue;
        end
        if ~any(strcmp(classNameOf(st), {'observation', 'manipulation'})) ...
                || ~any(strcmp(edgeIds(st, 'time_reference_id'), char(anchor.base.id)))
            continue;
        end
        if ~any(strcmp(systemIdOf(st, ctx), systems))
            continue;
        end
        if isChannelGroupOwner(st, prefixes)
            continue;   % NOT A ROW: a channel group's owner
        end
        found(end+1) = s; %#ok<AGROW>
    end
end
found = unique(found);   % sorted: batch order

rowLines = {};
paired = false(1, 0);
for i = 1:numel(found)
    st = ctx.docs{found(i)};
    [rowText, bad] = rowOf(st, ctx, prefixes);
    why = [why, bad]; %#ok<AGROW>
    % a `patch` / `sharp` row is two observations (voltage and current) of one
    % row, in a row: one line
    [~, rowType] = rowTypeOf(st, ctx);
    if ~isempty(rowLines) && strcmp(rowText, rowLines{end}) && ~paired(end) ...
            && any(strcmpi(rowType, {'patch', 'sharp'}))
        paired(end) = true;
        continue;
    end
    rowLines{end+1} = rowText; %#ok<AGROW>
    paired(end+1) = false; %#ok<AGROW>
end
% the wiring relations whose probe no statement names (A ROW WITH NO STATEMENT)
% (a plain loop: an anonymous function capturing CTX made each call 0.25 s,
% 1,855 s over B's 7,452 calls, MATLAB scratch run 42712175490)
named = cell(1, numel(found));
for i = 1:numel(found)
    named{i} = firstEdge(ctx.docs{found(i)}, 'instrument_id');
end
wirings = unique(wirings);
for i = 1:numel(wirings)
    w = ctx.docs{wirings(i)};
    if any(strcmp(firstEdge(w, 'child_id'), named))
        continue;
    end
    [rowText, bad, isDeferred] = wiringRowOf(w, ctx, prefixes);
    why = [why, bad]; %#ok<AGROW>
    if isDeferred
        deferred{end+1} = rowText; %#ok<AGROW>
    end
    rowLines{end+1} = rowText; %#ok<AGROW>
end
tab = sprintf('\t');
nl = newline;
pm = [strjoin({'name', 'reference', 'type', 'devicestring', 'subjectstring'}, tab), nl];
for i = 1:numel(rowLines)
    pm = [pm, rowLines{i}, nl]; %#ok<AGROW>
end
if isempty(rowLines)
    why{end+1} = 'no statement of the epoch names a rig that reads the manifest''s files';
end
end

% ===================== helpers =========================================

function tf = isChannelGroupOwner(st, prefixes)
% a statement whose variable is a channel-type term (NOT A ROW, above)
[node, ~] = termParts(getIn(st, 'statement', 'variable'));
tf = ~isempty(prefixOf(prefixes, node));
end

function tf = isWiring(b, anchorId, systems)
% a `connected to` (RO:0002170) directed_relation timed by ANCHORID whose
% parent is one of SYSTEMS (the rigs that read the manifest's files, and
% their devices)
tf = false;
if ~strcmp(classNameOf(b), 'directed_relation')
    return;
end
[node, ~] = termParts(getIn(getIn(b, 'directed_relation'), 'relation'));
tf = strcmp(curieKeyOf(node), curieKeyOf('RO:0002170')) ...
    && any(strcmp(edgeIds(b, 'time_reference_id'), anchorId)) ...
    && any(ismember(edgeIds(b, 'parent_id'), systems));
end

function [rowText, why, isDeferred] = wiringRowOf(w, ctx, prefixes)
% the row of a wiring relation no statement names: the element (its child),
% the rig (its parent) and its conditions, and the element's subject
% (ISDEFERRED: a device whose subject the batch does not hold, [no observes
% relation in v2]; its subjectstring is left empty)
why = {};
isDeferred = false;
tab = sprintf('\t');
instrumentId = firstEdge(w, 'child_id');
% rowOf reads the instrument, rig and wiring through a statement's edges: a
% stand-in statement with the wiring's own edges
% (the rig: the parent, or the acquisition_system whose device the parent is)
sysId = firstEdge(w, 'parent_id');
sys = rigSystem(sysId, {}, ctx);
if ~isempty(sys); sysId = char(sys.base.id); end
st = struct('base', struct('id', getIn(w, 'base', 'id')), ...
    'depends_on', struct('name', {'instrument_id', 'acquisition_system_id', ...
    'time_reference_id'}, 'value', {instrumentId, sysId, ...
    firstEdge(w, 'time_reference_id')}));
[rowText, why] = rowOf(st, ctx, prefixes);
% rowOf found no entity_id: the subject is the element's
why = why(~endsWith(why, 'its entity is not in the batch'));
subject = '';
subjectId = elementSubjectId(instrumentId, ctx);
subj = ctxDoc(ctx, subjectId);
if isempty(subjectId) && isDeviceEntity(ctxDoc(ctx, instrumentId))
    isDeferred = true;   % NDI's second pass reads the v1 subject_id
elseif isempty(subj)
    why{end+1} = sprintf('wiring %s: its element %s names no subject in the batch', ...
        char(getIn(w, 'base', 'id')), instrumentId);
else
    subject = fieldText(getIn(subj, 'entity'), 'local_identifier');
end
cols = strsplit(rowText, tab, 'CollapseDelimiters', false);
cols{5} = subject;
rowText = strjoin(cols, tab);
end

function id = elementSubjectId(elementId, ctx)
% the entity an element is `derived_from` (the lineage relation
% +migrators_j/element.m writes; +roundtrip/element.m reads it), else the v1
% subject the run's migration report carries for it: NDI-matlab's second pass
% holds there the v1 subject of a stimulator no statement names (and of a
% recording probe with no recording observation) (carry-172; [stimulator
% subject carried as needing information], [one-field carry in the migration
% report], [recording probe subject carried the same way], Jess Haley,
% 2026-11-19), read by did2.convert.carriedElementSubject. No `observes`
% relation is read ([no observes relation in v2], Jess Haley, 2026-11-26)
id = '';
derived = '';
for k = ctxReferrers(ctx, elementId)
    b = ctx.docs{k};
    if ~strcmp(classNameOf(b), 'directed_relation') ...
            || ~any(strcmp(edgeIds(b, 'child_id'), elementId))
        continue;
    end
    parent = edgeIds(b, 'parent_id');
    if ~isscalar(parent); continue; end
    handle = did2.build.vocabularyHandle('relation', getIn(b, 'directed_relation', 'relation'));
    if strcmp(handle, 'derived_from') && isempty(derived)
        derived = parent{1};
    end
end
id = derived;
if isempty(id)
    id = did2.convert.carriedElementSubject(elementId);
end
end

function [rowText, why] = rowOf(st, ctx, prefixes)
why = {};
tab = sprintf('\t');
% name, reference: the instrument
name = '';
ref = '';
instrumentId = firstEdge(st, 'instrument_id');
inst = ctxDoc(ctx, instrumentId);
if isempty(inst)
    why{end+1} = sprintf('statement %s: its instrument is not in the batch', char(st.base.id));
else
    instEntity = getIn(inst, 'entity');
    [name, r] = did2.convert.elementNameReferenceApart(fieldText(instEntity, 'name'), ...
        fieldText(instEntity, 'local_identifier'));
    if isnumeric(r) && isscalar(r) && isfinite(r) && r == round(r)
        ref = int2str(r);
    elseif isnumeric(r) && isscalar(r)
        ref = num2str(r, 17);
    elseif ischar(r) || isstring(r)
        ref = char(r);
    end
end
% type
[typeWhy, elType] = rowTypeOf(st, ctx);
if ~isempty(typeWhy)
    why{end+1} = typeWhy;
end
% devicestring: the rig and its channels
dev = '';
ac = ctxDoc(ctx, firstEdge(st, 'acquisition_channels_id'));
sys = ctxDoc(ctx, systemIdOf(st, ctx));
if isempty(sys)
    why{end+1} = sprintf('statement %s: its acquisition system is not in the batch', char(st.base.id));
else
    % its own name field, under either class name ([acquisition
    % configuration renamed]); its block is named after its class
    if did2.convert.isAcquisitionConfiguration(classNameOf(sys))
        dev = fieldText(getIn(sys, classNameOf(sys)), 'name');
    end
    if isempty(dev)
        dev = fieldText(sys.base, 'name');
    end
    if ~isempty(ac)
        [groups, bad] = channelText(getIn(ac, 'acquisition_channels'), prefixes);
    else
        [groups, bad] = wiringText(st, ctx, [{char(sys.base.id)}, edgeIds(sys, 'device_id')], prefixes);
    end
    why = [why, bad];
    if ~isempty(groups)
        dev = [dev ':' groups];
    end
end
% subjectstring
subj = ctxDoc(ctx, firstEdge(st, 'entity_id'));
subject = '';
if isempty(subj)
    why{end+1} = sprintf('statement %s: its entity is not in the batch', char(st.base.id));
else
    subject = fieldText(getIn(subj, 'entity'), 'local_identifier');
end
rowText = strjoin({name, ref, elType, dev, subject}, tab);
end

function [why, elType] = rowTypeOf(st, ctx)
% the instrument's `element type` assertion (+migrators_j/element.m), else the
% one type its device kind names (did2.convert.elementTypeOfKind)
why = '';
elType = '';
kindNodes = {};
instrumentId = firstEdge(st, 'instrument_id');
for k = ctxReferrers(ctx, instrumentId)
    b = ctx.docs{k};
    if ~strcmp(classNameOf(b), 'assertion') ...
            || ~any(strcmp(edgeIds(b, 'entity_id'), instrumentId))
        continue;
    end
    [~, variable] = termParts(getIn(b, 'statement', 'variable'));
    if strcmpi(variable, 'element type')
        [~, elType] = termParts(getIn(b, 'term', 'value'));
        return;
    elseif strcmpi(variable, 'equipment type')
        [kindNode, ~] = termParts(getIn(b, 'term', 'value'));
        kindNodes{end+1} = kindNode; %#ok<AGROW>
    end
end
if isscalar(kindNodes)
    elType = did2.convert.elementTypeOfKind(kindNodes{1});
    if ~isempty(elType)
        return;
    end
    % a kind several types share whose statement resolveEpochProbemap dropped
    % ([recording mode terms]): the kind plus THIS row's mode, the method
    % term the row's observation carries; with none, the kind's general type
    % (a bare patch or sharp row)
    mode = '';
    m = getIn(st, 'interaction', 'method');
    if isstruct(m) && isscalar(m) && isfield(m, 'term')
        [mode, ~] = termParts(m.term);
    end
    elType = did2.convert.elementTypeOfKindAndMode(kindNodes{1}, mode);
    if isempty(elType) && isempty(mode)
        elType = did2.convert.elementGeneralTypeOfKind(kindNodes{1});
    end
    if ~isempty(elType)
        return;
    end
end
why = sprintf('statement %s: its instrument states no element type', char(st.base.id));
end

function id = systemIdOf(st, ctx)
% the statement's rig: `acquisition_system_id` ([probe wiring is a relation]),
% or, in a batch migrated before it, its acquisition_channels' system
id = firstEdge(st, 'acquisition_system_id');
if isempty(id)
    ac = ctxDoc(ctx, firstEdge(st, 'acquisition_channels_id'));
    id = firstEdge(ac, 'acquisition_system_id');
end
end

function [text, why] = wiringText(st, ctx, sysId, prefixes)
% 'ai11-14;di1' from the conditions of the probe's wiring relation: the
% directed_relation `connected to` (RO:0002170) whose child is the statement's
% instrument, whose parent is one of SYSID (the rig's acquisition_system and
% its device entity, [acquisition system is a device entity]) and whose time
% is the statement's anchor.
% None: the row had no channels ('' and no complaint).
text = '';
why = {};
instrumentId = firstEdge(st, 'instrument_id');
anchorId = firstEdge(st, 'time_reference_id');
if isempty(instrumentId) || isempty(anchorId)
    return;
end
hits = {};
for k = ctxReferrers(ctx, anchorId)
    b = ctx.docs{k};
    if ~strcmp(classNameOf(b), 'directed_relation'); continue; end
    blk = getIn(b, 'directed_relation');
    [node, ~] = termParts(getIn(blk, 'relation'));
    if ~strcmp(curieKeyOf(node), curieKeyOf('RO:0002170')); continue; end
    if ~any(strcmp(edgeIds(b, 'child_id'), instrumentId)) ...
            || ~any(ismember(edgeIds(b, 'parent_id'), sysId)) ...
            || ~any(strcmp(edgeIds(b, 'time_reference_id'), anchorId))
        continue;
    end
    hits{end+1} = blk; %#ok<AGROW>
end
if isempty(hits)
    return;
end
if numel(hits) > 1
    why{end+1} = sprintf('statement %s: its probe has %d wiring relations to its rig in this epoch', ...
        char(st.base.id), numel(hits));
end
conds = getIn(hits{1}, 'conditions');
if isempty(conds)
    return;
end
if isstruct(conds)
    conds = num2cell(reshape(conds, 1, []));
end
groups = cell(1, numel(conds));
for g = 1:numel(conds)
    c = conds{g};
    nums = [];
    old = did2.read.oldNumericForm(c);
    if ~isempty(old)
        % [no migrated database is kept] (Jess Haley, 2026-11-19)
        did2.read.refuseOldNumericShape('A wiring relation''s channel group', old);
    end
    if isstruct(c) && isfield(c, 'numeric')
        nums = c.numeric;   % the numeric shape ([one shape for measured numbers])
    end
    groups{g} = struct('type', {getIn(c, 'variable')}, 'numbers', {nums});
end
[text, why2] = channelText(struct('channels', {groups}), prefixes);
why = [why, why2];
end

function [text, why] = channelText(blk, prefixes)
% 'ai11-14;di1' from acquisition_channels.channels ({type, numbers} groups)
text = '';
why = {};
if ~isstruct(blk) || ~isfield(blk, 'channels') || isempty(blk.channels)
    return;
end
groups = blk.channels;
if isstruct(groups)
    groups = num2cell(reshape(groups, 1, []));
end
parts = {};
for g = 1:numel(groups)
    grp = groups{g};
    [node, name] = termParts(getIn(grp, 'type'));
    prefix = prefixOf(prefixes, node);
    if isempty(prefix)
        prefix = name;
        why{end+1} = sprintf('channel type "%s" (%s) is no v1 prefix', name, node); %#ok<AGROW>
    end
    nums = [];
    if isstruct(grp) && isfield(grp, 'numbers')
        nums = grp.numbers;
        if iscell(nums); nums = cell2mat(nums); end
        nums = double(reshape(nums, 1, []));
    end
    parts{end+1} = [prefix numberText(nums)]; %#ok<AGROW>
end
text = strjoin(parts, ';');
end

function s = numberText(nums)
% [27 28 45] -> '27-28,45': a run of two or more consecutive numbers as a-b
s = '';
i = 1;
items = {};
while i <= numel(nums)
    j = i;
    while j < numel(nums) && nums(j + 1) == nums(j) + 1
        j = j + 1;
    end
    if j > i
        items{end+1} = sprintf('%d-%d', nums(i), nums(j)); %#ok<AGROW>
    else
        items{end+1} = sprintf('%d', nums(i)); %#ok<AGROW>
    end
    i = j + 1;
end
if ~isempty(items)
    s = strjoin(items, ',');
end
end

function table = prefixTable()
% channel type node -> the v1 prefix did2.convert.channelType gives it
table = containers.Map('KeyType', 'char', 'ValueType', 'char');
for c = {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx'}
    t = did2.convert.channelType(c{1});
    if ~isempty(t.node)
        table(curieKeyOf(t.node)) = c{1};
    end
end
end

function p = prefixOf(table, node)
% the v1 channel prefix whose channel type is NODE ('' when none is)
p = '';
if isempty(node)
    return;
end
k = curieKeyOf(node);
if isKey(table, k)
    p = table(k);
end
end

function k = curieKeyOf(s)
try
    k = char(did2.schema.curieKey(char(s)));
catch
    k = lower(char(s));
end
end

function id = firstEdge(body, name)
id = '';
if isempty(body)
    return;
end
ids = edgeIds(body, name);
if ~isempty(ids)
    id = ids{1};
end
end

function tf = isDeviceEntity(b)
% an `entity` of type device (by node, [vocabulary nodes] L2)
tf = ~isempty(b) && strcmp(classNameOf(b), 'entity') && isfield(b, 'entity') ...
    && isstruct(b.entity) && isfield(b.entity, 'type') ...
    && did2.build.isVocabulary(b.entity.type, 'entity_type', 'device');
end
