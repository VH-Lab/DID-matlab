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
%   PASS 1 NO LONGER WRITES THIS SHAPE. Since [retired classes leave V2]
%   (Decided by Jess Haley, 2026-10-25, step (1)) pass 1 hands the v1 document
%   on unchanged, stamped did_v1 (did2.convert.v1_to_v2 HAND_ON_CLASSES), and
%   did2.convert.roundtrip.check compares it as a carried document without
%   calling this inverse. The reading below is kept for a batch written
%   before that, whose cache is the retired V2 shape:
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
%                               the bodies carry only the slots that held files.
%                               Compared AS A SET ([archive file list compared
%                               as a set], Jess Haley, 2026-11-12): the v1
%                               list in another order is the same list; a
%                               duplicate, a missing or an extra name is lost
%                               (sameFileSet)
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
%                               round trip reports them DEFERRED to the second
%                               pass (spec.deferred, pass 'second_pass'), not
%                               lost ([archive segment lengths measured after
%                               the second pass], Jess Haley, 2026-11-12), and
%                               wholeBatch counts them in
%                               deferred_to_second_pass. Only these two
%                               fields: any other parameter is still lost
%
%   A body that is not an opaque_body or a sampled_body, or whose v1 names
%   cannot be rebuilt, is unplaced.
%
%   AFTER NDI'S SECOND PASS. The same rebuild reads the shape NDI-matlab's
%   second pass leaves (ndi.migrate.internal.ingestedArchiveBodies), through
%   did2.convert.roundtrip.ingestedArchiveFiles, which says how each name is
%   rebuilt (Decided by Jess Haley, 2026-11-17, did-schema
%   did_v2_go_forward_class_audit.md):
%     a converted channel group is a sampled_body; its members are named
%       body_data_0.. ([migrated body members renamed]) and NDI's names are
%       rebuilt from its channel type, group and segment ("The round trip
%       rebuilds NDI's names from the body's channel type, group and segment
%       number"); its owner may be another document than the recording
%       observation ([non-specimen channel groups get their own owner]): the
%       owners of every body are read
%     channel_list.bin, evmktx_group<g>_seg.nbf_1 and an evenly spaced time
%       group's segments may have been removed ([channel list rows get v2
%       homes], [unpacked events file is removed], [evenly spaced time is a
%       covariate]): their file_info entries are rebuilt BY NAME, in the
%       writer's place. Their v1 LOCATIONS are not: the file stays in NDI's
%       store, unreferenced, and no v2 document names its uid. For
%       channel_list.bin and an evmktx file that is an ACCEPTED LOSS
%       (Decided by Jess Haley, 2026-11-18 [removed file locations are an
%       accepted loss]: "the removed file's v1 storage record is an accepted
%       loss"), listed and counted by did2.convert.roundtrip.wholeBatch
%       (ACCEPTED_LOSSES, 'removed archive file location'); the removed
%       evenly spaced time segments are not covered by that decision, so
%       their location leaves still read lost. The file itself is compared
%       by its content (did2.convert.roundtrip.compareIngestedArchiveFiles),
%       which needs the bytes, so not here.
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
% the retired archive, rebuilt from the data bodies carrying its files (pass
% 1's opaque_body documents, or the sampled_body documents NDI's second pass
% makes of them) and from the batch (AFTER THE BATCH PASS, above)
spec = emptySpec();
v1 = struct();
v1.document_class = struct('class_name', CLASS);
entries = struct('name', {}, 'locations', {}, 'rank', {});
owners = {};
sessionId = '';
for k = 1:numel(bodies)
    b = bodies{k};
    if ~any(strcmp(classNameOf(b), {'opaque_body', 'sampled_body'}))
        spec.unplaced{end+1} = sprintf('document %d (%s) is not an opaque_body or a sampled_body', ...
            k, classNameOf(b));
        bodies{k} = [];
    end
end
bodies = bodies(~cellfun(@isempty, bodies));
% the v1 names of every member, in either shape (did2.convert.roundtrip.
% ingestedArchiveFiles: pass 1's slot names, or NDI's names rebuilt from a
% sampled_body's channel type, group and segment, [migrated body members
% renamed]), and the files NDI's second pass unpacked and removed
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, ctx);
for k = 1:numel(R.members)
    mem = R.members(k);
    b = ctxDoc(ctx, mem.body_id);
    if isempty(b)
        i = find(cellfun(@(x) strcmp(char(getIn(x, 'base', 'id')), mem.body_id), bodies), 1);
        if ~isempty(i); b = bodies{i}; end
    end
    if isempty(mem.names)
        if ~isempty(mem.why)
            spec.unplaced{end+1} = sprintf('%s %s: %s', mem.class_name, mem.body_id, mem.why);
        end
        continue;
    end
    if isempty(sessionId)
        sessionId = char(did2.schema.cache.sessionIdOf(b));
    end
    for o = edgeIds(b, 'owner_id')
        if ~any(strcmp(owners, o{1})); owners{end+1} = o{1}; end %#ok<AGROW>
    end
    members = asCell(getIn(b, 'files', 'file_info'));
    members = members(mem.file_index);   % in segment order (ingestedArchiveFiles)
    for m = 1:min(numel(members), numel(mem.names))
        loc = [];
        if isfield(members{m}, 'locations'); loc = members{m}.locations; end
        entries(end+1) = struct('name', mem.names{m}, 'locations', {loc}, ...
            'rank', {writerRank(mem.names{m})}); %#ok<AGROW>
    end
