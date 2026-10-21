function bodies = ontology_table_row(preBody)
%ONTOLOGY_TABLE_ROW Brainstorm-J split migrator: did_v1 ontology_table_row
%   -> the subject_statement tier (1 -> N).
%
%   Routed from did2.convert.v1_to_v2 only when TargetVersion == 'V_eta'.
%   Each column of the legacy open key/value table becomes its own statement,
%   classified by TIMELESSNESS then by the value's SHAPE (see
%   did-schema/schemas/V_eta_migration_plan.md Part D and
%   V_eta_discovery_notes.md):
%
%     timeless fact  -> a subject_assertion leaf
%                         species/sex/strain/genotype -> term_assertion
%                         date of birth / a timestamp -> date_assertion
%     timed measure  -> a subject_observation leaf, class by value SHAPE:
%                         numeric -> a data-type leaf (<dim>_observation), the
%                                    dimension chosen from the property term;
%                                    unrecognised a.u. -> intensity_observation
%                                    (J's one dimensionless numeric; NO generic
%                                    escape hatch, D8)
%                         string  -> term_observation (bound term value)
%     identity col   -> skipped (SubjectLocalIdentifier/DocumentIdentifier IS
%                         the subject, not a measurement)
%
%   Brainstorm J puts identity on the spine `variable` (owned by
%   subject_statement), the verb on subject_interaction.method, and the
%   per-sample cadence in subject_interaction.sample_time (D1).
%
%   PER-TABLE MAP DISPATCH (D10/D11). A table whose column SIGNATURE is
%   recognised is migrated by its map instead of the per-column seed: the map
%   resolves which entity each measurement is about (subject_id), mints one
%   shared bounded `time_reference` for a multi-party event, turns reference
%   columns into `directed_relation`s, and drops derived columns. The first map
%   implemented is the JH *C. elegans* encounter (`isEncounterTable` /
%   `applyEncounterMap`): worm behaviours -> worm observations sharing one
%   `session_bounded_reference` window (onset..offset); `BacterialPatchDocument-
%   Identifier` -> a `worm --encountered--> patch` relation on that window; the
%   derived `EncounterIdentifier` dropped; OD600 stays on the patch document.
%   Unmapped tables fall back to the per-column seed below (still knowingly-wrong
%   for qualifiers; retired one table at a time). Dispatch is seeded from the Dab
%   (FPS / EPM) and JH (C. elegans) corpora; the per-table maps grow in discovery
%   mode.
%
%   STATUS 2026-08-11 -- `isPatchGeometryTable` tightened (it was also matching
%   the C. elegans CULTIVATION-PLATE table) and the patch map's 6-measure
%   enumeration made non-lossy. NOTHING IN THIS REPO WAS EXECUTED for that
%   change: the session that made it has no MATLAB, so neither testMigratorsJ
%   nor any corpus was run. The dispatch claim it rests on was settled from the
%   NDI writer and dictionary, not from a run; `test-migrators-quick.yml` and
%   then a JH corpus run are what turn it into a result.
%
%   STATUS 2026-08-11 (second change, same day, ALSO NEVER EXECUTED) -- the
%   bacterial-patch subject's `local_identifier` is no longer the bare
%   `patchID`. See `jPatchLocalId` and the CAUTION note on the patch map below.
%   Team directive, not a design choice made here.

arguments
    preBody (1,1) struct
end

if ~isfield(preBody, 'ontology_table_row') || ~isstruct(preBody.ontology_table_row)
    error('did2:convert:missingBlock', ...
        'ontology_table_row body is missing the ontology_table_row property block.');
end

% --- per-table map dispatch (D10/D11) --------------------------------------
% A table with a recognised column signature is migrated by its per-table map:
% subject resolution (which entity each measurement is about), a shared bounded
% time_reference for multi-party events, references -> directed_relations, and
% derived columns dropped. Unmapped tables fall back to the legacy per-column
% seed below (still knowingly-wrong for qualifiers; retired table by table).
cols = extractColumns(preBody.ontology_table_row);
if isEncounterTable(cols)
    bodies = preserveSourceId(preBody, applyEncounterMap(preBody, cols));
    return;
end
if isPatchGeometryTable(cols)
    bodies = preserveSourceId(preBody, applyPatchGeometryMap(preBody, cols));
    return;
end

