function [software, swId] = jSoftware(name, version, url, sessionId, datestamp, opts)
%JSOFTWARE The `software` entity (did-schema #88: an `entity` of type software)
%   for a program NAME at VERSION, plus its version assertion.
%
%   [SOFTWARE, SWID] = jSoftware(NAME, VERSION, URL, SESSIONID, DATESTAMP)
%   SOFTWARE is a CELL of documents -- the entity, then, when VERSION is given,
%   a text_assertion of its version (`software.version` became a text
%   assertion, V_eta_entity_composition_plan.md sec. 4) -- and SWID the
%   entity's id. A caller appends the cell: `bodies = [bodies, software]`.
%   SOFTWARE is {} and SWID '' when NAME is empty (no identity, no entity; the
%   caller omits software_id). URL becomes a `global_identifier` (an IRI).
%   `local_identifier` is NAME@VERSION, as before, so two versions of one
%   program stay distinguishable (resolveSoftwareDedup keys on it).
%
%   'RequireSession', true: return {} when SESSIONID is empty.

arguments
    name (1,:) char
    version (1,:) char = ''
    url (1,:) char = ''
    sessionId = ''
    datestamp = ''
    opts.RequireSession (1,1) logical = false
end

software = {};
swId = '';
if isempty(name)
    return;
end
if opts.RequireSession && isempty(char(sessionId))
    return;
end
pre = struct('base', struct('session_id', char(sessionId), 'datestamp', char(datestamp)));
localId = name;
if ~isempty(version)
    localId = [name '@' version];
end
f = struct('name', name, 'local_identifier', localId);
if ~isempty(url)
    f.global_identifier = {url};
end
ent = jEntity(pre, 'software', f);
swId = ent.base.id;
software = {ent};
if ~isempty(version)
    software{end+1} = jStatement(pre, 'assertion', swId, ...
        did2.build.term('IAO:0000129', 'version number'), ...
        did2.build.valueCell('text', {version}, 'Canonical', 'text'), 'ValueKind', 'text');
end
end
