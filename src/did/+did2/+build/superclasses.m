function sc = superclasses(className, options)
%SUPERCLASSES The document_class.superclasses list of a V_eta class.
%
%   SC = did2.build.superclasses(CLASSNAME) returns the list a document of
%   CLASSNAME carries in document_class.superclasses: one {class_name,
%   class_version} per ancestor, root first, read from the schema the
%   did2.schema.cache has loaded (DID_SCHEMA_PATH). It is the list
%   did2.build.document writes, and the list validateDocument checks
%   class-name-by-class-name.
%
%   For a migrator that writes a document's header itself (a pass-1 carrier
%   that renames a v1 class and keeps its blocks), so the document it emits
%   is complete as emitted: [early migration pieces fixed] (2), Decided by
%   Jess Haley, 2026-10-26 (did-schema did_v2_go_forward_class_audit.md):
%   "`ensureClassBlocks` padding goes: the builder produces a complete
%   document".
%
%   Options:
%     'ValueKind'    the value kind of a statement direction that takes one;
%                    its chain is listed after the class's own
%     'SchemaCache'  a did2.schema.cache; default the shared one
%
%   See also did2.build.document, did2.schema.cache.

arguments
    className (1,:) char
    options.ValueKind (1,:) char = ''
    options.SchemaCache = []
end

cache = schemaCache(options.SchemaCache);
ancestors = cache.documentAncestors(className, options.ValueKind);
sc = struct('class_name', {}, 'class_version', {});
for k = 1:numel(ancestors)
    ancDC = cache.getClass(ancestors{k}).document_class;
    sc(end+1) = struct('class_name', char(ancDC.class_name), ...
        'class_version', char(ancDC.class_version)); %#ok<AGROW>
end
end
