function report = compareDatabaseSummary(summaryA, summaryB)
    % COMPAREDATABASESUMMARY - compare two database summaries and return a report
    %
    % REPORT = did.util.compareDatabaseSummary(SUMMARYA, SUMMARYB)
    %
    % Compares two database summary structs (as produced by did.util.databaseSummary
    % or loaded from JSON) and returns a report struct describing any differences.
    %
    % SUMMARYA and SUMMARYB may be:
    %   - structs returned by did.util.databaseSummary()
    %   - file paths to JSON files containing serialized summaries
    %   - did.database objects (which will be summarized automatically)
    %
    % The returned REPORT struct contains:
    %   .isEqual          - true if the two summaries match on all checked fields
    %   .messages         - cell array of human-readable difference descriptions
    %   .branchComparison - struct with per-branch comparison details:
    %       .<branchName>.inBoth     - true if branch exists in both summaries
    %       .<branchName>.docCountA  - document count in summary A
    %       .<branchName>.docCountB  - document count in summary B
    %       .<branchName>.docCountMatch - true if counts match
    %       .<branchName>.missingInA - cell array of doc IDs in B but not A
    %       .<branchName>.missingInB - cell array of doc IDs in A but not B
    %       .<branchName>.valueMismatches - cell array of mismatch descriptions
    %
    % Example:
    %   summaryA = did.util.databaseSummary(dbA);
    %   summaryB = did.util.databaseSummary(dbB);
    %   report = did.util.compareDatabaseSummary(summaryA, summaryB);
    %   if ~report.isEqual
    %       disp(report.messages);
    %   end
    %
    % See also: did.util.databaseSummary

    % Convert inputs to summary structs if needed
    summaryA = toSummaryStruct(summaryA);
    summaryB = toSummaryStruct(summaryB);

    report = struct();
    report.isEqual = true;
    report.messages = {};
    report.branchComparison = struct();

    % Compare branch names
    branchesA = summaryA.branchNames;
    branchesB = summaryB.branchNames;
    if ischar(branchesA), branchesA = {branchesA}; end
    if ischar(branchesB), branchesB = {branchesB}; end

    allBranches = union(branchesA, branchesB);

    onlyInA = setdiff(branchesA, branchesB);
    onlyInB = setdiff(branchesB, branchesA);

    if ~isempty(onlyInA)
        report.isEqual = false;
        for i = 1:numel(onlyInA)
            report.messages{end+1} = ['Branch "' onlyInA{i} '" exists only in summary A.'];
        end
    end
    if ~isempty(onlyInB)
        report.isEqual = false;
        for i = 1:numel(onlyInB)
            report.messages{end+1} = ['Branch "' onlyInB{i} '" exists only in summary B.'];
        end
    end

    % Compare each branch that exists in both
    for i = 1:numel(allBranches)
        branchName = allBranches{i};
        safeName = matlab.lang.makeValidName(branchName);

        comp = struct();
        comp.inBoth = ismember(branchName, branchesA) && ismember(branchName, branchesB);

        if ~comp.inBoth
            comp.docCountA = 0;
            comp.docCountB = 0;
            comp.docCountMatch = false;
            comp.missingInA = {};
            comp.missingInB = {};
            comp.valueMismatches = {};
            report.branchComparison.(safeName) = comp;
            continue;
        end

        % Get branch data from each summary
        branchA = summaryA.branches.(safeName);
        branchB = summaryB.branches.(safeName);

        comp.docCountA = branchA.docCount;
        comp.docCountB = branchB.docCount;
        comp.docCountMatch = (branchA.docCount == branchB.docCount);
        comp.missingInA = {};
        comp.missingInB = {};
        comp.valueMismatches = {};

        if ~comp.docCountMatch
            report.isEqual = false;
            report.messages{end+1} = ['Branch "' branchName '": doc count mismatch (' ...
                num2str(branchA.docCount) ' vs ' num2str(branchB.docCount) ').'];
        end

        % Build lookup maps by document ID
        docsA = branchA.documents;
        docsB = branchB.documents;
        mapA = buildDocMap(docsA);
        mapB = buildDocMap(docsB);

        idsA = keys(mapA);
        idsB = keys(mapB);

        comp.missingInA = setdiff(idsB, idsA);
        comp.missingInB = setdiff(idsA, idsB);

        if ~isempty(comp.missingInA)
            report.isEqual = false;
            for j = 1:numel(comp.missingInA)
                report.messages{end+1} = ['Branch "' branchName '": doc "' comp.missingInA{j} '" missing in summary A.'];
            end
        end
        if ~isempty(comp.missingInB)
            report.isEqual = false;
            for j = 1:numel(comp.missingInB)
                report.messages{end+1} = ['Branch "' branchName '": doc "' comp.missingInB{j} '" missing in summary B.'];
            end
        end

        % Compare documents present in both
        commonIds = intersect(idsA, idsB);
        for j = 1:numel(commonIds)
            docId = commonIds{j};
            docA = mapA(docId);
            docB = mapB(docId);

            % Compare class name
            classA = getClassName(docA);
            classB = getClassName(docB);
            if ~strcmp(classA, classB)
                report.isEqual = false;
                msg = ['Branch "' branchName '", doc "' docId '": class name mismatch ("' classA '" vs "' classB '").'];
                report.messages{end+1} = msg;
                comp.valueMismatches{end+1} = msg;
            end

            % Compare demo-type value fields
            demoFields = {'demoA', 'demoB', 'demoC'};
            propsA = getProperties(docA);
            propsB = getProperties(docB);
            for k = 1:numel(demoFields)
                fieldName = demoFields{k};
                hasA = isfield(propsA, fieldName);
                hasB = isfield(propsB, fieldName);
                if hasA && hasB
                    valA = propsA.(fieldName).value;
                    valB = propsB.(fieldName).value;
                    if ~isequal(valA, valB)
                        report.isEqual = false;
                        msg = ['Branch "' branchName '", doc "' docId '": ' fieldName '.value mismatch (' ...
                            num2str(valA) ' vs ' num2str(valB) ').'];
                        report.messages{end+1} = msg;
                        comp.valueMismatches{end+1} = msg;
                    end
                elseif hasA ~= hasB
                    report.isEqual = false;
                    msg = ['Branch "' branchName '", doc "' docId '": field "' fieldName '" present in one summary but not the other.'];
                    report.messages{end+1} = msg;
                    comp.valueMismatches{end+1} = msg;
                end
            end

            % Compare depends_on
            hasDepsA = isfield(propsA, 'depends_on');
            hasDepsB = isfield(propsB, 'depends_on');
            if hasDepsA && hasDepsB
                depsA = propsA.depends_on;
                depsB = propsB.depends_on;
                if ~isequal(normalizeDeps(depsA), normalizeDeps(depsB))
                    report.isEqual = false;
                    msg = ['Branch "' branchName '", doc "' docId '": depends_on mismatch.'];
                    report.messages{end+1} = msg;
                    comp.valueMismatches{end+1} = msg;
                end
            elseif hasDepsA ~= hasDepsB
                report.isEqual = false;
                msg = ['Branch "' branchName '", doc "' docId '": depends_on present in one summary but not the other.'];
                report.messages{end+1} = msg;
                comp.valueMismatches{end+1} = msg;
            end
        end

        report.branchComparison.(safeName) = comp;
    end
