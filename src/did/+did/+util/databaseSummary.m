function summary = databaseSummary(db)
    % DATABASESUMMARY - produce a struct summarizing a DID database and its branches
    %
    % SUMMARY = did.util.databaseSummary(DB)
    %
    % Returns a struct that captures the full state of a did.database object DB,
    % suitable for serialization to JSON and cross-language symmetry testing.
    %
    % The returned SUMMARY struct contains:
    %   .dbId             - the database identifier string
    %   .branchNames      - cell array of all branch IDs in the database
    %   .branchHierarchy  - struct mapping each branch name to its parent ('' for roots)
    %   .branches         - struct with one field per branch, each containing:
    %       .docCount     - number of documents in the branch
    %       .documents    - cell array of document summary structs, each with:
    %           .id         - document unique ID
    %           .className  - document_class.class_name
    %           .properties - the full document_properties struct
    %
    % The summary is deterministic: documents within each branch are sorted by ID.
    %
    % Example:
    %   db = did.implementations.sqlitedb('mydb.sqlite');
    %   summary = did.util.databaseSummary(db);
    %   jsonStr = did.datastructures.jsonencodenan(summary);
    %
    % See also: did.util.compareDatabaseSummary

    arguments
        db did.database
    end

    summary = struct();
    summary.dbId = db.dbid;

    % Gather all branch names
    branchNames = db.all_branch_ids();
    if ischar(branchNames)
        branchNames = {branchNames};
    end
    summary.branchNames = branchNames;

    % Build branch hierarchy (each branch -> its parent)
    branchHierarchy = struct();
    for i = 1:numel(branchNames)
        branchName = branchNames{i};
        safeName = matlab.lang.makeValidName(branchName);
        try
            parentId = db.get_branch_parent(branchName);
        catch
            parentId = '';
        end
        branchHierarchy.(safeName) = struct( ...
            'branchName', branchName, ...
            'parent', parentId ...
        );
    end
    summary.branchHierarchy = branchHierarchy;

    % Build per-branch document summaries
    branches = struct();
    for i = 1:numel(branchNames)
        branchName = branchNames{i};
        safeName = matlab.lang.makeValidName(branchName);

        docIds = db.get_doc_ids(branchName);
        if ischar(docIds)
            docIds = {docIds};
        end
        if isempty(docIds)
            docIds = {};
        end

        % Sort by ID for deterministic output
        docIds = sort(docIds);

        docSummaries = cell(1, numel(docIds));
        for j = 1:numel(docIds)
            doc = db.get_docs(docIds{j});
            props = doc.document_properties;

            docSummary = struct();
            docSummary.id = docIds{j};
            if isfield(props, 'document_class') && isfield(props.document_class, 'class_name')
                docSummary.className = props.document_class.class_name;
            else
                docSummary.className = '';
            end
            docSummary.properties = props;
            docSummaries{j} = docSummary;
        end

        branchInfo = struct();
        branchInfo.branchName = branchName;
        branchInfo.docCount = numel(docIds);
        branchInfo.documents = docSummaries;
        branches.(safeName) = branchInfo;
    end
    summary.branches = branches;
end
