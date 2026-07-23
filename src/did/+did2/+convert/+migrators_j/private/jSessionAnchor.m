function anchor = jSessionAnchor(preBody, relation)
%JSESSIONANCHOR Build a V_eta session_relative_reference (ordinal, no metric)
%   anchored to the source document's session, returned as a sibling body so a
%   migrated interaction can depend_on it as its time_reference. v1 treatment /
%   location / label rows have no DAQ epoch, so 'during' the session is the
%   honest fallback. Session identity rides on base.session_id -- no redundant
%   session_id edge (it only produced discovery-mode orphans).
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
anchor = struct();
anchor.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
end
