classdef NoQueryDatabaseWithRoots < did.test.helper.NoQueryDatabase
    % NOQUERYDATABASEWITHROOTS - NoQueryDatabase that also declares file roots
    %
    % Splitting this from did.test.helper.NoQueryDatabase is what lets both
    % halves of do_cachedPathRoots be exercised: the parent inherits
    % did.database's default (the empty list, which is what keeps sqldb and
    % matlabdumbjsondb working unchanged), and this one overrides it the way
    % did.implementations.sqlitedb does.

    properties
        pathRoots (1,:) cell = {} % returned by do_cachedPathRoots
    end

    methods
        function obj = NoQueryDatabaseWithRoots(pathRoots)
            arguments
                pathRoots (1,:) cell = {}
            end
            obj@did.test.helper.NoQueryDatabase();
            obj.pathRoots = pathRoots;
        end
    end

    methods (Access=protected)
        function roots = do_cachedPathRoots(obj)
            roots = obj.pathRoots;
        end
    end
end
