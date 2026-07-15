function v2Body = metadata_editor(preBody)
%METADATA_EDITOR Brainstorm-J migrator: did_v1 metadata_editor -> a structured
%   `dataset` entity + the person / organization / award / publication /
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
%                     version<-VersionIdentifier, description<-Description,
%                     license<-License, release_date<-ReleaseDate. (id preserved
%                     from the source doc's base.id.)
%     - person        one per Author: given_name<-givenName,
%                     family_name<-familyName, email<-contactInformation.email,
%                     ORCID -> global_identifier{scheme='ORCID'}.
%     - organization  author affiliations (affiliation.memberOf.fullName) and
%                     funders (Funding.funder), name-deduplicated.
%     - award         one per Funding: title<-awardTitle,
%                     awardNumber -> global_identifier{scheme='AwardNumber'}.
%     - publication   RelatedPublication: title<-Publication,
%                     DOI/PMID/PMCID -> global_identifier.
%     - web_resource  FullDocumentation IRI -> global_identifier{scheme='URL'}.
%
%   Bucket 1 -- RELATIONSHIPS -> directed_relation (kept, as edges not fields):
%     dataset -has_author-> person       (sequence = author position)
%     person  -affiliated_with-> organization
%     dataset -funded_by-> award
%     award   -issued_by-> organization  (the funder)
%     dataset -cites-> publication
%     dataset -documented_by-> web_resource
%
%   Bucket 2 -- PROJECTIONS -> dropped. Subjects (SpeciesList / StrainList /
%     BiologicalSexList), DataType, ExperimentalApproach, TechniquesEmployed are
%     summaries derivable from the dataset's subject `term_assertion`s /
%     `subject_statement`s (D-D "drop-fully-with-projection"): storing them here
%     would duplicate the per-subject truth and drift from it. They are recomputed
%     as a query-time projection, not persisted.
%
%   Bucket 3 -- GUI STATE -> dropped. Any editor-app view state (selected tab,
%     visibility, tooltips, VersionInnovation prose) is not dataset identity.

arguments
    preBody (1,1) struct
end

block = struct();
if isfield(preBody, 'metadata_editor') && isstruct(preBody.metadata_editor)
    block = preBody.metadata_editor;
end
ms = struct();
if isfield(block, 'metadata_structure') && isstruct(block.metadata_structure) ...
        && ~isempty(block.metadata_structure)
    ms = block.metadata_structure(1);      % scalar struct; guard array shape
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
fullName = firstChar(getChar(ms, 'DatasetFullName'), getChar(ms, 'DatasetShortName'));
if isempty(fullName); fullName = '(unnamed dataset)'; end   % full_name is required
datasetBlock = struct( ...
    'full_name',    fullName, ...
    'short_name',   getChar(ms, 'DatasetShortName'), ...
    'version',      getChar(ms, 'VersionIdentifier'), ...
    'description',  getChar(ms, 'Description'), ...
    'license',      getChar(ms, 'License'), ...
    'release_date', getChar(ms, 'ReleaseDate'));
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

% --- funding -> award entities + funded_by / issued_by relations -------------
funding = getStructArray(ms, 'Funding');
for i = 1:numel(funding)
    f = funding(i);
    awardTitle = getChar(f, 'awardTitle');
    awardNumber = getChar(f, 'awardNumber');
    if isempty(awardTitle) && isempty(awardNumber) && isempty(getChar(f, 'funder'))
        continue;   % an empty funding slot carries nothing
    end
    awardId = did.ido.unique_id();
    bodies{end+1} = entityDoc(preBody, 'award', awardId, ...
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

% ===================== builders ========================================

function d = entityDoc(preBody, className, docId, blockStruct, gids, fresh)
%ENTITYDOC An `<className>` entity: entity.global_identifier + the class block.
d = struct();
d.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'entity', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
d.depends_on = struct('name', {}, 'value', {});
d.base = freshBase(preBody, ['migrated_', className]);
if ~fresh && isfield(preBody, 'base') && isstruct(preBody.base)
    d.base = preBody.base;           % dataset: preserve the whole source base
end
d.base.id = docId;                   % the id the relations reference is authoritative
% cell-wrap: gids may be an empty or multi-element struct array; without the
% cell, struct() would fan `d.entity` out into a struct array (MATLAB gotcha).
d.entity = struct('global_identifier', {gids});
d.(className) = blockStruct;
end

function rel = relationDoc(preBody, childId, parentId, relationName, sequence)
%RELATIONDOC child --relationName--> parent, both entities. `sequence` may be [].
rel = struct();
rel.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
rel.depends_on = [ ...
    struct('name', 'child',  'value', childId), ...
    struct('name', 'parent', 'value', parentId)];
rel.base = freshBase(preBody, ['migrated_dataset_', relationName]);
drBlock = struct('relation', jOntologyTerm('', relationName));
if ~isempty(sequence); drBlock.sequence = sequence; end
rel.directed_relation = drBlock;
end

function [orgId, orgBody] = orgFor(preBody, name, orgIds)
%ORGFOR Dedup organizations by name; return existing id (orgBody = []) or mint.
key = lower(strtrim(name));
if isKey(orgIds, key)
    orgId = orgIds(key); orgBody = [];
    return;
end
orgId = did.ido.unique_id();
orgIds(key) = orgId;   % containers.Map is a handle: the update persists to the caller
orgBody = entityDoc(preBody, 'organization', orgId, ...
    struct('name', name), emptyGids(), true);
end

% ===================== global_identifier ================================

function g = buildGids(varargin)
%BUILDGIDS Assemble a global_identifier struct array from {scheme,value} pairs,
%   skipping any pair whose value is empty. Returns a 0x0 struct if none.
g = emptyGids();
for k = 1:numel(varargin)
    pair = varargin{k};
    val = char(pair{2});
    if isempty(val); continue; end
    g(end+1) = struct('scheme', char(pair{1}), 'value', val); %#ok<AGROW>
end
end

function g = emptyGids()
g = struct('scheme', {}, 'value', {});
end

% ===================== small helpers ===================================

function id = baseId(preBody)
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = preBody.base.id;
end
if isempty(id); id = did.ido.unique_id(); end
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

function arr = getStructArray(block, name)
%GETSTRUCTARRAY Read a field as a struct array ('empty' if absent / not a struct).
arr = struct([]);
if isstruct(block) && isfield(block, name) && isstruct(block.(name))
    arr = block.(name);
end
end
