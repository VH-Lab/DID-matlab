function [v1, spec] = daqreader_mfdaq_epochdata_ingested(bodies, ctx)
%DAQREADER_MFDAQ_EPOCHDATA_INGESTED Rebuild a v1
%   `daqreader_mfdaq_epochdata_ingested` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested(BODIES).
%   V1 is the ingested epoch cache in NDI's v1 shape
%   (daqreader_mfdaq_epochdata_ingested.json + daqreader_epochdata_ingested.json
%   + epochid.json + base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+daq/+reader/mfdaq.m ingest_epochfiles writes it). BODIES holds:
%
%   the de-encoded cache, one `daqreader_epochdata_ingested` document as
%   v1_to_v2 padded and stamped it:
%     base.*                          the document's (the session edge read
%                                     back into base.session_id, its
%                                     creation_timestamp into base.datestamp)
%     depends_on                      its edges, each {name, value} as v1
%                                     writes them (the session edge removed)
%     files, epochid, epochtable      the document's
%     daqreader_mfdaq_epochdata_ingested.parameters
%                                     daqreader_epochdata_ingested.parameters
%   and, when the cache had an `epoch_id` edge (never on a v1 document; the
%   parent migrator's lift), the relative_time_references it lifted: each must
%   restate one clock of the epochtable, or it is unplaced.
%
%   AFTER THE BATCH PASS. [V1, SPEC] = ...(BODIES, CTX), CTX the index of the
%   whole final batch (private/batchContext, made by
%   did2.convert.roundtrip.wholeBatch). did2.convert.resolveEpochProbemap
%   RETIRES the v1 archive once every file it holds is carried by a surviving
%   per-epoch data body and every clock it states is on an emitted time
%   reference (its "v1 ingested archives retire" step), and nothing that
%   survives names it ([segment length is the time chunk], Jess Haley,
%   2026-10-29: "The v1 archive document is not kept: its id goes under [a
%   rebuilt document may lose its id] unless something links to it"). Its id
%   is then RELEASED (wholeBatch, RELEASED_ID_CLASSES). wholeBatch finds the
%   `opaque_body` documents that carry its files (a body's file_info holds the
%   v1 locations verbatim, uid included: resolveEpochProbemap archiveBodies)
%   and hands them here as BODIES. The v1 document is rebuilt from them and
%   from what CTX holds:
%
%     base.id                   not rebuilt: the id is released (wholeBatch
%                               counts it in ids_released, not as a failure)
%     base.session_id, base.datestamp
%                               the epoch's clock references, which
%                               resolveEpochProbemap writes with the archive's
%                               own creation time (rebuildBase); the bodies'
%                               session when it has no clock reference
%     base.name                 not written (v2 never writes base.name)
%     depends_on daqreader_id   the `reader_id` of the acquisition_system each
%                               owner observation names (`acquisition_system_id`);
%                               the archive was joined to its epoch through that
%                               reader. Empty when the owners name none, or
%                               more than one
%     epochid.epochid           the epoch entity's local_identifier (the
%                               entity the clock references, or else the
%                               owners' 'during' anchor, refer to)
%     daqreader_epochdata_ingested.epochtable
%                               epochclock: each clock reference's clock, in
%                               the order the owner observations name them,
%                               approx_<clock> when its clock_tolerance is 5 s
%                               (did2.convert.epochClockReferences de-encodes
%                               the prefix that way); t0_t1: [start; start +
%                               duration] per clock, one column each
%     files.file_list           the mfdaq template's 62 declared slots, in the
%                               template's order (NDI-matlab
%                               ingestion/daqreader_mfdaq_epochdata_ingested.json
%                               at the locked `main`, 73f46d1, which
%                               ndi.document writes into every such document:
%                               the writer's fixed list, as
%                               roundtrip.spikewaves writes spikewaves'):
%                               the bodies carry only the slots that held files
%     files.file_info           one entry per body member: body_data_<m-1> of a
%                               body for slot `<stem>#` is v1's `<stem><m>`
%                               (mfdaq attaches segments 1..N that way;
%                               ndi.migrate.internal.ingestedArchiveBodies reads
%                               them back the same way), a slot without `#` its
%                               own name; locations as the body holds them. In
%                               the writer's order (NDI-matlab
%                               +ndi/+daq/+reader/mfdaq.m ingest_epochfiles_plan
%                               at 73f46d1): channel_list.bin first, then by
%                               channel prefix in the writer's type order (ai,
%                               ao, ax, di, do, ti, evmktx), group, segment
%     daqreader_mfdaq_epochdata_ingested.parameters
%                               NOT REBUILT: no document of this batch holds
%                               the segment lengths. [segment length is the
%                               time chunk] puts them in the time dimension's
%                               `chunk` of a sampled_body, which NDI-matlab's
%                               second pass fills from the v1 document
%                               (ndi.migrate.internal.ingestedArchiveBodies);
%                               this batch is the one before that pass, so the
%                               round trip reports them lost
%
%   A body that is not an opaque_body, or names no file slot, is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.daqreader_mfdaq_epochdata_ingested,
%            did2.convert.resolveEpochProbemap.

