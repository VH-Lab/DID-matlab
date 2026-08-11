function base = freshBase(preBody, name)
%FRESHBASE A newly-minted `base` block carrying PREBODY's session context.
%
%   BASE = did2.convert.entities.freshBase(PREBODY, NAME) mints a fresh
%   `base.id`, inherits `session_id` and `datestamp` from PREBODY when they are
%   present, and stamps NAME as the base.name sentinel.
%
%   The datestamp default ('2024-01-01T00:00:00.000Z') is the pipeline's
%   existing one; it fires only for a source body that carries no datestamp at
%   all.
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB -- see entityDoc's header. Moved
%   verbatim out of did2.convert.migrators_j.metadata_editor.
%
%   See also: did2.convert.entities.entityDoc, did2.convert.entities.relationDoc.

arguments
    preBody (1,1) struct
    name char
end

sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end