% --- GUARD: no resolvable subject => no fabricated statements ---------------
% The per-column fallback seeds every statement through startStatement, which
% calls carrySubject(preBody) -- a scan of the SOURCE document's depends_on for
% a dependency named `subject_id`. The real NDI template declares exactly one
% dependency and it is not that one:
%
%     ndi_common/database_documents/data/ontologyTableRow.json
%     depends_on: [ { "name": "document_id", "value": "" } ]
%
% So the scan never succeeds on a real document and every statement was emitted
% with subject_id = ''. Corpus run #256 measured the cost on Dab alone: 76,766
% observations and assertions -- intensity, count, term, duration, frequency,
% date_assertion, term_assertion -- each recording that SOMETHING was measured
% without recording WHAT. All of it passed validation, because references.m
% skips empty edges and mustBeNonEmpty on depends_on is not enforced.
%
% This is the same defect ontology_label had, and it gets the same treatment:
% carry the document through intact for the NDI second pass, which can see the
% migrated-id graph. `document_id` cannot simply be renamed to `subject_id` --
% it points at the document the row describes, which need not be a subject, and
% minting an unresolvable edge is what turned distance_metadata's non-gating
% quarantine into a GATING orphan failure.
%
% A mapped table (isEncounterTable / isPatchGeometryTable, handled above)
% resolves its subject explicitly and never reaches here.
if isempty(resolvedSubject(preBody))
    bodies = {preBody};
    return;
end

rows = extractRows(preBody.ontology_table_row);
if isempty(rows)
    % Unrecognised layout: carry the document unchanged (the class still exists
    % for discovery-mode fallback) rather than quarantining.
    bodies = {preBody};
    return;
end

anchor = makeSessionAnchor(preBody, 'during');
bodies = {};
usedAnchor = false;
for k = 1:numel(rows)
    [b, isObservation] = migrateRow(preBody, rows{k}, '', anchor.base.id);
    if isempty(b)
        continue;   % skipped column (identity, empty)
    end
    usedAnchor = usedAnchor || isObservation;
    bodies{end+1} = b; %#ok<AGROW>
end
if usedAnchor
    bodies{end+1} = anchor;
end
if isempty(bodies)
    bodies = {preBody};   % every column skipped -> carry unchanged
end
bodies = preserveSourceId(preBody, bodies);
end

function bodies = preserveSourceId(preBody, bodies)
%PRESERVESOURCEID Keep the source document's id on exactly ONE emitted body.
%
%   WHY. This migrator dissolves one document into many. Until now every
%   emitted body got a fresh id, so after migration NOTHING carried the source
%   row's id -- and any document pointing at that row was left pointing at an
%   id that no longer exists. An `ontologyImage` names its row via
%   `ontologyTableRow_id` and needs to follow it to reach its subject, so that
%   edge has to land somewhere real. There is no old-id -> new-id map anywhere
%   in the converter, so id preservation is the ONLY mechanism that can make
%   such an edge resolve.
%
%   This is the lesson the calculator work already paid for: dissolving a
%   referenced document without preserving its id produced 11448 orphans, and
%   preserving it is what fixed them (T10). `must_refer` is existence-only, so
%   a resolvable id is all a referrer needs.
%
%   WHICH BODY. Any of them works as a landing point, because every statement
%   this migrator emits carries `subject_id` -- so a follower lands on one
%   document and reads the subject straight off it, no search. The FIRST
%   emitted body takes it and the rest keep their fresh ids, matching the
%   primary/sibling convention jStartInteraction uses elsewhere in migrators_j.
%
%   EXCEPT when a per-table map already preserved it deliberately --
%   makePatchSubject does, because the encounter relation names that document
%   as its parent. So this checks first and leaves an existing preservation
%   alone; stamping again would mint two documents sharing one id.
%
%   Safe to apply after the bodies are built: no emitted body references
%   another body's id. Internal edges point at the shared time_reference and at
%   the carried subject, never at a sibling statement.
if isempty(bodies); return; end
if ~isfield(preBody, 'base') || ~isstruct(preBody.base) ...
        || ~isfield(preBody.base, 'id') || isempty(preBody.base.id)
    return;
end
srcId = preBody.base.id;
for k = 1:numel(bodies)
    b = bodies{k};
    if isstruct(b) && isfield(b, 'base') && isstruct(b.base) ...
            && isfield(b.base, 'id') && isequal(b.base.id, srcId)
        return;   % a per-table map (or a passthrough) already carries it
    end
end
if isfield(bodies{1}, 'base') && isstruct(bodies{1}.base)
    bodies{1}.base.id = srcId;
end
end