end
% the files the second pass unpacked and removed ([unpacked events file is
% removed], [channel list rows get v2 homes]) and the evenly spaced time it
% removed ([evenly spaced time is a covariate]): their names are rebuilt; the
% file is rebuilt by its content (did2.convert.roundtrip.
% compareIngestedArchiveFiles), and no document holds its v1 location, so its
% locations are not rebuilt
removed = R.time_segments;
if strcmp(R.channel_list_state, 'rebuilt'); removed{end+1} = 'channel_list.bin'; end
for e = 1:numel(R.evmktx)
    if ~R.evmktx(e).carried; removed{end+1} = R.evmktx(e).name; end %#ok<AGROW>
end
for r = 1:numel(removed)
    entries(end+1) = struct('name', removed{r}, 'locations', {[]}, ...
        'rank', {writerRank(removed{r})}); %#ok<AGROW>
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

% [archive file list compared as a set] (Jess Haley, 2026-11-12)
spec.same(end+1) = struct('path', 'files.file_list', 'fn', @sameFileSet, ...
    'why', '[archive file list compared as a set] (Jess Haley, 2026-11-12)');
% [archive segment lengths measured after the second pass] (Jess Haley,
% 2026-11-12): NDI-matlab's second pass writes them on a sampled_body's time
% chunk ([segment length is the time chunk]); this batch is before it
why = '[archive segment lengths measured after the second pass] (Jess Haley, 2026-11-12)';
spec.deferred = struct('path', { ...
    [CLASS '.parameters.sample_analog_segment'], ...
    [CLASS '.parameters.sample_digital_segment']}, ...
    'pass', 'second_pass', 'why', why);
end

function tf = sameFileSet(v1List, rebuiltList)
% the two file lists hold the same names, each as many times, in any order
% ([archive file list compared as a set]): order is ignored, a duplicate or a
% different membership is not
tf = false;
a = textList(v1List);
b = textList(rebuiltList);
if isempty(a) || isempty(b) || numel(a) ~= numel(b)
    return;
end
tf = isequal(sort(a), sort(b));
end

function c = textList(v)
% V as a column cellstr ({} when it is not a list of text)
c = {};
if ischar(v) && (isrow(v) || isempty(v))
    v = {v};
elseif isstring(v)
    v = cellstr(v);
end
if ~iscell(v) || ~all(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v(:)))
    return;
end
c = cellfun(@(x) reshape(char(x), 1, []), v(:), 'UniformOutput', false);
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
