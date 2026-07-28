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
if containsAny(hay, {'cool', 'cold', 'heat', 'warm', 'thermal', 'temperature'})
    manip = makeTemperatureManipulation(preBody, variable, notesText, numValue);
elseif containsAny(hay, {'inject', 'virus', 'aav', 'tracer', 'drug', ...
        'vehicle', 'bath', 'infusion', 'perfusate'}) ...
        || startsWith(lower(node), 'chebi:')
    manip = makeDoseManipulation(preBody, variable, notesText, numValue);
elseif containsAny(hay, {'craniotomy', 'implant', 'lesion', 'perfus', ...
        'eye opening', 'eyelid', 'ear notch', 'ear punch', 'tail clip', ...
        'toe clip', 'whisker', 'suture', 'surgery', 'transection', ...
        'resection', 'enucleation', 'dissection', 'procedure', 'optogenetic', ...
        'rear', 'deprivation', 'isolation', 'enrichment', 'housing', ...
        'light', 'dark', 'restriction', 'diet', 'training', 'habituation', ...
        'restraint', 'fast', 'regime'})
    manip = makeTermManipulation(preBody, variable, notesText);
else
    error('did2:convert:unresolvedTreatment', ...
        ['treatment "%s" (%s) could not be routed to a manipulation ', ...
         'leaf; curator review required.'], label, node);
end

% --- shared session anchor; wire onto the manipulation -----------------
anchor = jSessionAnchor(preBody, 'during');
manip.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);

bodies = {manip};
if ~isempty(siteTerm)
    obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
        {}, jOntologyTerm('', 'anatomical location'), {'subject_id'}, true);
    obs.term = struct('value', siteTerm);
    obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
    bodies{end+1} = obs;
end
bodies{end+1} = anchor;
v2Body = bodies;
end

% ===================== destination builders ============================

function body = makeTemperatureManipulation(preBody, variable, notesText, numValue)
body = jStartInteraction(preBody, 'temperature_manipulation', ...
    'subject_manipulation', {'temperature'}, variable);
body.subject_manipulation.notes = notesText;
body.temperature = struct('value', temperatureSeries(numValue));
end

function body = makeDoseManipulation(preBody, variable, notesText, numValue)
body = jStartInteraction(preBody, 'dose_manipulation', ...
    'subject_manipulation', {'dose'}, variable);
body.subject_manipulation.notes = notesText;
% the treatment substance is the spine identity AND the (single) dose chemical.
% Carry a source numeric_value as the amount (otherwise dropped -- only the
% temperature branch used to consume it); the source unit is left blank for
% discovery-mode fill-in.
amount = jConcentration();
if nargin >= 4 && ~isempty(numValue) && isnumeric(numValue)
    amount.source_value = double(numValue(1));
end
chemicals = struct('substance', variable, 'amount', amount);
body.dose = struct('value', jDoseValue(chemicals));
end

function body = makeTermManipulation(preBody, variable, notesText)
body = jStartInteraction(preBody, 'term_manipulation', ...
    'subject_manipulation', {}, variable);
body.subject_manipulation.notes = notesText;
body.term = struct('value', variable);   % the imposed act term
end

% ===================== local helpers ===================================

function s = temperatureSeries(numValue)
% A typed temperature value; series-as-cardinality -> a length-1 series is a
% single composite. Celsius assumed when a raw number is present (discovery
% mode refines the source unit).
s = struct('source_unit', '', 'source_value', 0.0, 'approximate', false);
if ~isempty(numValue) && isnumeric(numValue)
    s.source_value = double(numValue(1));
    s.source_unit = 'celsius';
end
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
