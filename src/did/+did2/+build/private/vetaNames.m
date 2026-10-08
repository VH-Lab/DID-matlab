function [statementClass, entityEdge] = vetaNames(cache)
%VETANAMES The statement class and its edge as the schema in use spells them.
%
%   [STATEMENTCLASS, ENTITYEDGE] = vetaNames(CACHE) is {'statement',
%   'entity_id'} for a V_eta schema built on or after 2026-10-08, when the
%   statement family dropped its `subject_` prefix and the edge naming what a
%   statement is about became `entity_id` (did-schema V_eta_tenets.md, T2
%   amendment), and {'subject_statement', 'subject_id'} for one built before.
%   The builders ask rather than assume, so they build valid documents against
%   either until every repository has moved. CACHE: a did2.schema.cache, or
%   [] for the shared one.

cache = schemaCache(cache);
if cache.hasClass('statement')
    statementClass = 'statement';
    entityEdge = 'entity_id';
else
    statementClass = 'subject_statement';
    entityEdge = 'subject_id';
end
end
