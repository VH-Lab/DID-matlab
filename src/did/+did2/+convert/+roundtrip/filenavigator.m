function [v1, spec] = filenavigator(bodies)
%FILENAVIGATOR Rebuild a v1 `filenavigator` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.filenavigator(BODIES). V1 is the file
%   navigator in NDI's v1 shape (filenavigator.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+file/navigator.m newdocument writes
%   it). BODIES holds the `epoch_file_pattern` and its `software` entity:
%
%     base.id, session_id, datestamp     the epoch_file_pattern's
%     base.name                          '' (the writer sets none; V2 writes
%                                        none)
%     ndi_filenavigator_class            the software entity's name
%     fileparameters                     file_pattern, written back as the
%                                        writer's cell2str ('' for none)
%     epochprobemap_fileparameters       epoch_map_pattern, the same
%     epochprobemap_class                epoch_map_format
%
%   Or the pass-1 passthrough (a navigator with nothing to declare), its
%   outbound renames undone.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.filenavigator.

arguments
    bodies cell
end

CLASS = 'filenavigator';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
[doc, ~, swName, spec] = daqParts(bodies, 'epoch_file_pattern', spec);
if isempty(doc)
    return;
end
blk = getIn(doc, 'epoch_file_pattern');
spec.unplaced = [spec.unplaced, others(blk, ...
    {'file_pattern', 'epoch_map_pattern', 'epoch_map_format'}, 'epoch_file_pattern')];
base = rebuildBase(doc);
v1.document_class = struct('class_name', CLASS);
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.filenavigator = struct( ...
    'ndi_filenavigator_class', swName, ...
    'fileparameters', cell2strOf(getIn(doc, 'epoch_file_pattern', 'file_pattern')), ...
    'epochprobemap_class', fieldText(blk, 'epoch_map_format'), ...
    'epochprobemap_fileparameters', cell2strOf(getIn(doc, 'epoch_file_pattern', 'epoch_map_pattern')));
end
