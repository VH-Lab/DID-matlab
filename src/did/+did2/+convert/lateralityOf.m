function [lat, isSide] = lateralityOf(term)
%LATERALITYOF Is a location term a SIDE (laterality), read from its node?
%
%   [LAT, ISSIDE] = did2.convert.lateralityOf(TERM), TERM a {node, name}
%   term. ISSIDE is true when TERM's node (case-folded) is in the table below;
%   LAT is then struct('side', 'left'|'right', 'structure', TF), STRUCTURE true
%   when the term also names a region (a cerebral hemisphere). A term not in
%   the table is an AREA, whatever its label says: laterality is read from the
%   term, never from its label.
%
%   THE TABLE IS NDI-matlab's ndi.migrate.internal.pathSPromotion
%   lateralityTable, restated here so DID-matlab's pass 1 and batch pass read
%   sides exactly as NDI's second pass does (Decided by Jess Haley, 2026-10-21
%   [laterality on the part], [one part per side], did-schema
%   did_v2_go_forward_class_audit.md). Each row is from the term's ontology
%   entry:
%     UBERON:0002812 left cerebral hemisphere  = cerebral hemisphere and
%         (BSPO:0000120 in_left_side_of some brain)
%     UBERON:0002813 right cerebral hemisphere = cerebral hemisphere and
%         (BSPO:0000121 in_right_side_of some brain)
%     NCIT:C32955 / C33472 Left / Right Cerebral Hemisphere
%     NCIT:C25229 / C25228 Left / Right (spatial qualifiers)
%   Widening the table is a vocabulary call, made in both repositories.
%
%   See also did2.convert.regionPart, did2.convert.resolveRegionParts.

lat = struct('side', '', 'structure', false);
isSide = false;
node = '';
if isstruct(term) && ~isempty(term) && isfield(term, 'node')
    node = lower(strtrim(char(term(1).node)));
end
if isempty(node)
    return;
end
T = table_();
if isKey(T, node)
    lat = T(node);
    isSide = true;
end
end

function T = table_()
persistent tab
if isempty(tab)
    tab = containers.Map('KeyType', 'char', 'ValueType', 'any');
    tab('uberon:0002812') = struct('side', 'left',  'structure', true);
    tab('uberon:0002813') = struct('side', 'right', 'structure', true);
    tab('ncit:c32955')    = struct('side', 'left',  'structure', true);
    tab('ncit:c33472')    = struct('side', 'right', 'structure', true);
    tab('ncit:c25229')    = struct('side', 'left',  'structure', false);
    tab('ncit:c25228')    = struct('side', 'right', 'structure', false);
end
T = tab;
end
