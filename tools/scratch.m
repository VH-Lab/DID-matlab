%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE 12: THE ORIDIR HALF-HEIGHT VALUES THE NEW WRITER GIVES THE MOCK
%   CURVE ([oridir half-height values], Jess Haley, 2026-11-09; DID-matlab
%   #423). NDIcalc-vis-matlab 8d95413's oridir_vectorindexes computes
%   half_low, half_high and fwhh with vis.oridir.index.compute_fwhh and
%   bandwidth with vis.oridir.index.compute_bandwidth, both with 'Period'
%   360, on response.curve = [direction; mean], the same direction and mean
%   the calculator stores in tuning_curve. Run here on the stored curve of
%   tests/+did2/fixtures/ndi_writer_outputs/oridirtuning_calc.mock.1.json
%   (written by NDIcalc-vis-matlab 00e3e0f, before the four fields), the
%   values the new writer gives that curve, printed with %.17g.

calcDir = fullfile(tempdir, 'NDIcalc-vis-matlab');
if ~isfolder(calcDir)
    [st, out] = system(['git clone -q https://github.com/VH-Lab/NDIcalc-vis-matlab.git "' calcDir '"']);
    fprintf('clone: %d %s\n', st, out);
end
[st, out] = system(['git -C "' calcDir '" checkout -q 8d9541373b037dc27d198b84957b6a6c113552e5 && git -C "' calcDir '" rev-parse HEAD']);
fprintf('NDIcalc-vis-matlab at: %d %s\n', st, out);
addpath(calcDir);
m = jsondecode(fileread(fullfile('tests', '+did2', 'fixtures', 'ndi_writer_outputs', ...
    'oridirtuning_calc.mock.1.json')));
tc = m.orientation_direction_tuning.tuning_curve;
angles = tc.direction(:)';
resp = tc.mean(:)';
fprintf('max(angles) = %g (direction curve when > 180)\n', max(angles));
[fwhh, low, high] = vis.oridir.index.compute_fwhh(angles, resp, 'Period', 360);
bw = vis.oridir.index.compute_bandwidth(angles, resp, 'Period', 360);
fprintf('\n==== PROBE 12 VERDICT ====\n');
fprintf('  half_low   %.17g\n', low);
fprintf('  half_high  %.17g\n', high);
fprintf('  fwhh       %.17g\n', fwhh);
fprintf('  bandwidth  %.17g\n', bw);
% the not-found case the writer documents: a curve that never falls to half
flat = ones(size(resp));
[f2, l2, h2] = vis.oridir.index.compute_fwhh(angles, flat, 'Period', 360);
b2 = vis.oridir.index.compute_bandwidth(angles, flat, 'Period', 360);
fprintf('  flat curve: half_low %.17g half_high %.17g fwhh %.17g bandwidth %.17g\n', l2, h2, f2, b2);
