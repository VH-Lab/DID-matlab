function C = compareIngestedArchiveFiles(R, original, varargin)
%COMPAREINGESTEDARCHIVEFILES Compare an ingested archive's rebuilt files with
%   the v1 files.
%
%   C = did2.convert.roundtrip.compareIngestedArchiveFiles(R, ORIGINAL) takes
%   R, what did2.convert.roundtrip.ingestedArchiveFiles rebuilt, and ORIGINAL,
%   a struct of what the v1 archive attached:
%     member_names      cellstr, the v1 files.file_info names (optional)
%     channel_list      the v1 rows (a struct array as
%                       ndi.file.type.mfdaq_epoch_channel reads them), or
%                       the path of the v1 channel_list.bin (optional)
%     evmktx            struct array {name, and either data and
%                       data_description (what ndi.compress.read_ndibinary
%                       reads from the file) or channeltype, channel, T, D
%                       (what ndi.compress.expand_eventmarktext returns)}
%                       (optional)
%   C = ...(R, ORIGINAL, 'TimeTolerance', TOL) compares event times within
%   TOL seconds (default 0: exactly). The times are stored relative to the
%   epoch's start and the start is added back, so the rounding of that sum is
%   what a non-zero TOL would accept; no decision sets one.
%
%   WHY. [unpacked events file is removed] and [channel list rows get v2
%   homes] (Jess Haley, 2026-11-17, did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): a file is removed only when
%   "the round trip rebuilds it exactly; otherwise it is kept and counted".
%   This says, per file, whether it does.
%
%   HOW EACH FILE IS COMPARED.
%     channel_list.bin  BYTES when ORIGINAL.channel_list is a path and
%                       vlt.file.saveStructArray (vhlab-toolbox-matlab, a
%                       DID-matlab requirement, the function NDI's writer
%                       uses: ndi.file.type.mfdaq_epoch_channel/writeToFile)
%                       is on the path: the rebuilt rows are written with it
%                       and the two files compared byte for byte. Also, and
%                       otherwise, ROWS: field by field (NaN equals NaN).
%     evmktx_group<g>_seg.nbf_1
%                       CONTENT, never bytes: the file is
%                       ndi.compress.compress_eventmarktext's output, in
%                       NDI-compress, which DID-matlab does not depend on.
%                       With ORIGINAL data and data_description: those two,
%                       exactly (the encoded vector the file holds); else the
%                       decoded channels (channeltype, channel, T, D).
%     member names      as a set of names, each as many times.
%
%   C, the denominator first (Operating Rule 5):
%     files_compared   the number of entries in C.files
%     files            struct array {name, compared ('bytes' | 'rows' |
%                      'content' | 'decoded content' | 'names' | 'not
%                      measured'), exact (true, false, or [] when not
%                      measured), differences (cellstr), why}
%     exact            true when every file compared is exact and none is
%                      'not measured'
%
%   See also did2.convert.roundtrip.ingestedArchiveFiles.

opts = struct('TimeTolerance', 0);
for k = 1:2:numel(varargin)
    if ~isfield(opts, varargin{k})
        error('did2:convert:roundtrip:badOption', 'Unknown option ''%s''.', varargin{k});
    end
    opts.(varargin{k}) = varargin{k + 1};
end
files = struct('name', {}, 'compared', {}, 'exact', {}, 'differences', {}, 'why', {});

if isfield(original, 'member_names') && ~isempty(original.member_names)
    want = sort(reshape(cellstr(original.member_names), 1, []));
    got = {};
    for m = 1:numel(R.members); got = [got, R.members(m).names]; end %#ok<AGROW>
    if strcmp(R.channel_list_state, 'rebuilt'); got{end+1} = 'channel_list.bin'; end
    for e = 1:numel(R.evmktx); got{end+1} = R.evmktx(e).name; end %#ok<AGROW>
    got = sort([got, R.time_segments]);
    d = {};
    missing = setdiff(want, got);
    extra = setdiff(got, want);
    if ~isempty(missing); d{end+1} = ['not rebuilt: ' strjoin(missing, ', ')]; end
    if ~isempty(extra); d{end+1} = ['not in v1: ' strjoin(extra, ', ')]; end
    if isempty(d) && ~isequal(want, got); d{end+1} = 'a name is repeated a different number of times'; end
    files(end+1) = struct('name', '(member names)', 'compared', 'names', 'exact', isempty(d), ...
        'differences', {d}, 'why', '');
end

if isfield(original, 'channel_list') && ~isempty(original.channel_list)
    files(end+1) = channelListComparison(R, original.channel_list);
end

if isfield(original, 'evmktx')
    for k = 1:numel(original.evmktx)
        files(end+1) = evmktxComparison(R, original.evmktx(k), opts.TimeTolerance); %#ok<AGROW>
    end
end

C = struct('files_compared', numel(files), 'files', files, ...
    'exact', ~isempty(files) && all(arrayfun(@(f) isequal(f.exact, true), files)));
end

% =========================================================================

function f = channelListComparison(R, orig)
f = struct('name', 'channel_list.bin', 'compared', 'rows', 'exact', [], ...
    'differences', {{}}, 'why', '');
if ~strcmp(R.channel_list_state, 'rebuilt')
    f.compared = 'not measured';
    f.why = sprintf('channel_list.bin is %s: %s', R.channel_list_state, R.channel_list_why);
    return;
end
if ~(ischar(orig) || (isstring(orig) && isscalar(orig)))
    f.differences = rowDifferences(orig, R.channel_list);
    f.exact = isempty(f.differences);
    return;
