function tests = testIngestedArchiveFiles
%TESTINGESTEDARCHIVEFILES did2.convert.roundtrip.ingestedArchiveFiles and
%   compareIngestedArchiveFiles: a v1 ingested archive's attached files
%   rebuilt from the v2 documents of its epoch, in either shape, and compared
%   with the v1 files.
%
%   Decided by Jess Haley, 2026-11-17 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): [event channels are
%   time-valued observations] and its follow-ups ([several marker numbers are
%   a second dimension], [unpacked event bodies are uncompressed], [unpacked
%   events file is removed]), [channel list rows get v2 homes], [time channel
%   is a per-channel covariate], [migrated body members renamed],
%   [non-specimen channel groups get their own owner] and [channel name is
%   an identifier]; and by Jess Haley, 2026-11-18, [event row defaults are
%   notation].
%
%   THE SECOND-PASS SHAPE here (secondPassEpoch) is built by hand from those
%   decisions and from what NDI-matlab's second pass writes today
%   (ndi.migrate.internal.ingestedArchiveBodies at e040dfe4: a converted
%   channel group is a sampled_body, dimensions time x channel, covariates
%   time (origin 0, spacing 1/rate), channel number, offset, scale (volts,
%   the v1 scale as source_value), its condition Channel = the channel type,
%   its `filename` kept). What the decisions add and NDI-matlab does not
%   write yet: the "time channel" covariate (EMPTY:0000374), the name
%   covariate (a text covariate along the channel dimension, variable
%   NCIT:C25364 "Identifier", [channel name is an identifier]), the members
%   renamed body_data_<k>, and the unpacked event and marker channels (an
%   observation each, its channel type and number as a condition, its times
%   in a sampled_body of little-endian float64; the marker's codes event x
%   column, keyed to a `time` value). The test that it matches what
%   NDI-matlab then writes is that work's own.
tests = functiontests(localfunctions);
end

function testTheChannelListIsRebuiltFromTheSecondPassShape(testCase)
[docs, bodies, ex] = secondPassEpoch(testCase);
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, docs);
verifyEqual(testCase, R.shape, 'second pass');
verifyEqual(testCase, R.documents_inspected, numel(bodies) + numel(docs), 'the denominator');
verifyEqual(testCase, R.group_bodies, 2);
verifyEqual(testCase, R.event_observations, 2);
verifyEqual(testCase, R.channel_list_state, 'rebuilt');
verifyTrue(testCase, isequaln(R.channel_list, ex.rows), describeRows(R.channel_list));
% the fields no decision homes are listed, never silently filled: the time
% channel the groups point at, whose own row is not rebuilt
verifyEqual(testCase, {R.no_home.field}, {'time row'});
verifyEqual(testCase, R.no_home.value, 1);
% [event row defaults are notation] (Jess Haley, 2026-11-18): each event and
% marker row's sample rate, offset, scale and time channel are NDI's
% defaults, rebuilt and listed as notation, not as a field without a home
verifyEqual(testCase, [R.notation.row], [4 5]);
verifyEqual(testCase, unique({R.notation.field}), {'sample_rate, offset, scale, time_channel'});
for e = 4:5
    verifyTrue(testCase, isequaln([R.channel_list(e).sample_rate, R.channel_list(e).offset, ...
        R.channel_list(e).scale, R.channel_list(e).time_channel], [NaN 0 1 NaN]), ...
        describeRows(R.channel_list(e)));
end
end

function testTheNameIsReadFromTheIdentifierCovariateOnly(testCase)
% [channel name is an identifier] (Jess Haley, 2026-11-17): the name is the
% text covariate whose variable is NCIT:C25364 "Identifier", by node; a text
% covariate along the channels with another variable is not a name (a check
% that cannot fail proves nothing)
[docs, bodies, ex] = secondPassEpoch(testCase);
ai = bodies{1};
i = find(cellfun(@(c) isfield(c, 'text'), ai.data.covariates));
assertNumElements(testCase, i, 1);
verifyEqual(testCase, ai.data.covariates{i}.variable.node, 'NCIT:C25364');
ai.data.covariates{i}.variable = struct('node', 'NCIT:C42614', 'name', 'Name');
docs{5} = ai;
R = did2.convert.roundtrip.ingestedArchiveFiles({ai, bodies{2}}, docs);
want = ex.rows;
want(2).name = 'ai2';
verifyTrue(testCase, isequaln(R.channel_list, want), describeRows(R.channel_list));
% every channel named, one text value per channel, after a JSON round trip
ai = bodies{1};
ai.data.covariates{i}.text = {'chanA', 'chanB'};
j = jsondecode(jsonencode(ai));
docs{5} = j;
R = did2.convert.roundtrip.ingestedArchiveFiles({j, bodies{2}}, docs);
verifyEqual(testCase, {R.channel_list(1:2).name}, {'chanA', 'chanB'});
end

