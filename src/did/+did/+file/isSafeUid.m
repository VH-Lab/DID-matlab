function tf = isSafeUid(uid)
% ISSAFEUID - Is uid safe to use as a filename under a cache or file root?
%
% TF = did.file.ISSAFEUID(UID)
%
% A uid stands in for a file basename under <root>/<uid>, so any value that
% would leave that directory once joined -- a path separator, a dot segment,
% a NUL, an empty or whitespace-padded string -- is refused.
% See DID-matlab issue #167.
%
% This is the implementation; did.implementations.sqlitedb.isSafeUid
% delegates here so that code outside the sqlitedb implementation -- notably
% did.file.cachedPathForUid -- can apply the same guard without depending on
% a database implementation.
%
% See also: did.file.cachedPathForUid

tf = false;
if isempty(uid), return, end
if isstring(uid) && isscalar(uid), uid = char(uid); end
if ~ischar(uid), return, end
uid = char(uid);
if isempty(uid), return, end
if ~isequal(strtrim(uid), uid), return, end
if any(strcmp(uid, {'.','..'})), return, end
if any(uid == '/') || any(uid == '\') || any(uid == 0), return, end
[~, name, ext] = fileparts(uid);
if ~isequal([name ext], uid), return, end
tf = true;
end
