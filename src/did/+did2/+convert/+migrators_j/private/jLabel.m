function t = jLabel(name)
%JLABEL A term known by NAME: the registered term when the schema's term
%   registry holds NAME (ignoring case), else {node '', name NAME} (tenet T19;
%   did2.convert.registeredTerm). NAME may be a cellstr: a 1xN term array.

if iscell(name) || (isstring(name) && ~isscalar(name))
    name = cellstr(name);
    c = cellfun(@(n) did2.convert.registeredTerm('', n), name, 'UniformOutput', false);
    t = [c{:}];
    return;
end
t = did2.convert.registeredTerm('', char(name));
end