function testTheRowsFollowNdisRuleAfterAJsonRoundTrip(testCase)
% NDI-matlab's rule (ndi.vintage.ingestedChannelList, VH-Lab/NDI-matlab#1251):
% a NaN time channel read back from JSON as null is still NaN; a rate within
% 1e-9 of a whole number is that number
[docs, bodies, ex] = secondPassEpoch(testCase);
ai = bodies{1};
ai.data.covariates{5}.quantity.value = [1 NaN];
ai.data.covariates{1}.spacing.value = 1 / 30000 * (1 + 1e-12);
j = jsondecode(jsonencode(ai));
docs{5} = j;
R = did2.convert.roundtrip.ingestedArchiveFiles({j, bodies{2}}, docs);
want = ex.rows;
want(2).time_channel = NaN;
verifyTrue(testCase, isequaln(R.channel_list, want), describeRows(R.channel_list));
end

function testAMemberStillNamedByNdiKeepsItsName(testCase)
% [migrated body members renamed]: "a name that does not fit NDI's pattern is
% not renamed"; one still named by NDI is read as that segment (as NDI-matlab's
% readers read it)
[docs, bodies] = secondPassEpoch(testCase);
ai = bodies{1};
ai.files.file_info(2).name = 'ai_group1_seg.nbf_2';
ai.files.file_info = ai.files.file_info([2 1]);
R = did2.convert.roundtrip.ingestedArchiveFiles({ai}, docs);
verifyEqual(testCase, R.members(1).names, {'ai_group1_seg.nbf_1', 'ai_group1_seg.nbf_2'});
verifyEqual(testCase, R.members(1).file_index, [2 1]);
end

function testMemberNamesComeFromTypeGroupAndSegment(testCase)
% [migrated body members renamed]: "The round trip rebuilds NDI's names from
% the body's channel type, group and segment number". A digital_out group is
% named `di`, as NDI's writer names it; a body without `filename` gets its
% group from its channel numbers by the writer's rule
[docs, bodies] = secondPassEpoch(testCase);
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, docs);
verifyEqual(testCase, R.members(1).names, {'ai_group1_seg.nbf_1', 'ai_group1_seg.nbf_2'});
verifyEqual(testCase, R.members(2).names, {'di_group1_seg.nbf_1'});
verifyEqual(testCase, R.time_segments, {'ti_group1_seg.nbf_1', 'ti_group1_seg.nbf_2'});
% each body's own owners ([non-specimen channel groups get their own owner])
verifyEqual(testCase, R.owners(1).owner_ids, {'obs_rec'});
verifyEqual(testCase, R.owners(2).owner_ids, {'obs_dig'});
end

function testEveryChannelTypeNamesItsFile(testCase)
% the channel type is read by node: each group type the writer attaches, as
% did2.convert.channelType writes its term, names its file prefix
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
want = {'ai', 'ai'; 'ao', 'ao'; 'ax', 'ax'; 'di', 'di'; 'do', 'di'};
for k = 1:size(want, 1)
    t = did2.convert.channelType(want{k, 1});
    b = groupBody('b', 'own', t, [1 2], {}, 'Filename', '');
    R = did2.convert.roundtrip.ingestedArchiveFiles({b}, {b});
    verifyEqual(testCase, R.members(1).names, {sprintf('%s_group1_seg.nbf_1', want{k, 2})}, want{k, 1});
end
% the writer's group rule: 1 + floor(number / 400) for analog input
b = groupBody('b', 'own', did2.convert.channelType('ai'), [400 401], {}, 'Filename', '');
R = did2.convert.roundtrip.ingestedArchiveFiles({b}, {b});
verifyEqual(testCase, R.members(1).names, {'ai_group2_seg.nbf_1'});
end

