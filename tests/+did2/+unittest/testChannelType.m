function tests = testChannelType
%TESTCHANNELTYPE did2.convert.channelType: a v1 channel prefix -> its channel
%   type term (Jess Haley 2026-10-22 [channel types]), compared by node.
%
%   Run with:  results = runtests('did2.unittest.testChannelType');
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping channelType tests');
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

function testTheTenPrefixesAreTheTenTypes(testCase)
prefixes = {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx'};
nodes = {'EMPTY:0000370', 'EMPTY:0000371', 'EMPTY:0000372', 'EMPTY:0000373', ...
    'EMPTY:0000374', 'EMPTY:0000375', 'EMPTY:0000376', 'EMPTY:0000377', ...
    'NCIT:C52095', 'NCIT:C25704'};
for k = 1:numel(prefixes)
    [t, kind] = did2.convert.channelType(prefixes{k});
    verifyEqual(testCase, kind, 'type', prefixes{k});
    verifyEqual(testCase, t.node, nodes{k}, prefixes{k});
    verifyNotEmpty(testCase, t.name, prefixes{k});
end
% the name is the registry's label when the loaded registry holds the node
t = did2.convert.channelType('AI');
verifyEqual(testCase, t.node, 'EMPTY:0000370');
end

function testTheTenTypesAreTheSchemasBoundSet(testCase)
% the map covers exactly the nodes acquisition_channels.channels.type binds
c = did2.schema.cache.shared();
s = c.getClass('acquisition_channels');
f = s.fields;
if isstruct(f); f = num2cell(f); end
ch = f{cellfun(@(d) strcmp(char(d.name), 'channels'), f)};
sub = ch.fields;
if isstruct(sub); sub = num2cell(sub); end
ty = sub{cellfun(@(d) strcmp(char(d.name), 'type'), sub)};
if ~isfield(ty.constraints, 'binding') || ~isfield(ty.constraints.binding, 'values')
    assumeFail(testCase, 'the loaded schema binds no closed channel type list');
end
vals = ty.constraints.binding.values;
if isstruct(vals); vals = num2cell(vals); end
bound = sort(cellfun(@(v) char(v.node), vals, 'UniformOutput', false));
if any(cellfun(@isempty, bound))
    assumeFail(testCase, 'the loaded schema binds channel types by label (before did-schema 34a15e2)');
end
% [text channel replaces NCIT Text] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): did-schema binds EMPTY:0000410 "text
% channel" beside NCIT Text until the writers move (NDI's
% +vintage/channelTypes.m first, then this map), so it may be bound ahead of
% the map. Once the map writes it and NCIT Text leaves the list, this is the
% exact comparison again.
mine0 = did2.convert.channelType('tx');
if ~strcmp(char(mine0.node), 'EMPTY:0000410')
    bound = bound(~strcmp(bound, 'EMPTY:0000410'));
end
mine = cellfun(@(p) char(did2.convert.channelType(p).node), ...
    {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx'}, 'UniformOutput', false);
verifyEqual(testCase, sort(mine(:)), sort(bound(:)));
end

function testDerivedReadModesGetNoTerm(testCase)
for p = {'dep', 'den', 'dimp', 'dimn', 'aep', 'aen', 'aimp', 'aimn'}
    [t, kind] = did2.convert.channelType(p{1});
    verifyEqual(testCase, kind, 'derived', p{1});
    verifyEmpty(testCase, t.node, p{1});
    verifyEqual(testCase, t.name, p{1});
end
[t, kind] = did2.convert.channelType('zz');
verifyEqual(testCase, kind, 'unknown');
verifyEmpty(testCase, t.node);
end
