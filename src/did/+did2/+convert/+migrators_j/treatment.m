function v2Body = treatment(preBody)
%TREATMENT Brainstorm-J split migrator: did_v1 treatment -> a data-type-named
%   subject_manipulation leaf (+ an optional site term_observation + the shared
%   session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J retires the injection/bath/generic_manipulation families (D8): a
%   treatment row is dispatched by the STRUCTURE its data needs into one of the
%   data-type leaves (V_eta_migration_plan.md Parts C-D; treatment.md):
%
%       temperature_manipulation  imposed heat/cold -> a typed temperature value
%       dose_manipulation         a delivered substance -> a dose/formulation
%                                 composite (the substance is the spine identity)
%       term_manipulation         a payload-free procedure or husbandry regime
%                                 -> the act as a bound ontology term (no escape
%                                 hatch)
%
%   In J the identity rides on the spine `subject_statement.variable` (the
%   queryable "what"); the verb would go on `subject_interaction.method` (left
%   blank -- the leaf class names the act); prose on `subject_manipulation.notes`.
%   There is NO `target_structure` in J: a focal site is Path S. A merely-located
%   site becomes a `term_observation` value here (located-by-default, D3); an
%   ATTRIBUTED site is promoted to a part-`subject` + a `part_of`
%   `directed_relation` by the NDI second pass (ndi.migrate), which has the
%   corpus-wide subject graph the single-document migrator lacks.
%
%   1 -> 2 (manipulation + anchor), or 1 -> 3 when the row carries a site.
%   Not-a-manipulation rows (date of birth, experiment time) and rows whose
%   branch cannot be resolved raise an error so the dispatcher routes the source
%   body to quarantine with a descriptive reason -- nothing is forced into a
%   residual family. Branch resolution is a keyword/CURIE-prefix HEURISTIC seed;
%   the authoritative per-term branch list is finalised in discovery mode
%   against the corpora (Dab = the Target-Location locus pattern; JH =
%   food-restriction regime).

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment') || ~isstruct(preBody.treatment)
    error('did2:convert:missingBlock', ...
        'treatment body is missing the treatment property block.');
end
block = preBody.treatment;

node     = jGetChar(block, 'ontology_name');
label    = jGetChar(block, 'name');
strValue = jGetChar(block, 'string_value');
numValue = [];
if isfield(block, 'numeric_value'); numValue = block.numeric_value; end

variable = jOntologyTerm(node, label);
hay = lower([node ' ' label]);

% --- Dab "Target Location" idiom: string_value is an ontology site, not prose.
siteTerm = struct('node', {}, 'name', {});   % empty ontology_term array
if endsWith(lower(strtrim(label)), 'target location') || looksLikeCURIE(strValue)
    siteTerm = jOntologyTerm(strValue, '');
    variable.name = strtrim(regexprep(label, '(?i)\s*target location$', ''));
    strValue = '';
end
notesText = strValue;

% --- not-a-manipulation rows -> quarantine with reason -----------------
if containsAny(hay, {'date of birth', 'non-survival experiment time', ...
        'experiment time'})
    error('did2:convert:notAManipulation', ...
        ['treatment "%s" is not a manipulation; route out of tier ', ...
         '(observation/session metadata) per treatment.md.'], label);
end

% --- branch dispatch into strict-J leaves (first match wins) -----------
anchor = jSessionAnchor(preBody, 'during');
if containsAny(hay, {'cool', 'cold', 'heat', 'warm', 'thermal', 'temperature'})
    manip = makeTemperatureManipulation(preBody, variable, notesText, numValue, anchor.base.id);
elseif containsAny(hay, {'inject', 'virus', 'aav', 'tracer', 'drug', ...
        'vehicle', 'bath', 'infusion', 'perfusate'}) ...
        || startsWith(lower(node), 'chebi:')
    manip = makeDoseManipulation(preBody, variable, notesText, numValue, anchor.base.id);
elseif containsAny(hay, {'craniotomy', 'implant', 'lesion', 'perfus', ...
        'eye opening', 'eyelid', 'ear notch', 'ear punch', 'tail clip', ...
        'toe clip', 'whisker', 'suture', 'surgery', 'transection', ...
        'resection', 'enucleation', 'dissection', 'procedure', 'optogenetic', ...
        'rear', 'deprivation', 'isolation', 'enrichment', 'housing', ...
        'light', 'dark', 'restriction', 'diet', 'training', 'habituation', ...
        'restraint', 'fast', 'regime'})
    manip = makeTermManipulation(preBody, variable, notesText, anchor.base.id);
else
    error('did2:convert:unresolvedTreatment', ...
        ['treatment "%s" (%s) could not be routed to a manipulation ', ...
         'leaf; curator review required.'], label, node);
end

% --- shared session anchor; wire onto the manipulation -----------------
v2Body = [manip, {anchor}];
if ~isempty(siteTerm)
    obs = jStatement(preBody, 'term_observation', jSubjectOf(preBody), ...
        jLabel('anatomical location'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id});
    v2Body = [v2Body, {obs}];
end
end

% ===================== leaf builders =======================================
% Each returns a CELL of documents, the manipulation FIRST, and takes the
% anchor's id: did-schema #88 builds the whole statement at once (did2.build),
% so the time reference is made before it.

function docs = makeTemperatureManipulation(preBody, variable, notesText, numValue, anchorId)
value = [];
if ~isempty(numValue) && isnumeric(numValue)
    value = jQuantity('temperature', double(numValue(1)), 'celsius', 'approximate', false);
end
docs = {jStatement(preBody, 'temperature_manipulation', jSubjectOf(preBody), variable, ...
    value, 'TimeReferenceIds', {anchorId}, 'Notes', notesText, ...
    'Id', char(preBody.base.id))};
end

function docs = makeDoseManipulation(preBody, variable, notesText, numValue, anchorId)
% did-schema #88: a dose names a `formulation` document (required
% `formulation_id`), whose ingredient is a `chemical` -- see jDoseBodies. The
% amount the source gave (unit unstated) rides on the ingredient entry.
chem = struct('substance', variable, 'source_value', [], 'source_unit', '');
if nargin >= 4 && ~isempty(numValue) && isnumeric(numValue)
    chem.source_value = double(numValue(1));
end
[parts, formulationId] = jDoseBodies(preBody, chem);
dose = jStatement(preBody, 'dose_manipulation', jSubjectOf(preBody), variable, [], ...
    'TimeReferenceIds', {anchorId}, 'Notes', notesText, ...
    'Edges', struct('formulation_id', formulationId), 'Id', char(preBody.base.id));
docs = [{dose}, parts];
end

function docs = makeTermManipulation(preBody, variable, notesText, anchorId)
docs = {jStatement(preBody, 'term_manipulation', jSubjectOf(preBody), variable, ...
    variable, 'TimeReferenceIds', {anchorId}, 'Notes', notesText, ...
    'Id', char(preBody.base.id))};
end

function tf = looksLikeCURIE(s)
tf = ~isempty(s) && ~isempty(regexp(char(s), '^[A-Za-z][A-Za-z0-9_]*:[^\s:]+$', 'once'));
end

function tf = containsAny(hay, needles)
tf = false;
for k = 1:numel(needles)
    pat = ['\<', regexptranslate('escape', needles{k}), '\>'];
    if ~isempty(regexp(hay, pat, 'once')); tf = true; return; end
end
end
