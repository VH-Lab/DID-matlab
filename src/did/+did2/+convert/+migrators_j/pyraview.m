function v2Body = pyraview(preBody)
%PYRAVIEW Brainstorm-J migrator: drop the retired `epochclocktimes` block.
%   Chunk (a) deleted the `epochclocktimes` class (its clock bounds duplicate
%   `element_epoch.clocks` / a `time_reference`). pyraview was a subclass, so v1
%   pyraview docs still carry an `epochclocktimes` block ({clocktype, t0_t1})
%   which is now undeclared. pyraview already includes the `epochid` mixin
%   directly (V_zeta chain: epochclocktimes, filter, base, epochid), so dropping
%   the block is all that is needed — the epoch identity is preserved on `epochid`.
%   (pyraview itself dissolves into a `data_body` in the 2.D collapse; this is the
%   interim fix so the reparented class validates.)

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if isfield(v2Body, 'epochclocktimes')
    v2Body = rmfield(v2Body, 'epochclocktimes');
end
end
