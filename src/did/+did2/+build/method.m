function doc = method(term, parameters, options)
%METHOD A standalone `method` document: a named, shared way of doing something.
%
%   DOC = did2.build.method(TERM, PARAMETERS, ...) builds a `method` document
%   (DID-schema V_eta_method_plan.md, did-schema #88, 2026-10-21): TERM is the
%   technique or stimulus kind (a term, a name, or [] when the source names
%   only the settings); PARAMETERS the settings (did2.build.parameter / list,
%   or []). It is the same {term, parameters} block a statement carries inline
%   as `method`, given an id of its own so many statements can point at it by
%   `method_id` (did2.build.statement 'MethodId') -- a spike sorter's
%   "default" settings, a protocol, or one stimulus given as a recipe ("drifting
%   sinusoidal grating" with its orientation, spatial and temporal frequency,
%   contrast). A statement carries the inline block OR the edge, never both.
%
%   Before #88 the class was `method_parameters` and carried only the list;
%   on that schema TERM must be empty (did2:build:unknownField otherwise).
%
%   Options:
%     'Name'        the protocol's name, e.g. 'default' (method.name)
%     'SoftwareId'  the software whose settings these are
%     'EntityId'    the entity they apply to
%     'EpochId'     the epoch they are scoped to
%     'ParentId'    the method this one was derived from (lineage)
%     'Fields', 'Edges', 'SessionId' (required), 'Id', 'CreationTimestamp',
%     'Validate', 'SchemaCache' -- as did2.build.document.
%
%   Example:
%     m = did2.build.method('drifting sinusoidal grating', did2.build.list( ...
%             did2.build.parameter('orientation', 'Value', 90, 'Unit', 'degree'), ...
%             did2.build.parameter('contrast', 'Value', 1)), 'SessionId', sid);
%     obs = did2.build.statement(..., 'MethodId', m.base.id, ...);
%
%   See also did2.build.parameter, did2.build.statement.

arguments
    term
    parameters
    options.Name = ''
    options.SoftwareId = ''
    options.EntityId = ''
    options.EpochId = ''
    options.ParentId = ''
    options.Fields (1,1) struct = struct()
    options.Edges = struct()
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

shape = methodShape(options.SchemaCache);
fields = struct();
if ~isAbsent(options.Name);  fields.name = options.Name;            end
if ~isAbsent(term);          fields.term = term;                    end
if ~isAbsent(parameters);    fields.(shape.listPath) = parameters;  end
[~, entityEdge] = vetaNames(options.SchemaCache);   % `subject_id` before 2026-10-08
edges = struct('software_id', options.SoftwareId, entityEdge, options.EntityId, ...
    'epoch_id', options.EpochId, 'parent_id', options.ParentId);
options.Files = {};
doc = forward(shape.docClass, fields, edges, options);
end
