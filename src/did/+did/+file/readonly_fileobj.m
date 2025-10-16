classdef readonly_fileobj < did.file.fileobj
    %READONLY_FILEOBJ - object wrapper interface to low-level read-only file access methods
    %
    % This is an object interface to fopen, fread, fseek, fclose, and ftell. Why do this?
    % One could imagine one day separating the process of reading and writing a data stream from the file
    % system. For example, one could write to GRIDFS by overriding these functions, and the user's code
    % would never have to know.
    %
    % See also: FILEOBJ

    methods
        function fileobj_obj = readonly_fileobj(options)
            % READONLY_FILEOBJ - create a new read-only binary file object
            %
            % FILEOBJ_OBJ = READONLY_FILEOBJ(...)
            %
            % Creates an empty FILEOBJ object. If FILENAME is provided,
            % then the filename is stored.
            arguments
                options.machineformat (1,1) string {did.file.mustBeValidMachineFormat} = 'n'; % native machine format
                options.permission (1,1) string {did.file.mustBeValidPermission} = "r"
                options.fid (1,1) int64 = -1
                options.fullpathfilename = '';
            end

            % Call the super-class constructor
            super_options = namedargs2cell(options);
            fileobj_obj@did.file.fileobj(super_options{:});

            % Ensure that the default 'r' permission was not modified
            if ~strcmpi(fileobj_obj.permission(1),'r')
                error('DID:File:ReadOnly_Fileobj','Read-only file must have ''r'' permission');
            end
        end % readonly_fileobj() constructor

        function fileobj_obj = fopen(fileobj_obj, permission, varargin)
            % FOPEN - open a FILEOBJ
            %
            % FILEOBJ_OBJ = FOPEN(FILEOBJ_OBJ,[PERMISSION],[MACHINEFORMAT],[FILENAME])
            %
            % Opens the file associated with a FILEOBJ_OBJ object in read-only mode
            %
            % See also: FOPEN, FILEOBJ/FOPEN, FILEOBJ/FCLOSE, FCLOSE

            if nargin > 1 && ~strcmpi(permission,'r')
                error('DID:File:ReadOnly_Fileobj','Read-only file must be opened with ''r'' permission');
            end
            fileobj_obj = fopen@did.file.fileobj(fileobj_obj,'r',varargin{:});
        end %fopen
    end % methods

end % classdef
