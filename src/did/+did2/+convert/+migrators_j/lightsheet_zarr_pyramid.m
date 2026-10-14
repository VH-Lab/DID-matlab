function bodies = lightsheet_zarr_pyramid(preBody)
%LIGHTSHEET_ZARR_PYRAMID Brainstorm-J migrator: did_v1 lightsheetZarrPyramid ->
%   an `observation` of intensity (the lightsheet volume) of its subject, id
%   PRESERVED, plus a `software` entity for `pipeline_version`; it carries the
%   `source_file_id` join a batch pass follows to make the source's
%   fileReference (OME-Zarr store or TIFF folder) the observation's unheld body.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   THE DESIGN IS NOT SIGNED. It is the #73 lightsheet walkthrough L1-L4
%   (DID-schema review/73/OPEN_ITEMS.md, section "Lightsheet OME-Zarr", walked
%   2026-09-25, agreed by jess, NO `TEAM-SIGN-OFF` line), recorded as this
%   class's `decided_targets` in DID-schema schemas/V_eta_migration_targets.json
%   (b005527). Nothing here is a team decision; it is the most literal reading
%   of that record, and the points where the record is silent are listed under
%   OPEN POINTS below rather than resolved.
%
%   ---------------------------------------------------------------------
%   WHAT THE WRITER PUTS ON THE DOCUMENT (the writer wins over the docs)
%   ---------------------------------------------------------------------
%   NDI origin/main src/ndi/+ndi/+fun/+doc/+lightsheet/makePyramid.m, the ONE
%   construction site (`session.newdocument('lightsheetZarrPyramid', ...)`):
%     label, pyramid_name, pyramid_type   from the first multiscales entry
%     axes_order    the axis names joined ('tczyx'; 'czyx' when the store has
%                   no t -- whatever ndr.format.omezarr.listPyramids reports)
%     axes_units    the per-axis NGFF units joined with ','  (fromSPIM writes
%                   ',,micrometer,micrometer,micrometer': t and c unitless)
%     channel_names, n_channels, shape_level0, voxel_size_level0 (NGFF
%                   `scale`), translation_level0, dtype, pipeline_version
%     voxel_size_units  'micrometer', hard-coded; byte_order 'little',
%                   hard-coded
%     depends_on    subject_id (always), element_id and source_file_id (only
%                   when given)
%   `dtype` is an NGFF typestring ('<u2') on the OME-Zarr path (fromOMEZarr ->
%   listPyramids reads `.zarray`) and a MATLAB class name ('uint16') on the
%   SmartSPIM path (fromSPIM.m `dtype = char(spim.dtype)`). jDatumType reads
%   both.
%
%   ---------------------------------------------------------------------
%   WHAT IT BECOMES
%   ---------------------------------------------------------------------
%   1. THE OBSERVATION (id = the pyramid's base.id, so every level's
%      `lightsheetZarrPyramid_id` edge names it and the levels' sampled_bodies
%      hang off it through `owner_id`). Built with did2.build.statement as
%      'intensity_observation' -- on a schema where the value kind is a mixin
%      that is an `observation` listing `intensity` (did2.build resolveLeaf).
%        entity_id      <- subject_id
%        instrument_id  <- element_id (the microscope, promoted to an entity
%                          with its id preserved), when present
%        software_id    <- the software entity below, when pipeline_version
%        data_type      <- dtype (jDatumType), source_data_type its spelling
%        data_body      true: the values are in bodies, never inline
%      The keys are NOT on the observation. did-schema `data.keys`: "with
%      `data_body` true, each body carries the keys of its own array". They
%      go on the store body here and on each level's sampled_body.
%   2. THE SOFTWARE ENTITY, `entity` with type `software`, named by
%      pipeline_version (the writer's only field for it). None when the field
%      is empty.
%   3. NO STORE BODY. The OME-Zarr store's body is the v1 `fileReference` the
%      pyramid's `source_file_id` names, folded by a BATCH PASS
%      (did2.convert.foldGenericFiles, its store-record half) into an UNHELD
%      `opaque_body` owned by this observation, with the fileReference's id
%      KEPT and the store recorded BY LOCATION, not ingested (#73 item 25;
%      Jess 2026-10-14, lightsheet point 3). A single-document migrator
%      cannot read the fileReference, so it CARRIES what the pass needs on
%      the observation, all three of them TRANSIENT -- the pass removes them
%      from every observation it finds them on, whether it folds or not:
%        depends_on `source_file_id`  the v1 edge, VERBATIM. No V_eta class
%                       declares it on an observation; the validator lists
%                       depends_on wholesale, so it validates, and it is the
%                       join (the resolveResponseParameters pattern: the
%                       migrator re-homes the v1 edge, the pass follows it
%                       and removes it).
%        data.keys      the full-resolution array's keys (axes / shape /
%                       voxel size / translation / units / channel names
%                       from this document), which only this document has --
%                       OME-Zarr ONLY (below).
%        statement.notes  for the body's description: label, NGFF
%                       multiscales name and type.
%      The edge and the notes are carried whenever the pyramid names a source.
%      The KEYS only when its dtype is an NGFF typestring -- the
%      writer-grounded sign that the source IS an OME-Zarr store. A SmartSPIM
%      pyramid's source is a folder of raw TIFF slices; point 4 (Jess
%      2026-10-14) makes it an unheld opaque_body of the observation too, in
%      the same fold, with format TIFF (EDAM:format_3591), no keys and
%      `redundant` false. The pass tells the two apart by the same NGFF rule,
%      read off the observation's value.source_data_type.
%      WITHOUT THE PASS (a bare v1_to_v2 call) the three stay on the
%      observation. Every DID-side harness and ndi.migrate.local run the pass.
%
%   Returns {observation, software?}.
%
%   ---------------------------------------------------------------------
%   OPEN POINTS -- RECORDED, NOT RESOLVED (the design does not say)
%   ---------------------------------------------------------------------
%   * NO TIME REFERENCE. `interaction` declares `time_reference_id` with
%     min_count 1. The pyramid carries no time at all, and the referent a
%     "during the session" relation needs is the session DOCUMENT's id, which
%     a single-document migrator cannot know (see jSessionDocId). The schema
%     cache does not enforce min_count (only did2.build does), so the
%     observation is built with a stand-in id and the edge is then REMOVED:
%     the document says nothing about time, which is the truth.
%   * `label`, `pyramid_name`, `pyramid_type` survive only as the store
%     body's `description` text (carried here in `notes`, moved by the pass);
%     `byte_order` (always 'little', and repeated on every level) is carried
%     by the levels' sampled_bodies, not here.
%   * The observation's `variable` is the name 'fluorescence' (DID-schema
%     review/73/veta_term_worksheet_73.csv row 41, a PROPOSED name with no
%     CURIE). The keys' variables and units are likewise names with no node.
%
%   STATUS: NEVER RUN LOCALLY. There is no MATLAB in the authoring container;
%   tests/+did2/+unittest/testMigratorsJLightsheet.m is the evidence, in CI.

