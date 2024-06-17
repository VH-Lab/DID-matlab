classdef fileCache < handle
% FILECACHE Implements a file cache directory with a maximum size and file removal with descending access time
% 

	properties (SetAccess=protected)
		directoryName (1,:) char % Full-path directory where the cache is stored
		fileNameCharacters (1,1) uint16 {mustBeGreaterThanOrEqual(fileNameCharacters,32)} = 32 % Number of characters allowed in a fileName (uint16)
		maxSize (1,1) uint64 {mustBeGreaterThanOrEqual(maxSize,10e3)} = 100e9 % maximum size for the cache in bytes (uint64)
		reduceSize (1,1) uint64 {mustBeGreaterThanOrEqual(reduceSize,8e3)} = 80e9 % size to be achieved when files need to be removed
	end

	properties (Constant)
		cacheInfoFileName = '.fileCacheInfo';
		cacheInfoLockFileName = '.fileCacheInfo-lock';
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
					fielCacheObj.reduceSize = savedFileCacheParams.reduceSize;
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
					fileCacheObj = fileCacheObj.setProperties(fileCacheObj.maxSize, fileCacheObj.reduceSize);
				end;

		end; % fileCache

		function fileCacheObj = setProperties(fileCacheObj, maxSize, reduceSize)
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
					reduceSize (1,1) uint64 {mustBeGreaterThanOrEqual(reduceSize,8e3),mustBeLessThan(reduceSize,maxSize)} = 80e9
				end

				if reduceSize>=maxSize,
					error(['reduceSize must be less than maxSize.']);
				end;

				lFileName = lockFileName(fileCacheObj);
				iFileName = infoFileName(fileCacheObj);
				[lockfid,key] = vlt.file.checkout_lock_file(lFileName, 30, 0, 60); % lock file expires in 60 seconds
				if lockfid>0,
					% we have the lock
					fid = fopen(iFileName,'w','ieee-le');
					if fid>0,
						fwrite(fid,fileCacheObj.fileNameCharacters,'uint16');
						fwrite(fid,[maxSize reduceSize],'uint64');
						fclose(fid);
						fileCacheObj.maxSize = maxSize;
						fileCacheObj.reduceSize = reduceSize;
					else,
						vlt.file.release_lock_file(lFileName,key);
						error(['Could not write to the cache info file ' iFileName '.']);
					end;
					vlt.file.release_lock_file(lFileName,key);
				else,
					error(['Unable to set properties. Cache lock file access could not be obtained: ' lFileName '.']);
				end;
		end; % SETPROPERTIES

		function filecacheinfo = getProperties(fileCacheObj)
			% GETPROPERTIES - read fileCache object properties from the info file
			%
			% FILECACHEINFO = GETPROPERTIES(FILECACHEOBJ)
			% 
			% Read the fileCacheObj properties that are stored on disk. 
			% FILECACHEINFO is a structure with the properties and values.
			%
				iFileName = infoFileName(fileCacheObj);
				fid = fopen(iFileName,'r','ieee-le');
				if fid>0,
					filecacheinfo.fileNameCharacters = fread(fid,1,'uint16');
					filecacheinfo.maxSize = fread(fid,1,'uint64');
					filecacheinfo.reduceSize = fread(fid,1,'uint64');
					fclose(fid);
				else,
					error(['Unable to get properties. Cache info file access could not be obtained: ' siFileName '.']);
				end;
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

		function [fn,sz,lastAccess] = fileList(fileCacheObj, useCatalog, varargin)
			% FILELIST - retrieve the files and sizes in the cache
			%
			% [FN,SZ,LASTACCESS] = FILELIST(FILECACHEOBJ, [USECATALOG])
			%
			% Return a list of filenames in FILECACHEOBJ. 
			%
			% FN is a cell array of file names, and SZ is an array of the
			% corresponding file sizes. That is, SZ(i) is the size (in bytes)
			% of the file FN{i}. LASTACCESS is a vector of DATENUM values (see NOW) of
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
					options.lockfid (1,1) double = NaN % undocumented option
					options.lockFileKey (1,:) char = '';
				end

				this_function_made_lockfile = 0;

				lFileName = lockFileName(fileCacheObj);
				iFileName = infoFileName(fileCacheObj);

				if useCatalog,
					if isnan(options.lockfid), % we did not make the lockfile, let's grab it so the data can't change while we are reading it
						[lockfid,key] = vlt.file.checkout_lock_file(lFileName, 30, 0, 60); % lock file expires in 60 seconds
						if lockfid>0,
							% we have the lock, continue
						else,
							error(['Could not gain access to the lock file ' lFileName '.']);
						end;
					end;
					% now we have the lock file, so open the info file
					fid = fopen(iFileName,'r','ieee-le');
					if fid>0,
						
						% do something
					end;
	
					if this_function_made_lockfile,
	                                        vlt.file.release_lock_file(lFileName,key);
					end;


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

				[fn,sz,lastaccess] = fileCacheObj.fileList(true);
				if sum(sz)+sum(newFileSize)>fileCacheObj.maxSize,
					[la_sorted,la_indexes] = sort(lastaccess);
					cutoff = find(sum(newFileSize)+cumsum(sz(la_indexes))>fileCacheObj.reduceSize,'first');
					fileCacheObj.removeFile(fn(la_indexes(1:cutoff)));
				end;
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

		function lFileName = lockFileName(fileCacheObj)
			% LOCKFILENAME - return the name of the lock file
			% 
			% LFILENAME = LOCKFILENAME(FILECACHEOBJ)
			%
			% Return the name of the lock file for a fileCacheObj
			%
				lFileName = fullfile(fileCacheObj.directoryName,did.file.fileCache.cacheInfoLockFileName);
		end; % lockFileName()

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

	methods static
		function properties = loadFileCacheProperties(filename)
			% LOADFILECACHEPROPERTIES - load properties for a fileCache object
			%
			%  PROPERTIES = LOADFILECACHEPROPERTIES(FILENAME)
			%
			% Load the properties from a fileCache object directory.
			%
				properties = [];

				if ~isfile(filename), 
					return;
				end;

				fid = fopen(filename,'r','ieee-le');
				if fid<0,
					error(['Problem opening ' filename ' for reading.']);
				end;

				properties.fileNameCharacters = fread(fid,1,'uint16');
				properties.maxSize = fread(fid,1,'uint64');
				properties.reduceSize = fread(fid,1,'uint64');

				fclose(fid);

		end; % loadFileCacheProperties()

	end


end % classdef
