function bodies = filenavigator(preBody)
%FILENAVIGATOR Brainstorm-J migrator: did_v1 filenavigator -> epoch_file_pattern
%   (+ the `software` entity for the implementation class). 1 -> 1 or 1 -> 2.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   TEAM-SIGN-OFF [file navigation]: jess, 2026-08-06 (V_eta_daq_family_decisions.md:325)
%     "filenavigator becomes `epoch_file_pattern` with base.id preserved: the two
%      eval'd parameter strings become declared pattern lists (data_file_pattern,
%      epoch_map_pattern) plus epoch_map_format, and the implementation class name
%      becomes a software_id edge. `directory` is NOT a did_v1 source and is
%      unaffected."
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main (template AND writer agree)
%   ---------------------------------------------------------------------
%   ndi_common/database_documents/daq/filenavigator.json declares FOUR fields and
%   NO dependencies, and filenavigator_schema.json declares the same four:
%
%       ndi_filenavigator_class       "the ndi.file.navigator class type"
%       fileparameters                "the file parameters for finding epochs"
%       epochprobemap_class           "the ndi.epoch.probemap class type"
%       epochprobemap_fileparameters  "file parameters for finding epochprobemaps"
%
%   The writer is ndi.file.navigator/newdocument (navigator.m:729-755). It writes
%   class(obj) into ndi_filenavigator_class -- so the value is a MATLAB class
%   name: 'ndi.file.navigator', 'ndi.file.navigator.epochdir',
%   'ndi.file.navigator.rhd_series', 'ndi.setup.file.navigator.vhPrairie2p' --
%   and cell2str(...) into the two parameter fields.
%
%   The mapping:
%
%       ndi_filenavigator_class       -> a `software` entity + a software_id edge
%       fileparameters                -> epoch_file_pattern.data_file_pattern
%       epochprobemap_fileparameters  -> epoch_file_pattern.epoch_map_pattern
%       epochprobemap_class           -> epoch_file_pattern.epoch_map_format
%
%   epoch_map_format stays a plain char by decision: it is a MATLAB class name
%   and really the FORMAT of the epochprobemap file, closer to a content type
%   than to software, and binding it buys nothing until #32 makes bindings real
%   (V_eta_daq_family_decisions.md, "3. epoch_map_format stays a plain char").
%   So only ONE of the two class-name fields becomes software; that asymmetry is
%   the signed decision, not an oversight.
%
%   ---------------------------------------------------------------------
%   base.id IS PRESERVED -- TWO REQUIRED EDGES DEPEND ON IT
%   ---------------------------------------------------------------------
%   `filenavigator_id` is declared on two NDI classes and is REQUIRED on both:
%
%       database_documents/daq/daqsystem.json:13              filenavigator_id
%       schema_documents/daq/daqsystem_schema.json:5          "mustbenotempty": 1
%       database_documents/ingestion/epochfiles_ingested.json:13   filenavigator_id
%       schema_documents/ingestion/epochfiles_ingested_schema.json:5  "mustbenotempty": 1
%
%   and it is queried live by id at +ndi/+daq/system.m:36-44,491,512 and
%   +ndi/+file/navigator.m:237,499,707,723. Minting a fresh id here would dangle
%   every daqsystem and every ingested-epoch document in the corpus -- the
%   11,448-orphan mistake. base.id, base.session_id, base.name and base.datestamp
%   are carried verbatim.
%
%   ---------------------------------------------------------------------
%   THE GUARD: NOTHING TO DECLARE => PASS THE DOCUMENT THROUGH
%   ---------------------------------------------------------------------
%   Same shape as fitcurve / openminds_stimulus / probe_geometry. If the
%   `filenavigator` block is missing, or all four of its fields are empty, this
%   migrator would emit an epoch_file_pattern with no patterns, no format and no
%   software edge -- a hollow document that validates clean and says nothing.
%   The source class still has its V_eta tombstone (V_eta/stable/filenavigator.json,
%   whose four fields match the NDI template exactly), so passing through loses
%   nothing and is visible in `unconverted_by_class`.
%
%   ---------------------------------------------------------------------
%   OPEN, AND IT BLOCKS A CORPUS RUN -- READ BEFORE ENABLING THIS
%   ---------------------------------------------------------------------
%   V_eta/stable/epoch_file_pattern.json declares data_file_pattern and
%   epoch_map_pattern as  "type": "char", "mustBeScalar": false  -- i.e. it
%   intends a LIST (its own documentation says {'#\.rhd\>', '#\.tsv\>'}), but
%   the validator's char branch accepts only a char array or a SCALAR string:
%
%       +did2/+schema/cache.m:965-970
%           case {'char', 'did_uid', 'timestamp'}
%               if ~(ischar(value) || (isstring(value) && isscalar(value)))
%                   error('did2:validation:typeMismatch', ...);
%
%   Only the `string` branch (cache.m:971-1001) accepts a cell-of-chars, and it
%   was written for exactly this case ("MATLAB's jsondecode produces a
%   cell-of-chars for JSON arrays of strings"). The family's own sibling already
%   uses it: epochfiles_ingested.files is "type": "string", "mustBeScalar": false.
%
%   This migrator emits the cellstr the sign-off asks for. Under the schema as
%   declared at the time, that meant a multi-pattern navigator QUARANTINED with
%   did2:validation:typeMismatch -- the deliberate direction, because a
%   quarantine is visible and every alternative loses data silently: joining the
%   list into one char destroys it, a char matrix pads short patterns with
%   spaces (changing the regex), and emitting a char for one pattern but a cell
%   for several is the representation drift V_eta_openminds_family_record.md
%   Part 3 rules out.
%
%   ---- RESOLVED 2026-08-10. THE EMBARGO IS LIFTED. -------------------------
%   DID-schema now declares both fields `string` (data_file_pattern,
%   epoch_map_pattern -- and `synonym`, which had the identical defect). A
%   multi-pattern navigator VALIDATES CLEAN, so this migrator is no longer held
%   out of a corpus run.
%
%   The tripwire worked exactly as designed and is worth recording as a pattern.
%   `testEpochFilePatternListIsBlockedByTheCharDeclaration` asserted the
%   QUARANTINE, with its own header saying "WHEN IT LANDS THIS TEST FAILS --
%   that is its purpose", and naming the replacement. The schema landed, the
%   test failed within one CI run, and the note said what to do about it. That
%   is the difference between a known limitation and a latent bug: a limitation
%   somebody wrote a failing-on-purpose test for announces its own repair.
%
%   1 -> 2 (epoch_file_pattern + software), or 1 -> 1 when the implementation
%   class name is absent, or a passthrough when there is nothing to declare.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI filenavigator.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+file/navigator.m newdocument writes
%   it). Every v1 field and where it goes; did2.convert.roundtrip.filenavigator
%   rebuilds the v1 document and testRawV1RoundTripDaq compares the two:
%
%     base.id, session_id, datestamp     -> the epoch_file_pattern's
%     base.name                          -> not written (the writer leaves the
%                                           template's '')
%     ndi_filenavigator_class            -> the software entity's name
%     fileparameters                     -> file_pattern (the writer's
%                                           cell2str list, parsed)
%     epochprobemap_fileparameters       -> epoch_map_pattern (the same)
%     epochprobemap_class                -> epoch_map_format
%
%   What the renamed path would have discarded is carried, carry-100, as
%   before; a field or edge no part of this migrator reads, which the renamed
%   path dropped without a word, now carries the document whole as v1
%   (private/jRawAccount, jRawCarry; carry-100, [fields outside the template
%   are malformed]).

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct('filenavigator', ...
    {{'ndi_filenavigator_class', 'fileparameters', 'epochprobemap_class', ...
    'epochprobemap_fileparameters'}}), {});
