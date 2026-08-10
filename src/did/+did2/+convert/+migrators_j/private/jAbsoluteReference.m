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
%   THE FIRST REAL EMITTER OF `absolute_reference`. The class was built
%   2026-08-06 with no writer -- "a wall-clock instant with no referent is
%   exactly what that class is for" -- and `subjectmeasurement.datestamp` is the
%   case it was built for.
%
%   ---------------------------------------------------------------------
%   WHAT GOES IN `value`, AND WHY start_utc IS SOMETIMES ABSENT
%   ---------------------------------------------------------------------
%   From schemas/V_eta/stable/absolute_reference.json:
%
%       value.start_utc    timestamp   canonical UTC start instant
%       value.end_utc      timestamp   ABSENT means a point in time
%       value.source_start char        the instant exactly as the source wrote it
%       value.approximate  boolean
%
%   `source_start` is ALWAYS set -- it is lossless provenance and costs nothing.
%   `start_utc` is set only when the source string is recognisably ISO-8601 in
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
%   the honest state; `start_utc` is `mustBeNonEmpty: false`, so it validates.
%
%   `end_utc` is never set: a measurement instant is a point, and the schema says
%   an absent `end_utc` IS the point-in-time case.
%
%   `time_reference.is_approximate` is false: the source gives a millisecond-
%   resolution stamp. (Contrast `jSessionAnchor`, which sets it true because
%   "during the session" is all it knows.)
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
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
ref.depends_on = struct('name', {}, 'value', {});
ref.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_measurement_time', 'datestamp', ds);
ref.time_reference = struct('is_approximate', false);

value = struct('source_start', instant, 'approximate', false);
utc = canonicalUTC(instant);
if ~isempty(utc)
    value.start_utc = utc;
end
ref.absolute_reference = struct('value', value);
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
