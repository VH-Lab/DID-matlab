function [b, value] = isfullfield(A, compositeFieldName)
    % ISFULLFIELD - is there a field (or field and subfield) of a structure with a given name?
    %
    % [B, VALUE] = ISFULLFIELD(A, FIELDNAME)
    %
    % Examines the structure A to see if A.<COMPOSITEFIELDNAME> can be evaluated.
    % If so, B is true and the VALUE is returned in VALUE. Otherwise, B is false.
    % If B is false, then VALUE is empty.
    %
    % See also: FIELDSEARCH
    %
    % Example:
    %     A = struct('a',struct('sub1',1,'sub2',2),'b',5);
    %     [b,value] = did.datastructures.isfullfield(A, 'a.sub1') % returns b==1 and value==1
    %     [b2,value2] = did.datastructures.isfullfield(A, 'a.sub3') % returns b==0 and value==[]

    arguments
        A struct
        compositeFieldName (1,1) string
    end

    % Initialize output assuming full field does not exist
    b = false;
    value = [];

    fieldNames = split(compositeFieldName, '.');
    subs = struct('type', '.', 'subs', cellstr(fieldNames));

    try
        value = subsref(A, subs);
        b = true;
    catch
        return
    end
end
