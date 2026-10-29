function tf = openmindsIdRebuilds(node, openmindsId, ix, uriBase)
%OPENMINDSIDREBUILDS True when a v1 openMINDS controlled term's `openminds_id`
%   can be rebuilt from its term through the term registry's `equivalent` list.
%
%   TF = did2.convert.openmindsIdRebuilds(NODE, OPENMINDSID) looks the term
%   NODE up in the shared schema's term registry (did2.schema.termIndex) and
%   is true when that row's `equivalent` list holds OPENMINDSID as written,
%   or as `openminds:<OPENMINDSID>`, or (an IRI) as `openminds:<its last path
%   segment>`, or (an IRI under the `openminds` prefix's `uri_base`) as the
%   registered CURIE `openminds:<terminology>/<name>`. TF = ...(NODE,
%   OPENMINDSID, IX) reads the index IX instead (a test, or a caller holding
%   one); TF = ...(NODE, OPENMINDSID, IX, URIBASE) takes the prefix's
%   `uri_base` as URIBASE instead of reading it from the shared schema's CURIE
%   registry (IX may be [] for the shared index).
%
%   THE REGISTERED FORM. did-schema's CURIE registry (CURIE_lookups_meta.json,
%   prefix `openminds`, registered for [census terms] and [dataset form terms],
%   Jess Haley, 2026-10-26) writes the openMINDS instance https://openminds.om-i.org/instances/<terminology>/<name>
%   as `openminds:<terminology>/<name>` (pattern ^[A-Za-z]+/[A-Za-z0-9_-]+$),
%   and check_term_registry rule R13 requires every `equivalent` to be a CURIE
%   in a known prefix, in its spelling. So a filled list holds
%   `openminds:species/caenorhabditisElegans`, which neither earlier form of
%   the v1 IRI gives; without this form no id that v1 writes as openMINDS's
%   own IRI (ndi.database.fun.openMINDSobj2struct: `char(openmindsObj.id)`)
%   could rebuild.
%
%   Decided by Jess Haley, 2026-10-27 [openMINDS subject leftovers] (did-schema
%   V_eta_go_forward_class_audit.md): "a controlled term's `openminds_id` is
%   rebuilt from the term through the registry's `equivalent` list ([term
%   equivalents recorded]), and a document whose id does not rebuild is
%   carried". did-schema has the `equivalent` column (3a1b316) but no row
%   fills it yet (0 of 896 rows at did-schema 013d198), so no id rebuilds and
%   did2.convert.migrators_j.openminds_subject carries every document that
%   states one. did2.convert.roundtrip.openminds_subject reads the id back
%   through this function ([term equivalents recorded], the round trip read).

arguments
    node {mustBeText}
    openmindsId {mustBeText}
    ix = []
    uriBase = []
end

tf = false;
node = strtrim(char(node));
openmindsId = strtrim(char(openmindsId));
if isempty(node) || isempty(openmindsId)
    return;
end
if isempty(ix)
    try
        ix = did2.schema.termIndex();
    catch
        return;
    end
end
if ~isstruct(ix) || ~isfield(ix, 'present') || ~ix.present
    return;
end
key = did2.schema.curieKey(node);
if ~isKey(ix.byNode, key)
    return;
end
e = ix.byNode(key);
if ~isfield(e, 'equivalent') || isempty(e.equivalent)
    return;
end
forms = {openmindsId, ['openminds:' openmindsId]};
parts = regexp(openmindsId, '[^/#]+$', 'match', 'once');
if ~isempty(parts) && ~strcmp(parts, openmindsId)
    forms{end+1} = ['openminds:' parts];
end
if isempty(uriBase)
    uriBase = registeredUriBase();
end
uriBase = char(uriBase);
if ~isempty(uriBase) && numel(openmindsId) > numel(uriBase) ...
        && strncmp(openmindsId, uriBase, numel(uriBase))
    forms{end+1} = ['openminds:' openmindsId(numel(uriBase)+1:end)];
end
tf = any(ismember(forms, e.equivalent));
end

% ===================== helpers =============================================

function b = registeredUriBase()
%REGISTEREDURIBASE The `openminds` prefix's `uri_base` in the shared schema's
%   CURIE registry, or '' when the schema in use has none.
b = '';
try
    c = did2.schema.cache.shared();
    reg = c.curieRegistry;
catch
    return;
end
if isstruct(reg) && isscalar(reg) && isfield(reg, 'prefixes') && isstruct(reg.prefixes) ...
        && isfield(reg.prefixes, 'openminds') && isstruct(reg.prefixes.openminds) ...
        && isfield(reg.prefixes.openminds, 'uri_base')
    v = reg.prefixes.openminds.uri_base;
    if ischar(v) || (isstring(v) && isscalar(v))
        b = char(v);
    end
end
end
