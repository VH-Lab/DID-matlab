function [v1, spec] = orientation_direction_tuning(bodies)
%ORIENTATION_DIRECTION_TUNING Rebuild a v1 `orientation_direction_tuning` from
%   what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.orientation_direction_tuning(BODIES).
%   V1 is the document in NDI's v1 shape (orientation_direction_tuning.json +
%   base.json at the locked NDI-matlab `main`, 3cb19a8, as ndi.app.oridirtuning
%   writes it, with the app's block). BODIES holds the
%   `orientation_direction_tuning_calculation` (id preserved), the session
%   anchor, the software entity and the run's operating_system / interpreter
%   entities: the result block is rebuilt by private/tuningBlock and the edges
%   and app block by private/tuningInverse, as for oridirtuning_calc
%   (did2.convert.roundtrip.oridirtuning_calc), whose result block is this
%   class.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.orientation_direction_tuning.

arguments
    bodies cell
end

[v1, spec] = tuningInverse(bodies, 'orientation_direction_tuning_calculation', ...
    'orientation_direction_tuning', 'ndi.calc.vis.oridir', 'oridir', ...
    'orientation_direction_tuning', 'stimulus_tuningcurve_id');
end