end

%% Local helper functions

function s = toSummaryStruct(input)
    % Convert various input types to a summary struct
    if isstruct(input)
        s = input;
    elseif ischar(input) || isstring(input)
        % Treat as file path to JSON
        fid = fopen(input, 'r');
        if fid < 0
            error('DID:CompareSummary:FileNotFound', 'Could not open file: %s', input);
        end
        rawJson = fread(fid, inf, '*char')';
        fclose(fid);
        s = jsondecode(rawJson);
    elseif isa(input, 'did.database')
        s = did.util.databaseSummary(input);
    else
        error('DID:CompareSummary:InvalidInput', ...
            'Input must be a summary struct, a JSON file path, or a did.database object.');
    end
end

function m = buildDocMap(docs)
    % Build a containers.Map from document ID to document struct
    m = containers.Map('KeyType', 'char', 'ValueType', 'any');
    if iscell(docs)
        for i = 1:numel(docs)
            docStruct = docs{i};
            docId = getDocId(docStruct);
            if ~isempty(docId)
                m(docId) = docStruct;
            end
        end
    elseif isstruct(docs)
        for i = 1:numel(docs)
            docId = getDocId(docs(i));
            if ~isempty(docId)
                m(docId) = docs(i);
            end
        end
    end
end

function docId = getDocId(docStruct)
    % Extract document ID from a summary doc struct
    if isfield(docStruct, 'id')
        docId = docStruct.id;
    elseif isfield(docStruct, 'properties') && isfield(docStruct.properties, 'base')
        docId = docStruct.properties.base.id;
    elseif isfield(docStruct, 'base')
        docId = docStruct.base.id;
    else
        docId = '';
    end
end

function cn = getClassName(docStruct)
    % Extract class name from a summary doc struct
    if isfield(docStruct, 'className')
        cn = docStruct.className;
    elseif isfield(docStruct, 'properties') && isfield(docStruct.properties, 'document_class')
        cn = docStruct.properties.document_class.class_name;
    elseif isfield(docStruct, 'document_class')
        cn = docStruct.document_class.class_name;
    else
        cn = '';
    end
end

function props = getProperties(docStruct)
    % Extract the document properties from a summary doc struct
    if isfield(docStruct, 'properties')
        props = docStruct.properties;
    else
        props = docStruct;
    end
end

function deps = normalizeDeps(depsInput)
    % Normalize depends_on to a consistent sortable form for comparison
    if isstruct(depsInput)
        deps = struct();
        for i = 1:numel(depsInput)
            if isfield(depsInput(i), 'name') && isfield(depsInput(i), 'value')
                deps(i).name = depsInput(i).name;
                deps(i).value = depsInput(i).value;
            else
                deps(i) = depsInput(i);
            end
        end
    else
        deps = depsInput;
    end
end
