function tf = sameMixture(a, b)
%SAMEMIXTURE True when two `mixture_table` texts state the same rows: the
%   same number of rows, in order, each with the same substance node (prefix
%   case aside, sameCurie) and name, the same number (compared as numbers,
%   so 1e-05 and 0.00001 agree) and the same unit node and name. The text's
%   layout -- header, quoting, number format, line ends -- is notation
%   ([spelling is notation], Jess Haley, 2026-10-26).
ra = mixtureRows(a);
rb = mixtureRows(b);
tf = numel(ra) == numel(rb);
for k = 1:numel(ra)
    if ~tf; return; end
    tf = sameNode(ra(k).node, rb(k).node) && strcmp(ra(k).name, rb(k).name) ...
        && sameNumber(ra(k).value, rb(k).value) ...
        && sameNode(ra(k).unode, rb(k).unode) && strcmp(ra(k).uname, rb(k).uname);
end
end

function tf = sameNode(a, b)
tf = (isempty(a) && isempty(b)) || sameCurie(a, b);
end

function tf = sameNumber(a, b)
if isempty(a) || isempty(b)
    tf = isempty(a) && isempty(b);
    return;
end
if isnan(a) || isnan(b)
    tf = isnan(a) && isnan(b);
    return;
end
tf = abs(a - b) <= 1e-12 * max(1, abs(a));
end
