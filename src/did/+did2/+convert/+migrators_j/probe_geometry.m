function bodies = probe_geometry(preBody)
%PROBE_GEOMETRY Brainstorm-J migrator: did_v1 probe_geometry -> one
%   `observation` with value kind `length` PER SPATIAL AXIS about the probe's
%   entity, plus the session anchor, plus an optional probe-model `assertion`
%   with value kind `term`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'. The
%   probe IS a `subject` (device-as-subject, D2), carried from the source
%   `probe_id` dependency -- which is the only dependency the real class has, so
%   subject resolution works from this document alone.
%
%   ---------------------------------------------------------------------
%   FIELD NAMES CORRECTED -- NOT ONE OF THE OLD ONES EXISTED
%   ---------------------------------------------------------------------
%   This migrator used to read `channel_positions`, `position_units` and
%   `probe_type`. THE REAL NDI TEMPLATE SHARES NO FIELD NAME WITH THAT AT ALL:
%
%       site_locations_leftright   per-site coordinate along X
%       site_locations_frontback   per-site coordinate along Y
%       site_locations_depth       per-site coordinate along Z
%       shank_id                   per-site shank index
%       contact_shape, contact_shape_width/_height/_radius
%       probe_model, manufacturer
%       ndim, unit, has_planar_contour, contour_x, contour_y
%
%   The old names came from DID-schema's own V_alpha snapshot (see
%   V_eta_ground_truth_plan.md). Because `channel_positions` never matched, the
%   `isempty(positions)` guard always fired and EVERY probe_geometry document was
%   carried through unconverted -- indistinguishable from a deliberate deferral,
%   which is why it went unnoticed.
%
%   WHY ONE OBSERVATION PER AXIS. The old code flattened an assumed N-by-D matrix
%   column-major into a single anonymous length array, and its own header flagged
%   that this loses which coordinate belongs to which channel. The real source is
%   not a matrix -- it is THREE ALREADY-NAMED PARALLEL ARRAYS, one per axis,
%   indexed by site (the ProbeInterface convention). Concatenating them back into
%   one anonymous array would discard naming the source hands us for free, and
%   would force an arbitrary ordering choice. So each populated axis becomes its
%   own length_observation with its own spine variable, and per-site identity
%   stays positional within each array -- the same series-as-cardinality rule
%   jMeasureArray already uses.
%
%   `unit` (e.g. 'um') applies to all three axes. `ndim` says how many axes are
%   meaningful, but it is not trusted over the data: an axis is emitted iff it is
%   actually populated, so a 2-D probe simply yields two observations.
%
%   `probe_model` (formerly read as the non-existent `probe_type`) becomes a
%   timeless `term_assertion` about the same probe-subject when non-empty.
%
%   NO HOME YET, AND NOW CARRIED: `shank_id`, `contact_shape` + its
%   width/height/radius, `manufacturer`, `has_planar_contour` and
%   `contour_x`/`contour_y`. These were dropped ("still deferred") until
%   2026-10-26; a home needs a contact-geometry model (a shape composite and a
%   per-site shank axis), which is modelling, not repair. [probe contact geometry
%   carried] (Jess Haley, 2026-10-26): a document that sets ANY of them is
%   carried whole as v1 until V2 has that model. `has_planar_contour` counts as
%   set whenever it holds a value (the NDI template default is 1 and
%   fromStruct.m writes 0), so a writer-shaped document carrying it is carried.
%
%   THE GUARD. A body carrying `channel_positions`, `position_units` or
%   `probe_type` is REJECTED BY NAME: those are V_alpha inventions, so their
%   presence means a fixture or caller was built against our schema instead of
%   the real document -- the precise mistake being corrected here.
%
%   A document with no populated site locations carries unchanged (discovery
%   fallback); the unconverted-document counter makes that visible.
arguments
    preBody (1,1) struct
end
blk = struct();
if isfield(preBody, 'probe_geometry') && isstruct(preBody.probe_geometry)
    blk = preBody.probe_geometry;
end

if isfield(blk, 'channel_positions') || isfield(blk, 'position_units') ...
        || isfield(blk, 'probe_type')
    error('did2:convert:probeGeometryInventedShape', ...
        ['probe_geometry body carries `channel_positions`/`position_units`/' ...
         '`probe_type`, which no did_v1 document has -- the real fields are ' ...
         '`site_locations_leftright`/`_frontback`/`_depth`, `unit` and ' ...
         '`probe_model`. This shape can only come from the V_alpha snapshot ' ...
         'or a fixture built against it.']);
end

% [probe contact geometry carried] (Jess Haley, 2026-10-26): no V2 home yet
unplacedNames = {'shank_id', 'contact_shape', 'contact_shape_width', ...
    'contact_shape_height', 'contact_shape_radius', 'manufacturer', ...
    'has_planar_contour', 'contour_x', 'contour_y'};
isSet = cellfun(@(f) isfield(blk, f) && ~isBlank(blk.(f)), unplacedNames);
if any(isSet)
    did2.convert.reportNote('carried_as_v1', 'probe_geometry', char(preBody.base.id), ...
        ['unplaced: ' strjoin(strcat('probe_geometry.', unplacedNames(isSet)), ', ')]);
    bodies = {preBody};
    return;
end

unit = jGetChar(blk, 'unit');
probeModel = jGetChar(blk, 'probe_model');

% the three per-site coordinate arrays, in the order NDI declares them
axisMap = { ...
    'site_locations_leftright', 'site location (left-right)'; ...
    'site_locations_frontback', 'site location (front-back)'; ...
    'site_locations_depth',     'site location (depth)'};

subjectSrc = {'probe_id', 'element_id', 'subject_id'};
anchor = jSessionAnchor(preBody, 'during');
obsBodies = {};
for k = 1:size(axisMap, 1)
    vals = numericArray(blk, axisMap{k, 1});
    if isempty(vals); continue; end
    % the first emitted body keeps the source id; later ones are siblings
    % the first observation keeps the source id (its references resolve); the
    % others are fresh
    idOpt = {};
    if isempty(obsBodies); idOpt = {'Id', char(preBody.base.id)}; end
    obs = jStatement(preBody, 'observation', jSubjectOf(preBody, subjectSrc), ...
        jLabel(axisMap{k, 2}), ...
        jQuantity('length', vals, unit, 'approximate', false), ...
        'TimeReferenceIds', {anchor.base.id}, idOpt{:}, 'ValueKind', 'length');
    obsBodies{end+1} = obs; %#ok<AGROW>
end

if isempty(obsBodies)
    bodies = {preBody};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

bodies = obsBodies;
if ~isempty(probeModel)
    % Optional probe-model assertion: a timeless subject_assertion leaf (no
    % interaction), a secondary sibling body so it mints a fresh base id.
    assertion = jStatement(preBody, 'assertion', jSubjectOf(preBody, subjectSrc), ...
        jLabel('probe model'), jLabel(probeModel), 'ValueKind', 'term');
    bodies{end+1} = assertion;
end
bodies{end+1} = anchor;
end

% ===================== local helpers ===================================

function vals = numericArray(blk, name)
%NUMERICARRAY A row vector of the named per-site coordinate array, or [].
vals = [];
if ~isfield(blk, name); return; end
v = blk.(name);
if isnumeric(v) && ~isempty(v)
    vals = double(v(:))';
end
end

function tf = isBlank(v)
%ISBLANK [] / '' / whitespace-only text / an empty cell or struct: nothing set.
tf = isempty(v) || ((ischar(v) || isstring(v)) && all(strlength(strtrim(string(v))) == 0));
end
