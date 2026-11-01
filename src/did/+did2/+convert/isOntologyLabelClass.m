function tf = isOntologyLabelClass(className)
%ISONTOLOGYLABELCLASS True when CLASSNAME names a v1 ontology-label document.
%
%   TF = did2.convert.isOntologyLabelClass(CLASSNAME) is true for both
%   spellings a label can have in pass 1's output:
%
%     'ontologyLabel'    the v1 class name (NDI template
%                        database_documents/data/ontologyLabel.json), which a
%                        label keeps now that it is read raw
%                        (did2.convert.rawV1Classes), and keeps when it is
%                        carried (carry-064);
%     'ontology_label'   the renamed spelling universalRenames gives it, which a
%                        label has when it was written while that pass ran
%                        (it is deleted) or a caller hands a batch pass a
%                        document built in that spelling.
%
%   The ONE place DID-matlab decides "is this a label document" by its class
%   name. It mirrors NDI-matlab's ndi.migrate.internal.isOntologyLabelClass
%   (NDI-matlab #1076), the same decision on the second-pass side.
%
%   CLASSNAME may be a char vector or a string scalar; anything else is false.
%
%   See also did2.convert.foldGenericFiles, did2.convert.rawV1Classes.

if isstring(className) && isscalar(className)
    className = char(className);
end
tf = ischar(className) && any(strcmp(className, {'ontology_label', 'ontologyLabel'}));
end
