function v2Body = metadata_editor(preBody)
%METADATA_EDITOR Brainstorm-J migrator: did_v1 metadata_editor -> a structured
%   `dataset` entity + the person / organization / funding / publication /
%   web_resource entities it references + the `directed_relation`s that connect
%   them. Strict J stops storing dataset metadata as one opaque
%   `metadata_structure` blob (the NDIMetaDataEditorApp serialization) and
%   instead decomposes it into first-class, queryable entities, exactly as the
%   subject side stopped storing openMINDS bundles.
%
%   1 -> N. The blob (`metadata_editor.metadata_structure`, built by
%   ndi.database.metadata_ds_core.convertDatasetInfoToDocument) is split into
%   three buckets:
%
%   Bucket 1 -- INTRINSIC IDENTITY -> typed entity fields (kept):
%     - dataset       full_name<-DatasetFullName, short_name<-DatasetShortName,
%                     version<-VersionIdentifier, version_innovation<-VersionInnovation,
%                     description<-Description, how_to_cite<-HowToCite,
%                     license<-License, release_date<-ReleaseDate, keyword<-Keyword,
%                     support_channel<-SupportChannel, and the openMINDS controlled-term
%                     fields accessibility<-Accessibility (an ontology_term, open
%                     node until the openMINDS IRI is resolved), and
%                     EthicsAssessment, handed to entityDoc as `ethics_assessment`
%                     and written by did2.convert.ethicsJurisdiction as an `ethics
%                     jurisdiction` (EMPTY:0000359) assertion: "EU compliant" /
%                     "EU compliant +" -> European Union (the "+" a note), "US
%                     compliant" -> United States, any other value -> no
%                     statement, counted (Jess Haley 2026-10-22 [ethics assessment
%                     to jurisdiction]; the obsolete EMPTY:0000355 is not
%                     written). (id preserved from base.id.) These openMINDS
%                     DatasetVersion properties have field homes (full-field parity),
%                     so they are stored, not dropped. experimental_approach is the
%                     exception -- see bucket 2 (it is a per-subject projection).
%     - person        one per Author: given_name<-givenName,
%                     family_name<-familyName, email<-contactInformation.email,
%                     ORCID -> global_identifier{scheme='ORCID'}.
%     - organization  author affiliations (affiliation.memberOf.fullName) and
%                     funders (Funding.funder), name-deduplicated.
%     - funding       one per Funding: title<-awardTitle,
%                     awardNumber -> global_identifier{scheme='AwardNumber'}.
%     - publication   RelatedPublication: title<-Publication,
%                     DOI/PMID/PMCID -> global_identifier.
%     - web_resource  FullDocumentation IRI -> global_identifier{scheme='URL'}.
%
%   Bucket 1 -- RELATIONSHIPS -> directed_relation (kept, as edges not fields):
%     dataset -has_author-> person       (order = author position)
%     person  -affiliated_with-> organization
%     dataset -funded_by-> funding
%     funding -issued_by-> organization  (the funder)
%     dataset -cites-> publication
%     dataset -documented_by-> web_resource
%
%   ExperimentalApproach, TechniquesEmployed and DataType are KEPT since
%     2026-10-26 ([dataset form terms]): term assertions about the dataset, each
%     value a term of its binding's closed list; a value outside it carries the
%     form whole as v1. Subjects, SpeciesList, StrainList and BiologicalSexList
%     are no longer dropped either: a non-empty one carries the form whole as v1
%     under a needs-home row ([dataset form lists carried until homed], Jess
%     Haley, 2026-10-27). The text below is the record of the earlier drop.
%
%   Bucket 2 -- PER-SUBJECT PROJECTIONS -> not persisted on migration. Subjects
%     (SpeciesList / StrainList / BiologicalSexList), DataType, TechniquesEmployed,
%     and ExperimentalApproach are summaries derivable from the dataset's subject
%     `term_assertion`s / `subject_statement`s (D-D "drop-fully-with-projection"):
%     storing them here would duplicate the per-subject truth and drift from it, so
%     they are recomputed as a query-time projection. (The dataset schema keeps an
%     experimental_approach field, but only openMINDS IMPORT populates it -- a
%     DatasetVersion states it explicitly; the did_v1 corpus migration does not.)
%
%   Bucket 3 -- GUI STATE -> dropped. Any editor-app view state (selected tab,
%     visibility, tooltips) is not dataset identity. (VersionInnovation is genuine
%     dataset metadata, not view state, so it moves to bucket 1.)
%
%   ---------------------------------------------------------------------
%   SHAPE TOLERANCE -- WHY THE READERS BELOW ACCEPT A CELL
%   ---------------------------------------------------------------------
%   STATUS 2026-08-11: this shape-tolerance edit and its five new tests were
%   WRITTEN WITHOUT MATLAB. There is neither MATLAB nor Octave in the
%   container they were authored in, so NOTHING HERE HAS BEEN EXECUTED. The
%   mutation check was a transcription of jsondecode's documented array rule
%   plus the two readers changed here, not a run. CI is the gate.
%
%   A corpus body reaches this migrator as raw JSON text that
%   `v1_to_v2/ensureStruct` hands to `jsondecode` (v1_to_v2.m:332-341); the
%   hand-built struct fixtures in testMigratorsJ.m do NOT take that path.
%   jsondecode turns a JSON array of objects into a STRUCT ARRAY only when
%   every object carries the same field names IN THE SAME ORDER; otherwise it
%   returns a CELL of scalar structs. The old `getStructArray` accepted a
%   struct array only and answered `struct([])` for a cell, so the Author /
%   Funding / RelatedPublication loops below ran ZERO times and the migrator
%   emitted a lone `dataset` body -- no error, no counter, nothing.
%
%   That loss is invisible to every detector we have: `unconverted_by_class`
%   sees output ~= input (a `dataset` IS emitted), `isFragment` sees a
%   substantive `dataset`, the empty-required-edge census sees nothing
%   (`dataset`/`person` declare `depends_on: []`), and the vacuous-required-
%   field census was defeated by the old `full_name = '(unnamed dataset)'`
%   fallback (retired 2026-10-25, [dataset name not invented]). So the only thing that can catch it is a test that
%   drives the migrator through a real jsonencode/jsondecode round trip --
%   testMigratorsJ.m's `runJRoundTrip` block.
%
%   The idiom is the pipeline's own, not a new one: `jEpochClockReferences`
%   (clockNames/intervalColumns, "the two shapes a serialisation round-trip
%   can leave behind"), `jFileMatchList:71`, `epochfiles_ingested:158`,
%   `sourceCensus:407` and `silentLoss:984` all read the cell alternative.
%
%   NOT CLAIMED: that any corpus document in hand delivers `Author` as a cell.
%   The task that prompted this edit attributed the cell to VALUE-type
%   heterogeneity (`AuthorData.getDefaultAuthorItem` setting
%   `affiliation = struct.empty` beside a filled author's struct); that is NOT
%   jsondecode's trigger -- differing field-name SETS or ORDER is, and every
%   NDI writer of this blob builds `Author` as a uniform MATLAB struct array
%   (`AuthorData.AuthorList (:,1) struct`, `table2struct` for Funding /
%   RelatedPublication). The guard is here because the failure mode is silent
%   and undetectable, not because a cell has been observed.
%
%   SEVERAL AFFILIATIONS: `AuthorData.addAffiliation` grows an author's
%   `affiliation` into a struct ARRAY (`affiliation(end+1) = affiliationStruct`,
%   +class/AuthorData.m). Each affiliation gets its own `affiliated_with`
%   relation (schema:affiliation) to its organization, in the order v1 lists
%   them. Decided by Jess Haley, 2026-10-27 [one affiliation relation each]
%   (did-schema V_eta_go_forward_class_audit.md; answers did-schema #148),
%   replacing the carry-054 interim that carried such a document whole as v1.
%
%   READS RAW v1 (did2.convert.rawV1Classes, 2026-10-27; Decided by Jess Haley,
%   2026-10-26 [migrators read raw v1], did-schema
%   V_eta_go_forward_class_audit.md): v1_to_v2 hands this migrator the document
%   exactly as v1 wrote it (NDI metadata_editor.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+database/+metadata_ds_core/
%   saveEditor2Doc.m writes it: base.id new, base.session_id = the dataset's
%   id, the form in metadata_editor.metadata_structure via
%   convertDatasetInfoToDocument). did2.convert.roundtrip.metadata_editor
%   rebuilds the v1 document and testRawV1RoundTripSession compares the two.
%   Where each v1 field goes is the bucket list above; in addition:
%
%     base.session_id  -> the dataset entity's id
%     base.datestamp   -> the creation_timestamp of every emitted document
%     base.id          -> NOT KEPT: a known finding, a question for the team
%     base.name        -> not kept ('' on every writer document)
%     metadata_structure.Subjects / SpeciesList / StrainList /
%       BiologicalSexList
%                      -> NOT DROPPED any more: a form whose list is not
%                         empty is carried whole as v1 under a needs-home
%                         row (Decided by Jess Haley, 2026-10-27 [dataset
%                         form lists carried until homed]); an empty list
%                         states nothing
%
%   A form field the migrator does not read (e.g. the writer's `Comments`,
%   an author's `authorRole`, an affiliation's other fields), or any other
%   field, block or edge, which the renamed path dropped without a word, now
%   carries the document whole as v1 (private/jRawAccount, jRawCarry and
%   formUnread below; carry-100, [fields outside the template are
%   malformed]); what the renamed path would have
%   discarded (an `ndi_document` beside `base`, a depends_on `version`) is
%   carried, carry-049, as before.

arguments
    preBody (1,1) struct
end

% THE RAW READ (see READS RAW v1 above): what the migrator does not read
% carries the untouched v1 document; a legacy identity block is read as base.
src = preBody;
[preBody, collision, unplaced0] = jRawAccount(src, ...
    struct('metadata_editor', {{'metadata_structure'}}), {});
if isempty(collision) && isfield(preBody, 'metadata_editor') ...
        && isstruct(preBody.metadata_editor) && isscalar(preBody.metadata_editor)
    unplaced0 = [unplaced0, formUnread(getScalarStruct(preBody.metadata_editor, ...
        'metadata_structure'))];
end
if jRawCarry('metadata_editor', src, collision, unplaced0, 'carry-100')
    v2Body = {src};
    return;
end

% ---------------------------------------------------------------------
% THE EMITTERS MOVED OUT, 2026-08-11. `entityDoc` / `relationDoc` / `orgFor` /
% `buildGids` / `emptyGids` / `freshBase` were local functions here and are now
% did2.convert.entities.*, because a SECOND reader of the same six entity
% classes exists: did2.convert.resolveOpenmindsCitations, which reads the
% openMINDS dataset graph instead of this blob (TEAM DECISION 2026-08-11,
% "Do B"). Only the readers differ; the emitted shape must not. Copying them
% would have produced two spellings of one document shape inside one dataset.
%
% NOTHING ABOUT THIS MIGRATOR'S OUTPUT CHANGED -- the bodies moved verbatim.
% The one addition is orgFor's optional 4th argument (an id to preserve), which
% this path does not pass.
% ---------------------------------------------------------------------
import did2.convert.entities.entityDoc
import did2.convert.entities.relationDoc
import did2.convert.entities.orgFor
import did2.convert.entities.buildGids
import did2.convert.entities.emptyGids

block = struct();
if isfield(preBody, 'metadata_editor') && isstruct(preBody.metadata_editor)
    block = preBody.metadata_editor;
end
ms = getScalarStruct(block, 'metadata_structure');

% [generic stage is lossless] and [partly placed is carried as v1] (Jess Haley,
% 2026-10-25, did-schema V_eta_go_forward_class_audit.md): two things this
% migrator cannot place carry the document WHOLE as v1 instead of being dropped:
%   - an EthicsAssessment that did2.convert.ethicsJurisdiction does not
%     recognise (it made no statement, only a report note);
%   - (an author with several affiliations is no longer one of them: each
%     affiliation gets its own relation, [one affiliation relation each].)
unplaced = {};
ethicsText = getChar(ms, 'EthicsAssessment');
if ~isempty(strtrim(ethicsText)) && isempty(did2.convert.ethicsJurisdiction(ethicsText))
    unplaced{end+1} = sprintf('[carry-044] EthicsAssessment "%s"', strtrim(ethicsText));
end
% [dataset form terms] (Decided by Jess Haley, 2026-10-25, did-schema
% V_eta_go_forward_class_audit.md; terms [census terms], 2026-10-26): the form's
% ExperimentalApproach, TechniquesEmployed and DataType are kept as term
% assertions about the dataset entity, each value a term of the binding's closed
% list (experimental approach EMPTY:0000356; Technique NCIT:C16847 and
% Scientific Data Type NCIT:C175886, valued by openMINDS terms). "A form value
% that is not in the list carries the form whole as v1 rather than being
% dropped."
[formTerms, formUnplaced] = datasetFormTerms(ms, char(preBody.base.id));
unplaced = [unplaced, formUnplaced];
% [dataset form lists carried until homed] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): "a v1 dataset form whose
% subject, species, strain or sex list is non-empty is carried whole as v1 with
% a needs-home register row until those lists have a V2 home (likely rebuilt
% from the subjects); revises the earlier drop under [lossless means round
% trip]". The register row is carry-105.
for listField = {'Subjects', 'SpeciesList', 'StrainList', 'BiologicalSexList'}
    if isstruct(ms) && isscalar(ms) && isfield(ms, listField{1}) ...
            && ~isEmptyValueOf(ms.(listField{1}))
        unplaced{end+1} = sprintf('[carry-105] awaiting_home: %s', listField{1}); %#ok<AGROW>
    end
end
if ~isempty(unplaced)
    % carry-register: carry-043 carry-044 carry-105 (the items
    %   above). A form field
    %   whose binding the loaded schema does not hold is not a carry: it
    %   errors in datasetFormTerms ([pipeline defects are not carries])
    did2.convert.reportNote('carried_as_v1', 'metadata_editor', ...
        char(preBody.base.id), ['unplaced: ' strjoin(unplaced, '; ')]);
    v2Body = {src};     % a carry is the untouched v1 source
    return;
end

% The dataset entity is keyed on the DATASET id (D.id() = base.session_id), the
% id every dataset-level doc and every dataset-referencing relation converges on
% -- NOT this metadata_editor doc's own base.id. That is what makes the
% session_in_a_dataset / dataset_remote edges resolve to THIS dataset, and lets
% resolveDatasetEntities dedup the bare stubs against this rich entity.
datasetId = jDatasetId(preBody);
orgIds = containers.Map('KeyType', 'char', 'ValueType', 'char');  % name -> id (dedup)
bodies = {};

% --- the dataset entity (id preserved) --------------------------------------
% Scalar fields via struct(); list/term fields assigned after (a cell/array value
% inside struct() would fan the struct into an array -- MATLAB gotcha).
fullName = firstChar(getChar(ms, 'DatasetFullName'), getChar(ms, 'DatasetShortName'));
% No form name: full_name is left empty ("not stated"), never '(unnamed
% dataset)'. The dataset is identified by its local_identifier, the v1 reference
% ([dataset name not invented], Jess Haley, 2026-10-25).
datasetBlock = struct( ...
    'full_name',          fullName, ...
    'short_name',         getChar(ms, 'DatasetShortName'), ...
    'version',            getChar(ms, 'VersionIdentifier'), ...
    'version_innovation', getChar(ms, 'VersionInnovation'), ...
    'description',        getChar(ms, 'Description'), ...
    'how_to_cite',        getChar(ms, 'HowToCite'), ...
    'license',            getChar(ms, 'License'), ...
    'accessibility',      termOrBlank(getChar(ms, 'Accessibility')), ...
    'ethics_assessment',  termOrBlank(getChar(ms, 'EthicsAssessment')), ...  % -> EMPTY:0000359 via did2.convert.ethicsJurisdiction (entityDoc)
    'release_date',       getChar(ms, 'ReleaseDate'));
% Repeatable fields (empty -> conventional empty list).
datasetBlock.keyword         = getStrList(ms, 'Keyword');
datasetBlock.support_channel = getStrList(ms, 'SupportChannel');
% experimental_approach is DELIBERATELY not populated here: it is a per-subject
% projection (bucket 2), derivable from the dataset's subject term_assertions, so
% the v1 migration leaves it empty. The schema field remains for openMINDS-IMPORT
% round-trip (an imported DatasetVersion carries it explicitly), just not for the
% did_v1 corpus migration.
bodies = [bodies, entityDoc(preBody, 'dataset', datasetId, datasetBlock, ...
    emptyGids(), false)];

% --- authors -> person entities + has_author / affiliated_with relations -----
authors = getStructArray(ms, 'Author');
for i = 1:numel(authors)
    a = authors(i);
    orcid = nestedChar(a, {'digitalIdentifier', 'identifier'});
    personBlock = struct( ...
        'given_name',  getChar(a, 'givenName'), ...
        'family_name', getChar(a, 'familyName'), ...
        'email',       nestedChar(a, {'contactInformation', 'email'}));
    personId = did2.convert.mintId('person');
    bodies = [bodies, entityDoc(preBody, 'person', personId, personBlock, ...
        buildGids({'ORCID', orcid}), true)];
    bodies{end+1} = relationDoc(preBody, datasetId, personId, 'has_author', i - 1);   % order counts from 0 ([author order from 0], Jess Haley 2026-10-21)

    % one affiliated_with relation per affiliation, in v1's order ([one
    % affiliation relation each], Jess Haley 2026-10-27)
    affs = getStructArray(a, 'affiliation');
    for j = 1:numel(affs)
        affName = nestedChar(affs(j), {'memberOf', 'fullName'});
        if isempty(affName); continue; end
        [orgId, orgBody] = orgFor(preBody, affName, orgIds);
        if ~isempty(orgBody); bodies = [bodies, orgBody]; end
        bodies{end+1} = relationDoc(preBody, personId, orgId, 'affiliated_with', []);
    end
