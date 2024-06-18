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
				if isfile(iFileName),
					need_to_set = 0;
					savedFileCacheParams = fileCacheObj.getProperties();
					fileCacheObj.fileNameCharacters = savedFileCacheParams.fileNameCharacters;
					fileCacheObj.maxSize = savedFileCacheParams.maxSize;
					fileCacheObj.reduceSize = savedFileCacheParams.reduceSize;
					fileCacheObj.currentSize = savedFileCacheParams.currentSize;

					if nargin>1,
						if savedFileCacheParams.fileNameCharacters ~= fileNameCharacters,
							error(['fileNameCharacters may not be altered once established.']);
						end;
					end;
				end;

				if nargin>2, % try to set the properties with the updated version
					need_to_set = 1;
					fileCacheObj.maxSize = maxSize;
				end;
				if nargin>3,
					fileCacheObj.reduceSize = reduceSize;
				end;

				if need_to_set,
					fileCacheObj = fileCacheObj.setProperties(fileCacheObj.maxSize, fileCacheObj.reduceSize, fileCacheObj.currentSize);
				end;

		end; % fileCache

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

				if reduceSize>=maxSize,
					error(['reduceSize must be less than maxSize.']);
				end;

				iFileName = infoFileName(fileCacheObj); 
				if ~isfile(iFileName), % does it exist already? If not, make it
					fileCacheObj.binaryTable = did.file.binaryTable(...
						did.file.fileobj('fullpathfilename',iFileName),...
						{'char','double','uint64'}, ... % filename, last-accessed time, size
						[fileCacheObj.fileNameCharacters*1 8 8], ... % size of these entries in bytes
						[fileCacheObj.fileNameCharacters 1 1], ... % size of these entries in elements
						2+8+8+8); % headerSize: fileNameCharacters (uint16) + maxSize & reduceSize & totalSize (uint64)
					h1 = typecast(uint16(fileCacheObj.fileNameCharacters),'uint8');
				else, % retrieve the fileCharacter number from the existing header
					hd = fileCacheObj.binaryTable.readHeader();
					h1 = hd(1:2);
					h1 = h1(:)';
				end;
				h2 = typecast(uint64(maxSize),'uint8');
				h3 = typecast(uint64(reduceSize),'uint8');
				h4 = typecast(uint64(currentSize),'uint8');
				hd = [h1 h2 h3 h4];
				fileCacheObj.maxSize = maxSize;
				fileCacheObj.reduceSize = reduceSize;
				fileCacheObj.currentSize = currentSize;
				fileCacheObj.binaryTable.writeHeader(hd);
					
		end; % SETPROPERTIES

		function fileCacheInfo = getProperties(fileCacheObj)
			% GETPROPERTIES - read fileCache object properties from the info file
			%
			% FILECACHEINFO = GETPROPERTIES(FILECACHEOBJ)
			% 
			% Read the fileCacheObj properties that are stored on disk. 
			% FILECACHEINFO is a structure with the properties and values.
			%
				iFileName = infoFileName(fileCacheObj); 
				if fileCacheObj.binaryTable==0,
					fileCacheObj.binaryTable = did.file.binaryTable(...
						did.file.fileobj('fullpathfilename',iFileName),...
						{'char','double','uint64'}, ... % filename, last-accessed time, size
						[fileCacheObj.fileNameCharacters*1 8 8], ... % size of these entries in bytes
						[fileCacheObj.fileNameCharacters 1 1], ... % size of these entries in elements
						2+8+8+8); % headerSize: fileNameCharacters (uint16) + maxSize & reduceSize & totalSize (uint64)
				end;
				hd = fileCacheObj.binaryTable.readHeader();
				fileCacheInfo.fileNameCharacters = typecast(hd(1:2),'uint16');
				fileCacheInfo.maxSize = typecast(hd(3:10),'uint64');
				fileCacheInfo.reduceSize = typecast(hd(11:18),'uint64');
				fileCacheInfo.currentSize = typecast(hd(19:26),'uint64');
			
		end; % GETPROPERTIES

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

				if isempty(fileNameInCache),
					[dummy,fileNameInCache,ext] = fileparts(fullPathFileName);
					fileNameInCache = [char(fileNameInCache) char(ext)];
				end;

				if numel(fileNameInCache)~=fileCacheObj.fileNameCharacters,
					error(['FileName has wrong number of characters (expected ' int2str(fileCacheObj.fileNameCharacters) ').']);
				end;

				% make sure file isn't already in there
				[lockfid,key] = fileCacheObj.binaryTable.getLock();
				[row,wouldbe] = fileCacheObj.binaryTable.findRow(1,fileNameInCache);
				if row,
					fileCacheObj.binaryTable.releaseLock(lockfid,key);
					error(['There is already a file with name ' fileNameInCache ' in the cache.']);
				end;

				finfo = dir(fullPathFileName);
				sz = finfo.bytes;
				fileCacheObj.resizeAndAdd(sz,fileNameInCache); % now it is in db
				fullFileInCache = fullfile(fileCacheObj.directoryName,fileNameInCache);
				if option.copy,
					copyfile(fullPathFileName,fullFileInCache);
				else,
					movefile(fullPathFileName,fullFileInCache);
				end;
				fileCacheObj.binaryTable.releaseLock(lockfid,key);
		end; % addFile()

		function removeFile(fileCacheObj, fileNameInCache)
			% REMOVEFILE - remove a file from the cache
			%
			% REMOVEFILE(FILECACHEOBJ, FILENAMEINCACHE)
			%
			% Remove a file from the cache. FILENAMEINCACHE should be the name of a local
			% file in the cache.
			%
				[lockfid,key] = fileCacheObj.binaryTable.getLock();
				[row,wouldbe] = fileCacheObj.binaryTable.findRow(1,fileNameInCache);
				if ~row,
					fileCacheObj.binaryTable.releaseLock(lockfid,key);
					error(['File ' filename ' is not in file cache manifest.']);
				end;
				p = fileCacheObj.getProperties();
				szHere = fileCacheObj.binaryTable.readRow(row,3);
				fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,p.currentSize - szHere);
				fileCacheObj.binaryTable.deleteRow(row);
				delete(fullfile(fileCacheObj.directoryName,fileNameInCache));
				fileCacheObj.binaryTable.releaseLock(lockfid,key);
		end; % removeFile

		function clear(fileCacheObj)
			% CLEAR - remove all files from fileCache object 
			%
			% CLEAR(FILECACHEOBJ) 
			%
			% Clear all files in the cache. Use with caution!
			%
				[lockfid,key] = fileCacheObj.binaryTable.getLock();
				fn = fileCacheObj.fileList(false); 
				data = {};
				fileCacheObj.binaryTable.writeTable(data);
				fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,uint16(0));
				fullnames = fullfile(fileCacheObj.directoryName,fn)
				if ~isempty(fullnames),
					delete(fullnames{:});
				end;
				fileCacheObj.binaryTable.releaseLock(lockfid,key);
		end; 

		function b = isFile(fileCacheObj, fileNameInCache)
			% ISFILE - is this file in the cache?
			%
			% B = ISFILE(FILECACHEOBJ, FILENAMEINCACHE)
			%
			% Returns 1 if the file FILENAMEINCACHE is in the cache and
			% 0 otherwise. FILENAMEINCACHE should be the name of a file only
			% without a path.
				b=(fileCacheObj.binaryTable.findRow(1,fileNameInCache)>0);
		end; % isFile()

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

				this_function_made_lockfile = 0;

				iFileName = infoFileName(fileCacheObj);

				if useCatalog,
					% lock for sequential ops, will save a little time
					[lockfid,key] = fileCacheObj.binaryTable.getLock();
					fn = fileCacheObj.binaryTable.readRow(Inf,1);
					lastAccess = fileCacheObj.binaryTable.readRow(Inf,2);
					sz = fileCacheObj.binaryTable.readRow(Inf,3);
					fileCacheObj.binaryTable.releaseLock(lockfid,key);
				else,
					d = dir(fileCacheObj.directoryName);
					fileIndexes = find([d.isdir]==0);
					d = d(fileIndexes);
					% leave hidden files
					include = [];
					for i=1:numel(d),
						if d(i).name(1)~='.',
							include(end+1) = i;
						end;
					end;
					d = d(include);
					fn = {d.name};
					sz = [d.bytes];
					lastAccess = NaN*sz;
				end;

		end; % fileList()

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

				if ~iscell(newFileName),
					newFileName = {newFileName};
				end;

				if sum(newFileSize)>fileCacheObj.maxSize,
					error(['New files to be added exceed cache allowed size by themselves.']);
				end;

				[lockfid,key] = fileCacheObj.binaryTable.getLock();
				fileCacheProperties = fileCacheObj.getProperties();
				newTotalSize = fileCacheProperties.currentSize + sum(newFileSize);
			
				if newTotalSize>fileCacheObj.maxSize,
					% we are full! must delete!
					%disp(['We are full! must delete...']);
					[fn,sz,lastaccess] = fileCacheObj.fileList(true);
					[la_sorted,la_indexes] = sort(lastaccess,'descend');
					cutoff = find(sum(newFileSize)+cumsum(sz(la_indexes))>fileCacheObj.reduceSize,1,'first');
					DC = mat2cell(fn(la_indexes(cutoff:end),:),repmat(1,-cutoff+numel(la_indexes)+1,1),fileCacheObj.fileNameCharacters);
					ffn = fullfile(fileCacheObj.directoryName, DC);
					delete(ffn{:});

					% now re-organize

					newfn = mat2cell(fn(la_indexes(1:cutoff-1),:),repmat(1,cutoff-1,1),size(fn,2));
					sz = sz(la_indexes(1:cutoff-1));
					lastaccess = lastaccess(la_indexes(1:cutoff-1));
					newfn = cat(1,newfn,newFileName);
					sz = cat(1,sz(:),newFileSize(:));
					lastaccess = cat(1,lastaccess(:),repmat(now,numel(newFileSize),1));
					[newfn,sortorder] = sort(newfn); % sort by file name
					tabledata = {};
					for i=1:numel(newfn),
						tabledata{i,1} = newfn{i};
						tabledata{i,2} = lastaccess(sortorder(i)); 
						tabledata{i,3} = sz(sortorder(i));
					end;
					fileCacheObj.binaryTable.writeTable(tabledata);
					fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,sum(sz));
				else,
					%disp(['Not full, total size is ' int2str(newTotalSize) ' and maxSize is ' int2str(fileCacheObj.maxSize) '.']);
					for i=1:numel(newFileName),
						data_here{i} = newFileName{i};
						data_here{2} = now;
						data_here{3} = newFileSize(i);
						[row,insertSpot] = fileCacheObj.binaryTable.findRow(1,newFileName{i},'sorted',true);
						fileCacheObj.binaryTable.insertRow(insertSpot,data_here);
					end;
					fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,newTotalSize);
				end;
				fileCacheObj.binaryTable.releaseLock(lockfid,key);
		end; % resize

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
				if row,
					fileCacheObj.binaryTable.writeEntry(row,2,now());
					b = 1;
				end;
				fileCacheObj.binaryTable.releaseLock(lockfid,key);
		end; % touch()

	end; % methods

	methods (Access=protected)

		function iFileName = infoFileName(fileCacheObj)
			% INFOFILENAME - return the name of the cache information file
			% 
			% IFILENAME = INFOFILENAME(FILECACHEOBJ)
			%
			% Return the name of the cache information file for a fileCacheObj
			%
				iFileName = fullfile(fileCacheObj.directoryName,did.file.fileCache.cacheInfoFileName);
		end; % infoFileName()

	end;

end % classdef
