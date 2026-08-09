%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   IDLE. Nothing to run right now -- this file stays in the repo between uses
%   so the next person finds the workflow instead of rediscovering that these
%   containers have no MATLAB.
%
%   TO USE IT: replace the body below with whatever you need to SEE, then push.
%   A push touching this file runs it and prints to the workflow log; it gates
%   nothing and exits 0 even on a throw, so an error reports its identifier,
%   message and stack rather than a bare red X.
%
%   IT KEEPS PAYING FOR ITSELF.
%     probe 2/3  #63's family counter was reverted once as "undiagnosable" on
%                the strength of a pass/fail result. Probe 2 showed the
%                detection logic was RIGHT; probe 3 showed the counts were
%                computed and then never assigned to the report.
%     probe 5    printed MATLAB's empty shapes instead of guessing at them:
%                unique([]) is 0-by-1, so `for n = unique([])` iterates ONCE.
%                That is where a phantom row in the corpus census came from.

fprintf('scratch.m is idle -- nothing to run.\n');
