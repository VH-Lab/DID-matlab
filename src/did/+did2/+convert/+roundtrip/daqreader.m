function [v1, spec] = daqreader(bodies)
%DAQREADER Rebuild a v1 `daqreader` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqreader(BODIES). V1 is the reader in
%   NDI's v1 shape (daqreader.json + base.json at the locked NDI-matlab
%   `main`, 3cb19a8, as +ndi/+daq/reader.m newdocument writes it). BODIES holds
%   the `acquisition_reader` and its `software` entity:
%
%     base.id, session_id, datestamp  the acquisition_reader's
%     base.name                       '' (the writer sets none)
%     daqreader.ndi_daqreader_class   the software entity's name
%     daqreader.reader_string         acquisition_reader.reader_string, when
%                                     it has one (not a template field; only a
%                                     de-encoded daqreader_ndr states one)
%
%   Or the pass-1 passthrough (a reader with nothing to declare), its outbound
%   renames undone.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.daqreader,
%            did2.convert.roundtrip.daqreader_ndr.

arguments
    bodies cell
end

CLASS = 'daqreader';
spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), CLASS)
    v1 = undoOutbound(bodies{1});
    return;
end
[doc, ~, swName, spec] = daqParts(bodies, 'acquisition_reader', spec);
if isempty(doc)
    return;
end
blk = getIn(doc, 'acquisition_reader');
spec.unplaced = [spec.unplaced, others(blk, {'reader_string'}, 'acquisition_reader')];
base = rebuildBase(doc);
v1.document_class = struct('class_name', CLASS);
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.daqreader = struct('ndi_daqreader_class', swName);
rs = fieldText(blk, 'reader_string');
if ~isempty(rs)
    v1.daqreader.reader_string = rs;
end
end
