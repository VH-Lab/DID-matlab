function blk = templateSpelling(blk, fields)
%TEMPLATESPELLING Give a rebuilt v1 block the field spelling of its NDI template.
%
%   BLK = templateSpelling(BLK, FIELDS). A method parameter's variable is a
%   term (jLabel), and did2.convert.registeredTerm writes a registered term
%   with the registry's label ([term labels stay as the ontology spells them],
%   Jess Haley, 2026-10-26): the bag entry for v1 `overlap` is named "Overlap".
%   The case of a label is notation ([spelling is notation]), so a rebuilt
%   field that matches one of FIELDS (the template's fields) only when case is
%   ignored is renamed to the template's spelling. Any other field is left as
%   it is (and reported by the round trip if v1 had no such field).
%
%   See also methodParameters.

fns = fieldnames(blk);
for k = 1:numel(fns)
    f = fns{k};
    if any(strcmp(f, fields))
        continue;
    end
    hit = find(strcmpi(f, fields), 1);
    if ~isempty(hit) && ~isfield(blk, fields{hit})
        blk.(fields{hit}) = blk.(f);
        blk = rmfield(blk, f);
    end
end
end
