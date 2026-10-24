classdef QueryLogSqlitedb < did.implementations.sqlitedb
    % QUERYLOGSQLITEDB - a sqlitedb that records the SQL queries it runs
    %
    % Used by did.unittest.TestBaseIdSearch to check how a search is carried
    % out, not just what it returns: every query run through run_sql_query
    % is appended to queryLog together with the number of rows it returned.
    %
    %   noCandidateSearch - when true, canSearchCandidates reports false, as
    %       for a database that lacks the doc_data (doc_idx,field_idx) index
    %       and could not be given it (a read-only file). Every search term
    %       is then searched over the whole branch.

    properties
        queryLog = struct('query',{},'rows',{})
        noCandidateSearch (1,1) logical = false
    end

    methods
        function obj = QueryLogSqlitedb(filename)
            obj@did.implementations.sqlitedb(filename);
        end

        function clearQueryLog(obj)
            obj.queryLog = struct('query',{},'rows',{});
        end

        function tf = hasSearchIndexFlag(obj)
            % The value of the protected hasSearchIndex property
            tf = obj.hasSearchIndex;
        end
    end

    methods (Access=protected)
        function data = do_run_sql_query(this_obj, query_str, varargin)
            data = do_run_sql_query@did.implementations.sqlitedb(this_obj, query_str, varargin{:});
            this_obj.queryLog(end+1) = struct('query', query_str, 'rows', numel(data));
        end

        function tf = canSearchCandidates(this_obj)
            tf = ~this_obj.noCandidateSearch && ...
                canSearchCandidates@did.implementations.sqlitedb(this_obj);
        end
    end
end
