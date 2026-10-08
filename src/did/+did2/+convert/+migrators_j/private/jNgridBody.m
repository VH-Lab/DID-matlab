function [body, datumType, sourceDatumType] = jNgridBody(preBody, statementId, name, axisLabels, opts)
%JNGRIDBODY did_v1 `ngrid` block -> a V_eta `sampled_body`, bound to a statement.
%
%   BODY = JNGRIDBODY(PREBODY, STATEMENTID, NAME) reads the did_v1 `ngrid` block
%   off PREBODY and returns ONE `sampled_body` document whose `statement` edge
%   points at STATEMENTID.
%
%   BODY = JNGRIDBODY(..., 'DataDim', D, 'AxisCoordinates', C) folds ONE SLICE
%   of a multi-quantity grid and CARRIES real coordinate positions. Both are
%   opt-in and both default to the historical behaviour; see "THE COORDINATES
%   GUARD" below, which is now a carry rather than a refusal.
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
%   THE COORDINATES GUARD -- NOW A CARRY, AND WHAT IT STILL REFUSES
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
%   TWO SENTENCES THAT STOOD HERE ARE DELETED RATHER THAN SOFTENED, because
%   left standing they instruct the next reader to keep a refusal the team has
%   lifted. They read: "No `values`, no `coordinates`. That is #45 (the
%   data_body tier), which is BLOCKED ON #32" and "So a fold today has nowhere
%   to put real coordinate positions." BOTH ARE FALSE. They sat THREE LINES
%   BELOW the 2026-08-14 correction that says `axes[].values` exists -- a
%   correction and the claim it corrects, in one comment block, for three days.
%   #45 was SIGNED AND UNBLOCKED on 2026-08-14 (DID-schema CLAUDE.md, the
%   data_body plan entry: "SIGNED AND UNBLOCKED 2026-08-14 -- do not repeat the
%   #32 block"), and the carry is now signed for this family specifically:
%
%     V_eta_ngrid_family_findings.md, TEAM-SIGN-OFF [receptive field fold],
%     jess@walthamdatascience.com / 2026-08-17: "`ngrid.coordinates` folds into
%     `axes[].values`, which now exists; the guard in `jNgridBody.m` lifts from
%     a refusal to a carry."
%
%   WHAT IS *NOT* LIFTED: retiring the `ngrid` class, which stays gated on BOTH
%   its consumers -- that same signature says so in its own "WHAT THIS DOES NOT
%   SIGN" list. This helper folds; it retires nothing.
%
%   THE FOLD IS STILL CONDITIONAL, and the condition is still losslessness. It
%   now has FOUR arms instead of three:
%
%     - coordinates ABSENT or EMPTY            -> fold. Nothing to lose.
%     - coordinates == the DEFAULT INDEX VECTOR -> fold, all axes REGULAR.
%       `mat2ngrid`'s nargin==1 path builds [(1:d1)'; ...; (1:dn)'], which
%       carries no information beyond `data_dim` -- and `data_dim` is stored, as
%       the axis lengths. This is the shape every ontologyImage document has,
%       because the one in-tree caller passes a single argument
%       (imageDocMaker.m:121).
%     - the CALLER SUPPLIES 'AxisCoordinates' AND THEY RECONCILE -> CARRY. Each
%       axis whose vector is the default index vector stays regular; every other
%       axis becomes `regular = false` with its positions in `values`.
%     - ANYTHING ELSE                          -> ERROR, as before.
%
%   WHY THE CARRY NEEDS THE CALLER, AND WHY IT IS *VERIFIED* AND NOT TRUSTED.
%   `coordinates` is ONE FLAT VECTOR. Reading it back needs the segment order,
%   and the order is NOT recoverable from the vector: `mat2ngrid` documents
%   data_dim order, and the Hartley writer does not follow it -- it stores
%   [T(36); X(200); Y(200)] against a data_dim of [200 200 36 2]. A
%   dim-order split of that vector is garbage, and it is garbage that would
%   VALIDATE. So this helper never guesses an order: the caller, which knows its
%   own writer, supplies the per-axis vectors, and this function checks that
%   SOME ordering of them re-concatenates to the stored vector EXACTLY. A caller
%   that got the assignment wrong fails here rather than mislabelling an axis.
%
%   THE ASYMMETRY IS STILL THE POINT. "No corpus we looked at has real
%   coordinates" is a fact about today's writers and about a SAMPLE OF DATASETS.
%   The remaining refusal keeps an unsegmentable vector a loud, dated failure
%   instead of a silent deletion.
%
%   'DataDim' IS THE OTHER OPT-IN, and it exists for the same document. A
%   `hartley_calc` grid is [200 200 36 2] where the trailing 2 is not an axis
%   but TWO QUANTITIES sharing a volume (the signed model: one body per plane).
%   The caller passes the ONE-PLANE dims; without it this helper would emit a
%   fourth axis of length 2 describing a dimension the body does not contain.
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
    % OPT-IN, both default to the historical behaviour.
    %   DataDim         the dims of ONE slice, when the grid stacks several
    %                   quantities on a trailing dimension. [] = use the block's.
    %   AxisCoordinates 1xN cell (N == numel(DataDim)), the coordinate vector
    %                   for each axis in DataDim order; {} or [] per entry means
    %                   "this axis has none". Supplying it is what turns the
    %                   coordinates guard from a refusal into a carry, and it is
    %                   VERIFIED against `ngrid.coordinates` before it is used.
    opts.DataDim         = []
    opts.AxisCoordinates = {}
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

