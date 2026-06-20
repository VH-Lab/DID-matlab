function v2Body = treatment(preBody)
%TREATMENT Brainstorm-E split migrator: did_v1 treatment -> manipulation tiers.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion ==
%   'V_epsilon'. Reads the treatment block's ontology identity + numeric
%   / string values and dispatches the row to the manipulation family
%   whose ACTION it names, per
%   did-schema/schemas/V_epsilon/conversions/from_did_v1/treatment.md:
%
%       injection                (substance delivered by injection)
%       bath                     (substance applied as a bath)
%       procedural_manipulation  (physical operation on the body)
%       temperature_manipulation (imposed heat / cold)
%       environmental_manipulation (changed condition / regime, no value)
%
%   This is a 1 -> 1 split (one treatment -> one manipulation). Rows that
%   are not manipulations (date of birth, experiment time) or whose
%   branch cannot be resolved raise an error so the dispatcher routes the
%   source body to quarantine with a descriptive reason -- the
%   "curator review queue" of the conversion spec; nothing is forced into
%   a residual family.
%
%   Branch resolution here is a keyword/CURIE-prefix HEURISTIC seed; the
%   authoritative per-term branch list is finalised in discovery mode
%   against real corpora (treatment.md, Open questions).

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'treatment') || ~isstruct(preBody.treatment)
    error('did2:convert:missingBlock', ...
        'treatment body is missing the treatment property block.');
end
block = preBody.treatment;

node  = getCharField(block, 'ontology_name');
label = getCharField(block, 'name');
strValue = getCharField(block, 'string_value');
numValue = [];
if isfield(block, 'numeric_value')
    numValue = block.numeric_value;
end

identity = struct('node', node, 'name', label);
hay = lower([node ' ' label]);   % search text for the heuristic branch

% --- Dab edge case: string_value is an ontology target, not prose ------
targetStructure = {};
notesText = strValue;
if endsWith(lower(strtrim(label)), 'target location') || looksLikeCURIE(strValue)
    targetStructure = {struct('node', strValue, 'name', '')};
    notesText = '';
    identity.name = strtrim(regexprep(label, '(?i)\s*target location$', ''));
end

% --- not-a-manipulation rows: route OUT of tier (quarantine w/ reason) --
if containsAny(hay, {'date of birth', 'non-survival experiment time', ...
        'experiment time'})
    error('did2:convert:notAManipulation', ...
        ['treatment "%s" is not a manipulation; route out of tier ', ...
         '(observation/session metadata) per treatment.md.'], label);
end

% --- branch dispatch (first match wins) --------------------------------
if containsAny(hay, {'cool', 'cold', 'heat', 'warm', 'thermal', 'temperature'})
    v2Body = makeTemperatureManipulation(preBody, identity, targetStructure, ...
        notesText, numValue);
elseif containsAny(hay, {'inject', 'virus', 'aav', 'tracer', 'drug', 'vehicle'}) ...
        || startsWith(lower(node), 'chebi:')
    v2Body = makeInjection(preBody, identity, targetStructure, notesText);
elseif containsAny(hay, {'bath'})
    v2Body = makeBath(preBody, identity, notesText);
elseif containsAny(hay, {'craniotomy', 'implant', 'lesion', 'perfus', ...
        'eye opening', 'eyelid', 'ear notch', 'ear punch', 'tail clip', ...
        'toe clip', 'whisker', 'suture', 'surgery', 'transection', ...
        'resection', 'enucleation', 'dissection', 'procedure', 'optogenetic'})
    v2Body = makeProceduralManipulation(preBody, identity, targetStructure, notesText);
elseif containsAny(hay, {'rear', 'deprivation', 'isolation', 'enrichment', ...
        'housing', 'light', 'dark', 'restriction', 'diet', 'training', ...
        'habituation', 'restraint'})
    v2Body = makeEnvironmentalManipulation(preBody, identity, targetStructure, notesText);
else
    error('did2:convert:unresolvedTreatment', ...
        ['treatment "%s" (%s) could not be routed to a manipulation ', ...
         'family; curator review required.'], label, node);
end

