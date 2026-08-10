function docId = jSessionDocId(preBody)
%JSESSIONDOCID The `session` DOCUMENT id for a body -- '' in pass 1, always.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB.
%
%   DOCID = jSessionDocId(PREBODY) returns the `base.id` of the `session`
%   document that PREBODY belongs to, or '' when it cannot be known.
%
%   IT RETURNS '' FOR EVERY did_v1 DOCUMENT, BY CONSTRUCTION. That is the whole
%   point of the file, exactly as it is for its sibling jEpochDocId.
%
%   ---------------------------------------------------------------------
%   WHY `base.session_id` IS NOT THE ANSWER
%   ---------------------------------------------------------------------
%   An edge declared `must_refer_to_document_class: session` must name a
%   session DOCUMENT's `base.id`. `base.session_id` is a DIFFERENT STRING in a
%   DIFFERENT ID SPACE:
%
%       ndi.document.m:57    base.id         <- a FRESH ndi.ido()
%       ndi.session.m:215    base.session_id <- session.id(), set SEPARATELY
%
%   So a session document's own `base.id` is not its `base.session_id`, and an
%   edge filled from the latter names a value no document carries. It does not
%   fail loudly: `+did2/+validate/references.m` reports it as an ORPHAN, which
%   is a gating failure, but only once a corpus runs.
%
%   THIS IS NOT A HYPOTHETICAL. It shipped, and the corpus caught it:
%
%       corpus run 31438980133 (20211116, fd36421)
%         reference integrity: 1 orphan of 2814 edges
%             1  clock_alignment_policy.session_id
%
%   One syncgraph in that corpus, one orphan -- 100% of the class, which is the
%   signature this project has now seen on six separate edges.
%
%   ---------------------------------------------------------------------
%   WHY A MIGRATOR CANNOT ANSWER IT
%   ---------------------------------------------------------------------
%   Mapping `base.session_id` -> the session document's `base.id` is a lookup
%   over the WHOLE migrated body set: you must find the `session` document
%   carrying that `base.session_id` and read its `base.id`.
%   `did2.convert.v1_to_v2` is strictly per-document -- one
%   `for k = 1:numel(bodies)` loop with no batch hook -- so a migrator holds
%   exactly one document and cannot see the session.
%
%   `did2.convert.epochMint` already builds that index, for exactly this reason,
%   and its own header records the refusal:
%
%       "`epoch.session_id` points at the session DOCUMENT's `base.id`, which is
%        NOT the `base.session_id` its siblings carry ... The pass therefore
%        INDEXES the session documents rather than assuming the two strings are
%        equal."
%
%   Two files, one fact, opposite conclusions -- and the one that could not
%   check is the one that was wrong. This seam exists so the next caller cannot
%   make that mistake silently: it must ask, and the answer is '' until a batch
%   pass supplies it.
%
%   ---------------------------------------------------------------------
%   HOW IT STOPS RETURNING ''
%   ---------------------------------------------------------------------
%   The session index moves out of `epochMint` into something both passes share,
%   and the caller either runs in the batch phase or is handed the resolved id.
%   Until then a caller that needs this edge must PASS ITS DOCUMENT THROUGH
%   rather than emit an edge it cannot fill -- a passthrough is non-gating and
%   reversible, an orphan gates the corpus, and an EMPTY required edge is worse
%   than both because `references.m:90` skips it and nothing reports it at all.
%
%   Shared helper for the Brainstorm-J (+migrators_j) migrators.
arguments
    preBody (1,1) struct
end

% There is NO did_v1 field holding a session DOCUMENT id, so nothing is derived
% and nothing is guessed. The ONLY way this answers is if a batch pass has
% already STAMPED the resolved id onto the body as a `session_document_id`
% dependency -- which is precisely how jEpochDocId un-gates its own fold.
%
% Deliberately a DIFFERENT name from `session_id`: `base.session_id` and the
% edge `session_id` both already exist and mean the other thing. Reusing either
% would make a resolved id indistinguishable from the unresolved string that
% caused the orphan in the first place.
docId = '';
if ~isfield(preBody, 'depends_on') || ~isstruct(preBody.depends_on)
    return;
end
deps = preBody.depends_on;
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), 'session_document_id')
        continue;
    end
    % Read tolerantly, exactly as jEpochDocId does: a raw migrator body spells
    % the target `value`, a body through did2.convert.universalRenames spells it
    % `document_id`, and an unconverted v1 body spells it `id`.
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(d, f) && ~isempty(d.(f))
            docId = char(d.(f));
            return;
        end
    end
    return;
end
end
