function carried = jRawCarry(className, preBody, collision, unplaced, row, valueReasons)
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
%     UNPLACED   a v1 field, block or edge no part of the migrator reads
%                (outside the class's NDI template), which the renamed path
%                dropped without a word: carry-100 (below); the note names the
%                paths.
%
%   CARRIED = jRawCarry(..., ROW) names the register row for UNPLACED; the
%   only row is 'carry-100', the default: Decided by Jess Haley, 2026-10-27
%   [fields outside the template are malformed] (did-schema
%   V_eta_go_forward_class_audit.md, carry-100): a field, block or edge
%   outside the class's NDI template, which the migrator therefore does not
%   read, carries the whole document under one generic row.
%
%   CARRIED = jRawCarry(..., ROW, VALUEREASONS) also carries for VALUEREASONS
%   (a cellstr): a field the template DOES define whose value the migrator
%   cannot place or would rewrite (an ndim other than the writer's, a unit no
%   term is known for, a fractional cluster index). Those are not malformed by
%   that decision and have no register row yet (a question for the team); the
%   note lists them after the row's, or alone.
%
%   See also jRawAccount.

if nargin < 5 || isempty(row)
    row = 'carry-100';
end
if nargin < 6
    valueReasons = {};
end
if ~strcmp(row, 'carry-100')
    error('did2:convert:jRawCarry:unknownRow', ...
        'jRawCarry cites carry-100 for a field outside the template; "%s" is not a row it knows.', row);
end
carried = ~isempty(collision) || ~isempty(unplaced) || ~isempty(valueReasons);
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
rest = '';
if ~isempty(valueReasons)
    rest = ['unplaced: ' strjoin(valueReasons, ', ')];
end
if ~isempty(unplaced)
    if ~isempty(rest)
        rest = ['; ' rest];
    end
    % carry-register: carry-100; none for VALUEREASONS listed after it (a
    %   template field whose value the migrator cannot place; no row yet)
    did2.convert.reportNote('carried_as_v1', className, id, ...
        ['[carry-100] malformed: outside the NDI template, unplaced: ' ...
        strjoin(unplaced, ', ') rest]);
    return;
end
% carry-register: none (a template field whose value the migrator cannot
%   place or would rewrite; no row yet)
did2.convert.reportNote('carried_as_v1', className, id, rest);
end
