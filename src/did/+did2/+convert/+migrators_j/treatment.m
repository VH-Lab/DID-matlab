function v2Body = treatment(preBody)
%TREATMENT Brainstorm-J migrator: did_v1 treatment -> a `manipulation` whose
%   value kind is the one the treatment's term states for its number, or a
%   dose / immersion for a ChEBI substance (+ an optional site `observation`
%   with value kind `term` + the shared session anchor); otherwise the v1
%   document carried whole.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   ONE CORRECT READING (Decided by Jess Haley, 2026-10-26 [one correct
%   reading], [dataset audit batch 1 and 2] (4), did-schema
%   V_eta_go_forward_class_audit.md): a treatment is placed only where the v1
%   document states its reading by itself:
%
%       a term that states its number's kind (termNumberKind; e.g.
%           EMPTY:0000199, a duration in hours) -> a manipulation of that
%           value kind, valued by the number;
%       a ChEBI substance node -> routed by its recorded location
%           (jTreatmentRoute, [treatment routes by location]): the bath -> an
%           immersion valued by its formulation; a body site -> a dose; no
%           location -> a dose with a NaN amount, noted route_unknown; an
%           environmental medium -> carried (needs_mapping).
%
%   Everything else -- a treatment whose temperature, substance or procedure
%   reading would be chosen from words in its label -- is returned UNCHANGED,
%   carried whole as v1 with a `carried_as_v1` note beginning `needs_mapping:`
%   that names the V2 homes and what decides between them.
%
%   numeric_value: NEVER an amount (Jess Haley, 2026-10-21, "yes"). Without a
%   term that states its kind, the number is an unlabelled condition ('numeric
%   value') and a `treatment_number_unlabelled` report note. The anchor is the
%   recorded administration onset when there is one, else the session
%   (jTreatmentAnchor; Jess Haley, 2026-10-21, "a"). A merely-located site
%   becomes a `term_observation` (D3); an ATTRIBUTED site is promoted by the
%   NDI second pass.
%
%   Not-a-manipulation rows (date of birth, experiment time), rows whose label
%   ends "target location" (the suffix would be stripped from the variable)
%   and substance rows whose dose amounts cannot all be placed are also
%   carried whole as v1 ([generic stage is lossless], [partly placed is
%   carried as v1], Jess Haley, 2026-10-25).

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

% --- ONE CORRECT READING (Decided by Jess Haley, 2026-10-26 [one correct
% reading] and [dataset audit batch 1 and 2] (4), did-schema
% V_eta_go_forward_class_audit.md): "`treatment` rows whose kind, direction or
% unit is chosen from label words carry as v1 with `needs_mapping` rows instead
% of a guessed reading". The temperature, substance and procedure word lists
% that routed a treatment by its label are gone (a "cold-water swim" number is
% not a temperature; "natural eye opening" is no act of the experimenter). What
% stays is what the document states by itself: a term that states its number's
% kind (termNumberKind, above), and a ChEBI substance node, routed by its
% recorded location ([treatment routes by location], jTreatmentRoute).
if startsWith(lower(node), 'chebi:')
    [manip, route, unplaced] = makeSubstanceManipulation(preBody, variable, notesText, ...
        numberCondition, siteTerm, anchor.base.id);
    if ~isempty(unplaced)
        v2Body = carryAsV1(preBody, jCarryWhy(unplaced));
        return;
    end
    if strcmp(route, 'immersion')
        siteTerm = struct('node', {}, 'name', {});   % a bath is no site on the subject
    end
else
    v2Body = carryAsV1(preBody, ['needs_mapping: manipulation (dose | exposure | ' ...
        'temperature | term) or observation; decided by the treatment''s meaning ' ...
        'in its dataset']);
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
