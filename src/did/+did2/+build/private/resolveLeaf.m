function [className, kind] = resolveLeaf(cache, leafClass, kind)
%RESOLVELEAF The class and value kind a leaf name means in the schema in use.
%
%   [CLASSNAME, KIND] = resolveLeaf(CACHE, LEAFCLASS, KIND). A class the schema
%   has is itself (KIND as given, usually ''). A name it lacks of the form
%   <kind>_<direction> ('temperature_observation') is that direction with that
%   value kind, when the direction declares `value_kind` -- the 2026-10-08
%   composition (did-schema V_eta_entity_composition_plan.md sec. 1), which
%   removed the join leaves. So a caller written for either schema builds the
%   right document on both. Anything else is returned unchanged, for the
%   caller's own unknown-class error.

className = leafClass;
if ~isempty(kind) || cache.hasClass(leafClass)
    return;
end
directions = {'observation', 'assertion', 'manipulation', 'calculation'};
for d = 1:numel(directions)
    suffix = ['_' directions{d}];
    if endsWith(leafClass, suffix) && cache.hasClass(directions{d}) ...
            && ~isempty(cache.valueKindRule(directions{d}))
        candidate = leafClass(1:end - numel(suffix));
        if cache.hasClass(candidate)
            className = directions{d};
            kind = candidate;
            return;
        end
    end
end
end
