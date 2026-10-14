function doc = opaqueBody(ownerId, format, options)
%OPAQUEBODY An opaque_body document: bytes in a named container format.
%
%   DOC = did2.build.opaqueBody(OWNERID, FORMAT, 'SessionId', SID, ...) builds
%   a body holding the value of OWNERID as bytes the database does not read
%   into an array: a PDF, a TIFF stack, a lab binary. FORMAT is an ontology
%   TERM (lightsheet point 4, Jess 2026-10-14; did-schema 877bbde): a
%   {node, name} struct, or a bare CURIE whose name is filled in when known
%   ('EDAM:format_3591' -> TIFF; see did2.build.formatTerm, which also writes the
%   older schema's media-type string when the loaded schema types format as char). It
%   is no longer an IANA media type. An opaque_body requires it
%   (require_inherited).
%
%   The bytes are the file series `body_data_0`, `body_data_1`, ...; the default
%   is the single member `body_data_0`.
%
%   Options (fields):
%     'Keys'          optional: the array as FORMAT presents it
%     'Complete', 'Conditions', 'Compression', 'ContentHash',
%     'HashAlgorithm' ('MD5','SHA-1','SHA-256','SHA-512'), 'Description'
%     'Fields'        any other declared field, as a struct
%   Options (edges):
%     'KeyIds', 'Edges'
%   Options (document):
%     'Chunks' (default 1), 'Files', 'SessionId' (required), 'Id',
%     'CreationTimestamp', 'Validate', 'SchemaCache'.
%
%   See also did2.build.sampledBody.

arguments
    ownerId (1,:) char
    format
    options.Keys = []
    options.Complete = []
    options.Conditions = []
    options.Compression = ''
    options.ContentHash = ''
    options.HashAlgorithm = ''
    options.Description = ''
    options.Fields (1,1) struct = struct()
    options.KeyIds = {}
    options.Edges = struct()
    options.Chunks (1,1) double {mustBeInteger, mustBePositive} = 1
    options.Files = {}
    options.SessionId (1,:) char = ''
    options.Id (1,:) char = ''
    options.CreationTimestamp (1,:) char = ''
    options.Validate (1,1) logical = true
    options.SchemaCache = []
end

format = did2.build.formatTerm(format, options.SchemaCache);
if isempty(format) || (isstruct(format) && isempty(format.node) && isempty(format.name))
    error('did2:build:missingField', ...
        'An opaque_body requires `format` (an ontology term: {node, name} or a CURIE).');
end
fields = struct('format', format, 'keys', {options.Keys}, ...
    'complete', options.Complete, 'conditions', {options.Conditions}, ...
    'compression', options.Compression, 'content_hash', options.ContentHash, ...
    'hash_algorithm', options.HashAlgorithm, 'description', options.Description);
fields = bodyFields(fields);
edges = struct('owner_id', ownerId, 'key_id', {options.KeyIds});
options.Files = bodyFiles(options.Files, options.Chunks);
doc = forward('opaque_body', fields, edges, options);
end
