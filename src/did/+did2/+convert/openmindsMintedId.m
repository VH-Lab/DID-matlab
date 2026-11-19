function tf = openmindsMintedId(openmindsId, openmindsType)
%OPENMINDSMINTEDID True when a v1 `openminds_id` is a per-document minted id.
%
%   TF = did2.convert.openmindsMintedId(OPENMINDSID, OPENMINDSTYPE) is true
%   when OPENMINDSID has the form `<Type>/<uuid>` (a UUID 8-4-4-4-12 in hex),
%   its <Type> is the openMINDS type OPENMINDSTYPE names (its IRI's last
%   segment, e.g. https://openminds.om-i.org/types/BiologicalSex), ignoring
%   case. Such an id is minted afresh for every document the writer makes
%   (Dab: one `BiologicalSex/<uuid>` per subject for the same term "male"), so
%   it names no shared openMINDS instance.
%
%   Decided by Jess Haley, 2026-11-19 [openMINDS minted ids are an accepted
%   loss] (did-schema did_v2_go_forward_class_audit.md; Waltham-Data-Science/
%   did-schema#212): "If these are just artifacts, accept the loss. We only
%   want one SD entity per dataset (or session)". carry-116's group B (the
%   minted ids of BiologicalSex, Species and Strain terms) converts to its term
%   assertion; no global_identifier is written for the id, and the whole-batch
%   round trip lists it as an accepted loss (did2.convert.roundtrip.wholeBatch
%   ACCEPTED_LOSSES).
%
%   See also did2.convert.migrators_j.openminds_subject,
%            did2.convert.openmindsIdRebuilds.

arguments
    openmindsId
    openmindsType = ''
end

tf = false;
if ~(ischar(openmindsId) || (isstring(openmindsId) && isscalar(openmindsId)))
    return;
end
if ~(ischar(openmindsType) || (isstring(openmindsType) && isscalar(openmindsType)))
    return;
end
tok = regexp(strtrim(char(openmindsId)), ['^([A-Za-z]+)/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-' ...
    '[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'], 'tokens', 'once');
if isempty(tok)
    return;
end
parts = strsplit(strtrim(char(openmindsType)), {'/', '#', ':', '.'});
parts = parts(~cellfun('isempty', parts));
tf = ~isempty(parts) && strcmpi(parts{end}, tok{1});
end
