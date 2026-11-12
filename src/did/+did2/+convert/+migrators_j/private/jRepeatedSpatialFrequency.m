function reason = jRepeatedSpatialFrequency(block)
%JREPEATEDSPATIALFREQUENCY The known v1 defect of a contrast sensitivity result
%   whose spatial frequencies are all one value ('' when it has none).
%
%   REASON = jRepeatedSpatialFrequency(BLOCK), BLOCK the v1
%   contrastsensitivity_calc block. REASON is non-empty when the block lists
%   more than one spatial frequency and every one is the same number: its
%   per-frequency Naka-Rushton fits then repeat one fit. The rule is generic
%   (any dataset, any frequency). The document is migrated unchanged; the
%   caller lists REASON in the run's migration report as a known v1 defect of
%   `contrast_sensitivity.value.model_fit` (did2.convert.migrationReport
%   'defect'; [known v1 defects], Jess Haley, 2026-11-12, "A").
%
%   Why it happens: NDI-matlab +ndi/+calc/+stimulus/tuningcurve.m, with
%   exactly one dealt property, used index 1 on every pass, so every input
%   contrast tuning curve was made at the first spatial frequency (fixed in
%   NDI-matlab 49a875c94, 2026-10-14); ndi.calc.vis.contrast_sensitivity
%   copied them faithfully. Found in all 1,431 Soph contrastsensitivity_calc
%   documents.

reason = '';
if ~isstruct(block) || ~isscalar(block)
    return;
end
fn = fieldnames(block);
hit = find(strcmpi(fn, 'spatial_frequencies'), 1);
if isempty(hit)
    return;
end
sf = block.(fn{hit});
if ~isnumeric(sf) || numel(sf) < 2
    return;
end
sf = double(sf(:));
if ~all(sf == sf(1))
    return;
end
reason = ['All spatial frequencies in this v1 contrastsensitivity_calc are the same value, ' ...
    'so its per-frequency Naka-Rushton fits are repeats of one fit, not fits at different ' ...
    'spatial frequencies. Known v1 defect: the input contrast tuning curves were all made ' ...
    'at the first spatial frequency by NDI-matlab +ndi/+calc/+stimulus/tuningcurve.m, which, ' ...
    'with exactly one dealt property, used index 1 on every pass (fixed in NDI-matlab ' ...
    'commit 49a875c94, 2026-10-14). Migrated unchanged.'];
end
