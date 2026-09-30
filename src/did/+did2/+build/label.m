function t = label(name)
%LABEL A term with a name and no node (item 33).
%
%   T = did2.build.label(NAME) is did2.build.term('', NAME): a knob, key or
%   condition variable that has no ontology term yet is still a term, carried
%   by name. NAME may be a cellstr / string array for several labels.
%
%   See also did2.build.term.

arguments
    name {mustBeText}
end

name = cellstr(name);
t = did2.build.term(repmat({''}, size(name)), name);
end
