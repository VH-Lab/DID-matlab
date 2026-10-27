function carried = jRawCarry(className, preBody, collision, unplaced, row)
%JRAWCARRY Note the carry of a raw v1 document whose fields its migrator
%   cannot all account for (jRawAccount), and say whether it is carried.
%
%   CARRIED = jRawCarry(CLASSNAME, PREBODY, COLLISION, UNPLACED) writes ONE
%   `carried_as_v1` note for the v1 document PREBODY and returns true when
%   COLLISION or UNPLACED is not empty; false (and no note) otherwise. The
%   caller then returns {PREBODY}: the carry is the untouched v1 source
%   ([migrators read raw v1]).
%
%     COLLISION  what universalRenames would have discarded: the renamed path
%                carried the document for it too, carry-049 ([renames carry is
%                temporary]); cited first
%     UNPLACED   a v1 field no part of the migrator reads, which the renamed
%                path dropped without a word. No register row yet (a question
%                for the team); the note says `unplaced:` and names the paths.
%
%   CARRIED = jRawCarry(..., 'carry-100') cites the register row for UNPLACED
%   instead of `none`: Decided by Jess Haley [fields outside the template are
%   malformed] (did-schema V_eta_go_forward_class_audit.md, carry-100): a field,
%   block or edge outside the class's NDI template carries the whole document
%   under one generic row. The families switched before that decision still
%   pass no ROW (`none`) until they are moved over.
%
%   See also jRawAccount.

carried = ~isempty(collision) || ~isempty(unplaced);
if ~carried
    return;
end
b = did2.convert.v1read.readBase(preBody);
id = b.id;
if ~ischar(id); id = ''; end
if ~isempty(collision)
    % carry-register: carry-049 (the renamed path carried this collision)
    did2.convert.reportNote('carried_as_v1', className, id, ...
        ['[carry-049] universalRenames would discard: ' strjoin(collision, ', ')]);
    return;
end
if nargin >= 5 && strcmp(row, 'carry-100')
    % carry-register: carry-100
    did2.convert.reportNote('carried_as_v1', className, id, ...
        ['[carry-100] malformed: outside the NDI template, unplaced: ' strjoin(unplaced, ', ')]);
    return;
end
% carry-register: none (a v1 field the migrator does not read; no row yet)
did2.convert.reportNote('carried_as_v1', className, id, ...
    ['unplaced: ' strjoin(unplaced, ', ')]);
end
