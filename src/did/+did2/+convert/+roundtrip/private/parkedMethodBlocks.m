function [blk, v1] = parkedMethodBlocks(blk, v1)
%PARKEDMETHODBLOCKS Move back what +migrators_j/private/jMethodParameters
%   parked in the parameter bag: the leftover of an `app` block that named no
%   software (spelled app_name / app_version there, as the renamed path spelled
%   it) and the epoch string of a document with no epoch document (`epochid`).
%
%   [BLK, V1] = parkedMethodBlocks(BLK, V1). BLK is the bag rebuilt by
%   methodParameters; V1 the document being rebuilt. `app` and `epochid` leave
%   BLK for V1.app and V1.epochid.epochid.
%
%   See also did2.convert.roundtrip.sorting_parameters, methodDocParts.

if isfield(blk, 'app') && isstruct(blk.app)
    a = blk.app;
    for f = {'name', 'version'}
        if isfield(a, ['app_' f{1}])
            a.(f{1}) = a.(['app_' f{1}]);
            a = rmfield(a, ['app_' f{1}]);
        end
    end
    v1.app = a;
    blk = rmfield(blk, 'app');
end
if isfield(blk, 'epochid')
    v1.epochid = struct('epochid', blk.epochid);
    blk = rmfield(blk, 'epochid');
end
end
