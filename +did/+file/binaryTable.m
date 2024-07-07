classdef binaryTable < handle

	% BINARYTABLE - a class that implements reading and writing to a binary table with regular columns and multi-thread protection

	properties (SetAccess=protected)
		file (1,1) did.file.fileobj
		recordType cell {mustBeVector,mustBeText} = cell(1,0) % Strings with column data types
		recordSize uint16 {mustBeVector} = zeros(1,0)  % Vector with byte size of each column
		elementsPerColumn uint16 {mustBeVector} = zeros(1,0)  % Vector with number of entries per column
		headerSize (1,1) uint16 {mustBeGreaterThanOrEqual(headerSize,0)} = 0 % Any header information to skip before reading the binary table
		hasLock (1,1) logical = false
	end

	methods 
		function binaryTableObj = binaryTable(f, recordType, recordSize, elementsPerColumn, headerSize)
			% BINARYTABLE - create a binaryTable object
			%
			% BINARYTABLEOBJ = BINARYTBALE(AFILEOBJ, RECORDTYPE, RECORDDSIZE, ELEMENTSPERCOLUMN, HEADERSIZE)
			%
			% Define a binaryTable object with parameters including:
			% 
			% AFILEOBJ is a type did.file.fileobj that holds the file name
			% RECORDTYPE is a cell array of the data types present in the table.
			% RECORDSIZE is an array with the size in bytes of each record in RECORDTYPE.
			% ELEMENTSPERCOLUMN is an array with number of datapoints in each column. For example, for a character array
			%   of N characters, ELEMENTSPERCOLUMN(i) = N. For a single number, ELEMENTS_PER_COLUMN(i) = 1.
			% HEADERSIZE is the amount of the beginning of the file to skip, in bytes.
			%
			% Example:
			%    bT = did.file.binaryTable(did.file.fileobj('fullpathfilename',[pwd filesep 'myBinTable.bin']),...
			%        {'char','double','uint64'},[33*1 8 8],[33 1 1],2+8+8+8);
			% 
				binaryTableObj.file = f;
				% always little endian for cross platform compatibility
				binaryTableObj.file = binaryTableObj.file.setproperties('machineformat','l'); 
				binaryTableObj.recordType = recordType;
				binaryTableObj.recordSize = recordSize;
				binaryTableObj.elementsPerColumn = elementsPerColumn;
				binaryTableObj.headerSize = headerSize;
				if isempty(binaryTableObj.file.fullpathfilename),
					error(['A full path file name must be given to the file object.']);
				end;
		end; % creator

		function [r,c,dataSize] = getSize(binaryTableObj)
			% GETSIZE - get the rows, columns, and total file size of a BINARYTABLE object
			%
			% [R,C,SZ] = GETSIZE(BINARYTABLEOBJ)
			%
			% Return file size parameters for BINARYTABLEOBJ with file identifier FID. 
			% FID must be an open file.
			%
			% R is the number of rows, C is the number of columns, and SZ is the total
			% file size in bytes.
			%
				arguments
					binaryTableObj
				end

				dataSize = 0;
				if isfile(binaryTableObj.file.fullpathfilename),
					d = dir(binaryTableObj.file.fullpathfilename);
					sz = d(1).bytes;
					dataSize = sz - binaryTableObj.headerSize;
				end;

				c = numel(binaryTableObj.recordSize);
				rowSize = sum(binaryTableObj.recordSize);
				r = dataSize/rowSize;
		end; % getSize()

		function headerData = readHeader(binaryTableObj)
			% READHEADER - read header information to binary data
			%
			% HEADERDATA = READHEADER(BINARYTABLEOBJ)
			%
			% Read the binary header data into a uint8 data
			% buffer.
			%
				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file.fclose();
				binaryTableObj.file = binaryTableObj.file.setproperties('permission','r');
				binaryTableObj.file.fopen();
				headerData = uint8(fread(binaryTableObj.file,binaryTableObj.headerSize,'uint8'));
				binaryTableObj.file.fclose();
				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % readHeader

		function writeHeader(binaryTableObj, headerdata)
			% WRITEHEADER - write header data to a binaryTable object
			%
			% WRITEHEADER(BINARYTABLEOBJ, HEADERDATA)
			%
			% Writes header data (uint8 data) to a binaryTable object.
			% HEADERDATA should not exceed the headerSize property of the 
			% binaryTable object.
			% No data is touched in the file beyond that specified by
			% HEADERDATA. (For example, the rest of the header space, if
			% there is any, is not cleared or altered in any way.)
			%
			% The header allows the user to save custom information about the
			% table.
			%
				if numel(headerdata)>binaryTableObj.headerSize,
					error(['Header data to write is larger ' int2str(numel(headerdata)) ...
						' than the header size of the file ' int2str(binaryTableObj.headerSize) '.']);
				end;
				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file.fclose();
				if isfile(binaryTableObj.file.fullpathfilename),
					binaryTableObj.file = binaryTableObj.file.setproperties('permission','r+');
				else,
					binaryTableObj.file = binaryTableObj.file.setproperties('permission','w');
				end;
				binaryTableObj.file.fopen();
				fwrite(binaryTableObj.file,headerdata,'uint8');
				binaryTableObj.file.fclose();
				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % writeHeader

		function [lockfid,key] = getLock(binaryTableObj)
			% GETLOCK - obtain the lock file to ensure only one process writes to binaryTableObj at a time
			%
			% [LOCKFID, KEY] = GETLOCK(BINARYTABLEOBJ)
			%
			% Return the key to the lock file associated with the binaryTable object.
			%
			% If a new lock had to be checked out, then KEY contains the key.
			% Otherwise, KEY is empty.
			%
			% If checking out the lock file fails, an error is generated.
			%
				key = '';
				lockfid = [];
				if binaryTableObj.hasLock == false,
					[lockfid,key] = did.file.checkout_lock_file(binaryTableObj.lockFileName(),...
						30,1,20);
					binaryTableObj.hasLock = true;
				end;
		end; % 

		function releaseLock(binaryTableObj, lockfid, key)
			% RELEASELOCK - release the lock on the file
			%
			% RELEASELOCK(BINARYTABLEOBJ, LOCKFID, KEY)
			%
			% If LOCKFID and KEY are not empty, release the 
			% lock on the file associated with BINARYTABLEOBJ.
			%
				if ~isempty(key),
					did.file.release_lock_file(binaryTableObj.lockFileName(),key);
					binaryTableObj.hasLock = false;
				end;
		end;

		function lFileName = lockFileName(binaryTableObj)
			% LOCKFILENAME - return the lock file name for a binaryTable object
			%
			% LFILENAME = LOCKFILENAME(BINARYTABLEOBJ)
			%
			% Return the full path file name of the lock file associated with
			% the binaryTable object.
			%

				lFileName = [binaryTableObj.file.fullpathfilename '-lock'];
		end;

		function tFileName = tempFileName(binaryTableObj)
			% TEMPFILENAME - return the temporary file name for a binaryTable object
			%
			% TFILENAME = TEMPFILENAME(BINARYTABLEOBJ)
			%
			% Return the full path file name of the temporary file associated with
			% the binaryTable object.
			%
				tFileName = [binaryTableObj.file.fullpathfilename '-temp'];
		end;

		function s = rowSize(binaryTableObj)
			% ROWSIZE - row byte size
			%
			% S = ROWSIZE(BINARYTABLEOBJ)
			%
			% The size of each row of the binaryTable object file, in bytes.
			%
				s = sum(binaryTableObj.recordSize);
		end; % rowSize()

		function data = readRow(binaryTableObj, row, col)	
			% READROW - read row or rows from a particular column of a binaryTable object
			%
			% DATA = READROW(BINARYTABLEOBJ, ROW, COL)
			%
			% Read data from ROW of column COL from a binaryTable object
			%
			% ROW can be a vector of rows to read, Inf to indicate
			% that all rows should be read.
			%
			% It is assumed the FID is an open file and FID is left open at the conclusion.
			%
				arguments
					binaryTableObj
					row double {mustBeVector}
					col (1,1) uint16 {mustBePositive}
				end

				if col>numel(binaryTableObj.recordSize),
					error(['Column must be in 1..number of columns (' int2str(numel(binaryTableObj.recordSize)) ').']);
				end;

				% obtain the lock so the file can't change while we read it
				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file = binaryTableObj.file.setproperties('permission','r');
				binaryTableObj.file.fopen();

				[r,c] = binaryTableObj.getSize();
				if isinf(row), % read them all
					fseek(binaryTableObj.file, binaryTableObj.headerSize+sum(binaryTableObj.recordSize(1:col-1)), 'bof');
					skipBytes = binaryTableObj.rowSize()-binaryTableObj.recordSize(col);
					data = fread(binaryTableObj.file, Inf, ...
						[int2str(binaryTableObj.elementsPerColumn(col)) '*' binaryTableObj.recordType{col}], ...
						skipBytes);
					data = reshape(data,prod(size(data))/r,r)';
					data = feval(binaryTableObj.recordType{col},data);
				else,
					if any(row>r),
						binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
						error(['Rows must be in 1..' int2str(r) '.']);
					end;
					data = feval(binaryTableObj.recordType{col},zeros(numel(row),binaryTableObj.elementsPerColumn(col)));
					for i=1:numel(row),
 						status=fseek(binaryTableObj.file,...
							binaryTableObj.headerSize+(row(i)-1)*binaryTableObj.rowSize()+...
							sum(binaryTableObj.recordSize(1:col-1)),...
							'bof');
						if status~=0,
							binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
							error(['Row ' int2str(row(i)) ' is out of bounds.']);
						end;
						dRead = fread(binaryTableObj.file,binaryTableObj.elementsPerColumn(col),...
							binaryTableObj.recordType{col})'; % make sure to transpose
						data(i,:) = feval(binaryTableObj.recordType{col},dRead);
					end;
				end;
				binaryTableObj.file.fclose();
				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % readRow()

		function insertRow(binaryTableObj, insertAfter, dataCell)
			% INSERTROW- insert or add a row of data to a binaryTable object file
			%
			% INSERTROW(BINARYTABLEOBJ, INSERTAFTER, DATACELL)
			%
			% Insert a row of data after row INSERTAFTER. 
			% INSERTAFTER must be in 0..number of rows of BINARYTABLEOBJ.
			%
				arguments
					binaryTableObj
					insertAfter (1,1) {mustBeNonnegative}
					dataCell cell {mustBeVector}
				end

				[r,c] = binaryTableObj.getSize();

				if insertAfter>r+1,
					error(['Row must be in 0..number of rows (' int2str(r) ').']);
				end;

				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file.fclose();
				% now there are two strategies; if insertAfter == r, then we can append to the file
				% if not, we must copy the file

				if insertAfter==r, % append a new row
					binaryTableObj.file = binaryTableObj.file.setproperties('permission','a');
					binaryTableObj.file.fopen();
					for i=1:numel(binaryTableObj.recordType),
						binaryTableObj.file.fwrite(dataCell{1,i},binaryTableObj.recordType{i});
					end;
					binaryTableObj.file.fclose();
				else, % copy over everything to temp file before inserting and moving back
					binaryTableObj.file = binaryTableObj.file.setproperties('permission','r');
					binaryTableObj.file.fopen();
					beforeBytes = binaryTableObj.headerSize + insertAfter * binaryTableObj.rowSize();
					totalBytes = (binaryTableObj.headerSize + r * binaryTableObj.rowSize());
					bufferSize = 1e6; % 1 MB buffer
					copied = 0;
					fid = fopen(binaryTableObj.tempFileName(),'w');
					if fid<0,
						error(['Could not open temporary file for reading.']);
					end;
					while(copied<beforeBytes),
						chunkSize = min(bufferSize, beforeBytes-copied);
						[data,count] = fread(binaryTableObj.file,chunkSize,'uint8');
						if count~=chunkSize,
							warning('chunkSize not fully read.');
						end;
						fwrite(fid,data,'uint8');
						copied = copied + chunkSize;
					end;
					for i=1:numel(binaryTableObj.recordType),
						fwrite(fid,dataCell{1,i},binaryTableObj.recordType{i});
					end;
					while(copied<totalBytes),
						chunkSize = min(bufferSize, totalBytes-copied);
						[data,count] = fread(binaryTableObj.file,chunkSize,'uint8');
						if count~=chunkSize,
							warning('chunkSize not fully read.');
						end;
						fwrite(fid,data,'uint8');
						copied = copied + chunkSize;
					end;
					fclose(fid);
					binaryTableObj.file.fclose();
					movefile(binaryTableObj.tempFileName,binaryTableObj.file.fullpathfilename);
				end;

				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % insertRow()

		function deleteRow(binaryTableObj, row)
			% DELETEROW - delete a row from a binaryTable object
			%
			% DELETEROW(BINARYTABLEOBJ, ROW)
			%
			% Deletes the row ROW from the BINARYTABLE object.
			%
			% ROW must be in 1..number of rows (see BINARYTABLE.GETSIZE()).
			%
				arguments
					binaryTableObj
					row (1,1) {mustBePositive}
				end

				[r,c] = binaryTableObj.getSize();

				if row>r+1,
					error(['Row must be in 1..number of rows (' int2str(r) ').']);
				end;

				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file.fclose();
				binaryTableObj.file = binaryTableObj.file.setproperties('permission','r');
				binaryTableObj.file.fopen();
				beforeBytes = binaryTableObj.headerSize + (row-1) * binaryTableObj.rowSize();
				totalBytes = (binaryTableObj.headerSize + r * binaryTableObj.rowSize());
				bufferSize = 1e6; % 1 MB buffer
				copied = 0;
				fid = fopen(binaryTableObj.tempFileName(),'w');
				if fid<0,
					error(['Could not open temporary file for reading.']);
				end;
				while(copied<beforeBytes),
					chunkSize = min(bufferSize, beforeBytes-copied);
					[data,count] = fread(binaryTableObj.file,chunkSize,'uint8');
					if count~=chunkSize,
						warning('chunkSize not fully read.');
					end;
					fwrite(fid,data,'uint8');
					copied = copied + chunkSize;
				end;
				% skip the row to be deleted
 				status=fseek(binaryTableObj.file, binaryTableObj.headerSize+(row)*binaryTableObj.rowSize(), 'bof');
				copied = copied + binaryTableObj.rowSize();
				while(copied<totalBytes),
					chunkSize = min(bufferSize, totalBytes-copied);
					[data,count] = fread(binaryTableObj.file,chunkSize,'uint8');
					if count~=chunkSize,
						warning('chunkSize not fully read.');
					end;
					fwrite(fid,data,'uint8');
					copied = copied + chunkSize;
				end;
				fclose(fid);
				binaryTableObj.file.fclose();
				movefile(binaryTableObj.tempFileName,binaryTableObj.file.fullpathfilename);
				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % deleteRow()

		function writeEntry(binaryTableObj, row, col, value)
			% WRITEENTRY - overwrite an entry in a binaryTable object
			%
			% WRITEENTRY(BINARYTABLEOBJ, ROW, COL, VALUE)
			%
			% Overwrite the value of an entry in a binaryTable object.
			%
				if ~strcmp(class(value),binaryTableObj.recordType{col}),
					error(['Data value of wrong type.']);
				end;
				if numel(value)~=binaryTableObj.elementsPerColumn(col),
					error(['value is wrong size; should be 1x' intstr(binaryTableObj.elementsPerColumn(col)) '.']);
				end;
				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file.fclose();
				binaryTableObj.file = binaryTableObj.file.setproperties('permission','r+');
				binaryTableObj.file.fopen();

 				status=fseek(binaryTableObj.file,...
					binaryTableObj.headerSize+(row-1)*binaryTableObj.rowSize()+...
					sum(binaryTableObj.recordSize(1:col-1)),...
					'bof');
				if status~=0,
					binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
					error(['Row ' int2str(row(i)) ' is out of bounds.']);
				end;
				fwrite(binaryTableObj.file,value,binaryTableObj.recordType{col});
				binaryTableObj.file.fclose();
				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % writeEntry()

		function writeTable(binaryTableObj, data)
			% WRITETABLE - write (or re-write) a binaryTable obj table file
			%
			% WRITETABLE(BINARYTABLEOBJ, DATA)
			%
			% Write row and column data to a binaryTable object's file.
			% DATA{r,c} should be the data that should be written at row r
			% and column c. The data type of DATA{r,c} should match the data type
			% of the column.
			%
			% This function completely replaces the contents of the binaryTable.
			% Old values are lost. The information in the header is re-copied.
			%
				[lockfid,key] = binaryTableObj.getLock();
				binaryTableObj.file.fclose();
				binaryTableObj.file = binaryTableObj.file.setproperties('permission','r');
				binaryTableObj.file.fopen();
				fid = fopen(binaryTableObj.tempFileName(),'w');

				if fid<0,
					error(['Could not open temporary file for reading.']);
				end;

				% step 1: copy the header
				hd = binaryTableObj.readHeader();
				fwrite(fid,hd,'uint8');

				% step 2: write each row

				for r=1:size(data,1),
					for c = 1:size(data,2),
						fwrite(fid,data{r,c},binaryTableObj.recordType{c});
					end;
				end;

				fclose(fid);
				binaryTableObj.file.fclose();
				movefile(binaryTableObj.tempFileName,binaryTableObj.file.fullpathfilename);
				binaryTableObj.releaseLock(lockfid,key); % release if we checked out the lock
		end; % writeTable() 

		function [row,wouldBe] = findRow(binaryTableObj, col, value, option)
			% FINDROW - find data in an ordered column
			%
			% [ROW,WOULDBE] = FINDROW(BINARYTABLEOBJ, COL, VALUE)
			%
			% Find rows that match VALUE in column COL.
			%
			% ROW is the row index where VALUE occurs.
			% If the value is not found, then ROW is 0.
			%
			% If the column is sorted, WOULDBE is the row preceding
			% where VALUE would go if it were present. Otherwise WOULDBE is NaN.
			%
			% If the data are sorted, FINDROW will use that information
			% to perform a binary search to speed the process:
			%
			% ROW = FINDROW(BINARYTABLEOBJ, COL, VALUE, 'sorted', true)
			%
				arguments
					binaryTableObj
					col (1,1) uint16 {mustBePositive}
					value
					option.sorted (1,1) logical = false
					option.lower_bound (1,1) double = -Inf
					option.upper_bound (1,1) double = Inf
					option.isRecurrent logical = false
				end

				row = 0;
				wouldBe = NaN;

				if ~option.isRecurrent,
					[lockfid,key] = binaryTableObj.getLock();
					binaryTableObj.file.fclose();
					binaryTableObj.file = binaryTableObj.file.setproperties('permission','r');
					binaryTableObj.file.fopen();
				end;

				if ~option.sorted,
					% then we just have to read each entry one by one
					r = binaryTableObj.getSize();
					for i=1:r,
						data = binaryTableObj.readRow(i,col);
						if isequal(data,value),
							row = i;
							break;
						end;
					end;
				else,
					rTotal = binaryTableObj.getSize();
					if isinf(option.lower_bound),
						option.lower_bound = 1;
					end;
					if isinf(option.upper_bound),
						option.upper_bound = rTotal;
					end;

					r_look = floor(option.lower_bound + double(option.upper_bound-option.lower_bound)/2);
					if r_look < 1 | r_look > rTotal, % we are out of bounds, probably because there's no data
						row = 0;
						wouldBe = 0;
					else,
						v_here = binaryTableObj.readRow(r_look,col);
						c = did.file.binaryTable.compare(v_here,value);
						have_equality = 0;
						lastmove = 0;
						if option.upper_bound<=option.lower_bound,
							lastmove = 1;
						end;

						if c<0, % value here is greater than we are looking for
							new_upper_bound = r_look - 1;
							new_lower_bound = option.lower_bound;
						elseif c>0, % value_here is less than we are looking for
							new_lower_bound = r_look + 1;
							new_upper_bound = option.upper_bound;
						else, % equality!
							have_equality = 1;
						end;

						if ~have_equality & ~lastmove,
							[row,wouldBe] = binaryTableObj.findRow(col, value, 'sorted', true,...
								'lower_bound',new_lower_bound,'upper_bound',new_upper_bound,...
								'isRecurrent',true);
						else
							if have_equality,
								row = r_look;
							else, % is lastmovie
								wouldBe = r_look -1 *(c<0); % 
							end;
						end;
					end;
				end;
				if ~option.isRecurrent,
					binaryTableObj.file.fclose();
					binaryTableObj.releaseLock(lockfid,key);
				end;
		end; % findRow()
	end

	methods (Static)
		function c = compare(value1,value2)
			% COMPARE - compare two values for less than, greater than, or equal to
			%
			% C = COMPARE(VALUE1,VALUE2)
			%
			% Compares two values. If both values are scalars, then a simple comparison is made.
			% If both values are character arrays, then they are compared in alphabetical order.
			% If ehter value is a cell array, then the first entry is examined.
			%
			% If VALUE1 > VALUE2, c is -1.
			% If VALUE1 == VALUE2, c is 0.
			% If VALUE1 < VALUE2, c is 1.
			% 
				c = NaN;
				if iscell(value1),
					value1 = value1{1};
				end;
				if iscell(value2),
					value2 = value2{1};
				end;
				if isstring(value1),
					value1 = char(value1);
				end;
				if isstring(value2),
					value2 = char(value2);
				end;
				if isscalar(value1) & isscalar(value2),
					c = 1 * (value1<value2) - 1 * (value1>value2);
					if c==0,
						if value1~=value2,
							error(['VALUE1 and VALUE2 cannot be compared numerically.']);
						end;
					end;
				elseif ischar(value1) & ischar(value2),
					[~,x] = sort({value1,value2});
					c = diff(x) * ~strcmp(value1,value2);
				end;
				if isnan(c),
					error(['Could not make comparison.']);
				end;
			
		end; % compare
	end % static methods

end
