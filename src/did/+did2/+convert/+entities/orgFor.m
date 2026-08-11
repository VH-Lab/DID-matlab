function [orgId, orgBody] = orgFor(preBody, name, orgIds, existingId)
%ORGFOR Dedup `organization` entities by name across one batch.
%
%   [ORGID, ORGBODY] = did2.convert.entities.orgFor(PREBODY, NAME, ORGIDS)
%   returns the id already minted for NAME (ORGBODY = []), or mints a fresh one
%   and returns the new `organization` body. ORGIDS is a containers.Map from
%   the case-folded, trimmed name to an id; it is a HANDLE, so the update
%   persists to the caller.
%
%   [...] = ORGFOR(..., EXISTINGID) uses EXISTINGID instead of minting, when
%   the organization is ITSELF a source document whose id is worth preserving
%   (the openMINDS graph writes one document per Organization instance;
%   the metadata_editor blob writes none, so that caller omits the argument).
%   The first name wins: a later EXISTINGID for a name already in ORGIDS is
%   IGNORED, because the id in the map is already referenced by every relation
%   minted so far. Preferring the later id would dangle those edges -- which is
%   the whole reason this returns the map's id rather than re-minting.
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB -- see entityDoc's header. Moved
%   out of did2.convert.migrators_j.metadata_editor; the EXISTINGID argument is
%   the only addition, and it is optional so the editor path is unchanged.
%
%   See also: did2.convert.entities.entityDoc, did2.convert.entities.emptyGids.

arguments
    preBody (1,1) struct
    name char
    orgIds
    existingId char = ''
end

key = lower(strtrim(name));
if isKey(orgIds, key)
    orgId = orgIds(key); orgBody = [];
    return;
end
if isempty(existingId)
    orgId = did.ido.unique_id();
else
    orgId = existingId;
end
orgIds(key) = orgId;   % containers.Map is a handle: the update persists to the caller
orgBody = did2.convert.entities.entityDoc(preBody, 'organization', orgId, ...
    struct('full_name', name), did2.convert.entities.emptyGids(), true);
end
