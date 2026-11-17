function [v1, spec] = element_epoch(bodies, ctx)
%ELEMENT_EPOCH Rebuild a v1 `element_epoch` from what the migration made of
%   it: the pass-1 carrier, or what the batch passes dissolved it into.
%
%   [V1, SPEC] = did2.convert.roundtrip.element_epoch(BODIES). V1 is the
%   element_epoch in NDI's v1 shape (element_epoch.json + epochid.json +
%   base.json at the locked NDI-matlab `main`, 73f46d1, as ndi.element/addepoch
%   writes it: one clock, t0_t1 a column [t0; t1], epochid.epochid,
%   set_dependency_value('element_id', ...), and the epoch's samples attached
%   as epoch_binary_data.vhsb). THE PASS-1 ROUND TRIP: BODIES is the one
%   `acquisition_epoch` did2.convert.migrators_j.element_epoch emitted:
%
%     base.id, session_id, datestamp   the carrier (rebuildBase)
%     depends_on(1) element_id         the carrier's element_id edge
%     element_epoch.epoch_clock        the clocks' names, joined by ','
%     element_epoch.t0_t1              [t0; t1] per clock, one column each (the
%                                      writer's column vector for one clock)
%     epochid.epochid                  the carrier's epochid.epochid
%     files                            the carrier's files block
%
%   AFTER THE DISSOLUTION. [V1, SPEC] = ...(BODIES, CTX), CTX the index of the
%   whole final batch (private/batchContext, made by
%   did2.convert.roundtrip.wholeBatch). The batch passes (did2.convert.epochMint
%   mints the epoch, tied to its acquisition system or, untied, anchored on the
%   session; did2.convert.resolveEpochProbemap dissolves the carrier: [epoch
%   dissolution before merge], Jess Haley, 2026-10-22) replace the carrier
%   with ONE observation of the element that keeps the element_epoch's id, its
%   own relative_time_reference onto the minted `epoch` entity, and the .vhsb
%   as its opaque_body. The id is kept, so wholeBatch hands that observation
%   here as BODIES, and the v1 document is rebuilt from it and from what CTX
%   holds ([lossless means round trip], [whole-batch round trip]: lossless is
%   measured on the FINAL batch):
%
%     base.id, session_id, datestamp   the observation (rebuildBase):
%                                      resolveEpochProbemap writes the
%                                      element_epoch's id, session and
%                                      creation time on it
%     base.name                        not written (v2 never writes base.name;
%                                      addepoch leaves it empty)
%     depends_on(1) element_id         the observation's `entity_id` edge (the
%                                      observation is about the element)
%     element_epoch.epoch_clock        every clock this source stated, in
%                                      its order, read back to the v1 string
%                                      (clockText): see THE CLOCKS below
%     element_epoch.t0_t1              [t0; t1] per clock, one column each:
%                                      dev_local_time from the observation's
%                                      one time reference (source_value,
%                                      else seconds, of its start and end);
%                                      each other clock from the epoch's own
%                                      extent for it, [start; start +
%                                      duration]
%     epochid.epochid                  the local_identifier of the `epoch`
%                                      entity that reference is relative to
%                                      (`referent_id`), the same for a tied
%                                      and an untied (session-anchored) epoch
%     files.file_list, files.file_info the one opaque_body owned by the
%                                      observation (`owner_id`): its
%                                      data_body.filename (the v1 file name,
%                                      epoch_binary_data.vhsb) and the
%                                      locations of its body_data_0 entry,
%                                      which resolveEpochProbemap carries
%                                      verbatim
%
%   THE CLOCKS. resolveEpochProbemap dissolves on dev_local_time only (the
%   offset "from the epoch"), so the observation's one time reference states
%   that clock. Every other clock the element_epoch states (JH's
%   exp_global_time) is not an offset from the epoch: the epoch carries it as
%   its own extent ([device clocks on one epoch], Jess Haley, 2026-10-26;
%   did2.convert.epochMint, #60 option A), one relative_time_reference per
%   (clock, referent) on the epoch's `time_reference_id` edges, onto the
%   acquisition system it is tied to, or onto the session document when it is
%   untied ([untied epochs keep the session anchor]). The source's clocks are
%   read from those references:
%     - the references epochMint minted FROM THIS SOURCE: their ids derive from
%       the source's id and the role 'epoch clock <clock> on <referent>'
%       (did2.convert.mintId; practice (b) of [migration reliability
%       practices], Jess Haley, 2026-10-26), and the observation keeps the
%       source's id, so each is recognised by re-deriving its id;
%     - else, when the epoch holds session-anchored references, those: they
%       exist only when every source of the epoch was untied and all of them
%       stated the same clocks in the same order with identical t0/t1
%       ([agreeing untied sources count as one], Jess Haley, 2026-11-12), so
%       they are every such source's clocks, not only the first's.
%   THE ORDER is the order of the epoch's `time_reference_id` edges, which
%   epochMint adds in the order the source lists its clocks. The source's
%   dev_local_time must be among those references (its position is the
%   order); its values are the observation's. When it is not (another source
%   on the same system stated it first, so the reference derives from that
%   source), the position of dev_local_time among the source's clocks is not
%   recorded anywhere and the clocks are not guessed: only the observation's
%   clock is rebuilt, and a source that stated any other clock has its
%   epoch_clock and t0_t1 reported LOST by the comparison, never matched. The
%   same holds for a TIED source none of whose clocks the epoch's references
%   derive from (a second source on one system that restates the first): the
%   references do not record which of them it stated. Anything the batch
%   does not hold (no time reference, no epoch, no body, two of either) is
%   named in spec.unplaced, and the fields it would have given are lost.
%
%   See also did2.convert.roundtrip.check, did2.convert.roundtrip.wholeBatch,
%            did2.convert.migrators_j.element_epoch,
%            did2.convert.resolveEpochProbemap.

