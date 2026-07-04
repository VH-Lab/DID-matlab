function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-I split migrator: did_v1 ontology_table_row
%   -> observation tier (1 -> N).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_zeta'.
%   Each column of the legacy open key/value table becomes its own
%   observation document, whose CLASS is chosen by the value's SHAPE (the
%   #59 axis test) -- not by the property -- and whose property identity is
%   carried on the spine `variable`, per
%   did-schema/schemas/V_zeta/conversions/from_did_v1/ontology_table_row.md:
%
%       numeric column -> a shape-typed scalar leaf (scalar_mass_observation,
%                         scalar_temperature_observation, ...) chosen by the
%                         value's DIMENSION; value as the matching typed
%                         composite; unrecognised dimension -> the
%                         generic_scalar_observation escape hatch.
%       term column    -> categorical_observation (one concrete class), value
%                         as a bound ontology_term.
%
%   The property (body weight vs brain mass) is NOT the class -- it is the
%   spine `variable`. Returns a CELL of body structs (one per column plus a
%   shared session anchor); the dispatcher lands each as its own migrated
%   document. Branch resolution is a keyword HEURISTIC seed; the per-term
%   table is finalised in discovery mode.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_table_row') || ~isstruct(preBody.ontology_table_row)
    error('did2:convert:missingBlock', ...
        'ontology_table_row body is missing the ontology_table_row property block.');
end
rows = extractRows(preBody.ontology_table_row);
if isempty(rows)
    % Unrecognised row layout: migrate the document unchanged as an
    % ontology_table_row (the class still exists in V_zeta, so it
    % validates). Splitting an unrecognised layout is a follow-up.
    bodies = {preBody};
    return;
end

% One session-relative anchor is shared by every observation from this table
% (they are all in the same session). 'during' is the honest fallback when
% the column carries no epoch and no UTC date.
anchor = makeSessionAnchor(preBody, 'during');
bodies = cell(1, numel(rows) + 1);
for k = 1:numel(rows)
    b = migrateRow(preBody, rows{k});
    b.depends_on(end+1) = struct('name', 'time_reference_1', ...
        'value', anchor.base.id);
    bodies{k} = b;
end
bodies{end} = anchor;
end

% ===================== per-row migration ===============================

function body = migrateRow(preBody, row)
node  = getCharField(row, 'ontology_name');
label = getCharField(row, 'name');
variable = struct('node', node, 'name', label);   % spine identity
hay = lower([node ' ' label]);

[isNumeric, numVal] = rowNumericValue(row);

if isNumeric
    [leafClass, shapeClass, valueStruct] = dispatchScalar(hay, row, numVal);
    body = makeScalarObservation(preBody, leafClass, shapeClass, variable, valueStruct);
else
    valueTerm = categoricalTerm(row);
    body = makeCategoricalObservation(preBody, variable, valueTerm);
end
end

function [leafClass, shapeClass, valueStruct] = dispatchScalar(hay, row, numVal)
%DISPATCHSCALAR Choose the shape-typed leaf by the value's DIMENSION. The
%   property (what was measured) rides on the spine `variable`, so a body
%   weight and a brain mass are BOTH scalar_mass_observation, told apart by
%   `variable`. Word-boundary matching only (containsAny), so "average"
%   !-> age, "encounter" !-> count.
unit = getCharField(row, 'unit');
if containsAny(hay, {'body weight', 'body mass', 'weight', 'mass'})
    leafClass = 'scalar_mass_observation'; shapeClass = 'scalar_mass';
    valueStruct = canonicalComposite('kilograms', unit, numVal);
elseif containsAny(hay, {'body length', 'length', 'tibia', 'tail length', 'snout-vent', 'body size', 'diameter'})
    leafClass = 'scalar_length_observation'; shapeClass = 'scalar_length';
    valueStruct = canonicalComposite('meters', unit, numVal);
elseif containsAny(hay, {'age', 'duration', 'latency'})
    leafClass = 'scalar_duration_observation'; shapeClass = 'scalar_duration';
    valueStruct = canonicalComposite('seconds', unit, numVal);
elseif containsAny(hay, {'organ volume', 'volume'})
    leafClass = 'scalar_volume_observation'; shapeClass = 'scalar_volume';
    valueStruct = canonicalComposite('liters', unit, numVal);
elseif containsAny(hay, {'temperature'})
    leafClass = 'scalar_temperature_observation'; shapeClass = 'scalar_temperature';
    valueStruct = canonicalComposite('celsius', unit, numVal);
elseif containsAny(hay, {'heart rate', 'respiration rate', 'respiratory rate', 'breathing rate', 'frequency', 'rate'})
    leafClass = 'scalar_frequency_observation'; shapeClass = 'scalar_frequency';
    valueStruct = canonicalComposite('hertz', unit, numVal);
elseif containsAny(hay, {'blood pressure', 'arterial pressure', 'pressure'})
    leafClass = 'scalar_pressure_observation'; shapeClass = 'scalar_pressure';
    valueStruct = canonicalComposite('mmhg', unit, numVal);
elseif containsAny(hay, {'membrane potential', 'voltage'})
    leafClass = 'scalar_voltage_observation'; shapeClass = 'scalar_voltage';
    valueStruct = canonicalComposite('volts', unit, numVal);
elseif containsAny(hay, {'current'})
    leafClass = 'scalar_current_observation'; shapeClass = 'scalar_current';
    valueStruct = canonicalComposite('amperes', unit, numVal);
elseif containsAny(hay, {'litter size', 'cell count', 'count'})
    leafClass = 'scalar_count_observation'; shapeClass = 'scalar_count';
    valueStruct = struct('value', round(numVal), ...
        'unit', struct('node', '', 'name', ''), 'approximate', false);
