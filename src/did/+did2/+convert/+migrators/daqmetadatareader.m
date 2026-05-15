function v2Body = daqmetadatareader(preBody)
%DAQMETADATAREADER Migrate a did_v1 daqmetadatareader body to V_delta.
%
%   Renames the v1 `ndi_daqmetadatareader_class` field on the
%   daqmetadatareader property block to the V_delta-required
%   `reader_class` field. The v1 `tab_separated_file_parameter` field
%   has no V_delta counterpart and is dropped (per
%   docs/v2/RFC-step6d-ci-pipeline.md decision-default Q1: drop v1
%   fields that V_delta does not declare).

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'daqmetadatareader') ...
        || ~isstruct(v2Body.daqmetadatareader)
    error('did2:convert:missingBlock', ...
        'daqmetadatareader body is missing the daqmetadatareader property block.');
end

block = v2Body.daqmetadatareader;
newBlock = struct();
if isfield(block, 'ndi_daqmetadatareader_class')
    newBlock.reader_class = char(block.ndi_daqmetadatareader_class);
elseif isfield(block, 'reader_class')
    newBlock.reader_class = char(block.reader_class);
else
    newBlock.reader_class = '';
end
if isfield(block, 'metadata_names')
    newBlock.metadata_names = char(block.metadata_names);
end
v2Body.daqmetadatareader = newBlock;
end
