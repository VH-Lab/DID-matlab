function bodies = jMeasurementFold(preBody, variable, numValue, strValue, anchor)
%JMEASUREMENTFOLD The did_v1 measurement -> `observation` fold, for the one
%   reading a measurement states by itself: a term value.
%
%   BODIES = jMeasurementFold(PREBODY, VARIABLE, NUMVALUE, STRVALUE, ANCHOR)
%   returns {OBSERVATION, ANCHOR} when the measurement's value is a term (a
%   CURIE-shaped string value), and {} otherwise -- the caller then carries its
%   document whole as v1. Extracted from `migrators_j/measurement.m`.
%
%   NO VALUE KIND IS READ FROM LABEL WORDS (Jess Haley, 2026-11-26, code audit
%   batch 1 (C3), under [one correct reading], did-schema
%   did_v2_go_forward_class_audit.md: the generic migration stops guessing
%   meaning from label words and carries the v1 document unchanged instead).
%   Until then a number was typed mass / temperature / length / time when the
%   measurement's node or label CONTAINED a keyword ('weight', 'age',
%   'length', ...; private/jQuantityLeaf, now deleted), with no unit: 'age'
%   matched inside 'voltage', 'average' and 'dosage', and even a whole word
%   names a quantity, not the scale of the number. A number is now never
%   folded here: the caller carries the document.
%
%   WHAT FOLDS
%     a CURIE-shaped string value -> an `observation` with value kind `term`
%     anything else               -> {} (carried by the caller)
%
%   THE ANCHOR IS BUILT BY THE CALLER AND HANDED IN, and it is emitted ONLY on
%   the success path. A carry returns {} and the anchor is discarded, so no
%   time_reference is ever stranded pointing at a document that did not fold.
%
%   preBody       the source body.
%   variable      the subject_statement.variable ontology_term.
%   numValue      the numeric value ([] when the source has none).
%   strValue      the string value ('' when the source has none).
%   anchor        the time_reference body this observation will depend on.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

bodies = {};

% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): the fold writes ONE
% value. A source that states a second one -- a number beside the CURIE a term
% takes, or a number with more than one element -- is not folded: {} is
% returned, so the caller carries the document whole as v1.
hasNumber = isnumeric(numValue) && ~isempty(numValue);
unplaced = '';
if hasNumber && numel(numValue) > 1
    unplaced = sprintf('a numeric value of %d elements', numel(numValue));
elseif looksLikeCURIE(strValue) && hasNumber
    unplaced = 'the numeric value beside the term value';
end
if ~isempty(unplaced)
    cn = '';
    if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
        cn = char(preBody.document_class.class_name);
    end
    % [second measurement value needs a map] (Jess Haley, 2026-10-26): carry-058
    % for a measurement, carry-059 for a subjectmeasurement
    row = '';
    if strcmp(cn, 'measurement'); row = '[carry-058] '; end
    if strcmp(cn, 'subjectmeasurement'); row = '[carry-059] '; end
    % carry-register: carry-058 carry-059
    did2.convert.reportNote('carried_as_v1', cn, sourceId(preBody), [row 'unplaced: ' unplaced]);
    return;
end

if ~looksLikeCURIE(strValue)
    return;
end
% did-schema #88: built through did2.build (jStatement): the `observation`
% direction with the value kind as its mixin.
entityId = jDependency(preBody, 'subject_id');
obs = jStatement(preBody, 'observation', entityId, variable, ...
    did2.build.term(strValue, ''), 'TimeReferenceIds', {anchor.base.id}, ...
    'Id', sourceId(preBody), 'ValueKind', 'term');
bodies = {obs, anchor};
end

function id = sourceId(preBody)
% The ONE observation a measurement folds to keeps the source id, as the pre-#88
% fold did (jStartInteraction), so anything naming the measurement still resolves.
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = char(preBody.base.id);
end
end

function tf = looksLikeCURIE(s)
tf = ~isempty(s) && ischar(s) ...
    && ~isempty(regexp(char(s), '^[A-Za-z_][A-Za-z0-9_]*:\S+$', 'once'));
end
