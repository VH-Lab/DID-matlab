function [v1, spec] = daqsystem(bodies)
%DAQSYSTEM Rebuild a v1 `daqsystem` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqsystem(BODIES). V1 is the
%   acquisition system in NDI's v1 shape (daqsystem.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+daq/system.m newdocument writes
%   it). BODIES holds the `acquisition_system`, its `software` entity and
%   the rig's `device` entity (Jess Haley 2026-11-19 [acquisition system is
%   a device entity], [migration mints the device by name]; did-schema
%   docs/plans/did_v2_standing_wiring_plan.md), which the configuration names
%   by `device_id`. The device holds nothing v1 does not: its name is the
%   rig name and it writes no local_identifier ([local identifier required
%   only where looked up], Jess Haley, 2026-11-19), so the round trip checks
%   the name against acquisition_system.name, reports any other field the
%   device states (local_identifier included), and reads nothing else from
%   it. A batch migrated
%   before the device was minted has neither, and reads as before.
%
%     base.id, session_id, datestamp   the acquisition_system's (rebuildBase)
%     base.name                        acquisition_system.name
%     daqsystem.ndi_daqsystem_class    the software entity's name
%     depends_on, in the writer's order:
%       filenavigator_id               epoch_file_pattern_id
%       daqreader_id                   reader_id
%       daqmetadatareader_id           '' (the template's own entry, which
%                                      add_dependency_value_n never fills)
%       daqmetadatareader_id_1.._N     epoch_parameter_reader_id, in order
%
%   Or the pass-1 passthrough (a daqsystem with nothing to declare), its
%   outbound renames undone.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.daqsystem.

arguments
    bodies cell
end

CLASS = 'daqsystem';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
[bodies, spec] = takeDevice(bodies, spec);
[doc, ~, swName, spec] = daqParts(bodies, 'acquisition_system', spec);
if isempty(doc)
    return;
end
spec.unplaced = [spec.unplaced, others(getIn(doc, 'acquisition_system'), {'name'}, ...
    'acquisition_system')];
base = rebuildBase(doc);
names = {'filenavigator_id', 'daqreader_id', 'daqmetadatareader_id'};
values = {firstId(doc, 'epoch_file_pattern_id'), firstId(doc, 'reader_id'), ''};
md = edgeIds(doc, 'epoch_parameter_reader_id');
for k = 1:numel(md)
    names{end+1} = sprintf('daqmetadatareader_id_%d', k); %#ok<AGROW>
    values{end+1} = md{k}; %#ok<AGROW>
end
v1.document_class = struct('class_name', CLASS);
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', fieldText(getIn(doc, 'acquisition_system'), 'name'), ...
    'datestamp', base.datestamp);
v1.daqsystem = struct('ndi_daqsystem_class', swName);
end

function [bodies, spec] = takeDevice(bodies, spec)
% The rig's device: the entity of type device the acquisition_system's
% `device_id` names, removed from BODIES once it is checked to hold only the
% rig name (its name; no local_identifier), so daqParts finds no extra
% document. A `device_id` naming no emitted device, or a device holding
% anything else, is reported.
k = find(cellfun(@(b) strcmp(classNameOf(b), 'acquisition_system'), bodies), 1);
if isempty(k)
    return;
end
devIds = edgeIds(bodies{k}, 'device_id');
if isempty(devIds)
    return;
end
if ~isscalar(devIds)
    spec.unplaced{end+1} = sprintf('the acquisition_system names %d devices', numel(devIds));
end
rigName = fieldText(getIn(bodies{k}, 'acquisition_system'), 'name');
j = find(cellfun(@(b) isEntityOfType(b, 'device') ...
    && strcmp(char(getIn(b, 'base', 'id')), devIds{1}), bodies), 1);
if isempty(j)
    spec.unplaced{end+1} = sprintf('the device %s the acquisition_system names was not emitted', devIds{1});
    return;
end
dev = bodies{j};
if ~strcmp(fieldText(dev.entity, 'name'), rigName)
    spec.unplaced{end+1} = 'the rig''s device is not named by the rig name';
end
for f = reshape(fieldnames(dev.entity), 1, [])
    if ~any(strcmp(f{1}, {'type', 'name'})) && ~allEmpty(dev.entity.(f{1}))
        spec.unplaced{end+1} = sprintf('the rig''s device states entity.%s', f{1}); %#ok<AGROW>
    end
end
bodies(j) = [];
end

function id = firstId(body, name)
ids = edgeIds(body, name);
id = '';
if ~isempty(ids); id = ids{1}; end
end
