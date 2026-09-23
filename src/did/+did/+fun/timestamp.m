function ts = timestamp(raw)
    % TIMESTAMP - a current UTC timestamp string that is safe for DID schema validation
    %
    % TS = did.fun.timestamp()
    %
    % Returns the current time as a char timestamp in the ISO-8601 form used
    % throughout DID: char(datetime('now','TimeZone','UTCLeapSeconds')).
    %
    % A UTCLeapSeconds datetime can occasionally render the seconds field as
    % '60' (a leap second), e.g. '2026-09-18T21:37:60.000Z'. The DID schema
    % validator parses timestamps with java.time.LocalDateTime.parse, which
    % rejects any seconds value greater than 59, so such a value would raise
    % DID:Database:ValidationFieldTimeStamp when the document is added. This
    % function clamps a leap second back to '59.999' so every generated
    % datestamp validates.
    %
    % TS = did.fun.timestamp(RAW) sanitizes the provided char timestamp RAW
    % instead of the current time. This is primarily useful for testing.
    %
    % See also: DATETIME, did.database/validate_field_type_and_value
    %
    % Note: this mirrors NDI's ndi.fun.timestamp guard and closes the
    % long-standing leap-second issue described in VH-Lab/DID-matlab issue #53.

    arguments
        raw (1,:) char = char(datetime('now','TimeZone','UTCLeapSeconds'))
    end

    % Clamp a leap-second seconds field (':60' with an optional fraction) to
    % ':59.999'. The leading capture group keeps the 'T HH:MM:' prefix so the
    % date portion is never touched, and any trailing 'Z' is preserved.
    ts = regexprep(raw, '(T\d{2}:\d{2}:)60(\.\d+)?', '$159.999');
end
