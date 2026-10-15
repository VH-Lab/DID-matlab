function doc = document(className, fields, options)
%DOCUMENT Build one V_eta document of CLASSNAME, checked against its schema.
%
%   DOC = did2.build.document(CLASSNAME, FIELDS, 'SessionId', SID, ...)
%   returns the document as a struct in the did2 wire shape:
%
%       document_class   {class_name, class_version, superclasses, schema_version 'V_eta'}
%       depends_on       struct array {name, document_id}
%       <block>          one property block per contributing class of the chain,
%                        in the chain's root-first order (base first)
%       files            {file_list} -- only when 'Files' is given
%
%   Everything is read from the schema that did2.schema.cache has loaded
%   (DID_SCHEMA_PATH): no field list, block layout, edge name or version is
%   written into this function.
%
%   FIELDS is a struct whose field names are the document's field names. Each
%   is routed to the block that declares it. When two blocks of the chain
%   declare the same name, pass that block as a struct instead:
%   FIELDS.(blockName) = struct(fieldName, value). Values are checked and
%   normalised field by field (see did2.build.composite for the rules on
%   nested structures), and optional fields that are not given are LEFT OUT
%   of the document rather than filled with blanks.
%
%   The base block is not set through FIELDS. `id`, `session_id` and
%   `creation_timestamp` come from the options below, and the did_v1-only
%   `base.name` is refused: V_eta documents never write it (#73 item 54).
%
%   Options:
%     'SessionId'          (required) base.session_id
%     'Edges'              the depends_on edges, as either
%                            - a struct: field name = edge name, value = the
%                              document id (char), or a cellstr of ids for an
%                              edge declared `multiple` (repeated, in order), or
%                            - an N x 2 cell {name, id; name, id; ...}.
%                          An edge name must be declared somewhere in the chain;
%                          an instance of a numbered family `foo_#` is written
%                          `foo_1`, `foo_2`, ....
%     'Files'              cellstr of attached file names; each must be
%                          declared by the chain (a `series` file `foo` takes
%                          members `foo_0`, `foo_1`, ...).
%     'Id'                 base.id to use (e.g. an id preserved from a source
%                          document). Default: a fresh did.ido.unique_id().
%     'CreationTimestamp'  ISO-8601 UTC. Default: now. There is no sentinel.
%     'Validate'           default true: run did2.schema.cache.validateDocument
%                          on the result as the last step.
%     'SchemaCache'        a did2.schema.cache; default the shared one.
%     'ValueKind'          the value kind of a statement direction that takes
%                          one ('temperature' for an `observation`); its chain
%                          is listed after the class's own and its blocks,
%                          fields and edges are the document's too.
%
%   VALUE KINDS. On a schema where a direction declares `value_kind`
%   (did-schema V_eta_entity_composition_plan.md sec. 1, 2026-10-08), the
%   join leaves are gone: a temperature observation is an `observation`
%   listing `temperature`. A CLASSNAME the schema lacks of the form
%   <kind>_<direction> ('temperature_observation') is read that way, so a
%   caller written for either schema builds the right document on both.
%
%   Errors, all raised BEFORE any document is returned:
%     did2:build:abstractClass    CLASSNAME is abstract
%     did2:build:missingValueKind a direction that takes a value kind, given none
%     did2:build:unknownField     a name no block declares (also nested)
%     did2:build:ambiguousField   a name two blocks declare, not qualified
%     did2:build:missingField     a required field (or nested field) not given
%     did2:build:unknownEdge      an edge name the chain does not declare
%     did2:build:missingEdge      a required edge not given, or fewer than a
%                                 `multiple` edge's min_count
%     did2:build:repeatedEdge     several ids for an edge not declared multiple
%     did2:build:unknownFile      a file name the chain does not declare
%     did2:build:ruleViolated     a schema rule or builder check (see
%                                 +build/private/checkRules.m for the list)
%     did2:build:unknownRule      the chain declares a rule the builder cannot check
%     did2:build:typeMismatch / notScalar / notInEnum / emptyTerm / ...
%   plus any did2:validation:* from the final validateDocument.
%
%   Example:
%     v = did2.build.valueCell('voltage', 0.012, 'SourceValue', 12, 'SourceUnit', 'mV');
%     doc = did2.build.document('voltage_observation', ...
%         struct('variable', did2.build.term('ncit:C25613', 'Voltage'), 'value', v), ...
%         'SessionId', sessionId, 'Edges', struct('entity_id', subjectId));
%
%   See also did2.build.statement, did2.build.composite, did2.schema.cache.

arguments
    className (1,:) char
    fields (1,1) struct = struct()
    options.SessionId (1,:) char = ''
    options.Edges = struct()
    options.Files = {}
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.ValueKind (1,:) char = ''
end

cache = schemaCache(options.SchemaCache);
[className, kind] = resolveLeaf(cache, className, options.ValueKind);
classSchema = cache.getClass(className);
dc = classSchema.document_class;
if isfield(dc, 'abstract') && isequal(dc.abstract, true)
    error('did2:build:abstractClass', ...
        'Class "%s" is abstract; build one of its concrete subclasses.', className);
end
if isempty(options.SessionId)
    error('did2:build:missingField', ...
        '''SessionId'' is required: every document belongs to a session (base.session_id).');
end

rule = cache.valueKindRule(className);
if isempty(kind) && ~isempty(rule) && ~any(strcmp(cache.superclasses(className), char(rule.root)))
    error('did2:build:missingValueKind', ...
        ['Class "%s" takes a value kind (a concrete descendant of "%s"); name it ' ...
         'with ''ValueKind'', or build "<kind>_%s".'], className, char(rule.root), className);
end
if ~isempty(kind) && isempty(rule)
    error('did2:build:missingValueKind', ...
        'Class "%s" takes no value kind, so ''ValueKind'' "%s" cannot be given.', className, kind);
end
chain = cache.documentChain(className, kind);

% ---- document_class --------------------------------------------------------
ancestors = cache.documentAncestors(className, kind);
sc = struct('class_name', {}, 'class_version', {});
for k = 1:numel(ancestors)
    ancDC = cache.getClass(ancestors{k}).document_class;
    sc(end+1) = struct('class_name', char(ancDC.class_name), ...
        'class_version', char(ancDC.class_version)); %#ok<AGROW>
end
doc = struct();
doc.document_class = struct( ...
    'class_name', char(dc.class_name), ...
    'class_version', char(dc.class_version), ...
    'superclasses', sc, ...
    'schema_version', 'V_eta');

% ---- depends_on --------------------------------------------------------------
doc.depends_on = buildEdges(cache, className, options.Edges, chain);

% ---- blocks ------------------------------------------------------------------
info = cache.resolvePlacementFor(className, kind);
givenByBlock = routeFields(info, fields, className);
for k = 1:numel(info.blocksContributed)
    blockName = info.blocksContributed{k};
    if strcmp(blockName, 'base')
        doc.base = baseBlock(info, options);
        continue;
    end
    doc.(blockName) = fillBlock(info, blockName, givenByBlock);
end

% ---- files -------------------------------------------------------------------
if ~isempty(options.Files)
    doc.files = struct('file_list', {checkFiles(cache, className, options.Files, chain)});
end

checkRules(cache, className, doc, chain);
if options.Validate
    cache.validateDocument(doc);
end
end

% =============================================================================

function givenByBlock = routeFields(info, fields, className)
% Map each given field onto the block that declares it.
blockNames = info.blocksContributed;
owner = containers.Map();          % field name -> cellstr of blocks
for b = 1:numel(blockNames)
    if strcmp(blockNames{b}, 'base') || ~isKey(info.fieldsByBlock, blockNames{b})
        continue;
    end
    entries = info.fieldsByBlock(blockNames{b});
    for f = 1:numel(entries)
        name = char(entries(f).fieldDef.name);
        if isKey(owner, name)
            owner(name) = [owner(name), blockNames(b)];
        else
            owner(name) = blockNames(b);
        end
    end
end

givenByBlock = containers.Map();
names = fieldnames(fields);
for k = 1:numel(names)
    name = names{k};
    value = fields.(name);
    if strcmp(name, 'base')
        error('did2:build:unknownField', ...
            ['The base block is set through the ''SessionId'', ''Id'' and ' ...
             '''CreationTimestamp'' options, not through FIELDS.']);
    elseif isKey(owner, name)
        blocks = owner(name);
        if numel(blocks) > 1
            error('did2:build:ambiguousField', ...
                ['Field "%s" is declared by blocks %s of "%s"; pass it as ' ...
                 'FIELDS.<block>.%s.'], name, strjoin(blocks, ' and '), className, name);
        end
        givenByBlock = put(givenByBlock, blocks{1}, name, value);
    elseif any(strcmp(name, blockNames)) && isstruct(value) && isscalar(value)
        inner = fieldnames(value);
        for j = 1:numel(inner)
            if ~isKey(owner, inner{j}) || ~any(strcmp(owner(inner{j}), name))
                error('did2:build:unknownField', ...
                    'Block "%s" of "%s" declares no field "%s".', name, className, inner{j});
            end
            givenByBlock = put(givenByBlock, name, inner{j}, value.(inner{j}));
        end
    else
        declared = sort(keys(owner));
        error('did2:build:unknownField', ...
            'Class "%s" declares no field "%s". Declared (outside base): %s.', ...
            className, name, strjoin(declared, ', '));
    end
end
end

function m = put(m, blockName, fieldName, value)
if isKey(m, blockName)
    s = m(blockName);
else
    s = struct();
end
if isfield(s, fieldName)
    error('did2:build:ambiguousField', ...
        'Field "%s.%s" was given twice.', blockName, fieldName);
end
s.(fieldName) = value;
m(blockName) = s;
end

function block = fillBlock(info, blockName, givenByBlock)
block = struct();
if isKey(givenByBlock, blockName)
    given = givenByBlock(blockName);
else
    given = struct();
end
if ~isKey(info.fieldsByBlock, blockName)
    return;
end
entries = info.fieldsByBlock(blockName);
for f = 1:numel(entries)
    def = entries(f).fieldDef;
    name = char(def.name);
    path = [blockName '.' name];
    if isfield(given, name) && ~isAbsent(given.(name))
        block.(name) = fillField(def, given.(name), path);
    elseif isfield(def, 'mustBeNonEmpty') && logical(def.mustBeNonEmpty)
        error('did2:build:missingField', 'Required field "%s" was not given.', path);
    end
end
end

function base = baseBlock(info, options)
id = options.Id;
if isempty(id)
    id = did.ido.unique_id();
end
ts = options.CreationTimestamp;
if isempty(ts)
    dt = datetime('now', 'TimeZone', 'UTC');
    dt.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
    ts = char(string(dt));
end
supplied = struct('id', id, 'session_id', options.SessionId, 'creation_timestamp', ts);
base = struct();
entries = info.fieldsByBlock('base');
for f = 1:numel(entries)
    name = char(entries(f).fieldDef.name);
    if isfield(supplied, name)
        base.(name) = supplied.(name);
    end
end
missing = reshape(setdiff(fieldnames(supplied), fieldnames(base)), 1, []);
if ~isempty(missing)
    error('did2:build:badSchema', ...
        ['The loaded base schema does not declare %s. did2.build targets ' ...
         'V_eta (base.creation_timestamp, renamed from datestamp 2026-08-13); ' ...
         'check DID_SCHEMA_PATH.'], strjoin(missing, ', '));
end
end

function edges = buildEdges(cache, className, given, chain)
% Check the given edges against every depends_on the chain declares.
declared = containers.Map();
order = {};
for c = 1:numel(chain)
    s = cache.getClass(chain{c});
    if ~isfield(s, 'depends_on')
        continue;
    end
    deps = asDefs(s.depends_on);
    for d = 1:numel(deps)
        name = char(deps{d}.name);
        declared(name) = deps{d};
        order{end+1} = name; %#ok<AGROW>
    end
end

pairs = edgePairs(given);
edges = struct('name', {}, 'document_id', {});
counts = containers.Map();
for k = 1:size(pairs, 1)
    name = pairs{k, 1};
    ids = pairs{k, 2};
    declName = declaredNameFor(declared, name);
    if isempty(declName)
        error('did2:build:unknownEdge', ...
            'Class "%s" declares no edge "%s". Declared: %s.', ...
            className, name, strjoin(order, ', '));
    end
    dep = declared(declName);
    if ischar(ids) || (isstring(ids) && isscalar(ids))
        ids = {char(ids)};
    elseif isstring(ids)
        ids = cellstr(ids);
    elseif ~iscellstr(ids)
        error('did2:build:typeMismatch', ...
            'Edge "%s" must be a document id (char) or a cellstr of ids.', name);
    end
    isMultiple = isfield(dep, 'multiple') && isequal(dep.multiple, true);
    prior = 0;
    if isKey(counts, name)
        prior = counts(name);
    end
    if ~isMultiple && prior + numel(ids) > 1
        error('did2:build:repeatedEdge', ...
            'Edge "%s" of "%s" is not declared `multiple` and takes one id; %d given.', ...
            name, className, prior + numel(ids));
    end
    for j = 1:numel(ids)
        if isempty(strtrim(ids{j}))
            error('did2:build:missingEdge', ...
                'Edge "%s" was given an empty id; leave an optional edge out instead.', name);
        end
        edges(end+1) = struct('name', name, 'document_id', ids{j}); %#ok<AGROW>
    end
    counts(name) = prior + numel(ids);
end

for k = 1:numel(order)
    dep = declared(order{k});
    name = order{k};
    n = 0;
    if isKey(counts, name)
        n = counts(name);
    end
    if endsWith(name, '_#')
        continue;   % a numbered family: its count is not an edge's to require
    end
    required = isfield(dep, 'mustBeNonEmpty') && isequal(dep.mustBeNonEmpty, true);
    if required && n == 0
        error('did2:build:missingEdge', 'Class "%s" requires edge "%s".', className, name);
    end
    if isfield(dep, 'min_count') && ~isempty(dep.min_count) && n > 0 && n < dep.min_count
        error('did2:build:missingEdge', ...
            'Edge "%s" of "%s" needs at least %d ids when given; %d given.', ...
            name, className, dep.min_count, n);
    end
    if isfield(dep, 'min_count') && ~isempty(dep.min_count) && dep.min_count > 0 && n == 0
        error('did2:build:missingEdge', ...
            'Edge "%s" of "%s" needs at least %d ids; none given.', name, className, dep.min_count);
    end
end
end

function pairs = edgePairs(given)
if isstruct(given)
    if ~isscalar(given)
        error('did2:build:typeMismatch', '''Edges'' must be a scalar struct or an N x 2 cell.');
    end
    names = fieldnames(given);
    pairs = cell(numel(names), 2);
    for k = 1:numel(names)
        pairs{k, 1} = names{k};
        pairs{k, 2} = given.(names{k});
    end
elseif iscell(given) && (isempty(given) || size(given, 2) == 2)
    pairs = given;
    if isempty(pairs)
        pairs = cell(0, 2);
    end
    for k = 1:size(pairs, 1)
        pairs{k, 1} = char(pairs{k, 1});
    end
else
    error('did2:build:typeMismatch', '''Edges'' must be a scalar struct or an N x 2 cell.');
end
end

function declName = declaredNameFor(declared, name)
declName = '';
if isKey(declared, name)
    declName = name;
    return;
end
tok = regexp(name, '^(.*)_\d+$', 'tokens', 'once');
if ~isempty(tok) && isKey(declared, [tok{1} '_#'])
    declName = [tok{1} '_#'];
end
end

function list = checkFiles(cache, className, files, chain)
if ischar(files) || isstring(files)
    files = cellstr(files);
end
if ~iscellstr(files)
    error('did2:build:typeMismatch', '''Files'' must be a cellstr of file names.');
end
names = {};
series = false(1, 0);
for c = 1:numel(chain)
    s = cache.getClass(chain{c});
    if ~isfield(s, 'file')
        continue;
    end
    decl = asDefs(s.file);
    for d = 1:numel(decl)
        names{end+1} = char(decl{d}.name); %#ok<AGROW>
        series(end+1) = isfield(decl{d}, 'series') && isequal(decl{d}.series, true); %#ok<AGROW>
    end
end
for k = 1:numel(files)
    f = files{k};
    ok = any(strcmp(f, names(~series)));
    for j = find(series)
        ok = ok || ~isempty(regexp(f, ['^' regexptranslate('escape', names{j}) '_\d+$'], 'once'));
    end
    if ~ok
        error('did2:build:unknownFile', ...
            'Class "%s" declares no file "%s". Declared: %s.', ...
            className, f, strjoin(names, ', '));
    end
end
list = reshape(files, 1, []);
end
