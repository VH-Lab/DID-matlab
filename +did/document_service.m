classdef documentservice
% DOCUMENTSERVICE - a class of methods that allows objects to interact with DOCUMENT objects
%
	properties (SetAccess=protected, GetAccess=public)

	end; % properties

	methods
		function documentservice_obj = documentservice()
			% DOCUMENTSERVICE - create an DOCUMENTSERVICE object, which is just an abstract class
			%
			% DOCUMENTSERVICE_OBJ = DOCUMENTSERVICE();
			%
				
		end; % did_documentservice()

		function did_document_obj = newdocument(ndi_documentservice_obj)
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

		function sq = searchquery(documentservice_obj)
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

