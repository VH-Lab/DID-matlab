function ResultTable = tableCrossJoin(Table1, Table2, options)
% TABLECROSSJOIN Performs a Cartesian product (SQL-style CROSS JOIN) of two tables.
%
% ResultTable = tableCrossJoin(Table1, Table2)
% ResultTable = tableCrossJoin(Table1, Table2, 'renameConflictingColumns', trueOrFalse)
%
%   This function returns a new table ResultTable that contains all
%   combinations of rows from Table1 and Table2. This is analogous to a
%   SQL CROSS JOIN.
%
%   By default, if Table1 and Table2 have common variable (column) names,
%   this function will throw an error with ID 'did:db:tableCrossJoin:ConflictingColumnNames'.
%
%   Optional Name-Value Arguments:
%       'renameConflictingColumns' - logical scalar (default false)
%           If true, conflicting variable names from Table2 will be
%           automatically renamed by appending a numeric suffix (e.g.,
%           'VarName1') to ensure uniqueness. Uses matlab.lang.makeUniqueStrings.
%           If false (default), an error is thrown if conflicting names exist.
%
%   The number of rows in ResultTable will be height(Table1) * height(Table2).
%   The columns of ResultTable will be all columns of Table1 followed by all
%   columns of Table2 (potentially renamed if 'renameConflictingColumns' is true).
%
%   Inputs:
%       Table1 - The first MATLAB table.
%       Table2 - The second MATLAB table.
%
%   Output:
%       ResultTable - A MATLAB table representing the Cartesian product.
%
%   Example (Error by default):
%       T1 = table({'a'}, 'VariableNames', {'ID'});
%       T2 = table({'x'}, 'VariableNames', {'ID'}); % 'ID' conflicts
%       try
%           T_cross = did.db.tableCrossJoin(T1, T2);
%       catch ME
%           fprintf('Caught expected error: %s (%s)\n', ME.message, ME.identifier);
%       end
%
%   Example (Rename option):
%       T1 = table({'a'}, 'VariableNames', {'ID'});
%       T2 = table({'x'}, 'VariableNames', {'ID'});
%       T_cross_renamed = did.db.tableCrossJoin(T1, T2, 'renameConflictingColumns', true);
%       disp('T_cross_renamed variable names:');
%       disp(T_cross_renamed.Properties.VariableNames); % Expected: {'ID'; 'ID1'} (or similar)
%
%   See also repelem, repmat, table, height, horzcat, arguments, matlab.lang.makeUniqueStrings, intersect, strjoin.

    arguments
        Table1 table
        Table2 table
        options.renameConflictingColumns (1,1) logical = false % Default to false
    end

    varNamesT1_orig = Table1.Properties.VariableNames;
    varNamesT2_orig = Table2.Properties.VariableNames;

    % Ensure cell arrays for intersect and makeUniqueStrings
    cellVarNamesT1 = cellstr(varNamesT1_orig);
    cellVarNamesT2 = cellstr(varNamesT2_orig);

    conflictingNames = intersect(cellVarNamesT1, cellVarNamesT2);

    if ~isempty(conflictingNames) && ~options.renameConflictingColumns
        conflictingNamesStr = strjoin(conflictingNames, ', ');
        error('did:db:tableCrossJoin:ConflictingColumnNames', ...
              'Input tables have conflicting column names: %s. Set the ''renameConflictingColumns'' option to true to automatically rename them.', conflictingNamesStr);
    end

    % Proceed with join logic
    numRows1 = height(Table1);
    numRows2 = height(Table2);

    if numRows1 == 0 || numRows2 == 0
        emptyShellT1 = Table1(1:0, :);
        emptyShellT2 = Table2(1:0, :); % Shell of Table2 with original names

        if ~isempty(conflictingNames) && options.renameConflictingColumns
            % This implies conflicts exist AND renaming is requested.
            % Only rename if both shells actually have columns to avoid
            % errors with .Properties.VariableNames on truly 0x0 tables.
            if width(emptyShellT1) > 0 && width(emptyShellT2) > 0
                varNames1_shell = emptyShellT1.Properties.VariableNames;
                varNames2_shell_original = emptyShellT2.Properties.VariableNames;
                
                varNames2_shell_modified = matlab.lang.makeUniqueStrings(...
                    cellstr(varNames2_shell_original), ...
                    cellstr(varNames1_shell), ...
                    namelengthmax);
                emptyShellT2.Properties.VariableNames = varNames2_shell_modified;
            end
        end
        ResultTable = [emptyShellT1, emptyShellT2];
        return;
    end

    idx1 = repelem((1:numRows1)', numRows2, 1);
    idx2 = repmat((1:numRows2)', numRows1, 1);

    Table1_Expanded = Table1(idx1, :);
    Table2_Repeated = Table2(idx2, :); % Still has original names from Table2

    if ~isempty(conflictingNames) && options.renameConflictingColumns
        % This implies conflicts exist AND renaming is requested.
        % varNamesT1_orig contains Table1's original (and thus expanded) names.
        varNames2_current_repeated = Table2_Repeated.Properties.VariableNames; % These are original Table2 names
        
        varNames2_modified = matlab.lang.makeUniqueStrings(...
            cellstr(varNames2_current_repeated), ...
            cellVarNamesT1, ... % Compare against original Table1 names for uniqueness context
            namelengthmax);
        Table2_Repeated.Properties.VariableNames = varNames2_modified;
    end
    
    ResultTable = [Table1_Expanded, Table2_Repeated];
end