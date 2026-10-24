classdef WriteFaultSqlitedb < did.implementations.sqlitedb
    % WRITEFAULTSQLITEDB - a sqlitedb that misbehaves at one point of a write
    %
    % Used by did.unittest.TestWriteTransactions to make a write operation
    % fail, or have its database file replaced, part-way through - which is
    % otherwise a matter of timing. Two hooks, both off by default:
    %
    %   onInsertInto / beforeInsert - just before the first INSERT into the
    %       named table, call beforeInsert(connection) once. A test passes a
    %       function that replaces or deletes the database file, as a sync
    %       client would while the write is open.
    %   failCommit - commitWrite raises DID:Test:CommitRefused instead of
    %       committing, so the operation leaves through its rollback.

    properties
        onInsertInto = ''
        beforeInsert = []
        failCommit (1,1) logical = false
    end

    methods
        function obj = WriteFaultSqlitedb(filename)
            obj@did.implementations.sqlitedb(filename);
        end
    end

    methods (Access=protected)
        function insert_into_table(this_obj, table_name, field_names, varargin)
            if ~isempty(this_obj.beforeInsert) && strcmp(table_name, this_obj.onInsertInto)
                action = this_obj.beforeInsert;
                this_obj.beforeInsert = [];  % once
                action(this_obj.connection);
            end
            insert_into_table@did.implementations.sqlitedb(this_obj, table_name, field_names, varargin{:});
        end

        function commitWrite(this_obj, hTx)
            if this_obj.failCommit && ~isempty(hTx)
                error('DID:Test:CommitRefused', 'commit refused by the test');
            end
            commitWrite@did.implementations.sqlitedb(this_obj, hTx);
        end
    end
end
