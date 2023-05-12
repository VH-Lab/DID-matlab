function sqlMetaData = doc2sql(doc)
% DOC2SQL analyzes a DID_DOCUMENT or NDI_DOCUMENT object and returns meta-data to be used by SQL
%
% sqlMetaData = doc2sql(doc)
%
% DOC must be a valid DID_DOCUMENT or NDI_DOCUMENT object.
%
% The returned sqlMetaData is a struct array, where each struct element has:
%    .name = meta-table name
%    .columns
%        .name       = meta-table column name
%        .matlabType = result of class(value)
%        .sqlType    = result of SQL.getSQLTypeOf(value)
%        .value      = value if scalar, otherwise []/blob
% Reference: issue #26

    % Input validation
    errMsg = 'doc2sql expects a did.document or ndi.document object as input arg';
    assert(nargin>0, errMsg);
    %assert(isa(doc,'did.document') || isa(doc,'ndi.document'), errMsg);

    % Extract the document properties (should croak if the document is invalid)
    doc_props = doc.document_properties;

    % Extract the document's table name
    sqlMetaData.name = 'meta'; %=getField(doc_props, {'app.name','base.name','ndi_document.name'});

    % Create some common columns
    sqlMetaData.columns = struct('name',{}, 'matlabType',{}, 'sqlType',{}, 'value',{}); %initialize

    id = getField(doc_props, {'app.id', 'base.id', 'ndi_document.id'});
    sqlMetaData.columns(end+1) = newColumn('doc_id', id);

    className = getField(doc_props, {'document_class.class_name','ndi_document.type'});
    sqlMetaData.columns(end+1) = newColumn('class', className);

    superclass = getField(doc_props, 'document_class.superclasses');
    if isstruct(superclass)
        superclass = regexprep({superclass.definition},{'.+/','\..+$'},'');
        superclass = strjoin(unique(superclass), ', ');
    end
    sqlMetaData.columns(end+1) = newColumn('superclass', superclass);

    datestamp = getField(doc_props, {'base.datestamp','ndi_document.datestamp'});
    sqlMetaData.columns(end+1) = newColumn('datestamp', datestamp);

    sqlMetaData.columns(end+1) = newColumn('creation', '');
    sqlMetaData.columns(end+1) = newColumn('deletion', '');

    dependsOn = getField(doc_props, 'depends_on');
    if isstruct(dependsOn)
        allData = [{dependsOn.name}; {dependsOn.value}];
        dependsOn = sprintf('%s,%s;',allData{:});
    end
    sqlMetaData.columns(end+1) = newColumn('depends_on', dependsOn);

    % Extract the custom (dynamic) meta-tables from the document property fields
    fields = fieldnames(doc_props);
    fields = setdiff(fields, {'depends_on','document_class','files'}, 'stable');
    for idx = 1 : numel(fields)
        sqlMetaData(end+1) = getMetaTableFrom(doc_props, id, fields{idx}); %#ok<AGROW>
    end
end

% Extract data field values based on a priorities list of field names
function value = getField(doc_props, fields) %#ok<INUSL>
    value = '';
    if ~iscell(fields), fields = {fields}; end
    for fieldIdx = 1 : numel(fields)
        try
            val = eval(['doc_props.' fields{fieldIdx}]); %#ok<EVLDOT>
            if ~isempty(val)
                value = val;
                return
            end
        catch
            % ignore this field
        end
    end
end

% Create a meta-data column
function colData = newColumn(name, value, matlabType)
    if nargin < 3, matlabType = class(value); end
    colData.name       = name;
    colData.matlabType = matlabType;
    colData.sqlType    = sqlTypeOf(matlabType);
    colData.value      = value;
end

% Create custom (dynamic) meta-table from a sub-struct
function metaTable = getMetaTableFrom(doc_props, id, name)
    metaTable.name = name;
    %metaTable.columns = struct('name',{}, 'matlabType',{}, 'sqlType',{}, 'value',{}); %initialize
    metaTable.columns = newColumn('doc_id', id);
    dataStruct = doc_props.(name);
    fields = fieldnames(dataStruct);
    for idx = 1 : numel(fields)
        recurseFields(dataStruct, fields{idx});
    end

    % Recursively parse sub-struct fields
    function recurseFields(dataStruct, fieldName, cumulFieldName)
        if nargin < 3, cumulFieldName = fieldName; end
        fieldValue = dataStruct.(fieldName);
        if isstruct(fieldValue)
            numElements = numel(fieldValue);
            for idx2 = 1 : numElements
                dataStruct = fieldValue(idx2);
                subFields = fieldnames(dataStruct);
                for idx3 = 1 : numel(subFields)
                    fieldName = subFields{idx3};
                    newCumulFieldName = [cumulFieldName '___' fieldName];
                    if (numElements > 1)
                        newCumulFieldName = [newCumulFieldName '_' num2str(idx2)]; %#ok<AGROW>
                    end
                    recurseFields(dataStruct, fieldName, newCumulFieldName);
                end
            end
        else
            % Convert strings => chars, string array => cellstr
            try fieldValue = controllib.internal.util.hString2Char(fieldValue); catch, end
            matlabType = class(fieldValue);
            dataSize = size(fieldValue);
            if iscell(fieldValue) && isvector(fieldValue)
               fieldValue = cell2str(fieldValue, char(7));  % issue #57
            elseif ~ischar(fieldValue) && ~isscalar(fieldValue) && ~isempty(fieldValue)
                %if 0 && strcmp(matlabType,'double') % just leave it
                %else
                    sizeStr = regexprep(mat2str(dataSize), '\s+', 'x'); %'×'
                    fieldValue = sprintf('%s %s', sizeStr, matlabType);
                %end
            end
            metaTable.columns(end+1) = newColumn(cumulFieldName, fieldValue, matlabType);
        end
    end
end

% SQL data type of the corresponding Matlab type
% TODO: database-dependent types
function sqlType = sqlTypeOf(matlabType)
    switch matlabType
        case 'logical',                sqlType = 'bool';
        case {'char','string'},        sqlType = 'varchar';
        case {'single','double'},      sqlType = 'float';
        case {'int','int16','int32'},  sqlType = 'integer';
        otherwise,                     sqlType = matlabType;
    end
end

% Convert a cell-array into a string that can be used in SQL
% 1) Don't use vlt.data.cell2str because it uses comma separators that we wish
%    to avoid (since they might be confused with commas within the cell items)
% 2) The output str format is '{ 'abc' <x> 'def' ... }' where <x> is the
%    optional input delimiter argument (default: ',' character)
function str = cell2str(cellArray, delimiter)
    %str = vlt.data.cell2str(cellArray)
    if isempty(cellArray)
        str = '{}';  %handle the trivial case first
    else
        % First, convert the cellArray into a single row vector
        cellArray = reshape(cellArray,1,[]);

        % Next, convert all cellArray items into char arrays
        cellArray = cellfun(@mat2str, cellArray, 'uniform',false);

        % Now join the items into a single char array (default delimiter: char(7)=BEL)
        if nargin < 2, delimiter = ', '; end  % use comma delimiter by default
        str = ['{ ' strjoin(cellArray,delimiter) ' }'];
    end
end
