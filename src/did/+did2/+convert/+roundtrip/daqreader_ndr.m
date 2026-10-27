function [v1, spec] = daqreader_ndr(bodies)
%DAQREADER_NDR Rebuild a v1 `daqreader_ndr` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.daqreader_ndr(BODIES). V1 is the NDR
%   reader in NDI's v1 shape (daqreader_ndr.json + daqreader.json + base.json
%   at the locked NDI-matlab `main`, 3cb19a8, as +daq/+reader/+mfdaq/ndr.m and
%   +daq/+reader/+image/ndr.m newdocument write it). The migrator de-encodes it
%   onto the daqreader and hands it on, so BODIES holds the
%   `acquisition_reader` and its `software` entity:
%
%     base.id, session_id, datestamp        the acquisition_reader's
%     base.name                             '' (the writers set none)
%     daqreader.ndi_daqreader_class         the software entity's name
%     daqreader_ndr.ndr_reader_string       acquisition_reader.reader_string
%     daqreader_ndr.ndi_daqreader_ndr_class the software entity's name again:
%                                           the migrator converts only a
%                                           document where the two are equal
%                                           (carry-017 otherwise; [restated
%                                           values checked])
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.daqreader_ndr.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
[doc, ~, swName, spec] = daqParts(bodies, 'acquisition_reader', spec);
if isempty(doc)
    return;
end
blk = getIn(doc, 'acquisition_reader');
spec.unplaced = [spec.unplaced, others(blk, {'reader_string'}, 'acquisition_reader')];
base = rebuildBase(doc);
v1.document_class = struct('class_name', 'daqreader_ndr');
v1.base = struct('id', base.id, 'session_id', base.session_id, 'name', '', ...
    'datestamp', base.datestamp);
v1.daqreader = struct('ndi_daqreader_class', swName);
v1.daqreader_ndr = struct('ndr_reader_string', fieldText(blk, 'reader_string'), ...
    'ndi_daqreader_ndr_class', swName);
end