arguments
    preBody (1,1) struct
end

blk = block(preBody, 'lightsheet_zarr_pyramid');
[obsId, sessionId, created] = baseOf(preBody);

subjectId = depValue(preBody, 'subject_id');
elementId = depValue(preBody, 'element_id');
sourceId  = depValue(preBody, 'source_file_id');

[dataType, sourceDataType] = jDatumType(field(blk, 'dtype', ''));

% ---- the software entity ---------------------------------------------------
bodies = {};
softwareId = '';
pipelineVersion = strtrim(char(field(blk, 'pipeline_version', '')));
software = [];
if ~isempty(pipelineVersion)
    software = did2.build.document('entity', ...
        struct('type', 'software', 'name', pipelineVersion), ...
        'SessionId', sessionId, 'CreationTimestamp', created, 'Validate', false);
    softwareId = software.base.id;
end

% ---- what the store-record pass needs (header, item 3) -------------------
rawDtype = char(field(blk, 'dtype', ''));
isNGFF = ~isempty(regexp(rawDtype, '^[<>|][uifcb]\d+$', 'once'));
carryStore = ~isempty(sourceId);
carried = {};
if carryStore
    carried = {'Notes', storeDescription(blk)};
end
if carryStore && isNGFF
    axesOrder = char(field(blk, 'axes_order', ''));
    units = splitList(field(blk, 'axes_units', ''), numel(axesOrder));
    units = defaultSpaceUnits(units, axesOrder, char(field(blk, 'voxel_size_units', '')));
    keys = jLightsheetKeys(axesOrder, field(blk, 'shape_level0', []), ...
        field(blk, 'voxel_size_level0', []), field(blk, 'translation_level0', []), ...
        units, splitList(field(blk, 'channel_names', ''), 0), []);
    carried = [carried, {'Keys', keys}];
end

