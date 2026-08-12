function v2Body = daqreader_ndr(preBody)
%DAQREADER_NDR Chunk-c de-encode: daqreader_ndr dissolves into daqreader.
%   The reader subtype ('ndr') was encoded in the CLASS NAME, but it is already
%   discriminated by ndi_daqreader_class, so the distinguishing fields de-encode
%   onto the generic daqreader: ndr_reader_string -> daqreader.reader_string,
%   and ndi_daqreader_ndr_class dropped (redundant). `file_extension` is NOT
%   carried -- see the block at the copy site below for why, and do not restore
%   it from this line. The daqreader superclass chain is rebuilt by
%   ensureClassBlocks after this.
%
%   CORRECTED 2026-08-12. This sentence read "file_extension carried" while the
%   code twenty lines down said "NO `file_extension`" and dated its deletion to
%   2026-08-10. The CODE was right: there is no `file_extension` assignment in
%   this function, and the built schema has no such declaration to receive one
%   (0 of 247 json files under DID-schema schemas/V_eta mention the name). This
%   is the stale-header trap in the header of the very file whose allow-list
%   entry was retired for it -- a docstring claiming MORE was carried than is,
%   which is the reassuring direction.

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
% INVENTED FIELD: no NDI template declares it and no NDI writer sets it.
% DID-schema deleted the declaration (commit 4815882), which means copying it
% would emit an UNDECLARED field and quarantine the document.
%
% THE CITATION HERE WAS THE CASE-SENSITIVE GREP, and it is replaced 2026-08-12.
% It read: `git grep -l "file_extension" origin/main -- '*.m' '*.json'` returns
% ZERO files. That command does return zero -- and it CANNOT have found the
% camelCase spelling NDI actually uses, which is the `demo_ndi`-against-`demoNDI`
% error CLAUDE.md names verbatim. universalRenames snake-cases NDI's fields on
% the way in, so the search had to cover both spellings. It does now, and the
% conclusion SURVIVES on positive evidence rather than on a query that could not
% have matched:
%
%   DENOMINATOR: 1,253 .m + .json files on NDI origin/main
%     file_extension   0 files      fileExtension   2 files
%     FileExtension    0 files      file_ext        0 files
%
%   $ git grep -n "fileExtension" origin/main -- '*.m' '*.json'
%     ndi_install.m:425      [~, fileName, fileExtension] = fileparts(...)
%     ndi_install.m:427,430  (the same local, used to build a websave path)
%     tests/+ndi/+unittest/NDIFileNavigatorTest.m:97,110,117,123,137,139
%                            a test helper's `fileExtensions` cell parameter
%
% Both are LOCAL VARIABLES -- an installer's fileparts result and a test
% helper's argument. Neither is a document field, neither is declared by a
% template, neither is written by a writer. So the field is invented in every
% spelling, and now that is measured rather than assumed.
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
