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
    error('did2:convert:emptyTable', ...
        'ontology_table_row has no rows to migrate.');
end

bodies = cell(1, numel(rows));
for k = 1:numel(rows)
    bodies{k} = migrateRow(preBody, rows{k}, k);
end
end

% ===================== per-row migration ===============================

function body = migrateRow(preBody, row, rowIndex)
node  = getCharField(row, 'ontology_name');
label = getCharField(row, 'name');
identity = struct('node', node, 'name', label);
hay = lower([node ' ' label]);

[isNumeric, numVal] = rowNumericValue(row);

if isNumeric
    [className, shapeClass, valueStruct] = dispatchScalar(hay, row, numVal);
    body = makeScalarObservation(preBody, rowIndex, className, shapeClass, ...
        identity, valueStruct);
else
    [className, valueTerm] = dispatchCategorical(hay, row);
    body = makeCategoricalObservation(preBody, rowIndex, className, ...
        identity, valueTerm);
end
end

function [className, shapeClass, valueStruct] = dispatchScalar(hay, row, numVal)
unit = getCharField(row, 'unit');
if containsAny(hay, {'weight', 'mass'})
    className = 'body_weight_observation'; shapeClass = 'scalar_mass';
    valueStruct = canonicalComposite('kilograms', unit, numVal);
elseif containsAny(hay, {'length', 'tibia', 'tail'})
    className = 'body_length_observation'; shapeClass = 'scalar_length';
    valueStruct = canonicalComposite('meters', unit, numVal);
elseif containsAny(hay, {'age', 'duration', 'latency'})
    className = 'age_observation'; shapeClass = 'scalar_duration';
    valueStruct = canonicalComposite('seconds', unit, numVal);
elseif containsAny(hay, {'temperature'})
    className = 'core_temperature_observation'; shapeClass = 'scalar_temperature';
    valueStruct = canonicalComposite('celsius', unit, numVal);
elseif containsAny(hay, {'heart rate', 'respiration', 'rate', 'frequency'})
    className = 'heart_rate_observation'; shapeClass = 'scalar_frequency';
    valueStruct = canonicalComposite('hertz', unit, numVal);
elseif containsAny(hay, {'pressure'})
    className = 'blood_pressure_observation'; shapeClass = 'scalar_pressure';
    valueStruct = canonicalComposite('mmhg', unit, numVal);
elseif containsAny(hay, {'litter', 'count', 'number of'})
    className = 'litter_size_observation'; shapeClass = 'scalar_count';
    valueStruct = struct('value', round(numVal), ...
        'unit', struct('node', '', 'name', ''), 'approximate', false);
elseif containsAny(hay, {'score', 'condition'})
    className = 'body_condition_observation'; shapeClass = 'scalar_score';
    valueStruct = struct('value', numVal, 'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
elseif containsAny(hay, {'concentration', 'glucose', 'cortisol', 'titer'})
    className = 'concentration_observation'; shapeClass = 'scalar_concentration';
    valueStruct = struct('source_unit', unit, 'source_value', numVal, 'approximate', false);
elseif containsAny(hay, {'volume'})
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
if containsAny(hay, {'stage', 'life cycle', 'developmental'})
    className = 'developmental_stage_observation';
elseif containsAny(hay, {'health', 'status'})
    className = 'health_status_observation';
elseif containsAny(hay, {'coat', 'pigment'})
    className = 'pigmentation_observation';
elseif containsAny(hay, {'estrous', 'estrus'})
    className = 'estrous_stage_observation';
elseif containsAny(hay, {'behavior', 'phenotype'})
    className = 'behavioral_phenotype_observation';
else
    className = 'generic_categorical_observation';
end
end

% ===================== destination builders ============================

function body = makeScalarObservation(preBody, rowIndex, className, shapeClass, identity, valueStruct)
body = startObservation(preBody, rowIndex, className, {'scalar_observation', shapeClass});
body.observation = struct('measured_property', identity, 'target_structure', {{}});
body.(shapeClass) = struct('value', valueStruct);
end

function body = makeCategoricalObservation(preBody, rowIndex, className, identity, valueTerm)
body = startObservation(preBody, rowIndex, className, ...
    {'categorical_observation', 'categorical_concept'});
body.observation = struct('measured_property', identity, 'target_structure', {{}});
% `value` lives in the block of the class that DECLARES it: the two
% overriders (developmental_stage / generic_categorical) declare their own
% value; every other categorical property class inherits it from the
% categorical_concept shape mixin, so its value lives in that block.
if any(strcmp(className, {'developmental_stage_observation', ...
        'generic_categorical_observation'}))
    valueBlock = className;
else
    valueBlock = 'categorical_concept';
end
body.(valueBlock) = struct('value', valueTerm);
end

% ===================== shared helpers ==================================

function body = startObservation(preBody, rowIndex, className, extraSupers)
chain = [{'observation'}, extraSupers];
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_epsilon');
body.depends_on = carrySubjectAndTime(preBody);
if isfield(preBody, 'base') && isstruct(preBody.base)
    base = preBody.base;
    if isfield(base, 'id') && ~isempty(base.id)
        base.id = sprintf('%s_row%02d', char(base.id), rowIndex);
    end
    body.base = base;
end
end

function deps = carrySubjectAndTime(preBody)
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
deps(end+1) = struct('name', 'time_reference_1', 'value', '');
end

function comp = canonicalComposite(canonField, unit, numVal)
comp = struct(canonField, double(numVal), 'source_unit', unit, ...
    'source_value', double(numVal), 'approximate', false);
end

function rows = extractRows(block)
%EXTRACTROWS Normalise the legacy table to a cell of row structs.
rows = {};
if isfield(block, 'rows')
    r = block.rows;
    if iscell(r)
        rows = r(:)';
    elseif isstruct(r)
        rows = arrayfun(@(x) x, r(:)', 'UniformOutput', false);
    end
elseif isfield(block, 'ontology_name') || isfield(block, 'name')
    % single-row legacy shape (the table block IS one row)
    rows = {block};
end
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
    if contains(hay, needles{k}); tf = true; return; end
end
end
