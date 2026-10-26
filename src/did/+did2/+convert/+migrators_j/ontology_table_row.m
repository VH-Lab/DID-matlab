function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-J split migrator: did_v1 ontology_table_row
%   -> one statement per column (1 -> N).
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
%   per-sample cadence in subject_interaction.sample_time (D1).
%
%   NO PER-TABLE MAPS (Decided by Jess Haley, 2026-10-26 [dataset-specific
%   logic leaves the generic migration], [dataset audit batch 1 and 2], did-schema
%   V_eta_go_forward_class_audit.md). The JH C. elegans encounter map and
%   bacterial-patch geometry map that lived here encoded one dataset's tables
%   (the Haley import's `encounterVariables` / `patchVariables`), so they left
%   the generic migration: such a row is handled like any other row below, and
%   the Haley dataset's V2 shape comes from its V2 re-import
%   (ndi.setup.conv.haley.import_V2).

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_table_row') || ~isstruct(preBody.ontology_table_row)
    error('did2:convert:missingBlock', ...
        'ontology_table_row body is missing the ontology_table_row property block.');
end

% --- GUARD: no resolvable subject => no fabricated statements ---------------
% The per-column fallback seeds every statement through startStatement, which
% calls carrySubject(preBody) -- a scan of the SOURCE document's depends_on for
% a dependency named `subject_id`. The real NDI template declares exactly one
% dependency and it is not that one:
%
%     ndi_common/database_documents/data/ontologyTableRow.json
%     depends_on: [ { "name": "document_id", "value": "" } ]
%
% So the scan never succeeds on a real document and every statement was emitted
% with subject_id = ''. Corpus run #256 measured the cost on Dab alone: 76,766
% observations and assertions -- intensity, count, term, duration, frequency,
% date_assertion, term_assertion -- each recording that SOMETHING was measured
% without recording WHAT. All of it passed validation, because references.m
% skips empty edges and mustBeNonEmpty on depends_on is not enforced.
%
% This is the same defect ontology_label had, and it gets the same treatment:
% carry the document through intact for the NDI second pass, which can see the
% migrated-id graph. `document_id` cannot simply be renamed to `subject_id` --
% it points at the document the row describes, which need not be a subject, and
% minting an unresolvable edge is what turned distance_metadata's non-gating
% quarantine into a GATING orphan failure.
if isempty(resolvedSubject(preBody))
    bodies = {preBody};
    return;
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
    [b, isObservation] = migrateRow(preBody, rows{k}, '', anchor.base.id);
    if isempty(b)
        continue;   % skipped column (identity, empty)
    end
    usedAnchor = usedAnchor || isObservation;
    bodies{end+1} = b; %#ok<AGROW>
end
if usedAnchor
    bodies{end+1} = anchor;
end
if isempty(bodies)
    bodies = {preBody};   % every column skipped -> carry unchanged
end
bodies = preserveSourceId(preBody, bodies);
end

function bodies = preserveSourceId(preBody, bodies)
%PRESERVESOURCEID Keep the source document's id on exactly ONE emitted body.
%
%   WHY. This migrator dissolves one document into many. Until now every
%   emitted body got a fresh id, so after migration NOTHING carried the source
%   row's id -- and any document pointing at that row was left pointing at an
%   id that no longer exists. An `ontologyImage` names its row via
%   `ontologyTableRow_id` and needs to follow it to reach its subject, so that
%   edge has to land somewhere real. There is no old-id -> new-id map anywhere
%   in the converter, so id preservation is the ONLY mechanism that can make
%   such an edge resolve.
%
%   This is the lesson the calculator work already paid for: dissolving a
%   referenced document without preserving its id produced 11448 orphans, and
%   preserving it is what fixed them (T10). `must_refer` is existence-only, so
%   a resolvable id is all a referrer needs.
%
%   WHICH BODY. Any of them works as a landing point, because every statement
%   this migrator emits carries `subject_id` -- so a follower lands on one
%   document and reads the subject straight off it, no search. The FIRST
%   emitted body takes it and the rest keep their fresh ids, matching the
%   primary/sibling convention jStartInteraction uses elsewhere in migrators_j.
%
%   EXCEPT when an emitted body already carries it: this checks first and
%   leaves an existing preservation alone; stamping again would mint two
%   documents sharing one id.
%
%   Safe to apply after the bodies are built: no emitted body references
%   another body's id. Internal edges point at the shared time_reference and at
%   the carried subject, never at a sibling statement.
if isempty(bodies); return; end
if ~isfield(preBody, 'base') || ~isstruct(preBody.base) ...
        || ~isfield(preBody.base, 'id') || isempty(preBody.base.id)
    return;
end
srcId = preBody.base.id;
for k = 1:numel(bodies)
    b = bodies{k};
    if isstruct(b) && isfield(b, 'base') && isstruct(b.base) ...
            && isfield(b.base, 'id') && isequal(b.base.id, srcId)
        return;   % already carried (a passthrough)
    end
end
if isfield(bodies{1}, 'base') && isstruct(bodies{1}.base)
    bodies{1}.base.id = srcId;
end
end

function id = sourceIdOf(preBody)
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = char(preBody.base.id);
end
end


% ===================== per-row migration ===============================

function [body, isObservation] = migrateRow(preBody, row, subjectId, anchorId)
%MIGRATEROW One column -> one statement.
%   SUBJECTID (optional) names the subject explicitly. Omit it on the
%   per-column fallback path, where the subject is CARRIED from the source
%   document's `subject_id` dependency (and the caller has already guarded on
%   there being one). Pass it from a per-table map, which MINTS its subject --
%   `carrySubject` would raise there, because a real ontologyTableRow declares
%   only `document_id`.
if nargin < 3; subjectId = ''; end
if nargin < 4; anchorId = ''; end
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
    body = makeTermAssertion(preBody, variable, valueTerm(row), subjectId);
    return;
