function checkRetired(cache, className)
%CHECKRETIRED A new document must not be of a class the schema retires.
%
%   CHECKRETIRED(CACHE, CLASSNAME) raises did2:build:retiredClass when
%   strictMode('RetiredClasses') is on (the default) and the schema's
%   class_disposition_meta.json lists CLASSNAME as retired. The message names
%   the class, its replacement(s) where one is recorded, and the decision that
%   retired it.
%
%   Decided by Jess Haley, 2026-10-24 [V2 builder refuses retired] (did-schema
%   V_eta_go_forward_class_audit.md): "did2.build refuses to create a new
%   document of a class whose disposition is retire, naming its replacement
%   where one is recorded; reading v1 and the generic migration are not
%   affected."
%
%   Not checked:
%     - a schema with no class_disposition_meta.json (nothing is retired);
%     - while strictMode('RetiredClasses') is off, as did2.convert sets it for
%       the generic migration and its batch passes.

arguments
    cache (1,1) did2.schema.cache
    className (1,:) char
end

if ~did2.schema.cache.strictMode('RetiredClasses')
    return;
end
if isempty(fieldnames(cache.classDisposition))
    return;   % no class_disposition_meta.json: nothing is refused
end
ix = did2.schema.retiredIndex(cache.classDisposition);
if ~ix.present || ~isKey(ix.byName, className)
    return;
end
e = ix.byName(className);
if isempty(e.replaced_by)
    replacement = 'no replacement is recorded';
else
    replacement = ['use ' strjoin(e.replaced_by, ' or ') ' instead'];
end
if isempty(e.decision)
    decision = 'no decision is recorded';
else
    decision = ['decision: ' e.decision];
end
error('did2:build:retiredClass', ...
    ['Class "%s" is retired (its disposition is `retire`); did2.build does not ' ...
     'create new documents of it: %s (%s).'], className, replacement, decision);
end
