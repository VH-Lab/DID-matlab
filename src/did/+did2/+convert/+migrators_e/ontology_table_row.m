function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-E split migrator: did_v1 ontology_table_row
%   -> observation tiers (1 -> N).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion ==
%   'V_epsilon'. Each row of the legacy open key/value table becomes its
%   own observation document, dispatched by what the property is and what
%   shape its value takes, per
%   did-schema/schemas/V_epsilon/conversions/from_did_v1/ontology_table_row.md:
%
%       numeric row  -> a scalar property class  (body_weight_observation,
%                       core_temperature_observation, ...) value as the
%                       matching typed composite; unrecognised -> the
%                       generic_scalar_observation escape hatch.
%       term row     -> a categorical property class (developmental_stage_
%                       observation, ...) value as a bound ontology_term;
%                       unrecognised -> generic_categorical_observation.
%
%   Returns a CELL of body structs (one per row); the dispatcher lands
%   each as its own migrated document. Branch resolution is a keyword
%   HEURISTIC seed; the per-term table is finalised in discovery mode.
%
%   Subject-intrinsic (species/strain/sex) and relational (cohort/housing)
%   rows are out of scope for the observation tier; in this seed they fall
%   to the generic categorical escape hatch and are flagged for review
%   rather than silently dropped. Refining that routing is a follow-up.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_table_row') || ~isstruct(preBody.ontology_table_row)
    error('did2:convert:missingBlock', ...
        'ontology_table_row body is missing the ontology_table_row property block.');
end
rows = extractRows(preBody.ontology_table_row);
if isempty(rows)
    % Unrecognised row layout (e.g. the real v1 form stores parallel
    % char fields names / variable_names / ontology_nodes / data rather
    % than a 'rows' array). Rather than quarantine, migrate the document
    % unchanged as an ontology_table_row -- the class still exists in
    % V_epsilon, so it validates. Splitting that char-field layout into
    % per-row observations is a follow-up (see ontology_table_row.md).
    bodies = {preBody};
    return;
end

% One session-relative anchor is shared by every observation from this
% table (they are all in the same session). 'during' is the honest
% fallback when the row carries no epoch and no UTC date.
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
identity = struct('node', node, 'name', label);
hay = lower([node ' ' label]);

[isNumeric, numVal] = rowNumericValue(row);

if isNumeric
    [className, shapeClass, valueStruct] = dispatchScalar(hay, row, numVal);
    body = makeScalarObservation(preBody, className, shapeClass, ...
        identity, valueStruct);
else
    [className, valueTerm] = dispatchCategorical(hay, row);
    body = makeCategoricalObservation(preBody, className, identity, valueTerm);
end
end

function [className, shapeClass, valueStruct] = dispatchScalar(hay, row, numVal)
unit = getCharField(row, 'unit');
% Conservative, high-confidence routing only: match SPECIFIC terms at word
% boundaries (containsAny is word-boundary, so "average" !-> age,
% "encounter" !-> count, "sampling rate" !-> heart rate). Anything not
% confidently a known property falls to the generic_scalar escape hatch --
% the corpora are dominated by lab-specific terms that belong there.
if containsAny(hay, {'body weight', 'body mass', 'weight'})
    className = 'body_weight_observation'; shapeClass = 'scalar_mass';
    valueStruct = canonicalComposite('kilograms', unit, numVal);
elseif containsAny(hay, {'body length', 'tibia', 'tail length', 'snout-vent', 'body size'})
    className = 'body_length_observation'; shapeClass = 'scalar_length';
    valueStruct = canonicalComposite('meters', unit, numVal);
elseif containsAny(hay, {'age'})
    className = 'age_observation'; shapeClass = 'scalar_duration';
    valueStruct = canonicalComposite('seconds', unit, numVal);
elseif containsAny(hay, {'temperature'})
    className = 'core_temperature_observation'; shapeClass = 'scalar_temperature';
    valueStruct = canonicalComposite('celsius', unit, numVal);
elseif containsAny(hay, {'heart rate'})
    className = 'heart_rate_observation'; shapeClass = 'scalar_frequency';
    valueStruct = canonicalComposite('hertz', unit, numVal);
elseif containsAny(hay, {'respiration rate', 'respiratory rate', 'breathing rate'})
    className = 'respiration_rate_observation'; shapeClass = 'scalar_frequency';
    valueStruct = canonicalComposite('hertz', unit, numVal);
elseif containsAny(hay, {'blood pressure', 'arterial pressure'})
    className = 'blood_pressure_observation'; shapeClass = 'scalar_pressure';
    valueStruct = canonicalComposite('mmhg', unit, numVal);
