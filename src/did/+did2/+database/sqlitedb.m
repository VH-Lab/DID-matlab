classdef sqlitedb < handle
    % did2.database.sqlitedb  SQLite + JSON1 backend for V_gamma documents.
    %
    %   First database backend in the v2 line. Stores each document's full
    %   V_gamma JSON body in a single TEXT column on the `documents`
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
            isNew = ~isfile(filename);
            obj.dbid = mksqlite(0, 'open', filename);
            mksqlite(obj.dbid, 'pragma foreign_keys = ON');
            if isNew
                obj.createSchema();
            else
                obj.assertSchema();
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
            [whereSQL, params] = did2.database.compileQuery(q);
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

    % ---- schema bootstrap ----
    methods (Access = private)
        function createSchema(obj)
            mksqlite(obj.dbid, 'BEGIN');
            try
                mksqlite(obj.dbid, [ ...
                    'CREATE TABLE documents (' ...
                    'id TEXT PRIMARY KEY,' ...
                    'classname TEXT NOT NULL,' ...
                    'class_version TEXT NOT NULL,' ...
                    'session_id TEXT,' ...
                    'datestamp TEXT NOT NULL,' ...
                    'body TEXT NOT NULL,' ...
                    'body_hash TEXT NOT NULL)']);
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_classname ON documents(classname)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_session_id ON documents(session_id)');
                mksqlite(obj.dbid, ...
                    'CREATE INDEX documents_datestamp ON documents(datestamp)');

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
                    'value TEXT NOT NULL,' ...
                    'PRIMARY KEY (doc_id, name))']);
                mksqlite(obj.dbid, ...
                    'CREATE INDEX depends_on_name_value ON depends_on(name, value)');

                mksqlite(obj.dbid, [ ...
                    'CREATE TABLE meta (' ...
                    'key TEXT PRIMARY KEY, value TEXT NOT NULL)']);
                mksqlite(obj.dbid, ...
                    'INSERT INTO meta(key, value) VALUES(?, ?)', ...
                    'schema_version', num2str(obj.SchemaVersion));
                mksqlite(obj.dbid, ...
                    'INSERT INTO meta(key, value) VALUES(?, ?)', ...
                    'schema_generation', 'V_gamma');

                mksqlite(obj.dbid, 'COMMIT');
            catch err
                try mksqlite(obj.dbid, 'ROLLBACK'); catch, end
                error('did2:database:createFailed', ...
                    'Failed to create v2 SQLite schema: %s', err.message);
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
            if isempty(row) || ~strcmp(row(1).value, 'V_gamma')
                error('did2:database:notV2Database', ...
                    '%s is not a V_gamma database.', obj.filename);
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
                        'INSERT INTO depends_on(doc_id, name, value) VALUES(?, ?, ?)', ...
                        id, deps{k}.name, deps{k}.value);
                end

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
                if ~isstruct(e) || ~isfield(e, 'name') || ~isfield(e, 'value')
                    continue;
                end
                if isempty(e.name) || isempty(e.value)
                    continue;
                end
                entries{end+1} = struct('name', char(e.name), ...
                    'value', char(e.value)); %#ok<AGROW>
            end
        end
    end

    methods (Static, Access = private)
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
