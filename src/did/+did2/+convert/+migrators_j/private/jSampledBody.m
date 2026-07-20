function body = jSampledBody(statementId, sessionId, datestamp, name, datum, sampleTime)
%JSAMPLEDBODY Mint a V_eta sampled_body doc bound to a statement.
%   The shared body-doc skeleton for the Brainstorm-J body-backed folds
%   (image_stack, pyraview, spikewaves, binnedspikeratevm, spike_clusters): the
%   document_class header (sampled_body <- data_body, schema_version 'V_eta'),
%   the `statement` -> statementId edge (the observation that owns this body), a
%   fresh base (id minted here; session_id / datestamp as given), and the
%   sampled_body block -- the caller's `datum` + `sample_time` plus the empty
%   `summary` scaffold every body shares.
%
%   The caller attaches the carried bytes afterward (body.files / body.file):
%   pyraview slices them per resolution level, the others carry the whole set, so
%   file handling stays with the caller.
%
%   statementId  base.id of the owning observation (the `statement` referent).
%   sessionId    session_id for the minted body doc (the source doc's session).
%   datestamp    datestamp for the minted body doc.
%   name         base.name for the minted body doc.
%   datum        the sampled_body.datum struct (kind/dtype/unit/shape).
%   sampleTime   the sampled_body.sample_time struct (regular/t0/dt/n | n only).
%
%   Shared helper for the Brainstorm-J (+migrators_j) body-backed migrators.
body = struct();
body.document_class = struct('class_name', 'sampled_body', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'data_body', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', {'statement'}, 'value', {statementId});
body.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', datestamp);
body.sampled_body = struct('datum', datum, 'sample_time', sampleTime, ...
    'summary', struct('value', struct(), 'time', struct()));
end
