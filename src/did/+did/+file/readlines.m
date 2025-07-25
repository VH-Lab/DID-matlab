function lines = readlines(filePath)
% readlines - Read lines of file as cell array
%
%   lines = did.file.readlines(filePath) returns each line of a text file
%       as an element in a cell array. 
%
%   This implementation should be compatible for MATLAB releases older than
%   R2020b when readlines was introduced.
%
%   Note: If the last line is empty (due to EOF character), it is removed.

    arguments
        filePath (1,1) string {mustBeFile}
    end

    if verLessThan('matlab','9.9') %#ok<VERLESSMATLAB> R2020b
        % Use verLessThan, as isMATLABReleaseOlderThan was introduced in R2020b
        fileContent = char(fileread(filePath));
        lines = split(fileContent, newline);
    else
        lines = cellstr( readlines(filePath) );
    end

    if isempty(lines{end})
        lines = lines(1:end-1);
    end
end
