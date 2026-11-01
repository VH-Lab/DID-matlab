function tf = needsInfoNamesValue(s)
%NEEDSINFONAMESVALUE True when a document's needs_info names its `value` or a
%   field within it.
%
%   TF = did2.schema.needsInfoNamesValue(S) reads the field paths
%   did2.schema.needsInfoFields returns for the document struct S (entries with
%   both a field and a reason) and is true when one names the value: 'value',
%   '<block>.value', '<block>.value.<field>...' or '<block>.value(k)...'.
%
%   [formulation amount needs info] (Decided by Jess Haley, 2026-10-31,
%   did-schema did_v2_go_forward_class_audit.md; docs/V2_PLAN.md G67 (a)): the
%   value rule (value_inline_or_body) accepts a blank value that needs_info
%   names -- a formulation in which no ingredient states an amount. Read by
%   did2.build (checkRules) and the validator (did2.schema.cache).
%
%   See also did2.schema.needsInfoFields.

tf = false;
named = did2.schema.needsInfoFields(s);
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
