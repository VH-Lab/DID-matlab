classdef binarydoc < handle
    % did.binarydoc: a binary file class that handles reading/writing
    %   Inherits Matlab object handle
    %
    % did.binarydoc defines the operations of a binary file / binary stream.
    % did.binarydoc is mostly abstract class (except for the delete method).
    % Implementations in subclasses must override the Methods here.
    %
    % did.binarydoc Methods:
    %   binarydoc - Create a new binary document
    %   fopen - Open the binary document for reading/writing
    %   fseek - Move to a location within the binary document
    %   ftell - Return the current location in a binary document
    %   feof - Is a binary document at the end of file?
    %   fwrite - write data to a binary document
    %   fread - read data from a binary document
    %   fclose - close a binary document
    %   delete - delete a binary document (calls handle superclass)
    %

    properties (SetAccess=protected, GetAccess=public)
    end  % protected, accessible

    methods
        function binarydoc_obj = binarydoc(varargin)
            % BINARYDOC - create a new BINARYDOC object
            %
            % BINARYDOC_OBJ = BINARYDOC()
            %
            % This is an abstract class, so the creator does nothing.
            %

        end % binarydoc()

        function delete(binarydoc_obj)
            % DELETE - close an BINARYDOC and delete its handle
            %
            % DELETE(BINARYDOC_OBJ)
            %
            % Closes an BINARYDOC (if necessary) and then deletes the handle.
            %
            fclose(binarydoc_obj);
            delete@handle(binarydoc_obj); % call superclass
        end % delete()

    end

    methods (Abstract)

        binarydoc_obj = fopen(binarydoc_obj)
        % FOPEN - open the BINARYDOC for reading/writing
        %
        % FOPEN(BINARYDOC_OBJ)
        %
        % Open the file record associated with BINARYDOC_OBJ.
        %

        %end; % fopen()

        fseek(binarydoc_obj, location, reference)
        % FSEEK - move to a location within the file stream
        %
        % FSEEK(BINARYDOC_OBJ, LOCATION, REFERENCE)
        %
        % Moves to a LOCATION (in bytes) in a file stream.
        %
        % LOCATION is relative to a REFERENCE:
        %    'bof'  - beginning of file
        %    'cof'  - current position in file
        %    'eof'  - end of file
        %
        % See also: FSEEK, FTELL, BINARYDOC/FTELL
        %end; % fseek()

        location = ftell(binarydoc_obj)
        % FTELL - return the current location in a binary document
        %
        % FTELL(BINARYDOC_OBJ)
        %
        % Returns the current LOCATION (in bytes) in a file stream.
        %
        % See also: FSEEK, FTELL, BINARYDOC/FSEEK
        %end; % ftell()

        b = feof(binarydoc_obj)
        % FEOF - is an BINARYDOC at the end of file?
        %
        % B = FEOF(BINARYDOC_OBJ)
        %
        % Returns 1 if the end-of-file indicator is set on the
        % file stream BINARYDOC_OBJ, and 0 otherwise.
        %
        % See also: FEOF, FSEEK, BINARYDOC/FSEEK
        %end % feof

        count = fwrite(binarydoc_obj, data, precision, skip)
        % FWRITE - write data to an BINARYDOC
        % FOPEN - open the BINARYDOC for reading/writing
        %
        % COUNT = FWRITE(FILENAME, PERMISSIONS)
        %
        %
        % See also: FWRITE
        %end; % fwrite()

        [data, count] = fread(binarydoc_obj, count, precision, skip)
        % FREAD - read data from an BINARYDOC
        %
        % [DATA, COUNT] = FREAD(BINARYDOC_OBJ, COUNT, [PRECISION],[SKIP])
        %
        % Read COUNT data objects (precision PRECISION) from an BINARYDOC object.
        % The actual COUNT is returned, along with the DATA.
        %
        % See also: FREAD
        %end; % fread()

        binarydoc_obj = fclose(binarydoc_obj)
        %FCLOSE - close an BINARYDOC
        %
        % FCLOSE(BINARYDOC_OBJ)
        %
        %

        %end; % fclose()

    end % Abstract methods
end