end

% --- funding -> funding entities + funded_by / issued_by relations -------------
funding = getStructArray(ms, 'Funding');
for i = 1:numel(funding)
    f = funding(i);
    awardTitle = getChar(f, 'awardTitle');
    awardNumber = getChar(f, 'awardNumber');
    if isempty(awardTitle) && isempty(awardNumber) && isempty(getChar(f, 'funder'))
        continue;   % an empty funding slot carries nothing
    end
    awardId = did2.convert.mintId('award');
    bodies = [bodies, entityDoc(preBody, 'funding', awardId, ...
        struct('title', awardTitle), buildGids({'AwardNumber', awardNumber}), true)];
    bodies{end+1} = relationDoc(preBody, datasetId, awardId, 'funded_by', []);

    funderName = getChar(f, 'funder');
    if ~isempty(funderName)
        [orgId, orgBody] = orgFor(preBody, funderName, orgIds);
        if ~isempty(orgBody); bodies = [bodies, orgBody]; end
        bodies{end+1} = relationDoc(preBody, awardId, orgId, 'issued_by', []);
    end
end

% --- related publication -> publication entity + cites relation --------------
pubs = getStructArray(ms, 'RelatedPublication');
for i = 1:numel(pubs)
    p = pubs(i);
    title = getChar(p, 'Publication');
    doi = getChar(p, 'DOI'); pmid = getChar(p, 'PMID'); pmcid = getChar(p, 'PMCID');
    if isempty(title) && isempty(doi) && isempty(pmid) && isempty(pmcid); continue; end
    pubId = did2.convert.mintId('publication');
    bodies = [bodies, entityDoc(preBody, 'publication', pubId, ...
        struct('title', title), ...
        buildGids({'DOI', doi}, {'PMID', pmid}, {'PMCID', pmcid}), true)];
    bodies{end+1} = relationDoc(preBody, datasetId, pubId, 'cites', []);
