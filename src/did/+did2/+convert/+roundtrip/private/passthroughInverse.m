function [v1, spec] = passthroughInverse(bodies, v1Class)
%PASSTHROUGHINVERSE The v1 document of a class pass 1 passes through
%   unchanged: the one emitted body, with v1_to_v2's outbound renames undone.
%
%   [V1, SPEC] = passthroughInverse(BODIES, V1CLASS). BODIES must be ONE
%   document of class V1CLASS (the raw passthrough keeps v1's class name); V1
%   is it with the `session_id` edge back in base.session_id and
%   creation_timestamp back in base.datestamp (private/undoOutbound). Anything
%   else is unplaced.
%
%   See also did2.convert.roundtrip.check, undoOutbound.

spec = emptySpec();
v1 = struct();
if isscalar(bodies) && strcmp(classNameOf(bodies{1}), v1Class)
    v1 = undoOutbound(bodies{1});
    return;
end
spec.unplaced{end+1} = sprintf('%d emitted document(s); pass 1 passes a %s through as one', ...
    numel(bodies), v1Class);
end
