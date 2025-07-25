function mustBeValidPermission(value)
    arguments
        value (1,1) string
    end

    if ismissing(value); return; end

    VALID_PERMISSIONS = ["r", "w", "a", "r+", "w+", "a+", "W", "A"];
    
    permissionsAsString = strjoin( "  " + VALID_PERMISSIONS, newline);

    % Add text modes:
    VALID_PERMISSIONS = [VALID_PERMISSIONS, insertAfter(VALID_PERMISSIONS, 1, "t")];

    assert(ismember(value, VALID_PERMISSIONS), ...
        'File permission must be one of:\n%s\n', permissionsAsString)
end
