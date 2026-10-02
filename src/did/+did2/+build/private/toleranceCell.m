function [cell, approximate] = toleranceCell(cell, tol, approximate, optName)
%TOLERANCECELL Put a `tolerance {minus, plus}` on a value cell (CHANGE 7).
%
%   [CELL, APPROXIMATE] = toleranceCell(CELL, TOL, APPROXIMATE, OPTNAME) sets
%   CELL.tolerance from TOL = [minus plus] (both >= 0, finite, in the cell's
%   canonical unit; for a time, minus = EARLIER and plus = LATER). An empty TOL
%   leaves CELL alone. A non-zero tolerance with APPROXIMATE not given sets
%   APPROXIMATE true: a bound refines `approximate`, it does not contradict it.
%   OPTNAME names the option in error messages.
if isempty(tol)
    return;
end
if ~isnumeric(tol) || numel(tol) ~= 2 || any(~isfinite(tol(:))) || any(tol(:) < 0)
    error('did2:build:badTolerance', ...
        '''%s'' must be [minus plus], two non-negative finite numbers in the canonical unit.', optName);
end
cell.tolerance = struct('minus', double(tol(1)), 'plus', double(tol(2)));
if isempty(approximate) && any(tol(:) > 0)
    approximate = true;
end
end
