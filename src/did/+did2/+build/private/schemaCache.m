function cache = schemaCache(cache)
%SCHEMACACHE The schema cache a builder should use.
%
%   An explicitly supplied did2.schema.cache wins; otherwise the shared
%   singleton (DID_SCHEMA_PATH) is used.

if isempty(cache)
    cache = did2.schema.cache.shared();
elseif ~isa(cache, 'did2.schema.cache')
    error('did2:build:badSchemaCache', ...
        'SchemaCache must be a did2.schema.cache, got %s.', class(cache));
end
end