function testABodyWhoseNameCannotBeRebuiltSaysWhy(testCase)
% no channel type and no slot: no names, and the reason (a check that cannot
% fail proves nothing)
b = groupBody('b', 'own', struct('node', '', 'name', ''), [1 2], {}, 'Filename', '');
R = did2.convert.roundtrip.ingestedArchiveFiles({b}, {b});
verifyEmpty(testCase, R.members(1).names);
verifyNotEmpty(testCase, R.members(1).why);
% a slot of another type than its condition
b = groupBody('b', 'own', did2.convert.channelType('ai'), [1 2], {}, 'Filename', 'ax_group1_seg.nbf_#');
R = did2.convert.roundtrip.ingestedArchiveFiles({b}, {b});
verifyEmpty(testCase, R.members(1).names);
verifySubstring(testCase, R.members(1).why, 'is not a ai file');
end

function testTheEventsFileContentIsRebuilt(testCase)
% [event channels are time-valued observations]: times are seconds from the
% epoch's start (v1 holds them on the epoch's clock: the start is added
% back); a marker with two numbers per event is event x column ([several
% marker numbers are a second dimension]); the vector NDI-compress writes is
% rebuilt too
[docs, bodies, ex] = secondPassEpoch(testCase);
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, docs, 'ReadBody', ...
    @(b) did2.convert.roundtrip.ingestedArchiveFiles('readFloat64', b));
assertNumElements(testCase, R.evmktx, 1);
e = R.evmktx;
verifyEqual(testCase, e.state, 'rebuilt', e.why);
verifyEqual(testCase, e.name, 'evmktx_group1_seg.nbf_1');
verifyFalse(testCase, e.carried);
verifyEqual(testCase, e.channeltype, ex.channeltype);
verifyEqual(testCase, e.channel, ex.channel);
verifyEqual(testCase, e.T, ex.T);
verifyEqual(testCase, e.D, ex.D);
verifyEqual(testCase, R.t0, 5);
% ndi.compress.eventmarktext2vector: [type number code n] per channel
verifyEqual(testCase, e.data_description, [1 1 0 2; 2 1 2 3]);
verifyEqual(testCase, e.data, [6; 7; 5.1; 5.2; 5.3; ex.D{2}(:)]);
end

function testWithoutAReaderTheEventsAreNotRead(testCase)
% no reader: the documents say the channels, types and order; times and codes
% are 'not read', never empty values passed off as the content
[docs, bodies, ex] = secondPassEpoch(testCase);
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, docs);
verifyEqual(testCase, R.evmktx.state, 'not read');
verifyEqual(testCase, R.evmktx.channeltype, ex.channeltype);
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, ...
    struct('evmktx', struct('name', 'evmktx_group1_seg.nbf_1', 'channeltype', {ex.channeltype}, ...
    'channel', ex.channel, 'T', {ex.T}, 'D', {ex.D})));
verifyEqual(testCase, C.files(1).compared, 'not measured');
verifyEmpty(testCase, C.files(1).exact);
verifyFalse(testCase, C.exact, 'not measured is not exact');
end

function testTheComparisonIsExactOnlyWhenEveryFileIs(testCase)
[docs, bodies, ex] = secondPassEpoch(testCase);
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, docs, 'ReadBody', ...
    @(b) did2.convert.roundtrip.ingestedArchiveFiles('readFloat64', b));
