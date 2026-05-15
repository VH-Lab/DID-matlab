function v2Body = calcCommon(preBody, v1ClassName, calculatorName)
%CALCCOMMON Shared migrator body for V_delta `*_calc` classes.
%
%   v2Body = did2.convert.calcCommon(PREBODY, V1CLASSNAME, CALCULATORNAME)
%   reshapes a did_v1 calculator document body to match the V_delta
%   `calculator`-base inheritance: the v1 `<class>.input_parameters`
%   field is moved into a new top-level `calculator` block, the
%   migrator sets `calculator.calculator_name` to CALCULATORNAME, and
%   redundant v1-only entries on the concrete class block are dropped.
%
%   Each per-class calc migrator under +did2/+convert/+migrators/
%   is a 3-line wrapper that calls this helper with the right
%   CALCULATORNAME, e.g.:
%
%       function v2Body = oridirtuning_calc(preBody)
%           v2Body = did2.convert.calcCommon(preBody, ...
%               'oridirtuning_calc', 'ndi.calc.vis.oridir_tuning');
%       end
%
%   The dispatcher's downstream ensureClassBlocks pass adds empty
%   `{}` property blocks for the rest of the V_delta inheritance
%   chain (e.g., `tuning_fit`, the measurement parent), so this
%   helper does not need to manufacture them itself.
%
%   See did-schema's schemas/V_delta/conversions/from_did_v1/
%   oridirtuning_calc.md for the full conversion spec.

arguments
    preBody (1,1) struct
    v1ClassName (1,:) char
    calculatorName (1,:) char
end

v2Body = preBody;
if ~isfield(v2Body, v1ClassName) || ~isstruct(v2Body.(v1ClassName))
    error('did2:convert:missingBlock', ...
        '%s body is missing the %s property block.', ...
        v1ClassName, v1ClassName);
end

block = v2Body.(v1ClassName);

if isfield(block, 'input_parameters')
    inputParams = block.input_parameters;
    block = rmfield(block, 'input_parameters');
else
    inputParams = struct();
end
inputParams = coerceToStruct(inputParams);

% v1 sometimes stored an internal `depends_on` struct on the calc
% block (e.g., oridirtuning_calc.depends_on); V_delta only honors
% top-level `depends_on`, so drop the redundant inner copy.
if isfield(block, 'depends_on')
    block = rmfield(block, 'depends_on');
end

% Drop any v1 calculator_name; this migrator always sets ours so
% the value is uniform per concrete class regardless of v1 drift.
if isfield(block, 'calculator_name')
    block = rmfield(block, 'calculator_name');
end

v2Body.(v1ClassName) = block;

v2Body.calculator = struct( ...
    'calculator_name', calculatorName, ...
    'input_parameters', inputParams);
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
