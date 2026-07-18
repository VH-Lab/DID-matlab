function v2Body = daqreader_ndr(preBody)
%DAQREADER_NDR Chunk-c de-encode: daqreader_ndr dissolves into daqreader.
%   The reader subtype ('ndr') was encoded in the CLASS NAME, but it is already
%   discriminated by ndi_daqreader_class, so the distinguishing fields de-encode
%   onto the generic daqreader: ndr_reader_string -> daqreader.reader_string,
%   file_extension carried, and ndi_daqreader_ndr_class dropped (redundant). The
%   daqreader superclass chain is rebuilt by ensureClassBlocks after this.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
v2Body.document_class.class_name = 'daqreader';
v2Body.document_class.class_version = '2.0.0';

sub = struct();
if isfield(v2Body, 'daqreader_ndr') && isstruct(v2Body.daqreader_ndr)
    sub = v2Body.daqreader_ndr;
end
if ~isfield(v2Body, 'daqreader') || ~isstruct(v2Body.daqreader)
    v2Body.daqreader = struct();
end
if isfield(sub, 'ndr_reader_string')
    v2Body.daqreader.reader_string = sub.ndr_reader_string;
end
if isfield(sub, 'file_extension')
    v2Body.daqreader.file_extension = sub.file_extension;
end
if isfield(v2Body, 'daqreader_ndr')
    v2Body = rmfield(v2Body, 'daqreader_ndr');
end
end
