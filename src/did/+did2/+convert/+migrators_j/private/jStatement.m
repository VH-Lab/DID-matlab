function doc = jStatement(preBody, leafClass, entityId, variable, value, varargin)
%JSTATEMENT A statement document built from the v1 body PREBODY, through
%   did2.build.statement.
%
%   DOC = jStatement(PREBODY, LEAFCLASS, ENTITYID, VARIABLE, VALUE, NAME, VALUE, ...)
%   is did2.build.statement(LEAFCLASS, ENTITYID, VARIABLE, VALUE, jOpts(PREBODY){:},
%   NAME, VALUE, ...). LEAFCLASS is '<kind>_<direction>' ('voltage_observation',
%   'term_assertion') or a named calculator class; on did-schema #88 the builder
%   reads it as the direction class with that value kind as a mixin
%   (V_eta_entity_composition_plan.md sec. 1). VARIABLE is a term or a name.
%   ENTITYID is what the statement is about (its `entity_id` edge).
%
%   An interaction (observation, manipulation, calculation) needs at least one
%   time reference: pass 'TimeReferenceIds', {id, ...}.
%
%   See also jOpts, did2.build.statement.

opts = jOpts(preBody, varargin{:});
doc = did2.build.statement(leafClass, char(entityId), variable, value, opts{:});
end
