classdef TestTimestamp < matlab.unittest.TestCase
    % TestTimestamp - unit tests for did.fun.timestamp
    %
    % did.fun.timestamp generates the datestamp stamped onto every DID
    % document. It must always produce a value that the schema validator
    % (java.time.LocalDateTime.parse in did.database) accepts. In particular
    % a UTCLeapSeconds datetime can render a ':60' leap second, which the
    % validator rejects; the helper must clamp that to ':59.999'. See
    % VH-Lab/DID-matlab issue #53.

    methods (Test)

        function testCurrentTimestampIsSchemaValid(testCase)
            % The generated current timestamp must parse via the same path
            % the schema validator uses.
            ts = did.fun.timestamp();
            testCase.verifyClass(ts, 'char');
            testCase.verifyParses(ts);
        end

        function testLeapSecondIsClamped(testCase)
            % A ':60.000' leap second is out of bounds for LocalDateTime and
            % must be clamped back to ':59.999'.
            raw = '2026-09-18T21:37:60.000Z';
            ts = did.fun.timestamp(raw);
            testCase.verifyEqual(ts, '2026-09-18T21:37:59.999Z');
            testCase.verifyParses(ts);
        end

        function testLeapSecondWithoutTrailingZIsClamped(testCase)
            raw = '2026-09-18T21:37:60.000';
            testCase.verifyEqual(did.fun.timestamp(raw), '2026-09-18T21:37:59.999');
        end

        function testNormalTimestampIsUnchanged(testCase)
            % A well-formed timestamp must pass through untouched.
            raw = '2026-09-18T21:37:45.123Z';
            testCase.verifyEqual(did.fun.timestamp(raw), raw);
            testCase.verifyParses(raw);
        end

    end

    methods

        function verifyParses(testCase, ts)
            % Mirror did.database/validate_field_type_and_value: strip a
            % trailing 'Z' and parse as a LocalDateTime. A throw here is the
            % same failure the validator would raise.
            value = regexprep(ts, 'Z$', '');
            try
                java.time.LocalDateTime.parse(java.lang.String(value));
            catch ME
                testCase.verifyFail(sprintf( ...
                    'Timestamp "%s" is not accepted by java.time.LocalDateTime.parse: %s', ...
                    ts, ME.message));
            end
        end

    end
end
