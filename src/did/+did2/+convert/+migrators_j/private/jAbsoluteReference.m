function ref = jAbsoluteReference(preBody, instant)
%JABSOLUTEREFERENCE Build a V_eta absolute_reference from a wall-clock instant.
%   REF = jAbsoluteReference(PREBODY, INSTANT) returns a sibling body a migrated
%   interaction can depend_on as its `time_reference_1`, or [] when INSTANT says
%   nothing -- NO TIMES => NO REFERENCE (V_eta_time_reference_model_plan.md: a
%   NaN/blank reference is a hollow document, the exact thing silentLoss and
%   isFragment exist to catch). The caller falls back to `jSessionAnchor` when
%   this returns [], because `subject_interaction` requires at least one
%   time_reference (min_count 1).
%
%   STATUS: NOT EXECUTED. Rewritten 2026-08-10 for #65 increment 2 in an
%   environment with no MATLAB, so nothing here has been run. The shape it emits
%   was read field-by-field off the rebuilt schema
%   (schemas/V_eta/stable/absolute_reference.json, class_version 2.0.0).
%
%   THE FIRST REAL EMITTER OF `absolute_reference`. The class was built
%   2026-08-06 with no writer -- "a wall-clock instant with no referent is
%   exactly what that class is for" -- and `subjectmeasurement.datestamp` is the
%   case it was built for.
%
%   ---------------------------------------------------------------------
%   WHAT GOES IN `value` -- THE SIGNED SHAPE, NOT THE INCREMENT-1 ONE
%   ---------------------------------------------------------------------
%   V_eta_time_reference_model_plan.md:468, TEAM-SIGN-OFF [time_reference],
%   jess@walthamdatascience.com / 2026-08-08, reshapes this class. The flat
%   `start_utc` / `end_utc` / `source_start` fields this function used to write
%   NO LONGER EXIST:
%
%       value.start              structure   the ANCHOR
%            .utc                timestamp     canonical instant
%            .source_value       char          the instant exactly as written
%            .source_timezone    char
%            .source_utc_offset  char
%            .approximate        boolean       is the ANCHOR imprecise
%       value.duration           duration    the EXTENT; ABSENT = an instant
%       value.source_end         char        only when the source wrote TWO instants
%
%   CHANGE 1 is why `end_utc` is gone: an anchor and an extent are independent
%   facts, and two instants make the exactness of their DIFFERENCE unrecoverable
%   ("started around 09:00, ran exactly 60 minutes"). `duration` is ABSENT here
%   because a measurement instant is a point -- which the schema says IS the
%   point-in-time case -- so this function never writes it.
%
%   `start.source_value` is ALWAYS set: lossless provenance, costs nothing.
%   `start.utc` is set only when the source string is recognisably ISO-8601 in
%   UTC (a trailing `Z`), which is what every in-tree writer produces:
%
%       build_intan_flat_exp.m:66  'subjectmeasurement.datestamp',
%                                  '2017-03-17T19:53:57.066Z'
%
%   Anything else -- a local time with a numeric offset, a bare date, a MATLAB
%   datenum -- is NOT normalised here. Converting an offset to UTC is arithmetic
%   this migrator can do, but converting an unlabelled local time is a guess, and
%   the two are not distinguishable without knowing which writer produced the
%   string. Recording the source string and leaving the canonical slot empty is
%   the honest state; `utc` is `mustBeNonEmpty: false`, so it validates.
%
%   ---------------------------------------------------------------------
%   NO `time_reference` BLOCK IS WRITTEN
%   ---------------------------------------------------------------------
%   CHANGE 2 deletes the value-level `approximate`, and the root's
%   `is_approximate` is DEPRECATED (it survives only until the six retiring
%   subclasses go, because emitters still write it). This document has nothing to
%   say in that block: the source gives a millisecond-resolution stamp, so there
%   is no `clock_tolerance` either. The block is therefore left OUT and
%   v1_to_v2's ensureClassBlocks pads it (`body.(cls) = struct()`,
%   +did2/+convert/v1_to_v2.m:471-475) -- the same door every other inherited
%   block goes through. `start.approximate` carries the one precision fact that
%   is real, and it is FALSE.
%
%   preBody   the post-universalRenames source body (supplies session + datestamp
%             for the minted document's own `base` block).
%   instant   the wall-clock instant as the source wrote it. Must be char/string;
%             a numeric value returns [] rather than being stringified, because a
%             bare number is not an instant this function can read.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

ref = [];

if isstring(instant) && isscalar(instant)
    instant = char(instant);
end
if ~ischar(instant) || isempty(strtrim(instant))
    return;
end
instant = strtrim(instant);

sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        % The minted document's OWN record-creation stamp, which is a different
        % fact from `instant` (the measurement time). The tombstone flags exactly
        % this: "SHADOWS base.datestamp -- a migrator must disambiguate."
        ds = preBody.base.datestamp;
    end
end

ref = struct();
ref.document_class = struct('class_name', 'absolute_reference', ...
    'class_version', '2.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '4.0.0'), ...
    'schema_version', 'V_eta');
ref.depends_on = struct('name', {}, 'value', {});
ref.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_measurement_time', 'datestamp', ds);

anchorCell = struct('source_value', instant, 'approximate', false);
utc = canonicalUTC(instant);
if ~isempty(utc)
    anchorCell.utc = utc;
end
% No `duration`: a measurement instant is a POINT, and an absent duration IS the
% point-in-time case. No `source_end`: the source wrote one instant, not two.
ref.absolute_reference = struct('value', struct('start', anchorCell));
end

% ===================== small helpers =======================================

function utc = canonicalUTC(s)
% Accept ISO-8601 that is ALREADY UTC (trailing Z), with either 'T' or a space
% as the date/time separator and optional fractional seconds. Nothing else is
% converted -- see the header.
utc = '';
tok = regexp(s, ...
    '^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2}(?:\.\d+)?)Z$', 'tokens', 'once');
if isempty(tok)
    return;
end
utc = [tok{1} 'T' tok{2} 'Z'];
end
