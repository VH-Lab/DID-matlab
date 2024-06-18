classdef fileCache < handle
% FILECACHE Implements a file cache directory with a maximum size and file removal with descending access time
% 

	properties (SetAccess=protected)
		directoryName (1,:) char % Full-path directory where the cache is stored
		fileNameCharacters (1,1) uint16 {mustBeGreaterThanOrEqual(fileNameCharacters,32)} = 32 % Number of characters allowed in a fileName (uint16)
		maxSize (1,1) uint64 {mustBeGreaterThanOrEqual(maxSize,10e3)} = 100e9 % maximum size for the cache in bytes (uint64)
		reduceSize (1,1) uint64 {mustBeGreaterThanOrEqual(reduceSize,8e3)} = 80e9 % size to be achieved when files need to be removed
		currentSize (1,1) uint64 {mustBeGreaterThanOrEqual(currentSize,0)} = 0
		binaryTable (1,1) 
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
					fileNameCharacters = uint16(32)
					maxSize = uint64(100e9)
					reduceSize = uint64(80e9)
				end

				fileCacheObj.directoryName = directoryName;

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
					maxSize (1,1) uint64 {mustBeGreaterThanOrEqual(maxSize,10e3)} = 100e9
					reduceSize (1,1) uint64 {mustBeGreaterThanOrEqual(reduceSize,8e3)} = 80e9
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
						[33*1 8 8], ... % size of these entries
						2+8+8+8); % headerSize: fileNameCharacters (uint16) + maxSize & reduceSize & totalSize (uint64)
					h1 = typecast(uint16(fileCacheObj.fileNameCharacters),'uint8');
				else, % retrieve the fileCharacter number from the existing header
					hd = fileCacheObj.binaryTable.readHeader();
					h1 = typecast(hd(1:2),'uint16');
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
				hd = fileCacheObj.binaryTable.readHeader();
				fileCacheInfo.maxSize = typecast(hd(1:2),'uint16');
				fileCacheInfo.maxSize = typecast(hd(3:10),'uint64');
				fileCacheInfo.reduceSize = typecast(hd(11:18),'uint64');
				fileCacheInfo.currentSize = typecast(hd(19:26),'uint64');
				
		end; % GETPROPERTIES

		function addFile(fileCacheObj, fullPathFileName)
			% ADDFILE - add a file to the cache
			%
			% ADDFILE(FILECACHEOBJ, FULLPATHFILENAME)
			%
			% Add a file to the cache. The file at FULLPATHFILENAME is moved 
			% into the cache. If adding the file would cause the cache to be
			% overfull, then files are deleted from the cache.
			%
			% The file at FULLPATHFILENAME should be outside of the cache.
			%
				arguments
					fileCacheObj (1,1)
					filename char {isFile} 
				end

		end; % addFile()

		function removeFile(fileCacheObj, filename)
			% REMOVEFILE - remove a file from the cache
			%
			% REMOVEFILE(FILECACHEOBJ, FILENAME)
			%
			% Remove a file from the cache. FILENAME should be the name of a local
			% file in the cache.

		end; % removeFile

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
					fileIndexes = find([d.isDir]==0);
					d = d(fileIndexes);
					fn = {d.name};
					sz = [d.size];
					lastAccess = NaN*sz;
				end;

		end; % fileList()

		function resize(fileCacheObj, newFileSize)
			% RESIZE - resize the cache if needed by deleting files
			%
			% RESIZE(FILECACHEOBJ, NEWFILESIZE)
			%
			% If needed, delete files from the cache (starting from the
			% least recently accessed) to make room for a file of NEWFILESIZE
			% in bytes.  NEWFILESIZE can be a scalar (if a single file is to be added)
			% or an array.
			%
				arguments
					fileCacheObj
					newFileSize {mustBeVector} uint64 = 0
				end

				if sum(newFileSize)>fileCacheObj.maxSize,
					error(['New files to be added exceed cache allowed size by themselves.']);
				end;

				[lockfid,key] = fileCacheObj.binaryTable.getLock();
				[fn,sz,lastaccess] = fileCacheObj.fileList(true);
				if sum(sz)+sum(newFileSize)>fileCacheObj.maxSize,
					% we are full! must delete!
					[la_sorted,la_indexes] = sort(lastaccess);
					cutoff = find(sum(newFileSize)+cumsum(sz(la_indexes))>fileCacheObj.reduceSize,'first');
					DC = mat2cell(fn(la_indexes(1:cutoff),:),repmat(1,cutoff,1),fileCacheObj.fileNameCharacters);
					ffn = fullfile(fileCacheObj.directoryName, DC);
					delete(ffn);

					% now re-organize
					newfn = mat2cell(fn(la_indexes(cutoff+1:end)),repmat(1,numel(sz)-cutoff,1),size(fn,2));
					sz = sz(la_indexes(cutoff+1:end));
					lastaccess = lastaccess(la_indexes(cutoff+1:end));
					[newfn,sortorder] = sort(newfn); % sort by file name
					sz = sz(sortorder);
					lastaccess = lastaccess(sortorder);
					tabledata = {};
					for i=1:numel(newfn),
						tabledata{i,1} = newfn{i};
						tabledata{i,2} = lastaccess(i); 
						tabledata{i,3} = sz(i);
					end;
					fileCacheObj.binaryTable.writeTable(tabledata);
					fileCacheObj.setProperties(fileCacheObj.maxSize,fileCacheObj.reduceSize,sum(sz));
				end;
				fileCacheObj.binaryTable.releaseLock(lockfid,key);
		end; % resize

		function touch(fileCacheObj, fileName)
			% TOUCH - mark a file as accessed right now
			%
			% TOUCH(FILECACHEOBJ, FILENAME)
			%
			% Indicate that a file has just been accessed. Updates the last access time
			% of FILENAME. FILENAME can be a scalar or cell array of file names.
			%
				argument
					fileCacheObj (1,1)
					fileName {mustBeText}
				end


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
