function b = jBase(id, sessionId, name, datestamp)
%JBASE Build a V_eta `base` block, with the sentinel rule in ONE place.
%
%   B = jBase(ID, SESSIONID, NAME, DATESTAMP) returns the struct every emitted
%   V_eta body needs as its `base` block. All four arguments are optional in
%   the sense that '' is accepted for each; what is NOT optional is the shape,
%   which is why this exists.
%
%   ---------------------------------------------------------------------
%   WHY A HELPER, WHEN THE BLOCK IS FOUR FIELDS
%   ---------------------------------------------------------------------
%   Because the four fields were being written out by hand at 65+ sites, and
%   one of them carries a RULE rather than a value:
%
%       base.datestamp is mustBeNonEmpty, and a v1 document may carry none.
%
%   Every site that noticed that fell back to the same literal --
%   '2024-01-01T00:00:00.000Z' -- and every site that did NOT notice emits a
%   document which cannot validate. The literal was copy-pasted into at least
%   jSoftware and jSessionAnchor, each with its own comment explaining it. A
%   rule stated in N places is a rule that is true in N-1 places eventually;
%   this is the one place.
%
%   base.id is deliberately NOT defaulted. A missing id is never a sentinel
%   situation -- it is either a preserved source id (the caller has it) or a
%   fresh mint (the caller decides, because whether an id is preserved is a
%   MODELLING fact about that class, not a formatting detail). Passing '' here
%   gets you '', and the validator will say so.
%
%   ---------------------------------------------------------------------
%   WHAT THIS IS NOT
%   ---------------------------------------------------------------------
%   It is NOT the place the did_v1 -> V_eta field rename happens. `datestamp`
%   is renamed on the way OUT, once, for every body including passthroughs --
%   see did2.convert.v1_to_v2/renameOutboundBaseFields. Doing it here would
%   cover only the bodies migrators construct, and would silently miss every
%   document that passes through untouched.
%
%   STATUS: NOT VERIFIED BY EXECUTION. There is no MATLAB in the authoring
%   environment, so not one line below has been run.

arguments
    id (1,:) char = ''
    sessionId (1,:) char = ''
    name (1,:) char = ''
    datestamp (1,:) char = ''
end

ds = datestamp;
if isempty(ds)
    % THE SENTINEL, and it is a stated fallback rather than a silent one: a
    % document with no creation time is still a real document, and refusing to
    % emit it would lose data to satisfy a formatting rule.
    ds = '2024-01-01T00:00:00.000Z';
end

b = struct('id', id, 'session_id', sessionId, 'name', name, 'datestamp', ds);
end
