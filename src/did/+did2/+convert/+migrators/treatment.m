function out = treatment(preBody)
%TREATMENT Migrate a did_v1 treatment via the V_epsilon manipulation split.
%
%   The legacy `treatment` catch-all (ontology_name + name +
%   numeric_value + string_value) splits across the V_epsilon
%   manipulation families by dispatching on its name/ontology, per
%   Procedural_Manipulation_Proposal.md and Boundary_Mapping_Proposal.md:
%
%     thermal (heat/cool/temperature)         -> temperature_manipulation
%     "...Target Location" + CURIE string_val -> procedural_manipulation
%                                                 (string_value is the
%                                                 target_structure, not
%                                                 prose)
%     surgical / minor procedures             -> procedural_manipulation
%     husbandry / sensory / behavioral regime -> environmental_manipulation
%
%   A non-empty numeric_value is preserved as a companion
%   generic_scalar_observation (the rung-2 escalation pattern) rather
%   than dropped. string_value lands in `notes` for the procedural /
%   environmental branches.
%
%   Records that are NOT manipulations (e.g. "Treatment: Date of birth",
%   "Treatment: Non-survival experiment time") and records whose branch
%   cannot be determined are QUARANTINED (this function throws), matching
%   the proposal's "report-only first; curator confirms ambiguous /
%   not-a-manipulation rows before any rewrite" mandate. Nothing is
%   silently mis-routed.
%
%   manipulation_id (stale) and protocol_id are dropped per the proposal.
%
%   See did-schema schemas/V_epsilon/conversions/from_did_v1/treatment.md.

arguments
    preBody (1,1) struct
end

ic = did2.convert.interactionCommon;

block = struct();
if isfield(preBody, 'treatment') && isstruct(preBody.treatment)
    block = preBody.treatment;
end
ontologyNode = char(getField(block, 'ontology_name', ''));
name         = char(getField(block, 'name', ''));
stringValue  = char(getField(block, 'string_value', ''));
numericValue = getField(block, 'numeric_value', []);

branch = classifyTreatment(name, ontologyNode, stringValue);

subjectId = ic.depDocId(preBody, 'subject_id');
% Timing is not recoverable from a legacy treatment (it carries none);
% the time_reference is omitted and flagged for curator backfill.
deps = ic.dependsOn({'subject_id', subjectId});

primary = struct();
primary.base = ic.carryBase(preBody);
primary.depends_on = deps;

switch branch
    case 'temperature'
        primary.document_class = struct('class_name', 'temperature_manipulation');
        primary.scalar_manipulation = struct( ...
            'applied_property', ic.ontologyTerm(ontologyNode, name), ...
            'target_structure', ic.ontologyTermArray({}), ...
            'notes', stringValue);
        primary.temperature_manipulation = struct( ...
            'value', struct('approximate', false, 'source_unit', '', ...
                'source_value', firstNumeric(numericValue)));
        numericValue = [];  % consumed into the temperature value
    case 'procedural'
        primary.document_class = struct('class_name', 'procedural_manipulation');
        primary.procedural_manipulation = struct( ...
            'procedure', ic.ontologyTerm(ontologyNode, name), ...
            'target_structure', ic.ontologyTermArray({}), ...
            'notes', stringValue);
    case 'procedural_target'
        % Dab-corpus convention: string_value is a UBERON CURIE naming
        % the target, and the name carries a "...Target Location" suffix.
        primary.document_class = struct('class_name', 'procedural_manipulation');
        primary.procedural_manipulation = struct( ...
            'procedure', ic.ontologyTerm(ontologyNode, stripTargetSuffix(name)), ...
            'target_structure', ic.ontologyTermArray({{stringValue, ''}}), ...
            'notes', '');
    case 'environmental'
        primary.document_class = struct('class_name', 'environmental_manipulation');
        primary.environmental_manipulation = struct( ...
            'factor', ic.ontologyTerm(ontologyNode, name), ...
            'target_structure', ic.ontologyTermArray({}), ...
            'notes', stringValue);
    otherwise
        error('did2:convert:treatmentUnrouted', ...
            ['treatment "%s" (ontology "%s") is not a recognized ' ...
             'manipulation branch (or is not a manipulation, e.g. a ' ...
             'date-of-birth / session-metadata record). Route it ' ...
             'manually per conversions/from_did_v1/treatment.md.'], ...
            name, ontologyNode);
