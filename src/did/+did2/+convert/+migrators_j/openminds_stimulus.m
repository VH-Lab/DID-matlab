function v2Body = openminds_stimulus(preBody)
%OPENMINDS_STIMULUS Brainstorm-J migrator: did_v1 openminds_stimulus -> term_assertion.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Brainstorm J does NOT store the bundled openMINDS document (J:92): it is
%   redundant with, and decomposes into, component assertions on the subject.
%   openMINDS survives as vocabulary (the terms) + a query-time projection,
%   never as a stored bundle.
%
%   In the corpus each `openminds_stimulus` is a SINGLE openMINDS controlled-term
%   entity ABOUT A STIMULUS -- the stimulus is the subject here -- carrying its
%   ontology id in `fields.preferredOntologyIdentifier` and pointing at the
%   stimulus-subject via the `stimulus_id` dependency. Each therefore becomes ONE
%   `term_assertion` on that stimulus-subject (a stimulus typically has several).
%   The openMINDS entity `type` names the asserted `variable`; the ontology id +
%   label are the term `value`. 1 -> 1.
%
%   Identical decomposition to openminds_subject, only the subject-source
%   dependency differs: the stimulus-as-subject is carried from `stimulus_id`
%   (falling back to `element_id` / `subject_id` when the stimulus referent was
%   already reconciled onto an element or subject in an earlier phase).

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'openminds') && isstruct(preBody.openminds)
    block = preBody.openminds;                 % the openMINDS mixin holds the data
elseif isfield(preBody, 'openminds_stimulus') && isstruct(preBody.openminds_stimulus)
    block = preBody.openminds_stimulus;
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
body.depends_on = jCarrySubject(preBody, {'stimulus_id', 'element_id', 'subject_id'});
if isfield(preBody, 'base') && isstruct(preBody.base)
    body.base = preBody.base;
end
body.subject_statement = struct('variable', variable, 'storage_mode', 'inline');
body.term = struct('value', valueTerm);
v2Body = body;
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
