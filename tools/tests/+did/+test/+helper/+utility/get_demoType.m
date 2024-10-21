function [demoType] = get_demoType(doc)
    %GET_DEMOTYPE find the first demo class for a given document
    %   DOC a document with classes demoA, demoB, or demoC
    if isfield(doc.document_properties,'demoA')
        demoType = 'demoA';
        return
    elseif isfield(doc.document_properties,'demoB')
        demoType = 'demoB';
        return
    elseif isfield(doc.document_properties,'demoC')
        demoType = 'demoC';
        return
    else
        demoType = '';
    end
