function key = curieKey(curie, index)
%CURIEKEY The form in which two CURIEs are compared.
%
%   KEY = did2.schema.curieKey(CURIE) returns '<registry key>:<local id>' for
%   a CURIE, so that two CURIEs name the same thing exactly when their keys
%   are equal. DID-schema V_eta_prefix_spelling_plan.md, signed 2026-10-19:
%   "readers match a prefix by key, spelling or synonym, ignoring case". So
%
%     'PMID:123', 'pmid:123', 'pubmed:123'        -> 'pubmed:123'
%     'NCIT:C175887', 'ncit:C175887'              -> 'ncit:C175887'
%     'WBStrain:00004246' (old form)              -> 'wormbase:WBStrain00004246'
%     'WormBase:WBStrain00004246'                 -> 'wormbase:WBStrain00004246'
%     'cellosaurus:0030', 'RRID:CVCL_0030'        -> 'rrid:CVCL_0030'
%
%   The local id keeps its case: the rule is about prefixes.
%
%   A prefix the registry does not know is compared ignoring case, as
%   '<lowercase prefix>:<local id>'. Text that is not a CURIE is returned
%   trimmed and otherwise unchanged.
%
%   INDEX ([] = the shared schema cache's) is a did2.schema.curiePrefixIndex;
%   pass one in when calling this in a loop over another registry.
%
%   See also did2.schema.curieSpelling, did2.schema.curiePrefixIndex.

arguments
    curie {mustBeText}
    index = []   % a did2.schema.curiePrefixIndex, or [] for the shared cache's
end

if isempty(index)
    index = did2.schema.curiePrefixIndex();
end
s = strtrim(char(curie));
if isempty(s)
    key = s;
    return;
end
[k, local, ~, ok] = resolveCurie(s, index);
if ~ok
    key = s;
elseif isempty(k)
    p = regexp(s, '^[^:]*', 'match', 'once');
    key = [lower(p) ':' local];
else
    key = [k ':' local];
end
end
