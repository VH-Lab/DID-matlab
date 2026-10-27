function [v1, spec] = stimulus_presentation(bodies)
%STIMULUS_PRESENTATION The round trip of a v1 `stimulus_presentation` in DID's
%   pass 1.
%
%   [V1, SPEC] = did2.convert.roundtrip.stimulus_presentation(BODIES). Pass 1
%   carries every such document whole as v1 (carry-045, [stimulus_presentation
%   retired]): did2.convert.roundtrip.check compares a carry itself and never
%   calls this inverse. The manipulation and methods it becomes are made by
%   NDI's second pass, in NDI-matlab, and are inverted there if anywhere. So
%   anything handed here is a pass-1 emission that should not exist, and every
%   document is reported unplaced.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.stimulus_presentation.

arguments
    bodies cell
end

spec = emptySpec();
v1 = struct();
for k = 1:numel(bodies)
    spec.unplaced{end+1} = sprintf(['emitted document %d (%s): pass 1 carries a ' ...
        'stimulus_presentation whole as v1'], k, classNameOf(bodies{k}));
end
if isempty(bodies)
    spec.unplaced{end+1} = 'nothing was emitted';
end
end
