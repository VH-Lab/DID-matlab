classdef binarydoc_matfid < did.binarydoc & fileobj

	properties,
		key            %  The key that is created when the binary doc is locked
		doc_unique_id  %  The document unique id
	end;

	methods,
		function binarydoc_matfid_obj = binarydoc_matfid(varargin)
			% BINARYDOC_MATFID - create a new BINARYDOC_MATFID object
			%
			% BINARYDOC_MATFID_OBJ = BINARYDOC_MATFID(PARAM1,VALUE1, ...)
			%
			% Follows same arguments as FILEOBJ
			%
			% See also: FILEOBJ, FILEOBJ/FILEOBJ
			%
				key = '';
				doc_unique_id = '';
				assign(varargin{:});
				binarydoc_matfid_obj = binarydoc_matfid_obj@fileobj(varargin{:});
				binarydoc_matfid_obj.machineformat = 'ieee-le';
				binarydoc_matfid_obj.key = key;
				_binarydoc_matfid_obj.doc_unique_id = doc_unique_id;
		end; % binarydoc_matfid() creator

		function binarydoc_matfid_obj = fclose(binarydoc_matfid_obj)
			% FCLOSE - close an BINARYDOC_MATFID object
			%
			% Closes the file, but also clears the fullpathfilename and other fields so the 
			% user cannot re-use the object without checking out another binary document from
			% the database.
			%
				binarydoc_matfid_obj.fclose@fileobj();
				binarydoc_matfid_obj.permission = 'r';
		end % fclose()
	end;
end

