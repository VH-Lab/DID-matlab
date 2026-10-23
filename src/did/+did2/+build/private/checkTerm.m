function checkTerm(def, t, path)
%CHECKTERM A term written into a vocabulary slot must be in the term registry.
%
%   CHECKTERM(DEF, T, PATH): T is the {node, name} term fillField has just
%   filled for the field DEF at PATH. Tenet T19 (DID-schema
%   V_eta_term_registry_plan.md): a term already used in an NDI dataset
%   first, then an existing ontology, then a new EMPTY term, and every term
%   is registered before it is used. With strictMode('TermRegistry') on (the
%   default) an unregistered term is an error, did2:build:unregisteredTerm;
%   with did2.build.unregisteredTerms collecting, it is recorded.
%
%   Not checked:
%     - a schema with no term registry (did-schema main);
%     - a field whose binding lists its own values (entity.type, a
%       relation, a clock): that list already governs it;
%     - a model fit's coefficient names (model_fit ... coefficients.variable):
%       a coefficient is named by its symbol in the model's equation ('a',
%       'b'), which tells the fit's own coefficients apart; its node still
%       says what kind of coefficient it is.
%
%   A statement's own value term (term.value, a chemical's substance) IS
%   checked, like a variable (Jess Haley, 2026-10-20: value terms are
%   registered too; DID-schema V_eta_term_registry_plan.md, open item 1). A term with no node is checked the same way
%   for every slot: it passes only when its name is registered as a STAGED
%   term (no node); see did2.schema.termRegistered.

arguments
    def struct
    t struct
    path (1,:) char
end

armed = did2.schema.cache.strictMode('TermRegistry');
collecting = did2.build.unregisteredTerms('-collecting');
if ~armed && ~collecting
    return;
end
if hasValueSet(def) ...
        || ~isempty(regexp(path, '\.coefficients(\(\d+\))?\.variable$', 'once'))
    return;
end
ix = did2.schema.termIndex();
if ~ix.present
    return;
end
t = struct('node', textOf(t, 'node'), 'name', textOf(t, 'name'));
[tf, reason] = did2.schema.termRegistered(t, ix);
if tf
    return;
end
if collecting
    did2.build.unregisteredTerms('-add', t, path, reason);
end
if armed
    error('did2:build:unregisteredTerm', ...
        ['"%s": %s. Register it in DID-schema''s term registry first ' ...
         '(tenet T19: reuse a term already used in NDI, else an ontology ' ...
         'term, else mint one in EMPTY).'], path, reason);
end
end

function tf = hasValueSet(def)
arguments
    def struct
end
tf = isfield(def, 'constraints') && isstruct(def.constraints) ...
    && isfield(def.constraints, 'binding') && isstruct(def.constraints.binding) ...
    && isfield(def.constraints.binding, 'values') && ~isempty(def.constraints.binding.values);
end

function v = textOf(s, f)
arguments
    s struct
    f {mustBeText}
end

v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = strtrim(char(s.(f)));
end
end
