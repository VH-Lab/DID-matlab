function [used, unplaced] = sessionAnchorOf(bodies, used, statement, sid)
%SESSIONANCHOROF Find the session anchor a statement names; say what is wrong
%   with it.
%
%   [USED, UNPLACED] = sessionAnchorOf(BODIES, USED, STATEMENT, SID). BODIES is
%   the cell of emitted documents, USED the logical mask of those an inverse
%   has already placed, STATEMENT the statement whose `time_reference_id`
%   names the anchor and SID the session id rebuilt for the v1 document. The
%   anchor must be the one did2.convert.migrators_j.private.jSessionAnchor
%   makes for 'during': a relative_time_reference `intervalDuring` the session
%   (referent_id SID), with no time of its own. USED comes back with the
%   anchor marked; UNPLACED lists, as text, what does not hold (no anchor, two
%   anchors, an anchor that is not the session's).
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.roundtrip.electrode_offset_voltage.

unplaced = {};
tr = edgeIds(statement, 'time_reference_id');
if numel(tr) ~= 1
    unplaced{end+1} = sprintf('the statement names %d time references (the session anchor is one)', ...
        numel(tr));
    return;
end
hit = 0;
for k = 1:numel(bodies)
    if ~used(k) && strcmp(char(getIn(bodies{k}, 'base', 'id')), tr{1})
        hit = k;
        break;
    end
end
if hit == 0
    unplaced{end+1} = 'the session anchor was not emitted';
    return;
end
used(hit) = true;
a = bodies{hit};
[rnode, rname] = termParts(getIn(a, 'relative_time_reference', 'value', 'relation'));
during = endsWith(rnode, 'intervalDuring') || strcmp(rname, 'intervalDuring');
if ~strcmp(classNameOf(a), 'relative_time_reference') ...
        || ~isequal(edgeIds(a, 'referent_id'), {sid}) || ~during ...
        || ~allEmpty(getIn(a, 'relative_time_reference', 'value', 'start'))
    unplaced{end+1} = 'the time reference is not the session anchor (intervalDuring the session)';
end
end
