function binaryTable
    % BINARYTABLE - test the did.file.binaryTable object
    %
    % BINARYTABLE()
    %
    % Perform a battery of tests on the binaryTable object type.
    %

    filename = fullfile(did.common.PathConstants.testpath,'myBinTable.bin');

    if isfile(filename), % start out deleting the file
        delete(filename);
    end;

    bT = did.file.binaryTable(did.file.fileobj('fullpathfilename',filename),...
        {'char','double','uint64'},[33*1 8 8],[33 1 1],2+8+8+8);

    % write a header

    h1 = typecast(uint16(33),'uint8');
    h2 = typecast(uint64(100e9),'uint8');
    h3 = typecast(uint64(80e9),'uint8');
    h4 = typecast(uint64(0e9),'uint8');

    headerData = [h1 h2 h3 h4];

    bT.writeHeader(headerData);

    hd = bT.readHeader();

    if ~isequal(hd(:),headerData(:)),
        error(['Header data not written correctly.']);
    end;

    % use fileCache details as a test case for this table
    id = {};
    timestamps = [];
    filesize = [];
    data = {};

    for i=1:20,
        id{i} = getfield(did.ido,'identifier');
        timestamps(i) = now;
        filesize(i) = uint64(1e9*rand);
        data{i} = {id{i} timestamps(i) filesize(i)};
        bT.insertRow(i-1,data{i});
    end;

    for i=1:20,
        d = bT.readRow(i,1);
        if ~isequal(data{i}{1},d),
            error(['Data not equal: c == 1, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,2);
        if ~isequal(data{i}{2},d),
            error(['Data not equal: c == 2, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,3);
        if ~isequal(data{i}{3},d),
            error(['Data not equal: c == 3, r == ' int2str(i) '.']);
        end;
    end;

    wholec = char([]);

    for i=1:20,
        wholec(i,:) = data{i}{1};
    end;

    d = bT.readRow(Inf,1);

    if ~isequal(wholec,d),
        error(['whole column read of column 1 failed.']);
    end;

    % insert a row in the middle

    id = cat(2,id(1:10),{getfield(did.ido,'identifier')},id(11:end));
    timestamps = [timestamps(1:10) now timestamps(11:end)];
    filesize = [filesize(1:10) uint64(1e9*rand) filesize(11:end)];
    data = cat(2,data(1:10),{{id{11} timestamps(11) filesize(11)}}, data(11:end));
    bT.insertRow(10,data{11});

    for i=1:size(data),
        d = bT.readRow(i,1);
        if ~isequal(data{i}{1},d),
            error(['Data not equal: c == 1, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,2);
        if ~isequal(data{i}{2},d),
            error(['Data not equal: c == 2, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,3);
        if ~isequal(data{i}{3},d),
            error(['Data not equal: c == 3, r == ' int2str(i) '.']);
        end;
    end;

    % now delete that row

    bT.deleteRow(11);
    id = id([1:10 12:end]);
    timestamps = timestamps([1:10 12:end]);
    filesize = filesize([1:10 12:end]);
    data = data([1:10 12:end]);

    for i=1:size(data),
        d = bT.readRow(i,1);
        if ~isequal(data{i}{1},d),
            error(['Data not equal: c == 1, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,2);
        if ~isequal(data{i}{2},d),
            error(['Data not equal: c == 2, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,3);
        if ~isequal(data{i}{3},d),
            error(['Data not equal: c == 3, r == ' int2str(i) '.']);
        end;
    end;

    % test search/find

    for i=1:size(data),

        value = id{i};
        myrow = bT.findRow(1,value);
        if myrow~=i,
            error(['Wrong row.']);
        end;

        myrow = bT.findRow(1,value,'sorted',true);
        if myrow~=i,
            error(['Wrong row.']);
        end;

        myrow = bT.findRow(1,'24234234','sorted',true);
        if myrow~=0,
            error(['Should not have found a match but did.']);
        end;
    end;

    % test search/find w/ miss

    for i=1:size(data),
        value = id{i};
        value(end) = value(end)-1;
        [myrow,wouldbe] = bT.findRow(1,value,'sorted',true);
        if wouldbe~=i-1,
            myrow,
            error(['1 Wrong row: got ' int2str(wouldbe) ' expected ' int2str(i-1)]);
        end;

        value = id{i};
        value(end) = value(end)+1;
        [myrow,wouldbe] = bT.findRow(1,value,'sorted',true);
        if wouldbe~=i,
            myrow,
            error(['2 Wrong row: got ' int2str(wouldbe) ' expected ' int2str(i)]);
        end;
    end;

    data2 = {};

    for r=1:numel(data),
        for c=1:3,
            data2{r,c} = data{r}{c};
        end;
    end;

    for i=1:size(data),
        d = bT.readRow(i,1);
        if ~isequal(data{i}{1},d),
            error(['Data not equal: c == 1, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,2);
        if ~isequal(data{i}{2},d),
            error(['Data not equal: c == 2, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,3);
        if ~isequal(data{i}{3},d),
            error(['Data not equal: c == 3, r == ' int2str(i) '.']);
        end;
    end;

    data{10}{2} = now;

    bT.writeEntry(10,2,data{10}{2});

    for i=1:size(data),
        d = bT.readRow(i,1);
        if ~isequal(data{i}{1},d),
            error(['Data not equal: c == 1, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,2);
        if ~isequal(data{i}{2},d),
            error(['Data not equal: c == 2, r == ' int2str(i) '.']);
        end;
        d = bT.readRow(i,3);
        if ~isequal(data{i}{3},d),
            error(['Data not equal: c == 3, r == ' int2str(i) '.']);
        end;
    end;
