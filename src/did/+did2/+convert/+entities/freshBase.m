function base = freshBase(preBody, name)
%FRESHBASE A newly-minted `base` block carrying PREBODY's session context.
%
%   BASE = did2.convert.entities.freshBase(PREBODY, NAME) mints a fresh
%   `base.id`, inherits `session_id` and `datestamp` from PREBODY when they are
%   present, and stamps NAME as the base.name sentinel.
%
%   A source body that carries no datestamp gets the time the migration ran
%   (did2.convert.migrationTime; [no invented values], Jess Haley, 2026-10-25).
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB -- see entityDoc's header. Moved
%   verbatim out of did2.convert.migrators_j.metadata_editor.
%
%   See also: did2.convert.entities.entityDoc, did2.convert.entities.relationDoc.

arguments
    preBody (1,1) struct
    name char
end

sessionId = ''; ds = did2.convert.migrationTime();
if isfield(preBody, 'base') && isstruct(preBody.base)
    sessionId = did2.schema.cache.sessionIdOf(preBody);
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
srcId = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    srcId = char(preBody.base.id);
end
% derived from the source id and NAME (practice (b) of [migration reliability
% practices], Jess Haley, 2026-10-26); random when the source has no id
base = struct('id', did2.convert.mintId(name, srcId), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end
