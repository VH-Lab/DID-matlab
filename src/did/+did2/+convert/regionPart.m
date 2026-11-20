function [bodies, ids] = regionPart(parentId, areaTerm, sideTerm, options)
%REGIONPART The documents of one region part, with computed ids.
%
%   [BODIES, IDS] = did2.convert.regionPart(PARENTID, AREATERM, SIDETERM, ...)
%   builds the part of PARENTID (a subject) at the region AREATERM, on the
%   side SIDETERM ([] for none), in its final V_eta shape (Decided by Jess
%   Haley, 2026-10-21 [region parts], [laterality on the part], [one part per
%   side], did-schema did_v2_go_forward_class_audit.md):
%
%     1. an `entity` of type `tissue`, identity only (local_identifier);
%     2. its kind: an `assertion` of value kind `term`, variable
%        UBERON:0000061 "anatomical structure" ([anatomy variable terms]),
%        value AREATERM as the source wrote it;
%     3. with a side, its laterality: an `assertion` of value kind `term`,
%        variable NCIT:C25185 "Laterality", value SIDETERM;
%     4. a `directed_relation` part_of, child the part, parent PARENTID.
%
%   BODIES is a cell of the document structs in that order; IDS is
%   did2.convert.regionPartIds(PARENTID, AREATERM, SIDETERM): every id is
%   computed from (parent, region, side) ([region part ids computed] (3)), so
%   a part minted by two source documents is one id, and the copies are
%   merged by did2.convert.resolveRegionParts ([duplicate parts merged in
%   DID]). NDI-matlab's ndi.migrate.internal.pathSPromotion builds the same
%   four documents, with the same ids, for a part it makes itself.
%
%   Options: 'SessionId', 'CreationTimestamp' (the source's; [region part ids
%   computed] (1): the copies' values come from the earliest source, which
%   resolveRegionParts enforces), 'Validate' (default false: v1_to_v2
%   validates what a migrator emits).
%
%   See also did2.convert.regionPartIds, did2.convert.resolveRegionParts,
%            did2.convert.lateralityOf.

arguments
    parentId
    areaTerm
    sideTerm = []
    options.SessionId (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = false
end

ids = did2.convert.regionPartIds(parentId, areaTerm, sideTerm);
common = {'SessionId', options.SessionId, ...
    'CreationTimestamp', options.CreationTimestamp, 'Validate', options.Validate};

ent = did2.build.document('entity', ...
    struct('type', did2.build.term('', 'tissue'), ...
           'local_identifier', ids.local_identifier), ...
    'Id', ids.part, common{:});
kind = did2.build.statement('assertion', ids.part, ...
    did2.convert.registeredTerm('UBERON:0000061', 'anatomical structure'), ...
    asTerm(areaTerm), 'ValueKind', 'term', 'Id', ids.kind, common{:});
bodies = {ent, kind};
if ~isempty(ids.laterality)
    bodies{end+1} = did2.build.statement('assertion', ids.part, ...
        did2.convert.registeredTerm('NCIT:C25185', 'Laterality'), ...
        asTerm(sideTerm), 'ValueKind', 'term', 'Id', ids.laterality, common{:});
end
bodies{end+1} = did2.build.directedRelation(ids.part, char(parentId), 'part_of', ...
    'Id', ids.relation, common{:});
end

function t = asTerm(v)
t = struct('node', '', 'name', '');
if isstruct(v) && ~isempty(v)
    if isfield(v, 'node'); t.node = char(v(1).node); end
    if isfield(v, 'name'); t.name = char(v(1).name); end
end
end
