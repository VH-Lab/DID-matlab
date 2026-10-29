function [v1, spec] = measurement(bodies)
%MEASUREMENT Rebuild a v1 `measurement` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.measurement(BODIES). V1 is the document
%   in NDI's v1 shape (measurement.json + base.json at the locked NDI-matlab
%   `main`, 3cb19a8, as +ndi/+setup/+NDIMaker/treatmentMaker.m
%   create_measurement_doc writes it). BODIES holds the `observation` and the
%   session anchor it names:
%
%     base.id, session_id, datestamp   the observation's
%     base.name                        '' (the writer sets none)
%     depends_on subject_id            the observation's entity_id (the
%                                      template's manipulation_id and
%                                      protocol_id entries are rebuilt empty)
%     measurement.ontologyName, name   the variable's node and name
%     measurement.numeric_value        a quantity's source value (and '' for a
%                                      term value: the writer's empty cell)
%     measurement.string_value         a term value's node (and '' for a
%                                      quantity: the writer's empty cell)
%     depends_on manipulation_id,      not rebuilt: the migrator converts only a
%       protocol_id                    document that names neither
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.measurement.

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
base = rebuildBase(obs);
[used, bad] = sessionAnchorOf(bodies, used, obs, base.session_id);
spec.unplaced = [spec.unplaced, bad];
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in a measurement', ...
        k, classNameOf(bodies{k}));
end
[node, name] = termParts(getIn(obs, 'statement', 'variable'));
blk = struct('ontologyName', node, 'name', name, 'numeric_value', '', 'string_value', '');
[kind, value] = statementValue(obs);
if strcmp(kind, 'term')
    [tnode, ~] = termParts(value);
    blk.string_value = tnode;
elseif ~isempty(kind)
    cells = asCell(value);
    if numel(cells) ~= 1
        spec.unplaced{end+1} = sprintf('the %s value holds %d entries (one number)', kind, numel(cells));
    else
        blk.numeric_value = numberOf(getIn(cells{1}, 'source_value'));
    end
else
    spec.unplaced{end+1} = 'the observation states no value';
end
subject = edgeIds(obs, 'entity_id');
if isempty(subject); subject = {''}; end
v1.document_class = struct('class_name', 'measurement');
% the template's three edges, in its order; the writer sets only subject_id
v1.depends_on = struct('name', {'subject_id', 'manipulation_id', 'protocol_id'}, ...
    'value', {subject{1}, '', ''});
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.measurement = blk;
spec.same(end+1) = struct('path', 'measurement.ontologyName', 'fn', @sameCurie, ...
    'why', ['a CURIE''s prefix case is notation ([spelling is notation], Jess ' ...
    'Haley, 2026-10-26); did2.convert.registeredTerm writes the registered spelling']);
spec.same(end+1) = struct('path', 'measurement.string_value', 'fn', @sameCurie, ...
    'why', 'a CURIE''s prefix case is notation ([spelling is notation])');
% [term names compare by node] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md)
spec = nameByNode(spec, 'measurement.name', node);
end
