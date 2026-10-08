function bodies = subjectmeasurement(preBody)
%SUBJECTMEASUREMENT Brainstorm-J migrator: did_v1 subjectmeasurement -> a typed
%   subject_observation leaf + an `absolute_reference` carrying the measurement
%   instant. Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
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
%   not say. The leaf is meant to come from the D9 binding registry, and the
%   registry cannot answer today -- `binding_registry_meta.json` ships five
%   `subject_statement_bindings`, all of them binding to `term_assertion`, none
%   dimensional. `jQuantityLeaf` is the pass-1 stand-in and is the single place
%   that changes when the registry gains dimensional rows.
%
%   WHEN NOTHING RESOLVES, THE DOCUMENT PASSES THROUGH. Four guards, each of
%   which would otherwise produce a husk that validates clean:
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
%     4. no quantity leaf   -> guessing one is the error this whole track exists
%                              to undo.
%
%   The passthrough is safe: `subjectmeasurement` has a V_eta tombstone in
%   stable/, so the carried document validates under its own class, and it shows
%   up in `summary.unconverted_by_class` instead of disappearing.
%
%   1 -> 2 on the fold path (observation + absolute_reference), 1 -> 1 otherwise.

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

bodies = {preBody};

% ---- guard 1: no subject => no observation ---------------------------------
subjectId = dependencyValue(preBody, 'subject_id');
if isempty(subjectId)
    return;
end

% ---- guard 2: no name => no `variable` -------------------------------------
% `measurement` is free text and is the whole of what the statement is ABOUT.
name = getCharField(blk, 'measurement');
if isempty(strtrim(name))
    return;
end

% ---- guard 3: the value must be one finite number --------------------------
value = [];
if isfield(blk, 'value'); value = blk.value; end
if ~(isnumeric(value) && isscalar(value) && isfinite(value))
    return;
end

% ---- the time anchor -------------------------------------------------------
% The measurement instant is the anchor when the source gives one. When it does
% not, fall back to the ordinal session anchor every other J fold uses --
% `subject_interaction` requires at least one time_reference, so "no anchor at
% all" is not an option, and "during the session" is the honest weaker claim.
% `datestamp` is read WITHOUT numeric stringification: a bare number is not an
% instant this migration can read, so it takes the session-anchor path.
anchor = jAbsoluteReference(preBody, getCharField(blk, 'datestamp'));
if isempty(anchor)
    anchor = jSessionAnchor(preBody, 'during');
end

% ---- route through the EXISTING measurement fold ---------------------------
% Same helper `measurement.m` uses. `variable` has an empty `node` because the
% source has no ontology field to fill it from; `strValue` is '' because `value`
% is typed `matrix`, so the fold's CURIE branch cannot fire here. wordBoundary
% is TRUE -- see jQuantityLeaf: this field is free text, and 'voltage' contains
% the letters 'age'.
variable = jOntologyTerm('', name);
folded = jMeasurementFold(preBody, variable, lower(name), value, '', anchor, true);

% ---- guard 4: no honest leaf => carry the document through ------------------
if isempty(folded)
    return;
end
bodies = folded;
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
