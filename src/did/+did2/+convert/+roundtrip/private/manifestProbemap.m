function [pm, why, epochString] = manifestProbemap(manifest, ctx)
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
%   each naming its rig and channels through an `acquisition_channels`
%   document. A row is read back from its statement:
%
%     name, reference  the instrument_id entity's local_identifier
%                      (did2.convert.elementNameReference; the probe map
%                      writes the reference with int2str)
%     type             the instrument's `element type` assertion (the v1
%                      element.type, kept by +migrators_j/element.m), or,
%                      where the migrator wrote none, the type its device
%                      kind names (its Equipment Type assertion,
%                      did2.convert.elementTypeOfKind; [element type is a
%                      device kind term])
%     devicestring     the acquisition_channels' acquisition_system name, ':',
%                      its channel groups ';'-joined, each the v1 prefix of its
%                      channel type (did2.convert.channelType, by node) and its
%                      numbers, runs of two or more written 'a-b'
%     subjectstring    the entity_id entity's local_identifier
%
%   The statements of THIS manifest are those whose acquisition system reads
%   the manifest's files: its `epoch_file_pattern_id` is the manifest's (the
%   v1 filenavigator_id). Rows are in batch order, which is the order the pass
%   appended them in (the probe map's row order).
%
%   See also did2.convert.roundtrip.epochfiles_ingested,
%            did2.convert.roundtrip.syncrule_mapping,
%            did2.convert.resolveEpochProbemap.

pm = '';
why = {};
epochString = '';
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

% the acquisition systems that read the manifest's files
systems = {};
for k = ctxReferrers(ctx, nav)
    b = ctx.docs{k};
    if strcmp(classNameOf(b), 'acquisition_system') ...
            && any(strcmp(edgeIds(b, 'epoch_file_pattern_id'), nav))
        systems{end+1} = char(b.base.id); %#ok<AGROW>
    end
end

% the statements anchored "during" the epoch through its rigs
found = zeros(1, 0);
for a = ctxReferrers(ctx, epochId)
    anchor = ctx.docs{a};
    if ~strcmp(classNameOf(anchor), 'relative_time_reference') ...
            || ~any(strcmp(edgeIds(anchor, 'referent_id'), epochId))
        continue;
    end
    for s = ctxReferrers(ctx, char(anchor.base.id))
        st = ctx.docs{s};
        if ~any(strcmp(classNameOf(st), {'observation', 'manipulation'})) ...
                || ~any(strcmp(edgeIds(st, 'time_reference_id'), char(anchor.base.id)))
            continue;
        end
        ac = ctxDoc(ctx, firstEdge(st, 'acquisition_channels_id'));
        if isempty(ac) || ~any(strcmp(firstEdge(ac, 'acquisition_system_id'), systems))
            continue;
        end
        found(end+1) = s; %#ok<AGROW>
    end
end
found = unique(found);   % sorted: batch order

prefixes = prefixTable();
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
    [name, r] = did2.convert.elementNameReference(fieldText(getIn(inst, 'entity'), 'local_identifier'));
    if isnumeric(r) && ~isempty(r)
        ref = int2str(r);
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
sys = ctxDoc(ctx, firstEdge(ac, 'acquisition_system_id'));
if isempty(sys)
    why{end+1} = sprintf('statement %s: its acquisition system is not in the batch', char(st.base.id));
else
    dev = fieldText(getIn(sys, 'acquisition_system'), 'name');
    if isempty(dev)
        dev = fieldText(sys.base, 'name');
    end
    [groups, bad] = channelText(getIn(ac, 'acquisition_channels'), prefixes);
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
end
why = sprintf('statement %s: its instrument states no element type', char(st.base.id));
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
