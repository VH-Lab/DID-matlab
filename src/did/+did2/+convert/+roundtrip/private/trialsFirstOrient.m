function x = trialsFirstOrient(x)
%TRIALSFIRSTORIENT A per-trial array back in v1's order, trials x stimuli: the
%   migrator wrote stimuli x trials (#88 audit 2, D3) by transposing a matrix
%   (a vector, one trial or one stimulus, was not transposed and is not here).
if (isnumeric(x) || islogical(x)) && ismatrix(x) && ~isvector(x)
    x = x.';
end
end
