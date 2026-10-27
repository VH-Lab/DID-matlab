function [base, entity] = rebuildBase(body)
%REBUILDBASE The v1 `base` block (id, session_id, datestamp) of an emitted
%   V2 document BODY, and its `entity` block (struct() when it has none).
%
%   id          base.id
%   session_id  base.session_id, or the `session_id` edge when `base` has no
%               such field (did2.schema.cache.sessionIdOf: the edge v1_to_v2
%               writes on the way out)
%   datestamp   base.creation_timestamp (v1_to_v2 renames datestamp on the
%               way out), else base.datestamp
%
%   `name` is NOT rebuilt here: V2 never writes base.name (#73 item 54), so
%   each inverse states what it can only have been (spec.equivalents).

base = struct('id', '', 'session_id', '', 'datestamp', '');
entity = struct();
if isfield(body, 'base') && isstruct(body.base) && isscalar(body.base)
    b = body.base;
    if isfield(b, 'id')
        base.id = char(b.id);
    end
    if isfield(b, 'creation_timestamp')
        base.datestamp = char(b.creation_timestamp);
    elseif isfield(b, 'datestamp')
        base.datestamp = char(b.datestamp);
    end
end
base.session_id = char(did2.schema.cache.sessionIdOf(body));
if isfield(body, 'entity') && isstruct(body.entity) && isscalar(body.entity)
    entity = body.entity;
end
end
