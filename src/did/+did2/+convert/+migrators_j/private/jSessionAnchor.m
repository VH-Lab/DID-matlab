function anchor = jSessionAnchor(preBody, relation)
%JSESSIONANCHOR Build a V_eta session_relative_reference (ordinal, no metric)
%   anchored to the source document's session, returned as a sibling body so a
%   migrated interaction can depend_on it as its time_reference. v1 treatment /
%   location / label rows have no DAQ epoch, so 'during' the session is the
%   honest fallback. Session identity rides on base.session_id -- no redundant
%   session_id edge (it only produced discovery-mode orphans).
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
%
%   ---------------------------------------------------------------------
%   THIS EMITS A RETIRED CLASS ON PURPOSE. IT IS A PASS-1 HANDLE.
%   ---------------------------------------------------------------------
%   The signed model -- DID-schema/schemas/V_eta_time_reference_model_plan.md,
%   TEAM-SIGN-OFF [time_reference], jess@walthamdatascience.com / 2026-08-08 --
%   collapses eight reference classes to `absolute_reference` +
%   `relative_reference`, and `session_relative_reference` is one of the six
%   that go. A reader arriving from the status board sees this line minting a
%   retired class and reads it as work that was left behind. It is not: THE SAME
%   PLAN PUTS THE CHANGE OUT OF A MIGRATOR'S REACH, in its own words --
%
%       "A: `relative_to` is REQUIRED (team call)."          fork A
%       "A pass-1 migrator knows the epoch string ... but not the
%        acquisition_epoch document id, so it cannot populate
%        `relative_to`."                                     "Pass 1 vs pass 2"
%
%   and the built schema says it on the field itself (relative_reference.json,
%   depends_on relative_to, mustBeNonEmpty true): *"NOT fillable in pass 1: a
%   migrator holds `base.session_id`, and the edge needs the session DOCUMENT's
%   `base.id`, which is a different, freshly minted uid."* Verified in
%   NDI-matlab rather than assumed: `+ndi/document.m:57-58` mints base.id from a
%   fresh `ndi.ido()`, `+ndi/session.m:35` mints the session object's identifier
%   from a different one, and `+ndi/session.m:215` stamps that second uid on as
%   `base.session_id`. This function holds one of the two and cannot derive the
%   other -- the mapping is a batch-wide grouping, and a single-document migrator
%   sees one document.
%
%   Emitting `relative_reference` here with an EMPTY `relative_to` is not the
%   lesser evil it looks like. `+did2/+validate/references.m:90` SKIPS empty
%   edges, so ~106k husks would validate clean and no gate would ever see them --
%   the invented-empty-edge pattern an order of magnitude past its previous
%   record of 11,440.
%
%   So: this document is the HANDLE and `did2.convert.resolveSessionAnchors` is
%   the RESOLUTION. It rewrites the class and fills the edge in a batch pass with
%   `base.id` PRESERVED, so every `time_reference_#` edge pointing here keeps
%   resolving. The seam between the two -- which nothing checked, because the
%   fold's own fixtures are hand copies of this function and cannot drift when it
%   does -- is pinned by
%   tests/+did2/+unittest/testSessionAnchorEmitterContract.m.
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
