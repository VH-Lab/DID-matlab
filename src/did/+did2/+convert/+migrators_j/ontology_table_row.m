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
    [b, isObservation] = migrateRow(preBody, rows{k});
    if isempty(b)
        continue;   % skipped column (identity, empty)
    end
    if isObservation
        b.depends_on(end+1) = struct('name', 'time_reference_1', ...
            'value', anchor.base.id);
        usedAnchor = true;
    end
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
%   key suffix -> {leafClass, shapeClass}. Onset/offset are the window (not
%   observations); the EncounterIdentifier is derived (dropped).
measures = {
    'DecelerationUponEncounter',            'acceleration_observation', 'acceleration'
    'MinimumVelocityDuringEncounter',       'velocity_observation',     'velocity'
    'PeakVelocityBeforeEncounterOnset',     'velocity_observation',     'velocity'
    'MinimumVelocityAfterEncounterOffset',  'velocity_observation',     'velocity'
    'PosteriorProbabilityOfExploitation',   'score_observation',        'score'
    'PosteriorProbabilityOfSensing',        'score_observation',        'score'
    'RelativeDensityOfEncounteredBacteria', 'concentration_observation','concentration'
    'RelativeDensityOfCultivationBacteria', 'concentration_observation','concentration'};

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

function body = makeEncObs(preBody, leafClass, shapeClass, variable, num, wormId, trefId)
body = struct();
body.document_class = struct('class_name', leafClass, 'class_version', '1.0.0', ...
    'superclasses', supersOf({'subject_observation', shapeClass}), ...
    'schema_version', 'V_eta');
body.depends_on = [ ...
    struct('name', 'subject_id',       'value', wormId), ...
    struct('name', 'time_reference_1', 'value', trefId)];
body.base = freshBase(preBody, 'migrated_encounter_measure');
body.subject_statement  = struct('variable', variable, 'storage_mode', 'inline');
body.subject_interaction = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
body.subject_observation = struct();
if strcmp(shapeClass, 'score')
    body.score = struct('value', struct('value', num, ...
        'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false));
else
    body.(shapeClass) = struct('value', ...
        struct('source_unit', '', 'source_value', double(num), 'approximate', false));
end
end

function tref = makeEncounterWindow(preBody, onset, offset)
% A bounded [onset, offset] window relative to the session/assay -- a
% session_bounded_reference (no parent interaction/epoch required; session rides
% on base.session_id). The encounter's measurements and its relation all depend
% on this one document, so the encounter is exactly "everything on it".
tref = struct();
tref.document_class = struct('class_name', 'session_bounded_reference', ...
    'class_version', '1.0.0', 'superclasses', supersOf({'time_reference'}), ...
    'schema_version', 'V_eta');
tref.depends_on = struct('name', {}, 'value', {});
tref.base = freshBase(preBody, 'migrated_encounter_window');
tref.time_reference = struct('is_approximate', false);
tref.session_bounded_reference = struct('relation', 'during', ...
    'start', durationSeconds(onset), 'end', durationSeconds(offset));
end

function rel = makeEncounterRelation(preBody, wormId, patchId, trefId)
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', 'superclasses', supersOf({'relation'}), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',            'value', wormId), ...   % subject of the verb
    struct('name', 'parent',           'value', patchId), ...  % object of the verb
    struct('name', 'time_reference_1', 'value', trefId)];      % when it happened
rel.base = freshBase(preBody, 'migrated_encounter');
% `relation` (renamed from subject_relation) is abstract with no fields -> no block.
rel.directed_relation = struct('relation', struct('node', '', 'name', 'encountered'));
end

% ===================== per-table map: C. elegans bacterial patch =======
%
%   The JH bacterial-patch geometry table (6,206 rows). Each row IS a bacterial
%   patch -- and the encounter table above references it by document id as the
%   `worm --encountered--> patch` relation's parent. So this map MINTS a bare
%   `subject` that PRESERVES the source document id (otherwise the per-column
%   fan-out would give every output a fresh id and the encounter parent would
%   dangle). The patch's geometry (OD600, volume, radius, circularity, centre)
%   becomes observations on that patch, all sharing one session-relative anchor.
%   The BacterialPatch/PlateIdentifier columns are bare local labels (e.g.
%   "0017"), not document ids, so they do NOT become relations -- relating to a
%   non-existent plate document would only trade one orphan for another.
%   `BacterialPatchIdentifier` is the patch's own identity and becomes its
%   `local_identifier`. `BacterialPlateIdentifier` names a DIFFERENT entity, so
%   it is data ABOUT the patch, not the patch's identity: it now falls through
%   to the per-column path as a `term_observation` instead of being dropped.
%   Relating the patch to a plate DOCUMENT stays deferred to the NDI second
%   pass, which can see the migrated-id graph.
%
%   CAUTION on local_identifier: `patchID` is `1:numPatch` WITHIN a plate
%   (doImport.m:275), so "0001" recurs on every plate, and `jEnsureLocalId` does
%   no dataset-level qualification while both Haley sessions land in one
%   `ndi.dataset.dir`. The id is a LABEL, not a key -- do not build anything
%   that joins on it. (This is pre-existing and unchanged here; it is recorded
%   because the cultivation-plate misfire made it much worse: that table sets
%   `patchID` to the CONSTANT '0001' for every row, doImport.m:192.)

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
subjectDoc = makePatchSubject(preBody, colVal(cols, 'BacterialPatchIdentifier'));
patchId = subjectDoc.base.id;