elseif containsAny(hay, {'date of birth', 'birth date', 'dob'})
    body = makeDateAssertion(preBody, variable, row, subjectId);
    return;
elseif ~isNumeric && looksLikeTimestamp(getCharField(row, 'value'))
    body = makeDateAssertion(preBody, variable, row, subjectId);
    return;
end

% timed measurements -> observations
isObservation = true;
if isNumeric
    [shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal);
    body = makeNumericObservation(preBody, shapeClass, variable, ...
        valueStruct, subjectId, anchorId);
else
    body = makeTermObservation(preBody, variable, valueTerm(row), subjectId, anchorId);
end
end

function [shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal)
%DISPATCHNUMERIC Choose the value kind by the property's DIMENSION. The
%   property rides on the spine `variable`; word-boundary matching only.
unit = getCharField(row, 'unit');
if containsAny(hay, {'body weight', 'body mass', 'weight', 'mass'})
    shapeClass = 'mass';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'radius', 'body length', 'length', 'diameter', 'distance', 'size'})
    shapeClass = 'length';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'sampling rate', 'heart rate', 'respiration rate', 'frequency', 'rate'})
    shapeClass = 'frequency';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'deceleration', 'acceleration'})
    shapeClass = 'acceleration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'velocity', 'speed'})
    shapeClass = 'velocity';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'onset time', 'offset time', 'age', 'duration', 'latency', 'time'})
    % `time`, not `duration`: the V_eta shape mixin was renamed by
    % TEAM-SIGN-OFF [time dtype] (DID-schema V_eta_tenet_audit.md, 2026-08-17).
    % The HAYSTACK words are unchanged -- they match the source column's label,
    % which is did_v1 text and did not move.
    shapeClass = 'time';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'volume'})
    shapeClass = 'volume';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'temperature'})
    shapeClass = 'temperature';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'pressure'})
    shapeClass = 'pressure';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'voltage', 'membrane potential'})
    shapeClass = 'voltage';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'current'})
    shapeClass = 'current';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'concentration', 'density', 'titer', 'titre', 'glucose'})
    shapeClass = 'concentration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'number of', 'count', 'entries', 'trial number', 'identifier', 'samples'})
    shapeClass = 'count';
    valueStruct = did2.build.valueCell('count', round(numVal), 'Approximate', false);
elseif containsAny(hay, {'percent', 'probability', 'circularity', 'score', 'condition'})
    shapeClass = 'score';
    valueStruct = did2.build.composite('score', 'value', ...
        struct('score', numVal, 'approximate', false));
else
    % J §7: intensity is the one dimensionless numeric (a.u.) -- the home for
    % amplitudes / fluorescence / ratios / unrecognised numerics. No generic
    % escape hatch (D8); a genuinely mis-dimensioned value is caught in
    % discovery-mode review, not silently dropped.
    shapeClass = 'intensity';
    valueStruct = sourceCell(unit, numVal);
end
if ~any(strcmp(shapeClass, {'count', 'score'}))
    valueStruct = jQuantity(shapeClass, valueStruct.source_value, ...
        valueStruct.source_unit, 'approximate', false);
end
end

% ===================== destination builders ============================

function body = makeNumericObservation(preBody, shapeClass, variable, valueStruct, subjectId, anchorId)
% did-schema #88: an `observation` with the value-kind mixin SHAPECLASS
body = jStatement(preBody, 'observation', subjectOrCarried(preBody, subjectId), ...
    variable, valueStruct, 'TimeReferenceIds', {anchorId}, 'ValueKind', shapeClass);
end

function body = makeTermObservation(preBody, variable, valueT, subjectId, anchorId)
body = jStatement(preBody, 'observation', subjectOrCarried(preBody, subjectId), ...
    variable, valueT, 'TimeReferenceIds', {anchorId}, 'ValueKind', 'term');
end

function body = makeTermAssertion(preBody, variable, valueT, subjectId)
body = jStatement(preBody, 'assertion', subjectOrCarried(preBody, subjectId), ...
    variable, valueT, 'ValueKind', 'term');
end

function body = makeDateAssertion(preBody, variable, row, subjectId)
raw = getCharField(row, 'value');
v = did2.build.composite('date', 'value', ...
    struct('instant', raw, 'precision', 'second', 'source_value', raw));
body = jStatement(preBody, 'assertion', subjectOrCarried(preBody, subjectId), ...
    variable, v, 'ValueKind', 'date');
end

function id = subjectOrCarried(preBody, subjectId)
id = char(subjectId);
if isempty(id)
    id = resolvedSubject(preBody);
    if isempty(id)
        error('did2:convert:noSubject', ...
            ['ontology_table_row: refusing to emit a statement with an empty ' ...
             'entity_id. A real ontologyTableRow declares only `document_id`, ' ...
             'so the caller must guard on resolvedSubject() and pass the ' ...
             'document through for the second pass instead.']);
    end
end
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

function subjectVal = resolvedSubject(preBody)
%RESOLVEDSUBJECT The subject this row is about, or '' when there is none.
%
%   Reads the SOURCE document's depends_on for a dependency named `subject_id`.
%   Real ontologyTableRow documents do not have one -- the NDI template declares
%   only `document_id` -- so this returns '' for them, and the caller must NOT
%   emit statements in that case. See the guard in the main function.
%
%   Kept as a separate query from carrySubject so that "is there a subject?" is
%   answerable WITHOUT building a dependency struct. The old code could only
%   answer it by constructing the edge, which is why the empty case was written
%   out instead of detected.
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
end

function anchor = makeSessionAnchor(preBody, relation)
anchor = jSessionAnchor(preBody, relation);
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
