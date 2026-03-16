function report = compareDatabaseSummary(summaryA, summaryB, options)
    % COMPAREDATABASESUMMARY - compare two database summaries and return a report
    %
    % REPORT = did.util.compareDatabaseSummary(SUMMARYA, SUMMARYB, ...)
    %
    % Compares two database summary structs (as produced by did.util.databaseSummary
    % or loaded from JSON) and returns a cell array of character arrays describing
    % any differences found. If no differences are found, returns an empty cell
    % array {}.
    %
    % SUMMARYA and SUMMARYB may be:
    %   - structs returned by did.util.databaseSummary()
    %   - file paths to JSON files containing serialized summaries
    %   - did.database objects (which will be summarized automatically)
    %
    % This function accepts name-value pair arguments:
    %   'excludeFields' - A cell array of top-level field names to skip
    %                     when comparing (e.g., {'dbId'} to ignore database IDs).
    %
    % Example:
    %   summaryA = did.util.databaseSummary(dbA);
    %   summaryB = did.util.databaseSummary(dbB);
    %   report = did.util.compareDatabaseSummary(summaryA, summaryB);
    %   if ~isempty(report)
    %       cellfun(@disp, report);
    %   end
    %
    % See also: did.util.databaseSummary

    arguments
        summaryA
        summaryB
        options.excludeFields (1,:) cell = {}
    end

    % Convert inputs to summary structs if needed
    summaryA = toSummaryStruct(summaryA);
    summaryB = toSummaryStruct(summaryB);

    report = {};

    % Compare branch names
    branchesA = summaryA.branchNames;
    branchesB = summaryB.branchNames;
    if ischar(branchesA), branchesA = {branchesA}; end
    if ischar(branchesB), branchesB = {branchesB}; end

    onlyInA = setdiff(branchesA, branchesB);
    onlyInB = setdiff(branchesB, branchesA);

    for i = 1:numel(onlyInA)
        report{end+1} = sprintf('Branch "%s" exists only in summary A.', onlyInA{i}); %#ok<*AGROW>
    end
    for i = 1:numel(onlyInB)
        report{end+1} = sprintf('Branch "%s" exists only in summary B.', onlyInB{i});
    end

    % Compare branch hierarchy if present in both
    if isfield(summaryA, 'branchHierarchy') && isfield(summaryB, 'branchHierarchy') ...
            && ~ismember('branchHierarchy', options.excludeFields)
        commonBranches = intersect(branchesA, branchesB);
        for i = 1:numel(commonBranches)
            branchName = commonBranches{i};
            safeName = matlab.lang.makeValidName(branchName);
            if isfield(summaryA.branchHierarchy, safeName) && isfield(summaryB.branchHierarchy, safeName)
                parentA = summaryA.branchHierarchy.(safeName).parent;
                parentB = summaryB.branchHierarchy.(safeName).parent;
                if ~strcmp(parentA, parentB)
                    report{end+1} = sprintf('Branch "%s": parent mismatch ("%s" vs "%s").', branchName, parentA, parentB);
                end
            end
        end
    end

    % Compare each branch's documents
    commonBranches = intersect(branchesA, branchesB);
    for i = 1:numel(commonBranches)
        branchName = commonBranches{i};
        safeName = matlab.lang.makeValidName(branchName);

        if ~isfield(summaryA.branches, safeName) || ~isfield(summaryB.branches, safeName)
            continue;
        end

        branchA = summaryA.branches.(safeName);
        branchB = summaryB.branches.(safeName);

        % Compare document counts
        if branchA.docCount ~= branchB.docCount
            report{end+1} = sprintf('Branch "%s": doc count mismatch (%d vs %d).', ...
                branchName, branchA.docCount, branchB.docCount);
        end

        % Build lookup maps by document ID
        mapA = buildDocMap(branchA.documents);
        mapB = buildDocMap(branchB.documents);

        idsA = keys(mapA);
        idsB = keys(mapB);

        missingInA = setdiff(idsB, idsA);
        missingInB = setdiff(idsA, idsB);

        for j = 1:numel(missingInA)
            report{end+1} = sprintf('Branch "%s": doc "%s" missing in summary A.', branchName, missingInA{j});
        end
        for j = 1:numel(missingInB)
            report{end+1} = sprintf('Branch "%s": doc "%s" missing in summary B.', branchName, missingInB{j});
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
                report{end+1} = sprintf('Branch "%s", doc "%s": class name mismatch ("%s" vs "%s").', ...
                    branchName, docId, classA, classB);
            end

            % Compare demo-type value fields
            propsA = getProperties(docA);
            propsB = getProperties(docB);
            demoFields = {'demoA', 'demoB', 'demoC'};
            for k = 1:numel(demoFields)
                fieldName = demoFields{k};
                hasA = isfield(propsA, fieldName);
                hasB = isfield(propsB, fieldName);
                if hasA && hasB
                    valA = propsA.(fieldName).value;
                    valB = propsB.(fieldName).value;
                    if ~isequal(valA, valB)
                        report{end+1} = sprintf('Branch "%s", doc "%s": %s.value mismatch (%s vs %s).', ...
                            branchName, docId, fieldName, num2str(valA), num2str(valB));
                    end
                elseif hasA ~= hasB
                    report{end+1} = sprintf('Branch "%s", doc "%s": field "%s" present in one summary but not the other.', ...
                        branchName, docId, fieldName);
                end
            end

            % Compare depends_on
            hasDepsA = isfield(propsA, 'depends_on');
            hasDepsB = isfield(propsB, 'depends_on');
            if hasDepsA && hasDepsB
                depsA = normalizeDeps(propsA.depends_on);
                depsB = normalizeDeps(propsB.depends_on);
                if ~isequal(depsA, depsB)
                    report{end+1} = sprintf('Branch "%s", doc "%s": depends_on mismatch.', branchName, docId);
                end
            elseif hasDepsA ~= hasDepsB
                report{end+1} = sprintf('Branch "%s", doc "%s": depends_on present in one summary but not the other.', ...
                    branchName, docId);
            end
        end
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
