function bodies = daqreader_mfdaq_epochdata_ingested(preBody)
%DAQREADER_MFDAQ_EPOCHDATA_INGESTED Chunk-b/c de-encode: the mfdaq ingested cache
%   dissolves into the generic daqreader_epochdata_ingested.
%
%   The reader subtype ('mfdaq') was encoded in the CLASS NAME, but the ingested
%   epoch cache is generic; the only mfdaq-specific content is the `parameters`
%   block (per-segment sample-count cutoffs), which de-encodes onto the parent as
%   an OPTIONAL field. The `epochid` block is CARRIED THROUGH -- it is a did_v1
%   SUPERCLASS holding the epoch-id string, not a stale duplicate of a dependency
%   (there is no epochid dependency; see the note at the bottom of this file).
%   The daqreader_epochdata_ingested superclass chain is written here, from
%   the schema (did2.build.superclasses).
%
%   ---------------------------------------------------------------------
%   IT NOW DELEGATES THE EPOCH-EXTENT LIFT TO THE PARENT MIGRATOR
%   ---------------------------------------------------------------------
%   The concrete-class migrator is looked up ONCE per document, on the class name
%   the source arrives with (did2.convert.v1_to_v2/runConcreteMigrator). So
%   renaming the class here does NOT route the result through
%   +migrators_j/daqreader_epochdata_ingested.m -- and without this delegation
%   the mfdaq documents, which are the ones carrying the real .nbf.tgz recording
%   archives, would be the only members of the family whose `epochtable` never
%   became `relative_reference` documents.
%
%   RETURN SHAPE: a bare struct while the parent's guard holds (no `epoch_id`
%   edge -- every did_v1 document today), a cell of {source, references...}
%   afterwards. did2.convert.v1_to_v2 accepts either
%   (normaliseMigratorOutput), and callers that invoke this migrator function
%   directly keep getting the struct they get today.
%
%   READS RAW v1 (did2.convert.rawV1Classes; Decided by Jess Haley, 2026-10-26
%   [migrators read raw v1]): v1_to_v2 hands this migrator the document exactly
%   as v1 wrote it (NDI daqreader_mfdaq_epochdata_ingested.json +
%   daqreader_epochdata_ingested.json + epochid.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+daq/+reader/mfdaq.m ingest_epochfiles
%   writes it), identity through jRawBody. Every v1 field and where it goes;
%   did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested rebuilds the v1
%   document and testRawV1RoundTripIngested compares the two:
%
%     base.*                    -> kept (v1_to_v2 renames datestamp and makes
%                                  session_id the edge on the way out)
%     depends_on daqreader_id   -> kept, as {name, document_id}: the shape
%                                  universalRenames gave it, which the batch
%                                  passes read. An entry with a `version` or a
%                                  second, different id is carried
%                                  (carry-100, [rename clashes are malformed])
%     files.file_list, file_info -> kept (the recording archives)
%     epochid.epochid           -> kept
%     daqreader_epochdata_ingested.epochtable -> kept (lifted when an epoch
%                                  edge exists, the parent migrator)
%     daqreader_mfdaq_epochdata_ingested.parameters
%                               -> daqreader_epochdata_ingested.parameters
%
%   An `ndi_document` block beside `base` is read as `base` ([ndi_document
%   read as base], Jess Haley, 2026-10-31); a field it states that `base`
%   cannot hold carries the document (carry-100). A field of the mfdaq
%   block other than `parameters`, which the renamed path dropped without a
%   word, or a legacy identity field outside base.json's four, now carries the
%   document whole as v1 ([fields outside the template are malformed],
%   carry-100, via private/jRawCarry).

arguments
    preBody (1,1) struct
end

body = jRawBody(preBody, 'daqreader_mfdaq_epochdata_ingested');
[deps, collision] = renamedDependsOn(body);
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

v2Body = body;
if isfield(v2Body, 'depends_on')
    v2Body.depends_on = deps;
end
% the superclass list of the class this document becomes, from the schema
% (did2.build.superclasses), so the document is complete as emitted
% ([early migration pieces fixed] (2), Jess Haley, 2026-10-26: "the builder
% produces a complete document"; before, v1_to_v2's ensureClassBlocks rebuilt
% it from v1's {base, epochid, daqreader_epochdata_ingested})
v2Body.document_class.superclasses = did2.build.superclasses('daqreader_epochdata_ingested');
v2Body.document_class.class_name = 'daqreader_epochdata_ingested';
v2Body.document_class.class_version = '2.0.0';

% de-encode `parameters` from the mfdaq block onto the generic cache block.
if ~isfield(v2Body, 'daqreader_epochdata_ingested') || ...
        ~isstruct(v2Body.daqreader_epochdata_ingested)
    v2Body.daqreader_epochdata_ingested = struct();
end
if isfield(v2Body, 'daqreader_mfdaq_epochdata_ingested') && ...
        isstruct(v2Body.daqreader_mfdaq_epochdata_ingested)
    sub = v2Body.daqreader_mfdaq_epochdata_ingested;
    if isfield(sub, 'parameters')
        v2Body.daqreader_epochdata_ingested.parameters = sub.parameters;
    end
end
if isfield(v2Body, 'daqreader_mfdaq_epochdata_ingested')
    v2Body = rmfield(v2Body, 'daqreader_mfdaq_epochdata_ingested');
end

% The epochid block is KEPT. It used to be deleted here, on the premise that
% "the epoch link is the epochid dep" -- but did_v1 has NO epochid dependency.
% All three NDI ingest templates declare exactly one, `daqreader_id`, and
% `epochid` is a SUPERCLASS whose block holds the epoch-id STRING (e.g.
% 't00001'), set explicitly by both concrete writers (+ndi/+daq/+reader/image.m
% and mfdaq.m). Deleting it destroyed the only record of which epoch the
% ingested bytes belong to, and the document still validated -- the FRAGMENT
% mode no counter sees. See V_eta_6_7_walkthrough_STATE.md for the correction.

% Hand the de-encoded body to the parent migrator so the epoch clock extents are
% lifted here exactly as they are for a plain daqreader_epochdata_ingested.
bodies = did2.convert.migrators_j.daqreader_epochdata_ingested(v2Body, true);   % accounted for above
end

% ===================== the raw read ========================================

function [deps, collision] = renamedDependsOn(body)
%RENAMEDDEPENDSON depends_on as {name, document_id}, the shape the
%   universalRenames pass wrote and the batch passes read, from the raw v1
%   entries (did2.convert.v1read.readDependsOn). COLLISION lists what that pass
%   would have discarded: an entry's `version`, or a second id that differs. (The depends_on read is
%   +migrators_j/element_epoch.m's.)
deps = struct('name', {}, 'document_id', {});
collision = {};
if ~isfield(body, 'depends_on') || isempty(body.depends_on)
    if isfield(body, 'depends_on')
        deps = body.depends_on;   % an empty list stays as written, as the pass left it
    end
    return;
end
raw = did2.convert.v1read.readDependsOn(body);
for k = 1:numel(raw)
    deps(end+1) = struct('name', raw(k).name, 'document_id', raw(k).document_id); %#ok<AGROW>
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
%UNREADFIELDS What the de-encode does not read and the renamed path dropped
%   or moved where nothing reads it: a field of the mfdaq block other than
%   `parameters`; a legacy identity field outside base.json's four (jRawBody
%   keeps only those four).
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
