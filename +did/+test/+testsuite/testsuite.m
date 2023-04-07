function output = testsuite
% TESTSUITE - run a suite of tests
%
% OUTPUT = did.test.testsuite
%
% Loads a set of test suite instructions in the file
% 'testsuite_list.txt'. This file is a tab-delimited table
% that can be loaded with vlt.file.loadStructArray with fields
% Field name          | Description
% --------------------------------------------------------------------------
% code                | The code to be run (as a Matlab evaluation)
% runit               | Should we run it? 0/1
% comment             | A comment string describing the test
%
% OUTPUT is a structure of outcomes. It includes the following fields:
% Field name          | Description
% --------------------------------------------------------------------------
% outcome             | Success is 1, failure is 0. -1 means it was not run.
% errormsg            | Any error message
%
% based on ndi.test.ndi_testsuite

w = which('did.test.testsuite.testsuite');
p = fileparts(w);
jobs = vlt.file.loadStructArray([p filesep 'testsuite_list.txt']);

output = vlt.data.emptystruct('outcome','errormsg');

for i=1:numel(jobs),
	output_here = output([]);
	output_here(1).errormsg = '';
	output_here(1).outcome = 0;
	if jobs(i).runit,
		try,
			eval(jobs(i).code);
			output_here(1).outcome = 1;
        catch lasterr
			output_here(1).errormsg = lasterr.message;
		end;
	else,
			output_here(1).outcome = -1; % not run
	end;
	output(i) = output_here;
end

disp(newline);
disp(newline);
disp(['--------------------------------------------']);
disp(newline);
disp('TESTSUITE OUTCOME');

for i=1:numel(output),
	if output(i).outcome>0,
		beginstr = ['  SUCCESS: '];
		endstr = '';
	elseif output(i).outcome==0,
		beginstr = ['  FAILURE: '];
		endstr = ['Error: ' output(i).errormsg];
	end;
	if output(i).outcome >= 0, 
		disp([beginstr jobs(i).code ' (' jobs(i).comment ')']);
		if ~isempty(endstr),
			disp(['      ' endstr]);
		end
	end;
end;
