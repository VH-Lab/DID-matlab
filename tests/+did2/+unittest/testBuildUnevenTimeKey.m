function tests = testBuildUnevenTimeKey
%TESTBUILDUNEVENTIMEKEY A recording's unevenly spaced timestamps are one
%   standalone `time` value stored in a body, and every channel-group body
%   keys its time covariate to it.
%
%   Decided by Jess Haley, 2026-11-03 [uneven time is a keyed time value]
%   (did-schema did_v2_go_forward_class_audit.md): "the timestamps are one
%   standalone `time` value document (`data_body: true`) whose `sampled_body`
%   (one `time` dimension, seconds) holds them; every channel-group body of
%   that recording lists it in `key_id` and its time covariate (along the
%   time dimension) is `key` to it, so sample k's time is position k of that
%   value; no time observation is minted; evenly spaced time stays
%   `origin`+`spacing`. Accepted limitation: the `time` value carries no time
%   reference". Its DID-matlab half: "check the validator accepts a
%   body-stored `time` value as a keyed document".
%
%   These tests build that shape with did2.build (which runs
%   did2.schema.cache/validateDocument as its last step, with the default
%   strict modes) and check it again with validateDocument and
%   did2.validate.references over the whole set. NDI-matlab's
%   ndi.migrate.internal.ingestedArchiveBodies writes the same shape for the
%   migrated ingested archives whose time channel is not evenly spaced.
%
%   Run with:  results = runtests('did2.unittest.testBuildUnevenTimeKey');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping uneven time key tests');
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== the fixture ==========================================

function t = TIME()
t = struct('node', 'om:Time', 'name', 'time');
end

function t = CHANNEL()
t = struct('node', 'NCIT:C44170', 'name', 'Channel');
end

function t = VOLTAGE()
t = struct('node', 'AFO:AFR_0001916', 'name', 'voltage');
end

function f = fixture(nGroups)
% One recording observation whose value is in NGROUPS channel-group bodies,
% each keyed to one standalone `time` value whose body holds the n
% timestamps. The ids the set points at but does not hold (the subject, the
% epoch's time reference, the session) are f.external.
f.sid = did.ido.unique_id();
f.subjectId = did.ido.unique_id();
f.timeRefId = did.ido.unique_id();
f.n = 7;
f.obs = did2.build.statement('observation', f.subjectId, VOLTAGE(), [], ...
    'ValueKind', 'voltage', 'DataBody', true, ...
    'TimeReferenceIds', {f.timeRefId}, 'SessionId', f.sid);
% the standalone time value: data_body true, no inline value, no time
% reference (the accepted limitation)
f.time = did2.build.document('time', struct('data_body', true), 'SessionId', f.sid);
% its body: one `time` dimension of n positions, the timestamps (seconds,
% the time value's canonical unit)
f.timeBody = did2.build.sampledBody(f.time.base.id, ...
    did2.build.dimension(TIME(), f.n), 'SessionId', f.sid);
f.groups = cell(1, nGroups);
for g = 1:nGroups
    nCh = g + 1;
    dims = did2.build.list( ...
        did2.build.dimension(TIME(), f.n), ...
        did2.build.dimension(CHANNEL(), nCh));
    covs = did2.build.list( ...
        did2.build.covariate(TIME(), 0, 'Key', 0), ...
        did2.build.covariate(CHANNEL(), 1, 'Count', 1:nCh));
    f.groups{g} = did2.build.sampledBody(f.obs.base.id, dims, ...
        'Covariates', covs, 'KeyIds', {f.time.base.id}, 'DatumOrder', 'F', ...
        'SessionId', f.sid);
end
f.all = [{f.obs, f.time, f.timeBody}, f.groups];
f.external = {f.sid, f.subjectId, f.timeRefId};
end

function ids = edgeIds(doc, name)
ids = {};
deps = doc.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    if strcmp(char(deps{k}.name), name)
        ids{end+1} = char(deps{k}.document_id); %#ok<AGROW>
    end
end
end

% ===================== the tests ============================================

function testTheTimeValueIsStoredInItsBody(testCase)
f = fixture(1);
verifyEqual(testCase, f.time.document_class.class_name, 'time');
verifyTrue(testCase, logical(f.time.value.data_body));
verifyFalse(testCase, isfield(f.time, 'time') && isfield(f.time.time, 'value') ...
    && ~isempty(f.time.time.value), 'the timestamps are in the body, not inline');
% no time reference ([clock only on the time reference]: accepted limitation)
deps = f.time.depends_on;
if isstruct(deps); deps = num2cell(deps); end
names = cellfun(@(d) char(d.name), deps, 'UniformOutput', false);
verifyFalse(testCase, any(startsWith(names, 'time_reference')));
verifyEqual(testCase, edgeIds(f.timeBody, 'owner_id'), {f.time.base.id});
verifyEqual(testCase, numel(f.timeBody.data.dimensions), 1);
verifyEqual(testCase, f.timeBody.data.dimensions.term.node, 'om:Time');
verifyEqual(testCase, f.timeBody.data.dimensions.n, f.n);
end

function testEveryGroupBodyKeysItsTimeToTheValue(testCase)
f = fixture(2);
for g = 1:numel(f.groups)
    b = f.groups{g};
    verifyEqual(testCase, edgeIds(b, 'key_id'), {f.time.base.id});
    verifyEqual(testCase, edgeIds(b, 'owner_id'), {f.obs.base.id});
    c = b.data.covariates(1);
    verifyEqual(testCase, c.variable.node, 'om:Time');
    verifyEqual(testCase, c.along, 0);
    verifyEqual(testCase, c.key, 0);
    % key, not origin+spacing: the samples are not evenly spaced
    verifyTrue(testCase, ~isfield(c, 'origin') || isempty(c.origin));
    verifyTrue(testCase, ~isfield(c, 'spacing') || isempty(c.spacing));
    % the keyed value has as many positions as the time dimension
    verifyEqual(testCase, b.data.dimensions(1).n, f.timeBody.data.dimensions.n);
end
end

function testTheValidatorAcceptsEveryDocument(testCase)
f = fixture(2);
cache = did2.schema.cache.shared();
for k = 1:numel(f.all)
    verifyWarningFree(testCase, @() cache.validateDocument(f.all{k}));
end
end

function testTheKeyedTimeValueResolves(testCase)
f = fixture(2);
r = did2.validate.references(f.all, 'KnownIds', f.external);
verifyEqual(testCase, r.total_docs, numel(f.all));
verifyGreaterThan(testCase, r.edges_examined, 0);
verifyEqual(testCase, r.orphan_count, 0);
% without the time value the key_id edges dangle: the check does look at them
r = did2.validate.references(f.all([1, 3:end]), 'KnownIds', f.external);
names = {r.orphans.edge_name};
verifyEqual(testCase, sum(strcmp(names, 'key_id')), numel(f.groups));
end
