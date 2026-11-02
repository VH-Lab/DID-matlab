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
    'NCIT:C52095', 'EMPTY:0000410'};
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

function testTheTenTypesAreRegisteredTerms(testCase)
% Every channel type the map writes is a registered term (did-schema term
% registry, T19): a probe's wiring relation names its channels by one
% condition per channel type, the variable that type's term (Jess Haley
% 2026-11-01 [probe wiring is a relation]; [channel types], [text channel
% replaces NCIT Text]). This replaces the comparison with
% `acquisition_channels.channels.type`'s bound list, a class that decision
% retires. The ten are distinct.
mine = {};
for p = {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx'}
    t = did2.convert.channelType(p{1});
    [tf, why] = did2.schema.termRegistered(t);
    verifyTrue(testCase, tf, sprintf('%s -> %s "%s": %s', p{1}, t.node, t.name, why));
    mine{end+1} = char(t.node); %#ok<AGROW>
end
verifyEqual(testCase, numel(unique(mine)), 10);
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
