function docs = entityDoc(preBody, className, docId, blockStruct, gids, fresh)
%ENTITYDOC The documents one entity of the pre-#73 class CLASSNAME becomes on
%   did-schema #88: an `entity` with a bound `type`, plus one assertion per
%   other field, plus a relation per entity edge.
%
%   DOCS = entityDoc(PREBODY, CLASSNAME, DOCID, BLOCKSTRUCT, GIDS, FRESH) is a
%   CELL -- callers concatenate it (`bodies = [bodies, entityDoc(...)]`). The
%   mapping is V_eta_entity_composition_plan.md sec. 4 (signed 2026-10-08),
%   and it is the same table NDI's import applies (ndi.setup.V2.entityDocuments):
%
%     identity      name (`full_name` / `title` / given+family for a person),
%                   local_identifier, description, global_identifier (GIDS:
%                   CURIEs or IRIs, did2.convert.entities.buildGids)
%     term          license (spdx:<id>), accessibility, ethics_assessment,
%                   experimental_approach -> term_assertion
%     date          release_date -> date_assertion
%     text          short_name, version, version_innovation, how_to_cite,
%                   support_channel, keyword, given_name, family_name, email
%                   -> text_assertion
%
%   CLASSNAME is the type, except `web_resource`, which #88 retired (sec. 7: a
%   URL is an address for the thing it names): a dataset's FULL DOCUMENTATION
%   is a written document about it, so it becomes an `entity {type: protocol}`
%   named by its label with the URL/DOI as its identifier -- a CONSERVATIVE
%   CHOICE recorded with the port, not a signed one.
%
%   DOCID is the entity's id (preserved or minted by the caller). FRESH is
%   ignored on #88 (the base block is the builder's): kept for callers.
%   An award number given as {'AwardNumber', n} is the funding entity's
%   `local_identifier` (sec. 6: "AwardNumber is not a prefix").

arguments
    preBody (1,1) struct
    className char
    docId char
    blockStruct (1,1) struct
    gids
    fresh (1,1) logical %#ok<INUSA>
end

type = className;
if strcmp(className, 'web_resource')
    type = 'protocol';
end
[curies, award] = splitGids(gids);
ent = struct();
nm = '';
for f = {'full_name', 'name', 'title', 'label'}
    if isfield(blockStruct, f{1}) && ~isempty(blockStruct.(f{1}))
        nm = char(blockStruct.(f{1}));
        break;
    end
end
if isempty(nm) && strcmp(className, 'person')
    parts = {};
    for f = {'given_name', 'family_name'}
        if isfield(blockStruct, f{1}) && ~isempty(blockStruct.(f{1}))
            parts{end+1} = char(blockStruct.(f{1})); %#ok<AGROW>
        end
    end
    nm = strjoin(parts, ' ');
end
if ~isempty(nm); ent.name = nm; end
if isfield(blockStruct, 'local_identifier') && ~isempty(blockStruct.local_identifier)
    ent.local_identifier = char(blockStruct.local_identifier);
elseif ~isempty(award)
    ent.local_identifier = award;
end
if isfield(blockStruct, 'description') && ~isempty(blockStruct.description)
    ent.description = char(blockStruct.description);
end
if ~isempty(curies)
    ent.global_identifier = curies;
end
docs = {jEntityDoc(preBody, type, ent, docId)};

terms = {'license', 'accessibility', 'ethics_assessment', 'experimental_approach'};
dates = {'release_date'};
texts = {'short_name', 'version', 'version_innovation', 'how_to_cite', ...
    'support_channel', 'keyword', 'given_name', 'family_name', 'email'};
identity = {'full_name', 'name', 'title', 'label', 'local_identifier', 'description'};
variableNodes = struct('accessibility', 'NCIT:C175887', 'given_name', 'IAO:0020016', ...
    'family_name', 'IAO:0020017', 'email', 'NCIT:C42775', 'keyword', 'EDAM:data_0968', ...
    'license', 'NCIT:C43611', 'short_name', 'NCIT:C42610', 'version', 'IAO:0000129', ...
    'release_date', 'EMPTY:0000346', 'ethics_assessment', 'EMPTY:0000355', ...
    'experimental_approach', 'EMPTY:0000356');