end
% the v1 file: its bytes, written again with the writer's own function
path = char(orig);
if isempty(which('vlt.file.saveStructArray')) || isempty(which('vlt.file.loadStructArray'))
    f.compared = 'not measured';
    f.why = 'vlt.file.saveStructArray / loadStructArray (vhlab-toolbox-matlab) are not on the path';
    return;
end
tmp = [tempname() '.bin'];
c = onCleanup(@() deleteIfThere(tmp)); %#ok<NASGU>
vlt.file.saveStructArray(tmp, R.channel_list(:));
f.compared = 'bytes';
f.exact = isequal(bytesOf(tmp), bytesOf(path));
if ~f.exact
    % what differs, row by row (as NDI's reader reads the v1 file)
    f.differences = [{'the rebuilt file''s bytes differ from the v1 file''s'}, ...
        rowDifferences(vlt.file.loadStructArray(path), R.channel_list)];
end
end

function d = rowDifferences(a, b)
d = {};
if numel(a) ~= numel(b)
    d{end+1} = sprintf('%d v1 row(s), %d rebuilt', numel(a), numel(b));
end
F = {'name', 'type', 'time_channel', 'sample_rate', 'offset', 'scale', 'number', 'group', 'dataclass'};
for r = 1:min(numel(a), numel(b))
    for k = 1:numel(F)
        x = fieldOr(a(r), F{k});
        y = fieldOr(b(r), F{k});
        if ischar(x) || ischar(y)
            same = strcmp(char(x), char(y));
        else
            same = isequaln(double(x), double(y));
        end
        if ~same
            d{end+1} = sprintf('row %d %s: v1 %s, rebuilt %s', r, F{k}, show(x), show(y)); %#ok<AGROW>
        end
    end
end
end

function f = evmktxComparison(R, orig, tol)
name = char(orig.name);
f = struct('name', name, 'compared', 'not measured', 'exact', [], ...
    'differences', {{}}, 'why', '');
i = find(strcmp({R.evmktx.name}, name), 1);
if isempty(i)
    f.why = 'no unpacked channel observation rebuilds it';
    f.exact = false;
    f.differences = {'not rebuilt'};
    return;
end
e = R.evmktx(i);
if ~strcmp(e.state, 'rebuilt')
    f.why = sprintf('%s: %s', e.state, e.why);
    return;
end
f.why = ['content, not bytes: the file is ndi.compress.compress_eventmarktext''s ' ...
    'output (NDI-compress), which DID-matlab does not depend on'];
d = {};
if isfield(orig, 'data') && isfield(orig, 'data_description')
    f.compared = 'content';
    dd0 = double(orig.data_description);
    if ~isequal(size(dd0), size(e.data_description)) || ~isequal(dd0, e.data_description)
        d{end+1} = sprintf('data_description: v1 %s, rebuilt %s', mat2str(dd0), ...
            mat2str(e.data_description));
    end
    x = double(orig.data(:));
    y = double(e.data(:));
    if numel(x) ~= numel(y)
        d{end+1} = sprintf('data: v1 %d value(s), rebuilt %d', numel(x), numel(y));
    elseif ~valuesAgree(x, y, timeMask(e), tol)
        d{end+1} = sprintf('data: largest difference %g', max(abs(x - y)));
    end
else
    f.compared = 'decoded content';
    if ~isequal(cellstr(orig.channeltype), e.channeltype)
        d{end+1} = 'channel types differ';
    end
    if ~isequal(double(orig.channel(:))', double(e.channel(:))')
        d{end+1} = 'channel numbers differ';
    end
    n = min(numel(orig.T), numel(e.T));
    if numel(orig.T) ~= numel(e.T); d{end+1} = 'the number of channels differs'; end
    for c = 1:n
        t0 = double(orig.T{c}(:)); t1 = double(e.T{c}(:));
        if numel(t0) ~= numel(t1) || any(abs(t0 - t1) > tol)
            d{end+1} = sprintf('channel %d times differ', c); %#ok<AGROW>
        end
        if ~isequal(orig.D{c}, e.D{c}) && ~(isnumeric(orig.D{c}) && isnumeric(e.D{c}) ...
                && isequal(double(orig.D{c}), double(e.D{c})))
            d{end+1} = sprintf('channel %d values differ', c); %#ok<AGROW>
        end
    end
end
f.differences = d;
f.exact = isempty(d);
end

function tf = valuesAgree(x, y, isT, tol)
% exactly, except the time entries (IST), which are within TOL
tf = numel(isT) == numel(x) && isequal(x(~isT), y(~isT)) ...
    && all(abs(x(isT) - y(isT)) <= tol);
end

function isT = timeMask(e)
% which entries of the rebuilt vector are times, from its layout
% (eventmarktext2vector: per channel its times, then its codes or entries)
isT = false(0, 1);
for c = 1:numel(e.T)
    isT = [isT; true(numel(e.T{c}), 1)]; %#ok<AGROW>
    switch e.channeltype{c}
        case 'marker'
            isT = [isT; false(numel(e.D{c}), 1)]; %#ok<AGROW>
        case 'text'
            for j = 1:numel(e.D{c})
                isT = [isT; false(1 + numel(e.D{c}{j}), 1)]; %#ok<AGROW>
            end
    end
end
end

function v = fieldOr(s, f)
v = [];
if isfield(s, f); v = s.(f); end
end

function s = show(x)
if ischar(x)
    s = ['"' x '"'];
elseif (isnumeric(x) || islogical(x)) && ismatrix(x)
    s = mat2str(x);
else
    s = sprintf('(a %s)', class(x));
end
end

function b = bytesOf(p)
fid = fopen(p, 'r');
b = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);
end

function deleteIfThere(p)
if exist(p, 'file') == 2; delete(p); end
end
