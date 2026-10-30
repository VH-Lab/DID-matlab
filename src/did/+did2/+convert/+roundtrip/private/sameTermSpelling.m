function tf = sameTermSpelling(a, b)
%SAMETERMSPELLING True when two texts are spellings of one registered term.
%
%   TF = sameTermSpelling(A, B). A is the v1 spelling, B the rebuilt one (a
%   registered term's name, or a label kept as the source spelled it). TF is
%   true when they are equal, or when B is the name of a row of the term
%   registry and A, trimmed and ignoring case, is that row's name or one of
%   its `synonyms`.
%
%   WHY. Decided by Jess Haley, 2026-10-26 [spelling is notation] (did-schema
%   V_eta_go_forward_class_audit.md): equivalent spellings of one registered
%   term ("Hz", "spikes/s" -> om:hertz) are the same thing in the round trip;
%   the spellings a migrator maps to a term are recorded in the term registry
%   as that term's `synonyms` (did-schema ccd05db), "read trimmed and ignoring
%   case". Everything else must come back exactly. The registry is the shared
%   schema cache's (did2.schema.cache.shared); with none, only equal texts
%   match.
tf = false;
if ~(ischar(a) || (isstring(a) && isscalar(a))) || ~(ischar(b) || (isstring(b) && isscalar(b)))
    return;
end
a = char(a);
b = char(b);
if strcmp(a, b)
    tf = true;
    return;
end
row = registryRow(b);
if isempty(row)
    return;
end
spellings = [{textOf(row, 'name')}, synonymsOf(row)];
tf = any(strcmp(lower(strtrim(a)), lower(strtrim(spellings))));
end

function row = registryRow(name)
% The term registry row whose name is NAME exactly ([] when none).
row = [];
try
    reg = did2.schema.cache.shared().termRegistry;
catch
    return;
end
if ~isstruct(reg) || ~isscalar(reg) || ~isfield(reg, 'terms')
    return;
end
terms = reg.terms;
if isstruct(terms)
    terms = num2cell(terms);
end
for k = 1:numel(terms)
    t = terms{k};
    if isstruct(t) && isscalar(t) && strcmp(textOf(t, 'name'), name)
        row = t;
        return;
    end
end
end

function c = synonymsOf(t)
c = {};
if ~isfield(t, 'synonyms') || isempty(t.synonyms)
    return;
end
v = t.synonyms;
if ischar(v) || isstring(v)
    c = cellstr(v);
elseif iscell(v)
    c = v(cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v));
    c = cellfun(@char, c, 'UniformOutput', false);
end
c = reshape(c, 1, []);
end

function v = textOf(s, f)
v = '';
if isfield(s, f) && ~isempty(s.(f)) && (ischar(s.(f)) || isstring(s.(f)))
    v = strtrim(char(s.(f)));
end
end
