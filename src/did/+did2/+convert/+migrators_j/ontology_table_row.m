function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-J split migrator: did_v1 ontology_table_row
%   -> the subject_statement tier (1 -> N).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Each column of the legacy open key/value table becomes its own statement,
%   classified by TIMELESSNESS then by the value's SHAPE (see
%   did-schema/schemas/V_eta_migration_plan.md Part D and
%   V_eta_discovery_notes.md):
%
%     timeless fact  -> a subject_assertion leaf
%                         species/sex/strain/genotype -> term_assertion
%                         date of birth / a timestamp -> date_assertion
%     timed measure  -> a subject_observation leaf, class by value SHAPE:
%                         numeric -> a data-type leaf (<dim>_observation), the
%                                    dimension chosen from the property term;
%                                    unrecognised a.u. -> intensity_observation
%                                    (J's one dimensionless numeric; NO generic
%                                    escape hatch, D8)
%                         string  -> term_observation (bound term value)
%     identity col   -> skipped (SubjectLocalIdentifier/DocumentIdentifier IS
%                         the subject, not a measurement)
%
%   Brainstorm J puts identity on the spine `variable` (owned by
%   subject_statement), the verb on subject_interaction.method, and the
%   per-sample cadence in subject_interaction.sample_time (D1). Returns a CELL
%   of body structs (one per kept column + a shared session anchor for the
%   observations); the dispatcher lands each as its own document. Dispatch is a
%   keyword heuristic seeded from the Dab (fear-potentiated-startle / EPM) and
%   JH (C. elegans) corpora; the per-term table is finalised in discovery mode.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_table_row') || ~isstruct(preBody.ontology_table_row)
    error('did2:convert:missingBlock', ...
        'ontology_table_row body is missing the ontology_table_row property block.');
end
rows = extractRows(preBody.ontology_table_row);
if isempty(rows)
    % Unrecognised layout: carry the document unchanged (the class still exists
    % for discovery-mode fallback) rather than quarantining.
    bodies = {preBody};
    return;
end

anchor = makeSessionAnchor(preBody, 'during');
bodies = {};
usedAnchor = false;
for k = 1:numel(rows)
    [b, isObservation] = migrateRow(preBody, rows{k});
    if isempty(b)
        continue;   % skipped column (identity, empty)
    end
    if isObservation
        b.depends_on(end+1) = struct('name', 'time_reference_1', ...
            'value', anchor.base.id);
        usedAnchor = true;
    end
    bodies{end+1} = b; %#ok<AGROW>
end
if usedAnchor
    bodies{end+1} = anchor;
end
if isempty(bodies)
    bodies = {preBody};   % every column skipped -> carry unchanged
end
end

% ===================== per-row migration ===============================

function [body, isObservation] = migrateRow(preBody, row)
node  = getCharField(row, 'ontology_name');
label = getCharField(row, 'name');
variable = struct('node', node, 'name', label);
hay = lower([node ' ' label]);
body = []; isObservation = false;

% identity columns are the subject itself, not a measurement
if containsAny(hay, {'local identifier', 'localidentifier', ...
        'document identifier', 'documentidentifier', 'subject id'})
    return;
end

[isNumeric, numVal] = rowNumericValue(row);

% timeless facts -> assertions (no act, optional time)
if containsAny(hay, {'species', 'sex', 'strain', 'genotype', 'taxon'})
    body = makeTermAssertion(preBody, variable, valueTerm(row));
    return;
elseif containsAny(hay, {'date of birth', 'birth date', 'dob'})
    body = makeDateAssertion(preBody, variable, row);
    return;
elseif ~isNumeric && looksLikeTimestamp(getCharField(row, 'value'))
    body = makeDateAssertion(preBody, variable, row);
    return;
end

% timed measurements -> observations
isObservation = true;
if isNumeric
    [leafClass, shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal);
    body = makeNumericObservation(preBody, leafClass, shapeClass, variable, valueStruct);
