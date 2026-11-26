function bodies = measurement(preBody)
%MEASUREMENT Brainstorm-J migrator: did_v1 measurement -> an `observation`
%   with value kind `term` (+ the shared session anchor) when its value is a
%   term; everything else (a number, a date, text) is carried whole as v1.
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
%   Only the reading the v1 document states by itself is written ([one
%   correct reading], Jess Haley, 2026-10-26; code audit batch 1 (C3), Jess
%   Haley, 2026-11-26, did-schema did_v2_go_forward_class_audit.md):
%
%     a CURIE string_value -> an `observation` with value kind `term` (the
%                             value IS an ontology term)
%     a number             -> CARRIED WHOLE AS V1 (needs_mapping): the
%                             measurement states no unit and its term states no
%                             quantity kind, so the kind would be chosen from
%                             words in the node or label
%     anything else        -> CARRIED WHOLE AS V1 (a date, text)
%
%   A NUMBER IS NOT TYPED FROM LABEL WORDS. Until 2026-11-26 a number was
%   typed mass / temperature / length / time when its node or label CONTAINED
%   a keyword ('weight', 'mass', 'temperature', 'length', 'age', 'duration',
%   ...; private/jQuantityLeaf, deleted), with no unit. 'age' matched inside
%   'voltage', 'average' and 'dosage'; and a word names a quantity, not the
%   scale of the number. The dataset's map names the kind and the unit.
%
%   DATE OF BIRTH is carried too, and it is not an oversight. There is no
%   `observation` with value kind `date` here, and a birth date is arguably a
%   property of the subject ENTITY rather than an observation of it -- a
%   modelling decision a single-document migrator has no business making.
%
%   `manipulation_id` and `protocol_id` are dropped: no writer on origin/main
%   ever sets either.
%
%   See V_eta_tombstone_audit.md for the evidence.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (measurement.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+setup/+NDIMaker/treatmentMaker.m
%   create_measurement_doc writes it: `ontologyName` the looked-up node, `name`
%   its label, string_value, numeric_value, subject_id). The node is read in v1's
%   spelling `ontologyName` (and universalRenames' `ontology_name` on the
%   renamed path). Every v1 field and where it goes;
%   did2.convert.roundtrip.measurement rebuilds the v1 document and
%   testRawV1RoundTripMeasurement compares the two:
%
%     base.id, session_id, datestamp     -> the observation's
%     base.name                          -> not written (the writer leaves '')
%     depends_on subject_id              -> the observation's entity_id
%     measurement.ontologyName, name     -> the observation's variable
%     measurement.numeric_value          -> none: a number carries the
%                                           document (see above)
%     measurement.string_value           -> a term value, when it is a CURIE
%
%   A manipulation_id or protocol_id that names a document (no writer sets one,
%   above) has no place in the observation: it now carries the document, where
%   the renamed path dropped it. A measurement with no v2 statement (a date, an
%   untyped number, text) passed through before, as a v2 `measurement`
%   (a `retire` class); its raw passthrough would meet that class's renamed
%   field `ontology_name` as an undeclared field, so it is carried as v1 at
%   once (no register row yet), the end state NDI's last step gave the
%   passthrough ([passthrough stays v1: how]). What the renamed path would have
%   discarded is carried, carry-100; a field, block or edge outside the
%   template carries the document, carry-100 (private/jRawAccount, jRawCarry).

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

% THE RAW READ (see READS RAW v1 above); the guard above runs first
src = preBody;
[preBody, collision, unplaced] = jRawAccount(src, struct( ...
    'measurement', {{'ontologyName', 'name', 'numeric_value', 'string_value'}}), ...
    {'^subject_id$', '^manipulation_id$', '^protocol_id$'});
valueReasons = {};
for e = {'manipulation_id', 'protocol_id'}
    if ~isempty(jDependency(preBody, e{1}))
        valueReasons{end+1} = sprintf('depends_on(%s) (no place in the observation)', e{1}); %#ok<AGROW>
    end
end
if jRawCarry('measurement', src, collision, unplaced, 'carry-100', valueReasons)
    bodies = {src};
    return;
end

node  = jGetCharAny(blk, {'ontologyName', 'ontology_name'});
label = jGetChar(blk, 'name');
strValue = jGetChar(blk, 'string_value');
numValue = [];
if isfield(blk, 'numeric_value'); numValue = blk.numeric_value; end

variable = jOntologyTerm(node, label);

anchor = jSessionAnchor(preBody, 'during');
bodies = jMeasurementFold(preBody, variable, numValue, strValue, anchor);
if isempty(bodies)
    % No v2 statement -- a number, a date, or free prose. The anchor built
    % above is discarded with it, so nothing is stranded. Carried as v1 (see
    % READS RAW v1 above), unless jMeasurementFold already carried it
    % (carry-058) and said so.
    if did2.convert.reportNote('pending', 'carried_as_v1') == 0
        if isnumeric(numValue) && isscalar(numValue) && isfinite(double(numValue))
            % code audit batch 1 (C3) (Jess Haley, 2026-11-26, under [one
            % correct reading]): a number whose kind would be chosen from the
            % words of its node or label is carried, not typed. Register row
            % carry-175 covers it (the twin of subjectmeasurement's carry-145).
            % carry-register: carry-175
            did2.convert.reportNote('carried_as_v1', 'measurement', jCarryId(src), ...
                ['[carry-175] needs_mapping: the measurement states no quantity kind or unit ' ...
                 'for its number; the dataset map names them (a quantity is not ' ...
                 'read from label words)']);
        else
            % "a measurement with no statement" is a carry of the kind
            % [values no writer produces are malformed] covers (Jess Haley,
            % 2026-10-27, did-schema V_eta_go_forward_class_audit.md), carry-120
            jRawCarry('measurement', src, {}, {}, 'carry-100', ...
                {'[carry-120] measurement (no v2 statement: a date, an untyped number or text)'});
        end
    end
    bodies = {src};
elseif isscalar(bodies) && isequaln(bodies{1}, preBody)
    bodies = {src};
end
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end
