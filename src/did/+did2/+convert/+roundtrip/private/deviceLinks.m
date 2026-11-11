function ids = deviceLinks(ctx, id)
%DEVICELINKS The ids of the documents of a batch index (batchContext) that
%   make the device ID an element by its links ('' cell when none, or when
%   CTX is empty).
%
%   The link test of NDI-matlab's reader (src/ndi/+ndi/+vintage/
%   linkedElements.m, probeLinks), Decided by Jess Haley, 2026-11-10
%   [element recognised by its links] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): a `device` entity is a
%   probe when
%     - an `observation` names it as its `instrument_id` (a recording), or
%     - a directed_relation `connected to` (RO:0002170, compared by node)
%       names it as its child (`child_id`, or the earlier `child`): its
%       wiring.
%   A device with neither is not an element: Decided by Jess Haley,
%   2026-11-11 [unlinked device is not an element].
%
%   See also did2.convert.roundtrip.element, did2.convert.roundtrip.wholeBatch.
ids = {};
for k = ctxReferrers(ctx, id)
    b = ctx.docs{k};
    switch classNameOf(b)
        case 'observation'
            if any(strcmp(edgeIds(b, 'instrument_id'), id))
                ids{end+1} = idOfDoc(b); %#ok<AGROW>
            end
        case 'directed_relation'
            [node, ~] = termParts(getIn(b, 'directed_relation', 'relation'));
            if sameCurie(node, 'RO:0002170') && ...
                    (any(strcmp(edgeIds(b, 'child_id'), id)) || any(strcmp(edgeIds(b, 'child'), id)))
                ids{end+1} = idOfDoc(b); %#ok<AGROW>
            end
    end
end
end

function id = idOfDoc(b)
id = '';
if isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id')
    id = char(b.base.id);
end
end