names = setdiff(fieldnames(blockStruct), identity, 'stable');
for k = 1:numel(names)
    f = names{k};
    v = blockStruct.(f);
    if isEmptyValue(v)
        continue;
    end
    node = '';
    if isfield(variableNodes, f); node = variableNodes.(f); end
    variable = did2.convert.registeredTerm(node, strrep(f, '_', ' '));
    o = opts(preBody);
    if any(strcmp(f, terms))
        if strcmp(f, 'license') && (ischar(v) || (isstring(v) && isscalar(v)))
            v = did2.build.term(['spdx:' strtrim(char(v))], strtrim(char(v)));
        end
        tv = asTerms(v);
        for j = 1:numel(tv)   % one assertion per term: `term.value` is one term
            docs{end+1} = did2.build.statement('term_assertion', docId, variable, ...
                tv(j), o{:}); %#ok<AGROW>
        end
    elseif any(strcmp(f, dates))
        d = cellstr(string(v));
        docs{end+1} = did2.build.statement('date_assertion', docId, variable, ...
            did2.build.valueCell('date', d, 'Fields', struct('precision', precisionOf(d{1}))), ...
            o{:}); %#ok<AGROW>
    elseif any(strcmp(f, texts))
        docs{end+1} = did2.build.statement('text_assertion', docId, variable, ...
            did2.build.valueCell('text', cellstr(string(v))), o{:}); %#ok<AGROW>
    else
        error('did2:convert:entities:noHome', ...
            '`%s.%s` has no home on the #88 entity: name it in entityDoc.', className, f);
    end
end
end

% -----------------------------------------------------------------------------

function d = jEntityDoc(preBody, type, ent, docId)
ent.type = did2.build.term('', type);
o = opts(preBody, 'Id', docId);
d = did2.build.document('entity', ent, o{:});
end

function c = opts(preBody, varargin)
base = did2.convert.entities.freshBase(preBody, '');
c = [{'SessionId', base.session_id, 'CreationTimestamp', base.datestamp, ...
    'Validate', false}, varargin];
end

function [curies, award] = splitGids(gids)
curies = {};
award = '';
if iscell(gids)
    curies = gids;
    return;
end
if ~isstruct(gids)
    return;
end
for k = 1:numel(gids)
    s = char(gids(k).scheme);
    v = strtrim(char(gids(k).value));
    if isempty(v); continue; end
    switch lower(s)
        case 'awardnumber'
            award = v;
        case 'url'
            curies{end+1} = v; %#ok<AGROW>
        case 'orcid'
            curies{end+1} = ['ORCID:' strip(v, 'https://orcid.org/')]; %#ok<AGROW>
        case 'doi'
            curies{end+1} = ['doi:' strip(v, 'https://doi.org/')]; %#ok<AGROW>
        case 'pmid'
            curies{end+1} = ['PMID:' v]; %#ok<AGROW>
        case 'pmcid'
            curies{end+1} = ['PMCID:' v]; %#ok<AGROW>
        case 'ndicloud'
            curies{end+1} = ['ndicloud:' v]; %#ok<AGROW>
        otherwise
            curies{end+1} = [s ':' v]; %#ok<AGROW>
    end
end
end

function v = strip(v, prefix)
if startsWith(lower(v), lower(prefix))
    v = v(numel(prefix) + 1:end);
end
end

function tf = isEmptyValue(v)
if isstruct(v)
    tf = isempty(v) || all(arrayfun(@(t) isfield(t, 'name') && isempty(t.name) ...
        && (~isfield(t, 'node') || isempty(t.node)), v));
elseif iscell(v)
    tf = isempty(v) || all(cellfun(@isempty, v));
else
    tf = isempty(v);
end
end

function t = asTerms(v)
if isstruct(v)
    t = v;
    return;
end
c = cellstr(string(v));
t = did2.convert.registeredTerm('', c{1});
for k = 2:numel(c)
    t(k) = did2.convert.registeredTerm('', c{k});
end
end

function p = precisionOf(s)
switch numel(regexp(s, '\d+', 'match'))
    case 1, p = 'year';
    case 2, p = 'month';
    otherwise, p = 'day';
end
end