arguments
    bodies cell
    ctx = []
end

spec = emptySpec();
v1 = struct();
if ~any(cellfun(@(b) strcmp(classNameOf(b), 'acquisition_epoch'), bodies)) ...
        && any(cellfun(@(b) strcmp(classNameOf(b), 'observation'), bodies))
    [v1, spec] = fromDissolution(bodies, ctx);   % AFTER THE DISSOLUTION
    return;
end
ae = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'acquisition_epoch') && isempty(ae)
        ae = bodies{k};
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the one acquisition_epoch', ...
            k, classNameOf(bodies{k}));
    end
end
if isempty(ae)
    spec.unplaced{end+1} = 'no acquisition_epoch was emitted';
    return;
end
[base, ~] = rebuildBase(ae);
clocks = asCell(getIn(ae, 'acquisition_epoch', 'clocks'));
names = cell(1, numel(clocks));
t0t1 = zeros(2, numel(clocks));
for k = 1:numel(clocks)
    names{k} = fieldText(clocks{k}, 'name');
    t0t1(:, k) = [timeOf(clocks{k}, 't0'); timeOf(clocks{k}, 't1')];
end
ids = edgeIds(ae, 'element_id');
if isempty(ids); ids = {''}; end

v1.document_class = struct('class_name', 'element_epoch');
v1.depends_on = struct('name', 'element_id', 'value', ids{1});
if isfield(ae, 'files')
    v1.files = ae.files;
end
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
[epochId, ok] = getIn(ae, 'epochid', 'epochid');
if ok
    v1.epochid = struct('epochid', epochId);
end
v1.element_epoch = struct('epoch_clock', strjoin(names, ','), 't0_t1', t0t1);
end

function [v1, spec] = fromDissolution(bodies, ctx)
% the v1 element_epoch rebuilt from its observation, its time reference, the
% epoch entity and its data body (AFTER THE DISSOLUTION, above)
spec = emptySpec();
v1 = struct();
obs = [];
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'observation') && isempty(obs)
        obs = bodies{k};
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the one observation', ...
            k, classNameOf(bodies{k}));
    end
end
if isempty(ctx)
    spec.unplaced{end+1} = ['no acquisition_epoch was emitted, and a dissolved ' ...
        'element_epoch is rebuilt only from the whole batch'];
    return;
end
[base, ~] = rebuildBase(obs);
v1.document_class = struct('class_name', 'element_epoch');
ids = edgeIds(obs, 'entity_id');
if numel(ids) ~= 1
    spec.unplaced{end+1} = sprintf('the observation names %d entities (the element is one)', ...
        numel(ids));
    ids = {''};
end
v1.depends_on = struct('name', 'element_id', 'value', ids{1});

% the epoch's samples: the one opaque_body the observation owns
owned = {};
for k = ctxReferrers(ctx, base.id)
    b = ctx.docs{k};
    if strcmp(classNameOf(b), 'opaque_body') && any(strcmp(edgeIds(b, 'owner_id'), base.id))
        owned{end+1} = b; %#ok<AGROW>
    end
end
if isscalar(owned)
    name = fieldText(getIn(owned{1}, 'data_body'), 'filename');
    if isempty(name)
        spec.unplaced{end+1} = 'the data body states no file name';
    else
        loc = bodyLocations(owned{1});
        if isempty(loc)
            spec.unplaced{end+1} = 'the data body holds no body_data_0 file';
        else
            v1.files = struct('file_list', {{name}}, ...
                'file_info', struct('name', name, 'locations', {loc}));
        end
    end
else
    spec.unplaced{end+1} = sprintf('the observation owns %d data bodies (the .vhsb is one)', ...
        numel(owned));
end

v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);

