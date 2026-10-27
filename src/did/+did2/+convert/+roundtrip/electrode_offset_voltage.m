function [v1, spec] = electrode_offset_voltage(bodies)
%ELECTRODE_OFFSET_VOLTAGE Rebuild a v1 `electrode_offset_voltage` from what the
%   migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.electrode_offset_voltage(BODIES). V1 is
%   the document in NDI's v1 shape (probe/electrode_offset_voltage.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as
%   +ndi/+setup/+conv/+marder/makeVoltageOffsets.m writes it). BODIES holds the
%   `observation` (variable "electrode offset voltage", value kind voltage) and
%   the session anchor its time_reference_id names:
%
%     base.id, session_id, datestamp        the observation's
%     base.name                             '' (the writer sets none)
%     depends_on probe_id                   the observation's entity_id
%     electrode_offset_voltage.offset       the voltage's source value (the
%                                           migrator writes source unit 'V')
%     electrode_offset_voltage.temperature  the `temperature` condition's value;
%                                           with no condition, NaN or empty
%                                           (the writer's "not recorded", which
%                                           the migrator leaves unwritten)
%
%   A passthrough (no numeric offset) is no conversion and has no inverse.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.electrode_offset_voltage.

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
[~, vname] = termParts(getIn(obs, 'statement', 'variable'));
if ~strcmpi(vname, 'electrode offset voltage')
    spec.unplaced{end+1} = sprintf('the observation''s variable is "%s", not electrode offset voltage', vname);
end
base = rebuildBase(obs);
sid = base.session_id;
[used, bad] = sessionAnchorOf(bodies, used, obs, sid);
spec.unplaced = [spec.unplaced, bad];
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in an electrode offset voltage', ...
        k, classNameOf(bodies{k}));
end

values = asCell(getIn(obs, 'voltage', 'value'));
offset = [];
if numel(values) ~= 1
    spec.unplaced{end+1} = sprintf('the observation holds %d voltage values (the offset is one)', ...
        numel(values));
else
    offset = numberOf(getIn(values{1}, 'source_value'));
    [unode, uname] = termParts(getIn(values{1}, 'source_unit'));
    if ~(sameCurie(unode, 'om:volt') || strcmp(uname, 'volt'))
        spec.unplaced{end+1} = sprintf('the voltage''s source unit is "%s", not the volt the migrator writes', ...
            unode);
    end
end

temperature = [];
conds = asCell(getIn(obs, 'statement', 'conditions'));
for k = 1:numel(conds)
    [~, cname] = termParts(getIn(conds{k}, 'variable'));
    if strcmpi(cname, 'temperature') && isempty(temperature)
        temperature = numberOf(getIn(conds{k}, 'quantity', 'value'));
    else
        spec.unplaced{end+1} = sprintf('condition %d ("%s") has no place in an electrode offset voltage', ...
            k, cname);
    end
end
if isempty(temperature)
    spec.equivalents(end+1) = struct('path', 'electrode_offset_voltage.temperature', ...
        'values', {{NaN, []}}, 'why', ['the writer''s "not recorded" (makeVoltageOffsets.m ' ...
        'reads T as NaN and skips the temperature query for it); the migrator writes no ' ...
        'condition for it']);
end

probe = edgeIds(obs, 'entity_id');
if isempty(probe); probe = {''}; end
v1.document_class = struct('class_name', 'electrode_offset_voltage');
v1.depends_on = struct('name', 'probe_id', 'value', probe{1});
v1.base = struct('id', base.id, 'session_id', sid, 'name', '', ...
    'datestamp', base.datestamp);
v1.electrode_offset_voltage = struct('offset', offset, 'temperature', temperature);
end
