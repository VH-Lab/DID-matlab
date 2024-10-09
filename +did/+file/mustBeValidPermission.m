function mustBeValidPermission(value)
    arguments
        value (1,1) string
    end

    if ismissing(value); return; end

    VALID_PERMISSIONS = ["r", "w", "a", "r+", "w+", "a+", "W", "A"];
    
    permissionsAsString = strjoin( "  " + VALID_PERMISSIONS, newline);
    
    assert(ismember(value, VALID_PERMISSIONS), ...
        'File permission must be one of:\n%s\n', permissionsAsString)
end