% its extent: the one time reference, relative to the epoch
tr = edgeIds(obs, 'time_reference_id');
if numel(tr) ~= 1
    spec.unplaced{end+1} = sprintf('the observation names %d time references (its extent is one)', ...
        numel(tr));
    return;
end
ref = ctxDoc(ctx, tr{1});
if ~strcmp(classNameOf(ref), 'relative_time_reference')
    spec.unplaced{end+1} = 'the observation''s time reference is not a relative_time_reference in the batch';
    return;
end
epochIds = edgeIds(ref, 'referent_id');
ep = [];
if isscalar(epochIds)
    ep = ctxDoc(ctx, epochIds{1});
end
if isEntityOfType(ep, 'epoch')
    v1.epochid = struct('epochid', fieldText(ep.entity, 'local_identifier'));
else
    spec.unplaced{end+1} = 'the time reference is not relative to an epoch entity in the batch';
    ep = [];
end
[names, t0t1] = sourceClocks(ref, ep, base.id, ctx);
v1.element_epoch = struct('epoch_clock', strjoin(names, ','), 't0_t1', t0t1);
end

function [names, t0t1] = sourceClocks(ref, ep, sourceId, ctx)
% every clock the source stated, in its order (THE CLOCKS, above): the
% observation's dev_local_time reference REF, with the epoch EP's own extents
% from this source around it; REF's clock alone when they are not recorded
devName = clockText(getIn(ref, 'relative_time_reference', 'value', 'clock'));
devT = [readValue(ref, 'start'); readValue(ref, 'end')];
names = {devName};
t0t1 = devT;
if isempty(ep)
    return;
end
refs = {};
for id = edgeIds(ep, 'time_reference_id')
    d = ctxDoc(ctx, id{1});
    if strcmp(classNameOf(d), 'relative_time_reference')
        refs{end+1} = d; %#ok<AGROW>
    end
end
if isempty(refs)
    return;
end
clocks = cellfun(@(r) clockText(getIn(r, 'relative_time_reference', 'value', 'clock')), ...
    refs, 'UniformOutput', false);
referents = cellfun(@(r) firstId(edgeIds(r, 'referent_id')), refs, 'UniformOutput', false);
own = false(1, numel(refs));
depth = did2.convert.mintId('-depth');
did2.convert.mintId('-push', '');   % a fresh context: each (source, role) is its first
restore = onCleanup(@() did2.convert.mintId('-popto', depth));
for r = 1:numel(refs)
    if isempty(clocks{r}) || isempty(referents{r}); continue; end
    own(r) = strcmp(char(refs{r}.base.id), did2.convert.mintId( ...
        ['epoch clock ' clocks{r} ' on ' referents{r}], char(sourceId)));
end
clear restore
if ~any(own)
    % [agreeing untied sources count as one]: the session-anchored extents
    % are every agreeing untied source's
    sessionDoc = edgeIds(ep, 'session_id');
    if isscalar(sessionDoc)
        own = strcmp(referents, sessionDoc{1});
    end
end
if ~any(own)
    return;
end
clocks = clocks(own);
refs = refs(own);
if nnz(strcmp(clocks, devName)) ~= 1
    return;   % the position of dev_local_time is not recorded
end
names = clocks;
t0t1 = zeros(2, numel(refs));
for r = 1:numel(refs)
    if strcmp(clocks{r}, devName)
        t0t1(:, r) = devT;
    else
        t0 = readValue(refs{r}, 'start');
        t0t1(:, r) = [t0; t0 + readValue(refs{r}, 'duration')];
    end
end
end

function s = firstId(c)
% the first id of cellstr C ('' when empty)
s = '';
if ~isempty(c); s = c{1}; end
end

function loc = bodyLocations(body)
% the locations of a data body's body_data_0 file ([] when it has none)
loc = [];
[infos, ok] = getIn(body, 'files');
if ~ok || ~isstruct(infos) || ~isfield(infos, 'file_info')
    return;
end
infos = asCell(infos.file_info);
for k = 1:numel(infos)
    if strcmp(fieldText(infos{k}, 'name'), 'body_data_0') && isfield(infos{k}, 'locations')
        loc = infos{k}.locations;
        return;
    end
end
end

function t = readValue(ref, name)
% a relative_time_reference's START, END or DURATION as the v1 value it was read from
% (source_value; seconds when it states none); NaN when it has neither
t = NaN;
[v, ok] = getIn(ref, 'relative_time_reference', 'value', name, 'source_value');
if ~(ok && isnumeric(v) && isscalar(v))
    [v, ok] = getIn(ref, 'relative_time_reference', 'value', name, 'seconds');
end
if ok && isnumeric(v) && isscalar(v)
    t = double(v);
end
end

function t = timeOf(clock, name)
t = NaN;
[v, ok] = getIn(clock, name);
if ok && isnumeric(v) && isscalar(v)
    t = double(v);
end
end
