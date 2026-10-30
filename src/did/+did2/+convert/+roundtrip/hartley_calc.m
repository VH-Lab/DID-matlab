function [v1, spec] = hartley_calc(bodies)
%HARTLEY_CALC Rebuild a v1 `hartley_calc` from what
%   did2.convert.migrators_j.hartley_calc emitted when it CONVERTED it: the
%   `receptive_field_calculation` (the source id), its two plane bodies and
%   its spike-time body (`sampled_body`), the session anchor and the software
%   entities (with their version assertions).
%
%   [V1, SPEC] = did2.convert.roundtrip.hartley_calc(BODIES). V1 is the
%   document in the shape NDIcalc-vis-matlab ndi.calc.vis.hartley writes it
%   (its stored self-test output, mock/hartley/mock.1.json, and the corpus
%   vintage: hartley_calc + hartley_reverse_correlation + reverse_correlation
%   + ngrid + app + base):
%
%     identity, `app`               calcParts (the calculator is the software;
%                                   method term EDAM:operation_2945 "Data
%                                   analysis" since [data analysis is the
%                                   general method], ndi.calc.vis.hartley before)
%     depends_on                    element_id (entity_id),
%                                   stimulus_presentation_id (input_id)
%     hartley_calc.input_parameters the method parameters other than the
%                                   stimulus sequence
%     hartley_calc.depends_on       restates the top-level element_id
%                                   (SPEC.equivalents, [restated values checked])
%     hartley_reverse_correlation
%       .reconstruction_properties  T_coords: the plane bodies' `lag`
%                                   covariate; X_coords, Y_coords: the two
%                                   other dimensions' covariates, or the index
%                                   1..n when they have none (jNgridBody writes
%                                   none for the default index vector)
%       .spiketimes                 the spike-time body's `time` covariate
%       .frameTimes, .hartley_numbers   the `stimulus sequence` parameters
%       .stimulus_properties        left unwritten only when equal to the
%                                   referenced presentation's generator
%                                   settings ([hartley leftovers checked]):
%                                   rebuilt from them
%                                   (did2.convert.stimulusPresentationSpecs, the
%                                   batch v1_to_v2 indexed), compared
%                                   orientation-insensitively (SPEC.same)
%     ngrid.data_dim                the plane's extents, then the plane count
%     ngrid.coordinates             [T; X; Y], the writer's order
%     ngrid.data_type               the calculation's source_data_type
%     ngrid.data_size               restates the data type's byte size
%                                   (SPEC.equivalents)
%     reverse_correlation.method    'Hartley', implied ([hartley method
%                                   implied]); '' restated. Implied by the
%                                   method term ndi.calc.vis.hartley before
%                                   2026-10-30; since [data analysis is the
%                                   general method] the term is the general
%                                   EDAM:operation_2945, and Hartley is implied
%                                   by the calculation being a
%                                   receptive_field_calculation, which only
%                                   hartley_calc writes
%     files                         the first plane body's, as v1 wrote them
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.hartley_calc.

arguments
    bodies cell
end

n = numel(bodies);
isBody = cellfun(@(b) strcmp(classNameOf(b), 'sampled_body'), bodies);
[v1, leaf, inputs, spec] = calcParts(bodies(~isBody), 'receptive_field_calculation', ...
    'hartley_calc', 'ndi.calc.vis.hartley');
if isempty(leaf)
    return;
end
leafId = char(getIn(leaf, 'base', 'id'));

% ---- the bodies -------------------------------------------------------------
planes = {};
planeNames = {};
spike = [];
for k = find(isBody)
    b = bodies{k};
    if ~isequal(edgeIds(b, 'owner_id'), {leafId})
        spec.unplaced{end+1} = sprintf('sampled_body %d is not owned by the calculation', k);
        continue;
    end
    [~, plane] = termParts(getIn(b, 'data_body', 'conditions', 'term'));
    if ~isempty(plane)
        planes{end+1} = b; %#ok<AGROW>
        planeNames{end+1} = plane; %#ok<AGROW>
    elseif isempty(spike)
        spike = b;
    else
        spec.unplaced{end+1} = sprintf('sampled_body %d has no role in a hartley_calc', k);
    end
