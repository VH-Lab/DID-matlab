function out = curieSpelling(curie, index)
%CURIESPELLING A CURIE written the way its issuer cites it.
%
%   OUT = did2.schema.curieSpelling(CURIE) rewrites CURIE's prefix to its
%   registry entry's `spelling` (DID-schema V_eta_prefix_spelling_plan.md,
%   signed 2026-10-19: "a CURIE's prefix is written as its issuer cites it").
%   A writer that is handed a CURIE in some other form calls this:
%
%     'pmid:123', 'pubmed:123'      -> 'PMID:123'
%     'ncit:C175887'                -> 'NCIT:C175887'
%     'WBStrain:00004246'           -> 'WormBase:WBStrain00004246'
%     'format:1929'                 -> 'EDAM:format_1929'
%     'cellosaurus:0030'            -> 'RRID:CVCL_0030'
%
%   A prefix the registry does not know, and text that is not a CURIE, come
%   back unchanged (trimmed): a writer must not invent a spelling.
%
%   INDEX ([] = the shared schema cache's) is a did2.schema.curiePrefixIndex.
%
%   See also did2.schema.curieKey, did2.schema.curiePrefixIndex.

arguments
    curie {mustBeText}
    index = []   % a did2.schema.curiePrefixIndex, or [] for the shared cache's
end

if isempty(index)
    index = did2.schema.curiePrefixIndex();
end
s = strtrim(char(curie));
if isempty(s)
    out = s;
    return;
end
[k, local, sp, ok] = resolveCurie(s, index);
if ~ok || isempty(k)
    out = s;
else
    out = [sp ':' local];
end
end
