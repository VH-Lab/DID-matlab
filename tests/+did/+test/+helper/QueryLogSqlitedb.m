classdef QueryLogSqlitedb < did.implementations.sqlitedb
    % QUERYLOGSQLITEDB - a sqlitedb that records the SQL queries it runs
    %
    % Used by did.unittest.TestSearchIndexes and did.unittest.TestBatchedOr
    % to check how a search is carried out, not just what it returns: every
    % query run through run_sql_query is appended to queryLog together with
    % the number of rows it returned.
    %
    %   noSearchIndexes - when true, hasSearchIndexes reports false, as
    %       for a database that lacks the doc_data search indexes and could
    %       not be given them (a read-only file). Searches then run as they
    %       did before those indexes existed.
    %   orBatchSize - when not empty, the most OR operands searched in one
    %       SQL query (see did.database/orBatchTerms); 1 searches every
    %       operand by a query of its own, as before batching.

    properties
        queryLog = struct('query',{},'rows',{})
        noSearchIndexes (1,1) logical = false
        orBatchSize double = []
    end

    methods
        function obj = QueryLogSqlitedb(filename)
            obj@did.implementations.sqlitedb(filename);
        end

        function clearQueryLog(obj)
            obj.queryLog = struct('query',{},'rows',{});
        end

        function tf = hasSearchIndexesFlag(obj)
            % The value of the protected searchIndexesReady property
            tf = obj.searchIndexesReady;
        end
    end

    methods (Access=protected)
        function data = do_run_sql_query(this_obj, query_str, varargin)
            data = do_run_sql_query@did.implementations.sqlitedb(this_obj, query_str, varargin{:});
            this_obj.queryLog(end+1) = struct('query', query_str, 'rows', numel(data));
        end

        function tf = hasSearchIndexes(this_obj)
            tf = ~this_obj.noSearchIndexes && ...
                hasSearchIndexes@did.implementations.sqlitedb(this_obj);
        end

        function n = orBatchTerms(this_obj)
            if isempty(this_obj.orBatchSize)
                n = orBatchTerms@did.implementations.sqlitedb(this_obj);
            else
                n = this_obj.orBatchSize;
            end
        end
    end
end
