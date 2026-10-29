function [v1, spec] = probe_location(bodies)
%PROBE_LOCATION Rebuild a v1 `probe_location` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.probe_location(BODIES). V1 is the
%   location in NDI's v1 shape (probe_location.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +fun/+doc/+probe/probeLocations4probes.m,
%   +setup/+conv/+dabrowska/doImport.m and +marder/marderprobe2uberon.m write
%   it). BODIES holds the `observation` (variable Anatomic Site, NCIT:C13717)
%   and the session anchor its time_reference_id names:
%
%     base.id, session_id, datestamp   the observation's
%     base.name                        '' (the writers set none)
%     depends_on probe_id              the observation's entity_id
%     probe_location.ontology_name     the value term's node (a CURIE's prefix
%                                      case is notation)
%     probe_location.name              the value term's name, compared
%                                      by the node ([term names compare by
%                                      node], Jess Haley, 2026-10-29)
%
%   The anchor must be the session anchor the migrator makes (a
%   relative_time_reference `intervalDuring` the observation's session, with
%   no time of its own); anything else, or any other document, is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.probe_location.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
obs = [];
used = false(1, numel(bodies));
for k = 1:numel(bodies)
    if strcmp(classNameOf(bodies{k}), 'observation')
        obs = bodies{k};
        used(k) = true;
        break;
    end
end
if isempty(obs)
    spec.unplaced{end+1} = 'no observation was emitted';
    return;
end
[vnode, ~] = termParts(getIn(obs, 'statement', 'variable'));
if ~sameCurie(vnode, 'NCIT:C13717')
    spec.unplaced{end+1} = sprintf('the observation''s variable is "%s", not Anatomic Site', vnode);
end
base = rebuildBase(obs);
sid = base.session_id;
tr = edgeIds(obs, 'time_reference_id');
if numel(tr) ~= 1
    spec.unplaced{end+1} = sprintf('the observation names %d time references (the session anchor is one)', ...
        numel(tr));
else
    hit = 0;
    for k = 1:numel(bodies)
        if ~used(k) && strcmp(char(getIn(bodies{k}, 'base', 'id')), tr{1})
            hit = k;
            break;
        end
    end
    if hit == 0
        spec.unplaced{end+1} = 'the session anchor was not emitted';
    else
        used(hit) = true;
        a = bodies{hit};
        [rnode, rname] = termParts(getIn(a, 'relative_time_reference', 'value', 'relation'));
        during = endsWith(rnode, 'intervalDuring') || strcmp(rname, 'intervalDuring');
        if ~strcmp(classNameOf(a), 'relative_time_reference') ...
                || ~isequal(edgeIds(a, 'referent_id'), {sid}) || ~during ...
                || ~allEmpty(getIn(a, 'relative_time_reference', 'value', 'start'))
            spec.unplaced{end+1} = 'the time reference is not the session anchor (intervalDuring the session)';
        end
    end
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a probe location', ...
        k, classNameOf(bodies{k}));
end
[node, name] = termParts(getIn(obs, 'term', 'value'));
probe = edgeIds(obs, 'entity_id');
if isempty(probe); probe = {''}; end
v1.document_class = struct('class_name', 'probe_location');
v1.depends_on = struct('name', 'probe_id', 'value', probe{1});
v1.base = struct('id', base.id, 'session_id', sid, 'name', '', ...
    'datestamp', base.datestamp);
v1.probe_location = struct('ontology_name', node, 'name', name);
spec.same(end+1) = struct('path', 'probe_location.ontology_name', 'fn', @sameCurie, ...
    'why', ['a CURIE''s prefix case is notation ([spelling is notation], Jess ' ...
    'Haley, 2026-10-26); did2.convert.registeredTerm writes the registered spelling']);
% [term names compare by node] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): the name is the registry label of the node
% (e.g. the Dabrowska writer's "bed nucleus of stria terminalis (BNST)" is
% UBERON:0001880 "bed nucleus of stria terminalis"); compared by that node
spec = nameByNode(spec, 'probe_location.name', node);
end