% ===================== per-table map: C. elegans encounter =============
%
%   The JH encounter table (20,411 rows) binds a multi-party event without a
%   trial document (D10/D11): the worm's behaviour measurements land on the
%   worm; onset/offset become ONE shared bounded time_reference (the encounter
%   window); the BacterialPatchDocumentIdentifier becomes a
%   `worm --encountered--> patch` directed_relation carrying that same
%   time_reference; the derived EncounterIdentifier is dropped (= onset rank).
%   OD600 etc. are NOT here -- they live on the referenced patch document.

function tf = isEncounterTable(cols)
tf = ~isempty(colByKey(cols, 'CElegansBehavioralAssay_EncounterIdentifier')) ...
    && ~isempty(colByKey(cols, 'BacterialPatchDocumentIdentifier'));
end

function bodies = applyEncounterMap(preBody, cols)
P = 'CElegansBehavioralAssay_';
wormId  = colVal(cols, 'SubjectDocumentIdentifier');
patchId = colVal(cols, 'BacterialPatchDocumentIdentifier');
onset   = colNum(cols, [P 'EncounterOnsetTime']);
offset  = colNum(cols, [P 'EncounterOffsetTime']);

% one shared bounded time_reference = the encounter window
tref = makeEncounterWindow(preBody, onset, offset);

% behaviour measurements -> worm observations, all sharing the window
%   key suffix -> {direction, value kind}. Onset/offset are the window (not
%   observations); the EncounterIdentifier is derived (dropped).
measures = {
    'DecelerationUponEncounter',            'observation',              'acceleration'
    'MinimumVelocityDuringEncounter',       'observation',              'velocity'
    'PeakVelocityBeforeEncounterOnset',     'observation',              'velocity'
    'MinimumVelocityAfterEncounterOffset',  'observation',              'velocity'
    'PosteriorProbabilityOfExploitation',   'observation',              'score'
    'PosteriorProbabilityOfSensing',        'observation',              'score'
    'RelativeDensityOfEncounteredBacteria', 'observation',              'concentration'
    'RelativeDensityOfCultivationBacteria', 'observation',              'concentration'};

bodies = {};
for i = 1:size(measures, 1)
    c = colByKey(cols, [P measures{i, 1}]);
    if isempty(c); continue; end
    [ok, num] = numericValue(c{1});
    if ~ok; continue; end
    variable = struct('node', '', 'name', c{1}.name);
    bodies{end+1} = makeEncObs(preBody, measures{i, 2}, measures{i, 3}, ...
        variable, num, wormId, tref.base.id); %#ok<AGROW>
end

% the reference: worm --encountered--> patch, on the same window
bodies{end+1} = makeEncounterRelation(preBody, wormId, patchId, tref.base.id);
bodies{end+1} = tref;
end

function body = makeEncObs(preBody, direction, shapeClass, variable, num, wormId, trefId)
% did-schema #88: built through did2.build. The v1 table states no unit, so a
% quantity cell carries only what was written (jQuantity).
if strcmp(shapeClass, 'score')
    v = did2.build.composite('score', 'value', struct('score', num, 'approximate', false));
else
    v = jQuantity(shapeClass, double(num), '', 'approximate', false);
end
body = jStatement(preBody, direction, wormId, variable, v, ...
    'TimeReferenceIds', {trefId}, 'ValueKind', shapeClass);
end

