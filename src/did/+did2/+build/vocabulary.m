function [node, handles] = vocabulary(kind, handle)
%VOCABULARY The node of a relation or entity-type handle, and matching by node.
%
%   NODE = did2.build.vocabulary(KIND, HANDLE) returns the ontology node the
%   handle HANDLE names in vocabulary KIND, read FIRST from the loaded
%   schema's bound row whose name is the handle, then from the table below -- 'relation' (directed and
%   undirected relation names), 'entity_type' (entity.type), 'clock'
%   (relative_time_reference value.clock and clock_alignment_configuration
%   clock, the did_clocktype value set) -- or '' when
%   the handle names no node (a relation with no published term; a row the
%   loaded schema binds with an empty node) or is not a handle of KIND. HANDLE is the snake_case handle code has always
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
%   CLOCKS. Decided by Jess Haley, 2026-10-26 [clock terms get nodes]
%   (did-schema V_eta_go_forward_class_audit.md): the four clock values get
%   nodes -- utc wikidata:Q1536 "UTC", dev_local_time EMPTY:0000403 "device
%   local time", dev_global_time EMPTY:0000404 "device global time",
%   exp_global_time EMPTY:0000405 "experiment global time" (did-schema
%   V_eta_term_registry.json) -- and the stored name becomes the label, after
%   DID-matlab and NDI-matlab compare clock nodes first. The handles are the
%   did_v1 clocktype strings (NDI ndi.time.clocktype); the label spellings
%   are listed too, so a name-only document written after the label flip
%   still finds its node.
%
%   CULTURE. Decided by Jess Haley [culture and alignment nodes] (did-schema
%   did_v2_go_forward_class_audit.md): the entity type `culture` gets the node
%   OBI:0001876, so code compares it by node like every other type. The table
%   row is added here first; the loaded schema's own row still decides (step
%   1 below), so while it binds culture with an EMPTY node (did-schema main
%   before that registration lands) the handle answers '' and a culture is
%   written and compared by name exactly as before. A node-less culture
%   document still matches either way (did2.build.isVocabulary compares a
%   term with no node by its name). [culture renamed cell culture] (Jess
%   Haley, 2026-11-10): the type will be renamed "cell culture"; until the
%   schema's row spells it, 'cell culture' is an alias of the handle
%   (private/vocabularyAlias), so a node-less document named either matches.
%
%   See also did2.build.isVocabulary, did2.build.vocabularyHandle,
%   did2.convert.channelType.

arguments
    kind (1,:) char {mustBeMember(kind, {'relation', 'entity_type', 'clock'})}
    handle = ''
end

switch kind
    case 'relation'
        handles = {
            'part_of',                  'BFO:0000050'
            'included_in',              'schema:isPartOf'
            'contained_in',             'RO:0001025'
            'member_of',                'RO:0002350'
            'derived_from',             'prov:wasDerivedFrom'
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
            'culture',      'OBI:0001876'
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
    case 'clock'
        % [clock terms get nodes] (Jess Haley, 2026-10-26). The v1 handle of
        % each node comes FIRST (did2.build.vocabularyHandle answers the first
        % row with a node); the label spellings after it are read-only aliases.
        handles = {
            'utc',                    'wikidata:Q1536'
            'dev_local_time',         'EMPTY:0000403'
            'dev_global_time',        'EMPTY:0000404'
            'exp_global_time',        'EMPTY:0000405'
            'device_local_time',      'EMPTY:0000403'
            'device_global_time',     'EMPTY:0000404'
            'experiment_global_time', 'EMPTY:0000405'};
end
node = '';
key = normalize(handle);
if isempty(key)
    return;
end
% 1. the LOADED schema's own row whose name is the handle (snake_case or
%    label): its node. The schema is the truth for a node, so while its row
%    is still {RO:0001000, "derived_from"} that row wins over the table's
%    prov:wasDerivedFrom below (Jess Haley 2026-10-22 [derived from general]).
%    A row the schema binds with an EMPTY node says the handle has no node
%    yet, and that wins over the table too (culture, before did-schema
%    registers OBI:0001876: a writer must not write a node the schema does
%    not bind).
rows = schemaRows(kind);
for k = 1:size(rows, 1)
    if strcmp(normalize(rows{k, 1}), key)
        node = rows{k, 2};
        return;
    end
end
% an ALIAS (private/vocabularyAlias: 'cell culture' for culture, [culture
% renamed cell culture]) the schema has no row for answers as its handle does
alias = vocabularyAlias(kind, handle);
if ~isempty(alias)
    node = did2.build.vocabulary(kind, alias);
    return;
end
% 2. the handle table, for a handle the schema's label no longer spells
%    ('sample_of' once the row is "derives from part of", 'funding' once it
%    is "Grant", 'derived_from' once the row is {prov:wasDerivedFrom,
%    "wasDerivedFrom"}, PROV-O's label: did-schema
%    V_eta_relation_inheritance_plan.md [derived from label], Jess Haley
%    2026-10-22)
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
        case 'clock'
            % a dotted path walks sub-`fields` (value.clock)
            spec = {'relative_time_reference', 'value.clock'; ...
                'clock_alignment_configuration', 'clock'};
        otherwise
            spec = {'entity', 'type'};
    end
    for s = 1:size(spec, 1)
        if ~c.hasClass(spec{s, 1}); continue; end
        cls = c.getClass(spec{s, 1});
        f = cls.fields;
        hit = {};
        segs = strsplit(spec{s, 2}, '.');
        for g = 1:numel(segs)
            if isstruct(f); f = num2cell(f); end
            if ~iscell(f); hit = {}; break; end
            hit = f(cellfun(@(d) isstruct(d) && isfield(d, 'name') ...
                && strcmp(char(d.name), segs{g}), f));
            if isempty(hit); break; end
            if g < numel(segs)
                if ~isfield(hit{1}, 'fields'); hit = {}; break; end
                f = hit{1}.fields;
            end
        end
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
