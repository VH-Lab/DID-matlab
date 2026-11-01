function bodies = probe_geometry(preBody)
%PROBE_GEOMETRY Brainstorm-J migrator: did_v1 probe_geometry -> one
%   `observation` with value kind `length` PER SPATIAL AXIS about the probe's
%   entity, each linked to the probe's one `coordinate_system`, plus that
%   coordinate system, the session anchor and an optional probe-model
%   `assertion` with value kind `term`.
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
%   THE VARIABLES AND THE FRAME. [site positions are coordinates] (Jess Haley,
%   2026-10-27, did-schema V_eta_go_forward_class_audit.md): each axis's
%   variable is the registered NCIT X-Coordinate (C44477), Y-Coordinate
%   (C44478) or Z-Coordinate (C44479) -- left-right, front-back and depth --
%   not a label of its own ('site location (left-right)' and so on until this
%   change). [site frame is a coordinate system] (Jess Haley, 2026-10-27): the
%   probe gets ONE `coordinate_system` whose `referent_id` is the probe's
%   device entity (the same id as the statements' entity_id), with axes x, y
%   and z in that order, and each site observation names it by its optional
%   `coordinate_system_id` edge. The positive directions are NDI's
%   (probe/probe_geometry_schema.json at the locked NDI-matlab `main`,
%   441530d: site_locations_leftright "Left (negative)/ right (positive) site
%   positions from facing the electrode", site_locations_frontback "Front
%   (negative)/ back (positive) ..."): x positive is right (PATO:0000367), y
%   positive is back (PATO:0001901). The axes are STATO x-axis (0000006),
%   y-axis (0000008) and z-axis (0000012). v1 states neither where zero is
%   (the template has no field for it; site_locations_depth is documented only
%   as "Depth of site positions") nor which way depth runs, so
%   `reference_point` and the z axis's `positive_direction` are left out and
%   named in the coordinate system's `base.needs_info` ([missing facts are
%   needs info], Jess Haley, 2026-10-29), one `needs_info` report note each.
%   The coordinate system is written for every converted document, with all
%   three axes, whichever axes the document populates. z-axis, right and back
%   are not yet in did-schema's term registry; did2.convert runs with the
%   TermRegistry strict mode off, so the migration writes them meanwhile.
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
%   carried whole as v1 until V2 has that model. `has_planar_contour` equal
%   to a v1 writer's own fixed default counts as NOT set ([writer default is
%   not set], Jess Haley, 2026-10-26: the default is recoverable): 1, the NDI
%   template's (src/ndi/ndi_common/database_documents/probe/probe_geometry.json:33)
%   and 0, fromStruct's (src/ndi/+ndi/+fun/+probe/+geometry/fromStruct.m:73),
%   both at NDI-matlab main 3cb19a8 (the did-schema sibling lock). Any other
%   value carries the document as before.
%
%   THE GUARD. A body carrying `channel_positions`, `position_units` or
%   `probe_type` is REJECTED BY NAME: those are V_alpha inventions, so their
%   presence means a fixture or caller was built against our schema instead of
%   the real document -- the precise mistake being corrected here.
%
%   A document with no populated site locations carries unchanged (discovery
%   fallback); the unconverted-document counter makes that visible.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI probe/probe_geometry.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +ndi/+fun/+probe/+geometry/fromStruct.m
%   writes it). Every v1 field and where it goes;
%   did2.convert.roundtrip.probe_geometry rebuilds the v1 document and
%   testRawV1RoundTripProbe compares the two:
%
%     base.id, session_id, datestamp      -> the first observation's (the
%                                            others and the assertion are
%                                            minted)
%     base.name                           -> not written (the writer leaves '')
%     depends_on probe_id                 -> each statement's entity_id, and
%                                            the coordinate system's referent_id
%     site_locations_leftright/frontback/ -> one length observation each, the
%       depth                                source values in order, variable
%                                            X-/Y-/Z-Coordinate
%     unit                                -> the source unit of every value; a
%                                            unit no length term is known for
%                                            has no place: carried
%     probe_model                         -> the probe-model assertion's term
%     ndim                                -> not written when it is 2 (fromStruct's
%                                            and the template's default, [writer
%                                            default is not set]); any other value
%                                            is carried
%     shank_id, contact_shape*, manufacturer, contour_x/_y, has_planar_contour
%                                         -> carry-001 when set (above)
%
%   fromStruct always writes shank_id (ones when the caller gives none), so
%   every writer document is carried, carry-001, as before the switch.
%
%   What the renamed path would have discarded is carried, carry-100, as
%   before. A field, block or edge no part of this migrator reads, an `ndim`
%   other than 2 and a unit with no length term (all dropped without a word on
%   the renamed path) now carry the document whole as v1 (private/jRawAccount,
%   jRawCarry; [fields outside the template are malformed], carry-100; the
%   ndim and unit values have no register row yet). Passthroughs and carries
%   return the untouched v1 source.
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

