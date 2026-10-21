function ax = jAxis(variable, n, varargin)
%JAXIS One signed axis entry, every field present, in a FIXED order.
%   The shared constructor for `sampled_body.axes` (and any other mount of the
%   signed axis entry). DID-schema TEAM-SIGN-OFF [data_body] 2026-08-14 +
%   AMENDMENT 1, named per AMENDMENT 3; the ten sub-fields are `variable,
%   unit, source_unit, approximate, n, regular, origin, spacing, quantity,
%   term` (`quantity` is {value, source_value}, two arrays of n; `term` is n
%   terms).
%
%   ax = jAxis(variableTerm, n, 'name', value, ...)
%
%   TWO PROPERTIES ARE THE WHOLE REASON THIS EXISTS, and neither is cosmetic.
%
%   (1) EVERY FIELD IS ALWAYS PRESENT, IN THE SCHEMA'S OWN DECLARATION ORDER,
%   because `axes` is an ARRAY and MATLAB concatenates struct arrays only when
%   the operands share a field set AND its order. Building entries ad hoc means
%   `[timeAxis, channelAxis]` throws whenever one entry happens to omit a field
%   the other sets -- a failure that appears only on the multi-axis path, which
%   is exactly the path that is hard to fixture. Unset fields carry the schema's
%   declared BLANK (origin/spacing/quantity are `{}`; unit is a bare term), so a
%   present-but-blank field is indistinguishable from an absent one to the
%   validator, and nothing is asserted that was not measured.
%
%   (2) FIELD ORDER IS ASSIGNMENT ORDER HERE, NOT `struct(...)` ORDER, and that
%   is deliberate: `struct('term', someTermArray)` DISTRIBUTES a non-scalar
%   value into a struct ARRAY instead of setting one field. That trap has been
%   hit twice in this package already (image_stack.m and jNgridBody.m both carry
%   a comment about it). Plain assignment cannot distribute.
%
%   `variable` and `n` are the two mustBeNonEmpty sub-fields, so they are
%   POSITIONAL rather than options -- an axis that cannot name itself or state
%   its extent is not an axis, and making them optional would let a caller mint
%   one that quarantines.
%
%   Shared helper for the Brainstorm-J (+migrators_j) migrators.
%
%   did-schema #88: the axis entry is a `keys` entry (data_body amendment 3:
%   {variable, unit, source_unit, approximate, n, regular, origin, spacing,
%   quantity, term, positions_from, cyclic, chunk}). This returns it built
%   through did2.build.composite, with ONLY the sub-fields given (an empty
%   default is left out, so the schema's key rules -- regular iff origin and
%   spacing; one position form when not regular -- see what was given).
%   'source_unit' given as text becomes a term (jSourceUnit). A key given no
%   positions and not regular violates key_positions_one_form when the
%   document is built; the caller decides what it has.

if mod(numel(varargin), 2) ~= 0
    error('did2:migrators_j:jAxis:badOptions', ...
        'jAxis options must be name-value pairs; got %d trailing argument(s).', ...
        numel(varargin));
end
known = {'variable', 'unit', 'source_unit', 'approximate', 'n', 'regular', ...
    'origin', 'spacing', 'quantity', 'term', 'positions_from', 'cyclic', 'chunk'};
ax = struct('variable', variable, 'n', n, 'regular', false);
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~any(strcmp(name, known))
        error('did2:migrators_j:jAxis:unknownField', ...
            'jAxis has no sub-field `%s`. The signed entry declares: %s.', ...
            name, strjoin(known, ', '));
    end
    v = varargin{k + 1};
    if strcmp(name, 'source_unit') && (ischar(v) || isstring(v))
        v = jSourceUnit(v);
    end
    if isempty(v) || (isstruct(v) && isscalar(v) && isempty(fieldnames(v))) ...
            || (isstruct(v) && isfield(v, 'node') && isfield(v, 'name') ...
                && isscalar(v) && isempty(v.node) && isempty(v.name))
        continue;
    end
    if strcmp(name, 'quantity') && isstruct(v)
        if isfield(v, 'value'); v.value = reshape(v.value, 1, []); end
        if isfield(v, 'source_value'); v.source_value = reshape(v.source_value, 1, []); end
    end
    ax.(name) = v;
end
ax = did2.build.composite('data', 'keys', ax);
end
