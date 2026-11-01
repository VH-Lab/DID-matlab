function doc = jEntity(preBody, type, fields, varargin)
%JENTITY An `entity` document of TYPE, built from the v1 body PREBODY.
%
%   DOC = jEntity(PREBODY, TYPE, FIELDS, NAME, VALUE, ...) builds the one
%   `entity` class of did-schema #88 (V_eta_entity_composition_plan.md sec. 4,
%   signed 2026-10-08): `type` is TYPE ('organism', 'device', 'cell',
%   'software', 'session', 'dataset', ...; the bound value set
%   entity_type_bindings names), FIELDS a struct of the identity fields
%   (`name`, `local_identifier`, `notes`, `global_identifier`), and the
%   trailing pairs go to did2.build.document ('Id' to preserve a source id,
%   'Edges' for `time_reference_id`). Empty fields are left out. What each type
%   requires (`local_identifier` for the physical types, session and epoch;
%   `name` for the rest) is the registry's, checked by validation.
%
%   Everything else an old entity class carried becomes an assertion or a
%   relation, written by the caller.

if nargin < 3 || isempty(fields)
    fields = struct();
end
ent = struct('type', did2.build.term('', char(type)));
for n = {'name', 'local_identifier', 'notes'}
    if isfield(fields, n{1}) && ~isempty(fields.(n{1}))
        ent.(n{1}) = char(fields.(n{1}));
    end
end
if isfield(fields, 'global_identifier') && ~isempty(fields.global_identifier)
    g = fields.global_identifier;
    if ischar(g) || isstring(g)
        g = cellstr(g);
    end
    g = g(~cellfun(@isempty, g));
    if ~isempty(g)
        ent.global_identifier = g;
    end
end
opts = jOpts(preBody, varargin{:});
doc = did2.build.document('entity', ent, opts{:});
end
