function v2Body = calcCommon(preBody, v1ClassName)
%CALCCOMMON Shared migrator body for V2 `*_calc` classes.
%
%   v2Body = did2.convert.calcCommon(PREBODY, V1CLASSNAME) reshapes a
%   did_v1 calculator document body to match the V2
%   `calculator`-base inheritance contract. The abstract
%   `calculator` parent declares `input_parameters` with
%   `placement: "concrete_class"` (DID-schema V2 calculator.json),
%   which means the field is hosted on the concrete subclass's block
%   (`<v1ClassName>.input_parameters`) on V2 instance bodies and
%   the abstract `calculator` class contributes no body block. See
%   V_gamma_SPEC.md "Field placement" under "Field Definition Object".
%
%   v1 already stores `input_parameters` on the concrete class block
%   (`<class>.input_parameters`) — the same location V2 wants —
%   so no structural move is needed. This migrator therefore only:
%
%     1. Coerces `<class>.input_parameters` to a struct (v1 sometimes
%        shipped an empty `[]`; V2 wants `struct()`). Idempotent
%        for v1 bodies that already shipped a struct.
%     2. Drops a redundant inner `depends_on` if v1 stored one on the
%        calc block (e.g., `oridirtuning_calc.depends_on`); V2
%        only honors top-level `depends_on`. Only when every inner entry
%        restates the top-level edge of the same name ([restated values
%        checked], Jess Haley, 2026-10-26): otherwise the body is returned
%        unchanged, carried whole as v1, with a `carried_as_v1` note.
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
%   `{}` property blocks for the rest of the V2 inheritance
%   chain (e.g., `tuning_fit`, the measurement parent), so this
%   helper does not need to manufacture them. ensureClassBlocks is
%   placement-aware and will not manufacture a `calculator` block
%   since calculator contributes nothing of its own to instance
%   bodies under the placement contract.
%
%   See did-schema's conversion notes (deleted with did-schema #88)
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
% block (e.g., oridirtuning_calc.depends_on); V2 only honors
% top-level `depends_on`, so drop the redundant inner copy -- only when it
% IS redundant ([restated values checked], Jess Haley, 2026-10-26). A copy
% that differs from the top-level edges carries the body whole as v1
% ([partly placed is carried as v1], Jess Haley, 2026-10-25).
if isfield(block, 'depends_on')
    differing = innerDependsOnDiffers(preBody, block.depends_on);
    if ~isempty(differing)
        did2.convert.reportNote('carried_as_v1', v1ClassName, baseId(preBody), ...
            sprintf('unplaced: %s.depends_on (%s differs from the top-level edge)', ...
            v1ClassName, strjoin(differing, ', ')));
        v2Body = preBody;
        return;
    end
    block = rmfield(block, 'depends_on');
end

v2Body.(v1ClassName) = block;
end

function out = coerceToStruct(value)
% Normalize a v1 `input_parameters` value to a struct so the
% V2 `structure`-type validator accepts it. v1 frequently
% stores an empty array (`[]`) where V2 wants `struct()`.
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

function differing = innerDependsOnDiffers(preBody, inner)
%INNERDEPENDSONDIFFERS The names of the inner entries whose id is not the
%   top-level edge's of the same name. Both spellings of an id are read
%   ({name, value} and {name, document_id}).
differing = {};
if isempty(inner)
    return;
end
if isstruct(inner)
    inner = num2cell(inner);
elseif ~iscell(inner)
    differing = {'(not a list of edges)'};
    return;
end
for k = 1:numel(inner)
    d = inner{k};
    if ~isstruct(d) || ~isscalar(d) || ~isfield(d, 'name')
        differing{end+1} = sprintf('entry %d', k); %#ok<AGROW>
        continue;
    end
    if ~strcmp(edgeId(d), topLevelEdge(preBody, char(d.name)))
        differing{end+1} = char(d.name); %#ok<AGROW>
    end
end
end

function v = topLevelEdge(preBody, name)
v = '';
if ~isfield(preBody, 'depends_on') || isempty(preBody.depends_on)
    return;
end
deps = preBody.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if isstruct(d) && isfield(d, 'name') && strcmp(char(d.name), name)
        v = edgeId(d);
        return;
    end
end
end

function v = edgeId(d)
v = '';
for key = {'document_id', 'value', 'id'}
    if isfield(d, key{1}) && ~isempty(d.(key{1}))
        v = char(d.(key{1}));
        return;
    end
end
end

function id = baseId(preBody)
id = '';
if isfield(preBody, 'base') && isstruct(preBody.base) && isfield(preBody.base, 'id')
    id = char(preBody.base.id);
end
end
