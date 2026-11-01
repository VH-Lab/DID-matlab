function tf = isFileReferenceClass(className)
%ISFILEREFERENCECLASS True when CLASSNAME names a v1 external-file record.
%
%   TF = did2.convert.isFileReferenceClass(CLASSNAME) is true for both
%   spellings a file record can have in pass 1's output:
%
%     'fileReference'    the v1 class name (NDI template
%                        database_documents/data/fileReference.json), which a
%                        record keeps now that it is read raw
%                        (did2.convert.rawV1Classes), and keeps when it is
%                        carried;
%     'file_reference'   the renamed spelling universalRenames gives it, which a
%                        record has when it was written while that pass ran
%                        (it is deleted) or a caller hands a batch pass a
%                        document built in that spelling.
%
%   The ONE place DID-matlab decides "is this a file record" by its class
%   name (did2.convert.foldGenericFiles, its store-record half). NDI-matlab's
%   second pass reads neither name.
%
%   CLASSNAME may be a char vector or a string scalar; anything else is false.
%
%   See also did2.convert.foldGenericFiles, did2.convert.rawV1Classes,
%            did2.convert.isOntologyLabelClass.

if isstring(className) && isscalar(className)
    className = char(className);
end
tf = ischar(className) && any(strcmp(className, {'file_reference', 'fileReference'}));
end
