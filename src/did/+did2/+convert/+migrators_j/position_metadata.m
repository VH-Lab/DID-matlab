function bodies = position_metadata(preBody)
%POSITION_METADATA Brainstorm-J migrator: did_v1 position_metadata -> carried
%   whole as v1, until its position element is mapped. 1 -> 1.
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   ================ [position and its metadata are one statement] ==========
%   Decided by Jess Haley, 2026-10-27 (did-schema
%   V_eta_go_forward_class_audit.md, answering did-schema #147): "this shouldn't
%   be a term observation ... Both v1 position and position metadata should map
%   to the same v2 position observation"; a v1 position element's values and
%   its `position_metadata` map to ONE V2 `calculation` with the `position`
%   value-kind mixin (the Haley V2 import's shape): `units` the value's unit,
%   `dimensions` the axis terms, `ontologyNode` the body part in the variable;
%   "no term observation is written. Until position elements are mapped
%   (carry-063) both stay carried together."
%
%   So this migrator NO LONGER WRITES THE TERM OBSERVATION it wrote before
%   (the "FOLD B" below, kept as the record of what was replaced): every
%   position_metadata is carried whole as v1. One that states `units` or
%   `dimensions` (every writer document) cites carry-053, as before; one that
%   states only an `ontologyNode` was the term observation's input and is now
%   carried too, with no register row yet (its marker says `none`). The values
%   live on the element, which this one-document migrator cannot see, so the
%   one calculation is built where the element is mapped, not here. Beside its
%   element (type `position`, carried, carry-063) v1_to_v2 also carries it for
%   that (carry-064).
%
%   The term-observation inverse, did2.convert.roundtrip.position_metadata, is
%   reached by no migrator output any more; a carried document's round trip is
%   the carry itself (did2.convert.roundtrip.check).
%
%   ============================ AMBIGUITY FLAG ============================
%   The V_eta position_metadata stub carries NO numeric value field, and the
%   position VALUES are genuinely absent from THIS document. Investigation of
%   the real did_v1 source (NDI-matlab +ndi/+setup/+conv/+haley/doImport.m,
%   Step 6) shows the numeric coordinates (xPosition,yPosition timeseries)
%   ride in a SEPARATE ndi.element.timeseries document -- the one `element_id`
%   points at -- NOT in the position_metadata body. The position_metadata body
%   holds only three DESCRIPTIVE ontology fields:
%       ontologyNode  (v1) -> measurement : WHAT kind of position (e.g. the
%                             C. elegans head/midpoint/tail body part CURIE)
%       units              -> units       : the value unit CURIE (e.g. pixels)
%       dimensions         -> dimensions  : per-axis coordinate-column CURIEs
%   There is NO values/coordinate array anywhere in this document.
%
%   Because there are NO numeric values to fold, emitting a length/position
%   leaf with a value would be INVENTING data. Per the honest-minimal rule we
%   take FOLD B: a single `term_observation` of the element-subject whose
%   spine variable is 'position' (the kind of measurement) and whose leaf
%   `value` is the measurement ontology_term (the v1 `ontologyNode` CURIE).
%   This records WHAT was measured about the subject without fabricating the
%   where. The element-subject is taken from the `element_id` dependency
%   (element dissolved to subject, D2; probe_location idiom).
%
%   DEFERRED / UNDER-SPECIFIED (NDI second pass): (a) the `units` term and the
%   per-axis `dimensions` descriptors are dropped here -- they annotate the
%   coordinate COLUMNS that live in the linked element/timeseries body, which
%   this subject-interaction fold does not carry; (b) the human-readable name
%   of the measurement CURIE is left '' (resolved via ndi.ontology.lookup at
%   the reconciliation pass); (c) binding the recorded position to its actual
%   numeric coordinate body is a Path-S / element-graph job. The class is
%   under-specified for any value-bearing leaf from this document alone.
%   =======================================================================
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI position_metadata.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8, as +setup/+conv/+haley/doImport.m
%   writes it: ontologyNode the body part, units 'NCIT:C48367', dimensions
%   'NCIT:C44477,NCIT:C44478'). Every v1 field and where it went until
%   [position and its metadata are one statement] (2026-10-27; since then every
%   document is carried whole as v1, see above, and
%   testRawV1RoundTripPosition checks the carry):
%
%     base.id, session_id, datestamp   -> the observation's
%     base.name                        -> not written (the writer leaves '')
%     depends_on element_id            -> the observation's entity_id
%     position_metadata.ontologyNode   -> the value term's node
%     position_metadata.units,         -> no place: the document is carried
%       position_metadata.dimensions      whole as v1 (carry-053). The writer
%                                         sets both, so every writer document
%                                         is carried.
%
%   A document stating no ontologyNode has nothing to observe. Before the
%   switch it passed through as a V2 `position_metadata` (a class whose
%   disposition is `retire`), which NDI's final step stamps v1 again
%   ([passthrough stays v1: how]); it is now carried as v1 at once (no register
%   row yet), the same end state. No NDI writer at the locked main writes one. What the
%   renamed path would have discarded is carried,
%   carry-049, as before; a field or edge no part of this migrator reads now
%   carries the document whole as v1 (private/jRawAccount, jRawCarry; no
%   register row yet). The JH writer's documents also hang off an element of
%   type `position`, which is carried (carry-063), so v1_to_v2 carries them
%   for that too (carry-064, [dependents of a carried document carry]).
arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above)
src = preBody;
[preBody, collision, unplacedRaw] = jRawAccount(src, ...
    struct('position_metadata', {{'ontologyNode', 'units', 'dimensions'}}), ...
    {'^element_id$', '^subject_id$'});
