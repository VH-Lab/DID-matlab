function v2Body = openminds_subject(preBody)
%OPENMINDS_SUBJECT Brainstorm-J migrator: did_v1 openminds_subject -> an `assertion`
%   with value kind `term`.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Brainstorm J does NOT store the bundled openMINDS document (J:92): it is
%   redundant with, and decomposes into, component assertions on the subject.
%   openMINDS survives as vocabulary (the terms) + a query-time projection,
%   never as a stored bundle.
%
%   In the corpus each `openminds_subject` is a SINGLE openMINDS controlled-term
%   entity about a subject -- a `Species`, `Strain`, `GeneticStrainType`, or
%   `BiologicalSex` -- carrying its ontology id in `fields.preferredOntologyIdentifier`
%   and pointing at the subject via the `subject_id` dependency. Each therefore
%   becomes ONE `term_assertion` on that subject (a subject typically has
%   several: species + strain + sex ...). The openMINDS entity `type` names the
%   asserted `variable` (species/strain/sex -- the D9 kind-variables); the
%   ontology id + label are the term `value`. 1 -> 1.
%
%   (openminds_element / openminds_stimulus decompose the same way, but onto the
%   element-/stimulus-subject, so they are handled with the element retirement /
%   stimulus phases where those referents become subjects.)
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-30; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (metadata/openminds_subject.json + openminds.json +
%   base.json at the locked NDI-matlab `main`, 441530d; written by
%   ndi.database.fun.openMINDSobj2ndi_document with dependency type 'subject':
%   the `openminds` block, an empty `openminds_subject` block, the
%   `subject_id` edge, and the `openminds` / `openminds_<n>` edges to its
%   openMINDS children). Its blocks are snake_case already (`fields` is nested
%   and never renamed), so the raw read changes nothing the assertion holds.
%   The `openminds_<n>` edges are not written to the assertion, as before; they
%   are accounted for because NDI's second pass reads them from the v1 input
%   (ndi.migrate.internal.subjectStrainAssembly, which assembles a Strain's
%   children). What the renamed path would have discarded is carried,
%   carry-100, [rename clashes are malformed]; a block, base field or edge outside the template, or
%   anything in the empty `openminds_subject` block (a DID-side fixture shape
%   that holds the openMINDS fields there is still read, when there is no
%   `openminds` block), carries the document whole as v1 (private/jRawAccount,
%   jRawCarry; [fields outside the template are malformed], carry-100). A
%   carry is the untouched v1 source. did2.convert.roundtrip.openminds_subject
%   rebuilds the v1 document; testRawV1RoundTripOpenminds compares the two.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
OPENMINDS = {'openminds_type', 'matlab_type', 'openminds_id', 'fields'};
if isfield(preBody, 'openminds') && isstruct(preBody.openminds)
    read = struct('openminds', {OPENMINDS}, 'openminds_subject', {{}});
else
    read = struct('openminds_subject', {OPENMINDS});
end
[preBody, collision, unplaced] = jRawAccount(src, read, {'^subject_id$', '^openminds(_\d+)?$'});
if jRawCarry('openminds_subject', src, collision, unplaced, 'carry-100')
    v2Body = {src};
    return;
end

block = struct();
if isfield(preBody, 'openminds') && isstruct(preBody.openminds)
    block = preBody.openminds;                 % the openMINDS mixin holds the data
elseif isfield(preBody, 'openminds_subject') && isstruct(preBody.openminds_subject)
    block = preBody.openminds_subject;
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

% [openMINDS subject leftovers] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): the term's definition and synonyms are not
% stored (read back from the term) and `matlab_type` is notation; "a controlled
% term's `openminds_id` is rebuilt from the term through the registry's
% `equivalent` list ([term equivalents recorded]), and a document whose id does
% not rebuild is carried; a lab-made strain's `openminds_id` goes on the strain
% entity's `global_identifier` as `openminds:<id>`". Pass 1 mints no strain
% entity for an openMINDS subject document (it writes one term assertion); NDI's
% second pass (ndi.migrate.internal.subjectStrainAssembly, NDI-matlab a24ee16a,
% #1107) mints the strain entity from that assertion and writes a lab-made
% strain's id on its `global_identifier`. So a lab-made strain (a Strain with no
% ontology node) converts like any other subject document, and its id is NOT
% checked against the registry here: the decision's build order was "NDI-matlab
% ... first, then DID-matlab (stop carrying ...)". Until a row of
% the registry's `equivalent` column is filled no controlled term's id rebuilds
% (did2.convert.openmindsIdRebuilds), so a controlled term that states an id
% that does not rebuild is carried (register row carry-116).
omId = jGetChar(block, 'openminds_id');
isLabStrain = strcmp(lower(typeSuffix(jGetChar(block, 'openminds_type'))), 'strain') ...
    && isempty(node);
if ~isempty(strtrim(omId)) && ~isLabStrain ...
        && ~did2.convert.openmindsIdRebuilds(node, omId)
    % carry-register: carry-116
    did2.convert.reportNote('carried_as_v1', 'openminds_subject', char(preBody.base.id), ...
        sprintf(['[carry-116] awaiting_home: openminds_id "%s" does not rebuild from ' ...
        'term "%s" through the registry''s equivalent list ([openMINDS subject ' ...
        'leftovers])'], omId, node));
    v2Body = {src};   % a carry is the untouched v1 source
    return;
end

% term_assertion: a timeless subject_assertion leaf (no method/interaction).
% did-schema #88: a term_assertion built through did2.build, id preserved.
body = jStatement(preBody, 'assertion', jSubjectOf(preBody, {'subject_id'}), ...
    variable, valueTerm, 'Id', char(preBody.base.id), 'ValueKind', 'term');
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
