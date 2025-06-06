function t=jsonencodenan(obj)
    % JSONENCODENAN - encode a JSON object allowing Nan/Infinity
    %
    % T = did.datastructures.jsonencodenan(OBJ)
    %
    % Encodes the Matlab variable OBJ into a JSON object in a manner that
    % allows the use of NaN and -Inf and Inf.
    %
    % JSONENCODE is called with 1 argument or 2 (Matlab 2018b) to ensure
    % these numbers are allowed.
    %
    % See also: JSONENCODE

    try
        t = jsonencode(obj,'ConvertInfAndNaN',false,'PrettyPrint',true); % newest version
    catch
        try
            t = jsonencode(obj,'ConvertInfAndNaN',false); % for after 2018b
        catch
            t = jsonencode(obj);
        end
    end
