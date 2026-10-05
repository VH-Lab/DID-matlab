function doc = sampledBody(ownerId, keys, options)
%SAMPLEDBODY A sampled_body document: an N-D array of samples, in bytes.
%
%   DOC = did2.build.sampledBody(OWNERID, KEYS, 'SessionId', SID, ...) builds
%   a body holding the value of the statement (or standalone data_type
%   document) OWNERID. KEYS describes THIS body's array, one key per dimension
%   (did2.build.key / list); a sampled_body requires them (require_inherited).
%   The element type is NOT on the body: it is the owner's `datum_type` ("extent
%   is per-body, type is per-statement"), and the owner sets `data_body` true.
%
%   The bytes are a DID FILE SERIES, `body_data_0`, `body_data_1`, ... (item
%   17); an unchunked body is the single member `body_data_0`, which is the
%   default. 'Chunks' N names members 0..N-1; 'Files' names them outright.
%
%   Options (fields):
%     'DatumOrder'    'C' (row-major, last key fastest) or 'F' (column-major,
%                     MATLAB's layout). Required when there is more than one key.
%     'ByteOrder'     'little' or 'big'; give it for any multi-byte datum type
%     'FillValue'     char literal read by the owner's datum_type ("NaN",
%                     "-32768"): what a missing chunk holds when 'Complete' is true
%     'Complete'      logical: dense (every position has a value)
%     'Conditions'    one-value facts true of THIS body only
%     'Format', 'Compression', 'ContentHash', 'HashAlgorithm', 'Description'
%     'Fields'        any other declared field, as a struct
%   Options (edges):
%     'FilterId'      the frequency filter these samples passed through
%     'KeyIds'        cellstr: data_type documents a key takes its positions
%                     from (a key's `positions_from` indexes them)
%     'Edges'         any other declared edge
%   Options (document):
%     'Chunks' (default 1), 'Files', 'SessionId' (required), 'Id',
%     'CreationTimestamp', 'Validate', 'SchemaCache'.
%
%   Example:
%     body = did2.build.sampledBody(obsId, ...
%         did2.build.list(did2.build.key('time', 30000, 'Unit', 'second', ...
%             'Origin', 0, 'Spacing', 1/30000), ...
%             did2.build.key('channel', 4, 'Labels', {'A1','A2','A3','A4'})), ...
%         'DatumOrder', 'F', 'ByteOrder', 'little', 'SessionId', sessionId);
%
%   See also did2.build.opaqueBody, did2.build.key, did2.build.statement.

arguments
    ownerId (1,:) char
    keys
    options.DatumOrder = ''
    options.ByteOrder = ''
    options.FillValue = ''
    options.Complete = []
    options.Conditions = []
    options.Format = ''
    options.Compression = ''
    options.ContentHash = ''
    options.HashAlgorithm = ''
    options.Description = ''
    options.Fields (1,1) struct = struct()
    options.FilterId = ''
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

fields = struct('keys', {keys}, ...
    'datum_order', options.DatumOrder, 'byte_order', options.ByteOrder, ...
    'fill_value', options.FillValue, 'complete', options.Complete, ...
    'conditions', {options.Conditions}, 'format', options.Format, ...
    'compression', options.Compression, 'content_hash', options.ContentHash, ...
    'hash_algorithm', options.HashAlgorithm, 'description', options.Description);
fields = bodyFields(fields);
edges = struct('owner_id', ownerId, 'filter_id', options.FilterId, ...
    'key_id', {options.KeyIds});
options.Files = bodyFiles(options.Files, options.Chunks);
doc = forward('sampled_body', fields, edges, options);
end
