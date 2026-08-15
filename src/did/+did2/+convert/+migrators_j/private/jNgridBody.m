function [body, datumType, sourceDatumType] = jNgridBody(preBody, statementId, name, axisLabels)
%JNGRIDBODY did_v1 `ngrid` block -> a V_eta `sampled_body`, bound to a statement.
%
%   BODY = JNGRIDBODY(PREBODY, STATEMENTID, NAME) reads the did_v1 `ngrid` block
%   off PREBODY and returns ONE `sampled_body` document whose `statement` edge
%   points at STATEMENTID.
%
%   [BODY, DATUMTYPE, SOURCEDATUMTYPE] = JNGRIDBODY(...) also returns the ngrid's
%   element encoding, normalised. IT IS RETURNED RATHER THAN WRITTEN because
%   `datum_type` lives on the STATEMENT (signed sec.5) and this helper mints the
%   BODY -- the caller owns the statement and is the only one that can set it.
%   Returning it is what stops the encoding being silently dropped when `datum`
%   went away: `ngrid.data_type` is real source data ('ubit1' for a logical
%   mask), not a derivable. BODY = JNGRIDBODY(..., AXISLABELS) names the axes from
%   a cellstr or a comma-separated char instead of the positional default.
%
%   THE CALLER ATTACHES THE BYTES (body.files / body.file), the same division of
%   labour jSampledBody already uses -- the raster file is declared on the
%   CONSUMER class (`ontologyImage.ngrid` in ontologyImage.json's file_list), not
%   on `ngrid` itself, so only the caller knows which files are the grid's.
%
%   THE CALLER ALSO OWNS THE SUBJECT. This helper mints a body and nothing else;
%   it never mints a statement and never reads a subject edge. That is deliberate:
%   the team's decision is "an ngrid document becomes a sampled_body, and the
%   sampled_body needs a corresponding subject_statement", and WHICH statement
%   differs per consumer (an image_observation for ontologyImage; a
%   subject_calculation leaf for the RF family). A helper that guessed would be
%   making a model decision at the wrong altitude.
%
%   STATUS 2026-08-11: written in a container with neither MATLAB nor Octave, so
%   not one line below has been executed. CI is the first run. Every factual
%   claim in this header is read from NDI `origin/main`, this repo's sources or
%   the did-schema working tree, with the command named inline.
%
%   ---------------------------------------------------------------------
%   THE did_v1 GROUND TRUTH, AND THE ONE WRITER
%   ---------------------------------------------------------------------
%   $ git show origin/main:src/ndi/ndi_common/database_documents/data/ngrid.json
%       "ngrid": { "data_size":"", "data_type":"", "data_dim":"", "coordinates":"" }
%       superclasses [base];  NO depends_on;  NO files
%   $ git grep -l 'mat2ngrid' origin/main -- '*.m'      # DENOMINATOR: 1002 .m files
%       +ndi/+fun/+data/mat2ngrid.m        <- the definition
%       +ndi/+setup/+NDIMaker/imageDocMaker.m:121   <- the ONE caller
%
%   mat2ngrid sets exactly those four and nothing else:
%       data_size   = props.bytes/numel(x)   bytes PER ELEMENT
%       data_type   = class(x)               ('ubit1' for logical)
%       data_dim    = size(x)
%       coordinates = [(1:d1)'; (1:d2)'; ... ; (1:dn)']   when nargin == 1
%
%   ---------------------------------------------------------------------
%   THE MAPPING, AND WHERE IT COMES FROM
%   ---------------------------------------------------------------------
%   V_eta_image_model_plan.md, R4 (audit re-audit, signed 2026-08-08):
%
%       "ngrid -> phases into sampled_body like every other carrier"
%
%   and the same document's per-descriptor table:
%
%       ngrid.data_type   -> the datum's dtype
%       ngrid.data_dim    -> one axis entry per dimension
%       ngrid.coordinates -> axes[k].values
%       ngrid.data_size   -> DROPPED (bytes-per-element restates the dtype)
%
%   Built here against the shape `sampled_body` ACTUALLY has today, which is not
%   the shape that table describes -- see the guard below. Concretely:
%
%       datum.kind    'array'          an ngrid is an N-D grid by definition
%       datum.dtype   data_type        verbatim; 'ubit1' included, it is NDI's
%                                      own spelling for logical and inventing a
%                                      translation here would lose that
%       datum.shape   data_dim         the intra-datum extent
%       datum.unit    ''               an ngrid carries no unit; the meaning
%                                      rides on the statement's `variable`
%       sample_time   regular, n = 1   an ngrid has NO time axis. One datum,
%                                      t0 = dt = 0. (Contrast image_stack, whose
%                                      v1 block declares dimension_order/T, so it
%                                      really does have frames to count.)
%       axes[k]       one per dim      name (labelled or positional), kind
%                                      'index', length data_dim(k), regularity
%                                      'regular', spacing 1, unit ''
%       data_size     NOT EMITTED      per the plan
%
%   `datum.kind` is one of {scalar, array, record} -- an enum, checked:
%     $ python3 -c "import json;d=json.load(open('schemas/V_eta/draft/ \
%           sampled_body.json'));print([f['constraints'] for f in \
%           d['fields'] if f['name']=='datum'][0])"   # via the datum subfields
%     'array' is admissible.
%
%   STALE AS OF 2026-08-14 AND CORRECTED HERE. This said "`axes[].name` is the
%   ONLY sub-field declared mustBeNonEmpty TRUE". There is no `name` sub-field
%   any more: the signed axis entry requires `variable` and `n`. Positional
%   variables (`axis_1` ...) are still emitted when no labels are supplied, for
%   the same reason -- a blank required field quarantines the body it describes.
%
%   ---------------------------------------------------------------------
%   THE COORDINATES GUARD -- WHY THIS REFUSES INSTEAD OF FOLDING
%   ---------------------------------------------------------------------
%   The plan sends `ngrid.coordinates` to `axes[k].values`. THAT FIELD NOW
%   EXISTS -- the sentence here said it did not, and that was true until
%   2026-08-14. Re-read from the built schema set, which is what the old note
%   asked the next reader to do:
%
%     $ python3 -c "import json;d=json.load(open('schemas/V_eta/draft/ \
%           sampled_body.json'));print([s['name'] for f in d['fields'] \
%           if f['name']=='axes' for s in f['fields']])"
%       ['variable', 'unit', 'source_unit', 'approximate', 'n', 'regular',
%        'origin', 'spacing', 'values', 'labels']
%
%   SO THE REFUSAL BELOW IS NOW A DEFERRAL, NOT A NECESSITY, and it stays for a
%   different reason than the one it was written for: retiring `ngrid` is gated
%   on BOTH its consumers (#46/#48) and folding real positions without carrying
%   them would DELETE them. When the carry lands, this guard goes with it.
%
%   No `values`, no `coordinates`. That is #45 (the data_body tier), which is
%   BLOCKED ON #32 -- V_eta_ngrid_family_findings.md F3b records the same gap and
%   names the repair as not decided and not built.
%
%   So a fold today has nowhere to put real coordinate positions. Emitting the
%   body anyway would delete them -- which is EXACTLY the deletion that
%   +migrators_j/+super/ngrid.m was written to stop, arriving through a different
%   door. `data_size` is dropped because it is derivable; `coordinates` is not.
%
%   THE FOLD IS THEREFORE CONDITIONAL, and the condition is losslessness:
%
%     - coordinates ABSENT or EMPTY            -> fold. Nothing to lose.
%     - coordinates == the DEFAULT INDEX VECTOR -> fold. `mat2ngrid`'s nargin==1
%       path builds [(1:d1)'; ...; (1:dn)'], which carries no information beyond
%       `data_dim` -- and `data_dim` is stored, as `datum.shape` and as the axis
%       lengths. This is the shape every ontologyImage document has, because the
%       one in-tree caller passes a single argument (imageDocMaker.m:121).
%     - ANYTHING ELSE                          -> ERROR. `mat2ngrid(X,c1,...,cn)`
%       is a documented signature that stores REAL positions, so this is a shape
%       the format admits; we simply cannot represent it yet. Quarantining is
%       visible, a silent drop is not.
%
%   THE ASYMMETRY IS THE POINT. "No corpus we looked at has real coordinates" is
%   a fact about today's writers and about a SAMPLE OF DATASETS -- it is not a
%   licence to delete the field. The guard converts that from a standing risk
%   into a loud, dated failure the moment such a document arrives.
%
%   See also: jSampledBody, did2.convert.migrators_j.super.ngrid,
%             did2.convert.migrators_j.ontology_image

% Positional, with `arguments` used only for the shape check every other
% migrators_j entry point makes. No text validators: nothing else in this
% package uses one, and a lone `mustBeTextScalar` would be the only thing in the
% converter tying it to a MATLAB release floor.
arguments
    preBody     (1,1) struct
    statementId
    name
    axisLabels  = {}
end

if ~isfield(preBody, 'ngrid') || ~isstruct(preBody.ngrid)
    error('did2:convert:ngridBlockMissing', ...
        ['jNgridBody was asked to fold a document with no `ngrid` block. The ' ...
         'caller must check for the block before folding -- a body invented ' ...
         'from an absent block is a husk, which is the failure this family has ' ...
         'already paid for twice.']);
end
block = preBody.ngrid;

% The V_delta output shape cannot come from a did_v1 document; +super/ngrid.m
% makes the same refusal for the same reason and with the same identifier, so a
% body that somehow reached here past it still cannot be folded from names NDI
% has never written.
vdeltaOnly = intersect({'dim_sizes', 'ndims'}, fieldnames(block));
if ~isempty(vdeltaOnly)
    error('did2:convert:ngridVDeltaShape', ...
        ['ngrid block presents the V_delta output shape (%s), which no did_v1 ' ...
         'document has: NDI declares exactly {data_size, data_type, data_dim, ' ...
         'coordinates}. Check that the fixture was built from the writer and ' ...
         'not from a DID-side schema.'], strjoin(vdeltaOnly, ', '));
end

dataDim  = numericRow(fieldOr(block, 'data_dim', []));
dataType = charOr(block, 'data_type', '');

% ---- THE COORDINATES GUARD (see the header) --------------------------------
coords = fieldOr(block, 'coordinates', []);
if ~isLosslessCoordinates(coords, dataDim)
    error('did2:convert:ngridCoordinatesHaveNoHome', ...
        ['ngrid document "%s" carries EXPLICIT coordinate positions ' ...
         '(%d value(s) for data_dim [%s]), and `sampled_body.axes[]` has no ' ...
         'slot to receive them: it declares {name, kind, length, regularity, ' ...
         'spacing, unit} and no coordinate array. The decided destination is ' ...
         '`axes[k].values` (V_eta_image_model_plan.md R4), which belongs to the ' ...
         'data_body tier (#45) and is BLOCKED ON #32. Folding anyway would ' ...
         'delete real positions -- the same silent loss +super/ngrid.m exists ' ...
         'to stop. `mat2ngrid(X,c1,...,cn)` is a documented signature, so this ' ...
         'document is well-formed and it is the MODEL that cannot hold it yet. ' ...
         'Refusing loudly instead.'], ...
        sourceId(preBody), numel(coords), num2str(dataDim));
end

% ---- the body ---------------------------------------------------------------
% `unit` is blank by construction: an ngrid is a bare numeric grid, and its
% meaning rides on the owning statement's `variable` (the R4 principle -- "a
% raw-numeric observation with no dimensioned meaning is valued by a bare
% self-describing sampled_body"). data_size is NOT carried.
% `datum` IS GONE (signed sec.5). What it carried:
%   dtype -> RETURNED to the caller for subject_statement.datum_type
%   kind  -> the axis COUNT, which axes[] states directly
%   shape -> [axes.n] in array order
%   unit  -> the value's unit comes from `variable`
[datumType, sourceDatumType] = jDatumType(dataType);

% `sample_time` IS NO LONGER WRITTEN. It was already vestigial here and said so
% in its own words -- "an ngrid declares no time axis at all, so t0 and dt are
% zero rather than invented", with n = 1 meaning "one datum", not one sample.
% Three of its four sub-fields were placeholders, and the fourth restated a
% cardinality the axes below already carry. The signed model retires the block
% (step 5); this writer had nothing in it to migrate.
body = jSampledBody(char(statementId), baseField(preBody, 'session_id', ''), ...
    baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'), ...
    char(name), struct());

% Assigned in its own statement, NOT inside struct(...): a non-scalar struct
% value passed to struct() would distribute into a struct ARRAY of bodies
% instead of becoming one field. image_stack.m documents the same trap.
axesArray = ngridAxes(dataDim, axisLabels);
body.sampled_body.axes = axesArray;
end

% ===================== the coordinates test ================================

function tf = isLosslessCoordinates(coords, dataDim)
%ISLOSSLESSCOORDINATES True when dropping `coords` loses nothing.
%
%   Two admissible cases, and NOTHING ELSE is guessed at:
%     (1) absent/empty -- there is nothing to drop;
%     (2) exactly `mat2ngrid`'s nargin==1 default, [(1:d1)'; ...; (1:dn)'],
%         which is fully recoverable from data_dim.
%
%   Deliberately NOT tolerant. A near-miss (right length, different values) is a
%   REAL coordinate vector that happens to be the same size, and treating it as
%   default would delete it. Length-only checking is how "0 empty edges" got
%   printed for two days.
tf = false;
if isempty(coords)
    tf = true;
    return;
end
if ~isnumeric(coords) || isempty(dataDim) || any(dataDim < 1)
    return;
end
expected = zeros(sum(dataDim), 1);
at = 0;
for k = 1:numel(dataDim)
    n = dataDim(k);
    expected(at + (1:n)) = (1:n)';
    at = at + n;
end
c = double(coords(:));
tf = numel(c) == numel(expected) && isequal(c, expected);
end

% ===================== builders ============================================

function ax = ngridAxes(dataDim, axisLabels)
%NGRIDAXES One axis entry per dimension of `data_dim`.
%
%   REWRITTEN 2026-08-14 FOR THE SIGNED AXIS ENTRY (DID-schema
%   TEAM-SIGN-OFF [data_body] + AMENDMENT 1). The old shape
%   {name, kind, length, regularity, spacing, unit} NO LONGER EXISTS. This was
%   the ONLY live writer of `sampled_body.axes` in the repository, so it is also
%   the only thing that had to move -- but it had to move in the SAME change,
%   because `variable` and `n` are mustBeNonEmpty and a body written in the old
%   shape quarantines outright. DID-schema's own test said so before either half
%   landed: "jNgridBody fills `name` and leaves the rest defaulted, so a new
%   requirement quarantines every folded body."
%
%   THE MAPPING, and every value is one the guard above has already checked:
%       name      -> variable   the label IS the variable (the plan's own point:
%                               'contrast' and 'orientation' are variables, and a
%                               free-text name beside a bound term is the escape
%                               hatch that makes the binding pointless)
%       length    -> n
%       regularity-> regular (a boolean now, not an enum of two strings)
%       spacing 1 -> spacing.value 1, and origin.value 1
%       kind/unit -> GONE. `kind` was one of three unrelated fields of that
%                    name; `unit` is now a bound ontology_term and an index axis
%                    has none, so it is left absent rather than blank.
%
%   `origin` IS NEW AND IS REQUIRED WHEN REGULAR, and 1 is the honest value: the
%   guard has established the coordinates are MATLAB's default index vector,
%   which starts at 1. The old shape could not say this at all -- it had no
%   origin -- so a reader had to assume it by convention. That gap is exactly
%   what the signed entry closes.
%
%   THE COORDINATE CARRY IS STILL NOT DONE. `axes[].values` now EXISTS, so the
%   refusal above (`did2:convert:ngridCoordinatesHaveNoHome`) is a DEFERRAL
%   rather than a necessity -- but retiring `ngrid` is gated on BOTH its
%   consumers (#46/#48) and is not this change. Folding real positions without
%   carrying them would DELETE them, which is what that guard exists to stop.
labels = normaliseLabels(axisLabels);
ax = struct('variable', {}, 'n', {}, 'regular', {}, 'origin', {}, 'spacing', {});
for k = 1:numel(dataDim)
    nm = sprintf('axis_%d', k);
    if k <= numel(labels) && ~isempty(labels{k})
        nm = labels{k};
    end
    ax(end+1) = struct( ...
        'variable', jOntologyTerm('', nm), ...
        'n',        dataDim(k), ...
        'regular',  true, ...
        'origin',   struct('value', 1, 'source_value', 1), ...
        'spacing',  struct('value', 1, 'source_value', 1)); %#ok<AGROW>
end
end

function labels = normaliseLabels(axisLabels)
%NORMALISELABELS Accept a cellstr or a comma-separated char.
%
%   The comma-separated form is NDI's: `reverse_correlation.dimension_labels` is
%   documented as "Comma-separated names for the axes ... (e.g. 'Time, X, Y')".
%   Whitespace is trimmed because that example has spaces after the commas.
labels = {};
if isempty(axisLabels)
    return;
end
if iscell(axisLabels)
    labels = cellfun(@(s) strtrim(char(s)), axisLabels, 'UniformOutput', false);
    return;
end
if ischar(axisLabels) || (isstring(axisLabels) && isscalar(axisLabels))
    parts = strsplit(char(axisLabels), ',');
    labels = cellfun(@strtrim, parts, 'UniformOutput', false);
end
end


% ===================== small readers =======================================

function v = fieldOr(s, nm, dflt)
v = dflt;
if isfield(s, nm)
    v = s.(nm);
end
end

function s = charOr(block, nm, dflt)
s = dflt;
if isfield(block, nm)
    v = block.(nm);
    if ischar(v)
        s = v;
    elseif isstring(v) && isscalar(v)
        s = char(v);
    end
end
end

function v = numericRow(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); end
end

function v = baseField(bodyStruct, nm, dflt)
v = dflt;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, nm) && ~isempty(bodyStruct.base.(nm))
    v = bodyStruct.base.(nm);
end
end

function id = sourceId(preBody)
id = '<no base.id>';
if isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isfield(preBody.base, 'id') && ~isempty(preBody.base.id)
    id = char(preBody.base.id);
end
end
