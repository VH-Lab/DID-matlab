function d = ndiDocument(className, options)
%NDIDOCUMENT A v1 document as ndi.document(CLASSNAME) builds it from NDI's
%   templates, before the writer sets its values.
%
%   D = did2.unittest.helpers.ndiDocument(CLASSNAME, 'Id', ID, 'SessionId',
%   SID, 'Name', NAME, 'Datestamp', DATESTAMP) reads
%   tests/+did2/fixtures/ndi_templates/<CLASSNAME>.json (copied verbatim from
%   NDI-matlab's locked `main`, 3cb19a8, or NDIcalc-vis-matlab) and, as
%   ndi.document's constructor does, adds the property blocks of every
%   superclass the template names by `definition` (base.json, app.json,
%   epochid.json, ...; each one's own template in the same folder), with their
%   template defaults. The `base` block takes ID, SID, NAME and DATESTAMP. The
%   template's `depends_on` and `files` are kept as the template states them.
%   The caller then sets what the WRITER sets (the writer wins over the
%   template) and passes the document through jsonencode/jsondecode, the shape
%   a corpus delivers.
%
%   A superclass whose template is not in the fixtures folder is an error: a
%   fixture never invents a block.
%
%   See also did2.unittest.helpers.setDependency.

arguments
    className (1,:) char
    options.Id (1,:) char = '41268b6f5c6a3d4e_c0d1a9e2b3f4a5b6'
    options.SessionId (1,:) char = '41268b6f5c6a3d4e_00000000000000a1'
    options.Name (1,:) char = ''
    options.Datestamp (1,:) char = '2025-05-27T15:47:23.738Z'
end

tpl = template(className);
d = struct();
d.document_class = tpl.document_class;
if isfield(tpl, 'depends_on')
    d.depends_on = tpl.depends_on;
end
d = addBlocks(d, tpl, {});
d.base.id = options.Id;
d.base.session_id = options.SessionId;
d.base.name = options.Name;
d.base.datestamp = options.Datestamp;
end

function d = addBlocks(d, tpl, seen)
% the superclasses' blocks first (root first), then the template's own
sc = {};
if isfield(tpl.document_class, 'superclasses')
    sc = tpl.document_class.superclasses;
    if isstruct(sc); sc = num2cell(sc); end
end
for k = 1:numel(sc)
    def = char(sc{k}.definition);
    [~, name] = fileparts(def);
    if any(strcmp(seen, name)); continue; end
    seen{end+1} = name; %#ok<AGROW>
    d = addBlocks(d, template(name), seen);
end
fns = fieldnames(tpl);
for k = 1:numel(fns)
    f = fns{k};
    if any(strcmp(f, {'document_class', 'depends_on'}))
        continue;
    end
    if ~isfield(d, f)
        d.(f) = tpl.(f);
    end
end
end

function tpl = template(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(fileparts(thisDir)), 'fixtures', 'ndi_templates', [name '.json']);
if ~isfile(f)
    error('did2:unittest:noTemplate', ...
        'No NDI template %s.json in tests/+did2/fixtures/ndi_templates.', name);
end
tpl = jsondecode(fileread(f));
end