end

% --- full documentation IRI -> web_resource entity + documented_by relation --
docIRI = getChar(ms, 'FullDocumentation');
if ~isempty(docIRI)
    wrId = did2.convert.mintId('web_resource');
    bodies = [bodies, entityDoc(preBody, 'web_resource', wrId, ...
        struct('label', 'full documentation'), buildGids({'URL', docIRI}), true)];
    bodies{end+1} = relationDoc(preBody, datasetId, wrId, 'documented_by', []);
end

for i = 1:size(formTerms, 1)
    bodies{end+1} = jStatement(preBody, 'assertion', datasetId, ...
        formTerms{i, 1}, formTerms{i, 2}, 'ValueKind', 'term'); %#ok<AGROW>
end

v2Body = bodies;
end

function [terms, unplaced] = datasetFormTerms(ms, docId)
%DATASETFORMTERMS {variable, value} per form value of ExperimentalApproach,
%   TechniquesEmployed and DataType, each value matched (by label, or by its
%   node or the node's last segment -- openMINDS's own id, e.g. "derivedData")
%   to a term of the binding's closed `values` list in the binding registry;
%   UNPLACED names each value that matches none. A field whose binding the
%   loaded schema does not have is an error, did2:convert:schemaTooOld
%   ([pipeline defects are not carries], Jess Haley, 2026-10-26); DOCID names
%   the document in its message.
fields = { ...
    'ExperimentalApproach', 'EMPTY:0000356'; ...
    'TechniquesEmployed',   'NCIT:C16847'; ...
    'DataType',             'NCIT:C175886'};
