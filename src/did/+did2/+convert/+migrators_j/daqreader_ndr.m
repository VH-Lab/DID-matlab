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
% NO `file_extension`. It was copied here until 2026-08-10, and it is an
% INVENTED FIELD: `git grep -l "file_extension" origin/main -- '*.m' '*.json'`
% returns ZERO files, so no NDI template declares it and no NDI writer sets it.
% DID-schema deleted the declaration (commit 4815882), which means copying it
% would emit an UNDECLARED field and quarantine the document.
%
% It is latent rather than live only because the source field cannot exist on a
% real document -- the same reason it survived this long. The DID-schema pytest
% twin (test_daqreader_ndr_de_encoded) was inverted when the field was deleted;
% its MATLAB twin at testMigratorsJ.m was not, and is inverted in the same
% commit as this deletion.
if isfield(v2Body, 'daqreader_ndr')
    v2Body = rmfield(v2Body, 'daqreader_ndr');
end
end
