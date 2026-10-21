function m = jMethod(term, parameters)
%JMETHOD An inline `method` block: {term, parameters} (did-schema #88,
%   V_eta_method_plan.md: one method shape inline and standalone; a bare term
%   before 2026-10-21). TERM is a term struct or a name (a label); PARAMETERS
%   is an entry list (did2.build.parameter / list) or [] for none. Pass it as
%   jStatement(..., 'Fields', struct('method', jMethod(...))).

if nargin < 2
    parameters = [];
end
m = struct();
if ~isempty(term)
    if ischar(term) || isstring(term)
        term = jLabel(char(term));
    end
    m.term = term;
end
if ~isempty(parameters)
    m.parameters = parameters;
end
end
