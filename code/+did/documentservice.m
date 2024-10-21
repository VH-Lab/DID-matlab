classdef documentservice
    % did.documentservice - a class of methods that allows objects to interact with DID.DOCUMENT objects
    %
    % did.documentservice provides methods for creating new documents and searching for documents
    % that are related to the class. For example, an APP class might create documents that
    % fill in the app-related information automatically, and other functions in that class that
    % create documents might start with documents created by did.documentservice.newdocument() before
    % adding their own features. Similarly, did.documentservice.searchquery() allows one to specify a
    % search of type did.query that will locate documents from the class.
    %
    % This class is just an abstract class. The methods should be overridden in subclasses.
    %
    % did.documentservice Methods:
    %   newdocument - Create a new did.document based on information in this class.
    %   searchquery - Create a search query of type did.query based on information in this class
    %
    properties (SetAccess=protected, GetAccess=public)

    end; % properties

    methods
        function documentservice_obj = documentservice()
            % DOCUMENTSERVICE - create an DOCUMENTSERVICE object, which is just an abstract class
            %
            % DOCUMENTSERVICE_OBJ = DOCUMENTSERVICE();
            %
        end; % did.documentservice()

        function did_document_obj = newdocument(ndi_documentservice_obj) %#ok<MANU>
            % NEWDOCUMENT - create a new DOCUMENT based on information in this object
            %
            % DOCUMENT_OBJ = NEWDOCUMENT(DOCUMENTSERVICE_OBJ)
            %
            % Create a new DID.DOCUMENT based on information in this class.
            %
            % The base DID.DOCUMENTSERVICE class returns empty.
            %
            did_document_obj = [];
        end; % newdocument

        function sq = searchquery(documentservice_obj) %#ok<MANU>
            % SEARCHQUERY - create a search query to find this object as an DOCUMENT
            %
            % SQ = SEARCHQUERY(DOCUMENTSERVICE_OBJ)
            %
            % Return a search query that can be used to find this object's representation as an
            % DID.DOCUMENT.
            %
            % The base class DID.DOCUMENTSERVICE just returns empty.
            sq = [];
        end; % searchquery
    end;
end
