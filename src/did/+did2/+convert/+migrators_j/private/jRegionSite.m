function [partBodies, entityId] = jRegionSite(preBody, siteTerm)
%JREGIONSITE The region part a treatment's body site names, in its final shape.
%
%   [PARTBODIES, ENTITYID] = jRegionSite(PREBODY, SITETERM): when SITETERM is
%   a body site (a UBERON area: jTreatmentRoute 'dose') that is not a side,
%   and PREBODY names its subject, PARTBODIES is the region part
%   (did2.convert.regionPart: the tissue entity, its anatomical-structure
%   assertion and its `part_of` relation, each with an id computed from
%   (subject, region)) and ENTITYID the part's id, the entity the treatment's
%   manipulation is about. Otherwise both are empty and the caller writes the
%   site `observation` it wrote before (the scaffolding
%   did2.convert.resolveRegionParts and NDI's pathSPromotion read).
%
%   WHY. Decided by Jess Haley, 2026-10-26 [site scaffolding not a loss] (2)
%   (did-schema did_v2_go_forward_class_audit.md): "pass 1 writes the final
%   shape directly (manipulation, region part entity, its anatomical-structure
%   assertion, `part_of` relation, anchor), the part's id COMPUTED from the
%   subject id, region term and side so that every document naming one region
%   of one subject yields the same part ... a side stated in a separate v1
%   document still needs the batch pass." -- amended 2026-11-25 by [side said
%   about its region]: such a side is attached to no part. [region parts] (2026-10-21): a
%   statement about an anatomical region of a subject targets that region's
%   part entity. [region part ids computed] (2026-11-19) (3): the ids.
%
%   A SIDE IS NOT A REGION. A v1 treatment states one location; when it is a
%   laterality term (did2.convert.lateralityOf: a cerebral hemisphere, read
%   from its node), the document gives a side, not the region it is the side
%   of, so it stays the site observation about the subject ([side said
%   about its region], Jess Haley, 2026-11-25, amending [region part ids
%   computed] (2): a side attaches to a part only when one v1 document names
%   the region and its side together; did2.convert.resolveRegionParts counts
%   it and attaches it to no part).
%
%   The part's session and creation timestamp are the source's; copies minted
%   by several sources are merged to the earliest source's values by
%   resolveRegionParts ([region part ids computed] (1)).

partBodies = {};
entityId = '';
if ~isstruct(siteTerm) || isempty(siteTerm)
    return;
end
if ~strcmp(jTreatmentRoute(siteTerm(1)), 'dose')
    return;
end
[~, isSide] = did2.convert.lateralityOf(siteTerm(1));
if isSide
    return;
end
subject = jSubjectOf(preBody);
if isempty(subject)
    return;
end
[partBodies, ids] = did2.convert.regionPart(subject, siteTerm(1), [], ...
    'SessionId', jSid(preBody), 'CreationTimestamp', jStamp(preBody));
entityId = ids.part;
end