function tref = makeEncounterWindow(preBody, onset, offset)
% did-schema #88: the encounter window is a relative_time_reference onto the
% session entity (`session_bounded_reference` before #73). A start needs a
% clock (rule clock_with_start); the table's onset/offset are seconds into
% the session's recording, read on the device's local clock as NDI's Haley
% import does (ndi.setup.conv.haley.sessionDocuments) -- a CONSERVATIVE
% CHOICE, recorded (the v1 table names no clock).
sec = struct('node', 'om:second-Time', 'name', 'second');
sid = jSid(preBody);
tref = did2.build.relativeTimeReference(sid, 'Relation', 'intervalDuring', ...
    'Clock', 'dev_local_time', ...
    'Start', double(onset), 'StartSourceValue', double(onset), 'StartSourceUnit', sec, ...
    'StartApproximate', false, ...
    'End', double(offset), 'EndSourceValue', double(offset), 'EndSourceUnit', sec, ...
    'EndApproximate', false, ...
    'SessionId', sid, 'CreationTimestamp', jStamp(preBody), 'Validate', false);
end

function rel = makeEncounterRelation(preBody, wormId, patchId, trefId)
o = jOpts(preBody, 'TimeReferenceIds', {trefId});
rel = did2.build.directedRelation(wormId, patchId, 'encountered', o{:});
end

function tf = isPatchGeometryTable(cols)
%ISPATCHGEOMETRYTABLE Signature of the JH C. elegans bacterial-patch geometry
%   table (doImport.m:291-293), which is a DIFFERENT table from the C. elegans
%   CULTIVATION-PLATE table (doImport.m:179-201) even though the two share this
%   map's first three clauses.
%
%   STATUS 2026-08-11: this comment used to claim "OD600-at-seeding is unique to
%   the geometry table". THAT WAS FALSE, and the cultivation plate was being
%   minted as a bacterial patch because of it. `+haley/tableDoc_dictionary.json`
%   maps THREE source columns to the one OD600-at-seeding term --
%
%       "patchOD600":  "EMPTY:bacterial OD600 (target) at seeding"
%       "growthOD600": "EMPTY:bacterial OD600 (target) at seeding"
%       "OD600":       "EMPTY:bacterial OD600 (target) at seeding"
%
%   -- and `data` keys are shortName(term), so the three collapse to ONE key.
%   The cultivation table carries `growthOD600` (doImport.m:100) alongside
%   `patchID` (:192, constant '0001') and no `patch_id`, so it satisfied all
%   three clauses exactly as the geometry table does. The columns were then
%   read against a 6-measure enumeration it does not have: of its 22 columns,
%   2 were carried, 1 became the (constant) local_identifier and 19 -- CFU,
%   OD600Real, four timestamps, growth duration, assayPhase, plateID, exclude,
%   the strain edge, arenaDiameter, lawnSpacing, temp, growthAge, expID and two
%   labels -- were dropped on the floor.
%
%   THE DISCRIMINATOR IS PATCH GEOMETRY. A cultivation plate has none: no
%   radius, no circularity, no centre. The geometry table has all four
%   (doImport.m:254-257 / :291-293). Requiring ANY ONE of them is deliberate --
%   the shortName strings cannot be verified in this session (`ndi.ontology.
%   lookup` lives in ndi-ontology-matlab, which is not checked out), so the
%   clause is written so that no single mis-spelling can un-dispatch the
%   geometry table that is green today: all four would have to be wrong at once.
%   The two clauses that ARE corpus-proven (the map fired on 6,306 JH documents,
%   commit 72ece64) are left exactly as they were.
tf = ~isempty(colByKey(cols, 'BacterialOD600TargetAtSeeding')) ...
    && ~isempty(colByKey(cols, 'BacterialPatchIdentifier')) ...
    && isempty(colByKey(cols, 'BacterialPatchDocumentIdentifier')) ...
    && hasAnyKey(cols, patchGeometryEvidenceKeys());
end

function keys = patchGeometryEvidenceKeys()
%PATCHGEOMETRYEVIDENCEKEYS Columns that only a real bacterial PATCH can have.
%   A plate-level row (cultivation or behaviour) never carries one.
keys = {'BacterialPatchRadius', 'BacterialPatchCircularity', ...
        'BacterialPatchCenter_XCoordinate', 'BacterialPatchCenter_YCoordinate'};
end

function tf = hasAnyKey(cols, keys)
tf = false;
for k = 1:numel(keys)
    if ~isempty(colByKey(cols, keys{k})); tf = true; return; end
end
end

function bodies = applyPatchGeometryMap(preBody, cols)
% the patch as a declared subject, id preserved so the encounter parent resolves
%
% BOTH identifier columns are read, not just the patch's own. Team directive
% 2026-08-11: "each experiment #, plate #, and patch # combo should be unique
% and should dictate the local identifier for all patches. None should be
% labeled just patch #". This table has NO `expID` column (doImport.m:290-292),
% so the most a single-document migrator can form is the PAIR; the batch pass
% did2.convert.resolveLawnPlateSubjects upgrades it to the triple where the
% plate -> expID hop resolves, and COUNTS the ones that stay a pair.
%
% `BacterialPlateIdentifier` is NOT added to `consumed` below: it names a
% DIFFERENT entity, so it remains data ABOUT the patch and still falls through
% to the per-column path as a term_observation. Using a value in the handle does
% not record it -- dropping the column would be the invisible loss this map was
% repaired for one change ago.
subjectDoc = makePatchSubject(preBody, ...
    colVal(cols, 'BacterialPlateIdentifier'), ...
    colVal(cols, 'BacterialPatchIdentifier'));
patchId = subjectDoc.base.id;

% one session-relative anchor shared by the geometry observations (the patch
% geometry has no meaningful per-reading time; it is a static property set)
anchor = makeSessionAnchor(preBody, 'during');

% geometry columns -> observations on the patch. Identifier columns are the
% patch's identity (skipped); centre X/Y are positions carried as lengths.
measures = {
    'BacterialOD600TargetAtSeeding',    'observation',              'concentration'
    'BacterialPatchVolume',             'observation',              'volume'
    'BacterialPatchRadius',             'observation',              'length'
    'BacterialPatchCircularity',        'observation',              'score'
    'BacterialPatchCenter_XCoordinate', 'observation',              'length'
    'BacterialPatchCenter_YCoordinate', 'observation',              'length'};

bodies = {subjectDoc};
usedAnchor = false;
% `BacterialPatchIdentifier` is THIS document's identity (it became the
% subject's local_identifier above), so it is not also a measurement. Every
% other column must end up somewhere.
consumed = {'BacterialPatchIdentifier'};
for i = 1:size(measures, 1)
    c = colByKey(cols, measures{i, 1});
    if isempty(c); continue; end
    [ok, num] = numericValue(c{1});
    if ~ok; continue; end   % unparseable -> NOT consumed; carried below
    consumed{end+1} = measures{i, 1}; %#ok<AGROW>
    variable = struct('node', '', 'name', c{1}.name);
    bodies{end+1} = makeEncObs(preBody, measures{i, 2}, measures{i, 3}, ...
        variable, num, patchId, anchor.base.id); %#ok<AGROW>
    usedAnchor = true;
end

% --- carry everything the enumeration does not name -------------------------
% A fixed list of 6 measures is the wrong shape for a table whose width is set
% by NDI, not by us: the geometry table already has a 7th column
% (BacterialPlateIdentifier) that this map dropped in silence, and the next
% column NDI adds would be dropped the same way -- invisibly, because a dropped
% column leaves no empty edge, no fragment and no vacuous field for any counter
% to see. So anything not enumerated and not this row's own identity falls
% through to the ordinary per-column path, which classifies it by the property
% term and the value's shape. The patch is passed in explicitly because this
% map MINTS its subject rather than carrying one (a real ontologyTableRow has
% no `subject_id` dependency -- see the guard in the main function).
for i = 1:numel(cols)
    c = cols{i};
    if any(strcmp(c.key, consumed)); continue; end
    if ~isCarriableValue(c.value); continue; end
    row = struct('ontology_name', c.node, 'name', c.name);
    row.value = c.value;   % assigned, not passed to struct(): a cell value
                           % would otherwise fan the row out into a struct ARRAY
    [b, isObservation] = migrateRow(preBody, row, patchId, anchor.base.id);
    if isempty(b); continue; end    % an identity column migrateRow recognises
    usedAnchor = usedAnchor || isObservation;
    bodies{end+1} = b; %#ok<AGROW>
end
if usedAnchor
    bodies{end+1} = anchor;
end
end

function tf = isCarriableValue(v)
%ISCARRIABLEVALUE Can the per-column path represent this value WITHOUT inventing
%   an empty document?
%
%   `migrateRow` reads a value through `rowNumericValue` (scalar numeric only)
%   and `getCharField` (char / scalar string / scalar numeric). Anything else --
%   a logical, a vector, a cell -- reaches `valueTerm`, which returns '' for it,
%   and the result is a term_observation asserting nothing. A hollow document is
%   NOT an improvement on a dropped column: it passes every gate while carrying
%   no fact, which is the exact failure `isFragment` and `silentLoss` exist to
%   find. So an unrepresentable value is left for a typed home (a logical wants
%   a boolean leaf; a vector wants a `sampled_body`) rather than fabricated.
%
%   No column of the JH patch geometry table is in this bucket -- its 8 columns
%   are chars and scalar doubles -- so today this predicate only bounds what a
%   FUTURE column may become.
tf = false;
if isempty(v); return; end
if ischar(v); tf = true; return; end
if isstring(v) && isscalar(v); tf = true; return; end
if isnumeric(v) && isscalar(v) && ~isnan(v); tf = true; return; end
end

function body = makePatchSubject(preBody, plateId, patchId)
% did-schema #88: an `entity` of type culture (a bacterial patch is a lawn:
% "a mass grown as one"), id PRESERVED so the encounter's parent resolves.
localId = jPatchLocalId(plateId, patchId, preBody);  % REQUIRED, and qualified
body = jEntity(preBody, 'culture', struct('local_identifier', localId, ...
    'description', 'bacterial patch'), 'Id', char(preBody.base.id));
