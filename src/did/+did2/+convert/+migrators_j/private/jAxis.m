function ax = jAxis(variable, n, varargin)
%JAXIS One signed axis entry, every field present, in a FIXED order.
%   The shared constructor for `sampled_body.axes` (and any other mount of the
%   signed axis entry). DID-schema TEAM-SIGN-OFF [data_body] 2026-08-14 +
%   AMENDMENT 1; the ten sub-fields are `variable, unit, source_unit,
%   approximate, n, regular, origin, spacing, values, labels`.
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
%   declared BLANK (origin/spacing/values are `{}`; unit is a bare term), so a
%   present-but-blank field is indistinguishable from an absent one to the
%   validator, and nothing is asserted that was not measured.
%
%   (2) FIELD ORDER IS ASSIGNMENT ORDER HERE, NOT `struct(...)` ORDER, and that
%   is deliberate: `struct('labels', someTermArray)` DISTRIBUTES a non-scalar
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

% Assigned one at a time, NOT via struct(...) -- see (2) above.
ax = struct();
ax.variable    = variable;
ax.unit        = struct('node', '', 'name', '');
ax.source_unit = '';
ax.approximate = false;
ax.n           = n;
ax.regular     = false;
ax.origin      = struct();
ax.spacing     = struct();
ax.values      = struct();
ax.labels      = struct('node', '', 'name', '');

if mod(numel(varargin), 2) ~= 0
    error('did2:migrators_j:jAxis:badOptions', ...
        'jAxis options must be name-value pairs; got %d trailing argument(s).', ...
        numel(varargin));
end
for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~isfield(ax, name)
        % NOT tolerated. A typo'd option would otherwise add an undeclared
        % sub-field, and `undeclaredField` is a QUARANTINE -- so the cheap
        % failure here replaces an expensive one on real documents.
        error('did2:migrators_j:jAxis:unknownField', ...
            'jAxis has no sub-field `%s`. The signed entry declares: %s.', ...
            name, strjoin(fieldnames(ax)', ', '));
    end
    ax.(name) = varargin{k + 1};
end
end
