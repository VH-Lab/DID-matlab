% TestTableCrossJoin.m
classdef TestTableCrossJoin < matlab.unittest.TestCase
    % TestTableCrossJoin tests the did.db.tableCrossJoin function.

    methods (Test)

        function testBasicValidInputs(testCase)
            % Test with two non-empty tables with multiple rows and columns, no conflicts.
            Table1 = table({'alpha'; 'beta'}, [101; 102], 'VariableNames', {'NameT1', 'IDT1'});
            Table2 = table(categorical({'X'; 'Y'; 'Z'}), [true; false; true], 'VariableNames', {'CategoryT2', 'FlagT2'});

            numRows1 = height(Table1);
            numRows2 = height(Table2);

            Exp_NameT1 = repelem(Table1.NameT1, numRows2, 1);
            Exp_IDT1 = repelem(Table1.IDT1, numRows2, 1);
            Exp_CategoryT2 = repmat(Table2.CategoryT2, numRows1, 1);
            Exp_FlagT2 = repmat(Table2.FlagT2, numRows1, 1);
            
            ExpectedResult = table(Exp_NameT1, Exp_IDT1, Exp_CategoryT2, Exp_FlagT2, ...
                'VariableNames', {'NameT1', 'IDT1', 'CategoryT2', 'FlagT2'});

            ActualResult = did.db.tableCrossJoin(Table1, Table2); % Default: renameConflictingColumns=false
            testCase.verifyEqual(ActualResult, ExpectedResult, ...
                'Basic valid inputs (no conflicts, default) failed.');
        end

        function testFirstTableEmpty(testCase)
            Table1_EmptyWithSchema = table('Size', [0, 2], ...
                                           'VariableTypes', {'string', 'double'}, ...
                                           'VariableNames', {'EmptyColA', 'EmptyColB'});
            Table2_Data = table(string({'X'; 'Y'}), [10; 20], 'VariableNames', {'DataColX', 'DataColY'});

            ExpectedSchemaTable1 = Table1_EmptyWithSchema(1:0,:);
            ExpectedSchemaTable2 = Table2_Data(1:0,:);
            ExpectedResultWithSchema = [ExpectedSchemaTable1, ExpectedSchemaTable2];
            
            ActualResultWithSchema = did.db.tableCrossJoin(Table1_EmptyWithSchema, Table2_Data);
            testCase.verifyEqual(ActualResultWithSchema, ExpectedResultWithSchema, ...
                'First table empty (with schema) did not produce an empty table with combined schema.');
        end

        function testSecondTableEmpty(testCase)
            Table1_Data = table(string({'A'; 'B'}), [1; 2], 'VariableNames', {'DataColA', 'DataColB'});
            Table2_EmptyWithSchema = table('Size', [0, 1], ...
                                           'VariableTypes', {'logical'}, ...
                                           'VariableNames', {'EmptyColX'});

            ExpectedSchemaTable1 = Table1_Data(1:0,:);
            ExpectedSchemaTable2 = Table2_EmptyWithSchema(1:0,:);
            ExpectedResultWithSchema = [ExpectedSchemaTable1, ExpectedSchemaTable2];

            ActualResultWithSchema = did.db.tableCrossJoin(Table1_Data, Table2_EmptyWithSchema);
            testCase.verifyEqual(ActualResultWithSchema, ExpectedResultWithSchema, ...
                'Second table empty (with schema) did not produce an empty table with combined schema.');
        end

        function testSingleRowInputs(testCase)
            Table1 = table(string("Alpha"), datetime(2025,5,6, 'TimeZone', 'America/New_York'), 'VariableNames', {'Text', 'Timestamp'});
            Table2 = table(duration(hours(2)), categorical({'Group1'}), 'VariableNames', {'TimeGap', 'Group'});

            ExpectedResult = table(string("Alpha"), datetime(2025,5,6, 'TimeZone', 'America/New_York'), ...
                                   duration(hours(2)), categorical({'Group1'}), ...
                                   'VariableNames', {'Text', 'Timestamp', 'TimeGap', 'Group'});
            
            ActualResult = did.db.tableCrossJoin(Table1, Table2);
            testCase.verifyEqual(ActualResult, ExpectedResult, ...
                'Single row input tables (no conflicts) failed.');
        end
        
        function testConflictingColumnNamesErrorDefault(testCase)
            % Test that an error is thrown by default for conflicting column names.
            Table1 = table("ID001", 10, 'VariableNames', {'ID', 'ValueT1'});
            Table2 = table(categorical("TypeA"), 1.5, 'VariableNames', {'ID', 'ValueT2'}); % Conflicting 'ID'
            
            % Verify that calling the function without the rename option throws the specific error
            testFcnDefault = @() did.db.tableCrossJoin(Table1, Table2);
            testCase.verifyError(testFcnDefault, 'did:db:tableCrossJoin:ConflictingColumnNames', ...
                'Function did not throw expected error for conflicting column names with default behavior.');
            
            % Also test explicitly with renameConflictingColumns = false
            testFcnFalse = @() did.db.tableCrossJoin(Table1, Table2, 'renameConflictingColumns', false);
            testCase.verifyError(testFcnFalse, 'did:db:tableCrossJoin:ConflictingColumnNames', ...
                 'Function did not throw expected error for conflicting column names when renameConflictingColumns is explicitly false.');
        end

        function testConflictingColumnNamesRenameTrue(testCase)
            % Test successful renaming when 'renameConflictingColumns' is true.
            Table1 = table(["ID001"; "ID002"], [10; 20], 'VariableNames', {'ID', 'ValueT1'});
            Table2 = table(categorical(["TypeA"; "TypeB"]), [1.5; 2.5], 'VariableNames', {'ID', 'ValueT2'}); % Conflicting 'ID'
            
            numRows1 = height(Table1);
            numRows2 = height(Table2);

            Exp_ID_T1 = repelem(Table1.ID, numRows2, 1);
            Exp_ValueT1 = repelem(Table1.ValueT1, numRows2, 1);
            Exp_ID_T2_original_data = repmat(Table2.ID, numRows1, 1); 
            Exp_ValueT2 = repmat(Table2.ValueT2, numRows1, 1);
            
            % Expect 'ID' from Table2 to be renamed to 'ID_1'
            % (This matches the observed behavior of makeUniqueStrings)
            ExpectedVariableNames = {'ID', 'ValueT1', 'ID_1', 'ValueT2'}; 
            
            ExpectedResult = table(Exp_ID_T1, Exp_ValueT1, Exp_ID_T2_original_data, Exp_ValueT2, ...
                'VariableNames', ExpectedVariableNames);

            ActualResult = did.db.tableCrossJoin(Table1, Table2, 'renameConflictingColumns', true);
            
            testCase.verifyEqual(ActualResult.Properties.VariableNames, ExpectedVariableNames, ...
                'Variable names not correctly renamed when renameConflictingColumns is true (e.g., expecting ID_1).');
            testCase.verifyEqual(ActualResult, ExpectedResult, ...
                'Table content incorrect after renaming conflicting columns.');
        end


        function testNoConflictingColumnNamesRenameTrue(testCase)
            % Test with no conflicting names, but rename option is true (should have no effect on names).
            Table1 = table({'alpha'}, [101], 'VariableNames', {'NameT1', 'IDT1'});
            Table2 = table(categorical({'X'}), [true], 'VariableNames', {'CategoryT2', 'FlagT2'});

            ExpectedResult = table({'alpha'}, [101], categorical({'X'}), [true], ...
                'VariableNames', {'NameT1', 'IDT1', 'CategoryT2', 'FlagT2'});

            ActualResult = did.db.tableCrossJoin(Table1, Table2, 'renameConflictingColumns', true);
            testCase.verifyEqual(ActualResult, ExpectedResult, ...
                'Cross join with no conflicting names (rename=true) failed or altered names unnecessarily.');
        end


    end % methods (Test)
end % classdef