end

function li = jPatchLocalId(plateId, patchId, preBody)
%JPATCHLOCALID The patch handle, qualified. NEVER a bare patch number.
%
%   Team directive 2026-08-11, verbatim: *"each experiment #, plate #, and patch
%   # combo should be unique and should dictate the local identifier for all
%   patches. None should be labeled just patch #"*.
%
%   THIS FILE CANNOT FORM THE TRIPLE and does not pretend to. `patchID` is
%   `1:numPatch` within a plate (doImport.m:275), so '0001' recurs on every
%   plate; `plateID` is on this row (doImport.m:290-292) so the PAIR is
%   available; `expID` is NOT on this table at all, and inventing one is exactly
%   what the directive's "derive every component from the source rows" forbids.
%   So the pair is emitted, and `did2.convert.resolveLawnPlateSubjects` -- which
%   can see the plate rows -- upgrades it to `exp/<expID>/plate/<plateID>/patch/
%   <patchID>` and counts the ones it could not.
%
%   The format is READ BACK by that pass's `parsePairHandle`, so the two are
%   coupled and testMigratorsJ pins the shape. If either component is missing
%   the handle falls back to the document id (unique by construction) rather
%   than to the bare patch number the directive names.
li = '';
if ~isempty(plateId) && ~isempty(patchId)
    li = sprintf('plate/%s/patch/%s', char(plateId), char(patchId));
