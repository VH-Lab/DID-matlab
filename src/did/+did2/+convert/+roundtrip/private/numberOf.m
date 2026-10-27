function v = numberOf(x)
%NUMBEROF X as a scalar double when it is a finite number; [] otherwise.
v = [];
x = firstOf(x);
if isnumeric(x) && ~isempty(x) && isfinite(double(x(1)))
    v = double(x(1));
end
end