% ---- the observation -------------------------------------------------------
% did2.build insists on the schema's time_reference_id min_count; there is no
% time to state (header, OPEN POINTS), so a stand-in id satisfies the builder
% and the edge is removed straight after. Nothing else about the document
% depends on it.
standIn = 'lightsheet_no_time_reference';
obs = did2.build.statement('intensity_observation', subjectId, 'fluorescence', [], ...
    'DataBody', true, ...
    'DatumType', dataType, ...
    'SourceDatumType', sourceDataType, ...
    'TimeReferenceIds', {standIn}, ...
    'InstrumentId', elementId, ...
    'SoftwareId', softwareId, ...
    carried{:}, ...
    'SessionId', sessionId, 'Id', obsId, 'CreationTimestamp', created, ...
    'Validate', false);
keep = ~strcmp({obs.depends_on.name}, 'time_reference_id');
obs.depends_on = obs.depends_on(keep);
if carryStore
    % The v1 edge, verbatim and TRANSIENT: did2.convert.foldGenericFiles
    % follows it to the fileReference and removes it.
    obs.depends_on(end+1) = edgeEntry(obs.depends_on, 'source_file_id', sourceId);
end
bodies{end+1} = obs;
if ~isempty(software)
    bodies{end+1} = software;
end
end

% ===================== helpers =============================================

function e = edgeEntry(deps, name, value)
% One depends_on entry shaped like the builder's own (its field names).
e = struct();
names = {'name', 'document_id'};
if ~isempty(deps) && isstruct(deps)
    names = fieldnames(deps).';
end
for k = 1:numel(names)
    e.(names{k}) = '';
end
e.name = name;
if isfield(e, 'document_id')
    e.document_id = value;
else
    e.value = value;
end
end

function d = storeDescription(blk)
% The pyramid's own words about its source; foldGenericFiles puts what the
% source IS (OME-Zarr store / folder of raw TIFF slices) in front of them.
parts = {};
label = strtrim(char(field(blk, 'label', '')));
name  = strtrim(char(field(blk, 'pyramid_name', '')));
type  = strtrim(char(field(blk, 'pyramid_type', '')));
if ~isempty(label); parts{end+1} = sprintf('label "%s"', label); end
if ~isempty(name);  parts{end+1} = sprintf('NGFF multiscales name "%s"', name); end
if ~isempty(type);  parts{end+1} = sprintf('NGFF multiscales type "%s"', type); end
d = strjoin(parts, '; ');
end

function units = defaultSpaceUnits(units, axesOrder, voxelUnits)
% A space axis with no unit of its own takes `voxel_size_units`, which the
% writer stamps as the unit of `voxel_size_level0` (makePyramid.m). Only space
% axes: the same hard-coded 'micrometer' sits beside the t and c entries of
% voxel_size_level0, where it cannot be a length.
for k = 1:numel(axesOrder)
    if any(axesOrder(k) == 'zyx') && isempty(units{k})
        units{k} = voxelUnits;
    end
end
end

function c = splitList(s, n)
% A writer's comma-joined list -> cellstr. N > 0 pads/keeps N entries (one per
% axis, empty entries kept); N == 0 drops empties.
s = char(s);
if isempty(strtrim(s))
    c = repmat({''}, 1, n);
    return;
end
c = strtrim(strsplit(s, ',', 'CollapseDelimiters', false));
if n > 0
    if numel(c) < n; c(end+1:n) = {''}; end
else
    c = c(~cellfun(@isempty, c));
end
end

function b = block(body, name)
b = struct();
if isfield(body, name) && isstruct(body.(name)) && isscalar(body.(name))
    b = body.(name);
end
end

function v = field(s, name, default)
v = default;
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end

function [id, sessionId, created] = baseOf(body)
id = ''; sessionId = ''; created = '';
if isfield(body, 'base') && isstruct(body.base)
    b = body.base;
    if isfield(b, 'id'); id = char(b.id); end
    if isfield(b, 'session_id'); sessionId = char(b.session_id); end
    if isfield(b, 'creation_timestamp') && ~isempty(b.creation_timestamp)
        created = char(b.creation_timestamp);
    elseif isfield(b, 'datestamp') && ~isempty(b.datestamp)
        created = char(b.datestamp);
    end
end
end

function v = depValue(body, name)
v = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on); return; end
for k = 1:numel(body.depends_on)
    e = body.depends_on(k);
    if ~isfield(e, 'name') || ~strcmp(e.name, name); continue; end
    if isfield(e, 'document_id') && ~isempty(e.document_id)
        v = char(e.document_id);
    elseif isfield(e, 'value') && ~isempty(e.value)
        v = char(e.value);
    end
    return;
end
end
