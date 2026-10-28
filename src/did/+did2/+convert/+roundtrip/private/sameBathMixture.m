function tf = sameBathMixture(a, b)
%SAMEBATHMIXTURE True when two bath `mixture_table` texts state the same
%   mixture, a pH or osmolarity row compared by what it states and not where
%   it stood or which term id it named.
%
%   Decided by Jess Haley, 2026-10-27 [bath ph and osmolarity are formulation
%   fields] (did-schema V_eta_go_forward_class_audit.md): "a v1 bath mixture row
%   for pH or osmolarity becomes the bath formulation's `ph` or `osmolarity`
%   field; the row's term id and its position in the mixture table are not
%   kept, and the round trip counts them equal". So the ingredient rows (every
%   row but those named pH or osm / osmolarity) must agree in order, exactly as
%   sameMixture compares them; each pH / osmolarity row must have one partner
%   with the same name (case aside; osm and osmolarity are one name), number
%   and unit, its substance node and its position set aside.

ra = mixtureRows(a);
rb = mixtureRows(b);
[ia, pa] = splitRows(ra);
[ib, pb] = splitRows(rb);
tf = numel(ia) == numel(ib) && numel(pa) == numel(pb);
if ~tf
    return;
end
tf = sameMixture(rowsText(ia), rowsText(ib));
if ~tf
    return;
end
used = false(1, numel(pb));
for k = 1:numel(pa)
    hit = 0;
    for j = find(~used)
        if strcmp(propertyName(pa(k).name), propertyName(pb(j).name)) ...
                && sameNumber(pa(k).value, pb(j).value) ...
                && sameNode(pa(k).unode, pb(j).unode) && strcmp(pa(k).uname, pb(j).uname)
            hit = j;
            break;
        end
    end
    if hit == 0
        tf = false;
        return;
    end
    used(hit) = true;
end
end

function [ingredients, props] = splitRows(rows)
isProp = arrayfun(@(r) ~isempty(propertyName(r.name)), rows);
ingredients = rows(~isProp);
props = rows(isProp);
end

function n = propertyName(name)
switch lower(strtrim(char(name)))
    case 'ph',                n = 'ph';
    case {'osm', 'osmolarity'}, n = 'osmolarity';
    otherwise,                n = '';
end
end

function t = rowsText(rows)
% the rows back as a header-led CSV for sameMixture (mixtureRows reads it)
lines = {'ontologyName,name,value,ontologyUnit,unitName'};
for k = 1:numel(rows)
    v = '';
    if ~isempty(rows(k).value)
        v = num2str(rows(k).value, 17);
    end
    lines{end+1} = sprintf('%s,"%s",%s,%s,%s', rows(k).node, ...
        strrep(rows(k).name, '"', '""'), v, rows(k).unode, rows(k).uname); %#ok<AGROW>
end
t = strjoin(lines, newline);
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
