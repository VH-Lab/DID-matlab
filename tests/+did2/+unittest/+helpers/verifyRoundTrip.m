function verifyRoundTrip(testCase, r, label, expectedLost)
%VERIFYROUNDTRIP The round trip of one v1 document reports exactly the
%   expected lost paths, and nothing invented or unplaced.
%
%   did2.unittest.helpers.verifyRoundTrip(TESTCASE, R, LABEL, EXPECTEDLOST).
%   R is did2.convert.roundtrip.check's report; EXPECTEDLOST a cellstr of the
%   paths V2 is known not to keep for this fixture (a known finding each; {}
%   for none). The round trip must have inspected something (Operating Rule
%   5: a check that inspected nothing is not a pass).
%
%   See also did2.convert.roundtrip.check.

arguments
    testCase
    r (1,1) struct
    label (1,:) char
    expectedLost cell = {}
end

verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
lost = {};
if ~isempty(r.lost)
    lost = {r.lost.path};
end
verifyEqual(testCase, reshape(sort(lost), 1, []), reshape(sort(expectedLost), 1, []), ...
    sprintf('%s: lost paths are not the listed findings; lost: %s', label, describeLost(r)));
verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end

function s = describeLost(r)
parts = cell(1, numel(r.lost));
for k = 1:numel(r.lost)
    parts{k} = sprintf('%s (v1 %s, rebuilt %s)', r.lost(k).path, ...
        show(r.lost(k).v1), show(r.lost(k).rebuilt));
end
s = strjoin(parts, '; ');
if isempty(s); s = '(none)'; end
end

function s = show(v)
try
    s = jsonencode(v);
catch
    s = class(v);
end
end
