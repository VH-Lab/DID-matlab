function bodies = measurement(preBody)
%MEASUREMENT Brainstorm-J migrator: did_v1 measurement -> a typed
%   subject_observation leaf (+ the shared session anchor), for the rows that can
%   be typed honestly; everything else is carried through for the second pass.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ---------------------------------------------------------------------
%   WHY THIS CLASS NEEDED A MIGRATOR AND DID NOT HAVE ONE
%   ---------------------------------------------------------------------
%   `measurement` is byte-for-byte the shape of `treatment` -- same four fields,
%   same three dependency names, same superclass -- and `treatment` has had a
%   dissolving migrator all along. This is its OBSERVATION-direction twin:
%
%       measurement: { ontologyName -> ontology_name, name,
%                      numeric_value, string_value }
%       depends_on:  subject_id (always set), manipulation_id, protocol_id
%
%   The coverage ledger listed it `retire` with no migrator, and separately
%   claimed its sibling `subjectmeasurement` had "dissolved into measurement".
%   NDI never performed that dissolution -- `subjectmeasurement` is still shipped
%   and still written by four in-tree emitters -- so BOTH classes were being
%   reported as accounted for while having nowhere to go. Real Babu/Hunsberger
%   date-of-birth and initial-weight rows flow through this pair.
%
%   THE BINDING IS GENUINE. `ontologyName` is always a resolved CURIE: the writer
%   (+ndi/+setup/+NDIMaker/treatmentMaker.m) gets it from `ndi.ontology.lookup`
%   and ERRORS if lookup fails. So `subject_statement.variable` arrives properly
%   bound, unlike its `subjectmeasurement` sibling whose field is free text.
%
%   ---------------------------------------------------------------------
%   WHAT IS FOLDED, AND WHAT IS DELIBERATELY NOT
%   ---------------------------------------------------------------------
%   A numeric value is folded ONLY when the ontology term says which physical
%   quantity it is. V_eta's observation leaves are quantity-typed (T3: leaf =
%   direction x data_type), so a number with no known dimension has no honest
%   leaf -- and inventing one is exactly the class of error this whole repair
%   track exists to undo. So:
%
%     mass / weight        -> mass_observation
%     temperature          -> temperature_observation
%     length / height      -> length_observation
%     age / duration       -> duration_observation
%     a CURIE string_value -> term_observation (the value IS an ontology term)
%     anything else        -> CARRIED THROUGH UNCHANGED
%
%   DATE OF BIRTH is the important member of that last group, and it is not an
%   oversight. There is no `date_observation` leaf in V_eta, and a birth date is
%   arguably a property of the subject ENTITY rather than an observation of it --
%   a modelling decision a single-document migrator has no business making.
%   `treatment.m` already routes date-of-birth OUT of its tier for the same
%   reason. Carrying it through keeps the document intact and visible in
%   `summary.unconverted_by_class`, which is the honest state until the model
%   question is answered.
%
%   The unit is NOT asserted. The class carries no units field, and the ontology
%   term names the quantity, not its scale -- so `source_unit` is left blank for
%   discovery-mode fill-in rather than guessed from the term.
%
%   `manipulation_id` and `protocol_id` are dropped: no writer on origin/main
%   ever sets either.
%
%   See V_eta_tombstone_audit.md for the evidence.

arguments
    preBody (1,1) struct
end

blk = getBlock(preBody, 'measurement');
if isfield(blk, 'measurement_class') || isfield(blk, 'parameters')
    error('did2:convert:measurementInventedShape', ...
        ['measurement body carries `measurement_class`/`parameters`, which no ' ...
         'did_v1 document has -- the real fields are `ontology_name`, `name`, ' ...
         '`numeric_value` and `string_value`. This shape can only come from ' ...
         'the V_alpha snapshot or a fixture built against it.']);
end

node  = jGetChar(blk, 'ontology_name');
label = jGetChar(blk, 'name');
strValue = jGetChar(blk, 'string_value');
numValue = [];
if isfield(blk, 'numeric_value'); numValue = blk.numeric_value; end

variable = jOntologyTerm(node, label);
hay = lower([node ' ' label]);

leaf = '';
if isnumeric(numValue) && ~isempty(numValue) && isfinite(numValue(1))
    if containsAny(hay, {'weight', 'mass'})
        leaf = 'mass';
    elseif containsAny(hay, {'temperature'})
        leaf = 'temperature';
    elseif containsAny(hay, {'length', 'height', 'width', 'diameter'})
        leaf = 'length';
    elseif containsAny(hay, {'age', 'duration', 'elapsed'})
        leaf = 'duration';
    end
end

if isempty(leaf) && looksLikeCURIE(strValue)
    % the value IS an ontology term (the consumer's nested-CURIE branch)
    anchor = jSessionAnchor(preBody, 'during');
    obs = jStartInteraction(preBody, 'term_observation', 'subject_observation', ...
        {}, variable, {'subject_id'});
    obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
    obs.term = struct('value', jOntologyTerm(strValue, ''));
    bodies = {obs, anchor};
    return;
end

if isempty(leaf)
    % No honest leaf -- date of birth, an untyped number, or free prose. Carry
    % it through; the unconverted-document counter makes that visible.
    bodies = {preBody};
    return;
end

anchor = jSessionAnchor(preBody, 'during');
obs = jStartInteraction(preBody, [leaf '_observation'], 'subject_observation', ...
    {leaf}, variable, {'subject_id'});
obs.depends_on(end+1) = struct('name', 'time_reference_1', 'value', anchor.base.id);
obs.subject_statement.storage_mode = 'inline';
% unit deliberately unstated -- the class has no units field and the term names
% the quantity, not its scale.
obs.(leaf) = struct('value', struct('source_unit', '', ...
    'source_value', double(numValue(1)), 'approximate', false));
bodies = {obs, anchor};
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function tf = containsAny(hay, needles)
tf = false;
for k = 1:numel(needles)
    if contains(hay, needles{k}); tf = true; return; end
end
end

function tf = looksLikeCURIE(s)
tf = ~isempty(s) && ~isempty(regexp(char(s), '^[A-Za-z_][A-Za-z0-9_]*:\S+$', 'once'));
end
