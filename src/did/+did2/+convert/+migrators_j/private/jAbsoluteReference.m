function ref = jAbsoluteReference(preBody, instant)
%JABSOLUTEREFERENCE An absolute_time_reference for a wall-clock instant.
%
%   REF = jAbsoluteReference(PREBODY, INSTANT) is an `absolute_time_reference`
%   (did-schema #88; `absolute_reference` before #73) whose `value.start` is the
%   instant INSTANT, or [] when INSTANT says nothing -- NO TIMES => NO
%   REFERENCE. The caller falls back to jSessionAnchor on [].
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

ref = [];
if isstring(instant) && isscalar(instant)
    instant = char(instant);
end
if ~ischar(instant) || isempty(strtrim(instant))
    return;
end
instant = strtrim(instant);
opts = jOpts(preBody);
utc = canonicalUTC(instant);
if ~isempty(utc)
    ref = did2.build.absoluteTimeReference(utc, 'SourceValue', instant, ...
        'Approximate', false, opts{:});
else
    ref = did2.build.document('absolute_time_reference', ...
        struct('value', struct('start', struct('source_value', instant, ...
        'approximate', false))), opts{:});
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
