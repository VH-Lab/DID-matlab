function bodies = lightsheet_zarr_pyramid(preBody)
%LIGHTSHEET_ZARR_PYRAMID Brainstorm-J migrator: did_v1 lightsheetZarrPyramid ->
%   an `observation` of intensity (the lightsheet volume) of its subject, id
%   PRESERVED, plus the `software` entity that built it (and its version); it carries the
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
%      an `observation` with 'ValueKind' 'intensity' (did-schema #88: the
%      direction class listing the `intensity` mixin).
%        entity_id      <- subject_id
%        instrument_id  <- element_id (the microscope, promoted to an entity
%                          with its id preserved), when present
%        software_id    <- the software entity below (always)
%        method         <- FBbi:00000369 'selective plane illumination
%                          fluorescence microscopy' (light-sheet microscopy),
%                          for EVERY pyramid, OME-Zarr and SmartSPIM alike
%                          (Jess 2026-10-15; DECIDED below)
%        notes          <- label, the pyramid's own name for itself, kept
%                          PERMANENTLY on the observation (Jess 2026-10-15;
%                          DECIDED below). Empty label: no notes.
%        data_type      <- dtype (jDatumType), source_data_type its spelling
%        data_body      true: the values are in bodies, never inline
%      The keys are NOT on the observation. did-schema `data.keys`: "with
%      `data_body` true, each body carries the keys of its own array". They
%      go on the store body here and on each level's sampled_body.
%   2. THE SOFTWARE ENTITY, `entity` with type `software`, named for the
%      program that writes every v1 pyramid (point 5), always; plus a
%      `text_assertion` 'version' about it carrying pipeline_version when that
%      is non-empty.
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
%                       from this document), which only this document has.
%                       Carried for EVERY pyramid (point 8, Jess 2026-10-14):
%                       the pass copies the `t` unit and the channel names
%                       onto each level's sampled_body keys, and checks the
%                       z/y/x units. They become the store body's keys only
%                       for an OME-Zarr source.
%        the TAIL of statement.notes  for the store body's description:
%                       the NGFF multiscales name, appended to the label
%                       after NOTES_SEPARATOR (a newline, then
%                       '-- store body: '), as 'NGFF multiscales name
%                       "..."'. The pass splits notes at the LAST separator,
%                       leaves the label on the observation and moves the
%                       tail into the description. The label part is NOT
%                       transient; only the tail is.
%      The edge and the notes tail are carried whenever the pyramid names a
%      source (the tail only when pyramid_name is non-empty).
%      The keys reach the STORE BODY only when its dtype is an NGFF typestring -- the
%      writer-grounded sign that the source IS an OME-Zarr store. A SmartSPIM
%      pyramid's source is a folder of raw TIFF slices; point 4 (Jess
%      2026-10-14) makes it an unheld opaque_body of the observation too, in
%      the same fold, with format TIFF (EDAM:format_3591), no keys and
%      `redundant` false. The pass tells the two apart by the same NGFF rule,
%      read off the observation's value.source_data_type.
%      WITHOUT THE PASS (a bare v1_to_v2 call) the three stay on the
%      observation: the source_file_id edge, the keys, and notes reading
%      '<label><newline>-- store body: NGFF multiscales name "<name>"'.
%      Every DID-side harness and ndi.migrate.local run the pass.
%
%   Returns {observation, software, versionAssertion?}.
%
%   ---------------------------------------------------------------------
%   OPEN POINTS -- RECORDED, NOT RESOLVED (the design does not say)
%   ---------------------------------------------------------------------
%   * TIME REFERENCE -- DECIDED (Jess 2026-10-14, lightsheet point 1, option
%     A). The pyramid carries no time, and the referent a "during the
%     session" relation needs is the session DOCUMENT's id, which a
%     single-document migrator cannot know. The observation is built without
%     one (did2.build insists on time_reference_id's min_count, so a stand-in
%     id satisfies the builder and is removed straight after) and carries the
%     transient marker did2.convert.mintSessionDuring('marker');
%     did2.convert.foldGenericFiles hands it to mintSessionDuring, which mints
%     a relative_time_reference 'intervalDuring' the session document and
%     points the observation's time_reference_id at it. No session document in
%     the batch: no reference, counted (observations_without_session).
%   * SOFTWARE -- DECIDED (Jess 2026-10-14, lightsheet point 5): one
%     `software` entity named 'NDI lightsheet pyramid builder
%     (ndi.fun.doc.lightsheet.makePyramid)', always emitted, always the
%     observation's software_id; pipeline_version (the writer's tag for the
%     pyramid, makePyramid.m:28) is a text_assertion 'version' about it when
%     non-empty.
%   * `label`, `pyramid_name`, `pyramid_type` -- DECIDED (Jess 2026-10-15):
%     `label` is the observation's `notes`, permanently, with or without a
%     source and with or without the pass. `pyramid_name` (the NGFF
%     multiscales name) is the store body's `description`, as
%     'NGFF multiscales name "..."' (carried on the notes tail, moved by the
%     pass; a pyramid with no source has no store body, so it is not kept).
%     `pyramid_type` is DROPPED: it repeats the levels' summary statistic,
%     and the v1 docs say not to trust it (an earlier writer labelled mean
%     pyramids `gaussian`). `byte_order` (always 'little', and repeated on
%     every level) is carried by the levels' sampled_bodies, not here.
%   * METHOD -- DECIDED (Jess 2026-10-15): every migrated pyramid's
%     observation carries `method` FBbi:00000369 'selective plane
%     illumination fluorescence microscopy' (checked on OLS), OME-Zarr and
%     SmartSPIM alike: every v1 pyramid is a light-sheet volume. NDI
%     (ndi.vintage.lightsheetPyramidDocs) finds migrated pyramids by this
%     node, no longer by the software entity's name; the entity stays, as the
%     record of what built the pyramid.
%   * TERMS -- DECIDED (Jess 2026-10-14, lightsheet point 10, option C;
%     nodes checked on OLS): the observation's `variable` is NCIT:C184706
%     'Fluorescence Intensity' (it was the bare name 'fluorescence'); the
%     keys' canonical units are OM terms (second om:second-Time, metre
%     om:metre; Jess 2026-10-21, replacing the UO nodes), an unrecognised
%     unit stays name-only; the levels'
%     `summary statistic` values carry NCIT nodes (Maximum NCIT:C25564,
%     Arithmetic Mean NCIT:C53319). The axis names (time, channel, z, y, x)
%     and the variable 'summary statistic' stay names with no node (term
%     worksheet).
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

