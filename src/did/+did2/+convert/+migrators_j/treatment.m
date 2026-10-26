function v2Body = treatment(preBody)
%TREATMENT Brainstorm-J split migrator: did_v1 treatment -> a `manipulation`
%   whose value kind is chosen by the treatment (`temperature`, `dose` or
%   `formulation` for a substance, `term` for a procedure, or the kind the
%   treatment's term names for its number) (+ an optional site `observation`
%   with value kind `term` + the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Strict J retires the injection/bath/generic_manipulation families (D8): a
%   treatment row is dispatched by the STRUCTURE its data needs into one of the
%   data-type leaves (V_eta_migration_plan.md Parts C-D; treatment.md):
%
%       temperature_manipulation  imposed heat/cold -> a typed temperature value
%       dose_manipulation         a delivered substance -> a dose naming a
%                                 formulation (the substance is the spine
%                                 identity); an immersion (bath site) is a
%                                 `manipulation` valued by the formulation
%                                 instead, and a row with no site is a dose
%                                 reported as route_unknown (jTreatmentBodies)
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
%   numeric_value: NEVER an amount. A term that says what its number is
%   (termNumberKind; e.g. EMPTY:0000199, a duration in hours) makes a
%   manipulation of that value kind, valued by it; a temperature term keeps the number as
%   its temperature; otherwise the number is an unlabelled condition
%   ('numeric value') and a `treatment_number_unlabelled` report note (Jess
%   Haley, 2026-10-21, "yes"). The anchor is the recorded
%   administration onset when there is one, else the session
%   (jTreatmentAnchor; Jess Haley, 2026-10-21, "a").
%
%   1 -> 2 (manipulation + anchor), or 1 -> 3 when the row carries a site.
%   Not-a-manipulation rows (date of birth, experiment time), rows whose
%   branch cannot be resolved, rows whose label ends "target location" (the
%   suffix would be stripped from the variable) and substance rows whose dose
%   amounts cannot all be placed are returned UNCHANGED, carried whole as v1
%   with a `carried_as_v1` note ([generic stage is lossless], [partly placed is
%   carried as v1], Jess Haley, 2026-10-25). Until then the first two raised
%   did2:convert:notAManipulation / unresolvedTreatment and were quarantined.
%   Nothing is forced into a residual family. Branch resolution is a keyword/CURIE-prefix HEURISTIC seed;
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
% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): each refusal below
% returns the v1 document UNCHANGED (carried whole as v1, noted
% `carried_as_v1`) instead of rewriting or quarantining it.
if endsWith(lower(strtrim(label)), 'target location')
    % the variable would be the label with its "target location" suffix
    % stripped, and the v1 spelling kept nowhere
    v2Body = carryAsV1(preBody, 'treatment.name (the "target location" suffix would be stripped)');
    return;
end
siteTerm = struct('node', {}, 'name', {});   % empty ontology_term array
if looksLikeCURIE(strValue)
    siteTerm = jOntologyTerm(strValue, '');
    variable.name = strtrim(regexprep(label, '(?i)\s*target location$', ''));
    strValue = '';
end
notesText = strValue;

% --- not-a-manipulation rows -> carried as v1 (were quarantined) --------
if containsAny(hay, {'date of birth', 'non-survival experiment time', ...
        'experiment time'})
    v2Body = carryAsV1(preBody, sprintf(['treatment "%s" is not a manipulation ' ...
        '(was did2:convert:notAManipulation)'], label));
    return;
end

% --- branch dispatch into strict-J leaves (first match wins) -----------
anchor = jTreatmentAnchor(preBody, block);   % the recorded onset, else the session

% --- numeric_value is NEVER an amount (Jess Haley, 2026-10-21, "yes"): it is
% the value the treatment's TERM says it is. A term that says what kind of
% number it carries (termNumberKind) makes the statement that kind of value;
% otherwise the number is kept, unlabelled, as a condition on the statement
% and the migration report notes it (`treatment_number_unlabelled`).
hasNumber = ~isempty(numValue) && isnumeric(numValue);
[kind, unit] = termNumberKind(node, label);
if ~isempty(kind)
    v = [];
    if hasNumber
        v = jQuantity(kind, double(numValue(1)), unit);
    end
    manip = {jStatement(preBody, 'manipulation', jSubjectOf(preBody), variable, ...
        v, 'TimeReferenceIds', {anchor.base.id}, 'Notes', notesText, ...
        'Id', char(preBody.base.id), 'ValueKind', kind)};
    v2Body = [manip, {anchor}];
    return;
end
numberCondition = [];
if hasNumber && isfinite(double(numValue(1)))
    numberCondition = did2.build.condition(jLabel('numeric value'), ...
        'Value', double(numValue(1)));
end

if containsAny(hay, {'cool', 'cold', 'heat', 'warm', 'thermal', 'temperature'})
    % the term says what the number is: a temperature
    manip = makeTemperatureManipulation(preBody, variable, notesText, numValue, anchor.base.id);
    numberCondition = [];
elseif containsAny(hay, {'inject', 'virus', 'aav', 'tracer', 'drug', ...
        'vehicle', 'bath', 'infusion', 'perfusate'}) ...
        || startsWith(lower(node), 'chebi:')
    [manip, route, unplaced] = makeSubstanceManipulation(preBody, variable, notesText, ...
        numberCondition, siteTerm, anchor.base.id);
    if ~isempty(unplaced)
        v2Body = carryAsV1(preBody, jCarryWhy(unplaced));
        return;
    end
    if strcmp(route, 'immersion')
        siteTerm = struct('node', {}, 'name', {});   % a bath is no site on the subject
    end
