function [result, report] = resolveOpenmindsCitations(result, options)
%RESOLVEOPENMINDSCITATIONS Assemble the openMINDS dataset CITATION graph into
%   the entity tier: `dataset` + `person` / `organization` / `funding` /
%   `publication` / `web_resource` + the `directed_relation` edges between
%   them -- the same six classes did2.convert.migrators_j.metadata_editor
%   emits, from a completely different store.
%
%   [RESULT, REPORT] = did2.convert.resolveOpenmindsCitations(RESULT) takes the
%   struct did2.convert.v1_to_v2 returns (after the per-document pass) and
%   consumes the bare `openminds` documents that make up a dataset's citation
%   metadata, appending the entities they decompose into. REPORT also rides on
%   RESULT.openminds_citations.
%
%   ---------------------------------------------------------------------
%   BATCH-PASS DECLARATION (DID-schema V_eta_OPEN_WORK.md row 107)
%   ---------------------------------------------------------------------
%   Read by tools/batch_pass_declarations.py and, across the repo boundary, by
%   DID-schema tools/coverage.py, which credits the completion ladder from it.
%   A pass carrying no declaration is an ERROR there, never an empty set.
%
%   BATCH-PASS-CONSUMES: openminds
%   BATCH-PASS-EMITS: openminds -> document: dataset, person, organization,
%       funding, publication, web_resource, directed_relation
%
%   The seven are the six entity classes named in the H1 line plus the
%   `directed_relation` edges between them, all minted through
%   did2.convert.entities (entityDoc :586/:610/:664/:703/:731, orgFor
%   :633/:673, relationDoc :614/:640/:668/:681/:706/:735). It is ADDITIVE to
%   migrators_j.metadata_editor, which emits the same seven from the other
%   store; neither replaces the other.
%   ---------------------------------------------------------------------
%
%   STATUS 2026-08-11: WRITTEN WITHOUT MATLAB. There is neither MATLAB nor
%   Octave in the container this was authored in, so NOTHING IN THIS FILE HAS
%   BEEN EXECUTED. CI is the first execution. Do not read the header's
%   confidence as evidence of a run.
%
%   ---------------------------------------------------------------------
%   THE DECISION THIS BUILDS, AND THE WORD THAT MATTERS IN IT
%   ---------------------------------------------------------------------
%   TEAM DECISION 2026-08-11 (DID-schema `V_eta_OPEN_WORK.md`), verbatim:
%   "Do B" -- write the migrator -- against A (accept the loss) and C (require
%   `metadata_editor`).
%
%   **B IS ADDITIVE.** It does not replace or weaken the `metadata_editor`
%   path, because the two stores are NOT information-equivalent and neither
%   dominates:
%
%     the GRAPH   holds only a DOI for a related publication. No title, no
%                 PMID, no PMCID. NDI's reader recovers those over the NETWORK
%                 (ndi.database.metadata_app.fun.resolveRelatedPublication,
%                 called from ndidataset2metadataeditorstruct.m:161).
%     the EDITOR  blob carries all four (Publication / DOI / PMID / PMCID).
%
%   0 of 6 corpora carry both stores (corpus run 31441923369: 1 graph-without-
%   editor, 1 editor-without-graph, 4 neither). So this pass MUST NOT fabricate
%   the difference: a `publication` assembled here gets its DOI and NOTHING
%   ELSE. An empty title is the honest record of what the graph holds.
%
%   ---------------------------------------------------------------------
%   THE SPECIFICATION IS NDI'S OWN READER
%   ---------------------------------------------------------------------
%   ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct rebuilds the
%   editor structure FROM the graph. Whatever it queries is what this consumes,
%   and the shape of every read below is taken from it:
%
%     :20      the anchor is  openminds.matlab_type == 'openminds.core.products.DatasetVersion'
%     :24      `find_newest` when several exist
%     :26-31   description / fullName / shortName / releaseDate /
%              versionIdentifier / versionInnovation, straight off dv_f
%     :40-43   author{i}(7:end)  -- every reference is the string
%              `ndi://<base.id>`, so the id starts at character 7
%     :92-100  funding -> awardTitle / awardNumber, and funder{1} -> an
%              Organization document whose fullName is the funder name
%     :104-108 fullDocumentation -> .IRI
%     :141-153 license -> webpage{2}, extension stripped, last path segment
%     :157-166 relatedPublication -> .identifier (a DOI), then a NETWORK lookup
%
%   and load_author_from_ndidocument (same package) for the person half:
%
%     familyName / givenName straight off the Person document;
%     affiliation{1} -> an Affiliation document -> memberOf{1} -> an
%     Organization document -> fullName;
%     digitalIdentifier{1} -> an ORCID document -> .identifier, then (19:end)
%     to strip the `https://orcid.org/` prefix the writer added
%     (convertFormDataToDocuments.addOrcidUriPrefix).
%
%   THREE READER FACTS THIS RESPECTS RATHER THAN INHERITS:
%
%     1. `fullDocumentation` IS BIMODAL. The writer tries
%        openminds.core.DOI first and falls back to openminds.core.WebResource
%        (convertFormDataToDocuments.m, the try/catch around
%        `datasetVersion.fullDocumentation`), while the reader unconditionally
%        reads `.IRI` -- which a DOI document does not have. Both shapes are
%        handled here and counted SEPARATELY, because a single total would hide
%        which one occurred.
%     2. TWO IRI VINTAGES ship for `openminds_type`
%        (`https://openminds.ebrains.eu/core/...` and
%        `https://openminds.om-i.org/types/...`), and the MATLAB namespace
%        differs between writer and reader too (`openminds.core.DatasetVersion`
%        is constructed; `openminds.core.products.DatasetVersion` is queried).
%        Every type test here matches the TRAILING SEGMENT only.
%     3. `core.Dataset` IS WRITTEN BUT NEVER READ -- only DatasetVersion is
%        queried. It is still CONSUMED here, and it has to be: it carries
%        `hasVersion` -> the DatasetVersion, so leaving it behind would dangle
%        that edge. See the orphan guard.
%
%   ---------------------------------------------------------------------
%   WHY A BATCH PASS AND NOT A MIGRATOR
%   ---------------------------------------------------------------------
%   ndi.database.fun.openMINDSobj2struct replaces every child object with an
%   `ndi://<childId>` string and openMINDSobj2ndi_document.m:77-90 turns each
%   into an `openminds_#` dependency, so ONE `person` needs FIVE documents
%   (Person + Affiliation + Organization + ORCID + ContactInformation). A
%   single-document migrator cannot follow an edge. Pass 1 is therefore a
%   guarded passthrough (did2.convert.migrators_j.openminds) and the assembly
%   happens here, with the batch in hand. The precedent is in-tree and this
%   pass is deliberately shaped like it: did2.convert.resolveDatasetEntities.
%
%   ORDER: THIS RUNS BEFORE resolveDatasetEntities, and that is load-bearing
%   rather than tidy. That pass keeps ONE `dataset` entity per id, the RICHEST
%   (resolveDatasetEntities.m:100-119, non-empty dataset fields + global
%   identifiers). The entity minted here is keyed on the same dataset id as the
%   bare stubs `dataset_remote` / `session_in_a_dataset` / `dataset_session_info`
%   mint, and carries fullName / shortName / description / version /
%   versionInnovation / releaseDate / license -- so it wins that ranking. If it
%   ran AFTER, the stub would already have been chosen and this entity would be
%   an unresolvable duplicate.
%
%   ---------------------------------------------------------------------
%   IDS: PRESERVED WHEREVER THE MODEL ALLOWS
%   ---------------------------------------------------------------------
%   Each openMINDS instance is its OWN document, which the editor blob is not,
%   so `person`, `funding`, `publication`, `web_resource` and `organization`
%   are minted with the source document's `base.id` -- an id-preserving 1:1
%   fold. did2.convert.migrators_j.metadata_editor cannot do this: it holds one
%   blob and mints a fresh id per author.
%
%   The `dataset` entity is the exception and deliberately so: it is keyed on
%   the DATASET id (base.session_id, = D.id()), not on the DatasetVersion
%   document's own id, because that is the id every dataset-level document and
%   every dataset-referencing relation converges on. Same rule as
%   +migrators_j/private/jDatasetId.m, which is a +migrators_j private helper
%   and therefore not visible from this package; the three-line rule is
%   restated in datasetIdOf below rather than duplicated by import.
%
%   ---------------------------------------------------------------------
%   THE ORPHAN GUARD -- the thing most likely to turn a green run red
%   ---------------------------------------------------------------------
%   Consumed `openminds` documents are referenced by other ones through
%   `openminds_1..n`. Consume a Person while its DatasetVersion survives and
%   that edge dangles: a gating orphan on a 0-orphan corpus gate. So:
%
%     CONSUMPTION IS ALL-OR-NONE PER CONNECTED COMPONENT.
%
%   Concretely, in four steps:
%
%     (1) COMPONENTS. The `openminds` documents are partitioned into connected
%         components over the UNDIRECTED reference graph -- every id reachable
%         through `depends_on` values AND through the `ndi://` strings inside
%         `openminds.fields`. Both routes, because an id can travel either way
%         and only `fields` says which role it fills.
%     (2) PLAN. Within a component holding a DatasetVersion, the planned set is
%         the citation closure: everything reachable from the DatasetVersion
%         through its fields EXCEPT `studiedSpecimen`, then closed UPWARD (any
%         openminds document referencing something already planned is added --
%         this is what pulls in `core.Dataset`).
%     (3) VERIFY, over the whole batch and not just the component. For every
%         planned id, every document that references it must also be planned.
%         A referrer outside the plan -- of ANY class, not only `openminds` --
%         fails the component.
%     (4) DECIDE, per component, all-or-none. A component that fails (3), or
%         that plans a document whose openMINDS type is subject-side, is
%         WITHHELD ENTIRELY: nothing consumed, nothing emitted, and the reason
%         is recorded in REPORT.withheld_reasons. Withholding leaves the corpus
%         exactly as pass 1 left it, which is the state it is green in.
%
%   A FIFTH, SEPARATE ALL-OR-NONE: VALIDATION. If any body this pass builds for
%   a component fails to validate, the WHOLE component is reverted -- nothing
%   appended and nothing consumed. Consuming sources whose replacements
%   quarantined would be silent loss with a green gate, which is the failure
%   this project keeps finding.
%
%   ---------------------------------------------------------------------
%   OUT OF SCOPE, BY THE TEAM'S BRIEF
%   ---------------------------------------------------------------------
%   Subject-side openMINDS types (Subject, BiologicalSex, Species, Strain,
%   RRID, StockNumber) are NOT touched: they overlap the existing
%   `openminds_subject` route and the signed strain decision
%   (ndi.migrate.internal.strainAssembly). They are excluded from the walk by
%   FIELD NAME (`studiedSpecimen`) and, belt and braces, by TYPE in step (4).
%
%   ---------------------------------------------------------------------
%   WHAT IS CONSUMED WITHOUT A HOME -- counted, not hidden
%   ---------------------------------------------------------------------
%   Three kinds of document must be consumed (they sit inside the planned set
%   and leaving them would dangle an edge) while the V_eta entity tier has
%   nowhere to put their content. Each is counted separately so the loss has a
%   number rather than a shrug:
%
%     Contribution / ContributionType    author ROLES ('1st Author',
%                                        'point of contact', 'Custodian').
%                                        `person` has no role field and
%                                        `directed_relation` has only
%                                        relation / method / sequence. Author
%                                        ORDER survives as `sequence`; the role
%                                        does not. metadata_editor drops these
%                                        too -- it never reads authorRole.
%     SemanticDataType                   `dataset` has no data-type field.
%                                        Bucket 2 of the metadata_editor model
%                                        (a per-subject projection).
%     technique                          likewise, and the type set is
%                                        open-ended by construction.
%
%   `experimental_approach` IS populated here, and that is not a new decision:
%   metadata_editor.m:50-52 states the field exists for exactly this path
%   ("only openMINDS IMPORT populates it -- a DatasetVersion states it
%   explicitly; the did_v1 corpus migration does not"), and the built schema
%   declares it `ontology_term` with mustBeScalar FALSE, i.e. a list.
%
%   AN AUTHOR'S SECOND AND LATER AFFILIATIONS ARE DROPPED, and that is
%   deliberate restraint rather than an oversight. metadata_editor's header
%   records the same loss and says it "needs a team call on whether a person
%   gets one `affiliated_with` edge per affiliation". This pass COULD emit one
%   edge each -- every affiliation is its own document here -- and emitting
%   them would be making that call. It takes the first, mirrors the editor
%   path, and counts the rest in REPORT.affiliations_beyond_first_dropped so
%   the team can see the size of the question.
%
%   See also: did2.convert.migrators_j.openminds,
%   did2.convert.migrators_j.metadata_editor, did2.convert.entities.entityDoc,
%   did2.convert.resolveDatasetEntities, ndi.migrate.internal.strainAssembly.

arguments
    result (1,1) struct
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.TargetVersion (1,:) char = 'V_eta'
end

% DENOMINATOR FIRST, and unconditionally -- Operating Rule 5. Every counter
% exists before a single document is read, so "did not run" (ran == false) and
% "ran and found nothing" (ran == true, all zero) are different readings of the
% struct rather than the same one.
report = struct( ...
    ... % --- what was looked at at all
    'documents_inspected',                  0, ...
    'documents_unreadable',                 0, ...
    'openminds_documents_seen',             0, ...
    'openminds_components_seen',            0, ...
    ... % --- the roots
    'dataset_versions_seen',                0, ...
    'dataset_versions_superseded_by_newer', 0, ...
    'components_without_dataset_version',   0, ...
    ... % --- the all-or-none decision, per component
    'components_planned',                   0, ...
    'components_consumed',                  0, ...
    'components_withheld',                  0, ...
    'components_reverted_on_validation',    0, ...
    'withheld_reasons',                     {{}}, ...
    'documents_consumed',                   0, ...
    ... % --- what was emitted
    'datasets_emitted',                     0, ...
    'persons_emitted',                      0, ...
    'persons_id_preserved',                 0, ...
    'organizations_emitted',                0, ...
    'organizations_id_preserved',           0, ...
    'funding_emitted',                      0, ...
    'funding_slots_empty_skipped',          0, ...
    'publications_emitted',                 0, ...
    'publications_without_doi_skipped',     0, ...
    'web_resources_emitted',                0, ...
    'web_resources_from_iri',               0, ...
    'web_resources_from_doi',               0, ...
    'experimental_approach_terms_emitted',  0, ...
    'relations_emitted',                    0, ...
    ... % --- consumed with nowhere to put it (a loss with a number on it)
    'affiliations_beyond_first_dropped',    0, ...
    'contribution_documents_consumed_without_a_home', 0, ...
    'data_type_documents_consumed_without_a_home',    0, ...
    'technique_documents_consumed_without_a_home',    0, ...
    ... % --- what landed
    'bodies_quarantined',                   0, ...
    'documents_appended',                   0, ...
    'ran',                                  false);
result.openminds_citations = report;

if ~strcmp(options.TargetVersion, 'V_eta')
    return;     % the entity tier exists only in V_eta.
end
if ~isfield(result, 'migrated') || isempty(result.migrated)
    report.ran = true;
    result.openminds_citations = report;
    return;
end
report.ran = true;

% ==========================================================================
% STAGE A -- read every document once. One this cannot read is COUNTED,
% never dropped.
% ==========================================================================
docs = result.migrated;
n = numel(docs);
report.documents_inspected = n;

bodies  = cell(1, n);
idOf    = repmat({''}, 1, n);
isOm    = false(1, n);
for k = 1:n
    try
        b = docs{k}.toStruct();
    catch
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    bodies{k} = b;
    idOf{k}   = baseField(b, 'id', '');
    if strcmp(classNameOf(b), 'openminds')
        isOm(k) = true;
        report.openminds_documents_seen = report.openminds_documents_seen + 1;
    end
end

if ~any(isOm)
    result.openminds_citations = report;
    return;     % nothing of this family here. Zeros above say so.
end

byId = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:n
    if ~isempty(idOf{k}); byId(idOf{k}) = k; end
end

% ==========================================================================
% STAGE B -- the reference graph, both routes.
% ==========================================================================
% referrers: target id -> the ids of every document pointing at it, over the
% WHOLE batch. The guard needs referrers of any class, not only `openminds`.
referrers = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:n
    if isempty(bodies{k}); continue; end
    targets = referencedIds(bodies{k});
    for t = 1:numel(targets)
        addUse(referrers, targets{t}, idOf{k});
    end
end

% ==========================================================================
% STAGE C -- connected components over the `openminds` documents.
% ==========================================================================
omIdx = find(isOm);
comp = zeros(1, n);          % component number per document index (0 = none)
nComp = 0;
for a = 1:numel(omIdx)
    seed = omIdx(a);
    if comp(seed) ~= 0; continue; end
    nComp = nComp + 1;
    stack = seed;
    comp(seed) = nComp;
    while ~isempty(stack)
        i = stack(end); stack(end) = [];
        neighbours = [omNeighboursOut(bodies{i}, byId, isOm), ...
                      omNeighboursIn(idOf{i}, referrers, byId, isOm)];
        for q = 1:numel(neighbours)
            j = neighbours(q);
            if comp(j) == 0
                comp(j) = nComp;
                stack(end+1) = j; %#ok<AGROW>
            end
        end
    end
end
report.openminds_components_seen = nComp;

% ==========================================================================
% STAGE D -- per component: plan, verify, decide, emit.
% ==========================================================================
removeMask = false(1, n);
appended = {};

for c = 1:nComp
    members = find(comp == c);
    % ONE ORGANIZATION MAP PER COMPONENT, deliberately, not one per batch. The
    % map is populated inside buildComponent, which runs BEFORE the validation
    % revert below -- so a batch-wide map that survived a reverted component
    % would hand a later component an organization id whose document was never
    % emitted, and that `affiliated_with` edge would dangle. Nothing is lost by
    % scoping it: an openMINDS Organization is a document, so two components
    % referencing the same one would be one component.
    orgIds = containers.Map('KeyType', 'char', 'ValueType', 'char');

    % --- the roots ---------------------------------------------------------
    roots = [];
    for a = 1:numel(members)
        if isOpenmindsType(bodies{members(a)}, 'DatasetVersion')
            roots(end+1) = members(a); %#ok<AGROW>
        end
    end
    report.dataset_versions_seen = report.dataset_versions_seen + numel(roots);
    if isempty(roots)
        report.components_without_dataset_version = ...
            report.components_without_dataset_version + 1;
        continue;   % a strain component, or anything else. Left untouched.
    end
    % `find_newest` -- ndidataset2metadataeditorstruct.m:24. Several versions
    % may exist; the newest is the one the reader speaks for. The others are
    % still CONSUMED (they sit in the planned set) and their content is not
    % emitted, so they are counted rather than absorbed.
    root = newestOf(roots, bodies);
    report.dataset_versions_superseded_by_newer = ...
        report.dataset_versions_superseded_by_newer + (numel(roots) - 1);

    % --- (2) PLAN ----------------------------------------------------------
    planned = citationClosure(roots, bodies, byId, isOm);
    planned = closeUpward(planned, members, bodies, byId, isOm);
    report.components_planned = report.components_planned + 1;

    % --- (4a) subject-side types are out of scope --------------------------
    why = '';
    for a = 1:numel(planned)
        if routeIsSubjectSide(bodies{planned(a)})
            why = sprintf(['component %d plans a subject-side openMINDS ' ...
                'document (%s) -- out of scope for the citation build ' ...
                '(openminds_subject route + the signed strain decision)'], ...
                c, shortId(idOf{planned(a)}));
            break;
        end
    end

    % --- (3) VERIFY: no surviving document may reference a planned one -----
    if isempty(why)
        plannedIds = idOf(planned);
        for a = 1:numel(planned)
            who = {};
            if isKey(referrers, idOf{planned(a)}); who = referrers(idOf{planned(a)}); end
            outside = who(~ismember(who, plannedIds));
            if ~isempty(outside)
                why = sprintf(['component %d would leave %s referenced by %d ' ...
                    'surviving document(s) (e.g. %s) -- consuming it would ' ...
                    'dangle their openminds_# edge'], ...
                    c, shortId(idOf{planned(a)}), numel(outside), ...
                    shortId(outside{1}));
                break;
            end
        end
    end

    if ~isempty(why)
        report.components_withheld = report.components_withheld + 1;
        report.withheld_reasons{end+1} = why;
        continue;   % ALL-OR-NONE: nothing consumed, nothing emitted.
    end

    % --- EMIT --------------------------------------------------------------
    [newBodies, tally] = buildComponent(root, bodies, byId, orgIds);

    % --- (5) VALIDATION IS ALSO ALL-OR-NONE --------------------------------
    [survived, quarantined] = validateBodies(newBodies, options);
    if ~isempty(quarantined)
        report.components_reverted_on_validation = ...
            report.components_reverted_on_validation + 1;
        report.bodies_quarantined = report.bodies_quarantined + numel(quarantined);
        result = appendQuarantine(result, quarantined);
        continue;   % REVERT: the sources stay, the entities are dropped.
    end

    for a = 1:numel(newBodies)
        id = newBodies{a}.base.id;
        if isKey(survived, id); appended{end+1} = survived(id); end %#ok<AGROW>
    end
    removeMask(planned) = true;
    report.documents_consumed = report.documents_consumed + numel(planned);
    report.components_consumed = report.components_consumed + 1;
    report = addTally(report, tally);
end

% ==========================================================================
% STAGE E -- land it.
% ==========================================================================
if isempty(appended) && ~any(removeMask)
    result.openminds_citations = report;
    return;
end
result.migrated = [docs(~removeMask), appended];
report.documents_appended = numel(appended);
result.summary = recountSummary(result);
result.openminds_citations = report;
end

% ===================== the plan ========================================

function planned = citationClosure(roots, bodies, byId, isOm)
%CITATIONCLOSURE Everything reachable from the DatasetVersion roots through the
%   openMINDS fields, EXCEPT the subject branch.
%
%   The exclusion is by FIELD NAME rather than by target type, because that is
%   where the boundary actually is: `studiedSpecimen` is the DatasetVersion's
%   only route into the subject half of the graph
%   (convertFormDataToDocuments.m, `datasetVersion.studiedSpecimen =
%   [subjects{:}]`), and every Species / BiologicalSex / Strain document hangs
%   off a Subject rather than off the version.
excluded = {'studiedSpecimen', 'studied_specimen'};
planned = [];
stack = roots;
seen = containers.Map('KeyType', 'double', 'ValueType', 'logical');
while ~isempty(stack)
    i = stack(end); stack(end) = [];
    if isKey(seen, i); continue; end
    seen(i) = true;
    planned(end+1) = i; %#ok<AGROW>
    f = openmindsFields(bodies{i});
    fn = fieldnames(f);
    for q = 1:numel(fn)
        if any(strcmp(fn{q}, excluded)); continue; end
        refs = ndiRefs(f.(fn{q}));
        for r = 1:numel(refs)
            if ~isKey(byId, refs{r}); continue; end
            j = byId(refs{r});
            if ~isOm(j) || isKey(seen, j); continue; end
            stack(end+1) = j; %#ok<AGROW>
        end
    end
end
planned = unique(planned);
end

function planned = closeUpward(planned, members, bodies, byId, isOm)
%CLOSEUPWARD Add any component member that REFERENCES something already
%   planned, to a fixpoint. This is what pulls in `core.Dataset`: it is written
%   but never read (only DatasetVersion is queried), and its `hasVersion` edge
%   points at the version, so leaving it behind would dangle that edge.
changed = true;
while changed
    changed = false;
    for a = 1:numel(members)
        i = members(a);
        if any(planned == i); continue; end
        refs = omNeighboursOut(bodies{i}, byId, isOm);
        if any(ismember(refs, planned))
            planned(end+1) = i; %#ok<AGROW>
            changed = true;
        end
    end
end
planned = unique(planned);
end

% ===================== the emitters ====================================

function [newBodies, tally] = buildComponent(root, bodies, byId, orgIds)
%BUILDCOMPONENT Every body this pass emits for ONE DatasetVersion.
%   The six entity classes + their directed_relations, built through
%   did2.convert.entities.* -- the same emitters
%   did2.convert.migrators_j.metadata_editor uses. Only the readers differ.
import did2.convert.entities.entityDoc
import did2.convert.entities.relationDoc
import did2.convert.entities.orgFor
import did2.convert.entities.buildGids
import did2.convert.entities.emptyGids

tally = struct('datasets_emitted', 0, 'persons_emitted', 0, ...
    'persons_id_preserved', 0, 'organizations_emitted', 0, ...
    'organizations_id_preserved', 0, 'funding_emitted', 0, ...
    'funding_slots_empty_skipped', 0, 'publications_emitted', 0, ...
    'publications_without_doi_skipped', 0, ...
    'web_resources_emitted', 0, 'web_resources_from_iri', 0, ...
    'web_resources_from_doi', 0, 'experimental_approach_terms_emitted', 0, ...
    'relations_emitted', 0, 'affiliations_beyond_first_dropped', 0, ...
    'contribution_documents_consumed_without_a_home', 0, ...
    'data_type_documents_consumed_without_a_home', 0, ...
    'technique_documents_consumed_without_a_home', 0);

dv = bodies{root};
f  = openmindsFields(dv);
datasetId = datasetIdOf(dv);
newBodies = {};

% --- the dataset entity (keyed on the dataset id, not this document's id) ---
fullName = firstNonEmpty(charField(f, {'fullName', 'full_name'}), ...
    charField(f, {'shortName', 'short_name'}));
if isempty(fullName); fullName = '(unnamed dataset)'; end   % as metadata_editor
datasetBlock = struct( ...
    'full_name',          fullName, ...
    'short_name',         charField(f, {'shortName', 'short_name'}), ...
    'version',            charField(f, {'versionIdentifier', 'version_identifier'}), ...
    'version_innovation', charField(f, {'versionInnovation', 'version_innovation'}), ...
    'description',        charField(f, {'description'}), ...
    'license',            licenseOf(f, byId, bodies), ...
    'release_date',       charField(f, {'releaseDate', 'release_date'}));
% Repeatable fields assigned after struct(): a cell inside struct() fans the
% struct out into an array (MATLAB gotcha).
datasetBlock.keyword         = {};   % not in the graph -- the editor blob's field
datasetBlock.support_channel = {};
% experimental_approach: THIS is the path metadata_editor.m:50-52 says
% populates it ("only openMINDS IMPORT populates it -- a DatasetVersion states
% it explicitly"). Declared mustBeScalar false, so it is a list.
approaches = termsFrom(f, {'experimentalApproach', 'experimental_approach'}, ...
    byId, bodies);
if ~isempty(approaches)
    datasetBlock.experimental_approach = approaches;
    tally.experimental_approach_terms_emitted = numel(approaches);
end
% how_to_cite / accessibility / ethics_assessment / copyright_year are NOT in
% the graph. Omitted rather than written blank: a blank is a vacuous field.
newBodies{end+1} = entityDoc(dv, 'dataset', datasetId, datasetBlock, ...
    emptyGids(), false);
tally.datasets_emitted = 1;

% --- authors -> person + has_author / affiliated_with -----------------------
authorRefs = refsOf(f, {'author'});
for i = 1:numel(authorRefs)
    if ~isKey(byId, authorRefs{i}); continue; end
    pIdx = byId(authorRefs{i});
    p    = bodies{pIdx};
    pf   = openmindsFields(p);
    personId = baseField(p, 'id', '');
    if isempty(personId); continue; end   % an id-preserving fold needs the id

    orcid = stripPrefix(charField(followFields(pf, ...
        {'digitalIdentifier', 'digital_identifier'}, byId, bodies), ...
        {'identifier'}), 'https://orcid.org/');
    email = charField(followFields(pf, ...
        {'contactInformation', 'contact_information'}, byId, bodies), {'email'});

    personBlock = struct( ...
        'given_name',  charField(pf, {'givenName', 'given_name'}), ...
        'family_name', charField(pf, {'familyName', 'family_name'}), ...
        'email',       email);
    newBodies{end+1} = entityDoc(p, 'person', personId, personBlock, ...
        buildGids({'ORCID', orcid}), true); %#ok<AGROW>
    tally.persons_emitted = tally.persons_emitted + 1;
    tally.persons_id_preserved = tally.persons_id_preserved + 1;
    newBodies{end+1} = relationDoc(dv, datasetId, personId, 'has_author', i); %#ok<AGROW>
    tally.relations_emitted = tally.relations_emitted + 1;

    % Affiliations. The FIRST only -- see the header: emitting one edge per
    % affiliation would be making a team call that is explicitly open.
    affRefs = refsOf(pf, {'affiliation'});
    if numel(affRefs) > 1
        tally.affiliations_beyond_first_dropped = ...
            tally.affiliations_beyond_first_dropped + (numel(affRefs) - 1);
    end
    if isempty(affRefs) || ~isKey(byId, affRefs{1}); continue; end
    aff = bodies{byId(affRefs{1})};
    orgBodyIdx = followFieldsIdx(openmindsFields(aff), ...
        {'memberOf', 'member_of'}, byId);
    if isempty(orgBodyIdx); continue; end
    org = bodies{orgBodyIdx};
    orgName = charField(openmindsFields(org), {'fullName', 'full_name'});
    if isempty(orgName); continue; end
    [orgId, orgBody] = orgFor(org, orgName, orgIds, baseField(org, 'id', ''));
    if ~isempty(orgBody)
        newBodies{end+1} = orgBody; %#ok<AGROW>
        tally.organizations_emitted = tally.organizations_emitted + 1;
        if strcmp(orgId, baseField(org, 'id', ''))
            tally.organizations_id_preserved = tally.organizations_id_preserved + 1;
        end
    end
    newBodies{end+1} = relationDoc(p, personId, orgId, 'affiliated_with', []); %#ok<AGROW>
    tally.relations_emitted = tally.relations_emitted + 1;
end

% --- funding -> funding + funded_by / issued_by -----------------------------
fundRefs = refsOf(f, {'funding'});
for i = 1:numel(fundRefs)
    if ~isKey(byId, fundRefs{i}); continue; end
    fu  = bodies{byId(fundRefs{i})};
    ff  = openmindsFields(fu);
    awardTitle  = charField(ff, {'awardTitle', 'award_title'});
    awardNumber = charField(ff, {'awardNumber', 'award_number'});
    funderIdx = followFieldsIdx(ff, {'funder'}, byId);
    funderName = '';
    if ~isempty(funderIdx)
        funderName = charField(openmindsFields(bodies{funderIdx}), ...
            {'fullName', 'full_name'});
    end
    if isempty(awardTitle) && isempty(awardNumber) && isempty(funderName)
        tally.funding_slots_empty_skipped = tally.funding_slots_empty_skipped + 1;
        continue;   % an empty funding slot carries nothing
    end
    awardId = baseField(fu, 'id', '');
    if isempty(awardId); continue; end
    newBodies{end+1} = entityDoc(fu, 'funding', awardId, ...
        struct('title', awardTitle), ...
        buildGids({'AwardNumber', awardNumber}), true); %#ok<AGROW>
    tally.funding_emitted = tally.funding_emitted + 1;
    newBodies{end+1} = relationDoc(dv, datasetId, awardId, 'funded_by', []); %#ok<AGROW>
    tally.relations_emitted = tally.relations_emitted + 1;

    if isempty(funderName); continue; end
    funder = bodies{funderIdx};
    [orgId, orgBody] = orgFor(funder, funderName, orgIds, baseField(funder, 'id', ''));
    if ~isempty(orgBody)
        newBodies{end+1} = orgBody; %#ok<AGROW>
        tally.organizations_emitted = tally.organizations_emitted + 1;
        if strcmp(orgId, baseField(funder, 'id', ''))
            tally.organizations_id_preserved = tally.organizations_id_preserved + 1;
        end
    end
    newBodies{end+1} = relationDoc(fu, awardId, orgId, 'issued_by', []); %#ok<AGROW>
    tally.relations_emitted = tally.relations_emitted + 1;
end

% --- related publications -> publication + cites ----------------------------
% THE GRAPH HOLDS ONLY A DOI. No title, no PMID, no PMCID -- NDI's reader gets
% those over the network. The title is left EMPTY on purpose; inventing one
% would fabricate the difference between the two stores, which is the one thing
% the team's decision says a migrator must not do.
pubRefs = refsOf(f, {'relatedPublication', 'related_publication'});
for i = 1:numel(pubRefs)
    if ~isKey(byId, pubRefs{i}); continue; end
    pub = bodies{byId(pubRefs{i})};
    doi = stripPrefix(charField(openmindsFields(pub), {'identifier'}), ...
        'https://doi.org/');
    if isempty(doi)
        tally.publications_without_doi_skipped = ...
            tally.publications_without_doi_skipped + 1;
        continue;
    end
    pubId = baseField(pub, 'id', '');
    if isempty(pubId); continue; end
    newBodies{end+1} = entityDoc(pub, 'publication', pubId, ...
        struct('title', ''), buildGids({'DOI', doi}), true); %#ok<AGROW>
    tally.publications_emitted = tally.publications_emitted + 1;
    newBodies{end+1} = relationDoc(dv, datasetId, pubId, 'cites', []); %#ok<AGROW>
    tally.relations_emitted = tally.relations_emitted + 1;
end

% --- full documentation -> web_resource + documented_by ---------------------
% BIMODAL, and the two arms are counted separately. The writer tries
% openminds.core.DOI first and falls back to WebResource; the reader reads
% `.IRI` unconditionally, which a DOI document does not have.
docRefs = refsOf(f, {'fullDocumentation', 'full_documentation'});
for i = 1:numel(docRefs)
    if ~isKey(byId, docRefs{i}); continue; end
    wr = bodies{byId(docRefs{i})};
    wf = openmindsFields(wr);
    iri = charField(wf, {'IRI', 'iri'});
    if ~isempty(iri)
        scheme = 'URL'; value = iri;
        tally.web_resources_from_iri = tally.web_resources_from_iri + 1;
    else
        value = stripPrefix(charField(wf, {'identifier'}), 'https://doi.org/');
        scheme = 'DOI';
        if isempty(value); continue; end
        tally.web_resources_from_doi = tally.web_resources_from_doi + 1;
    end
    wrId = baseField(wr, 'id', '');
    if isempty(wrId); continue; end
    newBodies{end+1} = entityDoc(wr, 'web_resource', wrId, ...
        struct('label', 'full documentation'), ...
        buildGids({scheme, value}), true); %#ok<AGROW>
    tally.web_resources_emitted = tally.web_resources_emitted + 1;
    newBodies{end+1} = relationDoc(dv, datasetId, wrId, 'documented_by', []); %#ok<AGROW>
    tally.relations_emitted = tally.relations_emitted + 1;
end

% --- consumed with no home. Counted, never summed into anything else. -------
tally.contribution_documents_consumed_without_a_home = ...
    numel(refsOf(f, {'otherContribution', 'other_contribution'}));
tally.data_type_documents_consumed_without_a_home = ...
    numel(refsOf(f, {'dataType', 'data_type'}));
tally.technique_documents_consumed_without_a_home = ...
    numel(refsOf(f, {'technique'}));
end

% ===================== openMINDS accessors =============================

function tf = isOpenmindsType(s, typeName)
%ISOPENMINDSTYPE Match the TRAILING segment of matlab_type or openminds_type.
%   Never the whole string: the MATLAB namespace differs between writer
%   (`openminds.core.DatasetVersion`) and reader
%   (`openminds.core.products.DatasetVersion`), and two IRI vintages ship.
tf = false;
if ~isstruct(s) || ~isfield(s, 'openminds') || ~isstruct(s.openminds); return; end
b = s.openminds(1);
mt = ''; ot = '';
if isfield(b, 'matlab_type');    mt = char(b.matlab_type);    end
if isfield(b, 'openminds_type'); ot = char(b.openminds_type); end
tf = endsWithSegment(mt, '.', typeName) || endsWithSegment(ot, '/', typeName);
end

function tf = routeIsSubjectSide(s)
%ROUTEISSUBJECTSIDE The types the team's brief puts out of scope. Belt and
%   braces beside the `studiedSpecimen` field exclusion: if a graph ever routes
%   a subject-side document into the citation half, the component is withheld
%   rather than silently consuming it.
names = {'Subject', 'SubjectState', 'BiologicalSex', 'Species', 'Strain', ...
    'GeneticStrainType', 'RRID', 'StockNumber', 'TissueSample', ...
    'TissueSampleState'};
tf = false;
for k = 1:numel(names)
    if isOpenmindsType(s, names{k}); tf = true; return; end
end
end

function tf = endsWithSegment(str, sep, seg)
tf = false;
str = char(str);
if isempty(str); return; end
parts = strsplit(str, sep);
tf = strcmpi(strtrim(parts{end}), seg);
end

function f = openmindsFields(s)
f = struct();
if isstruct(s) && isfield(s, 'openminds') && isstruct(s.openminds) ...
        && ~isempty(s.openminds)
    b = s.openminds(1);
    if isfield(b, 'fields') && isstruct(b.fields) && ~isempty(b.fields)
        f = b.fields(1);
    end
end
end

function ids = ndiRefs(v)
%NDIREFS The `ndi://<id>` document ids inside a fields value, in order.
ids = {};
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ~ischar(e); continue; end
    if startsWith(e, 'ndi://') && numel(e) > 6
        ids{end+1} = e(7:end); %#ok<AGROW>
    end
end
end

function out = refsOf(f, names)
%REFSOF The ndi:// ids under the first of NAMES that F carries.
out = ndiRefs(getAny(f, names));
end

function idx = followFieldsIdx(f, names, byId)
%FOLLOWFIELDSIDX The batch index of the FIRST document referenced by F.<name>.
idx = [];
refs = refsOf(f, names);
for k = 1:numel(refs)
    if isKey(byId, refs{k}); idx = byId(refs{k}); return; end
end
end

function g = followFields(f, names, byId, bodies)
%FOLLOWFIELDS The `fields` struct of the first document referenced by F.<name>.
g = struct();
idx = followFieldsIdx(f, names, byId);
if isempty(idx); return; end
g = openmindsFields(bodies{idx});
end

function terms = termsFrom(f, names, byId, bodies)
%TERMSFROM An ontology_term array from a list of controlled-term references.
%   node comes from whichever identifier the instance carries -- the same
%   fallback chain did2.convert.migrators_j.openminds_subject uses.
terms = struct('node', {}, 'name', {});
refs = refsOf(f, names);
for k = 1:numel(refs)
    if ~isKey(byId, refs{k}); continue; end
    cf = openmindsFields(bodies{byId(refs{k})});
    nm = charField(cf, {'name'});
    nd = charField(cf, {'preferredOntologyIdentifier', ...
        'preferred_ontology_identifier', 'ontologyIdentifier', ...
        'ontology_identifier', 'interlexIdentifier', 'interlex_identifier'});
    if isempty(nm) && isempty(nd); continue; end
    terms(end+1) = struct('node', nd, 'name', nm); %#ok<AGROW>
end
end

function lic = licenseOf(f, byId, bodies)
%LICENSEOF The dataset's license, as a short name.
%
%   ndidataset2metadataeditorstruct.m:141-153 derives it from `webpage{2}` --
%   the SECOND entry -- by stripping the file extension and taking the last
%   path segment. That index is not a property of the model, it is a property
%   of the instance files the app happened to load, so it is the LAST resort
%   here rather than the first: shortName, then fullName, then the reader's
%   derivation over every webpage entry in order. Empty when the license
%   document carries none of the three -- never guessed.
lic = '';
idx = followFieldsIdx(f, {'license'}, byId);
if isempty(idx); return; end
lf = openmindsFields(bodies{idx});
lic = firstNonEmpty(charField(lf, {'shortName', 'short_name'}), ...
    charField(lf, {'fullName', 'full_name'}));
if ~isempty(lic); return; end
pages = cellstrField(lf, {'webpage'});
for k = 1:numel(pages)
    w = pages{k};
    dots = strfind(w, '.');
    if ~isempty(dots) && dots(end) > 1; w = w(1:dots(end)-1); end
    segs = strsplit(w, '/');
    cand = strrep(strtrim(segs{end}), '"', '');
    if ~isempty(cand); lic = cand; return; end
end
end

% ===================== graph helpers ===================================

function out = referencedIds(s)
%REFERENCEDIDS Every document id this body points at -- `depends_on` values and
%   the `ndi://` strings inside `openminds.fields`. Both routes: the id can
%   travel either way and only the `fields` route says which role it fills.
out = {};
if isstruct(s) && isfield(s, 'depends_on') && isstruct(s.depends_on)
    for k = 1:numel(s.depends_on)
        d = s.depends_on(k);
        v = '';
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        end
        if ~isempty(v); out{end+1} = v; end %#ok<AGROW>
    end
end
f = openmindsFields(s);
fn = fieldnames(f);
for k = 1:numel(fn)
    r = ndiRefs(f.(fn{k}));
    for j = 1:numel(r); out{end+1} = r{j}; end %#ok<AGROW>
end
% `unique` on a cellstr returns a COLUMN; reshape so a caller's index loop sees
% N entries rather than one.
out = reshape(unique(out), 1, []);
end

function idx = omNeighboursOut(s, byId, isOm)
%OMNEIGHBOURSOUT The `openminds` documents this body points at.
idx = [];
refs = referencedIds(s);
for k = 1:numel(refs)
    if ~isKey(byId, refs{k}); continue; end
    j = byId(refs{k});
    if isOm(j); idx(end+1) = j; end %#ok<AGROW>
end
end

function idx = omNeighboursIn(id, referrers, byId, isOm)
%OMNEIGHBOURSIN The `openminds` documents pointing at ID.
idx = [];
if isempty(id) || ~isKey(referrers, id); return; end
who = referrers(id);
for k = 1:numel(who)
    if ~isKey(byId, who{k}); continue; end
    j = byId(who{k});
    if isOm(j); idx(end+1) = j; end %#ok<AGROW>
end
end

function root = newestOf(roots, bodies)
%NEWESTOF ndi.document.find_newest, restated: the largest ISO-8601 datestamp
%   wins (they sort lexicographically), and a tie falls to the FIRST, so the
%   answer is deterministic on a batch whose documents share a stamp -- which
%   is the normal case for one editor save.
root = roots(1);
best = char(creationTime(bodies{root}));
for k = 2:numel(roots)
    ds = char(creationTime(bodies{roots(k)}));
    if isNewerStamp(ds, best)
        root = roots(k); best = ds;
    end
end
end

function tf = isNewerStamp(a, b)
tf = false;
if isempty(a); return; end
if isempty(b); tf = true; return; end
if strcmp(a, b); return; end
ordered = sort({a, b});          % ascending, lexicographic
tf = strcmp(ordered{end}, a);
end

function id = datasetIdOf(s)
%DATASETIDOF The canonical dataset id -- D.id(), which every dataset-level
%   document carries as base.session_id. Same rule as
%   +migrators_j/private/jDatasetId.m, restated because a +migrators_j private
%   helper is not visible from this package.
id = '';
if isstruct(s) && isfield(s, 'base') && isstruct(s.base)
    if isfield(s.base, 'session_id') && ~isempty(s.base.session_id)
        id = char(s.base.session_id);
    elseif isfield(s.base, 'id') && ~isempty(s.base.id)
        id = char(s.base.id);
    end
end
if isempty(id); id = did.ido.unique_id(); end
end

% ===================== struct accessors ================================

function v = getAny(s, names)
v = [];
if ~isstruct(s); return; end
for k = 1:numel(names)
    if isfield(s, names{k}) && ~isempty(s.(names{k}))
        v = s.(names{k});
        return;
    end
end
end

function c = charField(s, names)
c = firstChar(getAny(s, names));
end

function c = firstChar(v)
c = '';
if isempty(v); return; end
if isstring(v); v = cellstr(v); end
if iscell(v)
    if isempty(v); return; end
    v = v{1};
    if isstring(v); v = char(v); end
end
if ischar(v); c = strtrim(v); end
end

function out = cellstrField(s, names)
out = {};
v = getAny(s, names);
if isempty(v); return; end
if ischar(v); v = {v}; end
if isstring(v); v = cellstr(v); end
if ~iscell(v); return; end
for k = 1:numel(v)
    e = v{k};
    if isstring(e); e = char(e); end
    if ischar(e) && ~isempty(strtrim(e)); out{end+1} = strtrim(e); end %#ok<AGROW>
end
end

function s = firstNonEmpty(varargin)
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function out = stripPrefix(str, prefix)
out = char(str);
if numel(out) > numel(prefix) && strncmpi(out, prefix, numel(prefix))
    out = out(numel(prefix)+1:end);
end
end

function c = classNameOf(s)
c = '';
if isstruct(s) && isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isstruct(s) && isfield(s, 'base') && isstruct(s.base) && isfield(s.base, name) ...
        && ~isempty(s.base.(name))
    v = s.base.(name);
end
end

function addUse(map, key, user)
if isempty(key) || isempty(user); return; end
if isKey(map, key); cur = map(key); else; cur = {}; end
if ~any(strcmp(cur, user)); cur{end+1} = user; end
map(key) = cur; %#ok<NASGU>
end

function s = shortId(idStr)
s = char(idStr);
if numel(s) > 8; s = s(1:8); end
end

function report = addTally(report, tally)
fn = fieldnames(tally);
for k = 1:numel(fn)
    report.(fn{k}) = report.(fn{k}) + tally.(fn{k});
end
end

% ===================== batch plumbing ==================================

function [survived, quarantined] = validateBodies(newBodies, options)
%VALIDATEBODIES Push bodies through v1_to_v2 and return what survived, by id.
%   The bodies carry schema_version == TargetVersion, so v1_to_v2 short-circuits
%   them (isAlreadyTarget) to ensureClassBlocks + validate.
survived = containers.Map('KeyType', 'char', 'ValueType', 'any');
quarantined = struct('original_body', {}, 'class_name', {}, 'identifier', {}, ...
    'reason', {}, 'failed_at', {});
if isempty(newBodies); return; end
out = did2.convert.v1_to_v2(newBodies, ...
    'Validate',      options.Validate, ...
    'SchemaCache',   options.SchemaCache, ...
    'TargetVersion', options.TargetVersion);
for k = 1:numel(out.migrated)
    try
        survived(char(out.migrated{k}.get('base.id'))) = out.migrated{k};
    catch
    end
end
if isfield(out, 'quarantine') && ~isempty(out.quarantine)
    quarantined = out.quarantine;
end
end

function result = appendQuarantine(result, quarantined)
if isfield(result, 'quarantine') && ~isempty(result.quarantine)
    result.quarantine = [result.quarantine, quarantined];
else
    result.quarantine = quarantined;
end
end

function summary = recountSummary(result)
%RECOUNTSUMMARY Same contract as resolveDatasetEntities' local copy.
summary = struct();
if isfield(result, 'summary') && isstruct(result.summary); summary = result.summary; end
summary.migrated_count = numel(result.migrated);
if isfield(result, 'quarantine'); summary.quarantine_count = numel(result.quarantine); end
byClass = struct();
for k = 1:numel(result.migrated)
    fieldName = matlab.lang.makeValidName(result.migrated{k}.className());
    if isfield(byClass, fieldName)
        byClass.(fieldName) = byClass.(fieldName) + 1;
    else
        byClass.(fieldName) = 1;
    end
end
summary.by_class = byClass;
end

function ts = creationTime(body)
%CREATIONTIME The document's creation time, EITHER VINTAGE.
%   V_eta renamed `base.datestamp` -> `base.creation_timestamp` (did-schema,
%   signed 2026-08-13) and the rename is applied OUTBOUND, inside
%   did2.convert.v1_to_v2 (renameOutboundBaseFields, v1_to_v2.m:272). Every
%   batch post-pass runs AFTER that, so the bodies reaching this file carry
%   the NEW key while a pre-migration body carries the old one.
%
%   Reading only `datestamp` returned '' on every migrated document and the
%   caller then substituted a default -- a WRONG timestamp on a valid-looking
%   document, which no gate would ever flag. That is the quiet half of the
%   same rename whose loud half stopped the database write dead
%   (did2.database.sqlitedb/requireCreationTimestamp).
%
%   Returns '' when neither key is present, so callers keep their own
%   fallback rather than having one imposed here.
ts = '';
if ~isstruct(body) || ~isfield(body, 'base') || ~isstruct(body.base)
    return;
end
for name = {'creation_timestamp', 'datestamp'}
    f = name{1};
    if isfield(body.base, f) && ~isempty(body.base.(f))
        ts = body.base.(f);
        return;
    end
end
end