orig = struct('member_names', {ex.names}, 'channel_list', ex.rows, ...
    'evmktx', struct('name', 'evmktx_group1_seg.nbf_1', 'channeltype', {ex.channeltype}, ...
    'channel', ex.channel, 'T', {ex.T}, 'D', {ex.D}));
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, orig);
verifyEqual(testCase, C.files_compared, 3, 'the denominator');
verifyTrue(testCase, C.exact, describeComparison(C));
verifyEqual(testCase, {C.files.compared}, {'names', 'rows', 'decoded content'});
% the encoded vector, when the caller read it from the file
o2 = orig;
o2.evmktx = struct('name', 'evmktx_group1_seg.nbf_1', 'data', R.evmktx.data, ...
    'data_description', R.evmktx.data_description);
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, o2);
verifyTrue(testCase, C.exact, describeComparison(C));
verifyEqual(testCase, C.files(3).compared, 'content');
% each difference is found (a check that cannot fail proves nothing)
bad = orig; bad.channel_list(5).time_channel = 3;           % a Spike2 event row
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, bad);
verifyFalse(testCase, C.exact);
verifySubstring(testCase, strjoin(C.files(2).differences, ' '), 'row 5 time_channel');
bad = orig; bad.evmktx.T{2}(1) = bad.evmktx.T{2}(1) + 1e-9;
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, bad);
verifyFalse(testCase, C.files(3).exact);
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, bad, 'TimeTolerance', 1e-6);
verifyTrue(testCase, C.files(3).exact, 'within the tolerance the caller gives');
bad = o2; bad.evmktx.data(end) = 99;
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, bad);
verifyFalse(testCase, C.files(3).exact);
bad = orig; bad.member_names{end+1} = 'ax_group1_seg.nbf_1';
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, bad);
verifyFalse(testCase, C.files(1).exact);
verifySubstring(testCase, strjoin(C.files(1).differences, ' '), 'ax_group1_seg.nbf_1');
end

function testTheChannelListIsComparedByItsBytes(testCase)
% the v1 file written by NDI's own writer function (vlt.file.saveStructArray,
% a DID-matlab requirement); the rebuilt rows written with it are the same
% bytes, and one changed name is not
assumeNotEmpty(testCase, which('vlt.file.saveStructArray'), ...
    'vhlab-toolbox-matlab is a DID-matlab requirement (requirements.txt)');
[docs, bodies, ex] = secondPassEpoch(testCase);
R = did2.convert.roundtrip.ingestedArchiveFiles(bodies, docs);
p = [tempname() '.bin'];
testCase.addTeardown(@() delete(p));
vlt.file.saveStructArray(p, ex.rows(:));
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, struct('channel_list', p));
verifyEqual(testCase, C.files(1).compared, 'bytes');
verifyTrue(testCase, C.files(1).exact, describeComparison(C));
rows = ex.rows; rows(2).name = 'ai2';
vlt.file.saveStructArray(p, rows(:));
C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, struct('channel_list', p));
verifyFalse(testCase, C.files(1).exact);
verifySubstring(testCase, strjoin(C.files(1).differences, ' '), 'row 2 name');
end

function testTodaysShapeCarriesTheChannelList(testCase)
% pass 1's shape (every series an opaque_body, channel_list.bin and the
% events file kept): names are the slot names, as before, and nothing is
% rebuilt that is still carried
b1 = opaqueBody('o1', 'own', 'channel_list.bin', 1);
b2 = opaqueBody('o2', 'own', 'ai_group1_seg.nbf_#', 2);
b3 = opaqueBody('o3', 'own', 'evmktx_group1_seg.nbf_#', 1);
R = did2.convert.roundtrip.ingestedArchiveFiles({b1, b2, b3}, {b1, b2, b3});
verifyEqual(testCase, R.shape, 'pass 1');
verifyEqual(testCase, R.channel_list_state, 'carried');
verifyEqual(testCase, {R.members.names}, {{'channel_list.bin'}, ...
    {'ai_group1_seg.nbf_1', 'ai_group1_seg.nbf_2'}, {'evmktx_group1_seg.nbf_1'}});
verifyEmpty(testCase, R.evmktx);
verifyEmpty(testCase, R.time_segments);
end

% =========================================================================
% fixtures
% =========================================================================

function [docs, bodies, ex] = secondPassEpoch(testCase)
% one ingested epoch after NDI's second pass, in the decided shape (see the
% header): an analog group (two channels, the second with a non-standard
% name) owned by the recording observation, a digital_out group owned by its
% own observation, an event and a marker channel unpacked; the epoch starts
% at 5 s on its clock
d = tempname();
mkdir(d);
testCase.addTeardown(@() rmdir(d, 's'));
sid = 'sess1';
T = @(node, name) struct('node', node, 'name', name);
loc = @(u) struct('uid', u, 'location', fullfile(d, u), 'location_type', 'file');
ep = doc('entity', 'ep1', sid, struct('entity', struct('type', T('', 'epoch'), ...
    'local_identifier', 't0001')), {});