if jRawCarry('filenavigator', src, collision, unplaced, 'carry-100')
    bodies = {src};
    return;
end

blk = struct();
if isfield(preBody, 'filenavigator') && isstruct(preBody.filenavigator) ...
        && isscalar(preBody.filenavigator)
    blk = preBody.filenavigator;
end

implClass  = jGetChar(blk, 'ndi_filenavigator_class');
mapFormat  = jGetChar(blk, 'epochprobemap_class');
dataList   = jFileMatchList(rawField(blk, 'fileparameters'));
mapList    = jFileMatchList(rawField(blk, 'epochprobemap_fileparameters'));

if isempty(implClass) && isempty(mapFormat) && isempty(dataList) && isempty(mapList)
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's V2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. Register row carry-132 covers it.
    % carry-register: carry-132
    did2.convert.reportNote('carried_as_v1', 'filenavigator', jCarryId(src), ...
        '[carry-132] malformed: no navigator class, file patterns or epoch map, so nothing to declare ([passthrough stays v1])');
    bodies = {src};         % nothing to declare -- see THE GUARD above
    return;
end

sessionId = jSid(preBody);
datestamp = jStamp(preBody);
[software, swId] = jSoftware(implClass, '', '', sessionId, datestamp);
% did-schema #88: `epoch_file_pattern` {file_pattern, epoch_map_pattern,
% epoch_map_format}; the data-file pattern list is `file_pattern`.
edges = struct();
if ~isempty(swId); edges.software_id = swId; end
efp = struct();
if ~isempty(dataList); efp.file_pattern = dataList; end
if ~isempty(mapList);  efp.epoch_map_pattern = mapList;  end
if ~isempty(mapFormat); efp.epoch_map_format = mapFormat; end
o = jOpts(preBody, 'Edges', edges, 'Id', char(preBody.base.id));
pattern = did2.build.document('epoch_file_pattern', efp, o{:});
bodies = [{pattern}, software];
end

% ===================== helpers =============================================

function v = rawField(block, name)
%RAWFIELD The field value untouched (jGetChar would coerce a cell away).
v = [];
if isstruct(block) && isfield(block, name)
    v = block.(name);
end
end