else
    body = makeTermObservation(preBody, variable, valueTerm(row));
end
end

function [leafClass, shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal)
%DISPATCHNUMERIC Choose the data-type leaf by the property's DIMENSION. The
%   property rides on the spine `variable`; word-boundary matching only.
unit = getCharField(row, 'unit');
if containsAny(hay, {'body weight', 'body mass', 'weight', 'mass'})
    leafClass = 'mass_observation'; shapeClass = 'mass';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'radius', 'body length', 'length', 'diameter', 'distance', 'size'})
    leafClass = 'length_observation'; shapeClass = 'length';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'sampling rate', 'heart rate', 'respiration rate', 'frequency', 'rate'})
    leafClass = 'frequency_observation'; shapeClass = 'frequency';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'deceleration', 'acceleration'})
    leafClass = 'acceleration_observation'; shapeClass = 'acceleration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'velocity', 'speed'})
    leafClass = 'velocity_observation'; shapeClass = 'velocity';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'onset time', 'offset time', 'age', 'duration', 'latency', 'time'})
    leafClass = 'duration_observation'; shapeClass = 'duration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'volume'})
    leafClass = 'volume_observation'; shapeClass = 'volume';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'temperature'})
    leafClass = 'temperature_observation'; shapeClass = 'temperature';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'pressure'})
    leafClass = 'pressure_observation'; shapeClass = 'pressure';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'voltage', 'membrane potential'})
    leafClass = 'voltage_observation'; shapeClass = 'voltage';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'current'})
    leafClass = 'current_observation'; shapeClass = 'current';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'concentration', 'density', 'titer', 'titre', 'glucose'})
    leafClass = 'concentration_observation'; shapeClass = 'concentration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'number of', 'count', 'entries', 'trial number', 'identifier', 'samples'})
    leafClass = 'count_observation'; shapeClass = 'count';
    valueStruct = struct('value', round(numVal), 'unit', ...
        struct('node', '', 'name', ''), 'approximate', false);