arguments
    bodies cell
    ctx = []
end

CLASS = 'daqreader_mfdaq_epochdata_ingested';
PARENT = 'daqreader_epochdata_ingested';
spec = emptySpec();
v1 = struct();
if ~isempty(ctx) && ~isempty(bodies) ...
        && ~any(cellfun(@(b) strcmp(classNameOf(b), PARENT), bodies))
    [v1, spec] = fromBatch(bodies, ctx, CLASS, PARENT);   % AFTER THE BATCH PASS
    return;
end
cache = [];
refs = {};
for k = 1:numel(bodies)
    cn = classNameOf(bodies{k});
    if strcmp(cn, PARENT) && isempty(cache)
        cache = bodies{k};
    elseif strcmp(cn, 'relative_time_reference')
        refs{end+1} = bodies{k}; %#ok<AGROW>
    else
        spec.unplaced{end+1} = sprintf('emitted document %d (%s) is not the de-encoded cache', ...
            k, cn);
    end
end
if isempty(cache)
    spec.unplaced{end+1} = 'no daqreader_epochdata_ingested was emitted';
    return;
end

v1 = undoOutbound(cache);
v1.document_class.class_name = CLASS;
if isfield(v1, 'depends_on') && isstruct(v1.depends_on)
    d = struct('name', {}, 'value', {});
    for k = 1:numel(v1.depends_on)
        ids = edgeIds(struct('depends_on', v1.depends_on(k)), char(v1.depends_on(k).name));
        if isempty(ids); ids = {''}; end
        d(end+1) = struct('name', char(v1.depends_on(k).name), 'value', ids{1}); %#ok<AGROW>
    end
    v1.depends_on = d;
end
if isfield(v1, PARENT) && isstruct(v1.(PARENT)) && isfield(v1.(PARENT), 'parameters')
    v1.(CLASS) = struct('parameters', v1.(PARENT).parameters);
    v1.(PARENT) = rmfield(v1.(PARENT), 'parameters');
end

% the lifted references restate the epochtable; each must name one of its clocks
clocks = asCell(getIn(v1, PARENT, 'epochtable', 'epochclock'));
for k = 1:numel(refs)
    clk = clockText(getIn(refs{k}, 'relative_time_reference', 'value', 'clock'));   % by node first [clock terms get nodes]
    if ~any(strcmp(clk, cellfun(@char, clocks, 'UniformOutput', false)))
        spec.unplaced{end+1} = sprintf('a relative_time_reference on clock "%s" restates no clock of the epochtable', clk);
    end
end
end

% ===================== after the batch pass ================================

function [v1, spec] = fromBatch(bodies, ctx, CLASS, PARENT)
% the retired archive, rebuilt from the opaque_body documents carrying its
% files and from the batch (AFTER THE BATCH PASS, above)
spec = emptySpec();
v1 = struct();
v1.document_class = struct('class_name', CLASS);
entries = struct('name', {}, 'locations', {}, 'rank', {});
owners = {};
sessionId = '';
for k = 1:numel(bodies)
    b = bodies{k};
    if ~strcmp(classNameOf(b), 'opaque_body')
        spec.unplaced{end+1} = sprintf('document %d (%s) is not an opaque_body', ...
            k, classNameOf(b));
        continue;
    end
    slot = fieldText(getIn(b, 'data_body'), 'filename');
    if isempty(slot)
        slot = fieldText(getIn(b, 'opaque_body'), 'filename');
    end
    if isempty(slot)
        spec.unplaced{end+1} = sprintf('opaque_body %s names no file slot', char(getIn(b, 'base', 'id')));
        continue;
    end
    if isempty(sessionId)
        sessionId = char(did2.schema.cache.sessionIdOf(b));
    end
    for o = edgeIds(b, 'owner_id')
        if ~any(strcmp(owners, o{1})); owners{end+1} = o{1}; end %#ok<AGROW>
    end
    members = asCell(getIn(b, 'files', 'file_info'));
    for m = 1:numel(members)
        name = slot;
        if endsWith(slot, '#')
            name = sprintf('%s%d', slot(1:end-1), m);
        end
        loc = [];
        if isstruct(members{m}) && isfield(members{m}, 'locations')
            loc = members{m}.locations;
        end
        entries(end+1) = struct('name', name, 'locations', {loc}, ...
            'rank', {writerRank(name)}); %#ok<AGROW>
    end
end