% THE RAW READ (see READS RAW v1 above). The guard above runs first, so a
% V_alpha-shaped body still fails as before rather than being carried.
TEMPLATE = {'site_locations_leftright', 'site_locations_frontback', ...
    'site_locations_depth', 'shank_id', 'contact_shape', 'contact_shape_width', ...
    'contact_shape_height', 'contact_shape_radius', 'probe_model', 'manufacturer', ...
    'ndim', 'unit', 'has_planar_contour', 'contour_x', 'contour_y'};
src = preBody;
[preBody, collision, unplacedRaw] = jRawAccount(src, struct('probe_geometry', {TEMPLATE}), ...
    {'^probe_id$', '^element_id$', '^subject_id$'});
valueReasons = {};
if isfield(blk, 'ndim') && ~isempty(blk.ndim) && ~isequal(double(blk.ndim), 2)
    % a probe with another number of dimensions is a value no NDI writer
    % produces: [values no writer produces are malformed] (Jess Haley,
    % 2026-10-27, did-schema V_eta_go_forward_class_audit.md), carry-120. (A
    % unit no length term is known for, below, is not malformed: it cites
    % carry-155, [canonical absent only as needs info], Jess Haley,
    % 2026-10-30: "A unit spelling the migrator does not recognise is carried
    % for mapping, not written without a canonical.")
    valueReasons{end+1} = '[carry-120] probe_geometry.ndim (not 2, the writer''s default)';
end
unitText = jGetChar(blk, 'unit');
if ~isempty(strtrim(unitText))
    [~, ~, unitKind] = jSourceUnit(unitText);
    if ~strcmp(unitKind, 'length')
        valueReasons{end+1} = sprintf(['[carry-155] needs_mapping: probe_geometry.unit ' ...
            '(no length unit is known for "%s"; [canonical absent only as needs info])'], unitText);
    end
end
if jRawCarry('probe_geometry', src, collision, unplacedRaw, 'carry-100', valueReasons)
    bodies = {src};
    return;
end

% [probe contact geometry carried] (Jess Haley, 2026-10-26): no V2 home yet
unplacedNames = {'shank_id', 'contact_shape', 'contact_shape_width', ...
    'contact_shape_height', 'contact_shape_radius', 'manufacturer', ...
    'has_planar_contour', 'contour_x', 'contour_y'};
isSet = cellfun(@(f) isfield(blk, f) && ~isBlank(blk.(f)), unplacedNames);
% [writer default is not set] (Jess Haley, 2026-10-26): the writers' fixed
% has_planar_contour (template 1, fromStruct 0) does not by itself carry
k = strcmp(unplacedNames, 'has_planar_contour');
if isSet(k) && isWriterDefaultContourFlag(blk.has_planar_contour)
    isSet(k) = false;
end
if any(isSet)
    % carry-register: carry-001
    did2.convert.reportNote('carried_as_v1', 'probe_geometry', char(preBody.base.id), ...
        ['[carry-001] unplaced: ' strjoin(strcat('probe_geometry.', unplacedNames(isSet)), ', ')]);
    bodies = {src};
    return;
end

unit = jGetChar(blk, 'unit');
probeModel = jGetChar(blk, 'probe_model');

% the three per-site coordinate arrays, in the order NDI declares them, and
% the NCIT coordinate each is ([site positions are coordinates])
axisMap = { ...
    'site_locations_leftright', 'NCIT:C44477', 'X-Coordinate'; ...
    'site_locations_frontback', 'NCIT:C44478', 'Y-Coordinate'; ...
    'site_locations_depth',     'NCIT:C44479', 'Z-Coordinate'};

subjectSrc = {'probe_id', 'element_id', 'subject_id'};
probeId = jSubjectOf(preBody, subjectSrc);
populated = false(1, size(axisMap, 1));
for k = 1:size(axisMap, 1)
    populated(k) = ~isempty(numericArray(blk, axisMap{k, 1}));
end

if ~any(populated)
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's V2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. Register row carry-134 covers it.
    % carry-register: carry-134
    did2.convert.reportNote('carried_as_v1', 'probe_geometry', jCarryId(src), ...
        '[carry-134] malformed: no per-site axis values, so nothing to fold ([passthrough stays v1])');
    bodies = {src};   % nothing to fold -> carry unchanged (discovery fallback)
    return;
end

anchor = jSessionAnchor(preBody, 'during');
% [site frame is a coordinate system]: the probe's one coordinate system,
% built before the observations so they can name it
frame = probeCoordinateSystem(preBody, probeId);
obsBodies = {};
for k = find(populated)
    vals = numericArray(blk, axisMap{k, 1});
    % the first observation keeps the source id (its references resolve); the
    % others are fresh
    idOpt = {};
    if isempty(obsBodies); idOpt = {'Id', char(preBody.base.id)}; end
    obs = jStatement(preBody, 'observation', probeId, ...
        did2.convert.registeredTerm(axisMap{k, 2}, axisMap{k, 3}), ...
        jQuantity('length', vals, unit, 'approximate', false), ...
        'TimeReferenceIds', {anchor.base.id}, ...
        'Edges', struct('coordinate_system_id', char(frame.base.id)), ...
        idOpt{:}, 'ValueKind', 'length');
    obsBodies{end+1} = obs; %#ok<AGROW>
end

bodies = obsBodies;
bodies{end+1} = frame;
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

function frame = probeCoordinateSystem(preBody, probeId)
%PROBECOORDINATESYSTEM The probe's own coordinate system ([site frame is a
%   coordinate system], Jess Haley, 2026-10-27): referent the probe's device
%   entity; axes x (positive right), y (positive back) and z, in that order.
%   What v1 never states -- where zero is, and which way depth runs -- is left
%   out and named in base.needs_info ([missing facts are needs info], Jess
%   Haley, 2026-10-29), with a `needs_info` report note per entry.
term = @(node, name) did2.convert.registeredTerm(node, name);
ax = { ...
    struct('axis', term('STATO:0000006', 'x-axis'), ...
        'positive_direction', term('PATO:0000367', 'right')), ...
    struct('axis', term('STATO:0000008', 'y-axis'), ...
        'positive_direction', term('PATO:0001901', 'back')), ...
    struct('axis', term('STATO:0000012', 'z-axis'))};
