function body = jNgridBody(preBody, statementId, name, axisLabels)
%JNGRIDBODY did_v1 `ngrid` block -> a V_eta `sampled_body`, bound to a statement.
%
%   BODY = JNGRIDBODY(PREBODY, STATEMENTID, NAME) reads the did_v1 `ngrid` block
%   off PREBODY and returns ONE `sampled_body` document whose `statement` edge
%   points at STATEMENTID. BODY = JNGRIDBODY(..., AXISLABELS) names the axes from
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
%   `axes[].name` is the ONLY sub-field of the axis entry declared
%   mustBeNonEmpty TRUE, so a nameless axis would quarantine. Positional names
%   (`axis_1` ...) are emitted when no labels are supplied, rather than blanks.
%
%   ---------------------------------------------------------------------
%   THE COORDINATES GUARD -- WHY THIS REFUSES INSTEAD OF FOLDING
%   ---------------------------------------------------------------------
%   The plan sends `ngrid.coordinates` to `axes[k].values`. THAT FIELD DOES NOT
%   EXIST. Read from the built schema set rather than from the plan:
%
%     $ python3 -c "import json;d=json.load(open('schemas/V_eta/draft/ \
%           sampled_body.json'));print([s['name'] for f in d['fields'] \
%           if f['name']=='axes' for s in f['fields']])"
%       ['name', 'kind', 'length', 'regularity', 'spacing', 'unit']
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
datum = struct('kind', 'array', 'dtype', dataType, 'unit', '', 'shape', dataDim);

% n = 1, not prod(data_dim): the whole grid is ONE datum whose intra-datum
% extent is `shape`. An ngrid declares no time axis at all, so t0 and dt are
% zero rather than invented.
sampleTime = struct('regular', true, ...
    't0', durationComposite(0), 'dt', durationComposite(0), 'n', 1);

body = jSampledBody(char(statementId), baseField(preBody, 'session_id', ''), ...
    baseField(preBody, 'datestamp', '2024-01-01T00:00:00.000Z'), ...
    char(name), datum, sampleTime);

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
%   `axes[].name` is the one sub-field declared mustBeNonEmpty TRUE, so a
%   positional name is emitted when the caller supplies no label -- blank names
%   would quarantine the body they are meant to describe.
%
%   `kind: 'index'` and `spacing: 1` state what the DEFAULT coordinates mean and
%   nothing more. The guard above has already established that the coordinates
%   are indices (or absent), so this is a restatement of a checked fact, not an
%   assumption about the data.
labels = normaliseLabels(axisLabels);
ax = struct('name', {}, 'kind', {}, 'length', {}, ...
    'regularity', {}, 'spacing', {}, 'unit', {});
for k = 1:numel(dataDim)
    nm = sprintf('axis_%d', k);
    if k <= numel(labels) && ~isempty(labels{k})
        nm = labels{k};
    end
    ax(end+1) = struct('name', nm, 'kind', 'index', ...
        'length', dataDim(k), 'regularity', 'regular', ...
        'spacing', 1, 'unit', ''); %#ok<AGROW>
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

function c = durationComposite(seconds)
%DURATIONCOMPOSITE The dimensioned-cell shape image_stack.m already emits.
%   Matched deliberately rather than improved: two spellings of one composite in
%   sibling migrators is the drift T14 exists to prevent.
c = struct('source_unit', 's', 'source_value', double(seconds), 'approximate', false);
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