ref = doc('relative_time_reference', 'ref1', sid, struct('relative_time_reference', ...
    struct('value', struct('clock', 'dev_local_time', 'start', struct('seconds', 5), ...
    'duration', struct('seconds', 100)))), {'referent_id', 'ep1'});
rec = doc('observation', 'obs_rec', sid, struct(), ...
    {'time_reference_id', 'ref1', 'acquisition_system_id', 'acq1'});
dig = doc('observation', 'obs_dig', sid, struct(), {'time_reference_id', 'ref1'});
ai = groupBody('b_ai', 'obs_rec', T('EMPTY:0000370', 'analog input channel'), [1 2], ...
    {'', 'myname'}, 'Offset', [32768 32768], 'Scale', [1.95e-7 1.95e-7], ...
    'SourceScale', [0.195 0.195], 'N', 1500, 'Chunk', 1000);
ai.files.file_info = struct('name', {'body_data_0', 'body_data_1'}, 'locations', {loc('a1'), loc('a2')});
di = groupBody('b_di', 'obs_dig', T('EMPTY:0000373', 'digital output channel'), 1, {}, ...
    'Filename', '', 'N', 1500, 'Chunk', 1e7);
% the marker channel: codes event x column, keyed to a time value
codes = [7 2; 8 3; 9 4];
mk = doc('observation', 'obs_mk1', sid, struct('observation', struct('conditions', ...
    struct('variable', T('EMPTY:0000377', 'marker channel'), 'count', 1))), ...
    {'time_reference_id', 'ref1'});
tv = doc('time', 'tv_mk1', sid, struct(), {});
mkb = doc('sampled_body', 'b_mk1', sid, struct('data', struct('dimensions', {{ ...
    struct('term', T('', 'event'), 'n', 3), struct('term', T('', 'column'), 'n', 2)}})), ...
    {'owner_id', 'obs_mk1', 'key_id', 'tv_mk1'});
mkb.files.file_info = struct('name', 'body_data_0', 'locations', loc('mk'));
writeFloat(fullfile(d, 'mk'), codes(:));
tvb = doc('sampled_body', 'b_tv_mk1', sid, struct('data', struct('dimensions', {{ ...
    struct('term', T('om:Time', 'time'), 'n', 3)}})), {'owner_id', 'tv_mk1'});
tvb.files.file_info = struct('name', 'body_data_0', 'locations', loc('mkt'));
writeFloat(fullfile(d, 'mkt'), [0.1; 0.2; 0.3]);
% the event channel: its own body holds the times
ev = doc('observation', 'obs_e1', sid, struct('observation', struct('conditions', ...
    struct('variable', T('EMPTY:0000376', 'event channel'), 'count', 1))), ...
    {'time_reference_id', 'ref1'});
evb = doc('sampled_body', 'b_e1', sid, struct('data', struct('dimensions', {{ ...
    struct('term', T('om:Time', 'time'), 'n', 2)}})), {'owner_id', 'obs_e1'});
evb.files.file_info = struct('name', 'body_data_0', 'locations', loc('e'));
writeFloat(fullfile(d, 'e'), [1; 2]);
docs = {ep, ref, rec, dig, ai, di, mk, tv, mkb, tvb, ev, evb};
bodies = {ai, di};
r = @(n, ty, tc, sr, o, s, num, g, dc) struct('name', n, 'type', ty, 'time_channel', tc, ...
    'sample_rate', sr, 'offset', o, 'scale', s, 'number', num, 'group', g, 'dataclass', dc);
% the rows as ndi.file.type.mfdaq_epoch_channel/create_properties orders them;
% no time row: it has no home (ndi.vintage.ingestedChannelList writes none)
ex.rows = [r('ai1', 'analog_in', 1, 30000, 32768, 0.195, 1, 1, 'ephys'), ...
    r('myname', 'analog_in', 1, 30000, 32768, 0.195, 2, 1, 'ephys'), ...
    r('do1', 'digital_out', 1, 30000, 0, 1, 1, 1, 'digital'), ...
    r('e1', 'event', NaN, NaN, 0, 1, 1, 1, 'eventmarktext'), ...
    r('mk1', 'marker', NaN, NaN, 0, 1, 1, 1, 'eventmarktext')];
