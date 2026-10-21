function fields = methodFields(fields, term, parameters, cache)
%METHODFIELDS Write a method term and its settings in the shape the schema uses.
%
%   FIELDS = methodFields(FIELDS, TERM, PARAMETERS, CACHE) adds HOW something
%   was done to the field struct a builder is assembling. TERM is a term (or a
%   name) for the technique; PARAMETERS the settings (did2.build.parameter /
%   list). Either may be [] for absent; when both are, FIELDS is unchanged.
%
%   On the #88 schema (methodShape: DID-schema V_eta_method_plan.md) both go
%   in ONE block, FIELDS.method = {term, parameters}; before it, TERM is
%   FIELDS.method and PARAMETERS is FIELDS.method_parameters.

arguments
    fields (1,1) struct
    term
    parameters
    cache % a did2.schema.cache, or [] for the shared one
end

hasTerm = ~isAbsent(term);
hasParams = ~isAbsent(parameters);
if ~hasTerm && ~hasParams
    return;
end
if methodShape(cache).block
    m = struct();
    if hasTerm; m.term = term; end
    if hasParams; m.parameters = parameters; end
    fields.method = m;
else
    if hasTerm; fields.method = term; end
    if hasParams; fields.method_parameters = parameters; end
end
end
