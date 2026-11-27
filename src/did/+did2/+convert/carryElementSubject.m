function carryElementSubject(elementId, subjectId, reason)
%CARRYELEMENTSUBJECT Hold a migrated element's v1 subject in the migration report's carried fields.
%
%   did2.convert.carryElementSubject(ELEMENTID, SUBJECTID, REASON) lists, in
%   the run's migration report (did2.convert.migrationReport 'carriedField'),
%   that the v1 `element` ELEMENTID, which converts, had `depends_on
%   subject_id` SUBJECTID, which no v2 document holds, because REASON. The
%   entry cites carry register row carry-172 (did-schema
%   schemas/registry/did_v2_carry_register.json: v1 `element`, field
%   `depends_on subject_id`, kind needs_mapping, scope field). Listed once per
%   element (the latest).
%
%   Decided by Jess Haley, 2026-11-19 (did-schema
%   docs/plans/did_v2_standing_wiring_plan.md):
%     [stimulator subject carried as needing information]  a migrated
%                          stimulator whose v1 `subject_id` no statement
%                          names gets no `observes`; its v1 subject is
%                          recorded as needing information, resolved by the
%                          dataset's import;
%     [one-field carry in the migration report]  it is held in the report's
%                          "carried fields" list {document_id, class, field,
%                          value, carry, reason}, citing a field-scoped carry
%                          register row (kind needs_mapping), written by
%                          NDI's second pass when no presentation, bath
%                          manipulation or Stimulator manipulation names the
%                          v1 subject; a DID-only run, with no second pass,
%                          keeps `observes` (superseded by [no observes
%                          relation in v2], 2026-11-26: no run writes one,
%                          and DID's round trip defers the subject);
%     [recording probe subject carried the same way]  a migrated recording
%                          probe with no recording observation, likewise.
%
%   The caller is NDI-matlab's second pass (`observesRetirement`), which
%   reads the element's v1 `subject_id` directly ([no observes relation in
%   v2], Jess Haley, 2026-11-26). DID-matlab's own pass 1 never calls this. The round trip reads
%   the entry back (did2.convert.carriedElementSubject; roundtrip.element,
%   roundtrip/private/manifestProbemap.m), so the v1 `subject_id` and
%   `direct` (true) are rebuilt and the probe map row keeps its subject.
%
%   ELEMENTID  the element's base.id (the v2 entity keeps the v1 id)
%   SUBJECTID  the v1 element's `depends_on subject_id` value, as v1 wrote it
%   REASON     why no v2 document holds it (e.g. 'no stimulus presentation,
%              bath manipulation or Stimulator manipulation names it')
%
%   See also did2.convert.carriedElementSubject, did2.convert.migrationReport.

arguments
    elementId (1,:) char {mustBeNonempty}
    subjectId (1,:) char {mustBeNonempty}
    reason (1,:) char {mustBeNonempty}
end

% carry-register: carry-172
did2.convert.migrationReport('carriedField', elementId, 'element', ...
    did2.convert.carriedElementSubject('field'), subjectId, '[carry-172]', reason);
end
