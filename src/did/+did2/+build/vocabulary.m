function [node, handles] = vocabulary(kind, handle)
%VOCABULARY The node of a relation or entity-type handle, and matching by node.
%
%   NODE = did2.build.vocabulary(KIND, HANDLE) returns the ontology node the
%   handle HANDLE names in vocabulary KIND, read FIRST from the loaded
%   schema's bound row whose name is the handle, then from the table below -- 'relation' (directed and
%   undirected relation names), 'entity_type' (entity.type) -- or '' when
%   the handle names no node (culture; a relation with no published term) or
%   is not a handle of KIND. HANDLE is the snake_case handle code has always
%   written ('member_of', 'dataset') or the label ('member of'); case,
%   spaces, underscores and hyphens are ignored.
%
%   [~, HANDLES] = did2.build.vocabulary(KIND) returns the handle table, a
%   cellstr N x 2 {handle, node}.
%
%   WHY IN CODE. did-schema #88 gives every relation name and entity type a
%   node (Jess Haley 2026-10-22 [vocabulary nodes] G6, K0-K5, L3) and stores
%   the ontology LABEL as the name ([vocabulary nodes] L1, L2: "part of",
%   "Data Set"); code matches BY NODE. The term registry holds nodes only, no
%   synonyms (Jess Haley 2026-10-22 [registry holds nodes], S1), so the map
%   from the handles writers use to the nodes lives here, as the channel
%   prefix map lives in did2.convert.channelType. The NAME a document carries
%   is the schema's: did2.build fills it from the field's bound value list by
%   node (fillField>completeFromValueSet), so the label can change in the
%   schema without a change here.
%
%   See also did2.build.isVocabulary, did2.convert.channelType.

arguments
    kind (1,:) char {mustBeMember(kind, {'relation', 'entity_type'})}
    handle = ''
end

switch kind
    case 'relation'
        handles = {
            'part_of',                  'BFO:0000050'
            'included_in',              'schema:isPartOf'
            'contained_in',             'RO:0001025'
            'member_of',                'RO:0002350'
            'derives_from_part_of',     'ENVO:01003004'
            'sample_of',                'ENVO:01003004'
            'encountered',              'RO:0002437'
            'has_author',               'schema:author'
            'cites',                    'schema:citation'
            'funded_by',                'schema:funding'
            'issued_by',                'schema:funder'
            'affiliated_with',          'schema:affiliation'
            'documented_by',            'schema:subjectOf'
            'has_custodian',            'schema:maintainer'
            'contributed_by',           'schema:contributor'
            'copyright_holder',         'schema:copyrightHolder'
            'alternative_of',           'SIO:000497'
            'input_data',               'schema:isBasedOn'
            'follows_protocol',         'EMPTY:0000378'
            'suborganization_of',       'schema:parentOrganization'
            'instance_of',              'EMPTY:0000382'
            'awarded_to',               'schema:fundedItem'
            'orthologous_gene_mapping', 'EMPTY:0000386'
            'gene_alias_mapping',       'EMPTY:0000381'
            'paired_with',              'EMPTY:0000380'
            'same_as',                  'owl:sameAs'
            'sold_by',                  'OBI:0000647'
            'developed_by',             'schema:producer'
            'hosted_by',                'schema:provider'
            'distributed_as',           'EMPTY:0000379'};
    case 'entity_type'
        handles = {
            'organism',     'COB:0000022'
            'tissue',       'UBERON:0000479'
            'cell',         'CL:0000000'
            'group',        'NCIT:C43359'
            'device',       'COB:0001300'
            'material',     'BFO:0000040'
            'strain',       'NCIT:C14419'
            'product',      'schema:Product'
            'software',     'IAO:0000010'
            'person',       'NCIT:C25190'
            'organization', 'OBI:0000245'
            'funding',      'NCIT:C16644'
            'grant',        'NCIT:C16644'
            'dataset',      'NCIT:C47824'
            'study',        'NCIT:C63536'
            'publication',  'IAO:0000311'
            'protocol',     'OBI:0000272'
            'session',      'NCIT:C67447'
            'epoch',        'EMPTY:0000383'
            'recording_epoch', 'EMPTY:0000383'};
end
node = '';
key = normalize(handle);
if isempty(key)
    return;
end
% 1. the LOADED schema's own row whose name is the handle (snake_case or
%    label): its node. The schema is the truth for a node, so a node it
%    changes (derived_from RO:0001000 -> prov:wasDerivedFrom, Jess Haley
%    2026-10-22 [derived from general]) needs no change here.
rows = schemaRows(kind);
for k = 1:size(rows, 1)
    if strcmp(normalize(rows{k, 1}), key) && ~isempty(rows{k, 2})
        node = rows{k, 2};
        return;
    end
end
% 2. the handle table, for a handle the schema's label no longer spells
%    ('sample_of' once the row is "derives from part of", 'funding' once it
%    is "Grant")
hit = find(strcmp(cellfun(@normalize, handles(:, 1), 'UniformOutput', false), key), 1);
if ~isempty(hit)
    node = handles{hit, 2};
end
end

function rows = schemaRows(kind)
% {name, node} of every member of the loaded schema's bound value list(s) for
% KIND, memoised per schema path
persistent memo
if isempty(memo); memo = containers.Map('KeyType', 'char', 'ValueType', 'any'); end
rows = cell(0, 2);
try
    c = did2.schema.cache.shared();
    mk = [char(c.schemaPath) '|' kind];
    if isKey(memo, mk); rows = memo(mk); return; end
    switch kind
        case 'relation'
            spec = {'directed_relation', 'relation'; 'undirected_relation', 'relation'; ...
                'clock_alignment', 'relation'};
        otherwise
            spec = {'entity', 'type'};
    end
    for s = 1:size(spec, 1)
        if ~c.hasClass(spec{s, 1}); continue; end
        cls = c.getClass(spec{s, 1});
        f = cls.fields;
        if isstruct(f); f = num2cell(f); end
        hit = f(cellfun(@(d) strcmp(char(d.name), spec{s, 2}), f));
        if isempty(hit) || ~isfield(hit{1}, 'constraints') || ~isstruct(hit{1}.constraints) ...
                || ~isfield(hit{1}.constraints, 'binding') ...
                || ~isfield(hit{1}.constraints.binding, 'values')
            continue;
        end
        vals = hit{1}.constraints.binding.values;
        if isstruct(vals); vals = num2cell(vals); end
        for v = 1:numel(vals)
            nd = '';
            if isfield(vals{v}, 'node'); nd = char(vals{v}.node); end
            rows(end+1, :) = {char(vals{v}.name), nd}; %#ok<AGROW>
        end
    end
    memo(mk) = rows;
catch
end
end

function s = normalize(h)
s = lower(regexprep(char(h), '[\s_\-]', ''));
end