% Attach a session-relative anchor. v1 treatment rows have no DAQ epoch and
% (often) no UTC date, so the honest fallback is an ordinal claim against the
% session. 'during' is correct for any migrated interaction (it happened
% within the session); 'at_end_of' is reserved for interactions known to be
% terminal and is not asserted blanket here. Emitting the time_reference as
% its own document makes this a 1 -> 2 migration.
anchor = makeSessionAnchor(preBody, 'during');
v2Body.depends_on(end+1) = struct('name', 'time_reference_1', ...
    'value', anchor.base.id);
v2Body = {v2Body, anchor};
end

% ===================== destination builders ============================

function body = makeTemperatureManipulation(preBody, identity, targetStructure, notesText, numValue)
body = startBody(preBody, 'temperature_manipulation', ...
    {'scalar_manipulation', 'scalar_temperature'});
body.scalar_manipulation = struct( ...
    'applied_property', identity, ...
    'target_structure', {targetStructure}, ...
    'notes', notesText);
body.scalar_temperature = struct('value', temperatureComposite(numValue));
end

function body = makeInjection(preBody, identity, targetStructure, notesText)
body = startBody(preBody, 'injection', {'pharmacological_manipulation'});
body.pharmacological_manipulation = struct('mixture', ...
    struct('agent', identity, 'concentration', emptyConcentration()));
body.injection = struct( ...
    'kind', 'drug', ...
    'route', struct('node', '', 'name', ''), ...
    'target_structure', {targetStructure}, ...
    'notes', notesText);
end

function body = makeBath(preBody, identity, notesText)
body = startBody(preBody, 'bath', {'pharmacological_manipulation'});
body.pharmacological_manipulation = struct('mixture', ...
    struct('agent', identity, 'concentration', emptyConcentration()));
body.bath = struct('kind', 'drug', ...
    'location', struct('node', '', 'name', ''), 'notes', notesText);
end

function body = makeProceduralManipulation(preBody, identity, targetStructure, notesText)
body = startBody(preBody, 'procedural_manipulation', {});
body.procedural_manipulation = struct( ...
    'procedure', identity, ...
    'target_structure', {targetStructure}, ...
    'notes', notesText);
end

function body = makeEnvironmentalManipulation(preBody, identity, targetStructure, notesText)
body = startBody(preBody, 'environmental_manipulation', {});
body.environmental_manipulation = struct( ...
    'factor', identity, ...
    'target_structure', {targetStructure}, ...
    'notes', notesText);
end

% ===================== shared helpers ==================================

function body = startBody(preBody, className, extraSupers)
%STARTBODY Seed a V_epsilon manipulation body: document_class header,
%   carried base + subject_id, and a synthesized time_reference slot.
chain = [{'manipulation'}, extraSupers];
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct( ...
    'class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_epsilon');
body.depends_on = carrySubject(preBody);
if isfield(preBody, 'base')
    body.base = preBody.base;
end
end

function deps = carrySubject(preBody)
%CARRYSUBJECT Carry the subject_id dependency forward (time_reference is
%   attached separately, pointing at the migrated session anchor).
deps = struct('name', {}, 'value', {});
subjectVal = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, 'subject_id')
            subjectVal = depValue(d);
        end
    end
end
deps(end+1) = struct('name', 'subject_id', 'value', subjectVal);
end

function anchor = makeSessionAnchor(preBody, relation)
%MAKESESSIONANCHOR Build a session_relative_reference document (ordinal,
%   no metric) anchored to the source document's session. Returned as a
%   sibling body so the interaction can depend_on it as its time_reference.
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

function v = depValue(d)
v = '';
if isfield(d, 'value')
    v = d.value;
elseif isfield(d, 'document_id')
    v = d.document_id;
end
end

function comp = temperatureComposite(numValue)
comp = struct('celsius', 0.0, 'source_unit', '', 'source_value', 0.0, ...
    'approximate', false);
if ~isempty(numValue) && isnumeric(numValue)
    v = double(numValue(1));
    comp.celsius = v;
    comp.source_unit = 'celsius';
    comp.source_value = v;
end
end

function c = emptyConcentration()
c = struct('source_unit', '', 'source_value', 0.0, 'approximate', false);
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    end
end
end

function tf = looksLikeCURIE(s)
tf = ~isempty(s) && ~isempty(regexp(char(s), '^[A-Za-z][A-Za-z0-9_]*:[^\s:]+$', 'once'));
end

function tf = containsAny(hay, needles)
tf = false;
for k = 1:numel(needles)
    if contains(hay, needles{k})
        tf = true;
        return;
    end
end
end
