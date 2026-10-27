function [v1, spec] = daqsystem(bodies)
%DAQSYSTEM Rebuild a v1 `daqsystem` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqsystem(BODIES). V1 is the
%   acquisition system in NDI's v1 shape (daqsystem.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+daq/system.m newdocument writes
%   it). BODIES holds the `acquisition_system` and its `software` entity:
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
for e = {'device_id'}
    if ~isempty(edgeIds(doc, e{1}))
        spec.unplaced{end+1} = sprintf('the acquisition_system has a %s edge', e{1});
    end
end
v1.document_class = struct('class_name', CLASS);
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', base.id, 'session_id', base.session_id, ...
    'name', fieldText(getIn(doc, 'acquisition_system'), 'name'), ...
    'datestamp', base.datestamp);
v1.daqsystem = struct('ndi_daqsystem_class', swName);
end

function id = firstId(body, name)
ids = edgeIds(body, name);
id = '';
if ~isempty(ids); id = ids{1}; end
end
