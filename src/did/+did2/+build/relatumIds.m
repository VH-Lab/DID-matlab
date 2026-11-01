function ids = relatumIds(doc)
%RELATUMIDS The ends (relata) of an undirected_relation document.
%
%   IDS = did2.build.relatumIds(DOC) returns, as a row cellstr in stored
%   order, the document ids DOC's `relatum_id` edges name, followed by any its
%   `entity_id` edges name. The undirected relation's ends were renamed from
%   `entity_id` to `relatum_id` (did-schema did_v2_go_forward_class_audit.md,
%   Jess Haley 2026-11-01 [undirected ends are relata]); a reader takes both
%   names until the schema drops `entity_id`. DOC is a document body struct
%   (as did2.build returns) or a did2.document.
%
%   See also did2.build.undirectedRelation.

arguments
    doc
end

if isa(doc, 'did2.document')
    doc = doc.documentProperties;
end
ids = {};
if ~isstruct(doc) || ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
dep = doc.depends_on;
if isstruct(dep), dep = num2cell(dep); end
for want = {'relatum_id', 'entity_id'}
    for k = 1:numel(dep)
        e = dep{k};
        if ~isstruct(e) || ~isfield(e, 'name') || ~strcmp(char(e.name), want{1})
            continue;
        end
        v = '';
        if isfield(e, 'document_id'), v = e.document_id; elseif isfield(e, 'value'), v = e.value; end
        v = char(v);
        if ~isempty(v), ids{end+1} = v; end %#ok<AGROW>
    end
end
end
