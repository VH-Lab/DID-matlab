did_root_path = '/Users/eivihe/Documents/MATLAB/NDI/tools/DID-matlab/src';
vlt_root_path = '/Users/eivihe/Code/MATLAB/General/Repositories/ehennestad/vhlab-toolbox-matlab/src';

L1 = dir(fullfile(did_root_path, '+did', '+datastructures'));
L1 = dirstrip(L1);

filesA = fullfile({L1.folder}, {L1.name});
filesB = strrep(filesA, L1(1).folder, fullfile(vlt_root_path, '+vlt', '+data'));

i=17
visdiff(filesA{i}, filesB{i})

% Todo: Same for did.file / vlt.file...
