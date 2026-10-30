function doc = sampledBody(ownerId, varargin)
%SAMPLEDBODY A sampled_body document: an N-D array of samples, in bytes.
%
%   DOC = did2.build.sampledBody(OWNERID, DIMENSIONS, 'SessionId', SID, ...)
%   DOC = did2.build.sampledBody(OWNERID, 'Dimensions', DIMENSIONS, 'SessionId', SID, ...)
%   builds a body holding the value of the statement (or standalone data_type
%   document) OWNERID. DIMENSIONS are THIS body's array axes, in array order
%   (did2.build.dimension / list; did-schema data_body AMENDMENT 6, `keys`
%   until 2026-10-22); a sampled_body requires them (require_inherited). They
%   may be given positionally or as 'Dimensions'. What is known along them
%   (sample times, channel names) is 'Covariates' (did2.build.covariate).
%   The element type is NOT on the body: it is the owner's `data_type` ("extent
%   is per-body, type is per-statement"), and the owner sets `data_body` true.
%
%   OWNERID may be a cellstr of several ids: `owner_id` repeats (did-schema
%   data_body, T15) when one body holds part of the value of several
%   statements -- a raw recording file shared by the observation of every
%   electrode recorded in it (Jess Haley, 2026-10-21,
%   V_eta_recording_observation_plan.md).
%
%   The bytes are a DID FILE SERIES, `body_data_0`, `body_data_1`, ... (item
%   17); an unchunked body is the single member `body_data_0`, which is the
%   default. 'Chunks' N names members 0..N-1; 'Files' names them outright.
%
%   Options (fields):
%     'Covariates'    what is known along THIS body's dimensions
%     'DatumOrder'    'C' (row-major, last dimension fastest) or 'F'
%                     (column-major, MATLAB's layout). Required when there is
%                     more than one dimension. Written to the block the schema
%                     declares it on: `data`, beside `dimensions`, since
%                     did-schema #88 (D-5); `sampled_body` before
%                     (did2.schema.cache/datumOrderBlock).
%     'ByteOrder'     'little' or 'big'; give it for any multi-byte datum type
%     'FillValue'     char literal read by the owner's data_type ("NaN",
%                     "-32768"): what a missing chunk holds
%     'Conditions'    one-value facts true of THIS body only
%     'Format'        an ontology term: {node, name} or a CURIE (formatTerm)
%     'Compression', 'ContentHash', 'HashAlgorithm', 'Description'
%     'Compression'   the codec: a spelling ('gzip', 'blosc-zstd'), a term or a
%                     {term, parameters} block, written in the form the
%                     schema declares (did2.build.compression; [compression
%                     block and empty levels], Jess Haley, 2026-10-26).
%                     Settings beyond the codec name: build the block with
%                     did2.build.compression(codec, 'Settings', s) and pass it
%     'Fields'        any other declared field, as a struct
%   Options (edges):
%     'MethodId'      the `method` document of the filter these samples
%                     passed through (Jess Haley 2026-10-22 [filters are
%                     methods]: a body's `filter_id` became `method_id`, and
%                     the 'FilterId' option is removed with it)
%     'KeyIds'        cellstr: value documents a covariate takes its positions
%                     from (a covariate's `document` indexes them)
%     'Edges'         any other declared edge
%   Options (document):
%     'Chunks' (default 1), 'Files', 'SessionId' (required),
%     'CreationTimestamp', 'Validate', 'SchemaCache'.
%     'Id'            base.id to use, as did2.build.document's 'Id': e.g. the
%                     id of the source document this body migrates from. ''
%                     (the default) mints a new id.
%
%   Example:
%     body = did2.build.sampledBody(obsId, ...
%         did2.build.list(did2.build.dimension('time', 30000), ...
%                         did2.build.dimension('channel', 4)), ...
%         'Covariates', did2.build.list( ...
%             did2.build.covariate('time', 0, 'Unit', 'second', 'Origin', 0, 'Spacing', 1/30000), ...
%             did2.build.covariate('channel', 1, 'Term', {'A1','A2','A3','A4'})), ...
%         'DatumOrder', 'F', 'ByteOrder', 'little', 'SessionId', sessionId);
%
%   See also did2.build.opaqueBody, did2.build.dimension, did2.build.covariate,
%   did2.build.statement.

% DIMENSIONS positionally (an odd count of the remaining arguments) or as the
% name-value 'Dimensions' (an even count): both reach buildBody() below.
if mod(numel(varargin), 2) == 1
    doc = buildBody(ownerId, varargin{1}, varargin{2:end});
else
    doc = buildBody(ownerId, [], varargin{:});
end
end

function doc = buildBody(ownerId, dimensions, options)
arguments
    ownerId {mustBeText} % one owner id, or a cellstr of several (owner_id repeats)
    dimensions
    options.Dimensions = []
    options.Covariates = []
    options.DatumOrder = ''
    options.ByteOrder = ''
    options.FillValue = ''
    options.Conditions = []
    options.Format = ''
    options.Compression = ''
    options.ContentHash = ''
    options.HashAlgorithm = ''
    options.Description = ''
    options.Fields (1,1) struct = struct()
    options.MethodId = ''
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

if ~isAbsent(dimensions) && ~isAbsent(options.Dimensions)
    error('did2:build:ambiguousField', ...
        'Give the dimensions positionally or as ''Dimensions'', not both.');
elseif isAbsent(dimensions)
    dimensions = options.Dimensions;
end
fields = struct('dimensions', {dimensions}, 'covariates', {options.Covariates}, ...
    'datum_order', options.DatumOrder, 'byte_order', options.ByteOrder, ...
    'fill_value', options.FillValue, ...
    'conditions', {options.Conditions}, 'format', did2.build.formatTerm(options.Format, options.SchemaCache), ...
    'compression', {did2.build.compression(options.Compression, 'SchemaCache', options.SchemaCache)}, 'content_hash', options.ContentHash, ...
    'hash_algorithm', options.HashAlgorithm, 'description', options.Description);
fields = bodyFields(fields);
edges = struct('owner_id', {ownerIds(ownerId)}, 'key_id', {options.KeyIds});
% the filter edge only when given, so a body with no filter builds on a schema
% that does not declare it
if ~isAbsent(options.MethodId); edges.method_id = options.MethodId; end
options.Files = bodyFiles(options.Files, options.Chunks);
doc = forward('sampled_body', fields, edges, options);
end

function ids = ownerIds(ownerId)
%OWNERIDS A body's owner id(s) as did2.build.document's 'Edges' takes them: a
%   char for one owner (unchanged), a cellstr for several. `owner_id` repeats
%   (did-schema data_body, T15, 2026-10-21) so one raw recording file can belong
%   to the observation of every electrode recorded in it. An empty cell is left
%   empty, so the builder's own min_count check reports it.
arguments
    ownerId {mustBeText}
end
if ischar(ownerId)
    ids = ownerId;
elseif isstring(ownerId) && isscalar(ownerId)
    ids = char(ownerId);
else
    ids = cellstr(ownerId);
    ids = ids(:)';
    if isscalar(ids)
        ids = ids{1};
    end
end
end
