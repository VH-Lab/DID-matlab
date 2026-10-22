function checkMethodSharedAndOwn(statement, method)
%CHECKMETHODSHAREDANDOWN An inline method beside `method_id` only adds settings.
%
%   did2.build.checkMethodSharedAndOwn(STATEMENT, METHOD) raises
%   did2:build:ruleViolated unless
%     * STATEMENT's `method_id` edge names METHOD (its base.id),
%     * STATEMENT's inline `method.term`, if it has an inline method, is empty,
%       and
%     * no variable of STATEMENT's inline `method.parameters` is also a
%       variable of METHOD's `parameters` (compared by node, else by label).
%   This is the did-schema interaction rule `method_shared_and_own` (Jess Haley
%   2026-10-22 [method shared plus own], [rules and clock_alignment tenet]): a
%   statement with `method_id` may also carry an inline `method` whose
%   parameters add settings only this run had. A CHANGED shared setting is a
%   variant method document with `parent_id`, not an inline override.
%   did2.build checks the term half when it builds the statement; the variable
%   half needs the shared method document, so a caller that holds both (a
%   migrator, an import) calls this. STATEMENT and METHOD are built document
%   structs (did2.build.*) or did2.document objects.
%
%   See also did2.build.method, did2.build.statement, did2.build.checkDoseIngredients.

arguments
    statement
    method
end

statement = asStruct(statement);
method = asStruct(method);
mid = char(method.base.id);
named = edgeIds(statement, 'method_id');
if ~isequal(named, {mid})
    error('did2:build:ruleViolated', ...
        ['method_shared_and_own (statement %s): its method_id names %s, not the ' ...
         'method given (%s).'], char(statement.base.id), strjoin(named, ', '), mid);
end
inline = [];
for b = reshape(fieldnames(statement), 1, [])
    blk = statement.(b{1});
    if isstruct(blk) && isscalar(blk) && isfield(blk, 'method') && isstruct(blk.method) ...
            && isscalar(blk.method)
        inline = blk.method;
        break;
    end
end
if isempty(inline)
    return;
end
if isfield(inline, 'term') && ~blankTerm(inline.term)
    error('did2:build:ruleViolated', ...
        ['method_shared_and_own (statement %s): beside method_id %s the inline ' ...
         'method only adds settings; its term must be empty.'], char(statement.base.id), mid);
end
own = variableKeys(inline);
shared = {};
if isfield(method, 'method') && isstruct(method.method)
    shared = variableKeys(method.method);
end
both = intersect(own, shared, 'stable');
if ~isempty(both)
    error('did2:build:ruleViolated', ...
        ['method_shared_and_own (statement %s): parameter variable(s) %s are ' ...
         'both inline and on the shared method %s; a changed shared setting is a ' ...
         'variant method document with parent_id.'], char(statement.base.id), ...
        strjoin(both, ', '), mid);
end
end

function keys = variableKeys(block)
keys = {};
if ~isfield(block, 'parameters') || ~isstruct(block.parameters)
    return;
end
p = block.parameters;
for k = 1:numel(p)
    if isfield(p, 'variable')
        key = termKey(p(k).variable);
        if ~isempty(key); keys{end+1} = key; end %#ok<AGROW>
    end
end
end

function s = termKey(term)
s = '';
if isstruct(term) && isfield(term, 'node') && ~isempty(term.node)
    s = char(term.node);
elseif isstruct(term) && isfield(term, 'name') && ~isempty(term.name)
    s = char(term.name);
elseif ischar(term) || isstring(term)
    s = char(term);
end
end

function tf = blankTerm(t)
tf = isempty(termKey(t));
end

function s = asStruct(d)
if isa(d, 'did2.document')
    s = d.documentProperties;
else
    s = d;
end
end

function ids = edgeIds(doc, name)
ids = {};
if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
for k = 1:numel(doc.depends_on)
    if iscell(doc.depends_on)
        d = doc.depends_on{k};
    else
        d = doc.depends_on(k);
    end
    if strcmp(char(d.name), name)
        if isfield(d, 'document_id')
            ids{end+1} = char(d.document_id); %#ok<AGROW>
        elseif isfield(d, 'value')
            ids{end+1} = char(d.value); %#ok<AGROW>
        end
    end
end
end
