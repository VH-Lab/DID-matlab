function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-J migrator: did_v1 ontology_table_row -> the v1
%   row, carried whole (1 -> 1).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   A row with no `subject_id` edge (every row NDI's writer makes) passes
%   through for the NDI second pass, which finds its subject. A row WITH a
%   subject is carried whole as v1 with a `needs_mapping` note: which entity
%   each column is about, its direction and its value kind are not stated by
%   the v1 row, and the per-column seed that chose them from label words left
%   the generic stage ([one correct reading], [dataset audit batch 1 and 2]
%   (4), Jess Haley, 2026-10-26).
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

% --- ONE CORRECT READING: a row with a subject is CARRIED, not guessed -------
% Decided by Jess Haley, 2026-10-26 [one correct reading] and [dataset audit
% batch 1 and 2] (4) (did-schema V_eta_go_forward_class_audit.md): "table
% columns ... whose kind, direction or unit is chosen from label words carry as
% v1 with `needs_mapping` rows instead of a guessed reading". The per-column
% seed this replaced chose every column's direction (assertion / observation)
% and value kind (mass, length, time, ..., intensity by default) from words in
% its label; nothing in a v1 ontologyTableRow states either (a Dab "percent
% time" column read as a time, an "administration" column as an observation).
% So the row is carried whole as v1, its note naming the V2 homes and what
% decides between them: the table's column map in its dataset.
did2.convert.reportNote('carried_as_v1', 'ontology_table_row', sourceIdOf(preBody), ...
    ['needs_mapping: assertion | observation | manipulation per column (its ' ...
     'entity, direction, value kind and unit); decided by the table''s column ' ...
     'map in its dataset']);
bodies = {preBody};
end

function id = sourceIdOf(preBody)
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = char(preBody.base.id);
end
end


% ===================== helpers =========================================

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

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v);
    elseif isnumeric(v) && isscalar(v); s = num2str(v); end
end
end
