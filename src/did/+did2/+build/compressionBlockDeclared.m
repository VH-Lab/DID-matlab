function tf = compressionBlockDeclared(schemaCache)
%COMPRESSIONBLOCKDECLARED Does the loaded schema declare `data_body.compression`
%   as the {term, parameters} block?
%
%   TF = did2.build.compressionBlockDeclared() reads the shared schema cache;
%   TF = did2.build.compressionBlockDeclared(SCHEMACACHE) reads that one.
%
%   [compression block and empty levels] (1) (Decided by Jess Haley,
%   2026-10-26, did-schema V_eta_go_forward_class_audit.md; issue #137):
%   `compression`, a `char` holding a codec name, becomes a {term, parameters}
%   block, the shape `method` uses. A field type change, so DID-matlab and
%   NDI-matlab change first (CLAUDE.md section 3, rule 2): every writer asks
%   this, and writes the block only once the schema declares it, so nothing
%   breaks while did-schema still says `char`.
%
%   TRUE when the first of data_body / sampled_body / opaque_body the schema
%   holds declares a `compression` field with a `term` subfield (the probe
%   jSchemaHasPath makes for a migrator, and formatTerm makes for `format`).
%   FALSE when it is declared any other way (a `char`), not declared, or the
%   schema cannot be read.
%
%   See also did2.build.compression, did2.build.compressionCodec.

arguments
    schemaCache = []
end

tf = false;
try
    cache = schemaCache;
    if isempty(cache)
        cache = did2.schema.cache.shared();
    end
    for cls = {'data_body', 'sampled_body', 'opaque_body'}
        if ~cache.hasClass(cls{1})
            continue;
        end
        tagged = cache.fieldsFor(cls{1});
        for k = 1:numel(tagged)
            fd = tagged(k).fieldDef;
            if isfield(fd, 'name') && strcmp(char(fd.name), 'compression')
                tf = hasSubfield(fd, 'term');
                return;
            end
        end
    end
catch
    tf = false;
end
end

function tf = hasSubfield(fd, name)
tf = false;
if ~isfield(fd, 'fields') || isempty(fd.fields)
    return;
end
subs = asDefs(fd.fields);
for j = 1:numel(subs)
    if isstruct(subs{j}) && isfield(subs{j}, 'name') && strcmp(char(subs{j}.name), name)
        tf = true;
        return;
    end
end
end
