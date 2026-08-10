function msg = batchPassFailure(result, reportField)
%BATCHPASSFAILURE The failure message a guarded batch post-pass left, '' if none.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB.
%
%   MSG = did2.unittest.helpers.batchPassFailure(RESULT, REPORTFIELD) returns
%   the `pass_failed` message that did2.unittest.helpers.runBatchPass recorded
%   on RESULT.(REPORTFIELD), or '' when the pass completed.
%
%   WHY THE HARD GATES CALL THIS INSTEAD OF LETTING THE PASS THROW. The guard
%   exists so the corpus REPORT survives a failure; it must not also let the
%   failure pass unnoticed. `testCorpusPRED` therefore writes its report FIRST
%   and asserts on this SECOND -- the artifact lands, and the gate still goes
%   red. A guard with no assertion downstream is a pass that quietly does
%   nothing, which is the defect this project keeps paying for.
%
%   THE ABSENT FIELD IS NOT A FAILURE HERE, deliberately. runBatchPass writes
%   the field on every path it takes, so an absent field means this RESULT never
%   went through the guard at all (a bare call, e.g. testFixtureCorpus) -- and a
%   bare call that failed already threw. Treating absence as failure would make
%   this function report on runs it did not observe, which is the
%   absence-as-evidence error Operating Rule 3 forbids.
%
%   See also: did2.unittest.helpers.runBatchPass.

arguments
    result (1,1) struct
    reportField (1,:) char
end

msg = '';
if ~isfield(result, reportField); return; end
rep = result.(reportField);
if ~isstruct(rep) || ~isscalar(rep); return; end
if ~isfield(rep, 'pass_failed'); return; end
v = rep.pass_failed;
if ischar(v) || isstring(v)
    msg = char(v);
end
end
