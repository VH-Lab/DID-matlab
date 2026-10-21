function bodies = image_stack(preBody)
%IMAGE_STACK Brainstorm-J migrator: did_v1 image_stack -> a body-backed
%   image_observation + a sampled_body (+ the shared session anchor).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   image_stack / image_stack_parameters are a pre-Brainstorm-I standalone image
%   document (a file-backed pixel blob + geometry bundle tied to a subject). It
%   is the main did_v1 class exercising J's new storage model (§C.4; 7,007 docs
%   in the JH corpus). Strict J has NO imageseries_observation class (§A.9): the
%   discoverable subject-side view is a plain `subject_observation` data-type
%   leaf whose value is body-backed --
%
%       image_observation   the spine handle: subject_id, a shared time anchor, a
%                           placeholder `subject_statement.variable` (the observed
%                           quantity is the linked ontology label, set by a
%                           second-pass join -- see V_eta_discovery_notes.md; NOT
%                           the file format), the inline image geometry on the
%                           `image` mixin, and `storage_mode: body` (so the
%                           statement carries no sample_time -- the cadence lives
%                           in the body, D1/§A.7). The prose `label` and the
%                           `format_ontology` file-type are dropped as derivable.
%       sampled_body        the DIGITAL frames: datum (kind/dtype/unit/shape) +
%                           sample_time (t0/dt/n) + the carried pixel bytes;
%                           `statement` -> the image_observation it belongs to.
%       session_relative_reference   the ordinal 'during' anchor (a v1 image
%                           stack carries a bare timestamp+clocktype, not a DAQ
%                           epoch -- the same honest fallback the treatment fold
%                           uses).
%
%   1 -> 3. The V_zeta `_i` fold also minted an element / element_epoch /
%   daqreader / ingested-frames quartet; in J the element_epoch + ingested pair
%   collapses into the one `sampled_body`, and the NDI-side imaging element /
%   daqreader infrastructure is left to the NDI second pass (D2: pass-1 migrators
%   populate no individuated element referent).
%
%   NOTE: image_observation and the *_body classes are `draft` in V_eta -- the
%   broader imageseries/dataseries/timeseries_observation branch this supersedes
%   is retired with the NDI-side ingest work, not here.
%
%   STATUS 2026-08-11 (second edit of the day) -- the `document_id` edge is now
%   CARRIED on the fold arm, as `ontology_table_row_id`. NOTHING IN THIS REPO
%   WAS EXECUTED for it: the session that made it has neither MATLAB nor Octave,
%   so neither testMigratorsJ nor any corpus was run locally. Every claim below
%   is read out of NDI `origin/main`, this repo's sources, the did-schema
%   working tree, or `git log`, and the commands are named inline so each one is
%   re-runnable. CI is the gate, and the carry was PROVEN there by mutation,
%   one mutation per run, on throwaway branches:
%
%       CONTROL     31463389188  259d4ca  SUCCESS   (this code, unmutated)
%       MUTATION A  31463723277  305bf07  FAILURE   carry deleted ->
%           2 FAILED of 885 RUN
%           testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot
%           testImageStackDocumentIdReferentSurvivesTheBatch
%       MUTATION B  31463724722  b03a411  FAILURE   carry made UNCONDITIONAL
%           (a blank edge when the source has none) ->
%           2 FAILED of 885 RUN
%           testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank
%           testImageStackBlankDocumentIdIsOmittedNotCarriedThrough
%
%   Both directions are covered, which is the point of two mutations rather
%   than one: A proves the tests see the carry, B proves they see the
%   CONDITION. The throwaway branches are claude/v-eta-imgstack-carry-mut-a
%   and -mut-b in BOTH repos (did-schema needs a same-named branch because
%   test-migrators-quick.yml checks the schema set out by ref name); they are
%   not deletable with these credentials and want cleaning up by hand.
%
%   ---------------------------------------------------------------------
%   THE `document_id` EDGE WAS DROPPED ON THE FOLD ARM. IT IS NOT ANY MORE.
%   ---------------------------------------------------------------------
%   The original header said, verbatim: "The legacy `document_id` dependency (a
%   corpus reference-integrity orphan) is dropped." THE REFERENT RESOLVES TODAY.
%   Three facts, each read from a writer rather than inferred from a search that
%   came back empty:
%
%   1. THE REFERENT IS AN `ontologyTableRow` DOCUMENT, not a loose id.
%      +setup/+conv/+haley/doImport.m:233-237 builds the behaviour-plate rows
%      with `tableDocMaker.table2ontologyTableRowDocs`, which constructs
%      `ndi.document('ontologyTableRow', ...)` (tableDocMaker.m:221), and takes
%      their `.id` into `plate_id`; the four subject-carrying imageStack sites
%      (:430, :464, :480, :499) set `document_id` to exactly that id. For the
%      behaviour arm that row IS the plate, carrying its OD600 / CFU / lawn
%      volume / arena covariates (behaviorPlateVariables, doImport.m:101-106).
%
%   2. AN `ontologyTableRow` NEVER CARRIES A `subject_id`. `tableDocMaker` has
%      exactly one `set_dependency_value` call in the whole file and it is
%      `document_id` (tableDocMaker.m:231) -- and not one of doImport.m's NINE
%      `table2ontologyTableRowDocs` calls (200, 234, 295, 351, 533, 688, 741,
%      757, 855) even passes `dependencyVariable`, the option that would reach
%      it. So the guard in +migrators_j/ontology_table_row.m --
%      `isempty(resolvedSubject(preBody))` -- fires and the row PASSES THROUGH
%      (`bodies = {preBody}`) with `base.id` untouched.
%
%   3. EVERY OTHER PATH OF THAT MIGRATOR PRESERVES THE ID TOO. All five of its
%      return points end in `preserveSourceId` or in `{preBody}`, so whichever
%      table a row belongs to -- encounter map, patch-geometry map, per-column
%      fan-out, or either passthrough -- the source id survives on exactly one
%      emitted body. `testOntologyTableRowPreservesSourceIdOnFirstBody` and
%      `testEncounterMapPreservesSourceId` already gate that.
%
%   TIMELINE, which is the whole story:
%
%       $ git log -1 --format='%ad %h %s' --date=short 1207c10
%       2026-07-10 1207c10 Add J image_stack migrator: body-backed ...
%       $ git log -1 --format='%ad %h %s' --date=short ef58c15
%       2026-07-29 ef58c15 ontology_table_row: preserve the source id on ...
%
%   The justification was written on 2026-07-10 and the mechanism that
%   invalidates it landed on 2026-07-29. It was true when written and has been
%   stale for the nineteen days since. It is NOT re-derivable from a corpus run:
%   the edge is dropped, so it can neither orphan nor be counted, and a green
%   orphan gate says nothing about it either way.
%
%   WHY WAS THE EDGE STILL DROPPED AFTER THAT? BECAUSE THERE WAS NOWHERE TO PUT
%   IT. `image_observation` and its seven ancestors -- subject_observation,
%   subject_interaction, subject_statement, base, image, data_type, data --
%   declared SIX `depends_on` slots between them: subject_id, time_reference_#,
%   instrument_id, software_id, method_parameters_id, derived_from_#. Not one
%   of them means "the metadata row that gives this image its data context".
%   `derived_from_#` is the near miss and it is wrong twice over: it is typed
%   to `subject_statement` (the row migrates to an `ontology_table_row`), and
%   it asserts COMPUTATION, which this is not.
%
%   THE SLOT LANDED (did-schema 6cf31f2, 2026-08-11), so the carry is built:
%
%       $ python3 -c "import json;print(json.load(open( \
%           'schemas/V_eta/draft/image_observation.json'))['depends_on'])"
%       [{'name': 'ontology_table_row_id', 'mustBeNonEmpty': False,
%         'must_refer_to_document_class': 'ontology_table_row', ...}]
%
%   The name is not invented: `stable/ontology_image.json` already declared
%   exactly that edge for the identical relationship.
%
%   THE CARRY IS CONDITIONAL, and that is the load-bearing part. There are
%   EIGHT `ndi.document('imageStack'...)` sites on NDI origin/main, not seven --
%   `git grep -n "ndi\.document('imageStack'" origin/main -- '*.m'` returns
%   doImport.m:421,461,477,496,789,811,827 AND +setup/+conv/+babu/import.m:474.
%   THREE populations, not two, and the fold arm sees TWO of them:
%
%       haley behaviour  doImport.m 421/461/477/496  document_id AND subject_id
%                        -> FOLD ARM, edge present, carried.
%       haley E. coli    doImport.m 789/811/827      document_id only
%                        -> GUARD ARM, passes through intact, keeps the edge
%                           under its did_v1 name (the tombstone declares it).
%       babu             import.m:474                subject_id only, NO
%                        document_id (import.m:478-479) -> FOLD ARM, nothing
%                        to carry, and the ENTRY IS OMITTED rather than
%                        emitted blank.
%
%   OMITTED, NOT BLANK. A blank edge is the invented-empty-edge pattern that
%   put 7,233 documents in the census, and the RequiredDependencies gate is
%   armed. `dependencyValue` returns '' both when the edge is absent and when
%   it is present-and-empty, so both shapes take the same (omitting) branch.
%
%   THE REFERENT IS TYPED CORRECTLY, both fold-arm populations checked against
%   the writer: `dataTable.plate_id{p}` (behaviour, doImport.m:430) is the id
%   of an `ontologyTableRow` built by `table2ontologyTableRowDocs` at
%   doImport.m:234-236, so the schema's `must_refer_to_document_class:
%   ontology_table_row` holds. (The E. coli sites name `imageTable.image_id`,
%   doImport.m:757-759 -- also an ontologyTableRow -- but they never reach here.)
%
%   THE ORPHAN RISK, STATED PLAINLY. In a FULL migration the referent is in the
%   batch: fact 2 above shows the row passes through with its id, and the
%   already-live guard-arm `document_id` edges are the same shape and the same
%   corpus (JH) at 0 orphans. In a DISCOVERY-MODE SUBSET the referent need not
%   be present, and +did2/+validate/references.m reports an orphan for an edge
%   naming a document that is neither in the batch nor in the database --
%   jSessionAnchor's note about exactly this is CORRECT and is not being
%   overridden here. That risk is accepted for the same reason it is accepted
%   for `subject_id` and for the guard arm's own `document_id`: the alternative
%   is losing the edge, and a subset batch orphans on every edge it does not
%   contain, not just this one.
%
%   testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot pins the
%   carry (it is the INVERSION of testImageStackFoldDropsDocumentIdForWantOfASlot,
%   which asserted the drop and could not be left standing).
%   testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank pins the babu
%   population. testImageStackDocumentIdReferentSurvivesTheBatch now runs the
%   REAL emitted edge through did2.validate.references instead of a probe.

arguments
    preBody (1,1) struct
end

params = getBlock(preBody, 'image_stack_parameters');
subjectId = dependencyValue(preBody, 'subject_id');
if isempty(subjectId)
    bodies = {preBody};
    return;
end

% ---- did-schema #88: what the raster IS (#73 review item 51, decided
% 2026-09-25): "a raster goes by what its pixels measure, keyed [y, x,
% (channel)]: JH's microscopy images -> intensity_observation, its masks /
% closest-patch maps -> label_calculation, chosen from the document's label".
% A mask or a map PASSES THROUGH (its v1 tombstone, deprecated/image_stack,
% validates it) -- reported -- because no label_calculation fold has been
% built on #88. (It used to say the reason was the calculation's required
% operating_system_id; that is optional since Jess Haley, 2026-10-21
% [calculation-os-optional], so the unbuilt fold is the only reason left.)
label = getCharField(getBlock(preBody, 'image_stack'), 'label');
if isMaskOrMap(label)
    bodies = {preBody};
    return;
end

stackId   = baseField(preBody, 'id', did.ido.unique_id());
dataType = getCharField(params, 'data_type');
dimOrder = firstNonEmpty(getCharField(params, 'dimension_order'), 'YXCZT');
dimSize  = numVec(getField(params, 'dimension_size'));
if numel(dimSize) < numel(dimOrder)
    bodies = {preBody};   % no extent for a dimension: no honest key
    return;
end

anchor = jSessionAnchor(preBody, 'during');
[datumType, sourceDatumType] = jDatumType(firstNonEmpty(dataType, 'uint16'));
conds = [];
ts = getField(params, 'timestamp');
if isnumeric(ts) && isscalar(ts) && isfinite(ts)
    % the v1 acquisition time is a MATLAB datenum on the named clock; it is
    % kept as written, as a whole-statement condition (no reference document
    % can be built from a datenum without assuming the clock is UTC)
    clk = firstNonEmpty(getCharField(params, 'clocktype'), 'unspecified clock');
    conds = did2.build.condition(jLabel(['acquisition timestamp (' clk ')']), ...
        'Value', double(ts), 'SourceValue', sprintf('%.17g', double(ts)));
end
extra = {};
tableRowId = dependencyValue(preBody, 'document_id');
obs = jStatement(preBody, 'intensity_observation', subjectId, ...
    jLabel('image intensity'), [], ...
    'DataBody', true, 'DatumType', datumType, 'SourceDatumType', sourceDatumType, ...
    'Conditions', conds, 'Notes', label, ...
    'TimeReferenceIds', {anchor.base.id}, 'Id', stackId, extra{:});
if ~isempty(tableRowId)
    % the v1 `document_id` (the ontologyTableRow this image belongs to): #88
    % dropped image_observation's `ontology_table_row_id` edge (#73 item 42)
    % and gives an observation no edge for it; the row is the NDI second
    % pass's to resolve. Reported.
end
% DATUM ORDER 'F': the stack is a MATLAB array in the source's dimension order,
% column-major (a judgment call, recorded in the port report).
o = jOpts(preBody, 'DatumOrder', 'F');
body = did2.build.sampledBody(stackId, imageKeys(dimOrder, dimSize, params), o{:});
if isfield(preBody, 'files'); body.files = preBody.files; end
if isfield(preBody, 'file');  body.file  = preBody.file;  end
bodies = {obs, body, anchor};
end

function tf = isMaskOrMap(label)
l = lower(label);
tf = contains(l, 'mask') || contains(l, 'each pixel''s value is the identifier') ...
    || contains(l, 'label map');
end

function keys = imageKeys(dimOrder, dimSize, params)
unitList = splitScaleUnits(getCharField(params, 'dimension_scale_units'));
names = splitScaleUnits(getCharField(params, 'dimension_labels'));
entries = {};
for k = 1:numel(dimOrder)
    nm = lower(dimOrder(k));
    if k <= numel(names) && ~isempty(names{k}); nm = names{k}; end
    sp = axisResolution(params, dimOrder(k));
    if sp ~= 0
        u = '';
        if k <= numel(unitList); u = unitList{k}; end
        entries{end+1} = jAxis(jOntologyTerm('', nm), dimSize(k), ...
            'regular', true, 'source_unit', u, ...
            'origin',  struct('value', 0, 'source_value', 0), ...
            'spacing', struct('value', sp, 'source_value', sp)); %#ok<AGROW>
    else
        entries{end+1} = jAxis(jOntologyTerm('', nm), dimSize(k), ...
            'regular', true, ...
            'origin',  struct('value', 1, 'source_value', 1), ...
            'spacing', struct('value', 1, 'source_value', 1)); %#ok<AGROW>
    end
end
keys = did2.build.list(entries{:});
end

function r = axisResolution(params, axisChar)
%AXISRESOLUTION The scale (spacing) of the named spatial axis, 0 if absent.
r = 0.0;
order = getCharField(params, 'dimension_order');
scale = numVec(getField(params, 'dimension_scale'));
idx = strfind(upper(order), upper(axisChar));
if ~isempty(idx) && idx(1) <= numel(scale)
    r = scale(idx(1));
end
end

function [clockName, t0] = clockFromParams(params)
clockName = getCharField(params, 'clocktype');
if isempty(clockName); clockName = 'no_time'; end
t0 = 0.0;
ts = getField(params, 'timestamp');
if ~isempty(ts) && isnumeric(ts) && isscalar(ts); t0 = double(ts); end
end

function dt = frameDt(clockName)
%FRAMEDT A unit frame spacing for a clocked stack; 0 for a clockless still.
if strcmp(clockName, 'no_time'); dt = 0.0; else; dt = 1.0; end
end

function n = frameCount(dimOrder, dimSize)
n = 1;
for i = 1:min(numel(dimOrder), numel(dimSize))
    c = upper(dimOrder(i));
    if (c == 'T' || c == 'Z') && dimSize(i) > 0
        n = n * dimSize(i);
    end
end
end

% ===================== small helpers =======================================

function t = otTerm(name)
t = struct('node', '', 'name', name);
end

function b = getBlock(bodyStruct, name)
b = struct();
if isfield(bodyStruct, name) && isstruct(bodyStruct.(name)); b = bodyStruct.(name); end
end

function v = getField(bodyStruct, name)
v = [];
if isfield(bodyStruct, name); v = bodyStruct.(name); end
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v; elseif isstring(v) && isscalar(v); s = char(v); end
end
end

function v = numVec(x)
v = [];
if isempty(x); return; end
if isnumeric(x); v = double(x(:)'); return; end
if ischar(x) || (isstring(x) && isscalar(x))
    parts = strsplit(char(x), {',', ' '});
    for k = 1:numel(parts)
        nn = str2double(parts{k});
        if ~isnan(nn); v(end+1) = nn; end %#ok<AGROW>
    end
end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function v = dependencyValue(bodyStruct, name)
v = '';
if isfield(bodyStruct, 'depends_on') && isstruct(bodyStruct.depends_on)
    for k = 1:numel(bodyStruct.depends_on)
        d = bodyStruct.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value') && ~isempty(d.value)
                v = char(d.value);
            elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                v = char(d.document_id);
            elseif isfield(d, 'id') && ~isempty(d.id)
                v = char(d.id);
            end
            return;
        end
    end
end
end

function v = baseField(bodyStruct, name, default)
v = default;
if isfield(bodyStruct, 'base') && isstruct(bodyStruct.base) ...
        && isfield(bodyStruct.base, name) && ~isempty(bodyStruct.base.(name))
    v = bodyStruct.base.(name);
end
end

function u = splitScaleUnits(raw)
%SPLITSCALEUNITS v1's comma-separated per-axis unit list -> a cell of char.
%   '' yields an empty cell, so every axis falls through to ''. Whitespace
%   around a separator is trimmed: the field is hand-entered in the converters,
%   and 'micrometer, second' must not become ' second'.
u = {};
if isempty(raw); return; end
parts = strsplit(char(raw), ',');
u = cell(1, numel(parts));
for k = 1:numel(parts)
    u{k} = strtrim(parts{k});
end
end
