function [dims, covs] = jLightsheetAxes(axesOrder, shape, scale, translation, units, channelNames, chunks)
%JLIGHTSHEETAXES The `dimensions` and `covariates` of a lightsheet array.
%
%   [DIMS, COVS] = jLightsheetAxes(AXESORDER, SHAPE, SCALE, TRANSLATION, UNITS,
%   CHANNELNAMES, CHUNKS) builds one did2.build.dimension per character of
%   AXESORDER (NDI's lightsheet writers store it as the axis names joined,
%   'tczyx' or 'czyx': makePyramid.m joinAxisNames), in that order, so
%   dimensions[k] IS array axis k, and one did2.build.covariate along each
%   that has positions beyond its index (below), holding them (did-schema
%   data_body AMENDMENT 6, Jess
%   Haley 2026-10-22 [covariates]; one `keys` entry per axis until then: the
%   key's variable is the dimension's term AND the covariate's variable). A
%   dimension the store does not have is not written (#73 lightsheet L1 rule
%   1): the list is read off the axes the document names, never padded to
%   five. (jLightsheetKeys until 2026-10-22.)
%
%   SHAPE        per-axis extent, in AXESORDER (the writer's `shape_level0` /
%                `shape`). Must have one entry per axis, or this errors.
%   SCALE        per-axis voxel size (NGFF `scale`, the writer's `voxel_size*`),
%                in each axis's own unit. May be empty.
%   TRANSLATION  per-axis NGFF translation. Empty means 0 on every axis, which
%                is the NGFF default for an absent translation -- the format's
%                own rule, not a value invented here.
%   UNITS        cellstr, one unit name per axis ('' when the source gives none).
%   CHANNELNAMES cellstr of channel names; used as the `c` covariate's `term`
%                only when there is exactly one per channel.
%   CHUNKS       per-axis chunk extent, or [] (a sampled_body's dimensions
%                only: did-schema rule dimension_chunk_sampled_only).
%
%   THE VARIABLES ARE NAMES WITH NO NODE: 'time', 'channel', 'z', 'y', 'x' --
%   the proposed names of DID-schema review/73/veta_term_worksheet_73.csv rows
%   17-21, none of which has a CURIE yet. They are passed to did2.build as
%   names, so they reach the document as {name} with no node.
%
%   UNITS ARE CONVERTED TO V_eta's CANONICAL ONES (`meter`, `second`) when the
%   source unit is one of the UDUNITS-2 names OME-NGFF allows for a space or
%   time axis; origin/spacing then carry the canonical numbers and
%   source_origin/source_spacing/source_unit the source's own. The canonical
%   unit is its OM term (Jess 2026-10-21: units are OM terms, consistent with
%   DID-schema's term registry: second om:second-Time, metre om:metre; this
%   replaces point 10's UO nodes). An axis whose unit is unrecognised keeps its numbers
%   and the unit NAME-ONLY, as the source spelled it (point 10); an axis with
%   no unit keeps its numbers with NO unit -- the honest "not stated" --
%   rather than borrowing one. (The SmartSPIM path
%   writes `t` and `c` with empty units: fromSPIM.m axesDesc.)
%
%   A space/time axis with no scale has no physical spacing to state, so its
%   positions are only the integer indices 0..n-1, and a channel axis without
%   one name per channel has only its indices too. Such an axis is a BARE
%   dimension with NO covariate (Jess Haley 2026-10-22 [covariate rules
%   named], 6.2a: "a covariate that only repeats its dimension's positions
%   0..n-1 is not written"; [bare dimension]). Until then they were written
%   as origin 0, spacing 1, no unit (Jess 2026-10-15) and as `quantity`
%   0..n-1 (the channel). The translation is not used there: with no scale it
%   has no unit to be read in. The `c` axis with names is categorical: its
%   names, as `term`.
%
%   Shared helper for the lightsheet migrators (+migrators_j).

arguments
    axesOrder {mustBeText}
    shape {mustBeNumeric}
    scale {mustBeNumeric}
    translation {mustBeNumeric}
    units {mustBeA(units, 'cell')}
    channelNames {mustBeA(channelNames, 'cell')}
    chunks {mustBeNumeric}
end

axesOrder = char(axesOrder);
nAx = numel(axesOrder);
shape = double(shape(:).');
if nAx == 0 || numel(shape) ~= nAx
    error('did2:migrators_j:lightsheet:badAxes', ...
        ['The axes "%s" and the shape %s do not match: one extent per ' ...
         'axis is needed to state the array''s dimensions.'], axesOrder, mat2str(shape));
end
scale = double(scale(:).');
translation = double(translation(:).');
if isempty(translation)
    translation = zeros(1, nAx);
end
if ~isempty(scale) && numel(scale) ~= nAx
    error('did2:migrators_j:lightsheet:badAxes', ...
        'The voxel size %s has %d entries for %d axes "%s".', ...
        mat2str(scale), numel(scale), nAx, axesOrder);
end
if numel(translation) ~= nAx
    error('did2:migrators_j:lightsheet:badAxes', ...
        'The translation %s has %d entries for %d axes "%s".', ...
        mat2str(translation), numel(translation), nAx, axesOrder);
end
if ~isempty(chunks)
    chunks = double(chunks(:).');
    if numel(chunks) ~= nAx
        error('did2:migrators_j:lightsheet:badAxes', ...
            'The chunk shape %s has %d entries for %d axes "%s".', ...
            mat2str(chunks), numel(chunks), nAx, axesOrder);
    end
end
if numel(units) < nAx
    units(end+1:nAx) = {''};
end

dimList = cell(1, nAx);
covList = {};
for k = 1:nAx
    n = shape(k);
    opts = {};
    switch axesOrder(k)
        case 't'
            variable = 'time';
            kind = 'time';
        case 'c'
            variable = 'channel';
            kind = 'channel';
        case {'z', 'y', 'x'}
            variable = axesOrder(k);
            kind = 'space';
        otherwise
            error('did2:migrators_j:lightsheet:badAxes', ...
                'Axis "%s" of "%s" is not one of t, c, z, y, x.', ...
                axesOrder(k), axesOrder);
    end
    if strcmp(kind, 'channel')
        if numel(channelNames) == n && n > 0
            opts = {'Term', reshape(channelNames, 1, [])};
        end   % else only the indices 0..n-1: no covariate (6.2a)
    elseif isempty(scale)
        % only the indices 0..n-1 (Jess 2026-10-15): no covariate (6.2a)
        opts = {};
    else
        [factor, canonical] = canonicalUnit(units{k}, kind);
        if isempty(canonical) && ~isempty(strtrim(char(units{k})))
            % Point 10: a unit with no unambiguous OM mapping stays NAME-ONLY,
            % as the source spelled it, with the source's own numbers. The
            % store-record pass counts these (pyramid_key_units_name_only).
            opts = {'Unit', struct('node', '', 'name', strtrim(char(units{k}))), ...
                'Origin', translation(k), 'Spacing', scale(k)};
        elseif isempty(canonical)
            opts = {'Origin', translation(k), 'Spacing', scale(k)};
        elseif factor == 1 && strcmp(units{k}, canonical)
            opts = {'Unit', unitTerm(canonical), 'Origin', translation(k), 'Spacing', scale(k)};
        else
            opts = {'Unit', unitTerm(canonical), 'SourceUnit', sourceUnitOf(units{k}), ...
                'Origin', translation(k) * factor, 'Spacing', scale(k) * factor, ...
                'SourceOrigin', translation(k), 'SourceSpacing', scale(k)};
        end
    end
    dimOpts = {};
    if ~isempty(chunks)
        dimOpts = {'Chunk', chunks(k)};
    end
    dimList{k} = did2.build.dimension(variable, n, dimOpts{:});
    % An axis WITH a voxel size keeps its covariate even when it reads 0, 1,
    % ... with no unit (scale 1, no translation): the source stated that
    % spacing, and its unit may be stated elsewhere -- a level's `t` takes
    % the pyramid's `second` (point 8, foldGenericFiles). Only the axes with
    % no stated positions at all are bare.
    if ~isempty(opts)
        covList{end+1} = did2.build.covariate(variable, k - 1, opts{:}); %#ok<AGROW>
    end
end
dims = did2.build.list(dimList{:});
covs = [];
if ~isempty(covList)
    covs = did2.build.list(covList{:});
end
end

function t = unitTerm(name)
%UNITTERM A unit spelling (OME-NGFF / UDUNITS-2) as its OM term.
%   Jess 2026-10-21: units are OM (Ontology of units of Measure 2.0) terms,
%   consistent with DID-schema's term registry; this replaces point 10's UO
%   nodes. Each node is the OM IRI's local name under the `om:` prefix and
%   each name is that element's English rdfs:label in om-2.0.rdf, so the
%   name is OM's spelling ('metre'), not the source's ('meter'). The table
%   covers every spelling canonicalUnit accepts, so a converted axis's
%   source unit is a term too. The lookup ignores case and surrounding
%   space, as canonicalUnit does. A spelling not in the table stays
%   name-only, as the source spelled it.
arguments
    name {mustBeText}
end

name = strtrim(char(name));
table = { ...
    'angstrom',    'om:angstrom',        'angstrom'; ...
    'nanometer',   'om:nanometre',       'nanometre'; ...
    'micrometer',  'om:micrometre',      'micrometre'; ...
    'millimeter',  'om:millimetre',      'millimetre'; ...
    'centimeter',  'om:centimetre',      'centimetre'; ...
    'meter',       'om:metre',           'metre'; ...
    'nanosecond',  'om:nanosecond-Time', 'nanosecond'; ...
    'microsecond', 'om:microsecond-Time','microsecond'; ...
    'millisecond', 'om:millisecond-Time','millisecond'; ...
    'second',      'om:second-Time',     'second'; ...
    'minute',      'om:minute-Time',     'minute'; ...
    'hour',        'om:hour',            'hour'};
k = find(strcmp(table(:, 1), lower(name)), 1);
if isempty(k)
    t = struct('node', '', 'name', name);
else
    t = struct('node', table{k, 2}, 'name', table{k, 3});
end
end

function u = sourceUnitOf(spelling)
%SOURCEUNITOF The source's unit in the shape the schema declares source_unit.
%   char (did-schema main, v_eta-pre73): the spelling, as before. A term
%   (DID-schema V_eta_source_unit_plan.md, signed 2026-10-21; did2.build
%   refuses text there): the spelling's term as unitTerm maps it, else the
%   spelling as the name with an empty node -- the plan's item 4 for a
%   migrated spelling, which the term registry check then reports.
arguments
    spelling {mustBeText}
end

spelling = strtrim(char(spelling));
if did2.schema.cache.shared().sourceUnitIsTerm()
    u = unitTerm(spelling);
else
    u = spelling;
end
end

function [factor, canonical] = canonicalUnit(unit, kind)
%CANONICALUNIT UDUNITS-2 name (as OME-NGFF spells it) -> V_eta canonical.
arguments
    unit {mustBeText}
    kind {mustBeText}
end

factor = 1;
canonical = '';
unit = lower(strtrim(char(unit)));
if isempty(unit); return; end
switch kind
    case 'space'
        names = {'angstrom', 'nanometer', 'micrometer', 'millimeter', ...
                 'centimeter', 'meter'};
        factors = [1e-10, 1e-9, 1e-6, 1e-3, 1e-2, 1];
        canonicalName = 'meter';
    case 'time'
        names = {'nanosecond', 'microsecond', 'millisecond', 'second', ...
                 'minute', 'hour'};
        factors = [1e-9, 1e-6, 1e-3, 1, 60, 3600];
        canonicalName = 'second';
    otherwise
        return;
end
idx = find(strcmp(unit, names), 1);
if isempty(idx); return; end
factor = factors(idx);
canonical = canonicalName;
end
