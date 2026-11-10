function v2Body = openminds_element(preBody)
%OPENMINDS_ELEMENT Brainstorm-J migrator: did_v1 openminds_element -> an `assertion`
%   with value kind `term`.
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
%   `assertion` (value kind `term`) on that element-subject. The openMINDS entity `type` names
%   the asserted `variable`; the ontology id + label are the term `value`. It is
%   a timeless `assertion` (no interaction, no session anchor). 1 -> 1.
%
%   If no openMINDS block is present, the document is carried whole as v1 with
%   a `carried_as_v1` note (carry-146). A `fields.description` is the
%   assertion's `notes`, and an `openminds_id` is not stored ([openMINDS
%   element description in notes], below).
%
%   [openMINDS element description in notes] (Decided by Jess Haley,
%   2026-11-10, did-schema did_v2_go_forward_class_audit.md; carry-128 is no
%   longer cited): a v1 openminds_element's `fields.description` is written to
%   its term assertion's `notes`, and its `openminds_id` is not stored, because
%   an openMINDS export rebuilds it. did2.convert.roundtrip.openminds_element
%   rebuilds both. It replaces [openMINDS element leftovers carried] (Jess
%   Haley, 2026-10-29), which carried such a document whole as v1.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-30; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (metadata/openminds_element.json + openminds.json +
%   base.json at the locked NDI-matlab `main`, 441530d; written by
%   ndi.database.fun.openMINDSobj2ndi_document with dependency type 'element':
%   the `openminds` block, an empty `openminds_element` block, the
%   `element_id` edge and the writer's empty `openminds` edge of a childless
%   term). Its blocks are snake_case already (`fields` is nested and never
%   renamed), so the raw read changes nothing the assertion holds. The
%   migrator reads `element_id`, falling back to `subject_id`. What the
%   renamed path would have discarded is carried, carry-100, [rename clashes are malformed]; a
%   block, base field or edge outside the template (an `openminds_<n>` edge
%   naming a child, which the assertion does not keep and no later pass reads
%   for this class, is one), or anything in the empty `openminds_element` block
%   (a DID-side fixture shape that holds the openMINDS fields there is still
%   read, when there is no `openminds` block), carries the document whole as v1
%   (private/jRawAccount, jRawCarry; [fields outside the template are
%   malformed], carry-100). A carry is the untouched v1 source.
%   did2.convert.roundtrip.openminds_element rebuilds the v1 document;
%   testRawV1RoundTripOpenminds compares the two.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above); an empty edge is never unplaced, so
% the writer's empty `openminds` entry needs no pattern
src = preBody;
OPENMINDS = {'openminds_type', 'matlab_type', 'openminds_id', 'fields'};
if isfield(preBody, 'openminds') && isstruct(preBody.openminds)
    read = struct('openminds', {OPENMINDS}, 'openminds_element', {{}});
else
    read = struct('openminds_element', {OPENMINDS});
end
[preBody, collision, unplaced] = jRawAccount(src, read, {'^element_id$', '^subject_id$'});
if jRawCarry('openminds_element', src, collision, unplaced, 'carry-100')
    v2Body = {src};
    return;
end

block = [];
if isfield(preBody, 'openminds') && isstruct(preBody.openminds)
    block = preBody.openminds;                 % the openMINDS mixin holds the data
elseif isfield(preBody, 'openminds_element') && isstruct(preBody.openminds_element)
    block = preBody.openminds_element;
end
if isempty(block)
    % No openMINDS block: nothing to assert, so the document is carried whole
    % as v1 ([passthrough stays v1], Jess Haley, 2026-10-24) rather than
    % passed through silently under the retire class `openminds_element`
    % ([one folder, final classes only], Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md: a retire class's v2 file is deleted
    % once no v1 document passes through under it). No register row covers a
    % missing block yet (a question for the team).
    % carry-register: carry-146
    did2.convert.reportNote('carried_as_v1', 'openminds_element', sourceIdOf(preBody), ...
        '[carry-146] malformed: no openminds block, so no term to assert ([passthrough stays v1])');
    v2Body = {src};   % a carry is the untouched v1 source
    return;
end

variable = variableForType(jGetChar(block, 'openminds_type'));

flds = struct();
if isfield(block, 'fields') && isstruct(block.fields); flds = block.fields; end

% [openMINDS element description in notes] (Decided by Jess Haley, 2026-11-10;
% see the header): the description is the assertion's notes, and the
% openminds_id is not stored (an openMINDS export rebuilds it)
omDescription = strtrim(jGetChar(flds, 'description'));
noteOpts = {};
if ~isempty(omDescription)
    noteOpts = {'Notes', omDescription};
end
node = firstNonEmpty( ...
    jGetChar(flds, 'preferredOntologyIdentifier'), ...
    jGetChar(flds, 'ontologyIdentifier'), ...
    jGetChar(flds, 'interlexIdentifier'), ...
    jGetChar(flds, 'alternateIdentifier'));
valueTerm = jOntologyTerm(node, jGetChar(flds, 'name'));

% An `assertion` with value kind `term`: timeless (no method/interaction).
% did-schema #88: an `assertion` (value kind `term`) built through did2.build, id preserved.
body = jStatement(preBody, 'assertion', jSubjectOf(preBody, {'element_id', 'subject_id'}), ...
    variable, valueTerm, 'Id', char(preBody.base.id), 'ValueKind', 'term', noteOpts{:});
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

function id = sourceIdOf(preBody)
%SOURCEIDOF The v1 document's base.id, or '' (did2.convert.v1read.readBase).
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end
