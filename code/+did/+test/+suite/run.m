function output = run
% did.test.suite.run - run a suite of tests
%
% OUTPUT = did.test.suite.run
%
% Loads a set of test suite instructions in the file
% 'list.txt'. This file is a tab-delimited table
% that can be loaded with vlt.file.loadStructArray with fields
%
% Test functions must be of the form [success,msg] = testfunction()
% The function should return success==1 and msg=='' if they run
% successfully, and success==0 with an error message in msg if they fail.
% The test function can also throw an exception or error and it will be
% caught and processed as a failure. The function can also return an array of
% success and a corresponding cell array of msg values.
% 
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

w = which('did.test.suite.run');
p = fileparts(w);
jobs = vlt.file.loadStructArray([p filesep 'list.txt']); 

output = vlt.data.emptystruct('outcome','errormsg');

for i=1:numel(jobs),
	jobs(i).code = jobs(i).code(2:end-1);
	output_here = output([]);
	output_here(1).errormsg = '';
	output_here(1).outcome = 0;
	if jobs(i).runit,
		disp(['+++++  Running ' jobs(i).code ' (' jobs(i).comment ') ++++++' ])
		try,
			[b,msg] = eval(jobs(i).code);
			theb = '';
			if iscell(msg), % check that all succeed
				for j=1:numel(b),
					if b(j)==0,
						theb = b(j);
						themsg = msg{j};
						break;
					end;
				end;
				if isempty(theb),
					theb = b(j);
					themsg = '';
				end;
			else,
				theb = 1;
				themsg = msg;
			end;
			output_here(1).outcome = theb;
			output_here(1).errormsg = themsg;
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
disp('did.test.suite.run OUTCOME');

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

