function bodies = subjectmeasurement(preBody)
%SUBJECTMEASUREMENT Brainstorm-J migrator: did_v1 subjectmeasurement -> the v1
%   document, carried whole as v1 with a note naming why. Routed from
%   did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%
%   SINCE 2026-11-26 NOTHING IS FOLDED (code audit batch 1 (C3), Jess Haley,
%   under [one correct reading], did-schema did_v2_go_forward_class_audit.md):
%   the generic migration carries the document instead of typing its number
%   from words of its free-text name. The fold below (TEAM-SIGN-OFF [subject
%   measurement]) typed the number through a keyword table (mass /
%   temperature / length / time from 'weight', 'age', ...), with no unit; the
%   table is deleted, and `value` is a number (never a term), so no reading
%   remains. A carry cites carry-144 (guards 1-3) or carry-145 (guard 4: the
%   dataset map names the quantity kind). The sign-off's routing (subject_id ->
%   entity_id, `measurement` -> variable, `datestamp` -> the time anchor, NOT a
%   field) is what a dataset's import writes once its map names the kind.
%
%   TEAM-SIGN-OFF (jess, 2026-08-06, V_eta_go_forward_class_audit.md §4):
%
%       subjectmeasurement routes through the existing `measurement` fold with
%       NO new class: subject_id carries over, `measurement` becomes the
%       statement's `variable`, `value` becomes the value, and `datestamp`
%       becomes the statement's TIME ANCHOR (time_reference_1 ->
%       absolute_reference), NOT a field. Known gap, signed with: `value`
%       carries no unit, so the typed leaf must be chosen through the D9
%       registry rather than from the template.
%
%   ---------------------------------------------------------------------
%   THE SOURCE, FROM NDI origin/main -- TEMPLATE AND WRITER AGREE
%   ---------------------------------------------------------------------
%   ndi_common/database_documents/subjectmeasurement.json
%       depends_on: [ subject_id ]                 (schema: mustbenotempty 1)
%       subjectmeasurement: { measurement, value, datestamp }
%
%   ndi_common/schema_documents/subjectmeasurement_schema.json
%       measurement  string     "The name of a measurement that was taken."
%       value        matrix     default [0], parameters [NaN,NaN]
%       datestamp    timestamp  "The timestamp of the measurement."
%
%   There are exactly THREE fields and ONE edge. No units field, no ontology
%   field -- `measurement` is FREE TEXT, unlike its `measurement` sibling whose
%   `ontologyName` is always a resolved CURIE.
%
%   ALL FOUR IN-TREE EMITTERS ARE TEST-SESSION BUILDERS. Verified, not assumed:
%   `git grep -il subjectmeasurement origin/main` returns 9 files -- the
%   template, its schema, ndiDocumentAttributes.json, two notebooks, and four
%   .m files, all four of which are session builders writing the identical row:
%
%       src/ndi/+ndi/+test/+daq/build_intan_flat_exp.m:62-66
%       tests/+ndi/+unittest/+session/buildSession.m:62-66
%       tests/+ndi/+unittest/+session/buildSessionNDRIntan.m:62-66
%       tests/+ndi/+unittest/+session/buildSessionNDRAxon.m:62-66
%           'base.name','Animal statistics',
%           'subjectmeasurement.measurement','age',
%           'subjectmeasurement.value',30,
%           'subjectmeasurement.datestamp','2017-03-17T19:53:57.066Z'
%
%   There is NO production writer in NDI's tree. That is NOT a reason to skip
%   the migrator: THE CORPORA ARE A SAMPLE, older lab scripts could have written
%   these, and a class we cannot migrate is a class that strands.
%
%   ---------------------------------------------------------------------
%   `datestamp` IS A DOCUMENT, NOT A FIELD -- AND THAT IS WHAT MAKES THE
%   FOLD LOSSLESS
%   ---------------------------------------------------------------------
%   `measurement` has NO datestamp field ({ontologyName, name, numeric_value,
%   string_value}). Folding `subjectmeasurement` into it as a plain field
%   mapping would have DROPPED THE MEASUREMENT TIME outright. `base.datestamp`
%   is the record-creation stamp and is a different fact -- the V_eta tombstone
%   says so in as many words ("SHADOWS base.datestamp -- a migrator must
%   disambiguate") -- so it is NOT used as a fallback for the instant.
%
%   Routing the instant to `time_reference_1` -> `absolute_reference` is what
%   keeps the fold lossless, and it is this class that gives `absolute_reference`
%   its first emitter.
%
%   ---------------------------------------------------------------------
%   THE SIGNED GAP: NO UNIT, SO THE LEAF IS GUARDED
%   ---------------------------------------------------------------------
%   `value: 30` for `measurement: 'age'` is 30 of something the document does
%   not say. The leaf was meant to come from the D9 binding registry, which
%   cannot answer it; the keyword stand-in (`jQuantityLeaf`) is deleted
%   (2026-11-26, above), so the number is carried, never typed.
%
%   THE DOCUMENT IS CARRIED. Four guards, in order; the first three name a
%   malformed source (carry-144), the fourth every other document (carry-145):
%
%     1. no subject_id      -> an observation about nobody. This is the
%                              `image_stack` / `fitcurve` failure exactly:
%                              +did2/+validate/references.m:90 SKIPS empty
%                              edges, so a subject-less observation clears the
%                              reference gate AND the quarantine gate, and only
%                              the empty-required-edge census can see it.
%     2. no `measurement`   -> `subject_statement.variable` is mustBeNonEmpty.
%     3. value not a finite scalar -> the quantity composites carry ONE number.
%                              A vector `value` (the template's [NaN,NaN]
%                              parameters permit one) has no scalar cell.
%     4. always since 2026-11-26 -> no quantity kind is read from the name
%                              (code audit batch 1 (C3)); the dataset map
%                              names it.
%
%   The carried document is the untouched v1 source, noted `carried_as_v1`
%   with its register row, so it shows up in the migration report instead of
%   disappearing.
%
%   1 -> 1 (the untouched v1 source).
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 would write it (subjectmeasurement.json + base.json at the
%   locked NDI-matlab `main`, 3cb19a8). NO NDI WRITER AT THAT `main` CONSTRUCTS
%   ONE OUTSIDE ITS TESTS (+ndi/+test/+daq/build_intan_flat_exp.m, tests/
%   buildSession.m: measurement 'age', value 30, a datestamp) AND NO CORPUS
%   HOLDS ONE; the template fixes its shape. Its block is snake_case already and
%   it has no `app` block. Since 2026-11-26 every document is carried
%   (above), so no v1 field is placed;
%   did2.convert.roundtrip.subjectmeasurement still reads the observation the
%   fold wrote (statement.variable, the quantity, the absolute time reference),
%   and testRawV1RoundTripMeasurement checks that a carry round trips.
%
%   What the renamed path would have discarded is carried, carry-100; a field,
%   block or edge outside the template carries the document, carry-100
%   (private/jRawAccount, jRawCarry). A passthrough and a carry return the
%   untouched v1 source.

arguments
    preBody (1,1) struct
end

blk = getBlock(preBody, 'subjectmeasurement');

% Invented-shape guard, the sibling of measurement.m's. These three field names
% belong to `measurement`, NOT to this class -- a body carrying them is a
% fixture built from the wrong sibling (or from the V_alpha snapshot), and
% reading it as a subjectmeasurement would silently produce an empty document.
if isfield(blk, 'ontology_name') || isfield(blk, 'numeric_value') ...
        || isfield(blk, 'string_value')
    error('did2:convert:subjectmeasurementInventedShape', ...
        ['subjectmeasurement body carries `ontology_name`/`numeric_value`/' ...
         '`string_value`, which are `measurement`''s fields. The real ' ...
         'subjectmeasurement fields are `measurement`, `value` and ' ...
         '`datestamp` (NDI origin/main subjectmeasurement.json).']);
end

% THE RAW READ (see READS RAW v1 above); the guard above runs first
[~, collision, unplaced] = jRawAccount(preBody, struct( ...
    'subjectmeasurement', {{'measurement', 'value', 'datestamp'}}), {'^subject_id$'});
bodies = {preBody};
if jRawCarry('subjectmeasurement', preBody, collision, unplaced, 'carry-100')
    return;
end

% ---- guard 1: no subject => no observation ---------------------------------
subjectId = dependencyValue(preBody, 'subject_id');
if isempty(subjectId)
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's v2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. Register row carry-144 covers it.
    % carry-register: carry-144
    did2.convert.reportNote('carried_as_v1', 'subjectmeasurement', jCarryId(preBody), ...
        '[carry-144] malformed: no subject_id, so no observation ([passthrough stays v1])');
    return;
end

% ---- guard 2: no name => no `variable` -------------------------------------
% `measurement` is free text and is the whole of what the statement is ABOUT.
name = getCharField(blk, 'measurement');
if isempty(strtrim(name))
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's v2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. Register row carry-144 covers it.
    % carry-register: carry-144
    did2.convert.reportNote('carried_as_v1', 'subjectmeasurement', jCarryId(preBody), ...
        '[carry-144] malformed: subjectmeasurement.measurement is empty, so no variable ([passthrough stays v1])');
    return;
end

% ---- guard 3: the value must be one finite number --------------------------
value = [];
if isfield(blk, 'value'); value = blk.value; end
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    % [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
    % V_eta_go_forward_class_audit.md): a retire class's v2 file is deleted once no
    % v1 document passes through under it, so this document, left as v1 on purpose,
    % is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
    % 2026-10-24) instead of passing through silently. Register row carry-144 covers it.
    % carry-register: carry-144
    did2.convert.reportNote('carried_as_v1', 'subjectmeasurement', jCarryId(preBody), ...
        '[carry-144] malformed: subjectmeasurement.value is not one finite number ([passthrough stays v1])');
    return;