% the owners' time references: the epoch's clock references, in the order
% the observations name them, and the epoch they refer to
clockRefs = {};
seen = {};
epochId = '';
readers = {};
for i = 1:numel(owners)
    obs = ctxDoc(ctx, owners{i});
    if isempty(obs); continue; end
    for s = edgeIds(obs, 'acquisition_system_id')
        sys = ctxDoc(ctx, s{1});
        if isempty(sys); continue; end
        for r = edgeIds(sys, 'reader_id')
            if ~any(strcmp(readers, r{1})); readers{end+1} = r{1}; end %#ok<AGROW>
        end
    end
    for t = edgeIds(obs, 'time_reference_id')
        ref = ctxDoc(ctx, t{1});
        if isempty(ref) || ~strcmp(classNameOf(ref), 'relative_time_reference')
            continue;
        end
        target = edgeIds(ref, 'referent_id');
        if isempty(epochId) && isscalar(target) && isEntityOfType(ctxDoc(ctx, target{1}), 'epoch')
            epochId = target{1};
        end
        if isempty(clockText(getIn(ref, 'relative_time_reference', 'value', 'clock'))) ...
                || any(strcmp(seen, t{1}))
            continue;
        end
        seen{end+1} = t{1}; %#ok<AGROW>
        clockRefs{end+1} = ref; %#ok<AGROW>
    end
end

% base: the clock references carry the archive's own creation time
base = struct('id', '', 'session_id', sessionId, 'name', '', 'datestamp', '');
if ~isempty(clockRefs)
    rb = rebuildBase(clockRefs{1});
    base.session_id = rb.session_id;
    base.datestamp = rb.datestamp;
end
v1.base = base;
rid = '';
if isscalar(readers); rid = readers{1}; end
v1.depends_on = struct('name', 'daqreader_id', 'value', rid);

epochString = '';
if ~isempty(epochId)
    epochString = fieldText(getIn(ctxDoc(ctx, epochId), 'entity'), 'local_identifier');
end
v1.epochid = struct('epochid', epochString);

names = cell(numel(clockRefs), 1);
t0t1 = zeros(2, numel(clockRefs));
for c = 1:numel(clockRefs)
    ref = clockRefs{c};
    clk = clockText(getIn(ref, 'relative_time_reference', 'value', 'clock'));   % by node first [clock terms get nodes]
    tol = numberOf(getIn(ref, 'time_reference', 'clock_tolerance', 'seconds'));
    if isequal(tol, 5) && any(strcmp(clk, {'utc', 'dev_global_time', 'exp_global_time'}))
        clk = ['approx_' clk];   % NDI's approx_ clocks are the clock within 5 s (+ndi/+time/clocktype.m)
    end
    names{c} = clk;
    t0 = numberOf(getIn(ref, 'relative_time_reference', 'value', 'start', 'seconds'));
    dt = numberOf(getIn(ref, 'relative_time_reference', 'value', 'duration', 'seconds'));
    if isempty(t0) || isempty(dt)
        t0t1(:, c) = [NaN; NaN];
    else
        t0t1(:, c) = [t0; t0 + dt];
    end
end
v1.(PARENT) = struct('epochtable', struct('epochclock', {names}, 't0_t1', t0t1));

[~, order] = sortrows(vertcat(entries.rank));
entries = entries(order);
fi = struct('name', {}, 'locations', {});
for e = 1:numel(entries)
    fi(end+1) = struct('name', entries(e).name, 'locations', {entries(e).locations}); %#ok<AGROW>
end
v1.files = struct('file_list', {TEMPLATE_FILE_LIST()}, 'file_info', {fi});
end

function r = writerRank(name)
% the place NDI's mfdaq writer gives an attached file (ingest_epochfiles_plan):
% channel_list.bin first, then by type in the writer's order, group, segment;
% a name of no known shape after all of them
r = [99, 0, 0];
if strcmp(name, 'channel_list.bin')
    r = [0, 0, 0];
    return;
end
tok = regexp(name, '^([a-z]+)_group(\d+)_seg\.nbf_(\d+)$', 'tokens', 'once');
if isempty(tok); return; end
p = find(strcmp(tok{1}, {'ai', 'ao', 'ax', 'di', 'do', 'ti', 'evmktx'}), 1);
if isempty(p); return; end
r = [p, str2double(tok{2}), str2double(tok{3})];
end

function c = TEMPLATE_FILE_LIST()
% NDI-matlab ingestion/daqreader_mfdaq_epochdata_ingested.json files.file_list
% at the locked `main` (73f46d1), in its order, as a column (the shape a stored
% document's JSON array reads back as)
c = {'channel_list.bin'};
for p = {'ai', 'ao', 'ax', 'di', 'do', 'ti'}
    for g = 1:10
        c{end+1} = sprintf('%s_group%d_seg.nbf_#', p{1}, g); %#ok<AGROW>
    end
end
c{end+1} = 'evmktx_group1_seg.nbf_#';
c = c(:);
end