end
if ~isequal(planeNames, {'response estimate', 'significance'})
    spec.unplaced{end+1} = sprintf('the plane bodies are {%s}, not the response estimate and the significance', ...
        strjoin(planeNames, ', '));
end

% ---- identity, edges ----------------------------------------------------------
entity = edgeIds(leaf, 'entity_id');
names = {'element_id'};
values = {''};
if isscalar(entity)
    values = entity;
else
    spec.unplaced{end+1} = sprintf('%d entity_id edges', numel(entity));
end
presentationId = '';
if ~isempty(inputs)
    presentationId = inputs{1};
    names{end+1} = 'stimulus_presentation_id';
    values{end+1} = presentationId;
end
for k = 2:numel(inputs)
    spec.unplaced{end+1} = sprintf('input_id %s has no v1 edge name', inputs{k});
end
v1.depends_on = struct('name', names, 'value', values);

% ---- hartley_calc: input parameters, the inner depends_on copy -----------------
hc = v1.hartley_calc;
seq = struct();
if isfield(hc, 'input_parameters') && isfield(hc.input_parameters, 'stimulus_sequence')
    seq = hc.input_parameters.stimulus_sequence;
    hc.input_parameters = rmfield(hc.input_parameters, 'stimulus_sequence');
end
v1.hartley_calc = hc;
why = ['the calculator block''s inner depends_on copy restates a top-level ' ...
    'edge ([restated values checked], Jess Haley, 2026-10-26)'];
for k = 1:numel(names)
    spec.equivalents(end+1) = struct('path', sprintf('hartley_calc.depends_on(%d).name', k), ...
        'values', {names}, 'why', why);
    spec.equivalents(end+1) = struct('path', sprintf('hartley_calc.depends_on(%d).value', k), ...
        'values', {values}, 'why', why);
end

% ---- the response volume: ngrid + reconstruction_properties --------------------
hrc = struct();
ng = struct();
if ~isempty(planes)
    [ext, coords, bad] = planeAxes(planes{1});
    spec.unplaced = [spec.unplaced, bad];
    for k = 2:numel(planes)
        [e2, c2] = planeAxes(planes{k});
        if ~isequal(e2, ext) || ~isequal(c2, coords)
            spec.unplaced{end+1} = sprintf('plane %d describes another volume', k);
        end
    end
    if numel(coords) == 3
        T = coords{1};
        X = coords{2};
        Y = coords{3};
        hrc.reconstruction_properties = struct('T_coords', T, 'X_coords', X, 'Y_coords', Y);
        ng.coordinates = [T; X; Y];
    end
    ng.data_dim = [ext(:); numel(planes)];
    for f = {'files', 'file'}
        if isfield(planes{1}, f{1})
            v1.(f{1}) = planes{1}.(f{1});
        end
    end
end
dataType = char(getIn(leaf, 'value', 'source_data_type'));
if ~isempty(dataType)
    ng.data_type = dataType;
    bytes = bytesOf(dataType);
    if ~isempty(bytes)
        spec.equivalents(end+1) = struct('path', 'ngrid.data_size', 'values', {{bytes}}, ...
            'why', 'the byte size the data type states ([restated values checked])');
    end
end

% ---- the spike times, the stimulus sequence -------------------------------------
if ~isempty(spike)
    c = asCell(getIn(spike, 'data', 'covariates'));
    if isscalar(c)
        hrc.spiketimes = column(getIn(c{1}, 'quantity', 'value'));
    else
        spec.unplaced{end+1} = 'the spike-time body has no single time covariate';
    end
end
if isstruct(seq) && isfield(seq, 'frame_times')
    hrc.frameTimes = column(seq.frame_times);
end
if isstruct(seq) && isfield(seq, 'hartley_numbers')
    hn = seq.hartley_numbers;
    fns = fieldnames(hn);
    for k = 1:numel(fns)
        hn.(fns{k}) = column(hn.(fns{k}));
    end
    hrc.hartley_numbers = hn;
end

% ---- stimulus_properties: the presentation's settings ---------------------------
KEYS = {'M', 'M'; 'L_max', 'L_absmax'; 'K_max', 'K_absmax'; 'sf_max', 'sfmax'; ...
    'fps', 'fps'; 'color_high', 'chromhigh'; 'color_low', 'chromlow'; 'rect', 'rect'};
