function [v1, spec] = syncrule_mapping(bodies, ctx)
%SYNCRULE_MAPPING Rebuild a v1 `syncrule_mapping` from its fold.
%
%   [V1, SPEC] = did2.convert.roundtrip.syncrule_mapping(BODIES). V1 is the
%   mapping in NDI's v1 shape (syncrule_mapping.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+time/syncgraph.m ingest writes it).
%
%   Pass 1 carries every v1 mapping whole (carry-036); did2.convert.roundtrip.
%   check compares a carry itself and never calls this inverse. This inverts
%   the FOLD did2.convert.epochMint makes ([device clocks on one epoch] (3)):
%   BODIES holds the `clock_alignment` and the documents its two ends are read
%   back from:
%
%     base.id, session_id, datestamp   the clock_alignment (rebuildBase)
%     depends_on syncgraph_id          its clock_alignment_policy_id
%     depends_on syncrule_id           its clock_alignment_configuration_id
%     syncrule_mapping.cost            its cost
%     syncrule_mapping.mapping         its polynomial coefficients
%     epochnode_a / _b, from the relative_time_reference its input_id /
%     output_id names:
%       epoch_clock, t0_t1             the reference's clock, and [start,
%                                      start + duration] in seconds
%       objectname                     the acquisition_system the reference
%                                      is on (its referent): its name
%       objectclass                    that system's software entity: its
%                                      local_identifier before any '@'
%       epoch_id, epoch_session_id     the epoch entity whose time_reference_id
%                                      names the reference: its
%                                      local_identifier and its session
%       epochprobemap                  the epoch's manifest: the v1
%                                      epochfiles_ingested of that session and
%                                      epoch read by the system's file navigator
%                                      (its epoch_file_pattern_id)
%
%   base.name is not rebuilt (V2 writes none; the fold takes only an empty
%   one); `files` is not rebuilt (the fold takes only one that lists no file).
%   Any other document in BODIES, or a missing one, is unplaced.
%
%   IN THE WHOLE BATCH. The documents the ends are read from are not ones the
%   mapping became: epochMint mints the references, and the epoch, the
%   systems and the manifest come from other sources. The whole-batch round
%   trip ([whole-batch round trip], Jess Haley, 2026-10-27) passes CTX, the
%   index of the final batch (private/batchContext); they are then read from
%   it, and only BODIES' own documents must each have a role. By then the
%   manifest may be the `ingestion_manifest` did2.convert.resolveEpochProbemap
%   renamed it to; its probe map is read back from the batch
%   (private/manifestProbemap).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.syncrule_mapping, did2.convert.epochMint.

arguments
    bodies cell
    ctx = []
end

spec = emptySpec();
v1 = struct();
nOwn = numel(bodies);
used = false(1, nOwn);
ca = [];
for k = 1:nOwn
    if strcmp(classNameOf(bodies{k}), 'clock_alignment')
        if isempty(ca)
            ca = bodies{k};
            used(k) = true;
        end
    end
end
if isempty(ca)
    spec.unplaced{end+1} = 'no clock_alignment was emitted';
    return;
end
[base, ~] = rebuildBase(ca);
if ~isempty(ctx)
    bodies = [bodies, endDocs(ca, ctx)];
    used = [used, false(1, numel(bodies) - nOwn)];
end

coeffs = getIn(ca, 'polynomial', 'value', 'coefficients');
if isempty(coeffs)
    coeffs = getIn(ca, 'clock_alignment', 'value', 'coefficients');
end
cost = getIn(ca, 'clock_alignment', 'cost');

blk = struct();
blk.cost = cost;
blk.mapping = reshape(double(coeffs), [], 1);   % jsondecode's column
ends = {'input_id', 'epochnode_a'; 'output_id', 'epochnode_b'};
for e = 1:size(ends, 1)
    [node, used, why] = endpoint(bodies, used, firstId(ca, ends{e, 1}), base.session_id, ctx);
    if ~isempty(why)
        spec.unplaced{end+1} = sprintf('%s: %s', ends{e, 2}, why);
    end
    blk.(ends{e, 2}) = node;
end
for k = find(~used(1:nOwn))
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in the mapping', ...
        k, classNameOf(bodies{k}));
end

v1.document_class = struct('class_name', 'syncrule_mapping');
v1.depends_on = struct('name', {'syncgraph_id', 'syncrule_id'}, ...
    'value', {firstId(ca, 'clock_alignment_policy_id'), ...
    firstId(ca, 'clock_alignment_configuration_id')});
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'datestamp', base.datestamp);
v1.syncrule_mapping = blk;
end

% ===================== helpers =========================================

function [node, used, why] = endpoint(bodies, used, refId, sessionId, ctx)
%ENDPOINT One epochnode, read back from the reference REFID and the documents
%   it is tied to; WHY says what could not be read ('' when all of it was).
node = struct('epoch_id', '', 'epoch_session_id', '', 'epochprobemap', '', ...
    'epoch_clock', '', 't0_t1', [], 'objectname', '', 'objectclass', '');
why = '';
[ref, i] = withId(bodies, refId);
if isempty(ref)
    why = 'its relative_time_reference is not among the documents';
    return;
end
used(i) = true;
node.epoch_clock = clockText(getIn(ref, 'relative_time_reference', 'value', 'clock'));   % by node first [clock terms get nodes]
t0 = numberOf(getIn(ref, 'relative_time_reference', 'value', 'start', 'seconds'));
dt = numberOf(getIn(ref, 'relative_time_reference', 'value', 'duration', 'seconds'));
if isempty(t0) || isempty(dt)
    why = 'its reference states no start or duration in seconds';
else
    node.t0_t1 = [t0; t0 + dt];
end

