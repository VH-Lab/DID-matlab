function [term, kind] = channelType(prefix)
%CHANNELTYPE A v1 channel-type prefix as its acquisition channel type term.
%
%   [TERM, KIND] = did2.convert.channelType(PREFIX) maps the letters of a v1
%   channel ('ai' of 'ai27', 'mk' of 'mk1') to the term
%   acquisition_channels.channels.type is bound to (did-schema #88, Jess Haley
%   2026-10-22 [channel types], B2a "with 10"; "should be real terms"):
%
%       ai  EMPTY:0000370 analog input channel
%       ao  EMPTY:0000371 analog output channel
%       di  EMPTY:0000372 digital input channel
%       do  EMPTY:0000373 digital output channel
%       t   EMPTY:0000374 time channel
%       ax  EMPTY:0000375 auxiliary input channel
%       e   EMPTY:0000376 event channel
%       mk  EMPTY:0000377 marker channel
%       md  NCIT:C52095   Metadata
%       tx  EMPTY:0000410 text channel  ([text channel replaces NCIT Text],
%                         Jess Haley 2026-10-29; NCIT:C25704 Text until then)
%
%   The NAME is the term registry's label for the node (did2.convert.
%   registeredTerm), so a relabel in the registry needs no change here; code
%   compares channel types BY NODE ([vocabulary nodes] L2, S1: the prefix map
%   lives in the migrator, not in the registry). KIND is
%     'type'     PREFIX is one of the ten channel types; TERM is its term
%     'derived'  PREFIX is one of NDI's eight derived read modes (dep den dimp
%                dimn aep aen aimp aimn): a way of READING a channel, not a
%                channel type, so it gets NO term ([channel types]: "the 8
%                derived read modes are not channel types"); TERM is the bare
%                label {'' , PREFIX} and the caller counts it
%     'unknown'  anything else; TERM is the bare label {'', PREFIX}
%   Matching is case-insensitive on the prefix.
%
%   See also did2.convert.registeredTerm.

arguments
    prefix {mustBeText}
end

p = lower(strtrim(char(prefix)));
[prefixes, nodes] = prefixTable();
hit = find(strcmp(prefixes, p), 1);
if ~isempty(hit)
    term = did2.convert.registeredTerm(nodes{hit}, '');
    kind = 'type';
    return;
end
term = struct('node', '', 'name', char(prefix));
if any(strcmp(p, {'dep', 'den', 'dimp', 'dimn', 'aep', 'aen', 'aimp', 'aimn'}))
    kind = 'derived';
else
    kind = 'unknown';
end
end

function [prefixes, nodes] = prefixTable()
prefixes = {'ai', 'ao', 'di', 'do', 't', 'ax', 'e', 'mk', 'md', 'tx'};
nodes = {'EMPTY:0000370', 'EMPTY:0000371', 'EMPTY:0000372', 'EMPTY:0000373', ...
    'EMPTY:0000374', 'EMPTY:0000375', 'EMPTY:0000376', 'EMPTY:0000377', ...
    'NCIT:C52095', 'EMPTY:0000410'};
end
