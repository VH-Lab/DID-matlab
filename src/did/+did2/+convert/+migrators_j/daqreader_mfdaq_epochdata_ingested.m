function bodies = daqreader_mfdaq_epochdata_ingested(preBody)
%DAQREADER_MFDAQ_EPOCHDATA_INGESTED Hand a v1 ingested mfdaq epoch archive on,
%   exactly as v1 wrote it, to the batch pass that converts it.
%
%   HANDED ON AS v1 (Decided by Jess Haley, 2026-10-25 [retired classes leave
%   V2], step (1), did-schema did_v2_go_forward_class_audit.md: "the generic
%   migration stops writing retired classes as V2 documents (at the locked DID
%   head the generated targets show ... `daqreader_mfdaq_epochdata_ingested` ->
%   `daqreader_epochdata_ingested`): each is carried as v1 until it has a V2
%   home ([generic stage is lossless])"). This migrator used to rename the
%   document to the retired V2 class `daqreader_epochdata_ingested`, moving the
%   mfdaq `parameters` block onto it, and validate it against that class file.
%   It now returns the v1 document unchanged; did2.convert.v1_to_v2 lists the
%   class in HAND_ON_CLASSES, so the document is stamped did_v1 and never
%   validated against v2, as `daqreader_epochdata_ingested` and
%   `daqreader_image_epochdata_ingested` already are ([handed-on are v1 as
%   written], Jess Haley, 2026-11-03).
%
%   ITS V2 HOME is built by the batch passes, not here ([ingested archives are
%   sampled bodies], Jess Haley, 2026-11-01): did2.convert.resolveEpochProbemap
%   carries each attached file series as an `opaque_body` of the epoch's
%   recording observations, writes the epoch's clocks as relative_time_reference
%   documents from the archive's `daqreader_epochdata_ingested.epochtable`, and
%   retires the archive once every file and clock it holds has a new owner
%   (its isArchiveClass matches this class name, and it reads the edge, the
%   epoch string and the files in their v1 spelling); NDI-matlab's second pass
%   (ndi.migrate.internal.ingestedArchiveBodies) turns those bodies into
%   sampled bodies, reading the segment lengths from the v1 document's
%   `daqreader_mfdaq_epochdata_ingested.parameters`. An archive the pass keeps
%   (a file with no new owner) is still this v1 document at the end of the
%   batch, and is stored as its v1 source ([handed-on classes carried at the
%   end], Jess Haley, 2026-11-02; NDI-matlab ndi.migrate.internal.
%   carryUnchangedAsV1), so NDI's readers read it as they read any v1
%   archive: ndi.daq.reader/getingestedarchive finds it by `isa
%   daqreader_epochdata_ingested` (its v1 superclass) and
%   ndi.daq.reader.mfdaq reads `daqreader_mfdaq_epochdata_ingested.parameters`,
%   which the renamed V2 document no longer held.
%
%   No epoch clock lift here: the v1 templates declare no `epoch_id` edge
%   (NDI-matlab ingestion/daqreader_mfdaq_epochdata_ingested.json at the
%   locked `main` declares only `daqreader_id`), and the clocks are written by
%   resolveEpochProbemap from the epochtable above.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]). Before handing it on, the document is checked
%   against its template, as before: an `ndi_document` block beside `base` is
%   read as `base` ([ndi_document read as base], Jess Haley, 2026-10-31); a
%   field it states that `base` cannot hold, a field of the mfdaq block other
%   than `parameters`, a legacy identity field outside base.json's four, or a
%   depends_on entry with a `version` or another field, carries the document
%   whole as v1 ([fields outside the template are malformed], carry-100, via
%   private/jRawCarry).
%
%   See also did2.convert.migrators_j.daqreader_epochdata_ingested,
%            did2.convert.resolveEpochProbemap,
%            did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested.

arguments
    preBody (1,1) struct
end

body = jRawBody(preBody, 'daqreader_mfdaq_epochdata_ingested');
collision = dependsOnCollisions(body);
unplaced = unreadFields(preBody);
if ~isempty(collision)
    % carry-register: carry-100 (a rename-era clash: [rename clashes are malformed])
    did2.convert.reportNote('carried_as_v1', 'daqreader_mfdaq_epochdata_ingested', ...
        char(body.base.id), ['[carry-100] malformed: outside the NDI template, unplaced: ' ...
        strjoin(collision, ', ')]);
    bodies = preBody;
    return;
end
if jRawCarry('daqreader_mfdaq_epochdata_ingested', preBody, {}, unplaced, 'carry-100')
    bodies = preBody;   % [fields outside the template are malformed], carry-100
    return;
end

% handed on unchanged: v1_to_v2 stamps it did_v1 (HAND_ON_CLASSES)
bodies = preBody;
end

% ===================== the raw read ========================================

function collision = dependsOnCollisions(body)
%DEPENDSONCOLLISIONS What a depends_on entry states beyond {name, value}: its
%   `version`, or another field (did2.convert.v1read.readDependsOn). Such an
%   entry is outside the template and carries the document (carry-100).
collision = {};
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    return;
end
raw = did2.convert.v1read.readDependsOn(body);
for k = 1:numel(raw)
    if ~isempty(raw(k).version)
        collision{end+1} = sprintf('depends_on(%s).version', raw(k).name); %#ok<AGROW>
    end
    others = fieldnames(raw(k).other);
    for j = 1:numel(others)
        collision{end+1} = sprintf('depends_on(%s).%s', raw(k).name, others{j}); %#ok<AGROW>
    end
end
end

function unplaced = unreadFields(preBody)
%UNREADFIELDS What the template does not declare: a field of the mfdaq block
%   other than `parameters`; a legacy identity field outside base.json's four
%   (jRawBody keeps only those four).
unplaced = {};
blk = 'daqreader_mfdaq_epochdata_ingested';
if isfield(preBody, blk)
    sub = preBody.(blk);
    if isstruct(sub) && isscalar(sub)
        fns = fieldnames(sub);
        for k = 1:numel(fns)
            if ~strcmp(fns{k}, 'parameters')
                unplaced{end+1} = [blk '.' fns{k}]; %#ok<AGROW>
            end
        end
    elseif ~isempty(sub)
        unplaced{end+1} = blk;
    end
end
b = did2.convert.v1read.readBase(preBody);
if strcmp(b.source, 'ndi_document')
    extra = fieldnames(b.extra);
    for k = 1:numel(extra)
        unplaced{end+1} = ['ndi_document.' extra{k}]; %#ok<AGROW>
    end
end
% an `ndi_document` block beside `base` is read as `base` (Decided by Jess
% Haley, 2026-10-31 [ndi_document read as base]): what it states that `base`
% cannot hold is outside the template (carry-100)
unplaced = [unplaced, b.conflict];
lextra = fieldnames(b.legacy_extra);
for k = 1:numel(lextra)
    if ~did2.convert.isEmptyBlock(b.legacy_extra.(lextra{k}))
        unplaced{end+1} = ['ndi_document.' lextra{k}]; %#ok<AGROW>
    end
end
end