[pspec, found] = did2.convert.stimulusPresentationSpecs('get', presentationId);
if found && isstruct(pspec)
    sp = struct();
    for k = 1:size(KEYS, 1)
        if isfield(pspec, KEYS{k, 2})
            sp.(KEYS{k, 1}) = pspec.(KEYS{k, 2});
            spec.same(end+1) = struct('path', ['hartley_reverse_correlation.stimulus_properties.' KEYS{k, 1}], ...
                'fn', @sameNumbers, 'why', ['equal to the presentation''s generator setting ' ...
                KEYS{k, 2} ' ([hartley leftovers checked]; compared as hartley_calc.m does)']);
        end
    end
    hrc.stimulus_properties = sp;
end
v1.hartley_reverse_correlation = hrc;
v1.ngrid = ng;

% ---- reverse_correlation ---------------------------------------------------------
[methodNode, method] = termParts(getIn(leaf, 'interaction', 'method', 'term'));
if strcmpi(method, 'ndi.calc.vis.hartley') || sameCurie(methodNode, 'EDAM:operation_2945')
    v1.reverse_correlation = struct('method', 'Hartley');
    spec.equivalents(end+1) = struct('path', 'reverse_correlation.method', ...
        'values', {{'Hartley', ''}}, 'why', ['implied ([hartley method implied]): ' ...
        'by the receptive_field_calculation hartley_calc writes, its method the ' ...
        'general EDAM:operation_2945 ([data analysis is the general method]; ' ...
        'the term ndi.calc.vis.hartley before); an empty one too']);
else
    spec.unplaced{end+1} = sprintf(['the method term is "%s", not ' ...
        'EDAM:operation_2945 (or ndi.calc.vis.hartley)'], method);
end
if n == 0
    spec.unplaced{end+1} = 'nothing was emitted';
end
end

% =============================================================================

function [ext, coords, bad] = planeAxes(b)
% the plane's extents in dimension order, and the coordinate vectors in the
% writer's [T; X; Y] order: the `lag` dimension, then the other two in order
bad = {};
coords = {};
dims = asCell(getIn(b, 'data', 'dimensions'));
ext = zeros(1, numel(dims));
labels = cell(1, numel(dims));
for k = 1:numel(dims)
    ext(k) = numberOf(getIn(dims{k}, 'n'));
    [~, labels{k}] = termParts(getIn(dims{k}, 'term'));
end
vals = cell(1, numel(dims));
covs = asCell(getIn(b, 'data', 'covariates'));
for k = 1:numel(covs)
    a = numberOf(getIn(covs{k}, 'along'));
    if isempty(a) || a < 0 || a >= numel(dims)
        bad{end+1} = sprintf('covariate %d is along no dimension', k); %#ok<AGROW>
        continue;
    end
    vals{a + 1} = column(getIn(covs{k}, 'quantity', 'value'));
end
for k = 1:numel(dims)
    if isempty(vals{k})
        vals{k} = (1:ext(k))';   % jNgridBody writes no covariate for 1..n
    end
end
lag = find(strcmp(labels, 'lag'));
if ~isscalar(lag) || numel(dims) ~= 3
    bad{end+1} = 'the plane is not (axis, axis, lag)';
    return;
end
others = setdiff(1:numel(dims), lag);
coords = [vals(lag), vals(others)];
end

function n = bytesOf(dataType)
% the byte size mat2ngrid stores for DATATYPE (hartley_calc.m's bytesOf)
n = [];
switch lower(strtrim(dataType))
    case {'double', 'int64', 'uint64'}
        n = 8;
    case {'single', 'int32', 'uint32'}
        n = 4;
    case {'int16', 'uint16'}
        n = 2;
    case {'int8', 'uint8', 'char', 'logical'}
        n = 1;
end
end

function tf = sameNumbers(a, b)
% numeric vectors by value, whatever their orientation; anything else exactly
if isnumeric(a) && isnumeric(b)
    tf = isequaln(double(a(:)), double(b(:)));
else
    tf = isequaln(a, b);
end
end
