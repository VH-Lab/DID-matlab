function new_path = replace_didpath(path)
%   REPLACE_DIDPATH - Replace placeholders in a file path with actual locations.
%
%   NEW_PATH = REPLACE_DIDPATH(PATH) replace the placeholder for a document
%       definition with the actual path location for the document
%       definition. The mapping between placeholders (names) and locations
%       are stored in the definition property of the did.common.PathConstants
%       A placeholder has the form $SOME_NAME, i.e $DIDSCHEMA_EX1
%
%   PATH - a file path that contains definition placeholder/name
%
%   NEW_PATH - an absolute file path for a schema definition
%
    
    new_path = path;

    if startsWith(path, "$")        
        splitPath = strsplit(path, filesep);
        placeHolder = splitPath{1};
        if isKey(did.common.PathConstants.definitions, placeHolder)
            absolutePath = did.common.PathConstants.definitions(placeHolder);
        else
            % Todo: warning or error?
            keyboard
            return
        end
        new_path = strrep(path, placeHolder, absolutePath);

    elseif contains(path, "$")
        % Todo/question: Does this ever happen?
        keyboard
    else
        return
    end
    % for i = 1:numel(definitionNames)
    %     new_path = strrep(new_path, definitionNames{i}, did.common.PathConstants.definitions(definitionNames{i}));
    % end
end