end
li = jEnsureLocalId(li, preBody);   % subject.local_identifier is REQUIRED
end

% ---- encounter helpers ------------------------------------------------

function cols = extractColumns(block)
%EXTRACTCOLUMNS Like extractRows, but keep each column's variable_names KEY so a
%   per-table map can dispatch on it. Returns a cell of structs
%   {key, name, node, value}.
cols = {};
if ~isfield(block, 'variable_names'); return; end
vars  = splitCSV(getCharField(block, 'variable_names'));
names = splitCSV(getCharField(block, 'names'));
nodes = splitCSV(getCharField(block, 'ontology_nodes'));
data = struct();
if isfield(block, 'data') && isstruct(block.data); data = block.data; end
for i = 1:numel(vars)
    key = vars{i};
    nm = ''; nd = '';
    if i <= numel(names); nm = names{i}; end
    if i <= numel(nodes); nd = nodes{i}; end
    val = [];
    if ~isempty(key) && isfield(data, key); val = data.(key); end
    cols{end+1} = struct('key', key, 'name', nm, 'node', nd, 'value', val); %#ok<AGROW>
end
end

function c = colByKey(cols, key)
c = {};
for i = 1:numel(cols)
    if strcmp(cols{i}.key, key); c = cols(i); return; end
end
end

function v = colVal(cols, key)
v = '';
c = colByKey(cols, key);
if ~isempty(c)
    x = c{1}.value;
    if ischar(x); v = x;
    elseif isstring(x) && isscalar(x); v = char(x);
    elseif isnumeric(x) && isscalar(x); v = num2str(x); end
end
end

function n = colNum(cols, key)
n = 0;
c = colByKey(cols, key);
if ~isempty(c)
    [ok, num] = numericValue(c{1});
    if ok; n = num; end
end
end

function [ok, num] = numericValue(col)
ok = false; num = [];
x = col.value;
if isnumeric(x) && isscalar(x) && isfinite(x)
    ok = true; num = double(x);
elseif (ischar(x) || (isstring(x) && isscalar(x)))
    d = str2double(char(x));
    if ~isnan(d); ok = true; num = d; end
end
end

% ===================== per-row migration ===============================

function [body, isObservation] = migrateRow(preBody, row, subjectId, anchorId)
%MIGRATEROW One column -> one statement.
%   SUBJECTID (optional) names the subject explicitly. Omit it on the
%   per-column fallback path, where the subject is CARRIED from the source
%   document's `subject_id` dependency (and the caller has already guarded on
%   there being one). Pass it from a per-table map, which MINTS its subject --
%   `carrySubject` would raise there, because a real ontologyTableRow declares
%   only `document_id`.
if nargin < 3; subjectId = ''; end
if nargin < 4; anchorId = ''; end
node  = getCharField(row, 'ontology_name');
label = getCharField(row, 'name');
variable = struct('node', node, 'name', label);
hay = lower([node ' ' label]);
body = []; isObservation = false;

% identity columns are the subject itself, not a measurement
if containsAny(hay, {'local identifier', 'localidentifier', ...
        'document identifier', 'documentidentifier', 'subject id'})
    return;
end

[isNumeric, numVal] = rowNumericValue(row);

% timeless facts -> assertions (no act, optional time)
if containsAny(hay, {'species', 'sex', 'strain', 'genotype', 'taxon'})
    body = makeTermAssertion(preBody, variable, valueTerm(row), subjectId);
    return;
