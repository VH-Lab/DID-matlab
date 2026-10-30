function v2Body = daqreader_ndr(preBody)
%DAQREADER_NDR Chunk-c de-encode: daqreader_ndr folds into an acquisition_reader.
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
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI daqreader_ndr.json + daqreader.json + base.json
%   at the locked NDI-matlab `main`, 3cb19a8, as +daq/+reader/+mfdaq/ndr.m and
%   +daq/+reader/+image/ndr.m newdocument write it). It has NO superclass
%   migrator to fold: neither `base` nor `daqreader` has one (+migrators_j/
%   daqreader.m is the concrete migrator this one hands on to). Every v1 field
%   and where it goes; did2.convert.roundtrip.daqreader_ndr rebuilds the v1
%   document and testRawV1RoundTripDaq compares the two:
%
%     base.id, session_id, datestamp     -> the acquisition_reader's
%     base.name                          -> not written (the writer leaves '')
%     daqreader.ndi_daqreader_class      -> the software entity's name
%     daqreader_ndr.ndr_reader_string    -> acquisition_reader.reader_string
%     daqreader_ndr.ndi_daqreader_ndr_class
%                                        -> not written: it restates the
%                                           reader class (carry-017 otherwise)
%     daqreader_ndr.file_extension       -> carried (carry-039)
%
%   What the renamed path would have discarded is carried, carry-049, as
%   before; a field or edge no part of this migrator reads now carries the
%   document whole as v1 (private/jRawAccount, jRawCarry; carry-100, [fields outside the template
%   are malformed]).

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'daqreader', {{'ndi_daqreader_class'}}, ...
    'daqreader_ndr', {{'ndr_reader_string', 'ndi_daqreader_ndr_class', 'file_extension'}}), {});
if jRawCarry('daqreader_ndr', src, collision, unplaced, 'carry-100')
    v2Body = {src};
    return;
end

% `ndi_daqreader_ndr_class` is dropped only when it restates
% `daqreader.ndi_daqreader_class` ([restated values checked], Jess Haley,
% 2026-10-26; TEAM-SIGN-OFF [daq configuration], "dropped as redundant").
% One that differs carries the document whole as v1 ([partly placed is carried
% as v1], Jess Haley, 2026-10-25).
ndrClass = textField(preBody, 'daqreader_ndr', 'ndi_daqreader_ndr_class');
readerClass = textField(preBody, 'daqreader', 'ndi_daqreader_class');
unplaced = {};
if ~isempty(ndrClass) && ~strcmp(ndrClass, readerClass)
    unplaced{end+1} = sprintf(['[carry-017] daqreader_ndr.ndi_daqreader_ndr_class "%s" (differs ' ...
        'from daqreader.ndi_daqreader_class "%s")'], ndrClass, readerClass);
end
% `file_extension` is restated nowhere on the V2 output (the acquisition_reader
% and its software entity hold no extension; see below for why it is not
% written either), so a document that sets one is carried whole as v1
% ([generic stage is lossless], Jess Haley, 2026-10-25) instead of losing it.
if ~isempty(textField(preBody, 'daqreader_ndr', 'file_extension'))
    unplaced{end+1} = '[carry-039] daqreader_ndr.file_extension';
end
if ~isempty(unplaced)
    % carry-register: carry-017 (the reader class item); carry-039 (file_extension)
    did2.convert.reportNote('carried_as_v1', 'daqreader_ndr', char(preBody.base.id), ...
        ['unplaced: ' strjoin(unplaced, ', ')]);
    v2Body = {src};
    return;
end

% NO RENAME TO `daqreader`: that class is `retire` and leaves V2 (Decided by
% Jess Haley, 2026-10-25 [retired classes leave V2] (1), did-schema
% V_eta_go_forward_class_audit.md: the generic migration stops writing retired
% classes as V2 documents). The reading copy keeps its v1 class name;
% daqreader.m reads only its `daqreader` block, never the class name, and
% writes the decided target, an `acquisition_reader`.
v2Body = preBody;

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

% AND NOW HAND IT ON, which is the half that was missing. (Until 2026-10-30 the
% class was renamed to `daqreader` here; see NO RENAME above.) Renaming the
% class to `daqreader` did NOT put this document on daqreader.m's path:
% did2.convert.v1_to_v2/runConcreteMigrator dispatches ONCE, on the SOURCE class
% name, and never re-dispatches after a migrator rewrites it. So a
% `daqreader_ndr` document came out of here as a `daqreader` -- a class the
% signed daq decision retires -- and daqreader.m's own header said so:
% "this migrator is not on that path today".
%
% Delegating here is the whole fix, and it is safe in both directions: the
% de-encode above has already moved ndr_reader_string onto
% daqreader.reader_string, so daqreader.m sees exactly the shape it expects,
% and if it decides there is nothing to say it returns the body unchanged.
% Both PRED `daqreader_ndr` documents carry reader_string 'intan', which is
% precisely the case the old guard passed through.
v2Body = did2.convert.migrators_j.daqreader(v2Body);
% daqreader.m carries a document it cannot declare (carry-130: no reader class
% and no reader string) by returning the body it was handed, which is this
% function's READING COPY (its daqreader_ndr block folded away), not the v1
% source. A carry is the untouched v1 document ([passthrough stays v1];
% [retired classes leave V2] (1)), so that copy is replaced by SRC; the note
% daqreader.m left stands.
if isCarried(v2Body)
    v2Body = {src};
end
end

function tf = isCarried(out)
%ISCARRIED True unless OUT holds the acquisition_reader daqreader.m builds.
if ~iscell(out); out = {out}; end
tf = true;
for k = 1:numel(out)
    b = out{k};
    cn = '';
    if isa(b, 'did2.document')
        cn = char(b.className());
    elseif isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
            && isfield(b.document_class, 'class_name')
        cn = char(b.document_class.class_name);
    end
    if strcmp(cn, 'acquisition_reader')
        tf = false;
        return;
    end
end
end

function v = textField(body, blockName, fieldName)
%TEXTFIELD BODY.(BLOCKNAME).(FIELDNAME) as char, '' when absent.
v = '';
if isfield(body, blockName) && isstruct(body.(blockName)) && isscalar(body.(blockName)) ...
        && isfield(body.(blockName), fieldName) && ~isempty(body.(blockName).(fieldName))
    v = char(string(body.(blockName).(fieldName)));
end
end