elseif containsAny(hay, {'body condition', 'score'})
    leafClass = 'scalar_score_observation'; shapeClass = 'scalar_score';
    valueStruct = struct('value', numVal, 'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
elseif containsAny(hay, {'concentration', 'glucose', 'cortisol', 'titer', 'titre'})
    leafClass = 'scalar_concentration_observation'; shapeClass = 'scalar_concentration';
    valueStruct = struct('source_unit', unit, 'source_value', numVal, 'approximate', false);
else
    leafClass = 'generic_scalar_observation'; shapeClass = 'generic_scalar';
    valueStruct = struct('source_unit', unit, 'source_value', numVal, 'approximate', false);
end
end

function valueTerm = categoricalTerm(row)
termValue = getCharField(row, 'value');
if isempty(termValue)
    termValue = getCharField(row, 'string_value');
end
valueTerm = struct('node', termValue, 'name', '');
end

% ===================== destination builders ============================

function body = makeScalarObservation(preBody, leafClass, shapeClass, variable, valueStruct)
body = startObservation(preBody, leafClass, {'scalar_observation', shapeClass}, variable);
body.(shapeClass) = struct('value', valueStruct);
end

function body = makeCategoricalObservation(preBody, variable, valueTerm)
% categorical_observation is a single CONCRETE class in Brainstorm I: it owns
% its `value` (ontology_term); the property observed is the spine `variable`.
body = startObservation(preBody, 'categorical_observation', {}, variable);
body.categorical_observation = struct('value', valueTerm);
end

% ===================== shared helpers ==================================

function body = startObservation(preBody, className, extraSupers, variable)
%STARTOBSERVATION Seed a V_zeta observation body: document_class header,
%   carried base (fresh id per column), subject_id, and the spine
%   `subject_interaction` block. `method` is left blank (the verb is
%   "measurement" on the observation tier and is optional); the property
%   observed is `variable`; `target_structure` is empty (whole-subject).
chain = [{'observation'}, extraSupers];
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_zeta');
body.depends_on = carrySubject(preBody);
if isfield(preBody, 'base') && isstruct(preBody.base)
    base = preBody.base;
    base.id = did.ido.unique_id();   % each column becomes its own document
    body.base = base;
end
body.subject_interaction = struct( ...
    'method', struct('node', '', 'name', ''), ...
    'variable', variable, ...
    'target_structure', {struct('node', {}, 'name', {})});
end

function deps = carrySubject(preBody)
deps = struct('name', {}, 'value', {});
subjectVal = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, 'subject_id')
            if isfield(d, 'value'); subjectVal = d.value;
            elseif isfield(d, 'document_id'); subjectVal = d.document_id; end
        end
    end
end
deps(end+1) = struct('name', 'subject_id', 'value', subjectVal);
end

function anchor = makeSessionAnchor(preBody, relation)
sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
anchor = struct();
anchor.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_zeta');
anchor.depends_on = struct('name', 'session_id', 'value', sessionId);
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
end

function comp = canonicalComposite(canonField, unit, numVal)
comp = struct(canonField, double(numVal), 'source_unit', unit, ...
    'source_value', double(numVal), 'approximate', false);
end

function rows = extractRows(block)
%EXTRACTROWS Normalise an ontology_table_row body to a cell of column structs
%   (each {ontology_name, name, value}), one per measured property.
rows = {};
if isfield(block, 'rows')
    r = block.rows;
    if iscell(r)
        rows = r(:)';
    elseif isstruct(r)
        rows = arrayfun(@(x) x, r(:)', 'UniformOutput', false);
    end
    return;
end
if isfield(block, 'variable_names')
    vars  = splitCSV(getCharField(block, 'variable_names'));
    names = splitCSV(getCharField(block, 'names'));
    nodes = splitCSV(getCharField(block, 'ontology_nodes'));
    data = struct();
    if isfield(block, 'data') && isstruct(block.data)
        data = block.data;
    end
    for i = 1:numel(vars)
        key = vars{i};
        label = ''; node = '';
        if i <= numel(names); label = names{i}; end
        if i <= numel(nodes); node = nodes{i}; end
        val = [];
        if ~isempty(key) && isfield(data, key)
            val = data.(key);
        end
        if isempty(val) || (isnumeric(val) && isscalar(val) && isnan(val))
            continue;
        end
        rows{end+1} = struct('ontology_name', node, 'name', label, 'value', val); %#ok<AGROW>
    end
    return;
end
if isfield(block, 'ontology_name') || isfield(block, 'name')
    rows = {block};   % single-row legacy shape (the block IS one row)
end
end

function parts = splitCSV(s)
parts = {};
if isempty(s)
    return;
end
raw = strsplit(char(s), ',');
parts = cellfun(@strtrim, raw, 'UniformOutput', false);
end

function [isNumeric, numVal] = rowNumericValue(row)
isNumeric = false; numVal = [];
if isfield(row, 'value')
    v = row.value;
    if isnumeric(v) && isscalar(v) && isfinite(v)
        isNumeric = true; numVal = double(v);
    end
elseif isfield(row, 'numeric_value')
    v = row.numeric_value;
    if isnumeric(v) && ~isempty(v)
        isNumeric = true; numVal = double(v(1));
    end
end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    elseif isnumeric(v) && isscalar(v)
        s = num2str(v);
    end
end
end

function tf = containsAny(hay, needles)
tf = false;
for k = 1:numel(needles)
    pat = ['\<', regexptranslate('escape', needles{k}), '\>'];
    if ~isempty(regexp(hay, pat, 'once'))
        tf = true; return;
    end
end
end
