function [v1, spec] = demoNDI(bodies)
%DEMONDI Rebuild a v1 `demoNDI` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.demoNDI(BODIES). BODIES is the `demo`
%   document +migrators_j/private/jDemoFold made of it (id preserved);
%   private/demoInverse says where each field comes from.
%
%   See also did2.convert.roundtrip.check.

arguments
    bodies cell
end

[v1, spec] = demoInverse(bodies, 'demoNDI');
end
