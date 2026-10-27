function [v1, spec] = stimulus_parameter(bodies)
%STIMULUS_PARAMETER Rebuild a v1 `stimulus_parameter` from what the migration
%   made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.stimulus_parameter(BODIES). Pass 1 keeps
%   the document as it is (its decided target is built by no migrator yet),
%   removing only a `value` that is empty text (the template's placeholder, not
%   set). BODIES is that one document; V1 is it with v1_to_v2's outbound
%   renames undone (private/undoOutbound). A removed empty value is not set in
%   v1 either.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.stimulus_parameter.

arguments
    bodies cell
end

[v1, spec] = passthroughInverse(bodies, 'stimulus_parameter');
end
