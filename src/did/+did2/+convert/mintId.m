function out = mintId(action, arg2)
%MINTID The id of a NEW document the migration mints, derived, not random.
%
%   Practice (b) of [migration reliability practices] (Jess Haley, 2026-10-26,
%   did-schema V_eta_go_forward_class_audit.md): deterministic ids for new
%   documents. A document the migration MINTS (a chemical, a formulation, an
%   anchor, a relation, a file uid, ...) takes an id derived from the v1
%   source it was minted for plus its ROLE, so two runs on the same input give
%   the same ids.
%
%   ID = did2.convert.mintId(ROLE)
%       a new id for a document of ROLE (a char: the class, or a short name of
%       what the document is) minted for the SOURCE of the innermost open
%       context (its key). The n-th id of one ROLE for one source in one
%       context is a pure function of (source, ROLE, n). With no context open,
%       or a context whose key is empty, there is no source. With no context
%       open (a caller outside a migration run: an NDI v2 writer calling
%       did2.build.document, a migrator called on its own) the id is
%       did.ido.unique_id() -- random, exactly as before. In a context opened
%       with an empty key, a call from the migration's own code is an error,
%       did2:convert:mintId:noSource (NO RANDOM ID INSIDE THE MIGRATION, below).
%   ID = did2.convert.mintId(ROLE, SOURCEID)
%       the same, for a named SOURCEID (the v1 or migrated document the new
%       one is minted for), counted in the innermost context; a batch pass
%       uses this form. Empty SOURCEID: the form above. With no context open
%       the ordinal is always 1, so a caller outside a context must give each
%       (SOURCEID, ROLE) once.
%   did2.convert.mintId('-push', KEY)
%       open a context: KEY is the source id ROLE-only calls mint for (v1_to_v2
%       opens one per source body, keyed on its v1 base.id), or '' for a
%       context that only scopes the ordinals (a batch pass, around its run).
%       Its counters start at 0. Contexts nest.
%   did2.convert.mintId('-pop')
%       close the innermost context.
%   N = did2.convert.mintId('-depth');  did2.convert.mintId('-popto', N)
%       how many contexts are open; close down to N (for an onCleanup).
%   did2.convert.mintId('-reset')
%       close every context (and clear '-simulateNoHash').
%   did2.convert.mintId('-simulateNoHash', TF)
%       TF true: behave as if no SHA-256 were available (for a test of
%       did2:convert:mintId:noHash).
%
%   THE FORMAT is did.ido's (did.ido.isvalid): 16 lowercase hex digits, '_',
%   16 lowercase hex digits. The second half is the first 16 hex digits of
%   SHA-256('<source>|<role>#<n>'). The first half is the source id's own first
%   half when it is a valid did.ido id (did.ido puts the creation time
%   there, so a minted document sorts beside its source), else the next 16 hex
%   digits of the same hash.
%
%   NO RANDOM ID INSIDE THE MIGRATION ([migration reliability practices] (b):
%   "two runs on the same input are identical"). The two ways this function
%   had to a random id are errors when the migration reaches them, so the
%   claim holds by construction rather than by a census:
%     did2:convert:mintId:noSource  a ROLE-only call in a context opened with
%         an empty key (a batch pass's run-wide context, or contentId's for a
%         body with no mint key) while a function of the did2.convert package
%         other than this one is on the call stack. A migration mint names its
%         source: mintId(ROLE, SOURCEID), a context keyed on it, or
%         did2.convert.contentId for a source that states no id (DID-matlab
%         #453, #457). v1_to_v2 opens a context keyed on every source body
%         (did2.convert.mintKey), and the batch passes that open none
%         (resolveClockAlignment, resolveDatasetEntities,
%         resolveResponseParameters, resolveSessionAnchors on V2 8a0d4708)
%         mint no document without an 'Id'.
%     did2:convert:mintId:noHash    no SHA-256 (no Java), so no id can be
%         derived. It was a random id and a warning.
%
%   NOT CHANGED: a document's id that the migration PRESERVES (the v1 id) is
%   not minted here. creation_timestamp is outside this practice.
%
%   See also did.ido.unique_id, did2.convert.v1_to_v2, did2.build.document,
%            did2.convert.contentId.

persistent stack noHash
if isempty(stack)
    stack = struct('key', {}, 'counts', {});
end
if isempty(noHash)
    noHash = false;
end
switch char(action)
    case '-push'
        stack(end+1) = struct('key', char(arg2), ...
            'counts', containers.Map('KeyType', 'char', 'ValueType', 'double'));
        out = numel(stack);
    case '-pop'
        if ~isempty(stack)
            stack(end) = [];
        end
        out = numel(stack);
    case '-popto'
        % close contexts down to depth ARG2 (an onCleanup's restore)
        n = max(0, double(arg2));
        if numel(stack) > n
            stack = stack(1:n);
        end
        out = numel(stack);
    case '-reset'
        stack = struct('key', {}, 'counts', {});
        noHash = false;
        out = 0;
    case '-simulateNoHash'
        noHash = logical(arg2);
        out = noHash;
    case '-depth'
        out = numel(stack);
    otherwise
        role = char(action);
        src = '';
        if nargin >= 2; src = char(arg2); end
        if isempty(src) && ~isempty(stack)
            src = stack(end).key;
        end
        if isempty(src)
            if ~isempty(stack) && calledFromTheMigration()
                error('did2:convert:mintId:noSource', ...
                    ['did2.convert.mintId("%s") was called by the migration with no ' ...
                     'source to derive the id from (no context, or a context opened ' ...
                     'with an empty key). A random id would make two runs on the same ' ...
                     'input differ: name the source (mintId(ROLE, SOURCEID), a context ' ...
                     'keyed on it, or did2.convert.contentId).'], role);
            end
            out = did.ido.unique_id();
            return;
        end
        counter = [src '|' role];
        n = 1;
        if ~isempty(stack)
            counts = stack(end).counts;   % a handle: updates in place
            if isKey(counts, counter)
                n = counts(counter) + 1;
            end
            counts(counter) = n; %#ok<NASGU>
        end
        out = derive(src, sprintf('%s#%d', role, n), noHash);
end
end

function tf = calledFromTheMigration()
% a function of the did2.convert package other than this one is on the call
% stack: the migration is minting
tf = false;
st = dbstack('-completenames');
for k = 1:numel(st)
    f = strrep(st(k).file, '\', '/');
    if contains(f, '/+did2/+convert/') && ~endsWith(f, '/+did2/+convert/mintId.m')
        tf = true;
        return;
    end
end
end

function id = derive(key, role, noHash)
h = '';
if ~noHash
    h = hashHex(sprintf('%s|%s', key, role));
end
if isempty(h)
    error('did2:convert:mintId:noHash', ...
        ['No SHA-256 (Java) is available, so the id minted for source "%s", ' ...
         'role "%s" cannot be derived; a random id would make two runs on the ' ...
         'same input differ.'], key, role);
end
if did.ido.isvalid(key)
    first = lower(key(1:16));
else
    first = h(17:32);
end
id = [first '_' h(1:16)];
end

function hex = hashHex(text)
%HASHHEX SHA-256 of TEXT (UTF-8) as 64 lowercase hex digits; '' when no JVM.
try
    md = java.security.MessageDigest.getInstance('SHA-256');
    bytes = md.digest(unicode2native(text, 'UTF-8'));
    hex = lower(reshape(dec2hex(typecast(bytes, 'uint8'), 2).', 1, []));
    hex = char(hex);
catch
    hex = '';
end
end
