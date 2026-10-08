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

if isempty(leaf) && looksLikeCURIE(strValue)
    % the value IS an ontology term (the consumer's nested-CURIE branch)
    obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
        {}, variable, {'subject_id'});
    obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
    obs.term = struct('value', jOntologyTerm(strValue, ''));
    bodies = {obs, anchor};
    return;
end

if isempty(leaf)
    % No honest leaf -- date of birth, an untyped number, or free prose. The
    % caller carries the document through; the unconverted-document counter
    % makes that visible.
    return;
end

obs = jStartInteraction(preBody, [leaf '_observation'], 'subject_observation', ...
    {leaf}, variable, {'subject_id'});
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.subject_statement.storage_mode = 'inline';
% unit deliberately unstated -- see the header.
obs.(leaf) = struct('value', struct('source_unit', '', ...
    'source_value', double(numValue(1)), 'approximate', false));
bodies = {obs, anchor};
end

% ===================== small helpers =======================================

function tf = looksLikeCURIE(s)
tf = ~isempty(s) && ischar(s) ...
    && ~isempty(regexp(char(s), '^[A-Za-z_][A-Za-z0-9_]*:\S+$', 'once'));
end