elseif containsAny(hay, {'craniotomy', 'implant', 'lesion', 'perfus', ...
        'eye opening', 'eyelid', 'ear notch', 'ear punch', 'tail clip', ...
        'toe clip', 'whisker', 'suture', 'surgery', 'transection', ...
        'resection', 'enucleation', 'dissection', 'procedure', 'optogenetic', ...
        'rear', 'deprivation', 'isolation', 'enrichment', 'housing', ...
        'light', 'dark', 'restriction', 'diet', 'training', 'habituation', ...
        'restraint', 'fast', 'regime'})
    manip = makeTermManipulation(preBody, variable, notesText, numberCondition, anchor.base.id);
else
    v2Body = carryAsV1(preBody, sprintf(['treatment "%s" (%s) could not be ' ...
        'routed to a manipulation (was did2:convert:unresolvedTreatment)'], label, node));
    return;
end

if ~isempty(numberCondition)
    did2.convert.reportNote('treatment_number_unlabelled', ...
        char(preBody.document_class.class_name), char(preBody.base.id), ...
        sprintf('%s: %s', label, num2str(double(numValue(1)), 17)));
end

% --- shared anchor; wire onto the manipulation -------------------------
v2Body = [manip, {anchor}];
if ~isempty(siteTerm)
    obs = jStatement(preBody, 'observation', jSubjectOf(preBody), ...
        did2.convert.registeredTerm('NCIT:C13717', 'Anatomic Site'), siteTerm, ...
        'TimeReferenceIds', {anchor.base.id}, 'ValueKind', 'term');
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
docs = {jStatement(preBody, 'manipulation', jSubjectOf(preBody), variable, ...
    value, 'TimeReferenceIds', {anchorId}, 'Notes', notesText, ...
    'Id', char(preBody.base.id), 'ValueKind', 'temperature')};
end

function [docs, route, unplaced] = makeSubstanceManipulation(preBody, variable, notesText, numberCondition, siteTerm, anchorId)
% A delivered substance, routed by its recorded location (jTreatmentRoute,
% Jess Haley, 2026-10-21): the bath -> an immersion (a `manipulation` valued
% by its formulation through `value_id`); any other site -> a dose; no site
% -> a dose listed as `route_unknown` in the migration report. A v1
% `treatment` records a location only through the Dab "Target Location"
% idiom (string_value), so most substance rows are route unknown. A dose's
% amount is NaN in `volume.liters` (jDoseValue). `numeric_value` is NEVER
% read as an amount -- neither the dose's nor the ingredient's (Jess Haley,
% 2026-10-21, "yes"); an unlabelled number rides as NUMBERCONDITION.
chem = struct('substance', variable, 'source_value', [], 'source_unit', '');
loc = [];
if ~isempty(siteTerm)
    loc = siteTerm(1);
end
[docs, route, unplaced] = jTreatmentBodies(preBody, variable, chem, loc, anchorId, ...
    'Notes', notesText, 'Conditions', numberCondition);
end

function docs = makeTermManipulation(preBody, variable, notesText, numberCondition, anchorId)
extra = {};
if ~isempty(numberCondition)
    extra = {'Conditions', numberCondition};
end
docs = {jStatement(preBody, 'manipulation', jSubjectOf(preBody), variable, ...
    variable, 'TimeReferenceIds', {anchorId}, 'Notes', notesText, ...
    'Id', char(preBody.base.id), extra{:}, 'ValueKind', 'term')};
end

function [kind, unit] = termNumberKind(node, label)
% The kind of number a treatment TERM says its numeric_value is, and the
% unit it is given in ('' / '' when the term does not say). Keyed by the
% term (CURIE key) or its label. One row per term whose definition states it:
%   EMPTY:0000199 "treatment: grating direction-of-motion visual stimulation",
%   defined "Training was provided for several hours with drifting
%   sinusoidal gratings (provided in hours)"; NDI's one writer,
%   +setup/+conv/+vhlab/treatmentTable.m row 1, stores duration_hours.
T = {'EMPTY:0000199', 'treatment: grating direction-of-motion visual stimulation', 'time', 'hours'};
kind = '';
unit = '';
lab = lower(strtrim(label));
for k = 1:size(T, 1)
    hit = strcmpi(lab, T{k, 2});
    if ~hit && ~isempty(node)
        try
            hit = strcmp(char(did2.schema.curieKey(node)), char(did2.schema.curieKey(T{k, 1})));
        catch
            hit = strcmpi(strtrim(node), T{k, 1});
        end
    end
    if hit
        kind = T{k, 3};
        unit = T{k, 4};
        return;
    end
end
end

function v2Body = carryAsV1(preBody, why)
%CARRYASV1 The v1 treatment, unchanged, as the generic stage's output ([generic
%   stage is lossless], [partly placed is carried as v1], Jess Haley,
%   2026-10-25), noted with WHY.
did2.convert.reportNote('carried_as_v1', char(preBody.document_class.class_name), ...
    char(preBody.base.id), why);
v2Body = {preBody};
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
