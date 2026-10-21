function c = jOpts(preBody, varargin)
%JOPTS The did2.build options every migrated document shares.
%
%   C = jOpts(PREBODY, NAME, VALUE, ...) is the name-value cell
%
%       {'SessionId', <the v1 session id>, 'CreationTimestamp', <the v1
%        datestamp, or the sentinel>, 'Validate', false, NAME, VALUE, ...}
%
%   for a document a migrator builds from the v1 body PREBODY through did2.build.
%   Pass it as did2.build.statement(..., C{:}).
%
%   SESSION. The v1 `base.session_id` is the session id; on did-schema #88
%   (V_eta_relation_inheritance_plan.md, signed 2026-10-21) the migrated
%   session entity takes it as its own base.id, so the `session_id` edge the
%   builder writes from it resolves. did2.build writes the field or the edge,
%   whichever the loaded `base` declares.
%
%   VALIDATE is false: did2.convert.v1_to_v2 validates every emitted document
%   once, and quarantines the source on failure, so a migrator does not.
%   Builder checks that run before validation (an unknown field, a missing
%   required edge) still raise, and v1_to_v2 quarantines on them the same way.
%
%   TIMESTAMP. `base.datestamp` (or `creation_timestamp` on a body already
%   renamed) is kept; a v1 body with none takes the sentinel jBase states.
%
%   Trailing NAME, VALUE pairs are appended, so a caller may add 'Id', ...
%   (a later duplicate wins in an arguments block).

c = [{'SessionId', jSid(preBody), 'CreationTimestamp', jStamp(preBody), ...
    'Validate', false}, varargin];
end
