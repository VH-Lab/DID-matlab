function [scalarMap, arrayMap] = queryablePathMaps(scalarPaths, arrayDefs)
%QUERYABLEPATHMAPS The path -> affinity maps did2.database.compileQuery reads.
%
%   [SCALARMAP, ARRAYMAP] = did2.database.queryablePathMaps(SCALARPATHS,
%   ARRAYDEFS) normalises compileQuery's QueryablePaths and
%   QueryableArrayPaths inputs into containers.Map (path -> affinity). An
%   input that is already such a map is returned as it is, so
%   did2.database.sqlitedb builds the two maps once per database and hands
%   them to every search. Building them on every search cost about 6 ms a
%   search (NDI-matlab run 42241497254: 26 s of a 68 s getelements over
%   4,418 searches).
%
%   See also: did2.database.compileQuery, did2.database.sqlitedb.

[scalarMap] = asPathSet(scalarPaths);
[arrayMap] = asArrayPathMap(arrayDefs);
end

function set = asPathSet(paths)
% Normalise the queryable scalar paths into a path -> affinity map. PATHS
% is a struct array with `path` and `affinity` (what did2.database.sqlitedb
% passes, so each value is compared in the column it was stored in), or a
% cellstr of bare paths, whose affinity is then UNKNOWN and the value is
% compared across all three value columns.
if isa(paths, 'containers.Map')
    set = paths;   % already normalised (did2.database.sqlitedb builds it once)
    return;
end
set = containers.Map('KeyType', 'char', 'ValueType', 'char');
if isstruct(paths)
    for k = 1:numel(paths)
        p = char(paths(k).path);
        if isempty(p), continue; end
        a = '';
        if isfield(paths(k), 'affinity') && ~isempty(paths(k).affinity)
            a = upper(char(paths(k).affinity));
        end
        set(p) = a;
    end
    return;
end
for k = 1:numel(paths)
    p = char(paths{k});
    if isempty(p)
        continue;
    end
    set(p) = 'UNKNOWN';
end
end

function map = asArrayPathMap(arrayDefs)
% Normalise the QueryableArrayPaths input into a path -> affinity map.
% Accepts a struct array (one entry per sidecar-indexed path; the
% schema-cache shape with `.path` and `.affinity`), a cellstr of bare
% paths (assumes TEXT affinity), or empty for "no indexed array paths."
if isa(arrayDefs, 'containers.Map')
    map = arrayDefs;   % already normalised (did2.database.sqlitedb builds it once)
    return;
end
map = containers.Map('KeyType', 'char', 'ValueType', 'char');
if isempty(arrayDefs)
    return;
end
if isstruct(arrayDefs)
    for k = 1:numel(arrayDefs)
        p = char(arrayDefs(k).path);
        if isempty(p)
            continue;
        end
        if isfield(arrayDefs(k), 'affinity') && ~isempty(arrayDefs(k).affinity)
            map(p) = char(arrayDefs(k).affinity);
        else
            map(p) = 'TEXT';
        end
    end
elseif iscell(arrayDefs)
    for k = 1:numel(arrayDefs)
        p = char(arrayDefs{k});
        if ~isempty(p)
            map(p) = 'TEXT';
        end
    end
end
end
