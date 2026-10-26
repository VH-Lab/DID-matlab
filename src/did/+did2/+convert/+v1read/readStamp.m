function s = readStamp(body)
%READSTAMP The `document_class` block (the stamp) of a RAW v1 document.
%
%   S = did2.convert.v1read.readStamp(BODY) reads `document_class` as NDI's
%   templates write it at the locked NDI-matlab `main` (3cb19a8):
%
%       definition, validation, class_name, property_list_name,
%       class_version, superclasses [{definition}]
%
%   and returns a struct with
%
%     class_name          as written; when absent, the basename of
%                         `definition` ('$NDIDOCUMENTPATH/subject.json' ->
%                         'subject'). Never snake_cased: a raw migrator is
%                         chosen by the v1 spelling.
%     class_version       as given ([] when absent)
%     definition, validation, property_list_name
%                         as text ('' when absent)
%     superclasses        cellstr of superclass names, in order, each its
%                         `class_name` or else its `definition` basename
%     schema_version      the generation stamp ('' when absent: a v1 document
%                         written before the stamps were named carries none)
%     is_v1, is_v2        did2.schema.isV1Stamp / isV2Stamp of that stamp
%                         (Decided by Jess Haley, 2026-10-25 [document
%                         stamps]: v1 = 'did_v1', V2 = 'did_v2')
%     extra               a struct of every other `document_class` field
%
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): the stamp is read by a shared helper each
%   migrator calls on the raw v1 document.
%
%   See also did2.convert.v1read.readBase, did2.convert.v1read.readDependsOn,
%            did2.convert.v1read.readApp, did2.schema.stampOf.

known = {'class_name', 'class_version', 'definition', 'validation', ...
    'property_list_name', 'superclasses', 'schema_version'};
s = struct('class_name', '', 'class_version', [], 'definition', '', ...
    'validation', '', 'property_list_name', '', 'superclasses', {{}}, ...
    'schema_version', '', 'is_v1', false, 'is_v2', false, 'extra', struct());
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'document_class') ...
        || ~isstruct(body.document_class) || ~isscalar(body.document_class)
    return;
end
dc = body.document_class;
for f = {'definition', 'validation', 'property_list_name', 'schema_version'}
    if isfield(dc, f{1})
        s.(f{1}) = textOf(dc.(f{1}));
    end
end
if isfield(dc, 'class_version')
    s.class_version = dc.class_version;
end
if isfield(dc, 'class_name') && ~isempty(dc.class_name)
    s.class_name = textOf(dc.class_name);
elseif ischar(s.definition) && ~isempty(s.definition)
    s.class_name = basenameOf(s.definition);
end
if isfield(dc, 'superclasses') && ~isempty(dc.superclasses)
    sc = dc.superclasses;
    if isstruct(sc)
        sc = num2cell(reshape(sc, 1, []));
    end
    if iscell(sc)
        for k = 1:numel(sc)
            e = sc{k};
            nm = '';
            if isstruct(e) && isscalar(e)
                if isfield(e, 'class_name') && ~isempty(e.class_name)
                    nm = textOf(e.class_name);
                elseif isfield(e, 'definition') && ~isempty(e.definition)
                    nm = basenameOf(textOf(e.definition));
                end
            end
            s.superclasses{end+1} = nm;
        end
    end
end
fns = fieldnames(dc);
for k = 1:numel(fns)
    if ~any(strcmp(fns{k}, known))
        s.extra.(fns{k}) = dc.(fns{k});
    end
end
if ischar(s.schema_version)
    s.is_v1 = did2.schema.isV1Stamp(s.schema_version);
    s.is_v2 = did2.schema.isV2Stamp(s.schema_version);
end
end

function name = basenameOf(path)
[~, name, ~] = fileparts(strrep(char(path), '\/', '/'));
end