% the epoch holding the reference
epoch = [];
for k = 1:numel(bodies)
    if isEntityOfType(bodies{k}, 'epoch') && any(strcmp(edgeIds(bodies{k}, 'time_reference_id'), refId))
        epoch = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(epoch)
    why = 'no epoch entity holds its reference';
else
    node.epoch_id = fieldText(epoch.entity, 'local_identifier');
    node.epoch_session_id = char(did2.schema.cache.sessionIdOf(epoch));
end

% the acquisition system the reference is on, and its software
sysIds = edgeIds(ref, 'referent_id');
sys = [];
if ~isempty(sysIds)
    [sys, i] = withId(bodies, sysIds{1});
end
if isempty(sys) || ~strcmp(classNameOf(sys), 'acquisition_system')
    why = 'its referent acquisition_system is not among the documents';
    return;
end
used(i) = true;
node.objectname = fieldText(getIn(sys, 'acquisition_system'), 'name');
if isempty(node.objectname)
    node.objectname = fieldText(sys.base, 'name');
end
swIds = edgeIds(sys, 'software_id');
if ~isempty(swIds)
    [sw, i] = withId(bodies, swIds{1});
    if ~isempty(sw)
        used(i) = true;
        node.objectclass = regexprep(fieldText(getIn(sw, 'entity'), 'local_identifier'), '@.*$', '');
    end
end

% the epoch's manifest, read by the system's file navigator: the v1
% epochfiles_ingested, or the ingestion_manifest the batch pass renamed it to
navIds = edgeIds(sys, 'epoch_file_pattern_id');
for k = 1:numel(bodies)
    b = bodies{k};
    if isempty(navIds); break; end
    switch classNameOf(b)
        case 'epochfiles_ingested'
            if strcmp(fieldText(getIn(b, 'epochfiles_ingested'), 'epoch_id'), node.epoch_id) ...
                    && strcmp(char(did2.schema.cache.sessionIdOf(b)), char(sessionId)) ...
                    && any(strcmp(edgeIds(b, 'filenavigator_id'), navIds{1}))
                node.epochprobemap = fieldText(b.epochfiles_ingested, 'epochprobemap');
                used(k) = true;
                break;
            end
        case 'ingestion_manifest'
            if ~isempty(epoch) && any(strcmp(edgeIds(b, 'epoch_id'), char(epoch.base.id))) ...
                    && any(strcmp(edgeIds(b, 'epoch_file_pattern_id'), navIds{1}))
                [pm, bad] = manifestProbemap(b, ctx);
                node.epochprobemap = pm;
                if ~isempty(bad)
                    why = strjoin(bad, '; ');
                end
                used(k) = true;
                break;
            end
    end
end
end

function docs = endDocs(ca, ctx)
%ENDDOCS From the batch: the two references the clock_alignment names, the
%   epochs holding them, the acquisition systems they are on, those systems'
%   software, and the manifests those systems' file patterns read.
docs = {};
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
refIds = [edgeIds(ca, 'input_id'), edgeIds(ca, 'output_id')];
for r = 1:numel(refIds)
    ref = ctxDoc(ctx, refIds{r});
    [docs, seen] = addDoc(docs, seen, ref);
    epochIds = {};
    epochStrings = {};
    for k = ctxReferrers(ctx, refIds{r})
        if isEntityOfType(ctx.docs{k}, 'epoch')
            [docs, seen] = addDoc(docs, seen, ctx.docs{k});
            epochIds{end+1} = char(ctx.docs{k}.base.id); %#ok<AGROW>
            epochStrings{end+1} = fieldText(ctx.docs{k}.entity, 'local_identifier'); %#ok<AGROW>
        end
    end
    % the renamed manifests name their epoch
    for e = 1:numel(epochIds)
        for k = ctxReferrers(ctx, epochIds{e})
            if strcmp(classNameOf(ctx.docs{k}), 'ingestion_manifest')
                [docs, seen] = addDoc(docs, seen, ctx.docs{k});
            end
        end
    end
    if isempty(ref); continue; end
    sysIds = edgeIds(ref, 'referent_id');
    for s = 1:numel(sysIds)
        sys = ctxDoc(ctx, sysIds{s});
        [docs, seen] = addDoc(docs, seen, sys);
        if isempty(sys); continue; end
        sw = edgeIds(sys, 'software_id');
        for w = 1:numel(sw)
            [docs, seen] = addDoc(docs, seen, ctxDoc(ctx, sw{w}));
        end
        % a manifest not renamed names its epoch by string only
        navs = edgeIds(sys, 'epoch_file_pattern_id');
        for n = 1:numel(navs)
            for k = ctxReferrers(ctx, navs{n})
                b = ctx.docs{k};
                if strcmp(classNameOf(b), 'epochfiles_ingested') ...
                        && any(strcmp(fieldText(getIn(b, 'epochfiles_ingested'), 'epoch_id'), epochStrings))
                    [docs, seen] = addDoc(docs, seen, b);
                end
            end
        end
    end
end
end

function [docs, seen] = addDoc(docs, seen, b)
if isempty(b) || ~isfield(b, 'base') || ~isfield(b.base, 'id')
    return;
end
id = char(b.base.id);
if isKey(seen, id)
    return;
end
seen(id) = true;
docs{end+1} = b;
end

function [b, idx] = withId(bodies, id)
b = [];
idx = 0;
for k = 1:numel(bodies)
    if isfield(bodies{k}, 'base') && isfield(bodies{k}.base, 'id') ...
            && strcmp(char(bodies{k}.base.id), char(id))
        b = bodies{k};
        idx = k;
        return;
    end
end
end

function id = firstId(body, name)
ids = edgeIds(body, name);
id = '';
if ~isempty(ids); id = ids{1}; end
end
