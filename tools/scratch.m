%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   IDLE. Nothing to run right now -- this file is deliberately left in the
%   repo between uses so the next person finds the workflow instead of
%   rediscovering that these containers have no MATLAB.
%
%   TO USE IT: replace the body below with whatever you need to SEE -- disp()
%   the struct, size() the array, print the fieldnames -- then push. A push
%   that touches this file runs it and prints to the workflow log; it gates
%   nothing and exits 0 even on a throw, so an error reports its identifier,
%   message and stack instead of a bare red X.
%
%   IT HAS ALREADY PAID FOR ITSELF. #63's family counter was reverted once as
%   "undiagnosable" on the strength of a pass/fail result. Probe 2 printed the
%   detection logic step by step and showed it was RIGHT; probe 3 printed the
%   report and showed the counts were being computed and then never assigned
%   to it. Neither round was guesswork, and neither was possible without a way
%   to print.

fprintf('scratch.m is idle -- nothing to run.\n');