elseif containsAny(hay, {'date of birth', 'birth date', 'dob'})
    body = makeDateAssertion(preBody, variable, row, subjectId);
    return;
elseif ~isNumeric && looksLikeTimestamp(getCharField(row, 'value'))
    body = makeDateAssertion(preBody, variable, row, subjectId);
    return;
end

% timed measurements -> observations
isObservation = true;
if isNumeric
    [shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal);
    body = makeNumericObservation(preBody, shapeClass, variable, ...
        valueStruct, subjectId, anchorId);
else
    body = makeTermObservation(preBody, variable, valueTerm(row), subjectId, anchorId);
end
end

function [shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal)
%DISPATCHNUMERIC Choose the value kind by the property's DIMENSION. The
%   property rides on the spine `variable`; word-boundary matching only.
unit = getCharField(row, 'unit');
if containsAny(hay, {'body weight', 'body mass', 'weight', 'mass'})
    shapeClass = 'mass';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'radius', 'body length', 'length', 'diameter', 'distance', 'size'})
    shapeClass = 'length';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'sampling rate', 'heart rate', 'respiration rate', 'frequency', 'rate'})
    shapeClass = 'frequency';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'deceleration', 'acceleration'})
    shapeClass = 'acceleration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'velocity', 'speed'})
    shapeClass = 'velocity';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'onset time', 'offset time', 'age', 'duration', 'latency', 'time'})
    % `time`, not `duration`: the V_eta shape mixin was renamed by
    % TEAM-SIGN-OFF [time dtype] (DID-schema V_eta_tenet_audit.md, 2026-08-17).
    % The HAYSTACK words are unchanged -- they match the source column's label,
    % which is did_v1 text and did not move.
    shapeClass = 'time';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'volume'})
    shapeClass = 'volume';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'temperature'})
    shapeClass = 'temperature';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'pressure'})
    shapeClass = 'pressure';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'voltage', 'membrane potential'})
    shapeClass = 'voltage';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'current'})
    shapeClass = 'current';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'concentration', 'density', 'titer', 'titre', 'glucose'})
    shapeClass = 'concentration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'number of', 'count', 'entries', 'trial number', 'identifier', 'samples'})
    shapeClass = 'count';
    valueStruct = did2.build.valueCell('count', round(numVal), 'Approximate', false);
elseif containsAny(hay, {'percent', 'probability', 'circularity', 'score', 'condition'})
    shapeClass = 'score';
    valueStruct = did2.build.composite('score', 'value', ...
        struct('score', numVal, 'approximate', false));
else
    % J §7: intensity is the one dimensionless numeric (a.u.) -- the home for
    % amplitudes / fluorescence / ratios / unrecognised numerics. No generic
    % escape hatch (D8); a genuinely mis-dimensioned value is caught in
    % discovery-mode review, not silently dropped.
    shapeClass = 'intensity';
    valueStruct = sourceCell(unit, numVal);
end
if ~any(strcmp(shapeClass, {'count', 'score'}))
    valueStruct = jQuantity(shapeClass, valueStruct.source_value, ...
        valueStruct.source_unit, 'approximate', false);
end
end

% ===================== destination builders ============================

function body = makeNumericObservation(preBody, shapeClass, variable, valueStruct, subjectId, anchorId)
% did-schema #88: an `observation` with the value-kind mixin SHAPECLASS
body = jStatement(preBody, 'observation', subjectOrCarried(preBody, subjectId), ...
    variable, valueStruct, 'TimeReferenceIds', {anchorId}, 'ValueKind', shapeClass);
end

function body = makeTermObservation(preBody, variable, valueT, subjectId, anchorId)
body = jStatement(preBody, 'observation', subjectOrCarried(preBody, subjectId), ...
    variable, valueT, 'TimeReferenceIds', {anchorId}, 'ValueKind', 'term');
end

function body = makeTermAssertion(preBody, variable, valueT, subjectId)
body = jStatement(preBody, 'assertion', subjectOrCarried(preBody, subjectId), ...
    variable, valueT, 'ValueKind', 'term');
end

function body = makeDateAssertion(preBody, variable, row, subjectId)
raw = getCharField(row, 'value');
v = did2.build.composite('date', 'value', ...
    struct('instant', raw, 'precision', 'second', 'source_value', raw));
body = jStatement(preBody, 'assertion', subjectOrCarried(preBody, subjectId), ...
    variable, v, 'ValueKind', 'date');
end

