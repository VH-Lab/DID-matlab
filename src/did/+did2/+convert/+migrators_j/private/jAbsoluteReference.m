function ref = jAbsoluteReference(preBody, instant, stopText, duration)
%JABSOLUTEREFERENCE An absolute_time_reference for a wall-clock instant, or an
%   interval that starts at one.
%
%   REF = jAbsoluteReference(PREBODY, INSTANT) is an `absolute_time_reference`
%   (did-schema #88; `absolute_reference` before #73) whose `value.start` is the
%   instant INSTANT, or [] when INSTANT says nothing -- NO TIMES => NO
%   REFERENCE. The caller falls back to jSessionAnchor on [].
%
%   REF = jAbsoluteReference(PREBODY, INSTANT, STOPTEXT, DURATION) also writes
%   the interval's END and EXTENT, each a fact of its own (CHANGE 6, CHANGE 1):
%     STOPTEXT  the end as the source wrote it ('' for none) -> `value.end`,
%               read like the start (`source_value` always, `utc` only for a
%               UTC ISO-8601 string)
%     DURATION  [] for none, or a struct {seconds, source_value, source_unit}
%               -> `value.duration` (the caller converts its source unit)
%   [drug end and duration on the anchor] (Jess Haley, 2026-10-27, did-schema
%   V_eta_go_forward_class_audit.md): a v1 treatment_drug's
%   `administration_offset_time` and `administration_duration` are the `end`
%   and `duration` of its anchor (jTreatmentAnchor). The caller checks that
%   they agree with the start (jTreatmentAnchor); this function writes what it
%   is given. With no INSTANT nothing is written: an end or duration needs a
%   start (rule end_consistent).
%
%   `start.source_value` is always the string as written. `start.utc` is set
%   only when the string is ISO-8601 in UTC (a trailing Z); anything else (a
%   local time, a bare date) is not normalised -- converting an unlabelled
%   local time is a guess -- and `utc` is optional, so it validates. With a
%   UTC instant it is built by did2.build.absoluteTimeReference; without one
%   by did2.build.document, because that builder requires the UTC instant.
%
%   The pre-#73 header that stood here (the signed value shape, CHANGE 1) is
%   unchanged in substance: an instant has no `duration`.

if nargin < 3; stopText = ''; end
if nargin < 4; duration = []; end
ref = [];
if isstring(instant) && isscalar(instant)
    instant = char(instant);
end
if ~ischar(instant) || isempty(strtrim(instant))
    return;
end
instant = strtrim(instant);
if isstring(stopText) && isscalar(stopText)
    stopText = char(stopText);
end
if ~ischar(stopText)
    stopText = '';
end
stopText = strtrim(stopText);
opts = jOpts(preBody);
utc = canonicalUTC(instant);
stopUtc = '';
if ~isempty(stopText)
    stopUtc = canonicalUTC(stopText);
end
if ~isempty(utc)
    extra = {};
    if ~isempty(stopText)
        if ~isempty(stopUtc)
            extra = [extra, {'End', stopUtc}];
        end
        extra = [extra, {'EndSourceValue', stopText, 'EndApproximate', false}];
    end
    if ~isempty(duration)
        extra = [extra, {'Duration', duration.seconds, ...
            'DurationSourceValue', duration.source_value, ...
            'DurationSourceUnit', duration.source_unit}];
    end
    ref = did2.build.absoluteTimeReference(utc, 'SourceValue', instant, ...
        'Approximate', false, extra{:}, opts{:});
else
    value = struct('start', struct('source_value', instant, 'approximate', false));
    if ~isempty(duration)
        value.duration = struct('seconds', duration.seconds, ...
            'source_unit', duration.source_unit, ...
            'source_value', duration.source_value);
    end
    if ~isempty(stopText)
        stop = struct();
        if ~isempty(stopUtc)
            stop.utc = stopUtc;
        end
        stop.source_value = stopText;
        stop.approximate = false;
        value.end = stop;
    end
    ref = did2.build.document('absolute_time_reference', ...
        struct('value', value), opts{:});
end
end

function utc = canonicalUTC(s)
utc = '';
tok = regexp(s, ...
    '^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2}(?:\.\d+)?)Z$', 'tokens', 'once');
if isempty(tok)
    return;
end
utc = [tok{1} 'T' tok{2} 'Z'];
end
