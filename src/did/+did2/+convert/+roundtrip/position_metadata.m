function [v1, spec] = position_metadata(bodies)
%POSITION_METADATA Rebuild a v1 `position_metadata` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.position_metadata(BODIES). V1 is the
%   document in NDI's v1 shape (element/position_metadata.json + base.json at
%   the locked NDI-matlab `main`, 3cb19a8, as +setup/+conv/+haley/doImport.m
%   writes it). BODIES holds the `observation` (variable PATO:0000140
%   "position", value kind term) and the session anchor its time_reference_id
%   names:
%
%     base.id, session_id, datestamp   the observation's
%     base.name                        '' (the writer sets none)
%     depends_on element_id            the observation's entity_id
%     position_metadata.ontologyNode   the value term's node (a CURIE's prefix
%                                      case is notation)
%     position_metadata.units,         not rebuilt: the migrator converts only
%       position_metadata.dimensions   a document that states neither (it
%                                      carries the others, carry-053)
%
%   The anchor must be the session anchor the migrator makes (a
%   relative_time_reference `intervalDuring` the observation's session, with
%   no time of its own); anything else, or any other document, is unplaced.
%   A passthrough (no ontologyNode) is no conversion and has no inverse.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.position_metadata.

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
[vnode, vname] = termParts(getIn(obs, 'statement', 'variable'));
if ~(sameCurie(vnode, 'PATO:0000140') || (isempty(vnode) && strcmp(vname, 'position')))
    spec.unplaced{end+1} = sprintf('the observation''s variable is "%s", not position', vnode);
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
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a position metadata', ...
        k, classNameOf(bodies{k}));
end
[node, ~] = termParts(getIn(obs, 'term', 'value'));
element = edgeIds(obs, 'entity_id');
if isempty(element); element = {''}; end
v1.document_class = struct('class_name', 'position_metadata');
v1.depends_on = struct('name', 'element_id', 'value', element{1});
v1.base = struct('id', base.id, 'session_id', sid, 'name', '', ...
    'datestamp', base.datestamp);
v1.position_metadata = struct('ontologyNode', node);
spec.same(end+1) = struct('path', 'position_metadata.ontologyNode', 'fn', @sameCurie, ...
    'why', ['a CURIE''s prefix case is notation ([spelling is notation], Jess ' ...
    'Haley, 2026-10-26); did2.convert.registeredTerm writes the registered spelling']);
end