function id = subjectOrCarried(preBody, subjectId)
id = char(subjectId);
if isempty(id)
    id = resolvedSubject(preBody);
    if isempty(id)
        error('did2:convert:noSubject', ...
            ['ontology_table_row: refusing to emit a statement with an empty ' ...
             'entity_id. A real ontologyTableRow declares only `document_id`, ' ...
             'so the caller must guard on resolvedSubject() and pass the ' ...
             'document through for the second pass instead.']);
    end
end
end

function c = sourceCell(unit, numVal)
c = struct('source_unit', char(unit), 'source_value', double(numVal), ...
    'approximate', false);
end

function valueT = valueTerm(row)
termValue = getCharField(row, 'value');
if isempty(termValue)
    termValue = getCharField(row, 'string_value');
end
valueT = struct('node', '', 'name', termValue);   % free label -> name; node backfilled
end

function subjectVal = resolvedSubject(preBody)
%RESOLVEDSUBJECT The subject this row is about, or '' when there is none.
%
%   Reads the SOURCE document's depends_on for a dependency named `subject_id`.
%   Real ontologyTableRow documents do not have one -- the NDI template declares
%   only `document_id` -- so this returns '' for them, and the caller must NOT
%   emit statements in that case. See the guard in the main function.
%
%   Kept as a separate query from carrySubject so that "is there a subject?" is
%   answerable WITHOUT building a dependency struct. The old code could only
%   answer it by constructing the edge, which is why the empty case was written
%   out instead of detected.
subjectVal = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for k = 1:numel(preBody.depends_on)
        d = preBody.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, 'subject_id')
            if isfield(d, 'value'); subjectVal = d.value;
            elseif isfield(d, 'document_id'); subjectVal = d.document_id; end
        end
    end
end
end

function anchor = makeSessionAnchor(preBody, relation)
anchor = jSessionAnchor(preBody, relation);
end

function rows = extractRows(block)
%EXTRACTROWS Normalise an ontology_table_row body to a cell of column structs
%   (each {ontology_name, name, value}), one per measured property.
rows = {};
if isfield(block, 'rows')
    r = block.rows;
    if iscell(r); rows = r(:)';
    elseif isstruct(r); rows = arrayfun(@(x) x, r(:)', 'UniformOutput', false); end
    return;
end
if isfield(block, 'variable_names')
    vars  = splitCSV(getCharField(block, 'variable_names'));
    names = splitCSV(getCharField(block, 'names'));
    nodes = splitCSV(getCharField(block, 'ontology_nodes'));
    data = struct();
    if isfield(block, 'data') && isstruct(block.data); data = block.data; end
    for i = 1:numel(vars)
        key = vars{i};
        label = ''; node = '';
        if i <= numel(names); label = names{i}; end
        if i <= numel(nodes); node = nodes{i}; end
        val = [];
        if ~isempty(key) && isfield(data, key); val = data.(key); end
        if isempty(val) || (isnumeric(val) && isscalar(val) && isnan(val)); continue; end
        rows{end+1} = struct('ontology_name', node, 'name', label, 'value', val); %#ok<AGROW>
    end
    return;
end
if isfield(block, 'ontology_name') || isfield(block, 'name')
    rows = {block};
end
end

function parts = splitCSV(s)
parts = {};
if isempty(s); return; end
raw = strsplit(char(s), ',');
parts = cellfun(@strtrim, raw, 'UniformOutput', false);
end

function [isNumeric, numVal] = rowNumericValue(row)
isNumeric = false; numVal = [];
if isfield(row, 'value')
    v = row.value;
    if isnumeric(v) && isscalar(v) && isfinite(v); isNumeric = true; numVal = double(v); end
elseif isfield(row, 'numeric_value')
    v = row.numeric_value;
    if isnumeric(v) && ~isempty(v); isNumeric = true; numVal = double(v(1)); end
end
end

function tf = looksLikeTimestamp(s)
tf = false;
if isempty(s) || ~ischar(s); return; end
% a date-ish string: contains a slash-or-dash date and/or a time
tf = ~isempty(regexp(s, '\d{1,4}[/-]\d{1,2}[/-]\d{1,4}', 'once')) || ...
     ~isempty(regexp(s, '\d{1,2}:\d{2}', 'once'));
end

function s = getCharField(block, name)
s = '';
if isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v);
    elseif isnumeric(v) && isscalar(v); s = num2str(v); end
end
end

function tf = containsAny(hay, needles)
tf = false;
for k = 1:numel(needles)
    pat = ['\<', regexptranslate('escape', needles{k}), '\>'];
    if ~isempty(regexp(hay, pat, 'once')); tf = true; return; end
end
end
