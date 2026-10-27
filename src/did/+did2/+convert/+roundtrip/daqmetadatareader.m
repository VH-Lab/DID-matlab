function [v1, spec] = daqmetadatareader(bodies)
%DAQMETADATAREADER Rebuild a v1 `daqmetadatareader` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqmetadatareader(BODIES). V1 is the
%   metadata reader in NDI's v1 shape (daqmetadatareader.json + base.json at
%   the locked NDI-matlab `main`, 3cb19a8, as +ndi/+daq/metadatareader.m
%   newdocument writes it). BODIES holds the `epoch_parameter_reader` and its
%   `software` entity:
%
%     base.id, session_id, datestamp  the epoch_parameter_reader's
%     base.name                       '' (the writer sets none)
%     ndi_daqmetadatareader_class     the software entity's name
%     tab_separated_file_parameter    file_regex
%
%   Or the pass-1 passthrough (a reader with nothing to declare), its outbound
%   renames undone.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.daqmetadatareader.

arguments
    bodies cell
end

CLASS = 'daqmetadatareader';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
[doc, ~, swName, spec] = daqParts(bodies, 'epoch_parameter_reader', spec);
if isempty(doc)
    return;
end
blk = getIn(doc, 'epoch_parameter_reader');
spec.unplaced = [spec.unplaced, others(blk, {'file_regex'}, 'epoch_parameter_reader')];
base = rebuildBase(doc);
v1.document_class = struct('class_name', CLASS);
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.daqmetadatareader = struct('ndi_daqmetadatareader_class', swName, ...
    'tab_separated_file_parameter', fieldText(blk, 'file_regex'));
end
