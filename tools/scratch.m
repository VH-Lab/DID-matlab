%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   MEASUREMENT ONLY (branch claude/measure-standing-wiring, not for merge).
%   PER-EPOCH vs STANDING probe wiring, timed on did2.database.sqlitedb (the
%   backend NDI-matlab V2 opens through
%   ndi.database.implementations.database.did2sqlite), on SYNTHETIC sessions.
%
%   Shape 1 (today, resolveEpochProbemap mkWiring): per epoch, an epoch entity,
%   its clock anchor (relative_time_reference onto the epoch, Start/End on
%   exp_global_time), a "during the epoch" anchor (Relation intervalDuring),
%   and one `connected to` directed_relation per probe wired in that epoch
%   (parent = acquisition_system, conditions = channel number, timed by the
%   during-anchor).
%   Shape 2 (standing, proposal): the same epochs and clock anchors; one
%   digitizer device entity, NCH channel entities (type device: `channel` is
%   not in entity.type's closed value set) each `part of` it, and per wiring
%   fact (one probe on one channel over one contiguous run of epochs) one
%   `connected to` relation probe -> channel entity, timed by ONE
%   relative_time_reference onto the session (exp_global_time, Start = first
%   epoch start, End = last epoch end).
%
%   Reads timed: "all wiring for epoch k" on a sample of epochs (and on every
%   epoch for the Dab-like size), and "all probes" (getprobes analogue).

fprintf('MATLAB %s\n', version);
try
    v = mksqlite('version sql'); fprintf('SQLite (mksqlite) %s\n', char(v));
catch e
    fprintf('SQLite version not read: %s\n', e.message);
end
fprintf('DID_SCHEMA_PATH=%s\n', getenv('DID_SCHEMA_PATH'));
[~, h] = system('git rev-parse HEAD'); fprintf('DID-matlab HEAD %s', h);
[~, h] = system('git -C did-schema rev-parse HEAD'); fprintf('did-schema HEAD %s', h);

sizes = struct('name', {'DAB-LIKE', 'TENX'}, 'nEpochs', {1604, 16040}, ...
    'fullRead', {true, false});
NSAMPLE = 50;
for s = 1:numel(sizes)
    runSize(sizes(s), NSAMPLE);
end
fprintf('\n==== SCRATCH DONE ====\n');

% ======================================================================

function runSize(sz, NSAMPLE)
fprintf('\n\n######## SIZE %s: %d epochs ########\n', sz.name, sz.nEpochs);
truth = makeTruth(sz.nEpochs);
fprintf('TRUTH: epochs %d; lanes %d; probe-epoch wirings %d; distinct facts (probe runs) %d; probes %d\n', ...
    truth.nEpochs, truth.nLanes, numel(truth.wEpoch), numel(truth.runProbe), truth.nProbes);
sampleK = unique(round(linspace(1, truth.nEpochs, NSAMPLE)));
fprintf('SAMPLE: %d epochs, evenly spaced 1..%d\n', numel(sampleK), truth.nEpochs);
R = struct();
for shape = 1:3
    t0 = tic;
    [docs, ids] = buildShape(truth, shape);
    tBuild = toc(t0);
    f = [tempname() sprintf('_shape%d.sqlite', shape)];
    db = did2.database.sqlitedb(f);
    t0 = tic;
    validated = true;
    try
        rep = db.add(docs);
    catch e
        fprintf('SHAPE %d add WITH validation FAILED: %s -- %s\nretrying Validate=false\n', ...
            shape, e.identifier, e.message);
        validated = false;
        db.close(); delete(f);
        db = did2.database.sqlitedb(f);
        t0 = tic;
        rep = db.add(docs, 'Validate', false);
    end
    tAdd = toc(t0);
    d = dir(f);
    fprintf('\n=== %s SHAPE %d WRITE ===\n', sz.name, shape);
    fprintf('documents built %d; db.count %d; add report: documents %d validated %d not_validated_by_request %d\n', ...
        numel(docs), db.count(), rep.documents, rep.validated, rep.not_validated_by_request);
    fprintf('by kind: %s\n', ids.census);
    fprintf('build %.2f s; add %.2f s (validation %d); add per doc %.3f ms; file %.1f MB\n', ...
        tBuild, tAdd, validated, 1000 * tAdd / numel(docs), d.bytes / 1e6);
    if shape == 2
        setenv('DID_SCRATCH_NO_CAST', '0');
        R.s2cast = timeReads(db, truth, ids, 2, sampleK, sz, 'CAST (as on V2)');
        setenv('DID_SCRATCH_NO_CAST', '1');
        R.s2nocast = timeReads(db, truth, ids, 2, sampleK, sz, 'NO CAST (scratch patch)');
        setenv('DID_SCRATCH_NO_CAST', '0');
    elseif shape == 1
        R.s1 = timeReads(db, truth, ids, 1, sampleK, sz, 'today');
    else
        R.s3 = timeReads(db, truth, ids, 3, sampleK, sz, 'P1 epoch_id edges');
    end
    db.close();
    delete(f);
end
fprintf('\n=== %s SUMMARY (seconds) ===\n', sz.name);
labels = {'s1', 's2cast', 's2nocast', 's3'};
for j = 1:numel(labels)
    r = R.(labels{j});
    names = fieldnames(r);
    for i = 1:numel(names)
        x = r.(names{i});
        fprintf('%-9s %-28s median %.4f p90 %.4f max %.4f total %.3f over %d\n', labels{j}, names{i}, ...
            median(x), prctile(x, 90), max(x), sum(x), numel(x));
    end
end
margin(sz.name, 'epoch wiring sample, standing overlap CAST', R.s1.epoch_sample, R.s2cast.epoch_overlap_nested);
margin(sz.name, 'epoch wiring sample, standing overlap NO CAST', R.s1.epoch_sample, R.s2nocast.epoch_overlap_nested);
margin(sz.name, 'epoch wiring sample, P1 epoch_id', R.s1.epoch_sample, R.s3.epoch_sample);
if isfield(R.s1, 'epoch_all')
    margin(sz.name, 'epoch wiring ALL, standing overlap CAST', R.s1.epoch_all, R.s2cast.epoch_all_overlap);
    margin(sz.name, 'epoch wiring ALL, standing overlap NO CAST', R.s1.epoch_all, R.s2nocast.epoch_all_overlap);
    margin(sz.name, 'epoch wiring ALL, P1 epoch_id', R.s1.epoch_all, R.s3.epoch_all);
end
margin(sz.name, 'all probes, standing', R.s1.allprobes, R.s2nocast.allprobes);
margin(sz.name, 'all probes, P1', R.s1.allprobes, R.s3.allprobes);
end

function margin(name, what, a, b)
A = sum(a); B = sum(b);
fprintf('MARGIN %s %s: today total %.3f s, candidate total %.3f s, ratio %.2f; candidate <= 1.10*today + 1 s: %d (today is the v2 per-epoch shape, not v1)\n', ...
    name, what, A, B, B / A, B <= 1.10 * A + 1);
end

function printPaths(db)
p = db.testHookQueryableScalarPaths();
if isstruct(p); p = {p.path}; end
hit = p(startsWith(p, 'relative_time_reference.value') | startsWith(p, 'directed_relation.relation') ...
    | startsWith(p, 'entity.type'));
fprintf('queryable scalar paths (of %d) under relative_time_reference.value / directed_relation.relation / entity.type:\n', numel(p));
fprintf('  %s\n', hit{:});
end

% ----------------------------------------------------------------------
% ground truth
% ----------------------------------------------------------------------

function T = makeTruth(nEpochs)
% 3 probes wired per epoch (3 lanes, lane L on channel L). Along each lane a
% probe holds for a run of epochs whose length cycles 3..13 (mean 8, as Dab's
% 3..23, median 7), then a new probe takes the lane. Epoch k lasts 60 + mod(7k,120)
% s, with 5 s gaps, on one session-wide clock (exp_global_time).
T.nEpochs = nEpochs;
T.nLanes = 3;
dur = 60 + mod(7 * (1:nEpochs), 120);
T.eStart = cumsum([0, dur(1:end-1) + 5]);
T.eEnd = T.eStart + dur;
runProbe = []; runLane = []; runFirst = []; runLast = [];
wEpoch = []; wProbe = []; wLane = [];
p = 0; cyc = 3:13;
for L = 1:T.nLanes
    k = 1; c = L;
    while k <= nEpochs
        len = cyc(mod(c - 1, numel(cyc)) + 1); c = c + 1;
        last = min(nEpochs, k + len - 1);
        p = p + 1;
        runProbe(end+1) = p; runLane(end+1) = L; runFirst(end+1) = k; runLast(end+1) = last; %#ok<AGROW>
        wEpoch = [wEpoch, k:last]; wProbe = [wProbe, repmat(p, 1, last - k + 1)]; %#ok<AGROW>
        wLane = [wLane, repmat(L, 1, last - k + 1)]; %#ok<AGROW>
        k = last + 1;
    end
end
T.nProbes = p;
T.runProbe = runProbe; T.runLane = runLane; T.runFirst = runFirst; T.runLast = runLast;
T.wEpoch = wEpoch; T.wProbe = wProbe; T.wLane = wLane;
end

% ----------------------------------------------------------------------
% documents
% ----------------------------------------------------------------------

function [docs, ids] = buildShape(T, shape)
ts = '2026-11-18T00:00:00.000Z';
sid = did2.build.document('entity', struct('type', did2.build.term('', 'session'), ...
    'local_identifier', 'synthetic_session'), 'SessionId', 'synthetic_session_0001', ...
    'Id', 'synthetic_session_0001', 'Validate', false, 'CreationTimestamp', ts);
S = sid.base.id;
docs = cell(1, 4 * T.nEpochs + 4 * numel(T.wEpoch) + T.nProbes + 200);
n = 1; docs{1} = did2.document(sid);
ids.session = S;
% probes
ids.probe = cell(1, T.nProbes);
for p = 1:T.nProbes
    b = did2.build.document('entity', struct('type', did2.build.term('', 'device'), ...
        'local_identifier', sprintf('probe_%d', p)), 'SessionId', S, 'Validate', false, ...
        'CreationTimestamp', ts);
    ids.probe{p} = b.base.id;
    n = n + 1; docs{n} = did2.document(b); %#ok<AGROW>
end
% epochs + clock anchors
ids.epoch = cell(1, T.nEpochs);
ids.clock = cell(1, T.nEpochs);
for k = 1:T.nEpochs
    e = did2.build.document('entity', struct('type', did2.build.term('', 'epoch'), ...
        'local_identifier', sprintf('t%05d', k)), 'SessionId', S, 'Validate', false, ...
        'CreationTimestamp', ts);
    ids.epoch{k} = e.base.id;
    a = did2.build.relativeTimeReference(e.base.id, 'Clock', 'exp_global_time', ...
        'Start', T.eStart(k), 'End', T.eEnd(k), 'SessionId', S, 'Validate', false, ...
        'CreationTimestamp', ts);
    ids.clock{k} = a.base.id;
    n = n + 1; docs{n} = did2.document(e); %#ok<AGROW>
    n = n + 1; docs{n} = did2.document(a); %#ok<AGROW>
end
aiTerm = did2.build.term('EMPTY:0000370', 'analog input channel');
connected = did2.convert.registeredTerm('RO:0002170', 'connected to');
nRel = 0; nTR = 0; nOther = 0;
if shape == 3
    acq = did2.build.document('acquisition_system', struct('name', 'synthetic_rig'), ...
        'Edges', struct('reader_id', 'synthetic_reader_0001', ...
        'epoch_file_pattern_id', 'synthetic_pattern_0001'), ...
        'SessionId', S, 'Validate', false, 'CreationTimestamp', ts);
    n = n + 1; docs{n} = did2.document(acq);
    nOther = 1;
    for r = 1:numel(T.runProbe)
        cond = did2.build.condition(aiTerm, 'Matrix', T.runLane(r));
        rel = did2.build.directedRelation(ids.probe{T.runProbe(r)}, acq.base.id, connected, ...
            'Fields', struct('conditions', {did2.build.list(cond)}), ...
            'SessionId', S, 'CreationTimestamp', ts, 'Validate', false);
        % P1: one epoch_id edge per epoch the wiring holds in (the plan's
        % `epoch_id_#`; here the repeated `epoch_id` of a multiple edge)
        dep = rel.depends_on(:)';
        for k = T.runFirst(r):T.runLast(r)
            e = dep(1); e.name = 'epoch_id'; e.document_id = ids.epoch{k};
            dep(end+1) = e; %#ok<AGROW>
        end
        rel.depends_on = dep;
        n = n + 1; docs{n} = did2.document(rel);
        nRel = nRel + 1;
    end
elseif shape == 1
    acq = did2.build.document('acquisition_system', struct('name', 'synthetic_rig'), ...
        'Edges', struct('reader_id', 'synthetic_reader_0001', ...
        'epoch_file_pattern_id', 'synthetic_pattern_0001'), ...
        'SessionId', S, 'Validate', false, 'CreationTimestamp', ts);
    n = n + 1; docs{n} = did2.document(acq);
    nOther = 1;
    during = cell(1, T.nEpochs);
    for k = 1:T.nEpochs
        a = did2.build.relativeTimeReference(ids.epoch{k}, 'Relation', 'intervalDuring', ...
            'SessionId', S, 'Validate', false, 'CreationTimestamp', ts);
        during{k} = a.base.id;
        n = n + 1; docs{n} = did2.document(a); %#ok<AGROW>
        nTR = nTR + 1;
    end
    for w = 1:numel(T.wEpoch)
        cond = did2.build.condition(aiTerm, 'Matrix', T.wLane(w));
        rel = did2.build.directedRelation(ids.probe{T.wProbe(w)}, acq.base.id, connected, ...
            'TimeReferenceIds', {during{T.wEpoch(w)}}, ...
            'Fields', struct('conditions', {did2.build.list(cond)}), ...
            'SessionId', S, 'CreationTimestamp', ts, 'Validate', false);
        n = n + 1; docs{n} = did2.document(rel); %#ok<AGROW>
        nRel = nRel + 1;
    end
else
    dig = did2.build.document('entity', struct('type', did2.build.term('', 'device'), ...
        'local_identifier', 'synthetic_digitizer'), 'SessionId', S, 'Validate', false, ...
        'CreationTimestamp', ts);
    n = n + 1; docs{n} = did2.document(dig);
    NCH = 40;
    ch = cell(1, NCH);
    partOf = did2.build.term('', 'part_of');
    for c = 1:NCH
        b = did2.build.document('entity', struct('type', did2.build.term('', 'device'), ...
            'local_identifier', sprintf('ai%d', c)), 'SessionId', S, 'Validate', false, ...
            'CreationTimestamp', ts);
        ch{c} = b.base.id;
        r = did2.build.directedRelation(b.base.id, dig.base.id, partOf, ...
            'SessionId', S, 'CreationTimestamp', ts, 'Validate', false);
        n = n + 1; docs{n} = did2.document(b); %#ok<AGROW>
        n = n + 1; docs{n} = did2.document(r); %#ok<AGROW>
    end
    nOther = 1 + 2 * NCH;
    for r = 1:numel(T.runProbe)
        tr = did2.build.relativeTimeReference(S, 'Clock', 'exp_global_time', ...
            'Start', T.eStart(T.runFirst(r)), 'End', T.eEnd(T.runLast(r)), ...
            'SessionId', S, 'Validate', false, 'CreationTimestamp', ts);
        cond = did2.build.condition(aiTerm, 'Matrix', T.runLane(r));
        rel = did2.build.directedRelation(ids.probe{T.runProbe(r)}, ch{T.runLane(r)}, connected, ...
            'TimeReferenceIds', {tr.base.id}, ...
            'Fields', struct('conditions', {did2.build.list(cond)}), ...
            'SessionId', S, 'CreationTimestamp', ts, 'Validate', false);
        n = n + 1; docs{n} = did2.document(tr); %#ok<AGROW>
        n = n + 1; docs{n} = did2.document(rel); %#ok<AGROW>
        nRel = nRel + 1; nTR = nTR + 1;
    end
end
ids.census = sprintf(['session 1, probes %d, epochs %d, epoch clock anchors %d, ' ...
    'wiring time references %d, wiring relations %d, other %d'], ...
    T.nProbes, T.nEpochs, T.nEpochs, nTR, nRel, nOther);
docs = docs(1:n);
end

% ----------------------------------------------------------------------
% reads
% ----------------------------------------------------------------------

function q = sess(S)
q = did2.query('base.session_id', 'exact_string', S);
end

function anchors = epochAnchors(db, S, epochId)
% as NDI-matlab +vintage/ingestedEpochs.m anchorQuery: the anchors onto the epoch
anchors = db.search(did2.query('', 'isa', 'relative_time_reference') & ...
    did2.query('', 'depends_on', 'referent_id', epochId) & sess(S));
end

function probes = wiredProbes(rels)
probes = cell(1, numel(rels));
for i = 1:numel(rels)
    s = rels{i}.toStruct();
    dep = s.depends_on;
    if iscell(dep); dep = [dep{:}]; end
    probes{i} = edgeTarget(dep(strcmp({dep.name}, 'child_id')));
end
probes = unique(probes);
end

function [e0, e1] = epochInterval(anchors)
e0 = NaN; e1 = NaN;
for i = 1:numel(anchors)
    s = anchors{i}.toStruct();
    v = s.relative_time_reference.value;
    if isfield(v, 'start') && isfield(v, 'end')
        e0 = secs(v.start); e1 = secs(v.end);
        return;
    end
end
end

function R = timeReads(db, T, ids, shape, sampleK, sz, label)
S = ids.session;
startPath = 'relative_time_reference.value.start.seconds';
endPath = 'relative_time_reference.value.end.seconds';
relQ = did2.query('', 'isa', 'directed_relation') & ...
    did2.query('directed_relation.relation.node', 'exact_string', 'RO:0002170') & sess(S);
truthOf = @(k) unique(ids.probe(T.wProbe(T.wEpoch == k)));
R = struct();
fprintf('\n=== %s SHAPE %d READS [%s] ===\n', sz.name, shape, label);
if shape == 1
    perEpoch = @(k) shape1Epoch(db, S, ids.epoch{k});
    for w = 1:3; perEpoch(sampleK(w)); end  % warm-up
    [R.epoch_sample, bad] = timeEach(perEpoch, sampleK, truthOf);
    fprintf('epoch wiring (anchors -> relations by time_reference_id): %d sampled, %d mismatching truth\n', ...
        numel(sampleK), bad);
    k = sampleK(round(end/2));
    anchors = epochAnchors(db, S, ids.epoch{k});
    aIds = cellfun(@(a) a.get('base.id'), anchors, 'UniformOutput', false);
    explain(db, 'shape1 relations of one epoch', did2.query('', 'isa', 'directed_relation') & ...
        did2.query('', 'depends_on', 'time_reference_id', aIds) & sess(S));
    if sz.fullRead
        [R.epoch_all, bad] = timeEach(perEpoch, 1:T.nEpochs, truthOf);
        fprintf('epoch wiring ALL %d epochs: %.3f s total, %d mismatching truth\n', T.nEpochs, sum(R.epoch_all), bad);
    end
elseif shape == 3
    perEpoch = @(k) shape3Epoch(db, S, ids.epoch{k});
    for w = 1:3; perEpoch(sampleK(w)); end  % warm-up
    [R.epoch_sample, bad] = timeEach(perEpoch, sampleK, truthOf);
    fprintf('epoch wiring (relations by epoch_id edge): %d sampled, %d mismatching truth\n', numel(sampleK), bad);
    explain(db, 'P1 relations of one epoch', did2.query('', 'isa', 'directed_relation') & ...
        did2.query('', 'depends_on', 'epoch_id', ids.epoch{sampleK(round(end/2))}) & sess(S));
    if sz.fullRead
        [R.epoch_all, bad] = timeEach(perEpoch, 1:T.nEpochs, truthOf);
        fprintf('epoch wiring ALL %d epochs: %.3f s total, %d mismatching truth\n', T.nEpochs, sum(R.epoch_all), bad);
    end
else
    k = sampleK(round(end/2));
    [e0, e1] = epochInterval(epochAnchors(db, S, ids.epoch{k}));
    explain(db, 'shape2 overlapping wiring time refs of one epoch', overlapTR(S, e0, e1, startPath, endPath));
    nested = @(k) shape2Nested(db, S, ids.epoch{k}, startPath, endPath);
    twostep = @(k) shape2TwoStep(db, S, ids.epoch{k}, startPath, endPath);
    for w = 1:3; nested(sampleK(w)); twostep(sampleK(w)); end
    [R.epoch_overlap_nested, bad] = timeEach(nested, sampleK, truthOf);
    fprintf('epoch wiring, overlap query nested in depends_on: %d sampled, %d mismatching truth\n', numel(sampleK), bad);
    [R.epoch_overlap_twostep, bad] = timeEach(twostep, sampleK, truthOf);
    fprintf('epoch wiring, overlap query then relations by id list: %d sampled, %d mismatching truth\n', numel(sampleK), bad);
    % fallback: fetch every wiring relation and every session-referent time
    % reference once, then filter in MATLAB
    t0 = tic;
    [relsAll, trById] = fetchAllWiring(db, S, relQ);
    tFetch = toc(t0);
    fprintf('fallback fetch: %d wiring relations + %d time references in %.3f s\n', ...
        numel(relsAll.child), trById.Count, tFetch);
    R.fallback_fetch_once = tFetch;
    cold = @(k) shape2FallbackCold(db, S, ids.epoch{k}, relQ);
    warm = @(k) filterWiring(relsAll, trById, epochInterval2(db, S, ids.epoch{k}));
    [R.epoch_fallback_warm, bad] = timeEach(warm, sampleK, truthOf);
    fprintf('epoch wiring, fallback filter after one fetch: %d sampled, %d mismatching truth\n', numel(sampleK), bad);
    ks = sampleK(1:min(10, numel(sampleK)));
    [R.epoch_fallback_cold, bad] = timeEach(cold, ks, truthOf);
    fprintf('epoch wiring, fallback fetch+filter per epoch: %d sampled, %d mismatching truth\n', numel(ks), bad);
    if sz.fullRead
        [R.epoch_all_overlap, bad] = timeEach(nested, 1:T.nEpochs, truthOf);
        fprintf('epoch wiring ALL %d epochs (overlap nested): %.3f s total, %d mismatching truth\n', ...
            T.nEpochs, sum(R.epoch_all_overlap), bad);
        t0 = tic; [relsAll, trById] = fetchAllWiring(db, S, relQ); tf = toc(t0);
        t0 = tic; bad = 0;
        for kk = 1:T.nEpochs
            got = filterWiring(relsAll, trById, epochInterval2(db, S, ids.epoch{kk}));
            bad = bad + ~isequal(sort(got), sort(truthOf(kk)));
        end
        R.epoch_all_fallback = tf + toc(t0);
        fprintf('epoch wiring ALL %d epochs (fallback: one fetch %.3f s + per-epoch anchor + filter): %.3f s total, %d mismatching truth\n', ...
            T.nEpochs, tf, R.epoch_all_fallback, bad);
    end
end
% all probes (getprobes analogue): every wiring relation, its child ids, the
% probe entities by id
x = zeros(1, 3);
for rep = 1:3
    t0 = tic;
    edges = db.searchEdges(relQ, {'child_id'});
    pid = unique({edges.document_id});
    probes = cell(1, numel(pid));
    for i = 1:numel(pid); probes{i} = db.get(pid{i}); end
    x(rep) = toc(t0);
end
R.allprobes = x;
fprintf('all probes: %d probes (truth %d) from %d wiring edges; runs %s s\n', numel(pid), T.nProbes, ...
    numel(edges), mat2str(x, 4));
x = zeros(1, 3);
for rep = 1:3
    t0 = tic; rels = db.search(relQ); x(rep) = toc(t0);
end
R.allwiring_decoded = x;
fprintf('all wiring relations decoded: %d; runs %s s\n', numel(rels), mat2str(x, 4));
end

function [t, bad] = timeEach(f, ks, truthOf)
t = zeros(1, numel(ks)); bad = 0;
for i = 1:numel(ks)
    t0 = tic; got = f(ks(i)); t(i) = toc(t0);
    bad = bad + ~isequal(sort(got), sort(truthOf(ks(i))));
end
end

function explain(db, label, q)
try
    r = db.testHookExplain(q);
    fprintf('EXPLAIN [%s] exact=%d\n  SQL: %s\n', label, db.testHookIsExact(q), r.sql);
    for i = 1:numel(r.plan); fprintf('  PLAN: %s\n', r.plan(i).detail); end
catch e
    fprintf('EXPLAIN [%s] failed: %s\n', label, e.message);
end
end

function probes = shape1Epoch(db, S, epochId)
anchors = epochAnchors(db, S, epochId);
aIds = cellfun(@(a) a.get('base.id'), anchors, 'UniformOutput', false);
rels = db.search(did2.query('', 'isa', 'directed_relation') & ...
    did2.query('', 'depends_on', 'time_reference_id', aIds) & sess(S));
probes = wiredProbes(rels);
end

function q = overlapTR(S, e0, e1, startPath, endPath)
q = did2.query('', 'isa', 'relative_time_reference') & ...
    did2.query('', 'depends_on', 'referent_id', S) & ...
    did2.query(startPath, 'lessthan', e1) & did2.query(endPath, 'greaterthan', e0) & sess(S);
end

function probes = shape2Nested(db, S, epochId, startPath, endPath)
[e0, e1] = epochInterval(epochAnchors(db, S, epochId));
rels = db.search(did2.query('', 'isa', 'directed_relation') & ...
    did2.query('', 'depends_on', 'time_reference_id', overlapTR(S, e0, e1, startPath, endPath)) & sess(S));
probes = wiredProbes(rels);
end

function probes = shape2TwoStep(db, S, epochId, startPath, endPath)
[e0, e1] = epochInterval(epochAnchors(db, S, epochId));
tr = db.searchIds(overlapTR(S, e0, e1, startPath, endPath));
if isempty(tr); probes = {}; return; end
rels = db.search(did2.query('', 'isa', 'directed_relation') & ...
    did2.query('', 'depends_on', 'time_reference_id', tr) & sess(S));
probes = wiredProbes(rels);
end

function iv = epochInterval2(db, S, epochId)
[e0, e1] = epochInterval(epochAnchors(db, S, epochId));
iv = [e0, e1];
end

function [relsAll, trById] = fetchAllWiring(db, S, relQ)
rels = db.search(relQ);
relsAll.child = cell(1, numel(rels)); relsAll.tr = cell(1, numel(rels));
for i = 1:numel(rels)
    s = rels{i}.toStruct();
    dep = s.depends_on;
    if iscell(dep); dep = [dep{:}]; end
    names = {dep.name};
    relsAll.child{i} = edgeTarget(dep(strcmp(names, 'child_id')));
    t = dep(startsWith(names, 'time_reference_id'));
    if isempty(t); relsAll.tr{i} = ''; else; relsAll.tr{i} = edgeTarget(t(1)); end
end
trs = db.search(did2.query('', 'isa', 'relative_time_reference') & ...
    did2.query('', 'depends_on', 'referent_id', S) & sess(S));
trById = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(trs)
    s = trs{i}.toStruct();
    v = s.relative_time_reference.value;
    if isfield(v, 'start') && isfield(v, 'end')
        trById(char(s.base.id)) = [secs(v.start), secs(v.end)];
    end
end
end

function probes = filterWiring(relsAll, trById, iv)
keep = false(1, numel(relsAll.child));
for i = 1:numel(relsAll.child)
    t = relsAll.tr{i};
    if ~isempty(t) && isKey(trById, t)
        x = trById(t);
        keep(i) = x(1) < iv(2) && x(2) > iv(1);
    end
end
probes = unique(relsAll.child(keep));
end

function probes = shape2FallbackCold(db, S, epochId, relQ)
[relsAll, trById] = fetchAllWiring(db, S, relQ);
probes = filterWiring(relsAll, trById, epochInterval2(db, S, epochId));
end

function x = secs(c)
% a time cell's canonical seconds (a bare number if stored that way)
if isstruct(c) && isfield(c, 'seconds'); x = c.seconds; else; x = c; end
x = double(x);
end

function x = edgeTarget(e)
% a depends_on entry's target: document_id (v2), else value or id
x = '';
for f = {'document_id', 'value', 'id'}
    if isfield(e, f{1}) && ~isempty(e.(f{1})); x = char(e.(f{1})); return; end
end
end

function probes = shape3Epoch(db, S, epochId)
rels = db.search(did2.query('', 'isa', 'directed_relation') & ...
    did2.query('', 'depends_on', 'epoch_id', epochId) & sess(S));
probes = wiredProbes(rels);
end
