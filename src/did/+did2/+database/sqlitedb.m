classdef sqlitedb < handle
    % did2.database.sqlitedb  SQLite + JSON1 backend for V_delta documents.
    %
    %   First database backend in the v2 line. Stores each document's full
    %   V_delta JSON body in a single TEXT column on the `documents`
    %   table; the `superclasses` and `depends_on` sidecar tables hold
    %   the entries needed for `isa` and `depends_on` queries without
    %   walking JSON.
    %
    %   This is the "JSON1 fallback only" backend called for in
    %   docs/v2/PLAN.md §9 step 3: every body predicate compiles to
    %   sqlite3 json_extract / json_each via did2.database.compileQuery,
    %   and the result set is post-filtered through the reference
    %   in-memory evaluator (did2.query.matches) to guarantee correctness
    %   even where the SQL compiler emits a permissive pre-filter
    %   (`regexp`, multi-element `exact_number`, etc.).
    %
    %   The class requires `mksqlite` on the MATLAB path. Schema layout
    %   matches §3.1 of the plan (without the step-4 generated columns
    %   and the step-5 queryable_array_elem sidecar; both can be added
    %   later without breaking the body / sidecar tables defined here).
    %
    %   did2.database.sqlitedb Methods:
    %       sqlitedb     - open or create a v2 SQLite database.
    %       close        - close the underlying mksqlite connection.
    %       isOpen       - has this instance an open connection?
    %       add          - insert one document or a list of documents.
    %       remove       - delete by id (string) or by did2.document.
    %       has          - true if a document with the given id exists.
    %       get          - fetch the did2.document for an id.
    %       allIds       - return every document id (cellstr).
    %       count        - number of documents in the database.
    %       search       - return documents matching a did2.query.
    %       searchIds    - return the ids of documents matching a query.
    %
    %   See also: did2.query, did2.database.compileQuery, did2.document,
    %             docs/v2/PLAN.md.

    properties (SetAccess = private)
        filename (1,:) char = ''
    end

    properties (Access = private)
        dbid = []
        schemaCache = []
        queryableScalarColumns = []  % struct array from did2.schema.cache.queryablePaths
        queryableScalarPaths = {}    % cellstr mirror, passed to compileQuery
        queryableArrayPathDefs = []  % struct array; one per [*]-bearing sub-field
        queryableArrayPaths = {}     % cellstr mirror, passed to compileQuery
        queryableBootstrapOk (1,1) logical = false
    end

    properties (Constant, Access = private)
        SchemaVersion = 1
    end

    methods
        function obj = sqlitedb(filename, opts)
            % sqlitedb - open an existing v2 SQLite database, or create one.
            arguments
                filename (1,:) char
                opts.SchemaCache = []
            end
            if isempty(which('mksqlite'))
                error('did2:database:noMksqlite', ...
                    ['mksqlite is required for did2.database.sqlitedb. ' ...
                     'Install https://github.com/a-ma72/mksqlite and put it on the path.']);
            end
            obj.filename = filename;
            obj.schemaCache = opts.SchemaCache;
            obj.bootstrapQueryableColumns();
            isNew = ~isfile(filename);
            obj.dbid = mksqlite(0, 'open', filename);
            mksqlite(obj.dbid, 'pragma foreign_keys = ON');
            if isNew
                obj.createSchema();
            else
                obj.assertSchema();
                obj.reconcileQueryableColumns();
                obj.reconcileQueryableArrayPaths();
            end
        end

        function delete(obj)
            obj.close();
        end

        function close(obj)
            % close - close the underlying mksqlite connection. Idempotent.
            if ~isempty(obj.dbid)
                try
                    mksqlite(obj.dbid, 'close');
                catch
                end
                obj.dbid = [];
            end
        end

        function tf = isOpen(obj)
            % isOpen - true if this instance has an open connection.
            tf = ~isempty(obj.dbid);
        end

        function add(obj, docOrList, opts)
            % add - insert one document or a list of documents.
            %
            %   db.add(doc)
            %   db.add({doc1, doc2, ...})
            %   db.add(docs, Validate=false) skips schema validation
            %       (PLAN.md §1 "unsafe_insert" escape hatch).
            arguments
                obj
                docOrList
                opts.Validate (1,1) logical = true
            end
            list = obj.normaliseDocList(docOrList);
            for k = 1:numel(list)
                obj.addOne(list{k}, opts.Validate);
            end
        end

        function remove(obj, target)
            % remove - delete a document by id or by did2.document.
            id = obj.coerceId(target);
            % ON DELETE CASCADE handles superclasses / depends_on rows.
            mksqlite(obj.dbid, 'DELETE FROM documents WHERE id = ?', id);
        end

        function tf = has(obj, idOrDoc)
            % has - does a document with this id exist?
            id = obj.coerceId(idOrDoc);
            row = mksqlite(obj.dbid, ...
                'SELECT 1 AS hit FROM documents WHERE id = ?', id);
            tf = ~isempty(row);
        end

        function doc = get(obj, idOrDoc)
            % get - fetch a did2.document for the given id.
            id = obj.coerceId(idOrDoc);
            row = mksqlite(obj.dbid, ...
                'SELECT body FROM documents WHERE id = ?', id);
            if isempty(row)
                error('did2:database:missingDocument', ...
                    'No document with id "%s".', id);
            end
            doc = did2.document.fromJSON(row(1).body);
        end

        function ids = allIds(obj)
            % allIds - every document id, in insertion order.
            rows = mksqlite(obj.dbid, ...
                'SELECT id FROM documents ORDER BY rowid ASC');
            ids = obj.rowsToCellstr(rows, 'id');
        end

        function n = count(obj)
            % count - number of documents.
            row = mksqlite(obj.dbid, 'SELECT COUNT(*) AS n FROM documents');
            n = double(row(1).n);
        end

        function docs = search(obj, q)
            % search - return the documents matching a did2.query.
            arguments
                obj
                q (1,1) did2.query
            end
            [whereSQL, params] = did2.database.compileQuery(q, ...
                'QueryablePaths', obj.queryableScalarPaths, ...
                'QueryableArrayPaths', obj.queryableArrayPathDefs);
            sql = ['SELECT id, body FROM documents WHERE ' whereSQL ...
                ' ORDER BY rowid ASC'];
            rows = mksqlite(obj.dbid, sql, params{:});
            docs = obj.rowsToDocs(rows, q);
        end

        function ids = searchIds(obj, q)
            % searchIds - return the ids of documents matching a query.
            arguments
                obj
                q (1,1) did2.query
            end
            docs = obj.search(q);
            ids = cell(1, numel(docs));
            for k = 1:numel(docs)
                ids{k} = docs{k}.get('base.id');
            end
        end
    end

    % ---- test-only hooks ----
    methods (Hidden)
        function id = testHookDbId(obj)
            % testHookDbId - return the underlying mksqlite dbid.
            %   Hidden helper for the +did2.unittest suite; lets tests
            %   inspect generated columns and table schema directly
            %   without round-tripping through public methods. Not part
            %   of the public API.
            id = obj.dbid;
        end

        function cols = testHookQueryableColumns(obj)
            % testHookQueryableColumns - cellstr of the q_<flat>
            %   generated-column names this instance expects on the
            %   documents table. Hidden helper for unit tests.
            cols = {obj.queryableScalarColumns.column};
        end

        function paths = testHookQueryableArrayPaths(obj)
            % testHookQueryableArrayPaths - cellstr of the '[*]'-bearing
            %   sidecar paths this instance expects in queryable_array_elem.
            %   Hidden helper for unit tests.
            paths = obj.queryableArrayPaths;
        end
    end

    % ---- schema bootstrap ----
    methods (Access = private)
        function bootstrapQueryableColumns(obj)
            % Resolve the schema cache and snapshot the queryable scalar
            % and array-iteration paths once per instance. Failures
            % (missing schema dir, cache errors) degrade gracefully:
            % queryableBootstrapOk stays false, the JSON1 fallback path
            % stays in effect, and the reconcile* methods become no-ops
            % (so we don't strip a healthy DB's q_* columns or sidecar
            % rows on a host that temporarily lacks the schema dir).
            obj.queryableScalarColumns = obj.emptyColumnStruct();
            obj.queryableScalarPaths = {};
            obj.queryableArrayPathDefs = obj.emptyArrayPathStruct();
            obj.queryableArrayPaths = {};
            obj.queryableBootstrapOk = false;
            try
                cache = obj.resolveSchemaCache();
                cache.loadAllSchemas();
                info = cache.queryablePaths();
            catch
                return;
            end
            if isempty(info) || ~isstruct(info)
                return;
            end
            if isfield(info, 'scalar') && ~isempty(info.scalar)
                % Sort deterministically by `column` so the CREATE
                % TABLE, reconciliation, and tests all see the same
                % order.
                scalar = info.scalar;
                cols = {scalar.column};
                [~, order] = sort(cols);
                scalar = scalar(order);
                obj.queryableScalarColumns = scalar;
                obj.queryableScalarPaths = {scalar.path};
            end
            if isfield(info, 'array') && ~isempty(info.array)
                arrayDefs = info.array;
                [~, order] = sort({arrayDefs.path});
                arrayDefs = arrayDefs(order);
                obj.queryableArrayPathDefs = arrayDefs;
                obj.queryableArrayPaths = {arrayDefs.path};
            end
            obj.queryableBootstrapOk = true;
        end

        function createSchema(obj)
            mksqlite(obj.dbid, 'BEGIN');
            try
                mksqlite(obj.dbid, obj.documentsTableSQL());
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_classname ON documents(classname)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_session_id ON documents(session_id)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_datestamp ON documents(datestamp)');
                obj.createQueryableColumnIndexes();

                mksqlite(obj.dbid, [ ...
                    'CREATE TABLE superclasses (' ...
                    'doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,' ...
                    'classname TEXT NOT NULL,' ...
                    'PRIMARY KEY (doc_id, classname))']);
                mksqlite(obj.dbid, ...
                    'CREATE INDEX superclasses_classname ON superclasses(classname)');

                mksqlite(obj.dbid, [ ...
                    'CREATE TABLE depends_on (' ...
                    'doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,' ...
                    'name TEXT NOT NULL,' ...
                    'document_id TEXT NOT NULL,' ...
                    'PRIMARY KEY (doc_id, name))']);
                mksqlite(obj.dbid, ...
                    'CREATE INDEX depends_on_name_document_id ON depends_on(name, document_id)');

                mksqlite(obj.dbid, [ ...
                    'CREATE TABLE queryable_array_elem (' ...
                    'doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,' ...
                    'path TEXT NOT NULL,' ...
                    'elem_index INTEGER NOT NULL,' ...
                    'value_text TEXT,' ...
                    'value_num REAL)']);
                mksqlite(obj.dbid, ...
                    'CREATE INDEX qae_path_text ON queryable_array_elem(path, value_text)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX qae_path_num ON queryable_array_elem(path, value_num)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX qae_doc_id ON queryable_array_elem(doc_id)');

                mksqlite(obj.dbid, [ ...
                    'CREATE TABLE meta (' ...
                    'key TEXT PRIMARY KEY, value TEXT NOT NULL)']);
                mksqlite(obj.dbid, ...
                    'INSERT INTO meta(key, value) VALUES(?, ?)', ...
                    'schema_version', num2str(obj.SchemaVersion));
                mksqlite(obj.dbid, ...
                    'INSERT INTO meta(key, value) VALUES(?, ?)', ...
                    'schema_generation', 'V_delta');
                mksqlite(obj.dbid, ...
                    'INSERT INTO meta(key, value) VALUES(?, ?)', ...
                    'queryable_array_paths', ...
                    did2.database.sqlitedb.serialisePathSet(obj.queryableArrayPaths));

                mksqlite(obj.dbid, 'COMMIT');
            catch err
                try mksqlite(obj.dbid, 'ROLLBACK'); catch, end
                error('did2:database:createFailed', ...
                    'Failed to create v2 SQLite schema: %s', err.message);
            end
        end

        function reconcileQueryableColumns(obj)
            % Compare the currently-installed `q_*` columns on documents
            % to the desired set. If they differ, rebuild the documents
            % table by table-swap. Bodies are preserved verbatim; the
            % generated columns repopulate themselves from json_extract.
            % Skipped when bootstrap degraded — see bootstrapQueryableColumns.
            if ~obj.queryableBootstrapOk
                return;
            end
            desired = sort({obj.queryableScalarColumns.column});
            current = obj.currentQueryableColumns();
            if isequal(sort(current(:)'), desired(:)')
                return;
            end
            obj.rebuildDocumentsTable();
        end

        function names = currentQueryableColumns(obj)
            % Probe each expected generated column with a zero-row SELECT
            % and collect the ones that succeed. We previously walked
            % `pragma_table_info('documents')` but the mksqlite + sqlite
            % combo on CI was returning rows whose `.name` field didn't
            % round-trip cleanly through ismember even though
            % `SELECT q_base_name FROM documents` (and the column itself)
            % worked fine. Probing the columns directly avoids that
            % layer entirely. Returns the subset of the expected columns
            % that currently exist on the table.
            names = {};
            for k = 1:numel(obj.queryableScalarColumns)
                col = obj.queryableScalarColumns(k);
                sql = sprintf('SELECT %s FROM documents LIMIT 0', col.column);
                try
                    mksqlite(obj.dbid, sql);
                    names{end+1} = col.column; %#ok<AGROW>
                catch
                    % column does not exist on this table.
                end
            end
        end

        function rebuildDocumentsTable(obj)
            % Table-swap: build documents_new with the current generated
            % columns, copy the canonical columns over, drop the old
            % table, rename. Indexes on classname/session_id/datestamp
            % and every q_* column are recreated against the new table.
            %
            % Foreign keys must be disabled outside the transaction —
            % the superclasses and depends_on tables reference
            % documents(id), and DROP TABLE documents would fault on FK
            % enforcement otherwise. The recommended SQLite pattern
            % (https://www.sqlite.org/lang_altertable.html section 7).
            mksqlite(obj.dbid, 'PRAGMA foreign_keys = OFF');
            mksqlite(obj.dbid, 'BEGIN IMMEDIATE');
            try
                % SQLite doesn't allow renaming TABLE references inside
                % the existing index DDL; we just drop and re-create.
                obj.dropQueryableColumnIndexes();
                mksqlite(obj.dbid, ...
                    'DROP INDEX IF EXISTS documents_classname');
                mksqlite(obj.dbid, ...
                    'DROP INDEX IF EXISTS documents_session_id');
                mksqlite(obj.dbid, ...
                    'DROP INDEX IF EXISTS documents_datestamp');

                mksqlite(obj.dbid, ...
                    strrep(obj.documentsTableSQL(), ...
                           'CREATE TABLE documents (', ...
                           'CREATE TABLE documents_new ('));
                mksqlite(obj.dbid, [ ...
                    'INSERT INTO documents_new(id, classname, class_version, ' ...
                    'session_id, datestamp, body, body_hash) ' ...
                    'SELECT id, classname, class_version, session_id, ' ...
                    'datestamp, body, body_hash FROM documents']);
                mksqlite(obj.dbid, 'DROP TABLE documents');
                mksqlite(obj.dbid, ...
                    'ALTER TABLE documents_new RENAME TO documents');

                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_classname ON documents(classname)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_session_id ON documents(session_id)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_datestamp ON documents(datestamp)');
                obj.createQueryableColumnIndexes();

                mksqlite(obj.dbid, 'COMMIT');
            catch err
                try mksqlite(obj.dbid, 'ROLLBACK'); catch, end
                mksqlite(obj.dbid, 'PRAGMA foreign_keys = ON');
                error('did2:database:rebuildFailed', ...
                    'Failed to rebuild documents table: %s', err.message);
            end
            mksqlite(obj.dbid, 'PRAGMA foreign_keys = ON');
        end

        function sql = documentsTableSQL(obj)
            % Compose the CREATE TABLE documents (...) statement,
            % appending one `q_<flat> <affinity> GENERATED ALWAYS AS
            % (json_extract(body, '$.<path>')) STORED` clause per
            % queryable scalar path.
            base = ['CREATE TABLE documents (' ...
                'id TEXT PRIMARY KEY,' ...
                'classname TEXT NOT NULL,' ...
                'class_version TEXT NOT NULL,' ...
                'session_id TEXT,' ...
                'datestamp TEXT NOT NULL,' ...
                'body TEXT NOT NULL,' ...
                'body_hash TEXT NOT NULL'];
            for k = 1:numel(obj.queryableScalarColumns)
                col = obj.queryableScalarColumns(k);
                affinity = col.affinity;
                if isempty(affinity)
                    affinityClause = '';
                else
                    affinityClause = [' ' affinity];
                end
                base = [base sprintf( ...
                    [',%s%s GENERATED ALWAYS AS ' ...
                     '(json_extract(body, ''$.%s'')) STORED'], ...
                    col.column, affinityClause, col.path)]; %#ok<AGROW>
            end
            sql = [base ')'];
        end

        function createQueryableColumnIndexes(obj)
            for k = 1:numel(obj.queryableScalarColumns)
                col = obj.queryableScalarColumns(k);
                mksqlite(obj.dbid, sprintf( ...
                    'CREATE INDEX documents_%s ON documents(%s)', ...
                    col.column, col.column));
            end
        end

        function dropQueryableColumnIndexes(obj)
            for k = 1:numel(obj.queryableScalarColumns)
                col = obj.queryableScalarColumns(k);
                mksqlite(obj.dbid, sprintf( ...
                    'DROP INDEX IF EXISTS documents_%s', col.column));
            end
        end

        function s = emptyColumnStruct(~)
            s = struct('path', {}, 'declaringClass', {}, ...
                'fieldName', {}, 'type', {}, ...
                'column', {}, 'affinity', {});
        end

        function s = emptyArrayPathStruct(~)
            s = struct('path', {}, 'declaringClass', {}, ...
                'parentField', {}, 'parentPath', {}, ...
                'subField', {}, 'type', {}, 'affinity', {});
        end

        function reconcileQueryableArrayPaths(obj)
            % Compare the configured queryable array-iteration path set
            % to the snapshot recorded in the meta table. If they
            % differ, drop every queryable_array_elem row and rebuild
            % from the stored document bodies. Skipped when bootstrap
            % degraded so a host that temporarily lacks the schema
            % directory doesn't strip a healthy sidecar.
            if ~obj.queryableBootstrapOk
                return;
            end
            obj.ensureSidecarTable();
            stored = obj.readArrayPathsMeta();
            desired = obj.queryableArrayPaths;
            if isequal(sort(stored), sort(desired))
                return;
            end
            obj.repopulateSidecarFromBodies();
            obj.writeArrayPathsMeta();
        end

        function ensureSidecarTable(obj)
            % Create the queryable_array_elem table if it isn't present
            % yet. Used when reopening a database that was created
            % before step 5 landed (no sidecar at create time).
            try
                mksqlite(obj.dbid, ...
                    'SELECT 1 FROM queryable_array_elem LIMIT 0');
                return;
            catch
            end
            mksqlite(obj.dbid, [ ...
                'CREATE TABLE queryable_array_elem (' ...
                'doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,' ...
                'path TEXT NOT NULL,' ...
                'elem_index INTEGER NOT NULL,' ...
                'value_text TEXT,' ...
                'value_num REAL)']);
            mksqlite(obj.dbid, ...
                'CREATE INDEX qae_path_text ON queryable_array_elem(path, value_text)');
            mksqlite(obj.dbid, ...
                'CREATE INDEX qae_path_num ON queryable_array_elem(path, value_num)');
            mksqlite(obj.dbid, ...
                'CREATE INDEX qae_doc_id ON queryable_array_elem(doc_id)');
        end

        function paths = readArrayPathsMeta(obj)
            paths = {};
            try
                row = mksqlite(obj.dbid, ...
                    'SELECT value FROM meta WHERE key = ?', ...
                    'queryable_array_paths');
            catch
                return;
            end
            if isempty(row) || isempty(row(1).value)
                return;
            end
            paths = did2.database.sqlitedb.deserialisePathSet(row(1).value);
        end

        function writeArrayPathsMeta(obj)
            encoded = did2.database.sqlitedb.serialisePathSet(obj.queryableArrayPaths);
            mksqlite(obj.dbid, ...
                'INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)', ...
                'queryable_array_paths', encoded);
        end

        function repopulateSidecarFromBodies(obj)
            % Drop every sidecar row and rebuild from the stored
            % document bodies under the currently-configured array
            % path set. O(numDocuments * numArrayPaths * elemsPerArray);
            % acceptable while DBs are small (see PLAN.md Decision 9).
            mksqlite(obj.dbid, 'BEGIN IMMEDIATE');
            try
                mksqlite(obj.dbid, 'DELETE FROM queryable_array_elem');
                if isempty(obj.queryableArrayPathDefs)
                    mksqlite(obj.dbid, 'COMMIT');
                    return;
                end
                rows = mksqlite(obj.dbid, ...
                    'SELECT id, body FROM documents ORDER BY rowid ASC');
                for k = 1:numel(rows)
                    docStruct = jsondecode(rows(k).body);
                    obj.insertSidecarRowsFromStruct(rows(k).id, docStruct);
                end
                mksqlite(obj.dbid, 'COMMIT');
            catch err
                try mksqlite(obj.dbid, 'ROLLBACK'); catch, end
                rethrow(err);
            end
        end

        function insertSidecarRowsFromStruct(obj, docId, s)
            % Walk every configured queryable array path and INSERT one
            % row per array element into queryable_array_elem.
            for k = 1:numel(obj.queryableArrayPathDefs)
                def = obj.queryableArrayPathDefs(k);
                elems = obj.resolveParentArray(s, def.parentPath);
                for idx = 1:numel(elems)
                    elem = obj.elementAt(elems, idx);
                    if ~isstruct(elem) || ~isfield(elem, def.subField)
                        continue;
                    end
                    value = elem.(def.subField);
                    if obj.isEmptyLeaf(value)
                        continue;
                    end
                    [textValue, numValue] = obj.coerceLeafValue(value, def.affinity);
                    mksqlite(obj.dbid, ...
                        ['INSERT INTO queryable_array_elem' ...
                         '(doc_id, path, elem_index, value_text, value_num) ' ...
                         'VALUES(?, ?, ?, ?, ?)'], ...
                        docId, def.path, idx, textValue, numValue);
                end
            end
        end

        function elems = resolveParentArray(~, s, parentPath)
            % Navigate a dot-path with no [*] segments down to the value
            % stored at parentPath. Returns a struct array, cell array
            % of structs, or [] if the path is unresolvable.
            elems = [];
            if isempty(parentPath)
                return;
            end
            parts = strsplit(parentPath, '.');
            cursor = s;
            for k = 1:numel(parts)
                if ~isstruct(cursor) || ~isscalar(cursor) ...
                        || ~isfield(cursor, parts{k})
                    return;
                end
                cursor = cursor.(parts{k});
            end
            elems = cursor;
        end

        function elem = elementAt(~, container, idx)
            if iscell(container)
                elem = container{idx};
            elseif isstruct(container)
                elem = container(idx);
            else
                elem = [];
            end
        end

        function tf = isEmptyLeaf(~, value)
            if isstring(value)
                tf = isscalar(value) && strlength(value) == 0;
            elseif ischar(value)
                tf = isempty(value);
            else
                tf = isempty(value);
            end
        end

        function [textValue, numValue] = coerceLeafValue(~, value, affinity)
            textValue = [];
            numValue = [];
            switch affinity
                case 'TEXT'
                    if ischar(value)
                        textValue = value;
                    elseif isstring(value) && isscalar(value)
                        textValue = char(value);
                    else
                        textValue = jsonencode(value);
                    end
                case {'REAL', 'INTEGER'}
                    if isnumeric(value) && isscalar(value)
                        numValue = double(value);
                    elseif islogical(value) && isscalar(value)
                        numValue = double(value);
                    end
                otherwise
                    if ischar(value) || (isstring(value) && isscalar(value))
                        textValue = char(value);
                    elseif isnumeric(value) && isscalar(value)
                        numValue = double(value);
                    end
            end
        end

        function assertSchema(obj)
            try
                row = mksqlite(obj.dbid, ...
                    'SELECT value FROM meta WHERE key = ?', 'schema_generation');
            catch
                error('did2:database:notV2Database', ...
                    '%s is not a v2 SQLite database (missing meta table).', ...
                    obj.filename);
            end
            if isempty(row) || ~strcmp(row(1).value, 'V_delta')
                error('did2:database:notV2Database', ...
                    '%s is not a V_delta database.', obj.filename);
            end
            obj.migrateDependsOnValueToDocumentId();
        end

        function migrateDependsOnValueToDocumentId(obj)
            % migrateDependsOnValueToDocumentId - rename the legacy
            % `value` column on the `depends_on` sidecar to
            % `document_id` (see did-schema#52). One-shot migration:
            % if the old column name is still present, ALTER TABLE
            % RENAME COLUMN + rebuild the index. Idempotent on
            % already-migrated databases.
            %
            % We probe column existence with zero-row SELECTs rather
            % than pragma_table_info -- the same workaround
            % currentQueryableColumns() uses, for the same reason
            % (the mksqlite + sqlite combo on CI returns rows whose
            % `.name` doesn't round-trip cleanly through ismember).
            hasDocId = obj.dependsOnHasColumn('document_id');
            if hasDocId
                return;
            end
            hasValue = obj.dependsOnHasColumn('value');
            if ~hasValue
                return;
            end
            mksqlite(obj.dbid, 'BEGIN');
            try
                mksqlite(obj.dbid, ...
                    'DROP INDEX IF EXISTS depends_on_name_value');
                mksqlite(obj.dbid, ...
                    'ALTER TABLE depends_on RENAME COLUMN value TO document_id');
                mksqlite(obj.dbid, ...
                    ['CREATE INDEX IF NOT EXISTS depends_on_name_document_id ' ...
                     'ON depends_on(name, document_id)']);
                mksqlite(obj.dbid, 'COMMIT');
            catch err
                mksqlite(obj.dbid, 'ROLLBACK');
                rethrow(err);
            end
        end

        function tf = dependsOnHasColumn(obj, columnName)
            % Probe the depends_on sidecar for a given column name
            % via a zero-row SELECT. Returns true iff the column
            % exists (the SELECT does not raise).
            sql = sprintf('SELECT %s FROM depends_on LIMIT 0', columnName);
            try
                mksqlite(obj.dbid, sql);
                tf = true;
            catch
                tf = false;
            end
        end

        function addOne(obj, doc, doValidate)
            if doValidate
                doc.validate('SchemaCache', obj.resolveSchemaCache());
            end
            s = doc.toStruct();
            id = obj.requireField(s, 'base', 'id');
            classname = obj.requireDocumentClassField(s, 'class_name');
            classVersion = obj.requireDocumentClassField(s, 'class_version');
            sessionId = obj.optionalField(s, 'base', 'session_id');
            datestamp = obj.requireField(s, 'base', 'datestamp');
            bodyText = doc.toJSON();
            bodyHash = did2.database.sqlitedb.computeHash(bodyText);

            mksqlite(obj.dbid, 'BEGIN');
            try
                mksqlite(obj.dbid, ...
                    ['INSERT INTO documents(id, classname, class_version, ' ...
                     'session_id, datestamp, body, body_hash) ' ...
                     'VALUES(?, ?, ?, ?, ?, ?, ?)'], ...
                    id, classname, classVersion, sessionId, datestamp, ...
                    bodyText, bodyHash);

                chain = obj.classChainFromStruct(s);
                for k = 1:numel(chain)
                    mksqlite(obj.dbid, ...
                        'INSERT INTO superclasses(doc_id, classname) VALUES(?, ?)', ...
                        id, chain{k});
                end

                deps = obj.dependsOnEntries(s);
                for k = 1:numel(deps)
                    mksqlite(obj.dbid, ...
                        'INSERT INTO depends_on(doc_id, name, document_id) VALUES(?, ?, ?)', ...
                        id, deps{k}.name, deps{k}.document_id);
                end

                obj.insertSidecarRowsFromStruct(id, s);

                mksqlite(obj.dbid, 'COMMIT');
            catch err
                try mksqlite(obj.dbid, 'ROLLBACK'); catch, end
                rethrow(err);
            end
        end

        function cache = resolveSchemaCache(obj)
            if ~isempty(obj.schemaCache)
                cache = obj.schemaCache;
                return;
            end
            cache = did2.schema.cache.shared();
        end

        function list = normaliseDocList(~, docOrList)
            if isa(docOrList, 'did2.document')
                list = arrayfun(@(i) docOrList(i), 1:numel(docOrList), ...
                    'UniformOutput', false);
                return;
            end
            if iscell(docOrList)
                list = docOrList(:)';
                return;
            end
            error('did2:database:badInput', ...
                'add() expects a did2.document or a cell array of did2.document.');
        end

        function id = coerceId(~, target)
            if ischar(target)
                id = target;
            elseif isstring(target) && isscalar(target)
                id = char(target);
            elseif isa(target, 'did2.document')
                id = char(target.get('base.id'));
            else
                error('did2:database:badInput', ...
                    'Expected a document id (char) or a did2.document; got %s.', ...
                    class(target));
            end
        end

        function docs = rowsToDocs(~, rows, q)
            n = numel(rows);
            docs = {};
            for k = 1:n
                d = did2.document.fromJSON(rows(k).body);
                if q.matches(d)
                    docs{end+1} = d; %#ok<AGROW>
                end
            end
        end

        function out = rowsToCellstr(~, rows, fieldName)
            n = numel(rows);
            out = cell(1, n);
            for k = 1:n
                v = rows(k).(fieldName);
                if isempty(v)
                    out{k} = '';
                else
                    out{k} = char(v);
                end
            end
        end

        function value = requireField(~, s, blockName, fieldName)
            if ~isfield(s, blockName) || ~isstruct(s.(blockName)) ...
                    || ~isfield(s.(blockName), fieldName) ...
                    || isempty(s.(blockName).(fieldName))
                error('did2:database:missingField', ...
                    'Document is missing required field "%s.%s".', ...
                    blockName, fieldName);
            end
            value = char(s.(blockName).(fieldName));
        end

        function value = optionalField(~, s, blockName, fieldName)
            value = '';
            if isfield(s, blockName) && isstruct(s.(blockName)) ...
                    && isfield(s.(blockName), fieldName) ...
                    && ~isempty(s.(blockName).(fieldName))
                value = char(s.(blockName).(fieldName));
            end
        end

        function value = requireDocumentClassField(~, s, fieldName)
            if ~isfield(s, 'document_class') ...
                    || ~isstruct(s.document_class) ...
                    || ~isfield(s.document_class, fieldName) ...
                    || isempty(s.document_class.(fieldName))
                error('did2:database:missingField', ...
                    'Document is missing required field "document_class.%s".', ...
                    fieldName);
            end
            value = char(s.document_class.(fieldName));
        end

        function chain = classChainFromStruct(~, s)
            % Concrete classname plus every superclass in document_class.
            chain = {char(s.document_class.class_name)};
            if ~isfield(s.document_class, 'superclasses') ...
                    || isempty(s.document_class.superclasses)
                return;
            end
            sc = s.document_class.superclasses;
            for k = 1:numel(sc)
                if isstruct(sc)
                    entry = sc(k);
                elseif iscell(sc)
                    entry = sc{k};
                else
                    continue;
                end
                if isstruct(entry) && isfield(entry, 'class_name') ...
                        && ~isempty(entry.class_name)
                    chain{end+1} = char(entry.class_name); %#ok<AGROW>
                end
            end
        end

        function entries = dependsOnEntries(~, s)
            entries = {};
            if ~isfield(s, 'depends_on') || isempty(s.depends_on)
                return;
            end
            d = s.depends_on;
            for k = 1:numel(d)
                if isstruct(d)
                    e = d(k);
                elseif iscell(d)
                    e = d{k};
                else
                    continue;
                end
                if ~isstruct(e) || ~isfield(e, 'name')
                    continue;
                end
                % V_delta uses `document_id`; tolerate the earlier
                % `value` draft and the raw v1 `id` so mid-migration
                % bodies still write their sidecar rows.
                if isfield(e, 'document_id')
                    documentId = char(e.document_id);
                elseif isfield(e, 'value')
                    documentId = char(e.value);
                elseif isfield(e, 'id')
                    documentId = char(e.id);
                else
                    continue;
                end
                if isempty(e.name) || isempty(documentId)
                    continue;
                end
                entries{end+1} = struct('name', char(e.name), ...
                    'document_id', documentId); %#ok<AGROW>
            end
        end
    end

    methods (Static, Access = private)
        function out = serialisePathSet(paths)
            % Encode a cellstr path set as a newline-delimited string.
            % Newline-joining sidesteps the jsondecode-shape variability
            % (string array vs char matrix vs cell array) that JSON
            % would otherwise introduce; queryable paths never contain
            % newlines themselves. The empty set is stored as the
            % literal '<none>' sentinel so the meta column's NOT NULL
            % constraint doesn't trip on a binding-as-NULL of MATLAB ''.
            if isempty(paths)
                out = '<none>';
                return;
            end
            out = strjoin(paths(:)', char(10));
        end

        function paths = deserialisePathSet(text)
            paths = {};
            if isempty(text)
                return;
            end
            text = char(text);
            if strcmp(text, '<none>')
                return;
            end
            parts = strsplit(text, char(10));
            paths = parts(~cellfun('isempty', parts));
        end

        function out = computeHash(text)
            % Lightweight, dependency-free content hash for body_hash.
            try
                md = java.security.MessageDigest.getInstance('SHA-256');
                bytes = md.digest(uint8(text));
                hex = lower(reshape(dec2hex(typecast(bytes, 'uint8'), 2).', 1, []));
                out = char(hex);
            catch
                out = sprintf('len-%d', numel(text));
            end
        end
    end
end