if jRawCarry('position_metadata', src, collision, unplacedRaw, 'carry-100')
    bodies = {src};
    return;
end

blk = struct();
if isfield(preBody, 'position_metadata') && isstruct(preBody.position_metadata)
    blk = preBody.position_metadata;
end

% measurement CURIE: v1 `ontologyNode`; `ontology_node` is the spelling
% universalRenames gives it, which this migrator still meets on the renamed path
% (v1_to_v2 'RawV1Classes', {}) until that pass is deleted
node = jGetChar(blk, 'ontologyNode');
if isempty(node); node = jGetChar(blk, 'ontology_node'); end

if isempty(node)
    % no measurement term to record: never invent an observation. Carried
    % whole as v1, where NDI's last step put the renamed path's passthrough
    % carry-register: none (a position_metadata naming no measurement)
    did2.convert.reportNote('carried_as_v1', 'position_metadata', ...
        char(preBody.base.id), 'unplaced: position_metadata (no ontologyNode: no measurement to observe)');
    bodies = {src};
    return;
end

% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): the observation has
% no place for the v1 `units` and `dimensions` (DEFERRED (a) above), so a
% document that states either is carried whole as v1 for the dataset's map.
unplaced = {};
for f = {'units', 'dimensions'}
    v = [];
    if isfield(blk, f{1}); v = blk.(f{1}); end
    if ~isempty(v) && ~(ischar(v) && isempty(strtrim(v)))
        unplaced{end+1} = ['position_metadata.' f{1}]; %#ok<AGROW>
    end
end
if ~isempty(unplaced)
    % carry-register: carry-053
    did2.convert.reportNote('carried_as_v1', 'position_metadata', ...
        char(preBody.base.id), ['[carry-053] unplaced: ' strjoin(unplaced, ', ')]);
    bodies = {src};
    return;
end

% [position and its metadata are one statement] (Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): "no term observation is
% written"; the metadata and its element's values become one position
% calculation, built where the element is mapped (carry-063), so until then
% the document is carried whole as v1 with its element. This replaces the term
% observation (variable 'position', value the ontologyNode) written here before.
% The decision makes this the same carry as `units` / `dimensions` above (both
% become the one position calculation), so it cites the same row.
% carry-register: carry-053
did2.convert.reportNote('carried_as_v1', 'position_metadata', ...
    char(preBody.base.id), ['[carry-053] awaiting_home: position_metadata.ontologyNode ' ...
    '(one position calculation with its element''s values, [position and its ' ...
    'metadata are one statement])']);
bodies = {src};
end