missing = struct( ...
    'field', {'coordinate_system.reference_point', ...
        'coordinate_system.axes(3).positive_direction'}, ...
    'reason', { ...
        ['v1 probe_geometry does not state where a probe''s coordinates are ' ...
         'zero: its template has no field for the reference point'], ...
        ['v1 probe_geometry does not state which way site_locations_depth ' ...
         'is positive: the template documents it only as "Depth of site ' ...
         'positions"']});
o = jOpts(preBody, 'Edges', struct('referent_id', char(probeId)), ...
    'NeedsInfo', missing);
frame = did2.build.document('coordinate_system', struct('axes', {ax}), o{:});
for k = 1:numel(missing)
    did2.convert.reportNote('needs_info', 'probe_geometry', char(preBody.base.id), ...
        missing(k).field);
end
end

function vals = numericArray(blk, name)
%NUMERICARRAY A row vector of the named per-site coordinate array, or [].
vals = [];
if ~isfield(blk, name); return; end
v = blk.(name);
if isnumeric(v) && ~isempty(v)
    vals = double(v(:))';
end
end

function tf = isWriterDefaultContourFlag(v)
%ISWRITERDEFAULTCONTOURFLAG True for 1 (NDI probe_geometry.json:33) or 0
%   (fromStruct.m:73), as one number or logical.
tf = (isnumeric(v) || islogical(v)) && isscalar(v) && any(double(v) == [0 1]);
end

function tf = isBlank(v)
%ISBLANK [] / '' / whitespace-only text / an empty cell or struct: nothing set.
tf = isempty(v) || ((ischar(v) || isstring(v)) && all(strlength(strtrim(string(v))) == 0));
end
