classdef fileCache < handle
    % FILECACHE Implements a file cache directory with a maximum size and file removal with descending access time
    %

    properties (SetAccess=protected)
        directoryName (1,:) char % Full-path directory where the cache is stored
        fileNameCharacters (1,1) uint16 {mustBeGreaterThanOrEqual(fileNameCharacters,32)} = 32 % Number of characters allowed in a fileName (uint16)
        maxSize (1,1) uint64 {mustBeGreaterThanOrEqual(maxSize,1000)} = 100e9 % maximum size for the cache in bytes (uint64)
        reduceSize (1,1) uint64 {mustBeGreaterThanOrEqual(reduceSize,800)} = 80e9 % size to be achieved when files need to be removed
        currentSize (1,1) uint64 {mustBeGreaterThanOrEqual(currentSize,0)} = 0
        binaryTable (1,1) = 0
    end

    properties (Constant)
        cacheInfoFileName = '.fileCacheInfo';
    end

    methods

        function fileCacheObj = fileCache(directoryName, fileNameCharacters, maxSize, reduceSize)
            % FILECACHE - make a new fileCache object
            %
            % FILECACHEOBJ = FILECACHE(DIRECTORYNAME)
            %
            %  Creates a new FILECACHE object located at the full path directory
            %  DIRECTORYNAME. The file names in the cache may be at most
            %  32 characters long. The cache will automatically remove files to
            %  maintain a maximum total size that defaults to 100 GB (100e9).
            %  When the cache fills up, files are deleted to achieve a size
            %  of 80 GB (80e9).
            %
            %  The directory DIRECTORYNAME must already exist.
            %
            %  One may set these default properties to other values by calling
            %
            % FILECACHEOBJ = FILECACHE(DIRECTORYNAME, FILENAMECHARACTERS, MAXSIZE, REDUCESIZE)
            %

            arguments
                directoryName (1,:) {mustBeFolder}
                fileNameCharacters (1,1) uint16 = uint16(32)
                maxSize = uint64(100e9)
                reduceSize = uint64(80e9)
            end

            fileCacheObj.directoryName = directoryName;
            fileCacheObj.fileNameCharacters = fileNameCharacters;

            need_to_set = 1;

            iFileName = infoFileName(fileCacheObj);
            if isfile(iFileName)
                need_to_set = 0;
                savedFileCacheParams = fileCacheObj.getProperties();
                fileCacheObj.fileNameCharacters = savedFileCacheParams.fileNameCharacters;
                fileCacheObj.maxSize = savedFileCacheParams.maxSize;
                fileCacheObj.reduceSize = savedFileCacheParams.reduceSize;
                fileCacheObj.currentSize = savedFileCacheParams.currentSize;

                if nargin>1
                    if savedFileCacheParams.fileNameCharacters ~= fileNameCharacters
                        error('fileNameCharacters may not be altered once established.');
                    end
                end

                % getProperties built the table with the caller's guess at
                % the name width, which is only the header's business.
                % Rebuild it now that the stored width is known: every row is
                % fixed-width, so a table built at the wrong width reads the
                % file at the wrong offsets. Opening an existing 33-character
                % cache as did.file.fileCache(dir) -- no second argument, so
                % the default 32 -- left exactly that mismatch.
                fileCacheObj.binaryTable = did.file.binaryTable(...
                    did.file.fileobj('fullpathfilename',iFileName),...
                    {'char','double','uint64'}, ...
                    [fileCacheObj.fileNameCharacters*1 8 8], ...
                    [fileCacheObj.fileNameCharacters 1 1], ...
                    2+8+8+8);
            end

            if nargin>2 % try to set the properties with the updated version
                need_to_set = 1;
                fileCacheObj.maxSize = maxSize;
            end
            if nargin>3
                fileCacheObj.reduceSize = reduceSize;
            end

            if need_to_set
                fileCacheObj = fileCacheObj.setProperties(fileCacheObj.maxSize, fileCacheObj.reduceSize, fileCacheObj.currentSize);
            end

        end % fileCache

        function fileCacheObj = setProperties(fileCacheObj, maxSize, reduceSize, currentSize)
            % SETPROPERTIES - set or reset the cache size and reduce size
            %
            % FILECACHEOBJ = SETPROPERTIES(FILECACHEOBJ, MAXSIZE, REDUCESIZE)
            %
            % Set or reset the MAXSIZE and REDUCESIZE parameters. MAXSIZE is the
            % maximum allowable size of the cache in bytes, and REDUCESIZE is the
            % size that the cache will be reduced to whenever it would exceed MAXSIZE,
            % also in bytes.
            %
            arguments
                fileCacheObj (1,1)
                maxSize (1,1) uint64 {mustBeGreaterThanOrEqual(maxSize,1000)} = 100e9
                reduceSize (1,1) uint64 {mustBeGreaterThanOrEqual(reduceSize,800)} = 80e9
                currentSize (1,1) uint64 {mustBeGreaterThanOrEqual(currentSize,0)} = 0
            end

            if reduceSize>=maxSize
                error('reduceSize must be less than maxSize.');
            end

            iFileName = infoFileName(fileCacheObj);
            if ~isfile(iFileName) % does it exist already? If not, make it
                fileCacheObj.binaryTable = did.file.binaryTable(...
                    did.file.fileobj('fullpathfilename',iFileName),...
                    {'char','double','uint64'}, ... % filename, last-accessed time, size
                    [fileCacheObj.fileNameCharacters*1 8 8], ... % size of these entries in bytes
                    [fileCacheObj.fileNameCharacters 1 1], ... % size of these entries in elements
                    2+8+8+8); % headerSize: fileNameCharacters (uint16) + maxSize & reduceSize & totalSize (uint64)
                h1 = typecast(uint16(fileCacheObj.fileNameCharacters),'uint8');
            else % retrieve the fileCharacter number from the existing header
                % No "is the table built yet" guard here: reaching this branch
                % means the info file exists, and every route to it -- the
                % constructor, addFile, removeFile, clear, resizeAndAdd --
                % goes through getProperties or the branch above first, both
                % of which build the table. getProperties keeps the guard
                % because it is the one that actually runs.
                hd = fileCacheObj.binaryTable.readHeader();
                h1 = hd(1:2);
                h1 = h1(:)';
            end
            h2 = typecast(uint64(maxSize),'uint8');
            h3 = typecast(uint64(reduceSize),'uint8');
            h4 = typecast(uint64(currentSize),'uint8');
            hd = [h1 h2 h3 h4];
            fileCacheObj.maxSize = maxSize;
            fileCacheObj.reduceSize = reduceSize;
            fileCacheObj.currentSize = currentSize;
            fileCacheObj.binaryTable.writeHeader(hd);

        end % SETPROPERTIES

        function fileCacheInfo = getProperties(fileCacheObj)
            % GETPROPERTIES - read fileCache object properties from the info file
            %
            % FILECACHEINFO = GETPROPERTIES(FILECACHEOBJ)
            %
            % Read the fileCacheObj properties that are stored on disk.
            % FILECACHEINFO is a structure with the properties and values.
            %
            iFileName = infoFileName(fileCacheObj);
            if fileCacheObj.binaryTable==0
                fileCacheObj.binaryTable = did.file.binaryTable(...
                    did.file.fileobj('fullpathfilename',iFileName),...
                    {'char','double','uint64'}, ... % filename, last-accessed time, size
                    [fileCacheObj.fileNameCharacters*1 8 8], ... % size of these entries in bytes
                    [fileCacheObj.fileNameCharacters 1 1], ... % size of these entries in elements
                    2+8+8+8); % headerSize: fileNameCharacters (uint16) + maxSize & reduceSize & totalSize (uint64)
            end
            hd = fileCacheObj.binaryTable.readHeader();
            fileCacheInfo.fileNameCharacters = typecast(hd(1:2),'uint16');
            fileCacheInfo.maxSize = typecast(hd(3:10),'uint64');
            fileCacheInfo.reduceSize = typecast(hd(11:18),'uint64');
            fileCacheInfo.currentSize = typecast(hd(19:26),'uint64');

        end % GETPROPERTIES

        function addFile(fileCacheObj, fullPathFileName, fileNameInCache, option)
            % ADDFILE - add a file to the cache
            %
            % ADDFILE(FILECACHEOBJ, FULLPATHFILENAME, fileNameInCache)
            %
            % Add a file to the cache. The file at FULLPATHFILENAME is moved
            % into the cache. If adding the file would cause the cache to be
            % overfull, then files are deleted from the cache.
            %
            % The file at FULLPATHFILENAME should be outside of the cache.
            %
            % If the file should only be copied and not moved, use
            % ADDFILE(FILECACHEOBJ, FULLPATHFILENAME, fileNameInCache,'copy',true)
            %
            arguments
                fileCacheObj (1,1)
                fullPathFileName char {mustBeFile}
                fileNameInCache (1,:) char = [];
                option.copy (1,1) logical = false
            end

            if isempty(fileNameInCache)
                [~,fileNameInCache,ext] = fileparts(fullPathFileName);
                fileNameInCache = [char(fileNameInCache) char(ext)];
            end

            if numel(fileNameInCache)~=fileCacheObj.fileNameCharacters
                error(['FileName has wrong number of characters (expected ' int2str(fileCacheObj.fileNameCharacters) ').']);
            end

            % Hold the lock across the whole add so a concurrent
            % addFile/removeFile cannot see the row without the bytes, and
            % release it on every exit path (including errors) so hasLock
            % does not get stuck true across the rest of the session.
            [lockfid,key] = fileCacheObj.binaryTable.getLock();
            try
                fullFileInCache = fullfile(fileCacheObj.directoryName,fileNameInCache);
                [row,~] = fileCacheObj.binaryTable.findRow(1,fileNameInCache);
                if row
                    if isfile(fullFileInCache)
                        error(['There is already a file with name ' fileNameInCache ' in the cache.']);
                    end
                    % Stale index row: the row promises a file that is no
                    % longer on disk (an interrupted eviction, a failed
                    % move, a lock race). Retract the promise instead of
                    % refusing the caller who has the bytes.
                    fileCacheObj.dropRowNoLock(row);
                end

                finfo = dir(fullPathFileName);
                sz = finfo.bytes;
                fileCacheObj.resizeAndAdd(sz,fileNameInCache); % row is in db
                try
                    if option.copy
                        copyfile(fullPathFileName,fullFileInCache);
                    else
                        movefile(fullPathFileName,fullFileInCache);
                    end
                catch moveErr
                    % Bytes did not land. Roll the row back so the next
                    % addFile of the same name is not refused as a
                    % "already in cache" that never was.
                    [rollbackRow,~] = fileCacheObj.binaryTable.findRow(1,fileNameInCache);
                    if rollbackRow
                        fileCacheObj.dropRowNoLock(rollbackRow);
                    end
                    rethrow(moveErr);
                end
                fileCacheObj.binaryTable.releaseLock(lockfid,key);
            catch addErr
                % Ensure the lock is released on any error path -- both the
                % on-disk file (if we hold it) and the in-memory hasLock
                % flag. Otherwise the singleton's binaryTable is stuck in
                % "already locked" and every subsequent getLock returns
                % empty, silently disabling concurrency protection.
                try
                    fileCacheObj.binaryTable.releaseLock(lockfid,key);
                catch
                end
                fileCacheObj.binaryTable.resetLockState();
                rethrow(addErr);
            end
        end % addFile()

        function removeFile(fileCacheObj, fileNameInCache)
            % REMOVEFILE - remove a file from the cache
            %
            % REMOVEFILE(FILECACHEOBJ, FILENAMEINCACHE)
            %
            % Remove a file from the cache. FILENAMEINCACHE should be the name of a local
            % file in the cache.
            %
            [lockfid,key] = fileCacheObj.binaryTable.getLock();
            [row,~] = fileCacheObj.binaryTable.findRow(1,fileNameInCache);
            if ~row
                fileCacheObj.binaryTable.releaseLock(lockfid,key);
                error(['File ' fileNameInCache ' is not in file cache manifest.']);
            end
            p = fileCacheObj.getProperties();
            szHere = fileCacheObj.binaryTable.readRow(row,3);
            fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,p.currentSize - szHere);
            fileCacheObj.binaryTable.deleteRow(row);
            delete(fullfile(fileCacheObj.directoryName,fileNameInCache));
            fileCacheObj.binaryTable.releaseLock(lockfid,key);
        end % removeFile

        function clear(fileCacheObj)
            % CLEAR - remove all files from fileCache object
            %
            % CLEAR(FILECACHEOBJ)
            %
            % Clear all files in the cache. Use with caution!
            %
            % clear() also resets the in-memory lock state at the end, so
            % a caller who runs clear() to recover from a poisoned cache
            % gets a genuinely clean binaryTable back -- otherwise a
            % previously stuck hasLock would survive the on-disk wipe and
            % continue to disable the singleton's concurrency protection.
            [lockfid,key] = fileCacheObj.binaryTable.getLock();
            try
                fn = fileCacheObj.fileList(false);
                data = {};
                fileCacheObj.binaryTable.writeTable(data);
                fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,uint16(0));
                fullnames = fullfile(fileCacheObj.directoryName,fn);
                if ~isempty(fullnames)
                    delete(fullnames{:});
                end
                fileCacheObj.binaryTable.releaseLock(lockfid,key);
            catch clearErr
                try
                    fileCacheObj.binaryTable.releaseLock(lockfid,key);
                catch
                end
                fileCacheObj.binaryTable.resetLockState();
                rethrow(clearErr);
            end
            fileCacheObj.binaryTable.resetLockState();
        end

        function b = isFile(fileCacheObj, fileNameInCache)
            % ISFILE - is this file in the cache?
            %
            % B = ISFILE(FILECACHEOBJ, FILENAMEINCACHE)
            %
            % Returns 1 if the file FILENAMEINCACHE is in the cache and
            % 0 otherwise. FILENAMEINCACHE should be the name of a file only
            % without a path.
            b=(fileCacheObj.binaryTable.findRow(1,fileNameInCache)>0);
        end % isFile()

        function [fn,sz,lastAccess] = fileList(fileCacheObj, useCatalog)
            % FILELIST - retrieve the files and sizes in the cache
            %
            % [FN,SZ,LASTACCESS] = FILELIST(FILECACHEOBJ, [USECATALOG])
            %
            % Return a list of filenames in FILECACHEOBJ.
            %
            % FN is an array of file names with names in the rows, and SZ is an array of the
            % corresponding file sizes. That is, SZ(i) is the size (in bytes)
            % of the file FN(i,:). LASTACCESS is a vector of DATENUM values (see NOW) of
            % last access times for each file.
            %
            % By default, the file list is obtained from the file cache information
            % file. If USECATALOG is provided and it is false, then the directory
            % is examined directly. If the directory is examined directly, then
            % LASTACCESS is filled with NaN.
            %
            arguments
                fileCacheObj (1,1)
                useCatalog (1,1) logical = true
            end

            this_function_made_lockfile = 0; %#ok<NASGU> % Currently unused
            iFileName = infoFileName(fileCacheObj); %#ok<NASGU> % Currently unused

            if useCatalog
                % lock for sequential ops, will save a little time
                [lockfid,key] = fileCacheObj.binaryTable.getLock();
                fn = fileCacheObj.binaryTable.readRow(Inf,1);
                lastAccess = fileCacheObj.binaryTable.readRow(Inf,2);
                sz = fileCacheObj.binaryTable.readRow(Inf,3);
                fileCacheObj.binaryTable.releaseLock(lockfid,key);
            else
                d = dir(fileCacheObj.directoryName);
                isFolder = [d.isdir];
                d(isFolder) = [];
                isHidden = strncmp({d.name}, '.', 1);
                d(isHidden) = [];
                fn = {d.name};
                sz = [d.bytes];
                lastAccess = NaN*sz;
            end

        end % fileList()

        function resizeAndAdd(fileCacheObj, newFileSize, newFileName)
            % RESIZEANDADD - resize the cache if needed by deleting files (and add file information)
            %
            % RESIZEANDADD(FILECACHEOBJ, NEWFILESIZE, NEWFILENAME)
            %
            % If needed, delete files from the cache (starting from the
            % least recently accessed) to make room for a file of NEWFILESIZE
            % in bytes.  NEWFILESIZE can be a scalar (if a single file is to be added)
            % or an array.
            %
            % NEWFILENAME is either a single name or a cell array of filenames to add.
            % If there is a cell array, the size of NEWFILESIZE(i) should correspond with NEWFILENAME{i}.
            %
            % The fileCache info entry for NEWFILENAME is added.
            %
            arguments
                fileCacheObj
                newFileSize uint64 {mustBeVector}
                newFileName {mustBeText}
            end

            if ~iscell(newFileName)
                newFileName = {newFileName};
            end

            if sum(newFileSize)>fileCacheObj.maxSize
                error('New files to be added exceed cache allowed size by themselves.');
            end

            [lockfid,key] = fileCacheObj.binaryTable.getLock();
            fileCacheProperties = fileCacheObj.getProperties();
            newTotalSize = fileCacheProperties.currentSize + sum(newFileSize);

            if newTotalSize>fileCacheObj.maxSize
                % we are full! must delete!
                %disp(['We are full! must delete...']);
                [fn,sz,lastaccess] = fileCacheObj.fileList(true);
                [~,la_indexes] = sort(lastaccess,'descend');
                cutoff = find(sum(newFileSize)+cumsum(sz(la_indexes))>fileCacheObj.reduceSize,1,'first');
                DC = mat2cell(fn(la_indexes(cutoff:end),:),repmat(1,-cutoff+numel(la_indexes)+1,1),fileCacheObj.fileNameCharacters);
                ffn = fullfile(fileCacheObj.directoryName, DC);

                % Rewrite the index BEFORE deleting the files. An interrupt
                % between the two used to leave rows without files -- a
                % permanently poisoned uid, since addFile would then refuse
                % as "already in cache" without the bytes ever existing.
                % Doing the delete second means an interrupt leaves
                % orphan files with no index row instead, which are
                % harmless (recovered by check(...,'RemoveOrphans',true)
                % or overwritten by the next add of the same name).

                newfn = mat2cell(fn(la_indexes(1:cutoff-1),:),repmat(1,cutoff-1,1),size(fn,2));
                sz = sz(la_indexes(1:cutoff-1));
                lastaccess = lastaccess(la_indexes(1:cutoff-1));
                newfn = cat(1,newfn,newFileName);
                sz = cat(1,sz(:),newFileSize(:));
                lastaccess = cat(1,lastaccess(:),repmat(now,numel(newFileSize),1));
                [newfn,sortorder] = sort(newfn); % sort by file name
                tabledata = {};
                for i=1:numel(newfn)
                    tabledata{i,1} = newfn{i};
                    tabledata{i,2} = lastaccess(sortorder(i));
                    tabledata{i,3} = sz(sortorder(i));
                end
                fileCacheObj.binaryTable.writeTable(tabledata);
                fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,sum(sz));
                delete(ffn{:});
            else
                %disp(['Not full, total size is ' int2str(newTotalSize) ' and maxSize is ' int2str(fileCacheObj.maxSize) '.']);
                for i=1:numel(newFileName)
                    % Column 1, not i: indexing by the loop variable meant
                    % that adding a second file wrote its name into the
                    % last-accessed column, where the next line immediately
                    % overwrote it -- so every file after the first was
                    % catalogued under the first file's name.
                    data_here{1} = newFileName{i};
                    data_here{2} = now;
                    data_here{3} = newFileSize(i);
                    [~,insertSpot] = fileCacheObj.binaryTable.findRow(1,newFileName{i},'sorted',true);
                    fileCacheObj.binaryTable.insertRow(insertSpot,data_here);
                end
                fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,newTotalSize);
            end
            fileCacheObj.binaryTable.releaseLock(lockfid,key);
        end % resize

        function report = check(fileCacheObj, options)
            % CHECK - report and optionally repair index/disk divergences
            %
            % REPORT = CHECK(FILECACHEOBJ)
            % REPORT = CHECK(FILECACHEOBJ, 'Repair', true)
            % REPORT = CHECK(FILECACHEOBJ, 'Repair', true, 'RemoveOrphans', true)
            %
            % Scans the fileCache and reports any divergence between the
            % binaryTable index and the files on disk. There are two
            % kinds:
            %
            %   staleRows    -- rows the index carries whose file is
            %                   missing on disk. These are what poison a
            %                   uid: addFile refuses because the index
            %                   says "already there", but the bytes are
            %                   not, and the file is never re-cacheable
            %                   until the row is dropped.
            %   orphanFiles  -- files on disk with no matching index row.
            %                   Harmless (they simply do not count
            %                   against currentSize), but they occupy
            %                   space.
            %
            % With 'Repair', true, stale rows are dropped and
            % currentSize is corrected. With 'RemoveOrphans', true, the
            % orphan files are also deleted. Both writes happen under
            % the binaryTable's lock, same as addFile/removeFile.
            %
            % The returned REPORT struct describes what was found and
            % what was repaired.
            arguments
                fileCacheObj (1,1)
                options.Repair (1,1) logical = false
                options.RemoveOrphans (1,1) logical = false
            end

            [lockfid,key] = fileCacheObj.binaryTable.getLock();
            try
                indexNames = fileCacheObj.fileList(true);
                indexList = fileCacheObj.rowNamesToCellstr(indexNames);
                diskList = fileCacheObj.fileList(false);
                diskList = diskList(:);

                staleMask = ~cellfun(@(n) isfile(fullfile(fileCacheObj.directoryName,n)), indexList);
                staleRows = indexList(staleMask);
                orphanFiles = setdiff(diskList, indexList);

                report = struct( ...
                    'directoryName', fileCacheObj.directoryName, ...
                    'checkedAt', now, ...
                    'staleRows', {staleRows}, ...
                    'orphanFiles', {orphanFiles}, ...
                    'consistent', numel(indexList) - numel(staleRows), ...
                    'repaired', struct('rowsDropped', 0, 'filesDeleted', 0));

                if options.Repair && ~isempty(staleRows)
                    for k = 1:numel(staleRows)
                        [rowIdx,~] = fileCacheObj.binaryTable.findRow(1, staleRows{k});
                        if rowIdx
                            fileCacheObj.dropRowNoLock(rowIdx);
                            report.repaired.rowsDropped = report.repaired.rowsDropped + 1;
                        end
                    end
                end

                if options.RemoveOrphans && ~isempty(orphanFiles)
                    fullOrphans = fullfile(fileCacheObj.directoryName, orphanFiles);
                    for k = 1:numel(fullOrphans)
                        if isfile(fullOrphans{k})
                            delete(fullOrphans{k});
                            report.repaired.filesDeleted = report.repaired.filesDeleted + 1;
                        end
                    end
                end

                fileCacheObj.binaryTable.releaseLock(lockfid,key);
            catch checkErr
                try
                    fileCacheObj.binaryTable.releaseLock(lockfid,key);
                catch
                end
                fileCacheObj.binaryTable.resetLockState();
                rethrow(checkErr);
            end
        end % check()

        function b = touch(fileCacheObj, fileName)
            % TOUCH - mark a file as accessed right now
            %
            % B = TOUCH(FILECACHEOBJ, FILENAME)
            %
            % Indicate that a file has just been accessed. Updates the last access time
            % of FILENAME. FILENAME can be a scalar or cell array of file names.
            %
            % B is 1 if the file is found and 0 otherwise.
            %
            arguments
                fileCacheObj (1,1)
                fileName {mustBeText}
            end

            b = 0;

            [lockfid,key] = fileCacheObj.binaryTable.getLock();
            row = fileCacheObj.binaryTable.findRow(1,fileName);
            if row
                fileCacheObj.binaryTable.writeEntry(row,2,now());
                b = 1;
            end
            fileCacheObj.binaryTable.releaseLock(lockfid,key);
        end % touch()

    end % methods

    methods (Access=protected)

        function iFileName = infoFileName(fileCacheObj)
            % INFOFILENAME - return the name of the cache information file
            %
            % IFILENAME = INFOFILENAME(FILECACHEOBJ)
            %
            % Return the name of the cache information file for a fileCacheObj
            %
            iFileName = fullfile(fileCacheObj.directoryName,did.file.fileCache.cacheInfoFileName);
        end % infoFileName()

        function dropRowNoLock(fileCacheObj, row)
            % DROPROWNOLOCK - remove one index row and decrement currentSize
            %
            % Internal helper used by addFile's stale-row reconciliation
            % and rollback paths, and by check(...,'Repair',true). The
            % caller MUST already hold the binaryTable lock. Unlike
            % removeFile, this does not touch any file on disk -- the
            % point is precisely that the file is not there.
            szHere = fileCacheObj.binaryTable.readRow(row,3);
            p = fileCacheObj.getProperties();
            newSize = p.currentSize;
            if szHere <= newSize
                newSize = newSize - szHere;
            else
                newSize = uint64(0);
            end
            fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,newSize);
            fileCacheObj.binaryTable.deleteRow(row);
        end % dropRowNoLock()

        function names = rowNamesToCellstr(~, rowNames)
            % ROWNAMESTOCELLSTR - fixed-width name matrix to cellstr
            %
            % fileList(true) returns names as a fixed-width char matrix
            % (one row per file). Callers that want to fullfile() or
            % compare against directory listings need one cell per row.
            % The names themselves are preserved verbatim (no strtrim),
            % so that findRow -- which does an exact byte match on the
            % column -- can look them up by the same value.
            if isempty(rowNames)
                names = cell(0,1);
                return
            end
            n = size(rowNames,1);
            names = cell(n,1);
            for k = 1:n
                names{k} = rowNames(k,:);
            end
        end % rowNamesToCellstr()

    end

end % classdef
