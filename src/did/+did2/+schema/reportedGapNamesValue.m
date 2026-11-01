function tf = reportedGapNamesValue(s)
%REPORTEDGAPNAMESVALUE True when the migration report lists a document's
%   `value`, or a field within it, as a gap.
%
%   TF = did2.schema.reportedGapNamesValue(S) reads the field paths
%   did2.schema.reportedGaps returns for the document struct S and is true
%   when one names the value: 'value', '<block>.value',
%   '<block>.value.<field>...' or '<block>.value(k)...'.
%
%   [formulation amount needs info] (Decided by Jess Haley, 2026-10-31,
%   did-schema did_v2_go_forward_class_audit.md; docs/V2_PLAN.md G67 (a)): the
%   value rule (value_inline_or_body) accepts a blank value whose gap is
%   recorded -- a formulation in which no ingredient states an amount. Since
%   [migration record] and [gap accepted when the report lists it] (Jess
%   Haley, 2026-11-01) the gap is listed in the run's migration report, not in
%   the document. Read by did2.build (checkRules) and the validator
%   (did2.schema.cache).
%
%   See also did2.schema.reportedGaps, did2.convert.migrationReport.

tf = false;
named = did2.schema.reportedGaps(s);
for k = 1:numel(named)
    seg = strsplit(char(named{k}), '.');
    for i = 1:min(2, numel(seg))
        if strcmp(stripIndex(seg{i}), 'value')
            tf = true;
            return;
        end
    end
end
end

function s = stripIndex(seg)
% 'value(2)' -> 'value'; anything else unchanged
s = seg;
p = strfind(seg, '(');
if ~isempty(p) && endsWith(seg, ')')
    s = seg(1:p(1) - 1);
end
end