end

% ---- guard 4: no quantity kind is read from the name -------------------------
% code audit batch 1 (C3) (Jess Haley, 2026-11-26, under [one correct reading],
% did-schema did_v2_go_forward_class_audit.md): the generic migration does not
% type the number from words of the free-text name. Until then the fold
% (private/jMeasurementFold with the keyword table of private/jQuantityLeaf,
% deleted) typed it mass / temperature / length / time when the name held one
% of a few words ('weight', 'age', ...), with no unit. `value` states no unit
% and `measurement` is free text, so no rule that holds for every dataset
% says what quantity the number is: the document is carried whole as v1 and
% the dataset map names the kind ([unnamed measurement kind needs a map]).
% [one folder, final classes only] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): a retire class's v2 file is deleted once no
% v1 document passes through under it, so this document, left as v1 on purpose,
% is carried whole as v1 with a note ([passthrough stays v1], Jess Haley,
% 2026-10-24) instead of passing through silently. Register row carry-145 covers it,
% of kind needs_mapping (Jess Haley, 2026-11-10 [unnamed measurement kind
% needs a map]): the dataset map names the quantity kind.
% carry-register: carry-145
did2.convert.reportNote('carried_as_v1', 'subjectmeasurement', jCarryId(preBody), ...
    ['[carry-145] needs_mapping: the dataset map names the quantity kind for ' ...
     'this measurement name ([unnamed measurement kind needs a map])']);
end

% ===================== small helpers =======================================

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function s = getCharField(block, name)
% char/string ONLY. Deliberately NOT jGetChar, which stringifies a scalar
% numeric: `num2str(737000)` is not a measurement name and not an instant.
s = '';
if isstruct(block) && isfield(block, name)
    v = block.(name);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    end
end
end

function v = dependencyValue(bodyStruct, name)
% Reads BOTH spellings. universalRenames normalises v1's {name, value} to
% {name, document_id} (universalRenames.m:372-380), so which one a body carries
% depends on where it came from. Precedence copied from
% +did2/+validate/references.m:176-179.
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            elseif isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            end
            return;
        end
    end
end
end