% The caller may fold ONE SLICE of a multi-quantity grid; then the block's own
% data_dim describes the whole stack and the caller's describes this body.
if ~isempty(opts.DataDim)
    dataDim = numericRow(opts.DataDim);
end

% ---- THE COORDINATES GUARD (see the header) --------------------------------
% Three outcomes: DROP (the coordinates carry nothing beyond data_dim), CARRY
% (the caller supplied a segmentation and it reconciles), REFUSE (anything else).
coords = fieldOr(block, 'coordinates', []);
axisCoords = normaliseAxisCoordinates(opts.AxisCoordinates, dataDim);
if isLosslessCoordinates(coords, dataDim)
    % Nothing to carry: absent, or exactly the default index vector. Every axis
    % is regular, which is what the DROP arm has always produced. A caller that
    % nonetheless supplied coordinates is honoured -- they can only be the
    % default ones, and a default vector reduces to a regular axis anyway.
    axisCoords = repmat({[]}, 1, numel(dataDim));
elseif coordinatesReconcile(coords, axisCoords)
    % CARRY. Verified, not trusted: some ordering of the caller's per-axis
    % vectors re-concatenates to the stored vector exactly.
else
    error('did2:convert:ngridCoordinatesHaveNoHome', ...
        ['ngrid document "%s" carries EXPLICIT coordinate positions ' ...
         '(%d value(s) for data_dim [%s]) that this fold cannot account for. ' ...
         '`axes[].values` EXISTS and the carry is signed ' ...
         '(V_eta_ngrid_family_findings.md, TEAM-SIGN-OFF [receptive field ' ...
         'fold], 2026-08-17), so this is no longer "the model cannot hold it" ' ...
         '-- it is that the stored vector cannot be SEGMENTED. `coordinates` ' ...
         'is one flat vector and its segment order is not recoverable from it: ' ...
         '`mat2ngrid` documents data_dim order and the Hartley writer stores ' ...
         '[T; X; Y] against a data_dim of [X Y T 2]. The caller must pass ' ...
         '''AxisCoordinates'' (%d supplied, %d value(s) between them), and ' ...
         'they must re-concatenate to the stored vector exactly. Splitting it ' ...
         'here on a guessed order would mislabel axes in a document that ' ...
         'validates -- a silent loss, which is the same failure ' ...
         '+migrators_j/+super/ngrid.m exists to stop. Refusing loudly instead.'], ...
        sourceId(preBody), numel(coords), num2str(dataDim), ...
        sum(~cellfun(@isempty, axisCoords)), ...
        sum(cellfun(@numel, axisCoords)));
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
    char(name));

% Assigned in its own statement, NOT inside struct(...): a non-scalar struct
% value passed to struct() would distribute into a struct ARRAY of bodies
% instead of becoming one field. image_stack.m documents the same trap.
axesArray = ngridAxes(dataDim, axisLabels, axisCoords);
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

function out = normaliseAxisCoordinates(raw, dataDim)
%NORMALISEAXISCOORDINATES One cell entry per dimension, [] where none is given.
%
%   Length is checked against `dataDim` HERE rather than being trusted later: a
%   vector of the wrong length for the axis it is assigned to is a caller bug,
%   and it would otherwise surface as an axis whose `n` and `values` disagree --
%   a body that validates and lies.
out = repmat({[]}, 1, numel(dataDim));
if isempty(raw)
    return;
end
if ~iscell(raw)
    raw = {raw};
end
if numel(raw) ~= numel(dataDim)
    error('did2:convert:ngridAxisCoordinateCount', ...
        ['jNgridBody was given %d AxisCoordinates entr(ies) for %d ' ...
         'dimension(s). One entry per dimension is required, in data_dim ' ...
         'order; pass [] for an axis that has no stored positions.'], ...
        numel(raw), numel(dataDim));
end
for k = 1:numel(raw)
    v = raw{k};
    if isempty(v); continue; end
    if ~isnumeric(v)
        error('did2:convert:ngridAxisCoordinateType', ...
            'AxisCoordinates{%d} is %s; coordinate positions must be numeric.', ...
            k, class(v));
    end
    v = double(v(:));
    if numel(v) ~= dataDim(k)
        error('did2:convert:ngridAxisCoordinateLength', ...
            ['AxisCoordinates{%d} has %d value(s) but dimension %d has ' ...
             'extent %d. An axis whose `n` and `values` disagree is a body ' ...
             'that validates and lies.'], k, numel(v), k, dataDim(k));
    end
    out{k} = v;
end
end

function tf = coordinatesReconcile(coords, axisCoords)
%COORDINATESRECONCILE Do the caller's per-axis vectors ACCOUNT for the stored one?
%
%   True when SOME ordering of the supplied vectors concatenates to `coords`
%   exactly. The order is searched rather than assumed because the stored order
%   is the WRITER's and differs between writers -- `mat2ngrid` uses data_dim
%   order, the Hartley writer stores [T; X; Y] against [X Y T 2].
%
%   EXACT, never tolerant. A near-miss (right lengths, different values) is a
%   real coordinate vector that happens to be the same size, and accepting it
%   would carry one axis's positions under another axis's name. Length-only
%   checking is how "0 empty edges" got printed for two days.
%
%   The search is over the supplied vectors only (at most one per dimension, so
%   at most a handful), and it stops at the first exact match. A permutation
%   that also matches must produce the same values by construction -- it can
%   only permute vectors that are equal to each other.
tf = false;
supplied = axisCoords(~cellfun(@isempty, axisCoords));
if isempty(supplied); return; end
c = double(coords(:));
if sum(cellfun(@numel, supplied)) ~= numel(c); return; end
tf = anyOrderMatches(c, supplied);
end

function tf = anyOrderMatches(c, supplied)
%ANYORDERMATCHES Depth-first over which vector comes next in the stored one.
tf = false;
if isempty(supplied)
    tf = isempty(c);
    return;
end
for k = 1:numel(supplied)
    v = supplied{k};
    n = numel(v);
    if n > numel(c); continue; end
    if ~isequal(c(1:n), v); continue; end
    rest = supplied;
    rest(k) = [];
    if anyOrderMatches(c(n+1:end), rest)
        tf = true;
        return;
    end
end
end

% ===================== builders ============================================

function ax = ngridAxes(dataDim, axisLabels, axisCoords)
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
%   THE COORDINATE CARRY IS DONE, 2026-08-17. The sentence that stood here
%   ("THE COORDINATE CARRY IS STILL NOT DONE ... Folding real positions without
%   carrying them would DELETE them") was the third statement in this one file
%   asserting a block that had been lifted; it is replaced rather than softened,
%   because a reader acting on it would re-instate a refusal the team removed.
%   An axis whose caller-supplied vector is the DEFAULT INDEX VECTOR still comes
%   out regular -- carrying [1..n] as `values` would store, per document, a
%   vector `n` already states.
%
%   IT IS BUILT WITH jAxis, NOT WITH struct(...), AND THAT IS NOT COSMETIC.
%   `axes` is a struct ARRAY and MATLAB concatenates struct arrays only when the
%   operands share a field set AND its order. Before the carry every entry had
%   the same five fields, so an ad-hoc struct was safe; now a regular axis and
%   an irregular one differ in which of {origin, spacing, values} carry
%   anything, and building them by hand would throw on exactly the mixed case
%   this fold produces (two regular index axes beside one irregular lag axis).
%   jAxis exists for that: every field always present, in the schema's own
%   declaration order, unset ones carrying the declared blank.
labels = normaliseLabels(axisLabels);
if nargin < 3 || isempty(axisCoords)
    axisCoords = repmat({[]}, 1, numel(dataDim));
end
% An EMPTY struct array with jAxis's exact field set, so a zero-dimension grid
% yields `axes = <0x0 struct>` rather than `[]`. Built by emptying a real entry
% rather than by naming the ten fields again -- a second list of them would be a
% second thing to keep in step with the signed axis entry.
ax = jAxis(jOntologyTerm('', 'axis_0'), 0);
ax(:) = [];
for k = 1:numel(dataDim)
    nm = sprintf('axis_%d', k);
    if k <= numel(labels) && ~isempty(labels{k})
        nm = labels{k};
    end
    v = [];
    if k <= numel(axisCoords); v = axisCoords{k}; end
    if isempty(v) || isDefaultIndexVector(v)
        % REGULAR. `origin` 1 is the honest value and not a default: either
        % there are no stored positions at all, or they have been checked to be
        % MATLAB's default index vector, which starts at 1.
        entry = jAxis(jOntologyTerm('', nm), dataDim(k), ...
            'regular', true, ...
            'origin',  struct('value', 1, 'source_value', 1), ...
            'spacing', struct('value', 1, 'source_value', 1));
    else
        % IRREGULAR. `values` is REQUIRED iff not regular; origin/spacing stay
        % blank, because a stored vector that is not an arithmetic progression
        % has neither. `source_values` repeats them: nothing was converted, and
        % saying so explicitly is cheaper than a reader wondering.
        entry = jAxis(jOntologyTerm('', nm), dataDim(k), ...
            'regular', false, ...
            'values',  struct('values', v, 'source_values', v));
    end
    ax(end+1) = entry; %#ok<AGROW>
end
end

function tf = isDefaultIndexVector(v)
%ISDEFAULTINDEXVECTOR Exactly (1:n)', the vector `n` already states.
%
%   EXACT, like every other test in this file. A vector that starts at 1 and
%   steps by 1 but is stored as slightly different doubles is a real coordinate
%   vector and is carried.
tf = isequal(double(v(:)), (1:numel(v))');
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
