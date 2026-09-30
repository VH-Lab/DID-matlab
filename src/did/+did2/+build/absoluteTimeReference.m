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
%     'Duration'         seconds, canonical ('DurationSourceValue',
%                        'DurationSourceUnit', 'DurationApproximate')
%     'SourceEnd'        the END instant verbatim, when the source gave the
%                        interval as two instants (not a duration)
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
    options.Duration = []
    options.DurationSourceValue = []
    options.DurationSourceUnit = ''
    options.DurationApproximate = []
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
if ~isempty(options.Approximate);     start.approximate = options.Approximate;            end
value = struct('start', start);
if ~isempty(options.Duration)
    d = struct('seconds', options.Duration);
    if ~isempty(options.DurationSourceUnit);  d.source_unit = options.DurationSourceUnit;   end
    if ~isempty(options.DurationSourceValue); d.source_value = options.DurationSourceValue; end
    if ~isempty(options.DurationApproximate); d.approximate = options.DurationApproximate; end
    value.duration = d;
end
if ~isempty(options.SourceEnd); value.source_end = options.SourceEnd; end
fields = struct('value', value);
if ~isempty(options.ClockTolerance)
    fields.clock_tolerance = struct('seconds', options.ClockTolerance);
end
options.Files = {};
doc = forward('absolute_time_reference', fields, struct(), options);
end