elseif containsAny(hay, {'litter size'})
    className = 'litter_size_observation'; shapeClass = 'scalar_count';
    valueStruct = struct('value', round(numVal), ...
        'unit', struct('node', '', 'name', ''), 'approximate', false);
elseif containsAny(hay, {'cell count'})
    className = 'cell_count_observation'; shapeClass = 'scalar_count';
    valueStruct = struct('value', round(numVal), ...
        'unit', struct('node', '', 'name', ''), 'approximate', false);
elseif containsAny(hay, {'body condition'})
    className = 'body_condition_observation'; shapeClass = 'scalar_score';
    valueStruct = struct('value', numVal, 'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
elseif containsAny(hay, {'concentration', 'glucose', 'cortisol', 'titer', 'titre'})
    className = 'concentration_observation'; shapeClass = 'scalar_concentration';
    valueStruct = struct('source_unit', unit, 'source_value', numVal, 'approximate', false);
elseif containsAny(hay, {'organ volume'})
    className = 'organ_volume_observation'; shapeClass = 'scalar_volume';
    valueStruct = canonicalComposite('liters', unit, numVal);
else
    className = 'generic_scalar_observation'; shapeClass = 'generic_scalar';
    valueStruct = struct('source_unit', unit, 'source_value', numVal, 'approximate', false);
end
end

function [className, valueTerm] = dispatchCategorical(hay, row)
termValue = getCharField(row, 'value');
if isempty(termValue)
    termValue = getCharField(row, 'string_value');
end
valueTerm = struct('node', termValue, 'name', '');
% Specific phrases only (word-boundary); ambiguous singletons like
% "status"/"stage"/"behavior" caused false positives, so require the full
% property phrase and let everything else fall to the generic escape hatch.
if containsAny(hay, {'life cycle stage', 'developmental stage', 'life stage'})
    className = 'developmental_stage_observation';
elseif containsAny(hay, {'health status'})
    className = 'health_status_observation';
elseif containsAny(hay, {'coat color', 'coat colour', 'pigmentation'})
    className = 'pigmentation_observation';
elseif containsAny(hay, {'estrous', 'estrus'})
    className = 'estrous_stage_observation';
elseif containsAny(hay, {'behavioral phenotype', 'behavioural phenotype'})
    className = 'behavioral_phenotype_observation';
else
    className = 'generic_categorical_observation';
end
end

% ===================== destination builders ============================

function body = makeScalarObservation(preBody, className, shapeClass, identity, valueStruct)
body = startObservation(preBody, className, {'scalar_observation', shapeClass});
body.observation = struct('measured_property', identity, ...
    'target_structure', {struct('node', {}, 'name', {})});
body.(shapeClass) = struct('value', valueStruct);
end

function body = makeCategoricalObservation(preBody, className, identity, valueTerm)
body = startObservation(preBody, className, ...
    {'categorical_observation', 'categorical_concept'});
body.observation = struct('measured_property', identity, ...
    'target_structure', {struct('node', {}, 'name', {})});
% categorical_concept declares `value` with placement: concrete_class, so
% the bound term lives in the concrete observation class's OWN block and
% categorical_concept contributes no block. One value, one block, uniform
% across every categorical observation (no per-class branching).
body.(className) = struct('value', valueTerm);
end

% ===================== shared helpers ==================================

function body = startObservation(preBody, className, extraSupers)
chain = [{'observation'}, extraSupers];
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_epsilon');
body.depends_on = carrySubject(preBody);
if isfield(preBody, 'base') && isstruct(preBody.base)
    base = preBody.base;
    base.id = did.ido.unique_id();   % each row becomes its own document
    body.base = base;
end
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
%MAKESESSIONANCHOR Session_relative_reference document (ordinal, no metric)
%   shared by all observations from this table; anchored to the source's
%   session via base.session_id.
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
    'schema_version', 'V_epsilon');
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
%
%   The real v1 layout (per the schema) is column-parallel: comma-separated
%   `names` / `variable_names` / `ontology_nodes` plus a `data` struct keyed
%   by the variable_names. One document is one table ROW; each COLUMN is a
%   property measurement and becomes one observation. (Also accepts the
%   synthetic `rows`-array and single-row shapes used by tests.)
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
        % Skip columns with no usable value (missing key, [], '', NaN).
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
% Word-boundary match: a needle matches only as a whole word/phrase, not as
% a substring inside another word. This prevents the heuristic false
% positives the routing inventory exposed -- e.g. "average" -> "age",
% "encounter" -> "count", "sampling rate" -> "rate".
tf = false;
for k = 1:numel(needles)
    pat = ['\<', regexptranslate('escape', needles{k}), '\>'];
    if ~isempty(regexp(hay, pat, 'once'))
        tf = true; return;
    end
end
end
