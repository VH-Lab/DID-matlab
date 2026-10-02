function doc = absoluteTimeReference(utc, options)
%ABSOLUTETIMEREFERENCE A wall-clock time: an instant or interval in UTC.
%
%   DOC = did2.build.absoluteTimeReference(UTC, ...) builds an
%   absolute_time_reference anchored at the ISO-8601 UTC instant UTC
%   ('2024-03-01T09:00:00.000Z'). 'Duration' makes it an interval; its absence
%   means an instant.
%
%   Options:
%     'SourceValue'      the start exactly as the source wrote it
%     'SourceTimezone'   the source's time zone (IANA name), when it gave one
%     'SourceUtcOffset'  the source's UTC offset ('+01:00'), when it gave one
%     'Approximate'      logical: the start is uncertain
%     'Tolerance'        [minus plus] seconds: the start's bound -- the true
%                        start lies in [start - minus, start + plus]; minus is
%                        EARLIER, plus LATER (CHANGE 7). Sets 'Approximate'
%                        true unless given or both are 0
%     'DurationTolerance', 'EndTolerance'   the same, for the duration / end
%     'Duration'         seconds, canonical ('DurationSourceValue',
%                        'DurationSourceUnit', 'DurationApproximate')
%     'End'              the END: an ISO-8601 UTC instant like the start
%                        ('EndSourceValue', 'EndSourceTimezone',
%                        'EndSourceUtcOffset', 'EndApproximate'). Its own
%                        fact with its own precision: an approximate start
%                        with an exact end is expressible. With 'Duration'
%                        too, the two must agree (rule end_consistent).
%     'SourceEnd'        the end exactly as the source wrote it (kept for
%                        callers: it fills `end.source_value`)
%     'ClockTolerance'   seconds: the stated precision of the timeline
%     'Fields', 'Edges', 'SessionId' (required), 'Id', 'CreationTimestamp',
%     'Validate', 'SchemaCache' -- as did2.build.document.
%
%   See also did2.build.relativeTimeReference.

arguments
    utc {mustBeTextScalar}
    options.SourceValue = ''
    options.SourceTimezone = ''
    options.SourceUtcOffset = ''
    options.Approximate = []
    options.Tolerance = []
    options.Duration = []
    options.DurationSourceValue = []
    options.DurationSourceUnit = ''
    options.DurationApproximate = []
    options.DurationTolerance = []
    options.End = ''
    options.EndSourceValue = ''
    options.EndSourceTimezone = ''
    options.EndSourceUtcOffset = ''
    options.EndApproximate = []
    options.EndTolerance = []
    options.SourceEnd = ''
    options.ClockTolerance = []
    options.Fields (1,1) struct = struct()
    options.Edges = struct()
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

utc = char(utc);
if isempty(regexp(utc, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?Z$', 'once'))
    error('did2:build:typeMismatch', ...
        'UTC must be an ISO-8601 UTC instant like 2024-03-01T09:00:00.000Z; got "%s".', utc);
end
start = struct('utc', utc);
if ~isempty(options.SourceValue);     start.source_value = options.SourceValue;           end
if ~isempty(options.SourceTimezone);  start.source_timezone = options.SourceTimezone;     end
if ~isempty(options.SourceUtcOffset); start.source_utc_offset = options.SourceUtcOffset;  end
[start, options.Approximate] = toleranceCell(start, options.Tolerance, options.Approximate, 'Tolerance');
if ~isempty(options.Approximate);     start.approximate = options.Approximate;            end
value = struct('start', start);
if ~isempty(options.Duration)
    d = struct('seconds', options.Duration);
    if ~isempty(options.DurationSourceUnit);  d.source_unit = options.DurationSourceUnit;   end
    if ~isempty(options.DurationSourceValue); d.source_value = options.DurationSourceValue; end
    [d, options.DurationApproximate] = toleranceCell(d, options.DurationTolerance, ...
        options.DurationApproximate, 'DurationTolerance');
    if ~isempty(options.DurationApproximate); d.approximate = options.DurationApproximate; end
    value.duration = d;
end
stop = struct();
if ~isempty(options.End)
    e = char(options.End);
    if isempty(regexp(e, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?Z$', 'once'))
        error('did2:build:typeMismatch', ...
            'End must be an ISO-8601 UTC instant like 2024-03-01T10:00:00.000Z; got "%s".', e);
    end
    stop.utc = e;
end
endSource = options.EndSourceValue;
if isempty(endSource); endSource = options.SourceEnd; end
if ~isempty(endSource);                  stop.source_value = endSource;                     end
if ~isempty(options.EndSourceTimezone);  stop.source_timezone = options.EndSourceTimezone;  end
if ~isempty(options.EndSourceUtcOffset); stop.source_utc_offset = options.EndSourceUtcOffset; end
if ~isempty(options.EndTolerance) && isempty(options.End)
    error('did2:build:ruleViolated', '''EndTolerance'' needs an ''End''.');
end
[stop, options.EndApproximate] = toleranceCell(stop, options.EndTolerance, options.EndApproximate, 'EndTolerance');
if ~isempty(options.EndApproximate);     stop.approximate = options.EndApproximate;         end
if ~isempty(fieldnames(stop)); value.end = stop; end
fields = struct('value', value);
if ~isempty(options.ClockTolerance)
    fields.clock_tolerance = struct('seconds', options.ClockTolerance);
end
options.Files = {};
doc = forward('absolute_time_reference', fields, struct(), options);
end
