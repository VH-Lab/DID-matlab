function [text, ok, why] = v1Files(action, arg1, arg2)
%V1FILES Read a file a v1 document attaches, for a migrator that must read it.
%
%   A per-document migrator is handed the v1 document, not its files. The
%   first migrator that must read an attached file is gene_list_mapping: the
%   gene indices of `mapping.tsv` become the `index` of the mapping's two
%   gene covariates, and its data rows are counted against v1 `n_pairs`
%   (Jess Haley, 2026-11-01, did-schema did_v2_go_forward_class_audit.md [key
%   covariate index]: "the indices are copied from mapping.tsv's gene index
%   columns"; [mapping rows counted, indices 0-based]).
%
%   did2.convert.v1Files('reset')            forget the reader
%   did2.convert.v1Files('set', READER)      READER is a function handle,
%       TEXT = READER(V1BODY, FILENAME), returning the file's bytes as char
%       (or erroring); [] for none. did2.convert.v1_to_v2 sets it from its
%       'V1FileReader' option (NDI-matlab passes one that reads its
%       database's binary store).
%   [TEXT, OK, WHY] = did2.convert.v1Files('read', V1BODY, FILENAME)
%       the bytes of the file FILENAME that V1BODY's `files` block attaches.
%       With a READER set, READER's answer. Without one, the first location
%       of that file whose `location_type` is 'file' and which exists on this
%       computer. OK is false (TEXT '') when the document attaches no such
%       file or none of it can be read; WHY says which, for the carry note.
%
%   [BYTES, OK, WHY] = did2.convert.v1Files('readBytes', V1BODY, FILENAME)
%       the same file's RAW bytes, a 1xN uint8 row, never decoded as text: for
%       a binary file (spikewaves.vsw and spiketimes.bin, float32 data; Jess
%       Haley, 2026-11-10 [spike waveforms built now], D4). With a READER set,
%       READER(V1BODY, FILENAME, 'bytes'), which must return uint8 (NDI-matlab's
%       ndi.migrate.internal.v1FileReader does); without one, the first local
%       `file` location, read with fread '*uint8'. The text read may not keep
%       every byte, so a binary file is never read with 'read'.
%   READER = did2.convert.v1Files('get')   the reader set now ([] for none),
%       for a batch pass that re-runs did2.convert.v1_to_v2 and must hand it
%       the same reader (did2.convert.epochMint's deferred spikewaves).
%
%   A file that cannot be read is NEVER read as empty: the caller carries the
%   document whole as v1.
%
%   See also did2.convert.v1_to_v2, did2.convert.migrators_j.gene_list_mapping.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'set', 'read', 'readBytes', 'get'})}
    arg1 = []
    arg2 = ''
end

persistent reader
text = '';
ok = false;
why = '';
switch action
    case 'reset'
        reader = [];
    case 'get'
        text = reader;
        ok = true;
    case 'readBytes'
        [text, ok, why] = readBytes(reader, arg1, char(arg2));
    case 'set'
        if ~isempty(arg1) && ~isa(arg1, 'function_handle')
            error('did2:convert:v1Files:badReader', ...
                'The v1 file reader is a function handle, TEXT = READER(V1BODY, FILENAME), or [].');
        end
        reader = arg1;
    case 'read'
        body = arg1;
        name = char(arg2);
        info = fileInfo(body, name);
        if isempty(info)
            why = sprintf('the document attaches no %s', name);
            return;
        end
        if ~isempty(reader)
            try
                text = reader(body, name);
                if isstring(text); text = char(text); end
                if ~ischar(text)
                    why = sprintf('the v1 file reader returned a %s for %s, not text', class(text), name);
                    text = '';
                    return;
                end
                ok = true;
            catch err
                why = sprintf('the v1 file reader could not read %s (%s)', name, err.message);
            end
            return;
        end
        locs = [];
        if isfield(info, 'locations')
            locs = info.locations;
        end
        if iscell(locs); locs = [locs{:}]; end
        for k = 1:numel(locs)
            if isstruct(locs) && isfield(locs, 'location') && isfield(locs, 'location_type') ...
                    && strcmpi(char(locs(k).location_type), 'file') ...
                    && isfile(char(locs(k).location))
                try
                    text = fileread(char(locs(k).location));
                    ok = true;
                    return;
                catch err
                    why = sprintf('%s could not be read at %s (%s)', name, char(locs(k).location), err.message);
                end
            end
        end
        if isempty(why)
            why = sprintf('%s is not readable here (no v1 file reader was given and no local file location exists)', name);
        end
end
end

function info = fileInfo(body, name)
% the `file_info` entry naming NAME; struct('name', NAME) when only
% `file_list` names it; [] when the document does not attach it
info = [];
if ~isstruct(body) || ~isfield(body, 'files') || ~isstruct(body.files) || ~isscalar(body.files)
    return;
end
f = body.files;
if isfield(f, 'file_info') && ~isempty(f.file_info)
    fi = f.file_info;
    if iscell(fi); fi = [fi{:}]; end
    if isstruct(fi) && isfield(fi, 'name')
        for k = 1:numel(fi)
            if strcmp(char(fi(k).name), name)
                info = fi(k);
                return;
            end
        end
    end
end
if isfield(f, 'file_list') && (ischar(f.file_list) || iscell(f.file_list) || isstring(f.file_list)) ...
        && any(strcmp(f.file_list, name))
    info = struct('name', name);
end
end

function [bytes, ok, why] = readBytes(reader, body, name)
% the raw bytes of NAME (see 'readBytes' above)
bytes = zeros(1, 0, 'uint8');
ok = false;
why = '';
info = fileInfo(body, name);
if isempty(info)
    why = sprintf('the document attaches no %s', name);
    return;
end
if ~isempty(reader)
    try
        got = reader(body, name, 'bytes');
        if ~isa(got, 'uint8')
            why = sprintf('the v1 file reader returned a %s for %s, not uint8 bytes', class(got), name);
            return;
        end
        bytes = reshape(got, 1, []);
        ok = true;
    catch err
        why = sprintf('the v1 file reader could not read the bytes of %s (%s)', name, err.message);
    end
    return;
end
locs = [];
if isfield(info, 'locations')
    locs = info.locations;
end
if iscell(locs); locs = [locs{:}]; end
for k = 1:numel(locs)
    if isstruct(locs) && isfield(locs, 'location') && isfield(locs, 'location_type') ...
            && strcmpi(char(locs(k).location_type), 'file') ...
            && isfile(char(locs(k).location))
        fid = fopen(char(locs(k).location), 'r');
        if fid < 0
            why = sprintf('%s could not be opened at %s', name, char(locs(k).location));
            continue;
        end
        got = fread(fid, Inf, '*uint8');
        fclose(fid);
        bytes = reshape(got, 1, []);
        if isempty(bytes); bytes = zeros(1, 0, 'uint8'); end
        ok = true;
        return;
    end
end
if isempty(why)
    why = sprintf('%s is not readable here (no v1 file reader was given and no local file location exists)', name);
end
end
