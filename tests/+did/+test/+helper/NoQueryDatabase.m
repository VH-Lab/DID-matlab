classdef NoQueryDatabase < did.database
    % NOQUERYDATABASE - a did.database in which EVERY database operation errors
    %
    % Used to prove that did.database/cachedPathForFile reaches none of them.
    %
    % A test that merely times cachedPathForFile, or that counts queries by
    % inspection, would still pass if the code path quietly acquired a
    % connection. This stub cannot: every abstract operation raises, so if
    % cachedPathForFile touches the database at all the test fails with
    % DID:Test:NoQueryDatabase:Used naming the method it reached.
    %
    % That property is the point of the fast path, not a side benefit. A
    % SQLite connection belongs to the thread that opened it, so a resolution
    % that reaches the database cannot run on a worker thread; one that does
    % not, can.

    properties
        pathRoots (1,:) cell = {} % returned by do_cachedPathRoots
    end

    methods
        function obj = NoQueryDatabase(pathRoots)
            arguments
                pathRoots (1,:) cell = {}
            end
            obj@did.database('');
            obj.pathRoots = pathRoots;
        end
    end

    methods (Access=protected)

        function roots = do_cachedPathRoots(obj)
            roots = obj.pathRoots;
        end

        function results = do_run_sql_query(obj, query_str, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_run_sql_query');
        end

        function branch_ids = do_get_branch_ids(obj) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_get_branch_ids');
        end

        function do_add_branch(obj, branch_id, parent_branch_id, varargin) %#ok<INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_add_branch');
        end

        function do_delete_branch(obj, branch_id, varargin) %#ok<INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_delete_branch');
        end

        function parent_branch_id = do_get_branch_parent(obj, branch_id, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_get_branch_parent');
        end

        function branch_ids = do_get_sub_branches(obj, branch_id, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_get_sub_branches');
        end

        function doc_ids = do_get_doc_ids(obj, branch_id, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_get_doc_ids');
        end

        function do_add_doc(obj, document_obj, branch_id, options) %#ok<INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_add_doc');
        end

        function document_obj = do_get_doc(obj, document_id, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_get_doc');
        end

        function do_remove_doc(obj, document_id, branch_id, varargin) %#ok<INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_remove_doc');
        end

        function file_obj = do_open_doc(obj, document_id, filename, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('do_open_doc');
        end

        function [tf, file_path] = check_exist_doc(obj, document_id, filename, varargin) %#ok<STOUT,INUSD>
            did.test.helper.NoQueryDatabase.refuse('check_exist_doc');
        end

    end

    methods (Static, Access=private)
        function refuse(methodName)
            error('DID:Test:NoQueryDatabase:Used', ...
                ['NoQueryDatabase.%s was called. cachedPathForFile must ' ...
                 'resolve from the in-memory document and the filesystem ' ...
                 'alone, without reaching the database.'], methodName);
        end
    end
end
