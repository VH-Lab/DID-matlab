function [d] = findalldependencies(DB, visited, docs)
    % FINDALLDEPENDENCIES- find documents that have dependencies on documents that do not exist
    %
    % [D] = FINDALLDEPENDENCIES(DB, VISITED, DOC1, DOC2, ...)
    %
    % Searches the database DB and returns all documents that have a
    % dependency ('depends_on') field for which the 'value' field corresponds to the
    % id of DOC1 or DOC2, etc. If any DOCS do not need to be searched, provide them in VISITED.
    % Otherwise, provide empty for VISITED.
    %
    % D is always a cell array of DID.DOCUMENT objects (perhaps empty, {}).
    %
    arguments
        DB did.database
        visited cell
    end
    arguments (Repeating)
        docs
    end


    d = {};

    if isempty(visited)
        visited = {};
    end

    for i=1:numel(docs)
        visited = cat(1,visited,{docs{i}.id()});
    end

    for i=1:numel(docs)
        q_v = ndi_query('','depends_on','*',docs{i}.id());
        bb = DB.database_search(q_v);

        for j=1:numel(bb)
            id_here = bb{j}.id();
            if ~any(strcmp(id_here,visited)) % we don't already know about it
                visited = cat(1,visited,{id_here});
                d = cat(1,d,bb(j));
                newdocs = did.fun.finddocs_missing_dependencies(E,visited,bb{j});
                if ~isempty(newdocs)
                    for k=1:numel(newdocs)
                        visited = cat(1,visited,newdocs{k}.id());
                    end
                    d = cat(1,d,newdocs(:));
                end
            end
        end
    end

    if ~iscell(d)
        error('This should always return a cell list, even if it is empty. Some element is wrong, debug necessary.');
    end
