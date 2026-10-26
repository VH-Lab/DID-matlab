function bodies = jMeasurementFold(preBody, variable, hay, numValue, strValue, anchor, wordBoundary)
%JMEASUREMENTFOLD The shared did_v1 measurement -> typed subject_observation fold.
%
%   BODIES = jMeasurementFold(PREBODY, VARIABLE, HAY, NUMVALUE, STRVALUE, ANCHOR)
%   returns {OBSERVATION, ANCHOR} when the measurement can be typed honestly, and
%   {} when it cannot -- the caller then passes its document through. Extracted
%   verbatim from `migrators_j/measurement.m` so `subjectmeasurement` ROUTES
%   THROUGH THE EXISTING FOLD instead of growing a parallel copy of it (the
%   sign-off: "routes through the existing `measurement` fold with NO new class").
%
%   The two callers differ in exactly three ways, all of them arguments:
%
%     measurement          variable = the resolved CURIE + its label
%                          hay      = CURIE + label
%                          anchor   = jSessionAnchor(preBody, 'during')
%     subjectmeasurement   variable = the free-text `measurement` string
%                          hay      = that same free text
%                          anchor   = jAbsoluteReference(preBody, datestamp)
%                                     -- the measurement instant is a document,
%                                        not a field (team, 2026-08-06)
%
%   THE ANCHOR IS BUILT BY THE CALLER AND HANDED IN, and it is emitted ONLY on
%   the success paths. A passthrough returns {} and the anchor is discarded, so
%   no time_reference is ever stranded pointing at a document that did not fold.
%
%   WHAT FOLDS, AND WHAT DELIBERATELY DOES NOT
%     a number whose dimension jQuantityLeaf can name -> <leaf>_observation
%     a CURIE-shaped string value                     -> term_observation
%     anything else                                   -> {} (carried through)
%
%   Date of birth is the important member of that last group and it is not an
%   oversight: there is no `date_observation` leaf in V_eta and a birth date is
%   arguably a property of the subject ENTITY rather than an observation of it.
%   `treatment.m` routes it out of its tier for the same reason.
%
%   THE UNIT IS NOT ASSERTED. Neither source class carries a units field --
%   `measurement` has {ontologyName, name, numeric_value, string_value} and
%   `subjectmeasurement` has {measurement, value, datestamp} -- so `source_unit`
%   is left blank and the quantity composite's canonical slot (kilograms /
%   celsius / meters / seconds) is LEFT ABSENT rather than filled with a number
%   in an unknown scale. All four canonical slots are `mustBeNonEmpty: false`,
%   so an absent canonical value validates; a wrong one would not be detectable.
%
%   preBody       the post-universalRenames source body.
%   variable      the subject_statement.variable ontology_term.
%   hay           lowercased haystack for the leaf lookup.
%   numValue      the numeric value ([] when the source has none).
%   strValue      the string value ('' when the source has none).
%   anchor        the time_reference body this observation will depend on.
%   wordBoundary  passed to jQuantityLeaf (see its header).
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.

if nargin < 7 || isempty(wordBoundary)
    wordBoundary = false;
end

bodies = {};

leaf = '';
if isnumeric(numValue) && ~isempty(numValue) && isfinite(numValue(1))
    leaf = jQuantityLeaf(hay, wordBoundary);
end

% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): each fold below
% writes ONE value. A source that states a second one -- a string beside the
% number a quantity leaf takes, a number beside the CURIE a term takes, or a
% number with more than one element (only the first was read) -- is not
% folded: {} is returned, so the caller carries the document whole as v1.
hasNumber = isnumeric(numValue) && ~isempty(numValue);
hasString = ~isempty(strValue) && ~(ischar(strValue) && isempty(strtrim(strValue)));
unplaced = '';
if hasNumber && numel(numValue) > 1
    unplaced = sprintf('a numeric value of %d elements', numel(numValue));
elseif ~isempty(leaf) && hasString
    unplaced = 'the string value beside the numeric value';
elseif isempty(leaf) && looksLikeCURIE(strValue) && hasNumber
    unplaced = 'the numeric value beside the term value';
end
if ~isempty(unplaced)
    cn = '';
    if isfield(preBody, 'document_class') && isfield(preBody.document_class, 'class_name')
        cn = char(preBody.document_class.class_name);
    end
    did2.convert.reportNote('carried_as_v1', cn, sourceId(preBody), ['unplaced: ' unplaced]);
    return;
end

% did-schema #88: built through did2.build (jStatement): the `observation`
% direction with the value kind as its mixin.
entityId = jDependency(preBody, 'subject_id');
if isempty(leaf) && looksLikeCURIE(strValue)
    obs = jStatement(preBody, 'observation', entityId, variable, ...
        did2.build.term(strValue, ''), 'TimeReferenceIds', {anchor.base.id}, ...
        'Id', sourceId(preBody), 'ValueKind', 'term');
    bodies = {obs, anchor};
    return;
end
if isempty(leaf)
    return;
end
obs = jStatement(preBody, 'observation', entityId, variable, ...
    jQuantity(leaf, double(numValue(1)), '', 'approximate', false), ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', sourceId(preBody), 'ValueKind', leaf);
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