ex.channeltype = {'event', 'marker'};
ex.channel = [1 1];
ex.T = {[6; 7], [5.1; 5.2; 5.3]};
ex.D = {ones(2, 1), codes};
ex.names = {'channel_list.bin', 'ai_group1_seg.nbf_1', 'ai_group1_seg.nbf_2', ...
    'ti_group1_seg.nbf_1', 'ti_group1_seg.nbf_2', 'di_group1_seg.nbf_1', ...
    'evmktx_group1_seg.nbf_1'};
end

function b = groupBody(id, owner, typeTerm, nums, names, varargin)
% a converted channel group, as NDI-matlab's second pass writes it (old
% numeric shape), with the decided time-channel covariate
p = inputParser;
p.addParameter('Filename', 'ai_group1_seg.nbf_#');
p.addParameter('Offset', zeros(size(nums)));
p.addParameter('Scale', ones(size(nums)));
p.addParameter('SourceScale', []);
p.addParameter('N', 10);
p.addParameter('Chunk', 10);
p.parse(varargin{:});
o = p.Results;
T = @(node, name) struct('node', node, 'name', name);
cov = @(v, f, x) setfield(struct('variable', v, 'along', 1), f, x); %#ok<SFLD>
scale = struct('value', o.Scale);
if ~isempty(o.SourceScale); scale.source_value = o.SourceScale; end
covs = {struct('variable', T('om:Time', 'time'), 'along', 0, 'origin', struct('value', 0), ...
        'spacing', struct('value', 1/30000)), ...
    cov(typeTerm, 'count', nums), ...
    cov(T('AFO:AFQ_0000202', 'signal offset configuration'), 'quantity', struct('value', o.Offset)), ...
    cov(T('NCIT:C70774', 'Unit Conversion Factor'), 'quantity', scale), ...
    cov(T('EMPTY:0000374', 'time channel'), 'quantity', struct('value', ones(size(nums))))};
if ~isempty(names)
    covs{end+1} = cov(T('NCIT:C25364', 'Identifier'), 'text', names);
end
db = struct('conditions', struct('variable', T('NCIT:C44170', 'Channel'), 'term', typeTerm));
if ~isempty(o.Filename); db.filename = o.Filename; end
b = doc('sampled_body', id, 'sess1', struct( ...
    'data', struct('dimensions', {{struct('term', T('om:Time', 'time'), 'n', o.N, 'chunk', o.Chunk), ...
        struct('term', T('NCIT:C44170', 'Channel'), 'n', numel(nums))}}, 'covariates', {covs}), ...
    'data_body', db), {'owner_id', owner});
b.files.file_info = struct('name', 'body_data_0', 'locations', struct('uid', [id '_u']));
end

function b = opaqueBody(id, owner, slot, n)
b = doc('opaque_body', id, 'sess1', struct('data_body', struct('filename', slot)), ...
    {'owner_id', owner});
b.files.file_info = struct('name', arrayfun(@(m) sprintf('body_data_%d', m), 0:n-1, ...
    'UniformOutput', false), 'locations', {struct('uid', 'u')});
end

function d = doc(cls, id, sid, blocks, edges)
d = blocks;
d.document_class = struct('class_name', cls);
d.base = struct('id', id, 'session_id', sid);
d.depends_on = struct('name', edges(1:2:end), 'value', edges(2:2:end));
end

function writeFloat(p, x)
fid = fopen(p, 'w', 'ieee-le');
fwrite(fid, x, 'float64');
fclose(fid);
end

function s = describeRows(rows)
s = strjoin(arrayfun(@(r) sprintf('%s/%s/%g/%g/%g/%g/%g/%g/%s', r.name, r.type, ...
    r.time_channel, r.sample_rate, r.offset, r.scale, r.number, r.group, r.dataclass), ...
    rows, 'UniformOutput', false), ' | ');
end

function s = describeComparison(C)
s = strjoin(arrayfun(@(f) sprintf('%s (%s): %s %s', f.name, f.compared, ...
    strjoin(f.differences, '; '), f.why), C.files, 'UniformOutput', false), ' || ');
end
