classdef binarydoc_matfid < did.binarydoc & did.file.fileobj

	properties,
		key            %  The key that is created when the binary doc is locked
		doc_unique_id  %  The document unique id
	end;

	methods,
		function binarydoc_matfid_obj = binarydoc_matfid(fileProps, matfidProps)
			% BINARYDOC_MATFID - create a new BINARYDOC_MATFID object
			%
			% BINARYDOC_MATFID_OBJ = BINARYDOC_MATFID(PARAM1,VALUE1, ...)
			%
			% Follows same arguments as FILEOBJ
			%
			% See also: FILEOBJ, FILEOBJ/FILEOBJ
			%

                arguments
                    fileProps.machineformat (1,1) string {did.file.mustBeValidMachineFormat} = 'l'; % native machine format
                    fileProps.permission (1,1) string {did.file.mustBeValidPermission} = "r"
                    fileProps.fid (1,1) int64 = -1
                    fileProps.fullpathfilename = '';
                    matfidProps.key = ''
                    matfidProps.doc_unique_id = ''
                end
                
				binarydoc_matfid_obj = binarydoc_matfid_obj@did.file.fileobj(fileProps);
				binarydoc_matfid_obj.machineformat = 'l'; %'ieee-le'; % Todo: is this supposed to always be this format
				binarydoc_matfid_obj.key = matfidProps.key;
				binarydoc_matfid_obj.doc_unique_id = matfidProps.doc_unique_id;
		end; % binarydoc_matfid() creator

		function binarydoc_matfid_obj = fclose(binarydoc_matfid_obj)
			% FCLOSE - close an BINARYDOC_MATFID object
			%
			% Closes the file, but also clears the fullpathfilename and other fields so the 
			% user cannot reuse the object without checking out another binary document from
			% the database.
			%
				binarydoc_matfid_obj.fclose@did.file.fileobj();
				binarydoc_matfid_obj.permission = 'r';
		end % fclose()
	end;
end