% ---- the software entity (point 5, Jess 2026-10-14) ------------------------
% NAMED for the program that writes every v1 pyramid, always emitted: the
% builder is known whether or not the document records a pipeline_version.
% `pipeline_version` is the writer's "tag for the pyramid" (makePyramid.m:28),
% NOT a program name, so it becomes a `text_assertion` (variable 'version')
% about this entity, the way ndi.setup.V2.entityDocuments records a software
% version -- only when it is non-empty. Software dedup across pyramids is
% NDI's resolveSoftwareDedup's job, not this migrator's.
bodies = {};
BUILDER = 'NDI lightsheet pyramid builder (ndi.fun.doc.lightsheet.makePyramid)';
software = did2.build.document('entity', ...
    struct('type', 'software', 'name', BUILDER), ...
    'SessionId', sessionId, 'CreationTimestamp', created, 'Validate', false);
softwareId = software.base.id;
pipelineVersion = strtrim(char(field(blk, 'pipeline_version', '')));
versionAssertion = [];
if ~isempty(pipelineVersion)
    % No time reference: an assertion declares no time_reference_id
    % (statement.json's depends_on is entity_id and value_id only), and
    % ndi.setup.V2.entityDocuments passes none.
    versionAssertion = did2.build.statement('assertion', softwareId, 'version', ...
        did2.build.valueCell('text', {pipelineVersion}), ...
        'SessionId', sessionId, 'CreationTimestamp', created, 'Validate', false, 'ValueKind', 'text');
end

% ---- the label, and what the store-record pass needs (header, item 3) ---
% The label stays on the observation's notes for good (Jess 2026-10-15). With
% a source, the NGFF multiscales name rides after NOTES_SEPARATOR for the pass
% to move into the store body's description. pyramid_type is dropped.
carryStore = ~isempty(sourceId);
notes = strtrim(char(field(blk, 'label', '')));
pyramidName = strtrim(char(field(blk, 'pyramid_name', '')));
if carryStore && ~isempty(pyramidName)
    notes = [notes NOTES_SEPARATOR() sprintf('NGFF multiscales name "%s"', pyramidName)];
end
carried = {};
if ~isempty(notes)
    carried = {'Notes', notes};
end
% The full-resolution keys are carried for EVERY pyramid (point 8): they hold
% the per-axis units (the `t` unit among them) and the channel names, which no
% level document has, and the batch pass copies them onto each level's keys.
% They reach the store body only for an OME-Zarr source (point 4). A pyramid
% whose axes, shape and voxel size do not agree carries none rather than
% failing: the keys are a convenience for the pass, not the observation.
axesOrder = char(field(blk, 'axes_order', ''));
try
    units = splitList(field(blk, 'axes_units', ''), numel(axesOrder));
    units = defaultSpaceUnits(units, axesOrder, char(field(blk, 'voxel_size_units', '')));
    keys = jLightsheetKeys(axesOrder, field(blk, 'shape_level0', []), ...
        field(blk, 'voxel_size_level0', []), field(blk, 'translation_level0', []), ...
        units, splitList(field(blk, 'channel_names', ''), 0), []);
    carried = [carried, {'Keys', keys}];
catch
end

% ---- the observation -------------------------------------------------------
% did2.build insists on the schema's time_reference_id min_count; there is no
% time to state (header, OPEN POINTS), so a stand-in id satisfies the builder
% and the edge is removed straight after. Nothing else about the document
% depends on it.
standIn = 'lightsheet_no_time_reference';
% Point 10 (Jess 2026-10-14, checked on OLS): the variable is NCIT's
% 'Fluorescence Intensity', replacing the bare name 'fluorescence'.
FLUORESCENCE_INTENSITY = struct('node', 'NCIT:C184706', 'name', 'Fluorescence Intensity');
% Jess 2026-10-15: every v1 pyramid is a light-sheet volume.
LIGHTSHEET_METHOD = struct('node', 'FBbi:00000369', ...
    'name', 'selective plane illumination fluorescence microscopy');
obs = did2.build.statement('observation', subjectId, FLUORESCENCE_INTENSITY, [], ...
    'Fields', struct('method', jMethod(LIGHTSHEET_METHOD)), ...   % #88: method {term, parameters}
    'DataBody', true, ...
    'DatumType', dataType, ...
    'SourceDatumType', sourceDataType, ...
    'TimeReferenceIds', {standIn}, ...
    'InstrumentId', elementId, ...
    'SoftwareId', softwareId, ...
    carried{:}, ...
    'SessionId', sessionId, 'Id', obsId, 'CreationTimestamp', created, ...
    'Validate', false, 'ValueKind', 'intensity');
keep = ~strcmp({obs.depends_on.name}, 'time_reference_id');
obs.depends_on = obs.depends_on(keep);
if carryStore
    % The v1 edge, verbatim and TRANSIENT: did2.convert.foldGenericFiles
    % follows it to the fileReference and removes it.
    obs.depends_on(end+1) = edgeEntry(obs.depends_on, 'source_file_id', sourceId);
end
% POINT 1 (Jess 2026-10-14, option A): the pyramid carries no time, so the
% observation is anchored "during the session" by the batch pass, which alone
% can find the session DOCUMENT. The TRANSIENT marker it looks for is a
% depends_on entry named did2.convert.mintSessionDuring('marker') whose value
% is this document's own id (so it can never dangle); the pass removes it on
% every path.
obs.depends_on(end+1) = edgeEntry(obs.depends_on, ...
    did2.convert.mintSessionDuring('marker'), obsId);
bodies{end+1} = obs;
bodies{end+1} = software;
if ~isempty(versionAssertion)
    bodies{end+1} = versionAssertion;
end
end

% ===================== helpers =============================================

function e = edgeEntry(deps, name, value)
% One depends_on entry shaped like the builder's own (its field names).
arguments
    deps % the depends_on struct array so far (may be empty)
    name {mustBeText}
    value {mustBeText}
end

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

function s = NOTES_SEPARATOR()
% Between the label (kept on the observation) and the text the store-record
% pass moves into the store body's description. The SAME literal is in
% did2.convert.foldGenericFiles (its own NOTES_SEPARATOR) and in NDI-matlab
% ndi.vintage.lightsheetPyramid; testMigratorsJLightsheet pins the round trip.
s = sprintf('\n-- store body: ');
end

function units = defaultSpaceUnits(units, axesOrder, voxelUnits)
% A space axis with no unit of its own takes `voxel_size_units`, which the
% writer stamps as the unit of `voxel_size_level0` (makePyramid.m). Only space
% axes: the same hard-coded 'micrometer' sits beside the t and c entries of
% voxel_size_level0, where it cannot be a length.
arguments
    units {mustBeA(units, 'cell')}
    axesOrder {mustBeText}
    voxelUnits {mustBeText}
end

for k = 1:numel(axesOrder)
    if any(axesOrder(k) == 'zyx') && isempty(units{k})
        units{k} = voxelUnits;
    end
end
end

function c = splitList(s, n)
% A writer's comma-joined list -> cellstr. N > 0 pads/keeps N entries (one per
% axis, empty entries kept); N == 0 drops empties.
arguments
    s % a comma-separated list as the v1 document stores it; char() below
    n (1,1) {mustBeNumeric}
end

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
arguments
    body (1,1) struct
    name {mustBeText}
end

b = struct();
if isfield(body, name) && isstruct(body.(name)) && isscalar(body.(name))
    b = body.(name);
end
end

function v = field(s, name, default)
arguments
    s (1,1) struct
    name {mustBeText}
    default
end

v = default;
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end

function [id, sessionId, created] = baseOf(body)
arguments
    body (1,1) struct
end

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
arguments
    body (1,1) struct
    name {mustBeText}
end

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
