%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 11: THE LEGACY did.unittest FILE-SERIES TESTS, AFTER THE MEMBER
%   BASE BECAME THE DOCUMENT'S VINTAGE (DID-schema #73 item 17, kept by Jess
%   2026-10-14: a V_eta document numbers series members from 0, a did_v1 one
%   from 1; did.document/seriesMemberBase).
%
%   WHY HERE. No workflow that runs on a claude/** push runs the did.unittest
%   package: test-migrators-quick and test-builder select did2.unittest, and
%   test-code runs only on main/V2. The change touches did.document,
%   did.database and did.implementations.sqlitedb, whose tests live in
%   tests/+did/+unittest/. This runs the four classes that exercise series.

import matlab.unittest.TestSuite;
import matlab.unittest.TestRunner;
classes = {'did.unittest.TestDocumentFileSeries', ...
           'did.unittest.TestFileSeriesRoundTrip', ...
           'did.unittest.TestSeriesMemberFetch', ...
           'did.unittest.TestCustomFileHandlerContext'};
suite = [];
for k = 1:numel(classes)
    suite = [suite, TestSuite.fromClass(meta.class.fromName(classes{k}))]; %#ok<AGROW>
end
results = TestRunner.withTextOutput.run(suite);
fprintf('\n==== PROBE 11 VERDICT ====\n');
fprintf('  tests run   %d\n', numel(results));
fprintf('  passed      %d\n', sum([results.Passed]));
fprintf('  FAILED      %d\n', sum([results.Failed]));
fprintf('  incomplete  %d\n', sum([results.Incomplete]));
failed = results([results.Failed]);
for k = 1:numel(failed)
    fprintf('    FAILED %s\n', failed(k).Name);
end
