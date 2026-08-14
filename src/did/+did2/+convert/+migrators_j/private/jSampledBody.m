function body = jSampledBody(statementId, sessionId, datestamp, name, sampleTime)
%JSAMPLEDBODY Mint a V_eta sampled_body doc bound to a statement.
%   The shared body-doc skeleton for the Brainstorm-J body-backed folds
%   (image_stack, pyraview, spikewaves, binnedspikeratevm, spike_clusters): the
%   document_class header (sampled_body <- data_body, schema_version 'V_eta'),
%   the `statement` -> statementId edge (the observation that owns this body), a
%   fresh base (id minted here; session_id / datestamp as given), and the
%   sampled_body block -- which is now the caller's `sample_time` and nothing
%   else. `datum` and `summary` were both removed 2026-08-14; see below.
%
%   The caller attaches the carried bytes afterward (body.files / body.file):
%   pyraview slices them per resolution level, the others carry the whole set, so
%   file handling stays with the caller.
%
%   statementId  base.id of the owning observation (the `statement` referent).
%   sessionId    session_id for the minted body doc (the source doc's session).
%   datestamp    datestamp for the minted body doc.
%   name         base.name for the minted body doc.
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
% `summary` IS NO LONGER EMITTED (#68, signed sec.9: "summary is DROPPED, not
% deferred in place"). What this used to write was
% `struct('value', struct(), 'time', struct())` -- an empty shell on EVERY body
% this helper has ever produced, with no writer ever filling either half and no
% reader ever consulting one. An always-empty required-looking block is the
% vacuous-composite shape #38 exists to catch, and it was being minted by the
% shared helper, so every body-backed migrator carried it.
%
% REMOVED BEFORE THE SCHEMA DROPS THE FIELD, deliberately, and that order is
% transient-free where the hoist's was not: `summary` is OPTIONAL, so a body
% that omits it validates against the OLD schema as happily as the new one.
% Additions and moves have to go schema-first; removals go writer-first.
% `datum` IS GONE FROM THE BODY (signed sec.5). Its `dtype` is now
% `subject_statement.datum_type` -- the statement says what the values ARE, the
% body says how the bytes lay out -- and `unit` / `shape` / `kind` were dropped:
% unit was EMPTY at 4 of 4 writers, shape was read two different ways by its own
% writers, and kind (scalar vs array) is the axis COUNT restated.
%
% THE ARGUMENT WENT WITH IT rather than being accepted and ignored. A helper
% that takes a value it does not use is how a caller comes to believe it has
% recorded something; all four callers now set `datum_type` on their own
% statement, where it belongs.
body.sampled_body = struct('sample_time', sampleTime);
end