terms = cell(0, 2);
unplaced = {};
reg = struct();
try
    reg = did2.schema.cache.shared().bindingRegistry;
catch
end
for f = 1:size(fields, 1)
    vals = getStrList(ms, fields{f, 1});
    if isempty(vals); continue; end
    row = bindingRow(reg, fields{f, 2});
    if isempty(row)
        % [pipeline defects are not carries] (Jess Haley, 2026-10-26, did-schema
        % V_eta_go_forward_class_audit.md): a binding the LOADED SCHEMA lacks is
        % a defect of the pipeline, not of the v1 document, so it is never a
        % carry. The run fails loudly; the cause is the schema it was given.
        error('did2:convert:schemaTooOld', ...
            ['metadata_editor "%s": the loaded schema is too old or incomplete: ' ...
             'its binding registry has no subject_statement_bindings row with ' ...
             'a closed `values` list for %s (the binding of the form field %s). ' ...
             'Load a did-schema that holds it (DID_SCHEMA_PATH); the document ' ...
             'is not carried for a schema defect.'], ...
            docId, fields{f, 2}, fields{f, 1});
    end
    for k = 1:numel(vals)
        t = matchValue(row.values, vals{k});
        if isempty(t)
            unplaced{end+1} = sprintf('[carry-043] %s "%s" (not in the closed list)', ...
                fields{f, 1}, vals{k}); %#ok<AGROW>
        else
            terms(end+1, :) = {struct('node', char(row.variable.node), ...
                'name', char(row.variable.name)), t}; %#ok<AGROW>
        end
    end
