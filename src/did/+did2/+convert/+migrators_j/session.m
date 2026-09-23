function v2Body = session(preBody)
%SESSION Brainstorm-J migrator: `reference` -> `local_identifier`, and drop the
%   three V_zeta inventions. 1 -> 1, base.id PRESERVED.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THIS CLASS HAD NO MIGRATOR UNTIL NOW, and that was correct: `session`
%   migrated 1:1 with its id preserved and every field carried through, so a
%   passthrough said everything there was to say. The signed 2026-08-13 change
%   gives it two things to do.
%
%   TEAM-SIGN-OFF [session]: jess@walthamdatascience.com / 2026-08-13
%   (did-schema schemas/V_eta_go_forward_class_audit.md)
%     "session.type/.date/.purpose are DELETED (V_zeta inventions, no writer);
%      session.reference becomes local_identifier, required, matching subject
%      and epoch."
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main -- ONE FIELD, AND THAT IS THE POINT
%   ---------------------------------------------------------------------
%   git show origin/main:src/ndi/ndi_common/database_documents/session.json
%      "session": { "reference": "" }
%
%   No `type`, no `date`, no `purpose`. `ndi.session.dir` writes only
%   `session.reference` (via ndi.document('session','session.reference',...)).
%   The three came from DID-schema's own V_zeta snapshot, so no did_v1 document
%   can carry them -- the same shape as the invented `daqreader.file_extension`,
%   deleted this month for the same reason.
%
%   They are REMOVED HERE ANYWAY, not merely left unset. A V_zeta-vintage body
%   re-run through this pipeline could carry them, and after the schema change
%   they are undeclared -- which quarantines the document. Removing is cheap;
%   assuming they cannot appear is the reassuring direction.
%
%   ---------------------------------------------------------------------
%   `reference` -> `local_identifier`
%   ---------------------------------------------------------------------
%   Every other entity names this fact `local_identifier`: `subject` and `epoch`
%   both declare it REQUIRED. `session` was the only one using a different word
%   for the same thing while ALSO carrying a second, optional
%   `local_identifier`. One slot, one name.
%
%   THE VALUE IS CARRIED, NEVER INVENTED. `local_identifier` is mustBeNonEmpty
%   on the new schema, so a source with an empty `reference` would quarantine --
%   correctly. Nothing is substituted for a missing handle: a session with no
%   reference is a fact about the source, and manufacturing one would be the
%   hollow-document defect.
%
%   ---------------------------------------------------------------------
%   THE CROSS-REPO HALF -- THREE SITES, NOT ONE, AND ONE OF THEM MUST NOT MOVE
%   ---------------------------------------------------------------------
%   `session.reference` matches 23 lines of NDI, and 20 of them are reads of
%   the ndi.session OBJECT PROPERTY, which this rename does not touch. Only
%   three touch the DOCUMENT FIELD, and a query-shaped grep finds none of them
%   because all three go by path -- the daqsystem lesson:
%
%     $ grep -rn "document_properties\.session\.reference\|'session\.reference'" \
%           --include=*.m src/ tests/          # 1061 .m files scanned
%     src/ndi/+ndi/+session/dir.m:124   READ   -> now accepts either spelling
%     src/ndi/+ndi/+session/dir.m:138   WRITE  -> DELIBERATELY UNCHANGED
%     src/ndi/+ndi/+dataset/dir.m:69    READ   -> now accepts either spelling
%
%   THE WRITE STAYS did_v1, AND THAT IS THE POINT. It builds through
%   ndi.document('session','session.reference',...), which validates against
%   NDI's OWN template -- and that template still declares `reference`, on this
%   branch and on origin/main alike. NDI is not migrating its templates; it is
%   the did_v1 source of truth. Renaming the write would make NDI emit a
%   document its own schema rejects.
%
%   The two READS take a document straight out of a database that may be pre-
%   or post-migration, so each prefers `local_identifier` and falls back to
%   `reference`. A one-way rename there would have broken every unmigrated
%   database instead.
%
%   STATUS: NOT VERIFIED BY EXECUTION. There is no MATLAB in the authoring
%   environment, so not one line of this file has been run.

arguments
    preBody (1,1) struct
end

v2Body = preBody;

if ~isfield(v2Body, 'session') || ~isstruct(v2Body.session) ...
        || ~isscalar(v2Body.session)
    return;     % nothing to rewrite; the body passes through as it arrived
end

blk = v2Body.session;

% The rename. `reference` is copied then removed, so a body that somehow
% carries BOTH keeps the v1 one -- the source is the authority.
if isfield(blk, 'reference')
    blk.local_identifier = blk.reference;
    blk = rmfield(blk, 'reference');
end

% The three inventions.
for f = {'type', 'date', 'purpose'}
    if isfield(blk, f{1})
        blk = rmfield(blk, f{1});
    end
end

v2Body.session = blk;
end
