function out = mergeRagged(elems, names)
%MERGERAGGED A cell of scalar structs as ONE struct array.
%
%   OUT = mergeRagged(ELEMS, NAMES) returns a 1xN struct array whose fields are
%   NAMES (the schema's declared order) restricted to the names at least one
%   element carries. An element that lacks a field gets [] there -- the absent
%   marker did2.schema.cache itself uses for a ragged JSON array
%   (cache.m, coerceStructArray / mergeStructCell), so the array round-trips.
%
%   An empty ELEMS gives a 0x0 struct with no fields.

if isempty(elems)
    out = struct([]);
    return;
end
used = false(1, numel(names));
for k = 1:numel(elems)
    used = used | isfield(elems{k}, names);
end
keep = names(used);
for k = 1:numel(elems)
    e = elems{k};
    for j = 1:numel(keep)
        if ~isfield(e, keep{j})
            e.(keep{j}) = [];
        end
    end
    if isempty(keep)
        elems{k} = struct();
    else
        elems{k} = orderfields(e, keep);
    end
end
out = [elems{:}];
end