elseif containsAny(hay, {'percent', 'probability', 'circularity', 'score', 'condition'})
    leafClass = 'score_observation'; shapeClass = 'score';
    valueStruct = struct('value', numVal, 'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
else
    % J §7: intensity is the one dimensionless numeric (a.u.) -- the home for
    % amplitudes / fluorescence / ratios / unrecognised numerics. No generic
    % escape hatch (D8); a genuinely mis-dimensioned value is caught in
    % discovery-mode review, not silently dropped.
    leafClass = 'intensity_observation'; shapeClass = 'intensity';
    valueStruct = sourceCell(unit, numVal);
end
end

% ===================== destination builders ============================

function body = makeNumericObservation(preBody, leafClass, shapeClass, variable, valueStruct)
body = startStatement(preBody, leafClass, {'subject_observation', shapeClass}, variable);
body.subject_interaction = interactionBlock();
body.subject_observation = struct();
body.(shapeClass) = struct('value', valueStruct);
end

function body = makeTermObservation(preBody, variable, valueT)
body = startStatement(preBody, 'term_observation', {'subject_observation'}, variable);
body.subject_interaction = interactionBlock();
body.subject_observation = struct();
body.term_observation = struct('value', valueT);
end

function body = makeTermAssertion(preBody, variable, valueT)
body = startStatement(preBody, 'term_assertion', {'subject_assertion'}, variable);
body.term_assertion = struct('value', valueT);
end

function body = makeDateAssertion(preBody, variable, row)
body = startStatement(preBody, 'date_assertion', {'subject_assertion'}, variable);
raw = getCharField(row, 'value');
body.date_assertion = struct('value', ...
    struct('instant', raw, 'precision', 'second', 'source', raw));
end

% ===================== shared helpers ==================================

function body = startStatement(preBody, className, supersChain, variable)
%STARTSTATEMENT Seed a V_eta statement body: document_class header, a fresh
%   base id, the carried subject_id, and the subject_statement block (variable
%   + storage_mode). The caller adds the subject_interaction block (for
%   interactions) and the leaf value block.
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(supersChain)
    supers(end+1) = struct('class_name', supersChain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_eta');
body.depends_on = carrySubject(preBody);
if isfield(preBody, 'base') && isstruct(preBody.base)
    base = preBody.base;
    base.id = did.ido.unique_id();   % each column becomes its own document
    body.base = base;
end
body.subject_statement = struct('variable', variable, 'storage_mode', 'inline');
end

function blk = interactionBlock()
% method optional (the observation verb is "measurement"); the cadence is a
% single point (one reading), per D1.
blk = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
end

function c = sourceCell(unit, numVal)
c = struct('source_unit', char(unit), 'source_value', double(numVal), ...
    'approximate', false);
end

function valueT = valueTerm(row)
termValue = getCharField(row, 'value');
if isempty(termValue)
    termValue = getCharField(row, 'string_value');
end
valueT = struct('node', '', 'name', termValue);   % free label -> name; node backfilled
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
    'schema_version', 'V_eta');
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
end

function rows = extractRows(block)
%EXTRACTROWS Normalise an ontology_table_row body to a cell of column structs
%   (each {ontology_name, name, value}), one per measured property.
rows = {};
if isfield(block, 'rows')
    r = block.rows;
    if iscell(r); rows = r(:)';
    elseif isstruct(r); rows = arrayfun(@(x) x, r(:)', 'UniformOutput', false); end
    return;
end
if isfield(block, 'variable_names')
    vars  = splitCSV(getCharField(block, 'variable_names'));
    names = splitCSV(getCharField(block, 'names'));
    nodes = splitCSV(getCharField(block, 'ontology_nodes'));
    data = struct();
    if isfield(block, 'data') && isstruct(block.data); data = block.data; end
    for i = 1:numel(vars)
        key = vars{i};
        label = ''; node = '';
        if i <= numel(names); label = names{i}; end
        if i <= numel(nodes); node = nodes{i}; end
        val = [];
        if ~isempty(key) && isfield(data, key); val = data.(key); end
        if isempty(val) || (isnumeric(val) && isscalar(val) && isnan(val)); continue; end
        rows{end+1} = struct('ontology_name', node, 'name', label, 'value', val); %#ok<AGROW>
    end
    return;
end
if isfield(block, 'ontology_name') || isfield(block, 'name')
    rows = {block};
end
end

function parts = splitCSV(s)
parts = {};
if isempty(s); return; end
raw = strsplit(char(s), ',');
parts = cellfun(@strtrim, raw, 'UniformOutput', false);
end

function [isNumeric, numVal] = rowNumericValue(row)
isNumeric = false; numVal = [];
if isfield(row, 'value')
    v = row.value;
    if isnumeric(v) && isscalar(v) && isfinite(v); isNumeric = true; numVal = double(v); end
elseif isfield(row, 'numeric_value')
    v = row.numeric_value;
    if isnumeric(v) && ~isempty(v); isNumeric = true; numVal = double(v(1)); end
end
end

function tf = looksLikeTimestamp(s)
tf = false;
if isempty(s) || ~ischar(s); return; end
% a date-ish string: contains a slash-or-dash date and/or a time
tf = ~isempty(regexp(s, '\d{1,4}[/-]\d{1,2}[/-]\d{1,4}', 'once')) || ...
     ~isempty(regexp(s, '\d{1,2}:\d{2}', 'once'));
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v);
    elseif isnumeric(v) && isscalar(v); s = num2str(v); end
end
end

function tf = containsAny(hay, needles)
tf = false;
for k = 1:numel(needles)
    pat = ['\<', regexptranslate('escape', needles{k}), '\>'];
    if ~isempty(regexp(hay, pat, 'once')); tf = true; return; end
end
end