% one session-relative anchor shared by the geometry observations (the patch
% geometry has no meaningful per-reading time; it is a static property set)
anchor = makeSessionAnchor(preBody, 'during');

% geometry columns -> observations on the patch. Identifier columns are the
% patch's identity (skipped); centre X/Y are positions carried as lengths.
measures = {
    'BacterialOD600TargetAtSeeding',    'concentration_observation','concentration'
    'BacterialPatchVolume',             'volume_observation',       'volume'
    'BacterialPatchRadius',             'length_observation',       'length'
    'BacterialPatchCircularity',        'score_observation',        'score'
    'BacterialPatchCenter_XCoordinate', 'length_observation',       'length'
    'BacterialPatchCenter_YCoordinate', 'length_observation',       'length'};

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
    [b, isObservation] = migrateRow(preBody, row, patchId);
    if isempty(b); continue; end    % an identity column migrateRow recognises
    if isObservation
        b.depends_on(end+1) = struct('name', 'time_reference_1', ...
            'value', anchor.base.id);
        usedAnchor = true;
    end
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

function body = makePatchSubject(preBody, localId)
%MAKEPATCHSUBJECT Bare V_eta subject PRESERVING the source document id. Mirrors
%   subject_group -> subject (class subject v3.0.0, bare identity). The id must
%   be preserved because the encounter table's directed_relation names this
%   document as its parent.
body = struct();
body.document_class = struct('class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', {}, 'value', {});
if isfield(preBody, 'base') && isstruct(preBody.base)
    body.base = preBody.base;   % PRESERVE id -> encounter parent resolves
end
localId = jEnsureLocalId(localId, preBody);   % subject.local_identifier is REQUIRED
body.subject = struct('local_identifier', localId, 'description', 'bacterial patch');
end

% ---- encounter helpers ------------------------------------------------

function supers = supersOf(chain)
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(chain)
    supers(end+1) = struct('class_name', chain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
end

function base = freshBase(preBody, name)
sessionId = ''; ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', name, 'datestamp', ds);
end

function d = durationSeconds(x)
d = struct('source_unit', 's', 'source_value', double(x), 'approximate', false);
end

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

function [body, isObservation] = migrateRow(preBody, row, subjectId)
%MIGRATEROW One column -> one statement.
%   SUBJECTID (optional) names the subject explicitly. Omit it on the
%   per-column fallback path, where the subject is CARRIED from the source
%   document's `subject_id` dependency (and the caller has already guarded on
%   there being one). Pass it from a per-table map, which MINTS its subject --
%   `carrySubject` would raise there, because a real ontologyTableRow declares
%   only `document_id`.
if nargin < 3; subjectId = ''; end
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
    [leafClass, shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal);
    body = makeNumericObservation(preBody, leafClass, shapeClass, variable, ...
        valueStruct, subjectId);
else
    body = makeTermObservation(preBody, variable, valueTerm(row), subjectId);
end
end

function [leafClass, shapeClass, valueStruct] = dispatchNumeric(hay, row, numVal)
%DISPATCHNUMERIC Choose the data-type leaf by the property's DIMENSION. The
%   property rides on the spine `variable`; word-boundary matching only.
unit = getCharField(row, 'unit');
if containsAny(hay, {'body weight', 'body mass', 'weight', 'mass'})
    leafClass = 'mass_observation'; shapeClass = 'mass';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'radius', 'body length', 'length', 'diameter', 'distance', 'size'})
    leafClass = 'length_observation'; shapeClass = 'length';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'sampling rate', 'heart rate', 'respiration rate', 'frequency', 'rate'})
    leafClass = 'frequency_observation'; shapeClass = 'frequency';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'deceleration', 'acceleration'})
    leafClass = 'acceleration_observation'; shapeClass = 'acceleration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'velocity', 'speed'})
    leafClass = 'velocity_observation'; shapeClass = 'velocity';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'onset time', 'offset time', 'age', 'duration', 'latency', 'time'})
    leafClass = 'duration_observation'; shapeClass = 'duration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'volume'})
    leafClass = 'volume_observation'; shapeClass = 'volume';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'temperature'})
    leafClass = 'temperature_observation'; shapeClass = 'temperature';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'pressure'})
    leafClass = 'pressure_observation'; shapeClass = 'pressure';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'voltage', 'membrane potential'})
    leafClass = 'voltage_observation'; shapeClass = 'voltage';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'current'})
    leafClass = 'current_observation'; shapeClass = 'current';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'concentration', 'density', 'titer', 'titre', 'glucose'})
    leafClass = 'concentration_observation'; shapeClass = 'concentration';
    valueStruct = sourceCell(unit, numVal);
