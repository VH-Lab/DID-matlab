function v2Body = daqmetadatareader(preBody)
%DAQMETADATAREADER Migrate a did_v1 daqmetadatareader body to V_delta.
%
%   Renames the v1 `ndi_daqmetadatareader_class` field on the
%   daqmetadatareader property block to the V_delta-required
%   `reader_class` field. Preserves the optional v1
%   `tab_separated_file_parameter` field as a V_delta pass-through:
%   it is the "lazy hook" for TSV-per-epoch metadata sources and
%   real v1 corpora populate it. See
%   `did-schema/schemas/V_delta/conversions/from_did_v1/daqmetadatareader.md`
%   and `did-schema#50` for the V_delta-side decision to keep the
%   field rather than force per-doc synthesis of a
%   `daqmetadatareader_tsv` subclass.

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
if isfield(block, 'tab_separated_file_parameter')
    newBlock.tab_separated_file_parameter = ...
        char(block.tab_separated_file_parameter);
end
v2Body.daqmetadatareader = newBlock;
end
