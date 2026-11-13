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
%     element_epoch.epoch_clock        the clock of the observation's one time
%                                      reference (`time_reference_id`), read
%                                      back to the v1 string (clockText)
%     element_epoch.t0_t1              [start; end] of that reference, as the
%                                      v1 values it was read from
%                                      (source_value, else seconds)
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
%   Only the clock resolveEpochProbemap dissolves on (dev_local_time, the one
%   clock addepoch writes) is on the reference. A v1 element_epoch stating
%   any other clock as well is not rebuilt whole: its epoch_clock and t0_t1
%   are then reported LOST by the comparison, never matched. Anything the
%   batch does not hold (no time reference, no epoch, no body, two of either)
%   is named in spec.unplaced, and the fields it would have given are lost.
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
end
v1.element_epoch = struct( ...
    'epoch_clock', clockText(getIn(ref, 'relative_time_reference', 'value', 'clock')), ...
    't0_t1', [readValue(ref, 'start'); readValue(ref, 'end')]);
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
% a relative_time_reference's START or END as the v1 value it was read from
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
