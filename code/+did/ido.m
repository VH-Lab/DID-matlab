classdef ido
    % did.ido   Identifier object class; creates globally unique IDs for DID database
    %
    % This class creates and stores globally unique IDs. The ID is based on both the
    % current time and a random number (see did.unique_id). Therefore, the IDs are
    % globally unique and also sortable (alphanumerically) by the time of creation
    % (which is in Universal Controlled Time (Leap Seconds), UTC).
    %
    % did.ido Properties:
    %   identifier - a unique identifier (id) for this did.ido object
    %
    % did.ido Methods:
    %   ido - creator that generates a DID globally unique ID (or stores an existing ID)
    %   id - return the identifier of the did.ido object
    %   unique_id - generate a DID globally unique ID (Static function)
    %
    % Examples:
    %   myid = did.ido()
    %   myid.id(), % show the ID
    %   anotherid = did.ido.unique_id(),

    properties (SetAccess=protected,GetAccess=public)
        identifier; % a unique identifier id for this object
    end % properties

    methods
        function obj = ido(id_value)
            % IDO - create a new DID.IDO (DID ID object)
            %
            % ID_OBJ = DID.IDO()
            %
            % Creates a new DID.IDO object and generates a unique id
            % that is stored in the property 'identifier'.
            %
            if nargin > 0
                % TODO: CHECK check it is a proper id
                obj.identifier = id_value;
            else
                obj.identifier = did.ido.unique_id();
            end
        end

        function identifier = id(ido_obj)
            % ID - return the identifier of an DID.IDO object
            %
            % IDENTIFIER = ID(DID.IDO_OBJ)
            %
            % Returns the unique identifier of an DID.IDO object.
            %
            identifier = ido_obj.identifier;
        end; % id()
    end; % methods

    methods (Static)
        function id = unique_id()
            % UNIQUE_ID - Generate a unique ID number for DID databases (Static method)
            %
            % ID = DID.IDO.UNIQUE_ID()
            %
            % Generates a unique ID character array based on the current time and a random
            % number. It is a hexadecimal representation of the serial date number in
            % UTC Leap Seconds time. The serial date number is the number of days since January 0, 0000 at 0:00:00.
            % The integer portion of the date is the whole number of days and the fractional part of the date number
            % is the fraction of days.
            %
            % ID = [NUM2HEX(SERIAL_DATE_NUMBER) '_' NUM2HEX(RAND)]
            %
            % See also: NUM2HEX, NOW, RAND
            %
            serial_date_number = convertTo(datetime('now','TimeZone','UTCLeapSeconds'),'datenum');
            random_number = rand + randi([-32727 32727],1);
            id = [num2hex(serial_date_number) '_' num2hex(random_number)];

        end; % did.ido.unique_id()

        function b = isvalid(id)
            % ISVALID - is a unique ID number valid?
            %
            % B = isvalid(ID)
            %
            % Returns true if ID matches the structure of a did.ido identifier and
            % false otherwise. A valid ID must have 16 hexidecimal digits in
            % 0-9 or a-f, an underscore, and then 16 more hexidecimal digits.
            % 

                try
                    id = char(id);
                    assert(numel(id)==33,'IDs must be 33 characters.');
                    valid_chars = ['0123456789abcdef'];
                    assert(all(ismember(id(1:16),valid_chars)),'ID digits 1..16 must be in 0..9abcdef');
                    assert(all(ismember(id(18:33),valid_chars)),'ID digits 18..33 must be in 0..9abcdef');
                    b=true;
                catch
                    b=false;
                end

        end % did.ido.isvalid

    end % methods(static)
end
