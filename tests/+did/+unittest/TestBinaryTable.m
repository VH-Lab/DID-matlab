classdef TestBinaryTable < matlab.unittest.TestCase
    % Test did.file.binaryTable, the storage engine behind did.file.fileCache.
    %
    % binaryTable had no test coverage, which is how the row-bound checks
    % below came to admit a row past the end of the table and how readRow
    % came to divide by zero on an empty one.
    %
    % The layout tested here is the one DID-python's BinaryTable also reads
    % and writes: little-endian, an optional header, then fixed-width rows.

    properties (Constant)
        NameCharacters = 33
        HeaderSize = 2+8+8+8
    end

    methods
        function bT = makeTable(testCase, fileName)
            if nargin < 2, fileName = 'table.bin'; end
            % Start from nothing. Reusing the name without this left the
            % previous table's rows in place, so a test that builds a table
            % more than once was reading a table twice the size it expected.
            if isfile(fullfile(pwd,fileName))
                delete(fullfile(pwd,fileName));
            end
            bT = did.file.binaryTable(...
                did.file.fileobj('fullpathfilename',fullfile(pwd,fileName)),...
                {'char','double','uint64'}, ...
                [testCase.NameCharacters*1 8 8], ...
                [testCase.NameCharacters 1 1], ...
                testCase.HeaderSize);
        end

        function bT = populatedTable(testCase, keys)
            bT = testCase.makeTable();
            bT.writeHeader([typecast(uint16(testCase.NameCharacters),'uint8') ...
                typecast(uint64(9000),'uint8') typecast(uint64(8000),'uint8') ...
                typecast(uint64(0),'uint8')]);
            for i=1:numel(keys)
                bT.insertRow(i-1, {testCase.nameOf(keys(i)), 700000+double(keys(i)), uint64(100*keys(i))});
            end
        end
    end

    methods (Static)
        function n = nameOf(index)
            n = sprintf('%033d', index);
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)

        function testRowSize(testCase)
            bT = testCase.makeTable();
            testCase.verifyEqual(bT.rowSize(), double(testCase.NameCharacters+8+8));
        end

        function testLockAndTempFileNames(testCase)
            % DID-python's BinaryTable builds the same two names. If they
            % disagreed, two languages guarding one table would take two
            % different locks and exclude each other not at all.
            bT = testCase.makeTable();
            testCase.verifyEqual(bT.lockFileName(), [fullfile(pwd,'table.bin') '-lock']);
            testCase.verifyEqual(bT.tempFileName(), [fullfile(pwd,'table.bin') '-temp']);
        end

        function testHeaderRoundTrip(testCase)
            bT = testCase.makeTable();
            hd = [typecast(uint16(33),'uint8') typecast(uint64(1000),'uint8') ...
                  typecast(uint64(800),'uint8') typecast(uint64(0),'uint8')];
            bT.writeHeader(hd);
            back = bT.readHeader();
            testCase.verifyEqual(numel(back), testCase.HeaderSize);
            testCase.verifyEqual(typecast(uint8(back(1:2)),'uint16'), uint16(33));
            testCase.verifyEqual(typecast(uint8(back(3:10)),'uint64'), uint64(1000));
        end

        function testHeaderTooLargeIsRefused(testCase)
            bT = testCase.makeTable();
            testCase.verifyError(@() bT.writeHeader(uint8(zeros(1,testCase.HeaderSize+1))), ...
                ?MException);
        end

        function testTypedRoundTrip(testCase)
            bT = testCase.populatedTable([1 2 3]);
            testCase.verifyEqual(double(bT.getSize()), 3);
            names = bT.readRow(Inf,1);
            testCase.verifyEqual(size(names), [3 testCase.NameCharacters]);
            testCase.verifyEqual(names(2,:), testCase.nameOf(2));
            testCase.verifyEqual(bT.readRow(Inf,2), [700001;700002;700003]);
            testCase.verifyEqual(bT.readRow(Inf,3), uint64([100;200;300]));
        end

        function testSingleRowRead(testCase)
            bT = testCase.populatedTable([1 2 3]);
            testCase.verifyEqual(bT.readRow(2,1), testCase.nameOf(2));
            testCase.verifyEqual(bT.readRow(2,3), uint64(200));
        end

        function testReadingAnEmptyTableReturnsNothing(testCase)
            % readRow(Inf,...) reshaped by the row count, so an empty table
            % divided by zero. fileCache.fileList calls straight into this.
            bT = testCase.makeTable();
            bT.writeHeader([typecast(uint16(testCase.NameCharacters),'uint8') ...
                typecast(uint64(9000),'uint8') typecast(uint64(8000),'uint8') ...
                typecast(uint64(0),'uint8')]);
            testCase.verifyEqual(double(bT.getSize()), 0);
            testCase.verifyEmpty(bT.readRow(Inf,1));
            testCase.verifyEmpty(bT.readRow(Inf,3));
        end

        function testReadingPastTheEndErrors(testCase)
            bT = testCase.populatedTable([1 2]);
            testCase.verifyError(@() bT.readRow(3,1), ?MException);
        end

        function testInsertAtTheFrontAndMiddle(testCase)
            bT = testCase.populatedTable([1 3]);
            bT.insertRow(1, {testCase.nameOf(2), 700002, uint64(200)});
            names = bT.readRow(Inf,1);
            testCase.verifyEqual(names(:,1:testCase.NameCharacters), ...
                [testCase.nameOf(1); testCase.nameOf(2); testCase.nameOf(3)]);

            bT.insertRow(0, {testCase.nameOf(0), 700000, uint64(0)});
            testCase.verifyEqual(double(bT.getSize()), 4);
            names = bT.readRow(Inf,1);
            testCase.verifyEqual(names(1,:), testCase.nameOf(0));
        end

        function testInsertPastTheEndIsRefused(testCase)
            % This used to be permitted, and then took the copy branch and
            % wrote the row past the end of the data.
            bT = testCase.populatedTable([1 2]);
            testCase.verifyError(...
                @() bT.insertRow(3, {testCase.nameOf(9), 1, uint64(1)}), ?MException);
        end

        function testDeleteRow(testCase)
            bT = testCase.populatedTable([1 2 3]);
            bT.deleteRow(2);
            testCase.verifyEqual(double(bT.getSize()), 2);
            names = bT.readRow(Inf,1);
            testCase.verifyEqual(names(:,1:testCase.NameCharacters), ...
                [testCase.nameOf(1); testCase.nameOf(3)]);
            testCase.verifyEqual(bT.readRow(Inf,3), uint64([100;300]));
        end

        function testDeletePastTheEndIsRefused(testCase)
            bT = testCase.populatedTable([1 2]);
            testCase.verifyError(@() bT.deleteRow(3), ?MException);
        end

        function testWriteEntry(testCase)
            bT = testCase.populatedTable([1 2 3]);
            bT.writeEntry(2, 2, 12345.5);
            testCase.verifyEqual(bT.readRow(Inf,2), [700001;12345.5;700003]);
            names = bT.readRow(Inf,1);
            testCase.verifyEqual(names(2,:), testCase.nameOf(2), ...
                'writeEntry must not disturb the neighbouring columns');
        end

        function testWriteTableKeepsTheHeader(testCase)
            bT = testCase.populatedTable([1 2 3]);
            bT.writeTable({testCase.nameOf(5), 5, uint64(55)});
            testCase.verifyEqual(double(bT.getSize()), 1);
            testCase.verifyEqual(bT.readRow(1,1), testCase.nameOf(5));
            hd = bT.readHeader();
            testCase.verifyEqual(typecast(uint8(hd(3:10)),'uint64'), uint64(9000));
        end

        function testHeaderSurvivesInsertAndDelete(testCase)
            bT = testCase.populatedTable([1 2 3]);
            bT.insertRow(0, {testCase.nameOf(0), 1, uint64(1)});
            bT.deleteRow(2);
            hd = bT.readHeader();
            testCase.verifyEqual(typecast(uint8(hd(1:2)),'uint16'), uint16(testCase.NameCharacters));
            testCase.verifyEqual(typecast(uint8(hd(3:10)),'uint64'), uint64(9000));
        end

        function testATableLargerThanTheOldUint16Ceiling(testCase)
            % Offsets were computed as headerSize (uint16) + something, which
            % MATLAB makes uint16 -- so every byte position saturated at
            % 65535. With 49-byte rows that ceiling arrives at about 1337
            % rows, well inside a real file cache. 2000 rows is past it.
            nRows = 2000;
            bT = testCase.makeTable();
            bT.writeHeader([typecast(uint16(testCase.NameCharacters),'uint8') ...
                typecast(uint64(9000),'uint8') typecast(uint64(8000),'uint8') ...
                typecast(uint64(0),'uint8')]);
            data = cell(nRows,3);
            for i=1:nRows
                data{i,1} = testCase.nameOf(i);
                data{i,2} = 700000+i;
                data{i,3} = uint64(i);
            end
            bT.writeTable(data);

            testCase.verifyEqual(double(bT.getSize()), nRows, ...
                'the row count must not saturate');
            testCase.verifyEqual(bT.readRow(nRows,1), testCase.nameOf(nRows), ...
                'the last row must be seekable');
            testCase.verifyEqual(bT.readRow(nRows,3), uint64(nRows));
            names = bT.readRow(Inf,1);
            testCase.verifyEqual(size(names,1), nRows);
            testCase.verifyEqual(bT.findRow(1, testCase.nameOf(nRows), 'sorted', true), nRows, ...
                'the binary search must reach past the old ceiling');
        end

        function testFindRowUnsorted(testCase)
            bT = testCase.populatedTable([2 4 6 8]);
            testCase.verifyEqual(bT.findRow(1, testCase.nameOf(6)), 3);
            testCase.verifyEqual(bT.findRow(1, testCase.nameOf(5)), 0);
        end

        function testFindRowSortedFindsEveryRow(testCase)
            keys = [2 4 6 8];
            bT = testCase.populatedTable(keys);
            for i=1:numel(keys)
                testCase.verifyEqual(bT.findRow(1, testCase.nameOf(keys(i)), 'sorted', true), i, ...
                    sprintf('binary search should find row %d', i));
            end
        end

        function testFindRowSortedSaysWhereAMissingValueBelongs(testCase)
            % wouldBe is the row to insert *after*, so inserting there keeps
            % the column sorted. DID-python relies on the same contract.
            missing = [1 3 5 7 9];
            expected = [0 1 2 3 4];
            for i=1:numel(missing)
                bT = testCase.populatedTable([2 4 6 8]);
                [row, wouldBe] = bT.findRow(1, testCase.nameOf(missing(i)), 'sorted', true);
                testCase.verifyEqual(row, 0);
                testCase.verifyEqual(wouldBe, expected(i), ...
                    sprintf('wrong insertion point for %d', missing(i)));

                bT.insertRow(wouldBe, {testCase.nameOf(missing(i)), 1, uint64(1)});
                names = bT.readRow(Inf,1);
                testCase.verifyEqual(names, sortrows(names), ...
                    'inserting at wouldBe must keep the column sorted');
            end
        end

        function testFindRowOnAnEmptyTable(testCase)
            bT = testCase.makeTable();
            bT.writeHeader([typecast(uint16(testCase.NameCharacters),'uint8') ...
                typecast(uint64(9000),'uint8') typecast(uint64(8000),'uint8') ...
                typecast(uint64(0),'uint8')]);
            [row, wouldBe] = bT.findRow(1, testCase.nameOf(1), 'sorted', true);
            testCase.verifyEqual(row, 0);
            testCase.verifyEqual(wouldBe, 0);
        end

        function testCompare(testCase)
            testCase.verifyEqual(did.file.binaryTable.compare('a','b'), 1);
            testCase.verifyEqual(did.file.binaryTable.compare('b','a'), -1);
            testCase.verifyEqual(did.file.binaryTable.compare('a','a'), 0);
            testCase.verifyEqual(did.file.binaryTable.compare(1,2), 1);
            testCase.verifyEqual(did.file.binaryTable.compare(2,1), -1);
            testCase.verifyEqual(did.file.binaryTable.compare(2,2), 0);
            testCase.verifyEqual(did.file.binaryTable.compare({'a'},{'b'}), 1);
        end

        function testTheBytesOnDiskAreTheDocumentedLayout(testCase)
            % Read the file with plain fread, not through binaryTable, so a
            % change of layout is caught rather than round-tripped over.
            % DID-python's tests assert the same offsets from the other side.
            bT = testCase.makeTable();
            bT.writeHeader([typecast(uint16(testCase.NameCharacters),'uint8') ...
                typecast(uint64(1000),'uint8') typecast(uint64(800),'uint8') ...
                typecast(uint64(0),'uint8')]);
            bT.insertRow(0, {testCase.nameOf(7), 738000.5, uint64(4096)});

            fid = fopen(fullfile(pwd,'table.bin'),'r','ieee-le');
            raw = uint8(fread(fid, Inf, 'uint8'))';
            fclose(fid);

            testCase.verifyEqual(numel(raw), testCase.HeaderSize + testCase.NameCharacters+8+8);
            testCase.verifyEqual(typecast(raw(1:2),'uint16'), uint16(testCase.NameCharacters));
            testCase.verifyEqual(typecast(raw(3:10),'uint64'), uint64(1000));

            row = raw(testCase.HeaderSize+1:end);
            testCase.verifyEqual(char(row(1:testCase.NameCharacters)), testCase.nameOf(7));
            testCase.verifyEqual(typecast(row(testCase.NameCharacters+(1:8)),'double'), 738000.5);
            testCase.verifyEqual(typecast(row(testCase.NameCharacters+8+(1:8)),'uint64'), uint64(4096));
        end

    end
end
