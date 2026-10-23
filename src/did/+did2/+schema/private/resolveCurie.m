function [key, local, spelling, ok] = resolveCurie(s, index)
%RESOLVECURIE Split a CURIE and find its registry entry.
%
%   [KEY, LOCAL, SPELLING, OK] = resolveCurie(S, INDEX). OK is false when S
%   is not a CURIE (no `prefix:` in front). Otherwise KEY is the registry key
%   the prefix names ('' when the registry does not know it), LOCAL is the
%   local id as the entry writes it, and SPELLING is the prefix as a document
%   writes it.
%
%   The prefix is matched against the entry's key, `spelling` and
%   `synonyms`, ignoring case. An old prefix that splits the identifier
%   differently (`legacy_rewrite`: `WBStrain:00004246`) and an entry cited
%   through another one (`written_as`: `cellosaurus:0030`) move part of the
%   meaning into the local id, so both are applied here and nowhere else.
%   DID-schema V_eta_prefix_spelling_plan.md, signed 2026-10-19.

arguments
    s char   % one CURIE, trimmed
    index struct   % a did2.schema.curiePrefixIndex
end

key = ''; local = ''; spelling = '';
tok = regexp(s, '^([A-Za-z][A-Za-z0-9_.\-]*):(.*)$', 'tokens', 'once');
ok = ~isempty(tok);
if ~ok
    return;
end
p = tok{1};
local = tok{2};
spelling = p;
lp = lower(p);
if isKey(index.legacy, lp)
    rw = index.legacy(lp);
    key = rw{1};
    local = [rw{2} local];
elseif isKey(index.names, lp)
    key = index.names(lp);
else
    lv = lower(matlab.lang.makeValidName(p));
    if isKey(index.names, lv)
        key = index.names(lv);
    end
end
if isempty(key)
    return;
end
if isKey(index.writtenAs, key)
    wa = index.writtenAs(key);
    if ~startsWith(local, wa{2})
        local = [wa{2} local];
    end
    key = wa{1};
end
if isKey(index.spelling, key)
    spelling = index.spelling(key);
end
end
