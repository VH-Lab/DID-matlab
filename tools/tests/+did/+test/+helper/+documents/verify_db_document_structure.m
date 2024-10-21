function [b,msg]=verify_db_document_structure(db, G, expected_docs)
    % VERIFY_DB_DOCUMENT_STRUCTURE - test that a database contains the documents expected
    %
    % [B,MSG] = VERIFY_DB_DOCUMENT_STRUCTURE(DB, G, EXPECTED_DOCS)
    %
    % Searches the database for a set of EXPECTED_DOCS of type demoA, demoB, or
    % demoC. G is the adjacency matrix of graph relationships between the documents
    % (G(i,j) is 1 if j depends on i). EXPECTED_DOCS is a cell array of
    % did.document types that correspond to the nodes in G. (That is,
    % EXPECTED_DOCS{i} corresponds to node i in the graph adjacency matrix).
    %
    % B is 1 if the relationships are all verified and 0 otherwise.
    % MSG is empty if there are no errors, or contains a description of the error.

    % Initialize
    msg = '';
    b = true;
    fieldset = {'demoA','demoB','demoC'};

    % Loop over all docs
    for i=1:numel(expected_docs)
        % try loading the expected docs
        id_here = expected_docs{i}.id();
        doc_here = db.get_docs(id_here);

        % test whether the content matches
        for j=1:numel(fieldset)
            if isfield(expected_docs{i}.document_properties,fieldset{j})
                hasfield = isfield(doc_here.document_properties,fieldset{j});
                if hasfield
                    field1 = getfield(expected_docs{i}.document_properties,fieldset{j});
                    field2 = getfield(doc_here.document_properties,fieldset{j});
                    b = b & vlt.data.eqlen(field1,field2);
                    if ~b
                        msg = ['Field ' fieldset{j} ' of document ' expected_docs{i}.document_properties.base.id ' did not match.'];
                        fprintf(2,'%s\n',msg);
                        return
                    end
                end
            end
        end
    end
