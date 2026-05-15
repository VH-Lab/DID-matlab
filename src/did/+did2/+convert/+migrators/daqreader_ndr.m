function v2Body = daqreader_ndr(preBody)
%DAQREADER_NDR Migrate a did_v1 daqreader_ndr body to V_delta.
%
%   Renames the v1 `ndr_reader_string` field on the daqreader_ndr
%   property block to the V_delta-required `file_type` field. The v1
%   `ndi_daqreader_ndr_class` field has no V_delta counterpart and is
%   dropped.
%
%   v1 shape:
%       daqreader_ndr.ndr_reader_string    (e.g., 'intan')
%       daqreader_ndr.ndi_daqreader_ndr_class
%
%   V_delta shape:
%       daqreader_ndr.file_type            (required, char)
%       daqreader_ndr.file_extension       (optional, not produced
%                                           from v1; left absent)

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'daqreader_ndr') || ~isstruct(v2Body.daqreader_ndr)
    error('did2:convert:missingBlock', ...
        'daqreader_ndr body is missing the daqreader_ndr property block.');
end

block = v2Body.daqreader_ndr;
newBlock = struct();
if isfield(block, 'ndr_reader_string')
    newBlock.file_type = char(block.ndr_reader_string);
elseif isfield(block, 'file_type')
    newBlock.file_type = char(block.file_type);
else
    newBlock.file_type = '';
end
if isfield(block, 'file_extension')
    newBlock.file_extension = char(block.file_extension);
end
v2Body.daqreader_ndr = newBlock;
end
