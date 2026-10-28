function T = v1Templates(root)
%V1TEMPLATES NDI-matlab's v1 document templates, indexed by class name.
%
%   T = did2.schema.v1Templates(ROOT) reads every *.json under ROOT (NDI-matlab's
%   src/ndi/ndi_common/database_documents, at the locked `main`) and returns:
%     present   false when ROOT is empty or holds no template (nothing can be
%               checked: a caller says NOT CHECKED, never "valid")
%     root      ROOT
%     count     the number of templates read
%     byClass   containers.Map, document_class.class_name -> a struct
%                 class_name, blocks (a struct: property block name -> cellstr
%                 of its fields), edges (cellstr of depends_on names),
%                 has_files (the template declares a `files` block),
%                 superclasses (cellstr of the superclasses' class names)
%               with the blocks, edges and files of every superclass merged in
%               (NDI's ndi.document constructor adds them the same way)
%
%   T = did2.schema.v1Templates() reads the ROOT named by the environment:
%   DID_NDI_TEMPLATE_PATH, else $NDI_MATLAB/src/ndi/ndi_common/database_documents;
%   with neither, present is false. The index is built once per ROOT.
%
%   A superclass is named in a template by `definition`
%   ('$NDIDOCUMENTPATH/base.json'); it is found by that path under ROOT, else
%   by its file name anywhere under ROOT (a flat copy, such as DID-matlab's
%   tests/+did2/fixtures/ndi_templates).
%
%   WHY. Decided by Jess Haley, 2026-10-27 [carried v1 validates against NDI
%   templates] (did-schema V_eta_go_forward_class_audit.md): "a document carried
%   whole as v1 is validated against NDI-matlab's v1 templates at the locked
%   NDI `main`, not against did-schema tombstones". did2.validate.v1Document is
%   the check; this is what it reads.
%
%   See also did2.validate.v1Document.

arguments
    root = []
end

if isempty(root)
    root = getenv('DID_NDI_TEMPLATE_PATH');
    if isempty(root) && ~isempty(getenv('NDI_MATLAB'))
        root = fullfile(getenv('NDI_MATLAB'), 'src', 'ndi', 'ndi_common', 'database_documents');
    end
end
root = char(root);

persistent lastRoot lastT
if ~isempty(lastRoot) && strcmp(lastRoot, root) && ~isempty(lastT)
    T = lastT;
    return;
end

T = struct('present', false, 'root', root, 'count', 0, ...
    'byClass', containers.Map('KeyType', 'char', 'ValueType', 'any'));
if isempty(root) || ~isfolder(root)
    return;
end
files = dir(fullfile(root, '**', '*.json'));
raw = containers.Map('KeyType', 'char', 'ValueType', 'any');     % class -> template
byPath = containers.Map('KeyType', 'char', 'ValueType', 'any');  % relative path / file name -> class
for k = 1:numel(files)
    f = fullfile(files(k).folder, files(k).name);
    try
        t = jsondecode(fileread(f));
    catch
        continue;
    end
    if ~isstruct(t) || ~isfield(t, 'document_class') || ~isstruct(t.document_class) ...
            || ~isfield(t.document_class, 'class_name')
        continue;
    end
    cls = char(t.document_class.class_name);
    if isempty(cls) || isKey(raw, cls)
        continue;
    end
    raw(cls) = t;
    rel = strrep(f(numel(root) + 2:end), '\', '/');
    byPath(rel) = cls;
    if ~isKey(byPath, files(k).name)
        byPath(files(k).name) = cls;
    end
end
names = keys(raw);
for k = 1:numel(names)
    T.byClass(names{k}) = resolve(names{k}, raw, byPath, {});
end
T.count = numel(names);
T.present = T.count > 0;
lastRoot = root;
lastT = T;
end

function e = resolve(cls, raw, byPath, seen)
t = raw(cls);
e = struct('class_name', cls, 'blocks', struct(), 'edges', {{}}, ...
    'has_files', isfield(t, 'files'), 'superclasses', {{}});
dc = t.document_class;
if isfield(dc, 'property_list_name') && ~isempty(dc.property_list_name)
    blk = char(dc.property_list_name);
    fields = {};
    if isfield(t, blk) && isstruct(t.(blk))
        fields = fieldnames(t.(blk))';
    end
    e.blocks.(blk) = fields;
end
if isfield(t, 'depends_on') && ~isempty(t.depends_on)
    d = t.depends_on;
    if isstruct(d)
        e.edges = {d.name};
    elseif iscell(d)
        e.edges = cellfun(@(x) char(x.name), d, 'UniformOutput', false);
    end
end
supers = {};
if isfield(dc, 'superclasses') && ~isempty(dc.superclasses)
    s = dc.superclasses;
    if isstruct(s); s = num2cell(s); end
    for k = 1:numel(s)
        if isstruct(s{k}) && isfield(s{k}, 'definition')
            supers{end+1} = char(s{k}.definition); %#ok<AGROW>
        end
    end
end
for k = 1:numel(supers)
    def = strrep(supers{k}, '\', '/');
    rel = regexprep(def, '^\$NDIDOCUMENTPATH/?', '');
    [~, nm, ext] = fileparts(rel);
    sc = '';
    if isKey(byPath, rel)
        sc = byPath(rel);
    elseif isKey(byPath, [nm ext])
        sc = byPath([nm ext]);
    end
    if isempty(sc) || any(strcmp(sc, seen)) || strcmp(sc, cls)
        continue;
    end
    p = resolve(sc, raw, byPath, [seen, {cls}]);
    e.superclasses = [e.superclasses, {sc}, p.superclasses];
    for b = fieldnames(p.blocks)'
        e.blocks.(b{1}) = p.blocks.(b{1});
    end
    e.edges = [e.edges, p.edges];
    e.has_files = e.has_files || p.has_files;
end
e.edges = unique(e.edges, 'stable');
end