elseif containsAny(hay, {'number of', 'count', 'entries', 'trial number', 'identifier', 'samples'})
    leafClass = 'count_observation'; shapeClass = 'count';
    valueStruct = struct('value', round(numVal), 'unit', ...
        struct('node', '', 'name', ''), 'approximate', false);
elseif containsAny(hay, {'percent', 'probability', 'circularity', 'score', 'condition'})
    leafClass = 'score_observation'; shapeClass = 'score';
    valueStruct = struct('value', numVal, 'scale', struct('node', '', 'name', ''), ...
        'scale_min', 0.0, 'scale_max', 0.0, 'approximate', false);
else
    % J §7: intensity is the one dimensionless numeric (a.u.) -- the home for
    % amplitudes / fluorescence / ratios / unrecognised numerics. No generic
    % escape hatch (D8); a genuinely mis-dimensioned value is caught in
    % discovery-mode review, not silently dropped.
    leafClass = 'intensity_observation'; shapeClass = 'intensity';
    valueStruct = sourceCell(unit, numVal);
end
end

% ===================== destination builders ============================

function body = makeNumericObservation(preBody, leafClass, shapeClass, variable, valueStruct, subjectId)
body = startStatement(preBody, leafClass, {'subject_observation', shapeClass}, ...
    variable, subjectId);
body.subject_interaction = interactionBlock();
body.subject_observation = struct();
body.(shapeClass) = struct('value', valueStruct);
end

function body = makeTermObservation(preBody, variable, valueT, subjectId)
body = startStatement(preBody, 'term_observation', {'subject_observation'}, ...
    variable, subjectId);
body.subject_interaction = interactionBlock();
body.subject_observation = struct();
body.term = struct('value', valueT);
end

function body = makeTermAssertion(preBody, variable, valueT, subjectId)
body = startStatement(preBody, 'term_assertion', {'subject_assertion'}, ...
    variable, subjectId);
body.term = struct('value', valueT);
end

function body = makeDateAssertion(preBody, variable, row, subjectId)
body = startStatement(preBody, 'date_assertion', {'subject_assertion'}, ...
    variable, subjectId);
raw = getCharField(row, 'value');
body.date = struct('value', ...
    struct('instant', raw, 'precision', 'second', 'source', raw));
end

% ===================== shared helpers ==================================

function body = startStatement(preBody, className, supersChain, variable, subjectId)
%STARTSTATEMENT Seed a V_eta statement body: document_class header, a fresh
%   base id, the subject_id edge, and the subject_statement block (variable
%   + storage_mode). The caller adds the subject_interaction block (for
%   interactions) and the leaf value block.
%
%   SUBJECTID (optional, may be '') names the subject explicitly -- used by a
%   per-table map, which mints its own subject. Empty or absent falls back to
%   carrySubject, which reads the SOURCE document's `subject_id` dependency and
%   raises when there is none.
if nargin < 5; subjectId = ''; end
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(supersChain)
    supers(end+1) = struct('class_name', supersChain{k}, 'class_version', '1.0.0'); %#ok<AGROW>
end
body = struct();
body.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_eta');
if isempty(subjectId)
    body.depends_on = carrySubject(preBody);
else
    body.depends_on = struct('name', 'subject_id', 'value', char(subjectId));
end
if isfield(preBody, 'base') && isstruct(preBody.base)
    base = preBody.base;
    base.id = did.ido.unique_id();   % each column becomes its own document
    body.base = base;
end
body.subject_statement = struct('variable', variable, 'storage_mode', 'inline');
end

function blk = interactionBlock()
% method optional (the observation verb is "measurement"); the cadence is a
% single point (one reading), per D1.
blk = struct('method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
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

function deps = carrySubject(preBody)
%CARRYSUBJECT The subject_id edge for an emitted statement.
%
%   Only ever reached once resolvedSubject() has confirmed a subject exists --
%   the main function guards on it. It therefore cannot emit an empty edge; if
%   it ever does, the guard has been removed and 76,766 hollow observations per
%   corpus are back.
deps = struct('name', {}, 'value', {});
subjectVal = resolvedSubject(preBody);
if isempty(subjectVal)
    error('did2:convert:noSubject', ...
        ['ontology_table_row: refusing to emit a statement with an empty ' ...
         'subject_id. A real ontologyTableRow declares only `document_id`, ' ...
         'so the caller must guard on resolvedSubject() and pass the ' ...
         'document through for the second pass instead.']);
end
deps(end+1) = struct('name', 'subject_id', 'value', subjectVal);
end

function anchor = makeSessionAnchor(preBody, relation)
sessionId = '';
ds = '2024-01-01T00:00:00.000Z';
if isfield(preBody, 'base') && isstruct(preBody.base)
    if isfield(preBody.base, 'session_id'); sessionId = preBody.base.session_id; end
    if isfield(preBody.base, 'datestamp') && ~isempty(preBody.base.datestamp)
        ds = preBody.base.datestamp;
    end
end
anchor = struct();
anchor.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
anchor.depends_on = struct('name', {}, 'value', {});
anchor.base = struct('id', did.ido.unique_id(), 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', ds);
anchor.time_reference = struct('is_approximate', true);
anchor.session_relative_reference = struct('relation', relation);
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
