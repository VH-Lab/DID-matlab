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
%                     fields accessibility<-Accessibility, ethics_assessment<-
%                     EthicsAssessment (ontology_terms, open node until the openMINDS
%                     IRI is resolved). (id preserved from base.id.) These openMINDS
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
%     dataset -has_author-> person       (sequence = author position)
%     person  -affiliated_with-> organization
%     dataset -funded_by-> funding
%     funding -issued_by-> organization  (the funder)
%     dataset -cites-> publication
%     dataset -documented_by-> web_resource
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
%   field census is defeated by the `full_name = '(unnamed dataset)'` fallback
%   at the top of the body. So the only thing that can catch it is a test that
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
%   OPEN, FOUND WHILE DOING THIS, DELIBERATELY NOT FIXED HERE (out of scope --
%   a different reader, and it changes what is emitted): an author with TWO OR
%   MORE affiliations loses all of them. `AuthorData.addAffiliation` grows the
%   field into a struct ARRAY (`affiliation(end+1) = affiliationStruct`, +class/
%   AuthorData.m), and `nestedChar` below walks only SCALAR structs
%   (`isstruct(cur) && isscalar(cur)`), so it returns '' and no organization
%   and no `affiliated_with` edge is minted. This is not a round-trip artefact:
%   it fails identically on a hand-built struct fixture. Same silent-loss
%   family, same four blind detectors; needs a team call on whether a person
%   gets one `affiliated_with` edge per affiliation.

arguments
    preBody (1,1) struct
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
if isempty(fullName); fullName = '(unnamed dataset)'; end   % full_name is required
datasetBlock = struct( ...
    'full_name',          fullName, ...
    'short_name',         getChar(ms, 'DatasetShortName'), ...
    'version',            getChar(ms, 'VersionIdentifier'), ...
    'version_innovation', getChar(ms, 'VersionInnovation'), ...
    'description',        getChar(ms, 'Description'), ...
    'how_to_cite',        getChar(ms, 'HowToCite'), ...
    'license',            getChar(ms, 'License'), ...
    'accessibility',      termOrBlank(getChar(ms, 'Accessibility')), ...
    'ethics_assessment',  termOrBlank(getChar(ms, 'EthicsAssessment')), ...
    'release_date',       getChar(ms, 'ReleaseDate'));
% Repeatable fields (empty -> conventional empty list).
datasetBlock.keyword         = getStrList(ms, 'Keyword');
datasetBlock.support_channel = getStrList(ms, 'SupportChannel');
% experimental_approach is DELIBERATELY not populated here: it is a per-subject
% projection (bucket 2), derivable from the dataset's subject term_assertions, so
% the v1 migration leaves it empty. The schema field remains for openMINDS-IMPORT
% round-trip (an imported DatasetVersion carries it explicitly), just not for the
% did_v1 corpus migration.
bodies{end+1} = entityDoc(preBody, 'dataset', datasetId, datasetBlock, ...
    emptyGids(), false);

% --- authors -> person entities + has_author / affiliated_with relations -----
authors = getStructArray(ms, 'Author');
for i = 1:numel(authors)
    a = authors(i);
    orcid = nestedChar(a, {'digitalIdentifier', 'identifier'});
    personBlock = struct( ...
        'given_name',  getChar(a, 'givenName'), ...
        'family_name', getChar(a, 'familyName'), ...
        'email',       nestedChar(a, {'contactInformation', 'email'}));
    personId = did.ido.unique_id();
    bodies{end+1} = entityDoc(preBody, 'person', personId, personBlock, ...
        buildGids({'ORCID', orcid}), true);
    bodies{end+1} = relationDoc(preBody, datasetId, personId, 'has_author', i);

    affName = nestedChar(a, {'affiliation', 'memberOf', 'fullName'});
    if ~isempty(affName)
        [orgId, orgBody] = orgFor(preBody, affName, orgIds);
        if ~isempty(orgBody); bodies{end+1} = orgBody; end
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
    awardId = did.ido.unique_id();
    bodies{end+1} = entityDoc(preBody, 'funding', awardId, ...
        struct('title', awardTitle), buildGids({'AwardNumber', awardNumber}), true);
    bodies{end+1} = relationDoc(preBody, datasetId, awardId, 'funded_by', []);

    funderName = getChar(f, 'funder');
    if ~isempty(funderName)
        [orgId, orgBody] = orgFor(preBody, funderName, orgIds);
        if ~isempty(orgBody); bodies{end+1} = orgBody; end
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
    pubId = did.ido.unique_id();
    bodies{end+1} = entityDoc(preBody, 'publication', pubId, ...
        struct('title', title), ...
        buildGids({'DOI', doi}, {'PMID', pmid}, {'PMCID', pmcid}), true);
    bodies{end+1} = relationDoc(preBody, datasetId, pubId, 'cites', []);
end

% --- full documentation IRI -> web_resource entity + documented_by relation --
docIRI = getChar(ms, 'FullDocumentation');
if ~isempty(docIRI)
    wrId = did.ido.unique_id();
    bodies{end+1} = entityDoc(preBody, 'web_resource', wrId, ...
        struct('label', 'full documentation'), buildGids({'URL', docIRI}), true);
    bodies{end+1} = relationDoc(preBody, datasetId, wrId, 'documented_by', []);
end

v2Body = bodies;
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
%   `(unnamed dataset)` fallback fires, and one bare `dataset` body is emitted,
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
