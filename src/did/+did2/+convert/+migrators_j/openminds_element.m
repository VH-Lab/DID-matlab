function v2Body = openminds_element(preBody)
%OPENMINDS_ELEMENT Brainstorm-J migrator: did_v1 openminds_element -> term_assertion.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Brainstorm J does NOT store the bundled openMINDS document (J:92): it is
%   redundant with, and decomposes into, component assertions on the referent.
%   openMINDS survives as vocabulary (the terms) + a query-time projection,
%   never as a stored bundle.
%
%   openminds_element mirrors openminds_subject EXACTLY: each openMINDS
%   controlled-term entity is a SINGLE assertion, carrying its ontology id in
%   `fields.preferredOntologyIdentifier` and pointing at its referent by a
%   dependency. The ONLY difference is the referent: an openminds_element is an
%   openMINDS entity ABOUT AN ELEMENT/DEVICE, so the subject is carried from the
%   `element_id` dependency (falling back to `subject_id`) rather than from
%   `subject_id` directly -- the element concept is dissolved (D2) and its
%   referent is a `subject` (device-as-subject). Each therefore becomes ONE
%   `term_assertion` on that element-subject. The openMINDS entity `type` names
%   the asserted `variable`; the ontology id + label are the term `value`. It is
%   a timeless subject_assertion (no interaction, no session anchor). 1 -> 1.
%
%   If no openMINDS block is present the document is carried unchanged.

arguments
    preBody (1,1) struct
end

block = [];
if isfield(preBody, 'openminds') && isstruct(preBody.openminds)
    block = preBody.openminds;                 % the openMINDS mixin holds the data
elseif isfield(preBody, 'openminds_element') && isstruct(preBody.openminds_element)
    block = preBody.openminds_element;
end
if isempty(block)
    v2Body = {preBody};                        % no openMINDS block: carry unchanged
    return;
end

variable = variableForType(jGetChar(block, 'openminds_type'));

flds = struct();
if isfield(block, 'fields') && isstruct(block.fields); flds = block.fields; end
node = firstNonEmpty( ...
    jGetChar(flds, 'preferredOntologyIdentifier'), ...
    jGetChar(flds, 'ontologyIdentifier'), ...
    jGetChar(flds, 'interlexIdentifier'), ...
    jGetChar(flds, 'alternateIdentifier'));
valueTerm = jOntologyTerm(node, jGetChar(flds, 'name'));

% term_assertion: a timeless subject_assertion leaf (no method/interaction).
body = struct();
body.document_class = struct('class_name', 'term_assertion', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'subject_assertion', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
% referent is the ELEMENT-subject: element_id first, subject_id as fallback.
body.depends_on = jCarrySubject(preBody, {'element_id', 'subject_id'});
if isfield(preBody, 'base') && isstruct(preBody.base)
    body.base = preBody.base;
end
body.subject_statement = struct('variable', variable, 'storage_mode', 'inline');
body.term_assertion = struct('value', valueTerm);
v2Body = {body};
end

% ===================== local helpers ===================================

function variable = variableForType(omType)
%VARIABLEFORTYPE The asserted variable named by the openMINDS entity type. The
%   type is a URL/identifier ending in the entity name (.../types/Species). Known
%   subject kinds map to the D9 kind-variable label; anything else falls back to
%   a de-camel-cased suffix so no assertion is silently mis-named.
suffix = lower(typeSuffix(omType));
switch suffix
    case 'species';           name = 'species';
    case 'strain';            name = 'strain';
    case 'geneticstraintype'; name = 'genetic strain type';
    case 'biologicalsex';     name = 'biological sex';
    case 'sex';               name = 'biological sex';
    case 'phenotype';         name = 'phenotype';
    otherwise;                name = deCamel(typeSuffix(omType));
end
variable = jOntologyTerm('', name);
end

function s = typeSuffix(omType)
s = char(omType);
if isempty(s); s = 'openminds entity'; return; end
parts = strsplit(s, {'/', '#', ':'});
parts = parts(~cellfun('isempty', parts));
if ~isempty(parts); s = parts{end}; end
end

function out = deCamel(s)
%DECAMEL "GeneticStrainType" -> "genetic strain type".
s = char(s);
out = lower(strtrim(regexprep(s, '([a-z0-9])([A-Z])', '$1 $2')));
if isempty(out); out = 'openminds entity'; end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end
