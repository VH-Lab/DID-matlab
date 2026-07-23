function v2Body = calcCommon(preBody, v1ClassName)
%CALCCOMMON Shared migrator body for V_delta `*_calc` classes.
%
%   v2Body = did2.convert.calcCommon(PREBODY, V1CLASSNAME) reshapes a
%   did_v1 calculator document body to match the V_delta
%   `calculator`-base inheritance contract. The abstract
%   `calculator` parent declares `input_parameters` with
%   `placement: "concrete_class"` (DID-schema V_delta calculator.json),
%   which means the field is hosted on the concrete subclass's block
%   (`<v1ClassName>.input_parameters`) on V_delta instance bodies and
%   the abstract `calculator` class contributes no body block. See
%   V_gamma_SPEC.md "Field placement" under "Field Definition Object".
%
%   v1 already stores `input_parameters` on the concrete class block
%   (`<class>.input_parameters`) — the same location V_delta wants —
%   so no structural move is needed. This migrator therefore only:
%
%     1. Coerces `<class>.input_parameters` to a struct (v1 sometimes
%        shipped an empty `[]`; V_delta wants `struct()`). Idempotent
%        for v1 bodies that already shipped a struct.
%     2. Drops a redundant inner `depends_on` if v1 stored one on the
%        calc block (e.g., `oridirtuning_calc.depends_on`); V_delta
%        only honors top-level `depends_on`.
%
%   The calculator-identity string lives in `app.app_name`, not in a
%   `calculator.calculator_name` field; that rename is handled
%   universally by did2.convert.universalRenames against the v1
%   top-level `app` block, which calc documents already carry. So
%   this helper does not have to (and must not) populate calculator
%   identity per concrete class.
%
%   Each per-class calc migrator under +did2/+convert/+migrators/
%   is a 3-line wrapper that calls this helper, e.g.:
%
%       function v2Body = oridirtuning_calc(preBody)
%           v2Body = did2.convert.calcCommon(preBody, 'oridirtuning_calc');
%       end
%
%   The dispatcher's downstream ensureClassBlocks pass adds empty
%   `{}` property blocks for the rest of the V_delta inheritance
%   chain (e.g., `tuning_fit`, the measurement parent), so this
%   helper does not need to manufacture them. ensureClassBlocks is
%   placement-aware and will not manufacture a `calculator` block
%   since calculator contributes nothing of its own to instance
%   bodies under the placement contract.
%
%   See did-schema's schemas/V_delta/conversions/from_did_v1/
%   oridirtuning_calc.md for the full conversion spec.

arguments
    preBody (1,1) struct
    v1ClassName (1,:) char
end

v2Body = preBody;
if ~isfield(v2Body, v1ClassName) || ~isstruct(v2Body.(v1ClassName))
    error('did2:convert:missingBlock', ...
        '%s body is missing the %s property block.', ...
        v1ClassName, v1ClassName);
end

block = v2Body.(v1ClassName);

if isfield(block, 'input_parameters')
    block.input_parameters = coerceToStruct(block.input_parameters);
else
    block.input_parameters = struct();
end

% v1 sometimes stored an internal `depends_on` struct on the calc
% block (e.g., oridirtuning_calc.depends_on); V_delta only honors
% top-level `depends_on`, so drop the redundant inner copy.
if isfield(block, 'depends_on')
    block = rmfield(block, 'depends_on');
end

v2Body.(v1ClassName) = block;
end

function out = coerceToStruct(value)
% Normalize a v1 `input_parameters` value to a struct so the
% V_delta `structure`-type validator accepts it. v1 frequently
% stores an empty array (`[]`) where V_delta wants `struct()`.
if isstruct(value)
    out = value;
elseif isnumeric(value) && isempty(value)
    out = struct();
elseif iscell(value) && isempty(value)
    out = struct();
else
    out = value;  % leave non-empty non-struct as-is; validator will
                   % surface the type mismatch with a clear error.
end
end
