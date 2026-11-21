function form = oldNumericForm(item)
%OLDNUMERICFORM Which old-shape numeric form a list item holds ('' when none).
%
%   FORM = did2.read.oldNumericForm(ITEM). ITEM is one list item: a
%   covariate, a condition, a method or compression parameter, a model_fit
%   coefficient or constraint (the first element of a struct array or cell).
%   FORM names the first form of the OLD numeric shape that holds something:
%     'quantity'  a quantity {value, source_value}
%     'matrix'    a matrix
%     'origin'    an origin block {value, source_value}
%     'spacing'   a spacing block {value, source_value}
%     'value'     a model_fit coefficient's or constraint's old {variable,
%                 value}
%   and '' when ITEM is in the new shape or holds no number. A field that is
%   present but blank (an empty quantity or matrix) is not a form.
%
%   The old shape is no longer read: no v2 database migrated before the
%   writers wrote the new shape is kept, and one is migrated again from v1
%   (did-schema docs/plans/did_v2_numeric_shape_plan.md, section 9 step 4,
%   [no migrated database is kept], Jess Haley, 2026-11-19). Readers call
%   this and, on a non-empty FORM, did2.read.refuseOldNumericShape.
%
%   See also did2.read.refuseOldNumericShape, did2.read.numeric.

form = '';
if iscell(item)
    if isempty(item); return; end
    item = item{1};
end
if ~isstruct(item) || isempty(item)
    return;
end
item = item(1);
if isfield(item, 'quantity') && holds(item.quantity)
    form = 'quantity';
elseif isfield(item, 'matrix') && holds(item.matrix)
    form = 'matrix';
elseif isfield(item, 'origin') && isstruct(item.origin) && holds(item.origin)
    form = 'origin';
elseif isfield(item, 'spacing') && isstruct(item.spacing) && holds(item.spacing)
    form = 'spacing';
elseif isfield(item, 'variable') && isfield(item, 'value') && holds(item.value) ...
        && ~isfield(item, 'numeric')
    form = 'value';
end
end

function tf = holds(x)
% X holds something: a non-empty array, or a struct one of whose
% `value` / `source_value` is non-empty
tf = false;
if isempty(x)
    return;
end
if isstruct(x)
    for f = {'value', 'source_value'}
        if isfield(x, f{1}) && any(arrayfun(@(e) ~isempty(e.(f{1})), x))
            tf = true;
            return;
        end
    end
    return;
end
if iscell(x)
    tf = any(~cellfun(@isempty, x(:)));
    return;
end
tf = true;
end