end

companions = {};
% Preserve a non-empty numeric_value as a companion observation (rung 2).
if hasNumeric(numericValue)
    companions{end+1} = buildNumericCompanion(ic, ...
        ontologyNode, name, numericValue, subjectId, ic.sessionIdOf(preBody));
end

out = [{primary}, companions];
end

% ---- classification -------------------------------------------------

function branch = classifyTreatment(name, ~, stringValue)
% The ontology node is not used for routing (the legacy `name` carries
% the semantic signal); it is accepted positionally for call-site
% symmetry with the field mapping.
n = lower(name);
% Not a manipulation -> caller quarantines.
if contains(n, 'date of birth') || contains(n, 'non-survival') ...
        || contains(n, 'experiment time')
    branch = 'not_manipulation';
    return;
end
% Dab target-location convention (string_value is an ontology CURIE).
if endsWith(strtrim(n), 'target location') && looksLikeCurie(stringValue)
    branch = 'procedural_target';
    return;
end
if anyContains(n, {'heat', 'cool', 'cold', 'thermal', 'temperature', 'warm'})
    branch = 'temperature';
    return;
end
if anyContains(n, {'dark rear', 'rearing', 'deprivation', 'deprive', ...
        'monocular', 'housing', 'isolation', 'enrichment', 'light cycle', ...
        'light/dark', 'diet', 'food restrict', 'water restrict', ...
        'social', 'training', 'exposure'})
    branch = 'environmental';
    return;
end
if anyContains(n, {'craniotomy', 'durotomy', 'implant', 'lesion', ...
        'surgery', 'surgical', 'eye opening', 'ear notch', 'notch', ...
        'tail clip', 'whisker trim', 'trim', 'clip', 'perfusion', ...
        'dissection', 'transection', 'resection', 'enucleation', ...
        'suture', 'blood draw', 'opening', 'procedure'})
    branch = 'procedural';
    return;
end
branch = 'unresolved';
end

function tf = anyContains(s, needles)
tf = false;
for k = 1:numel(needles)
    if contains(s, needles{k})
        tf = true;
        return;
    end
end
end

function tf = looksLikeCurie(s)
tf = ~isempty(regexp(char(s), '^[A-Za-z][A-Za-z0-9_]*:[A-Za-z0-9]+$', 'once'));
end

function s = stripTargetSuffix(name)
s = regexprep(char(name), '\s*Target Location\s*$', '', 'ignorecase');
end

% ---- numeric companion ---------------------------------------------

function body = buildNumericCompanion(ic, ontologyNode, name, numericValue, subjectId, sessionId)
% A generic_scalar_observation preserving the legacy numeric value
% verbatim (source-only), so a recognizable typed quantity is not lost.
% The legacy base.id stays on the primary; the companion gets a fresh
% id but the same session_id.
body = struct();
body.document_class = struct('class_name', 'generic_scalar_observation');
body.base = ic.newBase(sessionId);
body.observation = struct( ...
    'measured_property', ic.ontologyTerm(ontologyNode, name), ...
    'target_structure', ic.ontologyTermArray({}));
body.generic_scalar_observation = struct('value', struct( ...
    'approximate', true, 'source_unit', '', ...
    'source_value', firstNumeric(numericValue)));
body.depends_on = ic.dependsOn({'subject_id', subjectId});
end

% ---- numeric helpers -----------------------------------------------

function tf = hasNumeric(v)
tf = isnumeric(v) && ~isempty(v) && any(~isnan(v(:)));
end

function x = firstNumeric(v)
x = 0;
if isnumeric(v) && ~isempty(v)
    vv = v(~isnan(v));
    if ~isempty(vv)
        x = vv(1);
    end
end
end

function val = getField(s, name, default)
val = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    val = s.(name);
end
end
