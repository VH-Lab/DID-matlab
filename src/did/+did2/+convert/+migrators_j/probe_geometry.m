function bodies = probe_geometry(preBody)
%PROBE_GEOMETRY Brainstorm-J migrator: did_v1 probe_geometry -> one
%   length_observation PER SPATIAL AXIS about the probe-subject, plus the session
%   anchor, plus an optional probe-model term_assertion.
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
%   STILL DEFERRED, and now itemised rather than implied: `shank_id`,
%   `contact_shape` + its width/height/radius, `manufacturer`,
%   `has_planar_contour` and `contour_x`/`contour_y`. These were dropped silently
%   before and are still dropped -- carrying them needs a contact-geometry model
%   (a shape composite and a per-site shank axis), which is modelling, not repair.
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
    obs = jStartInteraction(preBody, 'length_observation', 'subject_observation', ...
        {'length'}, jOntologyTerm('', axisMap{k, 2}), subjectSrc, ~isempty(obsBodies));
    obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
    obs.length = struct('value', jMeasureArray(vals, unit));
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
    assertion = struct();
    assertion.document_class = struct('class_name', 'term_assertion', ...
        'class_version', '1.0.0', ...
        'superclasses', struct('class_name', 'subject_assertion', 'class_version', '1.0.0'), ...
        'schema_version', 'V_eta');
    assertion.depends_on = jCarrySubject(preBody, subjectSrc);
    if isfield(preBody, 'base') && isstruct(preBody.base)
        assertion.base = preBody.base;
        assertion.base.id = did.ido.unique_id();
    end
    assertion.subject_statement = struct('variable', jOntologyTerm('', 'probe model'), ...
        'storage_mode', 'inline');
    assertion.term = struct('value', jOntologyTerm('', probeModel));
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