end
end

function row = bindingRow(reg, variableNode)
row = [];
if ~isstruct(reg) || ~isfield(reg, 'subject_statement_bindings'); return; end
rows = reg.subject_statement_bindings;
% A cell when the rows' fields differ (jsondecode); never concatenated.
for k = 1:numel(rows)
    if iscell(rows); r = rows{k}; else; r = rows(k); end
    if ~isstruct(r); continue; end
    if isfield(r, 'variable') && isstruct(r.variable) && isfield(r.variable, 'node') ...
            && strcmpi(char(r.variable.node), variableNode) ...
            && isfield(r, 'values') && ~isempty(r.values)
        row = r;
        return;
    end
end
end

function t = matchValue(values, v)
t = [];
v = strtrim(char(v));
for k = 1:numel(values)
    if iscell(values); e = values{k}; else; e = values(k); end
    if ~isstruct(e) || ~isfield(e, 'node'); continue; end
    node = char(e.node);
    name = '';
    if isfield(e, 'name'); name = char(e.name); end
    tail = node;
    cut = find(node == '/' | node == ':', 1, 'last');
    if ~isempty(cut); tail = node(cut+1:end); end
    if strcmpi(v, name) || strcmpi(v, node) || strcmpi(v, tail)
        t = struct('node', node, 'name', name);
        return;
    end
