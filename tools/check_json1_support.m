function check_json1_support()
%CHECK_JSON1_SUPPORT  Probe whether the mksqlite build supports JSON1.
%
% Prints: SQLite version, whether ENABLE_JSON1 appears in compile options,
% and the result of a functional json_extract + json_each test.
%
% Run from the DID-matlab root with mksqlite on the path.
%
% Note: since SQLite 3.38, JSON1 is built unconditionally and the
% ENABLE_JSON1 compile flag is a no-op (so it does not appear in
% PRAGMA compile_options). Tests 1-4 below are the authoritative signal,
% not the flag.

    fprintf('--- mksqlite / SQLite JSON1 probe ---\n');

    % 1. Open an in-memory database
    try
        db = mksqlite(0, 'open', ':memory:');
    catch ME
        fprintf(2, 'Could not open in-memory db via mksqlite: %s\n', ME.message);
        return;
    end
    cleanup = onCleanup(@() mksqlite(db, 'close')); %#ok<NASGU>

    % 2. SQLite version
    try
        v = mksqlite(db, 'SELECT sqlite_version() AS v');
        fprintf('SQLite version: %s\n', v.v);
    catch ME
        fprintf(2, 'sqlite_version() failed: %s\n', ME.message);
    end

    % 3. Compile options
    try
        opts = mksqlite(db, 'PRAGMA compile_options');
        optStrs = {opts.compile_options};
        hasFlag = any(contains(optStrs, 'ENABLE_JSON1', 'IgnoreCase', true));
        omitFlag = any(contains(optStrs, 'OMIT_JSON',    'IgnoreCase', true));
        fprintf('compile_options: ENABLE_JSON1=%d  OMIT_JSON=%d  (n=%d total)\n', ...
            hasFlag, omitFlag, numel(optStrs));
    catch ME
        fprintf(2, 'PRAGMA compile_options failed: %s\n', ME.message);
    end

    % 4. Functional test: json_extract on a scalar path
    fprintf('\n[test 1] json_extract on a scalar path\n');
    try
        r = mksqlite(db, ...
            'SELECT json_extract(''{"a":{"b":42}}'', ''$.a.b'') AS v');
        fprintf('  json_extract -> %d  (expected 42)  %s\n', ...
            r.v, tickOrCross(isequal(r.v, 42)));
    catch ME
        fprintf(2, '  FAIL: %s\n', ME.message);
    end

    % 5. Functional test: json_each over an array (array-iteration / [*] support)
    fprintf('[test 2] json_each over an array of objects\n');
    try
        r = mksqlite(db, [ ...
            'SELECT value FROM json_each(' ...
            '''[{"name":"x","unit":"um"},{"name":"y","unit":"um"},{"name":"z","unit":"mm"}]'')']);
        fprintf('  json_each rows: %d  (expected 3)  %s\n', ...
            numel(r), tickOrCross(numel(r) == 3));
    catch ME
        fprintf(2, '  FAIL: %s\n', ME.message);
    end

    % 6. Functional test: EXISTS over json_each with json_extract on each element
    %    (the actual shape of a compiled [*] query)
    fprintf('[test 3] EXISTS over json_each + json_extract on the element\n');
    try
        mksqlite(db, 'CREATE TABLE docs(id INTEGER PRIMARY KEY, body TEXT)');
        mksqlite(db, ['INSERT INTO docs(body) VALUES (' ...
            '''{"axes":[{"name":"x","unit":"um"},{"name":"z","unit":"mm"}]}'')']);
        r = mksqlite(db, [ ...
            'SELECT id FROM docs WHERE EXISTS (' ...
            '  SELECT 1 FROM json_each(docs.body, ''$.axes'') AS ax' ...
            '  WHERE json_extract(ax.value, ''$.unit'') = ''mm''' ...
            ')']);
        fprintf('  matched docs: %d  (expected 1)  %s\n', ...
            numel(r), tickOrCross(numel(r) == 1));
    catch ME
        fprintf(2, '  FAIL: %s\n', ME.message);
    end

    % 7. Generated-column-with-json_extract test (optional speed path)
    fprintf('[test 4] generated column using json_extract (for indexed paths)\n');
    try
        mksqlite(db, ['CREATE TABLE docs2(' ...
            '  id INTEGER PRIMARY KEY,' ...
            '  body TEXT,' ...
            '  hertz REAL GENERATED ALWAYS AS (json_extract(body, ''$.sample_rate.hertz'')) STORED' ...
            ')']);
        mksqlite(db, 'INSERT INTO docs2(body) VALUES (''{"sample_rate":{"hertz":40000}}'')');
        r = mksqlite(db, 'SELECT hertz FROM docs2');
        fprintf('  generated column hertz=%g  (expected 40000)  %s\n', ...
            r.hertz, tickOrCross(isequal(r.hertz, 40000)));
    catch ME
        fprintf(2, '  FAIL: %s\n', ME.message);
    end

    fprintf('\nDone. If tests 1-3 pass, JSON1 is usable for the v2 query layer.\n');
    fprintf('Test 4 passing is a bonus -- it means we can use indexed generated columns\n');
    fprintf('for queryable scalar paths without a separate sidecar table.\n');
end

function s = tickOrCross(ok)
    if ok, s = 'OK'; else, s = 'FAIL'; end
end
