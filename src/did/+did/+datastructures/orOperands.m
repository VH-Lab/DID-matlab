function operands = orOperands(searchstruct)
    % OROPERANDS - the operands of an 'or' search structure, with nested ORs flattened
    %
    % OPERANDS = did.datastructures.orOperands(SEARCHSTRUCT)
    %
    % Returns the operands of the 'or' search structure SEARCHSTRUCT as a cell
    % array, in their left-to-right order, with any operand that is itself an
    % 'or' replaced by its own operands.
    %
    % A query built as q = q | did.query(...) in a loop nests one 'or' per
    % term: or(or(or(q1, q2), q3), ...). Evaluating that by recursion costs a
    % stack frame or more per term, and a few hundred terms overrun MATLAB's
    % recursion limit (500 by default). This walks the chain with a stack
    % instead, so a caller can evaluate the operands in a loop.
    %
    % The operation of SEARCHSTRUCT itself is not examined, so the caller
    % decides what a negated top-level '~or' means. A nested operand is
    % flattened only if it is a single search structure whose operation is
    % exactly 'or': a negated '~or' stays one operand, since its negation
    % applies to its whole result. Operands are returned as given, empty ones
    % included.
    %
    % Mirrors DID-python's did.datastructures.or_operands (issue #100 there).
    %
    % See also: did.datastructures.fieldsearch, did.query/or

    arguments
        searchstruct (1,1) struct
    end

    operands = {};
    pending = {searchstruct.param2, searchstruct.param1};
    while ~isempty(pending)
        item = pending{end};
        pending(end) = [];
        if isstruct(item) && isscalar(item) && isfield(item, 'operation') ...
                && strcmpi(strtrim(char(item.operation)), 'or')
            pending(end+1:end+2) = {item.param2, item.param1};
        else
            operands{end+1} = item; %#ok<AGROW>
        end
    end
end
