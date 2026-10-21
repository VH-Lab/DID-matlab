function anchor = jSessionAnchor(preBody, relation)
%JSESSIONANCHOR A "during the session" time reference for a statement built
%   from the v1 body PREBODY.
%
%   ANCHOR = jSessionAnchor(PREBODY, RELATION) is a relative_time_reference
%   whose referent is the session entity -- whose base.id IS the v1 session id
%   (did-schema V_eta_relation_inheritance_plan.md item 4, signed 2026-10-21:
%   "a migrated session entity takes the v1 session id as its base.id") -- and
%   whose `value.relation` is RELATION as an OWL-Time interval relation.
%   RELATION 'during' (every caller today) is `intervalDuring`; a name already
%   spelled `interval...` is passed through. No clock, start or duration: the
%   v1 document says only that it belongs to the session.
%
%   This replaces the pre-#73 `session_relative_reference` (`{is_approximate,
%   relation: 'during'}`), which no longer exists. The referent no longer has
%   to be found in the batch (resolveSessionAnchors' job on the old shape): the
%   session entity's id is known from the document itself.
%
%   A document with no session id cannot say which session it is in;
%   did2.build raises did2:build:missingField and v1_to_v2 quarantines it.

if nargin < 2 || isempty(relation)
    relation = 'during';
end
relation = char(relation);
if ~startsWith(relation, 'interval')
    relation = ['interval' upper(relation(1)) relation(2:end)];
end
sid = jSid(preBody);
if isempty(sid)
    error('did2:build:missingField', ...
        ['jSessionAnchor: the v1 body carries no session id, so no session ' ...
         'time reference can name the session it belongs to.']);
end
opts = jOpts(preBody);
anchor = did2.build.relativeTimeReference(sid, 'Relation', relation, opts{:});
anchor.base.name = 'migrated_session_anchor';   % lets a batch pass find the anchors it may remove
end
