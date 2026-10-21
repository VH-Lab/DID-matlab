function m = methodShape(cache)
%METHODSHAPE How the schema in use spells HOW something was done.
%
%   M = methodShape(CACHE) answers for a did2.schema.cache (or [] for the
%   shared one). DID-schema V_eta_method_plan.md (Jess Haley, 2026-10-21,
%   did-schema #88): an interaction's `method` term and its separate
%   `method_parameters` list became ONE block `method: {term, parameters}`,
%   the same block a relation and a clock_alignment_configuration carry and
%   the standalone class `method_parameters` became `method` (block {name,
%   term, parameters}); the edge `method_parameters_id` became `method_id`.
%
%   M is a struct:
%     block       true on the #88 shape: `method` is the {term, parameters}
%                 block; false before, when `method` was a bare term
%     docClass    the standalone class: 'method' / 'method_parameters'
%     listPath    the entry list's path on that class: 'parameters' /
%                 'method_parameters'
%     edge        the statement's edge to it: 'method_id' /
%                 'method_parameters_id'
%
%   The builders ask rather than assume, as vetaNames does, so one caller
%   builds valid documents on either schema until every repository has moved.

arguments
    cache % a did2.schema.cache, or [] for the shared one
end

cache = schemaCache(cache);
m = struct('block', false, 'docClass', 'method_parameters', ...
    'listPath', 'method_parameters', 'edge', 'method_parameters_id');
if ~cache.hasClass('method')
    return;
end
own = cache.ownFields('method');
names = cellfun(@(d) char(d.name), asDefs(own), 'UniformOutput', false);
if any(strcmp(names, 'parameters'))
    m = struct('block', true, 'docClass', 'method', ...
        'listPath', 'parameters', 'edge', 'method_id');
end
end
