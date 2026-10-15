function keys = jLightsheetKeys(axesOrder, shape, scale, translation, units, channelNames, chunks)
%JLIGHTSHEETKEYS The `keys` of a lightsheet array, one per axis it HAS.
%
%   KEYS = jLightsheetKeys(AXESORDER, SHAPE, SCALE, TRANSLATION, UNITS,
%   CHANNELNAMES, CHUNKS) builds one did2.build.key per character of AXESORDER
%   (NDI's lightsheet writers store it as the axis names joined, 'tczyx' or
%   'czyx': makePyramid.m joinAxisNames), in that order, so keys[k] IS array
%   dimension k (did-schema `data.keys`). A dimension the store does not have
%   gets no key (#73 lightsheet L1 rule 1): the key list is read off the axes
%   the document names, never padded to five.
%
%   SHAPE        per-axis extent, in AXESORDER (the writer's `shape_level0` /
%                `shape`). Must have one entry per axis, or this errors.
%   SCALE        per-axis voxel size (NGFF `scale`, the writer's `voxel_size*`),
%                in each axis's own unit. May be empty.
%   TRANSLATION  per-axis NGFF translation. Empty means 0 on every axis, which
%                is the NGFF default for an absent translation -- the format's
%                own rule, not a value invented here.
%   UNITS        cellstr, one unit name per axis ('' when the source gives none).
%   CHANNELNAMES cellstr of channel names; used as the `c` key's labels only
%                when there is exactly one per channel.
%   CHUNKS       per-axis chunk extent, or [] (a sampled_body's keys only:
%                did-schema rule key_chunk_sampled_only).
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
%   unit carries its UO node (point 10, Jess 2026-10-14: second UO:0000010;
%   meter UO:0000008). An axis whose unit is unrecognised keeps its numbers
%   and the unit NAME-ONLY, as the source spelled it (point 10); an axis with
%   no unit keeps its numbers with NO unit -- the honest "not stated" --
%   rather than borrowing one. (The SmartSPIM path
%   writes `t` and `c` with empty units: fromSPIM.m axesDesc.)
%
%   A space/time axis with no scale has no physical spacing to state, so its
%   positions are the integer indices 0..n-1, written in the REGULAR form:
%   `regular` true, origin 0, spacing 1, NO unit (Jess 2026-10-15: the same
%   positions as `values` 0..n-1, in the smaller form; the absent unit says
%   they are indices, not a measured extent). The translation is not used
%   there: with no scale it has no unit to be read in. The `c` axis is
%   categorical: its names when the source gives one per channel, else the
%   indices 0..n-1 (`values`).
%
%   Shared helper for the lightsheet migrators (+migrators_j).

axesOrder = char(axesOrder);
nAx = numel(axesOrder);
shape = double(shape(:).');
if nAx == 0 || numel(shape) ~= nAx
    error('did2:migrators_j:lightsheet:badAxes', ...
        ['The axes "%s" and the shape %s do not match: one extent per ' ...
         'axis is needed to state the array''s keys.'], axesOrder, mat2str(shape));
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

entries = cell(1, nAx);
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
            opts = {'Labels', reshape(channelNames, 1, [])};
        else
            opts = {'Values', 0:(n - 1)};
        end
    elseif isempty(scale)
        % index positions 0..n-1, regular and unit-less (Jess 2026-10-15)
        opts = {'Origin', 0, 'Spacing', 1};
    else
        [factor, canonical] = canonicalUnit(units{k}, kind);
        if isempty(canonical) && ~isempty(strtrim(char(units{k})))
            % Point 10: a unit with no unambiguous UO mapping stays NAME-ONLY,
            % as the source spelled it, with the source's own numbers. The
            % store-record pass counts these (pyramid_key_units_name_only).
            opts = {'Unit', struct('node', '', 'name', strtrim(char(units{k}))), ...
                'Origin', translation(k), 'Spacing', scale(k)};
        elseif isempty(canonical)
            opts = {'Origin', translation(k), 'Spacing', scale(k)};
        elseif factor == 1 && strcmp(units{k}, canonical)
            opts = {'Unit', unitTerm(canonical), 'Origin', translation(k), 'Spacing', scale(k)};
        else
            opts = {'Unit', unitTerm(canonical), 'SourceUnit', units{k}, ...
                'Origin', translation(k) * factor, 'Spacing', scale(k) * factor, ...
                'SourceOrigin', translation(k), 'SourceSpacing', scale(k)};
        end
    end
    if ~isempty(chunks)
        opts = [opts, {'Chunk', chunks(k)}]; %#ok<AGROW>
    end
    entries{k} = did2.build.key(variable, n, opts{:});
end
keys = did2.build.list(entries{:});
end

function t = unitTerm(name)
%UNITTERM A canonical unit name as its UO term (point 10, Jess 2026-10-14).
%   second UO:0000010 and micrometer UO:0000017 were checked on OLS by Jess;
%   meter UO:0000008 is UO's metre (the canonical length every space axis is
%   converted to). A name not in this table stays name-only.
table = {'second', 'UO:0000010'; 'micrometer', 'UO:0000017'; 'meter', 'UO:0000008'};
k = find(strcmp(table(:, 1), name), 1);
if isempty(k)
    t = struct('node', '', 'name', name);
else
    t = struct('node', table{k, 2}, 'name', name);
end
end

function [factor, canonical] = canonicalUnit(unit, kind)
%CANONICALUNIT UDUNITS-2 name (as OME-NGFF spells it) -> V_eta canonical.
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
