function [v1, spec] = metadata_editor(bodies)
%METADATA_EDITOR Rebuild a v1 `metadata_editor` from what the migration made
%   of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.metadata_editor(BODIES). V1 is the form
%   in NDI's v1 shape (metadata_editor.json + base.json at the locked
%   NDI-matlab `main`, 3cb19a8, as +ndi/+database/+metadata_ds_core/
%   saveEditor2Doc.m writes it, the form in metadata_structure). BODIES holds
%   what did2.convert.migrators_j.metadata_editor emits:
%
%     base.id                       not kept (absent: the round trip reports
%                                   it lost)
%     base.session_id               the dataset entity's id
%     base.datestamp                the dataset entity's creation_timestamp
%     base.name                     '' (the writer sets none)
%     DatasetFullName               the dataset entity's name
%     Description                   the dataset entity's description
%     DatasetShortName, VersionIdentifier, VersionInnovation, HowToCite,
%     Keyword, SupportChannel       text assertions about the dataset
%     License                       the licence term's SPDX id
%     Accessibility                 the accessibility term's name
%     EthicsAssessment              "EU compliant" / "US compliant", from the
%                                   ethics jurisdiction term
%     ReleaseDate                   the release-date assertion's instant
%     ExperimentalApproach, TechniquesEmployed, DataType
%                                   the form-term assertions (a v1 value names
%                                   its term by label, node or the node's last
%                                   segment: spec.same)
%     Author(i)                     the dataset -has_author-> person relations,
%                                   by order: givenName / familyName /
%                                   contactInformation.email (text assertions
%                                   on the person), digitalIdentifier.identifier
%                                   (its ORCID: identifier), affiliation.
%                                   memberOf.fullName (its affiliated_with
%                                   organization's name)
%     Funding(i)                    the funded_by funding entities: awardTitle
%                                   (name), awardNumber (local_identifier),
%                                   funder (its issued_by organization's name)
%     RelatedPublication(i)         the cited publications: Publication (name),
%                                   DOI / PMID / PMCID (global identifiers)
%     FullDocumentation             the documented_by protocol's identifier
%
%   Any other emitted document, assertion or field is unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.metadata_editor.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
n = numel(bodies);
used = false(1, n);
ids = cell(1, n);
for k = 1:n
    ids{k} = char(getIn(bodies{k}, 'base', 'id'));
end
ds = 0;
for k = 1:n
    if isEntityOfType(bodies{k}, 'dataset')
        ds = k;
        break;
    end
end
if ds == 0
    spec.unplaced{end+1} = 'no dataset entity was emitted';
    return;
end
used(ds) = true;
[base, dsEntity] = rebuildBase(bodies{ds});
dsId = base.id;
ms = struct();
spec.unplaced = [spec.unplaced, others(dsEntity, {'type', 'name', 'description'}, ...
    'dataset entity')];
if ~isempty(fieldText(dsEntity, 'name'))
    ms.DatasetFullName = fieldText(dsEntity, 'name');
end
if ~isempty(fieldText(dsEntity, 'description'))
    ms.Description = fieldText(dsEntity, 'description');
end

% --- assertions about the dataset ------------------------------------------
textFields = {'NCIT:C42610', 'short name', 'DatasetShortName'; ...
    'IAO:0000129', 'version', 'VersionIdentifier'; ...
    '', 'version innovation', 'VersionInnovation'; ...
    '', 'how to cite', 'HowToCite'; ...
    'EDAM:data_0968', 'keyword', 'Keyword'; ...
    '', 'support channel', 'SupportChannel'};
formFields = {'EMPTY:0000356', 'ExperimentalApproach'; ...
    'NCIT:C16847', 'TechniquesEmployed'; ...
    'NCIT:C175886', 'DataType'};
formTerms = struct();
for k = 1:n
    if used(k) || ~isStatementAbout(bodies{k}, dsId)
        continue;
    end
    used(k) = true;
    b = bodies{k};
    [vnode, vname] = termParts(getIn(b, 'statement', 'variable'));
    hit = [];
    for r = 1:size(textFields, 1)
        if (~isempty(textFields{r, 1}) && sameCurie(vnode, textFields{r, 1})) ...
                || (isempty(textFields{r, 1}) && strcmpi(strrep(vname, '_', ' '), textFields{r, 2}))
            hit = r;
            break;
        end
    end
    if ~isempty(hit)
        ms = appendText(ms, textFields{hit, 3}, textsOf(b));
        continue;
    end
    form = find(cellfun(@(c) sameCurie(vnode, c), formFields(:, 1)), 1);
    if ~isempty(form)
        f = formFields{form, 2};
        [tnode, tname] = termParts(getIn(b, 'term', 'value'));
        if ~isfield(formTerms, f); formTerms.(f) = struct('node', {}, 'name', {}); end
        formTerms.(f)(end+1) = struct('node', tnode, 'name', tname);
        continue;
    end
    if sameCurie(vnode, 'NCIT:C43611')
        [tnode, tname] = termParts(getIn(b, 'term', 'value'));
        if startsWith(lower(tnode), 'spdx:')
            ms.License = tnode(6:end);
        else
            ms.License = tname;
        end
    elseif sameCurie(vnode, 'NCIT:C175887')
        [~, tname] = termParts(getIn(b, 'term', 'value'));
        ms.Accessibility = tname;
    elseif sameCurie(vnode, 'EMPTY:0000359')
        [tnode, ~] = termParts(getIn(b, 'term', 'value'));
        ms.EthicsAssessment = ethicsText(tnode);
        if isempty(ms.EthicsAssessment)
            spec.unplaced{end+1} = sprintf('ethics jurisdiction "%s" has no v1 text', tnode);
        end
    elseif sameCurie(vnode, 'EMPTY:0000346')
        ms.ReleaseDate = char(getIn(b, 'date', 'value', 'instant'));
    else
        spec.unplaced{end+1} = sprintf('an assertion about the dataset with variable "%s %s"', ...
            vnode, vname);
    end
end
fns = fieldnames(formTerms);
for k = 1:numel(fns)
    t = formTerms.(fns{k});
    names = {t.name};
    if isscalar(names); ms.(fns{k}) = names{1}; else; ms.(fns{k}) = names; end
    spec.same(end+1) = struct('path', ['metadata_editor.metadata_structure.' fns{k}], ...
        'fn', @(a, ~) formMatches(a, t), 'why', ['a form value names its term by ' ...
        'label, node or the node''s last segment ([dataset form terms], Jess Haley, ' ...
        '2026-10-25; did2.convert.migrators_j.metadata_editor matchValue)']);
end
for f = {'Keyword', 'SupportChannel'}
    if isfield(ms, f{1}) && isscalar(ms.(f{1}))
        ms.(f{1}) = ms.(f{1}){1};
    end
end

% --- relations from the dataset ---------------------------------------------
authors = struct('order', {}, 'person', {});
funding = {};
pubs = {};
for k = 1:n
    if used(k) || ~strcmp(classNameOf(bodies{k}), 'directed_relation')
        continue;
    end
    child = firstId(bodies{k}, 'child_id');
    if ~strcmp(child, dsId)
        continue;
    end
    parent = firstId(bodies{k}, 'parent_id');
    p = find(strcmp(ids, parent) & ~used, 1);
    rname = did2.build.vocabularyHandle('relation', getIn(bodies{k}, 'directed_relation', 'relation'));
    if isempty(p)
        spec.unplaced{end+1} = sprintf('the %s relation''s target was not emitted', rname);
        used(k) = true;
        continue;
    end
    used([k p]) = true;
    switch rname
        case 'has_author'
            authors(end+1) = struct('order', getIn(bodies{k}, 'directed_relation', 'order'), ...
                'person', p); %#ok<AGROW>
        case 'funded_by'
            funding{end+1} = p; %#ok<AGROW>
        case 'cites'
            pubs{end+1} = p; %#ok<AGROW>
        case 'documented_by'
            [~, e] = rebuildBase(bodies{p});
            g = asCell(getIn(bodies{p}, 'entity', 'global_identifier'));
            if ~isempty(g); ms.FullDocumentation = char(g{1}); end
            spec.unplaced = [spec.unplaced, others(e, {'type', 'name', 'global_identifier'}, ...
                'documentation entity')];
        otherwise
            spec.unplaced{end+1} = sprintf('a %s relation from the dataset', rname);
    end
end
if ~isempty(authors)
    [~, o] = sort(cellfun(@double, {authors.order}));
    authors = authors(o);
    list = cell(1, numel(authors));
    for i = 1:numel(authors)
        [list{i}, used] = authorOf(bodies, ids, used, authors(i).person);
    end
    ms.Author = [list{:}];
end
if ~isempty(funding)
    list = cell(1, numel(funding));
    for i = 1:numel(funding)
        [list{i}, used] = fundingOf(bodies, ids, used, funding{i});
    end
    ms.Funding = [list{:}];
end
if ~isempty(pubs)
    list = cell(1, numel(pubs));
    for i = 1:numel(pubs)
        list{i} = publicationOf(bodies{pubs{i}});
    end
    ms.RelatedPublication = [list{:}];
end
for k = find(~used)
    spec.unplaced{end+1} = sprintf('emitted document %d (%s) has no role in the form', ...
        k, classNameOf(bodies{k}));
end
v1.document_class = struct('class_name', 'metadata_editor');
v1.base = struct('session_id', dsId, 'name', '', 'datestamp', base.datestamp);
v1.metadata_editor = struct('metadata_structure', ms);
if isfield(ms, 'Author')
    spec.same(end+1) = struct('path', 'metadata_editor.metadata_structure.Author.digitalIdentifier.identifier', ...
        'fn', @sameOrcid, 'why', 'an ORCID iD with or without its https://orcid.org/ prefix');
end
end

% ===================== the parts ==========================================

function [a, used] = authorOf(bodies, ids, used, p)
person = bodies{p};
pid = ids{p};
a = struct('givenName', '', 'familyName', '', ...
    'contactInformation', struct('email', ''), ...
    'digitalIdentifier', struct('identifier', ''));
g = asCell(getIn(person, 'entity', 'global_identifier'));
for j = 1:numel(g)
    s = char(g{j});
    if startsWith(lower(s), 'orcid:')
        a.digitalIdentifier.identifier = s(7:end);
    end
end
affs = {};   % one affiliated_with relation per affiliation, in v1's order
for k = 1:numel(bodies)
    if used(k); continue; end
    b = bodies{k};
    if isStatementAbout(b, pid)
        [vnode, ~] = termParts(getIn(b, 'statement', 'variable'));
        t = textsOf(b);
        if isempty(t); t = {''}; end
        if sameCurie(vnode, 'IAO:0020016')
            a.givenName = t{1}; used(k) = true;
        elseif sameCurie(vnode, 'IAO:0020017')
            a.familyName = t{1}; used(k) = true;
        elseif sameCurie(vnode, 'NCIT:C42775')
            a.contactInformation.email = t{1}; used(k) = true;
        end
    elseif strcmp(classNameOf(b), 'directed_relation') ...
            && strcmp(firstId(b, 'child_id'), pid)
        rname = did2.build.vocabularyHandle('relation', getIn(b, 'directed_relation', 'relation'));
        o = find(strcmp(ids, firstId(b, 'parent_id')), 1);
        if strcmp(rname, 'affiliated_with') && ~isempty(o)
            used(k) = true;
            used(o) = true;
            [~, oe] = rebuildBase(bodies{o});
            affs{end+1} = fieldText(oe, 'name'); %#ok<AGROW>
        end
    end
end
% [one affiliation relation each] (Jess Haley, 2026-10-27): several relations
% rebuild v1's struct array (AuthorData.addAffiliation), one a scalar struct.
if ~isempty(affs)
    a.affiliation = struct('memberOf', cellfun(@(n) struct('fullName', n), ...
        affs, 'UniformOutput', false));
end
end

function [f, used] = fundingOf(bodies, ids, used, p)
fid = ids{p};
[~, e] = rebuildBase(bodies{p});
f = struct('funder', '', 'awardTitle', fieldText(e, 'name'), ...
    'awardNumber', fieldText(e, 'local_identifier'));
for k = 1:numel(bodies)
    b = bodies{k};
    if used(k) || ~strcmp(classNameOf(b), 'directed_relation') ...
            || ~strcmp(firstId(b, 'child_id'), fid)
        continue;
    end
    o = find(strcmp(ids, firstId(b, 'parent_id')), 1);
    rname = did2.build.vocabularyHandle('relation', getIn(b, 'directed_relation', 'relation'));
    if strcmp(rname, 'issued_by') && ~isempty(o)
        used(k) = true;
        used(o) = true;
        [~, oe] = rebuildBase(bodies{o});
        f.funder = fieldText(oe, 'name');
    end
end
end

function p = publicationOf(body)
[~, e] = rebuildBase(body);
p = struct('Publication', fieldText(e, 'name'), 'DOI', '', 'PMID', '', 'PMCID', '');
g = asCell(getIn(body, 'entity', 'global_identifier'));
for j = 1:numel(g)
    s = char(g{j});
    if startsWith(lower(s), 'doi:')
        p.DOI = s(5:end);
    elseif startsWith(s, 'PMID:')
        p.PMID = s(6:end);
    elseif startsWith(s, 'PMCID:')
        p.PMCID = s(7:end);
    end
end
end

% ===================== helpers ==============================================

function tf = isStatementAbout(b, id)
tf = isstruct(b) && isfield(b, 'statement') ...
    && isequal(edgeIds(b, 'entity_id'), {id});
end

function t = textsOf(b)
t = {};
vals = asCell(getIn(b, 'text', 'value'));
for k = 1:numel(vals)
    if isstruct(vals{k}) && isfield(vals{k}, 'text')
        t{end+1} = char(vals{k}.text); %#ok<AGROW>
    elseif ischar(vals{k})
        t{end+1} = vals{k}; %#ok<AGROW>
    end
end
end

function ms = appendText(ms, field, t)
if isfield(ms, field)
    ms.(field) = [ms.(field), t];
else
    ms.(field) = t;
end
if isscalar(ms.(field)) && ~any(strcmp(field, {'Keyword', 'SupportChannel'}))
    ms.(field) = ms.(field){1};
end
end

function s = ethicsText(node)
s = '';
for c = {'EU compliant', 'US compliant'}
    t = did2.convert.ethicsJurisdiction(c{1});
    if ~isempty(t) && sameCurie(char(t.node), node)
        s = c{1};
        return;
    end
end
end

function tf = formMatches(v1Value, terms)
vals = v1Value;
if ischar(vals) || isstring(vals); vals = cellstr(vals); end
tf = iscell(vals) && numel(vals) == numel(terms);
for k = 1:numel(vals)
    if ~tf; return; end
    v = strtrim(char(vals{k}));
    node = terms(k).node;
    tail = node;
    cut = find(node == '/' | node == ':', 1, 'last');
    if ~isempty(cut); tail = node(cut+1:end); end
    tf = strcmpi(v, terms(k).name) || strcmpi(v, node) || strcmpi(v, tail);
end
end

function tf = sameOrcid(a, b)
strip = @(s) regexprep(strtrim(char(s)), '^https?://orcid\.org/', '', 'ignorecase');
tf = (ischar(a) || isstring(a)) && (ischar(b) || isstring(b)) ...
    && strcmpi(strip(a), strip(b));
end

function id = firstId(body, name)
ids = edgeIds(body, name);
id = '';
if ~isempty(ids); id = ids{1}; end
end