end
end

function paths = formUnread(ms)
%FORMUNREAD The form fields (metadata_structure, as NDI's editor writes it)
%   that hold a value and that no part of this migrator reads, each as a path.
%   Read: the bucket-1 fields; Author's givenName, familyName,
%   contactInformation.email, digitalIdentifier.identifier and
%   affiliation(k).memberOf.fullName; Funding's funder, awardTitle and
%   awardNumber; RelatedPublication's Publication, DOI, PMID and PMCID; the
%   three form-term fields. Subjects, SpeciesList, StrainList and
%   BiologicalSexList are read by the caller: a non-empty one carries the form
%   ([dataset form lists carried until homed], Jess Haley, 2026-10-27).
paths = {};
if ~isstruct(ms) || ~isscalar(ms)
    return;
end
top = {'DatasetFullName', 'DatasetShortName', 'VersionIdentifier', ...
    'VersionInnovation', 'Description', 'HowToCite', 'License', 'Accessibility', ...
    'EthicsAssessment', 'ReleaseDate', 'Keyword', 'SupportChannel', ...
    'FullDocumentation', 'ExperimentalApproach', 'TechniquesEmployed', 'DataType', ...
    'Subjects', 'SpeciesList', 'StrainList', 'BiologicalSexList'};
lists = struct( ...
    'Author', {{'givenName', 'familyName', 'contactInformation', ...
        'digitalIdentifier', 'affiliation'}}, ...
    'Funding', {{'funder', 'awardTitle', 'awardNumber'}}, ...
    'RelatedPublication', {{'Publication', 'DOI', 'PMID', 'PMCID'}});
fns = fieldnames(ms);
for k = 1:numel(fns)
    f = fns{k};
    if any(strcmp(f, top))
        continue;
    end
    if isfield(lists, f)
        items = getStructArray(ms, f);
        v = ms.(f);
        if ~isempty(v) && isempty(items)
            paths{end+1} = f; %#ok<AGROW>
            continue;
        end
        for i = 1:numel(items)
            paths = [paths, unreadOf(items(i), lists.(f), sprintf('%s(%d)', f, i))]; %#ok<AGROW>
            if strcmp(f, 'Author')
                paths = [paths, authorUnread(items(i), i)]; %#ok<AGROW>
            end
        end
        continue;
    end
    if ~isEmptyValueOf(ms.(f))
        paths{end+1} = f; %#ok<AGROW>
    end
end
end

function paths = authorUnread(a, i)
paths = {};
where = sprintf('Author(%d)', i);
paths = [paths, unreadOf(scalarOf(a, 'contactInformation'), {'email'}, ...
    [where '.contactInformation'])];
paths = [paths, unreadOf(scalarOf(a, 'digitalIdentifier'), {'identifier'}, ...
    [where '.digitalIdentifier'])];
if isfield(a, 'affiliation') && isstruct(a.affiliation)
    for j = 1:numel(a.affiliation)
        af = a.affiliation(j);
        w = sprintf('%s.affiliation(%d)', where, j);
        paths = [paths, unreadOf(af, {'memberOf'}, w)]; %#ok<AGROW>
        paths = [paths, unreadOf(scalarOf(af, 'memberOf'), {'fullName'}, [w '.memberOf'])]; %#ok<AGROW>
    end
elseif isfield(a, 'affiliation') && ~isEmptyValueOf(a.affiliation)
    paths{end+1} = [where '.affiliation'];
end
end

function s = scalarOf(a, f)
s = struct();
if isstruct(a) && isscalar(a) && isfield(a, f) && isstruct(a.(f)) && isscalar(a.(f))
    s = a.(f);
end
end

function paths = unreadOf(s, known, where)
paths = {};
if ~isstruct(s) || ~isscalar(s)
    return;
end
fns = fieldnames(s);
for k = 1:numel(fns)
    if ~any(strcmp(fns{k}, known)) && ~isEmptyValueOf(s.(fns{k}))
        paths{end+1} = [where '.' fns{k}]; %#ok<AGROW>
    end
end
end

function tf = isEmptyValueOf(v)
if isempty(v)
    tf = true;
elseif isstruct(v) && isscalar(v)
    tf = all(cellfun(@(f) isEmptyValueOf(v.(f)), fieldnames(v)));
elseif ischar(v) || (isstring(v) && isscalar(v))
    tf = isempty(strtrim(char(v)));
else
    tf = false;
end
end

% ===================== small helpers ===================================
%
% The BUILDERS that used to live here (entityDoc / relationDoc / orgFor /
% buildGids / emptyGids / freshBase) are did2.convert.entities.* as of
% 2026-08-11 -- see the note at the top of the function body. Only the READERS
% below are specific to the NDIMetaDataEditorApp blob.

function s = getChar(block, name)
%GETCHAR Read a char/string/scalar-numeric field as char ('' if absent).
s = '';
if isstruct(block) && isfield(block, name)
    v = block.(name);
    if ischar(v); s = v;
    elseif isstring(v) && isscalar(v); s = char(v);
    elseif iscell(v) && ~isempty(v) && (ischar(v{1}) || isstring(v{1})); s = char(v{1});
    elseif isnumeric(v) && isscalar(v); s = num2str(v);
    end
end
end

function s = nestedChar(block, path)
%NESTEDCHAR Walk a struct path (cell of field names); '' if any hop is absent.
cur = block;
for k = 1:numel(path)
    if isstruct(cur) && isscalar(cur) && isfield(cur, path{k})
        cur = cur.(path{k});
    else
        s = ''; return;
    end
end
if ischar(cur); s = cur;
elseif isstring(cur) && isscalar(cur); s = char(cur);
else; s = '';
end
end

function s = firstChar(varargin)
%FIRSTCHAR First non-empty char argument ('' if all empty).
s = '';
for k = 1:numel(varargin)
    if ~isempty(varargin{k}); s = varargin{k}; return; end
end
end

function s = getScalarStruct(block, name)
%GETSCALARSTRUCT Read a field as ONE scalar struct (empty struct if absent).
%   The metadata blob itself. Accepts the struct a live document carries, the
%   struct ARRAY a one-element JSON array decodes to, and the CELL jsondecode
%   returns for a heterogeneous array. `struct()` -- the answer for the NDI
%   template's own `"metadata_structure": []`, which decodes to a 0x0 double --
%   is UNCHANGED behaviour: every reader below then returns blank, the
%   dataset is left unnamed, and one bare `dataset` body is emitted,
%   which is the right answer for a document that states no metadata.
s = struct();
if ~(isstruct(block) && isfield(block, name)); return; end
v = block.(name);
if iscell(v)
    for k = 1:numel(v)
        if isstruct(v{k}) && ~isempty(v{k}); s = v{k}(1); return; end
    end
    return;
end
if isstruct(v) && ~isempty(v); s = v(1); end
end

function arr = getStructArray(block, name)
%GETSTRUCTARRAY Read a field as a struct array ('empty' if absent / not a list
%   of objects). Accepts BOTH shapes a JSON array of objects can arrive in --
%   see the SHAPE TOLERANCE note in the file header. A cell is normalised to a
%   struct array so callers keep indexing it with (i).
arr = struct([]);
if ~(isstruct(block) && isfield(block, name)); return; end
v = block.(name);
if isstruct(v)
    arr = v;
    return;
end
if ~iscell(v); return; end
items = {};
for k = 1:numel(v)
    e = v{k};
    if ~isstruct(e); continue; end
    for j = 1:numel(e)
        items{end+1} = e(j); %#ok<AGROW>
    end
end
if isempty(items); return; end
arr = toStructArray(items);
end

function arr = toStructArray(items)
%TOSTRUCTARRAY Concatenate scalar structs that need NOT agree on their fields.
%   A plain [items{:}] errors the moment two entries carry different field
%   names -- which is the very condition that made jsondecode hand back a cell
%   instead of a struct array. Missing fields become [], which every reader
%   here (getChar / nestedChar) already treats as absent.
names = {};
for k = 1:numel(items)
    f = fieldnames(items{k});
    for j = 1:numel(f)
        if ~any(strcmp(f{j}, names)); names{end+1} = f{j}; end %#ok<AGROW>
    end
end
if isempty(names)
    arr = repmat(struct(), 1, numel(items));
    return;
end
blank = cell2struct(repmat({[]}, numel(names), 1), names(:), 1);
arr = repmat(blank, 1, numel(items));
for k = 1:numel(items)
    f = fieldnames(items{k});
    for j = 1:numel(f)
        arr(k).(f{j}) = items{k}.(f{j});
    end
end
end

function c = getStrList(block, name)
%GETSTRLIST Read a field as a cellstr row (empty entries dropped). Handles char,
%   cellstr, string array, or a struct array carrying a name-like field -- the
%   shapes the NDIMetaDataEditorApp uses for its list-valued metadata.
c = {};
if ~(isstruct(block) && isfield(block, name)); return; end
v = block.(name);
if isempty(v); return; end
if ischar(v)
    c = {v};
elseif isstring(v)
    c = cellstr(v(:).');
elseif iscell(v)
    for k = 1:numel(v)
        if ischar(v{k}); c{end+1} = v{k}; %#ok<AGROW>
        elseif isstring(v{k}) && isscalar(v{k}); c{end+1} = char(v{k}); end %#ok<AGROW>
    end
elseif isstruct(v)
    for k = 1:numel(v)
        for nm = {'name', 'label', 'value'}
            s = getChar(v(k), nm{1});
            if ~isempty(s); c{end+1} = s; break; end %#ok<AGROW>
        end
    end
end
c = c(~cellfun(@isempty, c));
end

function t = termOrBlank(str)
%TERMORBLANK A scalar ontology_term {node, name}; name '' when absent (== the field
%   blank). node stays open ('') until the openMINDS instance IRI is resolved.
t = jOntologyTerm('', str);
end
